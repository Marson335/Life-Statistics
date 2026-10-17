import 'dart:convert';
import 'dart:math' as math;
import 'package:http/http.dart' as http;
import 'models/crypto_models.dart';
import 'groq_ai_service.dart';

/// Закриті денні свічки (поточна незавершена свічка відкидається).
class _Candles {
  final List<double> opens = [];
  final List<double> highs = [];
  final List<double> lows = [];
  final List<double> closes = [];
  final List<double> volumes = [];
  final List<double> quoteVolumes = [];
  final List<double> takerBuy = [];
  int get length => closes.length;
}

/// Сирі метрики монети. Рахуються для ВСЬОГО ліквідного всесвіту —
/// це база для крос-секційних перцентилів та ширини ринку (breadth).
class _CoinMetrics {
  _CoinMetrics(this.symbol, this.price, this.quoteVolume24h, this.candles);

  final String symbol;
  final double price;
  final double quoteVolume24h;
  final _Candles candles;

  double medianQuoteVolume20d = 0;
  double ema20 = 0, ema50 = 0, ema200 = 0, ema20Prev = 0, ema50Prev = 0;
  double atr14 = 0, atrPct = 0, atrRatio = 1, bbWidthPctile = 0.5;
  double rsi = 50, rsiDelta = 0;
  double rs30 = 0, rs90 = 0, momRaw = 0, sharpe60 = 0, trendPts = 0;
  double takerRatio7d = 50, takerDeltaPp = 0, udRatio = 1, obvSlope = 0;
  double dd250 = 0, beta = 1, corrBtc = 0;
  List<double> returns60 = const [];
  _CoinPlan? plan;
}

/// Торговий план монети (сетап, рівні, ризик, історична перевірка, оцінка).
class _CoinPlan {
  String setupType = '';
  String entryStatus = RadarEntryStatus.buyNow;
  double triggerPrice = 0;
  double entryMin = 0, entryMax = 0, entryRef = 0;
  double stop = 0, hardStop = 0, slPct = 0;
  String stopBasis = '';
  double tp1 = 0, tp2 = 0, tp1Pct = 0, tp2Pct = 0;
  String tp1Source = '', tp2Source = '';
  double rr1 = 0, rr2 = 0, blendedRR = 0;
  double? intermediateResistance;
  double hitRate = -1, expectancy = 0;
  int samples = 0;
  int timeStopDays = 21;
  double fMom = 0, fTrend = 0, fFlow = 0, fContr = 0, fEntry = 0, fRR = 0;
  double score = 0;
}

/// Ринковий режим: керує вагами факторів, ризиком на угоду, порогом оцінки та к-стю сигналів.
class _Regime {
  const _Regime({
    required this.code,
    required this.label,
    required this.riskMultiplier,
    required this.minScore,
    required this.maxPicks,
    required this.weights,
    required this.advice,
  });

  final String code;
  final String label;
  final double riskMultiplier;
  final double minScore;
  final int maxPicks;

  /// [momentum, trend, flow, contraction, entry, riskReward]
  final List<double> weights;
  final String advice;

  static const riskOn = _Regime(
    code: 'RISK_ON',
    label: 'Ризик-он (бичачий ринок)',
    riskMultiplier: 1.0,
    minScore: 55,
    maxPicks: 8,
    weights: [0.25, 0.20, 0.15, 0.10, 0.15, 0.15],
    advice: 'Ринок сприяє альткоїнам: пріоритет — лідери відносної сили, трендові відкати та пробої консолідацій.',
  );

  static const neutral = _Regime(
    code: 'NEUTRAL',
    label: 'Нейтральний (змішаний ринок)',
    riskMultiplier: 0.75,
    minScore: 60,
    maxPicks: 6,
    weights: [0.20, 0.20, 0.15, 0.10, 0.15, 0.20],
    advice: 'Змішаний ринок: входи лише від рівнів, обов\'язкова часткова фіксація на TP1 і перенесення стопу в беззбиток.',
  );

  static const riskOff = _Regime(
    code: 'RISK_OFF',
    label: 'Ризик-оф (ведмежий ринок)',
    riskMultiplier: 0.5,
    minScore: 66,
    maxPicks: 4,
    weights: [0.10, 0.15, 0.20, 0.10, 0.20, 0.25],
    advice: 'Ведмежий ринок: більшість альткоїнів падають разом з BTC. Тримайте 40–60% у стейблкоїнах, входьте половинним розміром і лише в найсильніші сетапи.',
  );
}

/// Smart Money Spot Radar v3 — режимно-адаптивний багатофакторний скринер Binance Spot.
///
/// 1. Режим ринку: BTC (EMA50/EMA200, нахил EMA50) + ширина ринку (% монет вище EMA50).
/// 2. Всесвіт: усі ліквідні USDT-пари (до 200 шт.), 230 ЗАКРИТИХ денних свічок на кожну.
/// 3. Фільтри якості: нові лістинги (<120 днів), низька медіанна ліквідність, памп-енд-дамп.
/// 4. 4 типи сетапів зі своєю логікою входу/стопу: трендовий відкат, пробій VCP, розворот з бази, лідер RS.
/// 5. Чесні цілі: TP від реальних опорів (pivot highs), а не примусові відсотки; фільтр R:R.
/// 6. Історична перевірка рівнів (hit-rate TP1 до SL за 200 днів) та очікуване EV.
/// 7. Крос-секційний 6-факторний скор + диверсифікація за кореляцією + розмір позиції від ризику.
class CryptoMarketScannerService {
  final GroqAiService groqService;
  static const String _baseUrl = 'https://api.binance.com';

  static const int _maxUniverse = 200;
  static const int _klineLimit = 230;
  static const int _batchSize = 20;
  static const int _minHistoryDays = 120;
  static const double _minQuoteVolume24h = 2000000;
  static const double _minMedianQuoteVolume20d = 1500000;
  static const double _baseRiskPerTradePct = 1.0;
  static const double _maxPositionPct = 25.0;
  static const double _maxStopPct = 18.0;
  static const double _maxPairCorrelation = 0.85;

  static const Set<String> _excludedTokens = {
    'USDT', 'USDC', 'FDUSD', 'TUSD', 'DAI', 'BUSD', 'EUR', 'GBP', 'UAH',
    'TRY', 'BIDR', 'IDRT', 'AUD', 'CAD', 'BRL', 'JPY', 'RUB', 'PAXG',
    'WBTC', 'WETH', 'WBETH', 'BNSOL', 'BTCST', 'USDD', 'PYUSD', 'AEUR',
    'USD1', 'USDE', 'USDP', 'XUSD', 'BFUSD', 'EURI', 'TROY', 'OMG', 'WAVES', 'XEM',
  };

  CryptoMarketScannerService({required this.groqService});

  Future<AiMarketRadarReport> scanMarket({
    void Function(String stage, double progress)? onProgress,
    double portfolioValueUsd = 0.0,
  }) async {
    final funnel = <String, int>{};
    try {
      // ---------------------------------------------------------------
      // ЕТАП 1. Котирування всіх пар + 230 днів BTC
      // ---------------------------------------------------------------
      onProgress?.call('Етап 1/5: Котирування 350+ пар Binance та макро-режим BTC...', 0.08);

      final responses = await Future.wait([
        http.get(Uri.parse('$_baseUrl/api/v3/ticker/24hr')).timeout(const Duration(seconds: 12)),
        http
            .get(Uri.parse('$_baseUrl/api/v3/klines?symbol=BTCUSDT&interval=1d&limit=$_klineLimit'))
            .timeout(const Duration(seconds: 8)),
      ]);
      if (responses[0].statusCode != 200) {
        throw Exception('Binance ticker недоступний (${responses[0].statusCode})');
      }
      if (responses[1].statusCode != 200) {
        throw Exception('Не вдалося отримати історію BTC (${responses[1].statusCode})');
      }

      final List<dynamic> allTickers = json.decode(responses[0].body);
      final btc = _parseKlines(json.decode(responses[1].body) as List<dynamic>);
      if (btc.length < 200) throw Exception('Недостатньо історії BTC для розрахунку режиму');

      double btcPrice = btc.closes.last;
      for (final t in allTickers) {
        if (t['symbol'] == 'BTCUSDT') {
          btcPrice = _d(t['lastPrice']);
          break;
        }
      }

      // ---------------------------------------------------------------
      // ЕТАП 2. Всесвіт: ліквідні, активні USDT-пари
      // ---------------------------------------------------------------
      final nowMs = DateTime.now().millisecondsSinceEpoch;
      int usdtPairs = 0;
      final universe = <Map<String, dynamic>>[];

      for (final t in allTickers) {
        final symbol = t['symbol']?.toString().toUpperCase() ?? '';
        if (!symbol.endsWith('USDT')) continue;
        final base = symbol.substring(0, symbol.length - 4);
        if (base.isEmpty || _excludedTokens.contains(base)) continue;
        if (base.endsWith('UP') || base.endsWith('DOWN') || base.endsWith('BULL') || base.endsWith('BEAR')) {
          continue;
        }
        final lastPrice = _d(t['lastPrice']);
        if (lastPrice <= 0) continue;
        usdtPairs++;

        final closeTime = (t['closeTime'] as num?)?.toInt() ?? nowMs;
        if (nowMs - closeTime > const Duration(hours: 3).inMilliseconds) {
          _inc(funnel, 'halted');
          continue;
        }
        final quoteVolume = _d(t['quoteVolume']);
        if (quoteVolume < _minQuoteVolume24h) {
          _inc(funnel, 'illiquid');
          continue;
        }
        universe.add({'symbol': base, 'pair': symbol, 'price': lastPrice, 'qv': quoteVolume});
      }
      universe.sort((a, b) => (b['qv'] as double).compareTo(a['qv'] as double));
      final selectedUniverse = universe.take(_maxUniverse).toList();
      funnel['scanned'] = usdtPairs;
      funnel['liquid'] = selectedUniverse.length;

      // ---------------------------------------------------------------
      // ЕТАП 3. Глибокий аналіз 230 закритих денних свічок кожної монети
      // ---------------------------------------------------------------
      final metrics = <_CoinMetrics>[];
      for (int i = 0; i < selectedUniverse.length; i += _batchSize) {
        final batch = selectedUniverse.sublist(i, math.min(i + _batchSize, selectedUniverse.length));
        onProgress?.call(
          'Етап 2/5: Глибокий аналіз свічок ${math.min(i + _batchSize, selectedUniverse.length)}/${selectedUniverse.length} '
              '(EMA200, ATR, Order Flow, RS vs BTC)...',
          0.12 + 0.58 * (i / math.max(1, selectedUniverse.length)),
        );
        final results = await Future.wait(batch.map((u) async {
          try {
            final resp = await http
                .get(Uri.parse('$_baseUrl/api/v3/klines?symbol=${u['pair']}&interval=1d&limit=$_klineLimit'))
                .timeout(const Duration(seconds: 8));
            if (resp.statusCode != 200) {
              _inc(funnel, 'fetchError');
              return null;
            }
            final candles = _parseKlines(json.decode(resp.body) as List<dynamic>);
            return _computeMetrics(
              u['symbol'] as String,
              u['price'] as double,
              u['qv'] as double,
              candles,
              btc,
              funnel,
            );
          } catch (_) {
            _inc(funnel, 'fetchError');
            return null;
          }
        }));
        metrics.addAll(results.whereType<_CoinMetrics>());
      }
      funnel['analyzed'] = metrics.length;

      if (metrics.isEmpty) {
        throw Exception('Не вдалося проаналізувати жодної пари — перевірте з\'єднання з Binance');
      }

      // ---------------------------------------------------------------
      // ЕТАП 4. Режим ринку (BTC + ширина) та торгові плани
      // ---------------------------------------------------------------
      onProgress?.call('Етап 3/5: Режим ринку, ширина ринку та пошук сетапів...', 0.74);

      final breadthPct = metrics.where((m) => m.price > m.ema50).length / metrics.length * 100.0;
      final btcCtx = _btcContext(btc, btcPrice);
      final regime = _resolveRegime(btcCtx, breadthPct);
      final riskPerTradePct = _baseRiskPerTradePct * regime.riskMultiplier;

      for (final m in metrics) {
        m.plan = _buildPlan(m, funnel);
      }
      final withPlans = metrics.where((m) => m.plan != null).toList();
      funnel['setups'] = withPlans.length;

      // ---------------------------------------------------------------
      // ЕТАП 5. Крос-секційний 6-факторний скор + диверсифікація
      // ---------------------------------------------------------------
      onProgress?.call('Етап 4/5: 6-факторний скоринг, історичний бектест рівнів та кореляція...', 0.82);

      List<double> sortedOf(double Function(_CoinMetrics) f) => metrics.map(f).toList()..sort();
      final sMom = sortedOf((m) => m.momRaw);
      final sSharpe = sortedOf((m) => m.sharpe60);
      final sTaker = sortedOf((m) => m.takerDeltaPp);
      final sUd = sortedOf((m) => math.log(m.udRatio.clamp(0.05, 20.0)));
      final sObv = sortedOf((m) => m.obvSlope);
      final sAtrR = sortedOf((m) => m.atrRatio);

      for (final m in withPlans) {
        final p = m.plan!;
        p.fMom = _pctRank(sMom, m.momRaw);
        p.fTrend = 0.6 * m.trendPts + 0.4 * _pctRank(sSharpe, m.sharpe60);
        p.fFlow = (_pctRank(sTaker, m.takerDeltaPp) +
                _pctRank(sUd, math.log(m.udRatio.clamp(0.05, 20.0))) +
                _pctRank(sObv, m.obvSlope)) /
            3.0;
        p.fContr = ((1.0 - _pctRank(sAtrR, m.atrRatio)) + (1.0 - m.bbWidthPctile)) / 2.0;

        double fEntry = switch (p.entryStatus) {
          RadarEntryStatus.buyNow => 0.65,
          RadarEntryStatus.waitBreakout => 0.55,
          _ => 0.45,
        };
        if (m.rsiDelta > 0) fEntry += 0.10;
        if (p.entryStatus == RadarEntryStatus.buyNow) {
          final distToStopAtr = (m.price - p.stop) / m.atr14;
          if (distToStopAtr <= 2.0) {
            fEntry += 0.20;
          } else if (distToStopAtr <= 3.0) {
            fEntry += 0.10;
          }
        }
        if (m.rsi > 68) fEntry -= 0.10;
        p.fEntry = fEntry.clamp(0.0, 1.0);

        final rrPart = ((p.blendedRR - 1.5) / 2.5).clamp(0.0, 1.0);
        final evPart = p.hitRate >= 0 ? (0.5 + p.expectancy / 12.0).clamp(0.0, 1.0) : 0.45;
        p.fRR = 0.6 * rrPart + 0.4 * evPart;

        final w = regime.weights;
        double score = 100.0 *
            (w[0] * p.fMom + w[1] * p.fTrend + w[2] * p.fFlow + w[3] * p.fContr + w[4] * p.fEntry + w[5] * p.fRR);
        // Відповідність сетапу режиму ринку
        if (regime.code == 'RISK_OFF' &&
            (p.setupType.contains('VCP') || p.setupType.contains('RS'))) {
          score *= 0.9;
        }
        if (regime.code == 'RISK_ON' && p.setupType.contains('Розворот')) score *= 0.95;
        p.score = score.clamp(1.0, 99.0);
      }

      withPlans.sort((a, b) => b.plan!.score.compareTo(a.plan!.score));

      final picks = <_CoinMetrics>[];
      for (final m in withPlans) {
        if (m.plan!.score < regime.minScore) {
          _inc(funnel, 'lowScore');
          continue;
        }
        if (picks.length >= regime.maxPicks) {
          _inc(funnel, 'overLimit');
          continue;
        }
        final tooCorrelated = picks.any((s) => _correlation(s.returns60, m.returns60) > _maxPairCorrelation);
        if (tooCorrelated) {
          _inc(funnel, 'correlated');
          continue;
        }
        picks.add(m);
      }
      funnel['selected'] = picks.length;

      // ---------------------------------------------------------------
      // Формування сигналів
      // ---------------------------------------------------------------
      final now = DateTime.now();
      final opportunities = picks
          .map((m) => _toOpportunity(m, regime, riskPerTradePct, portfolioValueUsd, btcCtx, now))
          .toList();

      final macro = StringBuffer()
        ..write('Режим: ${regime.label}. Ширина ринку: ${breadthPct.toStringAsFixed(0)}% ліквідних монет вище EMA50. ')
        ..write('Глибоко проаналізовано ${metrics.length} пар із $usdtPairs; знайдено ${withPlans.length} валідних сетапів, ')
        ..write('відібрано ${picks.length} з урахуванням порогу оцінки (${regime.minScore.toStringAsFixed(0)}+) та кореляції між монетами. ')
        ..write('Ризик на угоду: ${riskPerTradePct.toStringAsFixed(2)}% депозиту. ')
        ..write(regime.advice);
      if (picks.isEmpty) {
        macro.write('\n\nЖодна монета зараз не пройшла всі фільтри якості. Це нормальний результат: '
            'найкраща позиція в такий момент — кеш і очікування.');
      }

      final baseReport = AiMarketRadarReport(
        scannedAt: now,
        marketRegime: regime.code,
        btcTrend: btcCtx.description,
        macroSummary: macro.toString(),
        totalCoinsScanned: usdtPairs,
        opportunities: opportunities,
        breadthPct: double.parse(breadthPct.toStringAsFixed(1)),
        riskPerTradePct: riskPerTradePct,
        coinsDeepAnalyzed: metrics.length,
        setupsFound: withPlans.length,
        funnel: Map<String, int>.from(funnel),
      );

      // ---------------------------------------------------------------
      // AI-коментар (лише текст: числа, рівні та скор AI змінити не може)
      // ---------------------------------------------------------------
      if (opportunities.isEmpty) {
        onProgress?.call('Аналіз завершено!', 1.0);
        return baseReport;
      }
      onProgress?.call('Етап 5/5: AI-аналітик формує коментарі до сигналів...', 0.92);
      final enriched = await groqService.enrichRadarReport(baseReport);
      onProgress?.call('Аналіз завершено!', 1.0);
      return enriched;
    } catch (e) {
      return AiMarketRadarReport(
        scannedAt: DateTime.now(),
        marketRegime: 'Помилка сканування',
        btcTrend: '—',
        macroSummary: 'Не вдалося завершити сканування: $e. Перевірте з\'єднання з інтернетом та повторіть спробу.',
        totalCoinsScanned: 0,
        opportunities: const [],
        funnel: funnel,
      );
    }
  }

  // ===========================================================================
  // РОЗРАХУНОК МЕТРИК МОНЕТИ
  // ===========================================================================

  _CoinMetrics? _computeMetrics(
    String symbol,
    double price,
    double qv24,
    _Candles c,
    _Candles btc,
    Map<String, int> funnel,
  ) {
    final n = c.length;
    if (n < _minHistoryDays) {
      _inc(funnel, 'newListing');
      return null;
    }
    final closes = c.closes, highs = c.highs, lows = c.lows, volumes = c.volumes;

    // Медіанна ліквідність за 20 днів (стійкіша за 24г обсяг, який легко накрутити)
    final medianQv = _median(c.quoteVolumes.sublist(n - 20));
    if (medianQv < _minMedianQuoteVolume20d) {
      _inc(funnel, 'illiquid');
      return null;
    }

    // Памп-енд-дамп: денний ріст > 45% за останні 30 днів — фаза розподілу, не купуємо
    for (int i = n - 30; i < n; i++) {
      if (closes[i - 1] > 0 && closes[i] / closes[i - 1] - 1.0 > 0.45) {
        _inc(funnel, 'pumpDump');
        return null;
      }
    }

    final m = _CoinMetrics(symbol, price, qv24, c)..medianQuoteVolume20d = medianQv;

    // --- Тренд ---
    m.ema20 = _ema(closes, 20);
    m.ema50 = _ema(closes, 50);
    m.ema200 = n >= 200 ? _ema(closes, 200) : _sma(closes);
    m.ema20Prev = _ema(closes.sublist(0, n - 5), 20);
    m.ema50Prev = _ema(closes.sublist(0, n - 10), 50);

    // --- Волатильність ---
    m.atr14 = _atr(highs, lows, closes, 14);
    if (m.atr14 <= 0) return null;
    m.atrPct = m.atr14 / price * 100.0;
    final atr5 = _atr(highs, lows, closes, 5);
    final atr30 = _atr(highs, lows, closes, 30);
    m.atrRatio = atr30 > 0 ? atr5 / atr30 : 1.0;
    m.bbWidthPctile = _bbWidthPercentile(closes);

    // --- Імпульс ---
    m.rsi = _rsi(closes);
    m.rsiDelta = m.rsi - _rsi(closes.sublist(0, n - 3));

    // Відносна сила vs BTC (пропускаємо останні 3 дні — короткостроковий шум/реверсія)
    final bn = btc.length;
    double ret(List<double> s, int len, int fromEnd, int back) {
      final a = s[len - 1 - fromEnd];
      final b = s[len - 1 - fromEnd - back];
      return b > 0 ? (a / b - 1.0) * 100.0 : 0.0;
    }

    m.rs30 = ret(closes, n, 3, 30) - ret(btc.closes, bn, 3, 30);
    m.rs90 = ret(closes, n, 3, 90) - ret(btc.closes, bn, 3, 90);
    m.momRaw = 0.6 * m.rs30 + 0.4 * m.rs90;

    // Денні доходності за 60 днів (для Sharpe, beta, кореляції)
    final rets = <double>[];
    final btcRets = <double>[];
    for (int k = 60; k >= 1; k--) {
      final i = n - k, j = bn - k;
      rets.add(closes[i - 1] > 0 ? closes[i] / closes[i - 1] - 1.0 : 0.0);
      btcRets.add(btc.closes[j - 1] > 0 ? btc.closes[j] / btc.closes[j - 1] - 1.0 : 0.0);
    }
    m.returns60 = rets;
    final meanR = rets.reduce((a, b) => a + b) / rets.length;
    final stdR = _std(rets);
    m.sharpe60 = stdR > 0 ? meanR / stdR : 0.0;
    final varBtc = math.pow(_std(btcRets), 2).toDouble();
    m.beta = varBtc > 0 ? _covariance(rets, btcRets) / varBtc : 1.0;
    m.corrBtc = _correlation(rets, btcRets);

    int pts = 0;
    if (price > m.ema50) pts++;
    if (m.ema50 > m.ema200) pts++;
    if (m.ema50 >= m.ema50Prev) pts++;
    if (price > m.ema200) pts++;
    if (m.ema20 >= m.ema20Prev) pts++;
    m.trendPts = pts / 5.0;

    // --- Order Flow (відносно власної норми монети, а не абсолютні 53%) ---
    double sumTb7 = 0, sumV7 = 0, sumTbBase = 0, sumVBase = 0;
    for (int i = n - 7; i < n; i++) {
      sumTb7 += c.takerBuy[i];
      sumV7 += volumes[i];
    }
    for (int i = n - 60; i < n - 7; i++) {
      sumTbBase += c.takerBuy[i];
      sumVBase += volumes[i];
    }
    m.takerRatio7d = sumV7 > 0 ? sumTb7 / sumV7 * 100.0 : 50.0;
    final takerBase = sumVBase > 0 ? sumTbBase / sumVBase * 100.0 : 50.0;
    m.takerDeltaPp = m.takerRatio7d - takerBase;

    // Обсяг днів росту / днів падіння за 20 днів
    double upVol = 0, downVol = 0;
    for (int i = n - 20; i < n; i++) {
      if (closes[i] > closes[i - 1]) {
        upVol += volumes[i];
      } else if (closes[i] < closes[i - 1]) {
        downVol += volumes[i];
      }
    }
    m.udRatio = downVol > 0 ? upVol / downVol : (upVol > 0 ? 3.0 : 1.0);

    // Нахил OBV (лінійна регресія 20 днів, нормована на середній обсяг)
    double obv = 0;
    final obvSeries = <double>[];
    for (int i = n - 20; i < n; i++) {
      if (closes[i] > closes[i - 1]) {
        obv += volumes[i];
      } else if (closes[i] < closes[i - 1]) {
        obv -= volumes[i];
      }
      obvSeries.add(obv);
    }
    final avgVol20 = volumes.sublist(n - 20).reduce((a, b) => a + b) / 20.0;
    m.obvSlope = avgVol20 > 0 ? _linRegSlope(obvSeries) / avgVol20 : 0.0;

    final hiAll = highs.reduce(math.max);
    m.dd250 = hiAll > 0 ? (hiAll - price) / hiAll * 100.0 : 0.0;

    return m;
  }

  // ===========================================================================
  // СЕТАП, РІВНІ ВХОДУ / СТОПУ / ЦІЛЕЙ, ІСТОРИЧНА ПЕРЕВІРКА
  // ===========================================================================

  _CoinPlan? _buildPlan(_CoinMetrics m, Map<String, int> funnel) {
    final c = m.candles;
    final n = c.length;
    final p = m.price;
    final atr = m.atr14;
    final highs = c.highs, lows = c.lows, closes = c.closes;

    final lo10 = lows.sublist(n - 10).reduce(math.min);
    final lo30prev = lows.sublist(n - 30, n - 10).reduce(math.min);
    final higherLow = lo10 > lo30prev;
    final rangeHigh = highs.sublist(n - 31, n - 1).reduce(math.max);
    final extended = (p - m.ema20) / atr;

    final plan = _CoinPlan();
    double entryMin;
    double entryMax;
    double stop;

    if (p > m.ema200 &&
        m.ema50 > m.ema200 &&
        m.ema50 >= m.ema50Prev &&
        extended >= -1.5 &&
        extended <= 1.0 &&
        m.rsi >= 38 &&
        m.rsi <= 60) {
      // A. Трендовий відкат: висхідний тренд, ціна повернулась до EMA20/EMA50
      plan.setupType = 'Трендовий відкат до EMA';
      plan.timeStopDays = 21;
      final anchorIsEma20 = p >= m.ema20 - 0.5 * atr;
      final anchor = anchorIsEma20 ? m.ema20 : m.ema50;
      entryMin = anchor - 0.4 * atr;
      entryMax = anchor + 0.5 * atr;
      stop = math.min(lo10, anchor - 0.8 * atr) - 0.4 * atr;
      plan.stopBasis = 'нижче 10-денного мінімуму / ${anchorIsEma20 ? 'EMA20' : 'EMA50'} з буфером 0.4×ATR';
    } else if (p > m.ema50 &&
        (m.atrRatio < 0.8 || m.bbWidthPctile < 0.25) &&
        (rangeHigh - p) / atr <= 1.5 &&
        (p - rangeHigh) / atr <= 1.5 &&
        m.rsi >= 50 &&
        m.rsi <= 72 &&
        m.udRatio >= 1.0) {
      // B. Пробій консолідації: стиснення волатильності під 30-денним максимумом
      plan.setupType = 'Пробій консолідації (VCP)';
      plan.timeStopDays = 14;
      if (p < rangeHigh) {
        plan.entryStatus = RadarEntryStatus.waitBreakout;
        plan.triggerPrice = rangeHigh * 1.003;
        entryMin = plan.triggerPrice;
        entryMax = plan.triggerPrice + 0.4 * atr;
      } else {
        entryMin = rangeHigh - 0.2 * atr;
        entryMax = rangeHigh + 0.8 * atr;
      }
      stop = lo10 - 0.3 * atr;
      plan.stopBasis = 'нижче останнього мінімуму стиснення (10D) з буфером 0.3×ATR';
      final ref = math.max(p, entryMin);
      if (ref - stop > 3.5 * atr) {
        stop = ref - 3.0 * atr;
        plan.stopBasis = '3×ATR нижче точки пробою (база занадто глибока для структурного стопу)';
      }
    } else if (m.dd250 >= 35 &&
        closes[n - 1] > m.ema20 &&
        closes[n - 2] > m.ema20 &&
        higherLow &&
        m.rsi >= 45 &&
        m.rsi <= 63 &&
        m.rsiDelta > 0 &&
        (m.takerDeltaPp > 0 || m.obvSlope > 0)) {
      // C. Розворот з бази: після падіння — вищий мінімум + повернення над EMA20
      plan.setupType = 'Розворот з бази (вищий мінімум)';
      plan.timeStopDays = 30;
      entryMin = m.ema20 - 0.2 * atr;
      entryMax = m.ema20 + 1.0 * atr;
      stop = lo10 - 0.5 * atr;
      plan.stopBasis = 'нижче вищого мінімуму (10D) з буфером 0.5×ATR — злам структури розвороту';
    } else if (m.rs30 >= 10 &&
        p > m.ema20 &&
        m.ema20 > m.ema50 &&
        m.rsi >= 52 &&
        m.rsi <= 70 &&
        extended <= 2.2) {
      // D. Лідер відносної сили: сильніший за BTC, тримається над EMA20
      plan.setupType = 'Лідер відносної сили (RS)';
      plan.timeStopDays = 21;
      entryMin = m.ema20;
      entryMax = m.ema20 + 1.0 * atr;
      stop = math.max(lo10 - 0.3 * atr, m.ema20 - 1.5 * atr);
      plan.stopBasis = 'нижче EMA20 / 10-денного мінімуму — втрата лідерства';
    } else {
      _inc(funnel, 'noSetup');
      return null;
    }

    if (p <= stop) {
      _inc(funnel, 'brokenStructure');
      return null;
    }

    // Статус входу
    if (plan.entryStatus != RadarEntryStatus.waitBreakout) {
      if (p > entryMax) {
        plan.entryStatus = RadarEntryStatus.waitPullback;
        plan.triggerPrice = entryMax;
      } else {
        plan.entryStatus = RadarEntryStatus.buyNow;
        plan.triggerPrice = p;
      }
    }
    final entryRef = plan.entryStatus == RadarEntryStatus.buyNow ? p : plan.triggerPrice;
    if (stop >= entryRef) {
      _inc(funnel, 'brokenStructure');
      return null;
    }

    // Стоп: не ближче 1.2×ATR (шум), не далі 18% (для споту це вже не свінг)
    double slPct = (entryRef - stop) / entryRef * 100.0;
    final minSlPct = 1.2 * atr / entryRef * 100.0;
    if (slPct < minSlPct) {
      stop = entryRef * (1.0 - minSlPct / 100.0);
      slPct = minSlPct;
    }
    if (slPct > _maxStopPct) {
      _inc(funnel, 'wideStop');
      return null;
    }
    final risk = entryRef - stop;
    entryMin = math.max(entryMin, stop + 0.3 * atr);
    if (entryMin > entryMax) entryMin = entryMax;

    // Чесні цілі: реальні опори (pivot highs за 230 днів, річний максимум, EMA200)
    final levels = _pivotHighs(highs, wing: 3).where((h) => h > entryRef + 1.2 * atr).toList();
    final hiAll = highs.reduce(math.max);
    if (hiAll > entryRef + 1.2 * atr) levels.add(hiAll);
    if (m.ema200 > entryRef + 1.2 * atr) levels.add(m.ema200);
    levels.sort();
    final clustered = <double>[];
    for (final l in levels) {
      if (clustered.isEmpty || l - clustered.last > 0.6 * atr) clustered.add(l);
    }

    double tp1;
    double tp2;
    final tp1Candidates = clustered.where((l) => (l - 0.15 * atr) - entryRef >= risk).toList();
    if (tp1Candidates.isNotEmpty) {
      tp1 = tp1Candidates.first - 0.15 * atr;
      plan.tp1Source = 'перед найближчим значущим опором';
      final below = clustered.where((l) => l < tp1Candidates.first).toList();
      if (below.isNotEmpty) plan.intermediateResistance = below.first;
    } else {
      tp1 = entryRef + 2.0 * risk;
      plan.tp1Source = '2R — над ціною немає історичних опорів';
    }
    final tp2Candidates = clustered.where((l) => (l - 0.15 * atr) >= tp1 + atr).toList();
    if (tp2Candidates.isNotEmpty) {
      tp2 = tp2Candidates.first - 0.15 * atr;
      plan.tp2Source = 'перед наступним опором';
    } else {
      tp2 = math.max(tp1 + 1.5 * risk, entryRef + 3.0 * risk);
      plan.tp2Source = '3R — вільне небо над ціною';
    }

    final rr1 = (tp1 - entryRef) / risk;
    final rr2 = (tp2 - entryRef) / risk;
    final blended = 0.5 * rr1 + 0.5 * rr2;
    if (rr2 < 2.0 || blended < 1.5) {
      _inc(funnel, 'lowRR');
      return null;
    }

    // Історична перевірка: як часто на цій монеті (у тому ж положенні відносно EMA50)
    // ціна доходила до TP1 раніше, ніж до SL, протягом 30 днів.
    final ema50Series = _emaSeries(closes, 50);
    final aboveNow = p > m.ema50;
    final tpF = (tp1 - entryRef) / entryRef;
    final slF = slPct / 100.0;
    int wins = 0, losses = 0, samples = 0;
    for (int t = math.max(55, n - 200); t <= n - 31; t++) {
      if ((closes[t] > ema50Series[t]) != aboveNow) continue;
      samples++;
      final e = closes[t];
      for (int j = t + 1; j <= t + 30; j++) {
        if (lows[j] <= e * (1.0 - slF)) {
          losses++;
          break;
        }
        if (highs[j] >= e * (1.0 + tpF)) {
          wins++;
          break;
        }
      }
    }

    plan
      ..entryMin = entryMin
      ..entryMax = entryMax
      ..entryRef = entryRef
      ..stop = stop
      ..hardStop = math.max(stop - 0.8 * atr, stop * 0.9)
      ..slPct = slPct
      ..tp1 = tp1
      ..tp2 = tp2
      ..tp1Pct = tpF * 100.0
      ..tp2Pct = (tp2 - entryRef) / entryRef * 100.0
      ..rr1 = rr1
      ..rr2 = rr2
      ..blendedRR = blended
      ..samples = samples
      ..hitRate = samples >= 15 ? wins / samples * 100.0 : -1.0
      ..expectancy = samples >= 15 ? (wins * tpF - losses * slF) / samples * 100.0 : 0.0;
    return plan;
  }

  // ===========================================================================
  // ПЕРЕТВОРЕННЯ В СИГНАЛ ДЛЯ UI
  // ===========================================================================

  AiMarketOpportunity _toOpportunity(
    _CoinMetrics m,
    _Regime regime,
    double riskPerTradePct,
    double portfolioValueUsd,
    _BtcContext btcCtx,
    DateTime now,
  ) {
    final p = m.plan!;
    final positionPct = math.min(_maxPositionPct, riskPerTradePct / p.slPct * 100.0);
    final positionUsd = portfolioValueUsd > 0 ? portfolioValueUsd * positionPct / 100.0 : 0.0;

    final riskLevel = (p.slPct <= 8 && m.beta < 1.3)
        ? 'Низький'
        : ((p.slPct <= 13 && m.beta < 1.8) ? 'Помірний' : 'Високий');

    // --- Попередження (чесно про ризики) ---
    final warnings = <String>[];
    if (regime.code == 'RISK_OFF') {
      warnings.add('Ведмежий режим ринку — розмір позиції вже урізано вдвічі.');
    }
    if (m.beta >= 1.6) {
      warnings.add('Високий beta ${m.beta.toStringAsFixed(1)} до BTC: падіння BTC на 5% може дати ≈-${(m.beta * 5).toStringAsFixed(0)}% по монеті.');
    }
    if (p.hitRate >= 0 && p.hitRate < 40) {
      warnings.add('Історично TP1 досягався лише в ${p.hitRate.toStringAsFixed(0)}% випадків — розгляньте менший розмір.');
    }
    if (p.intermediateResistance != null) {
      warnings.add('Проміжний опір на \$${_fmt(p.intermediateResistance!)} — можлива пауза до TP1.');
    }
    if (m.medianQuoteVolume20d < 5000000) {
      warnings.add('Помірна ліквідність (медіана \$${(m.medianQuoteVolume20d / 1e6).toStringAsFixed(1)}M/добу) — лише лімітні ордери.');
    }
    if (m.dd250 >= 70) {
      warnings.add('Монета -${m.dd250.toStringAsFixed(0)}% від річного максимуму — довгий шлях відновлення, багато «зависших» продавців.');
    }
    if (p.entryStatus == RadarEntryStatus.waitPullback) {
      warnings.add('Ціна вище зони входу — не наздоганяйте ринковим ордером.');
    }
    if (p.tp2Source.startsWith('3R')) {
      warnings.add('Над ціною немає історичних опорів — TP2 розраховано за R-мультиплікатором.');
    }

    final rsiSign = m.rsiDelta >= 0 ? '+' : '';
    final trendDesc = (m.price > m.ema200 && m.ema50 > m.ema200)
        ? 'висхідний тренд'
        : (m.price < m.ema200 && m.ema50 < m.ema200 ? 'низхідний тренд' : 'перехідна фаза');

    final technical = 'Сетап: ${p.setupType}. Ціна \$${_fmt(m.price)}; EMA20 \$${_fmt(m.ema20)} · '
        'EMA50 \$${_fmt(m.ema50)} · EMA200 \$${_fmt(m.ema200)} ($trendDesc). '
        'RSI(14D) ${m.rsi.toStringAsFixed(1)} ($rsiSign${m.rsiDelta.toStringAsFixed(1)} за 3 дні). '
        'Волатильність ATR ${m.atrPct.toStringAsFixed(1)}%/день; стиснення ATR5/ATR30 = ${m.atrRatio.toStringAsFixed(2)}, '
        'ширина Боллінджера на ${(m.bbWidthPctile * 100).toStringAsFixed(0)}-му перцентилі власної історії. '
        'Від 230-денного максимуму: -${m.dd250.toStringAsFixed(1)}%.';

    final flow = 'Відносна сила проти BTC: ${_signed(m.rs30)}% за 30 днів, ${_signed(m.rs90)}% за 90 днів '
        '(без останніх 3 днів шуму). Order Flow: агресивні покупки за 7 днів ${m.takerRatio7d.toStringAsFixed(1)}% '
        '(${_signed(m.takerDeltaPp)} п.п. до власної 60-денної норми монети). '
        'Обсяг днів росту / днів падіння (20D): ${m.udRatio.toStringAsFixed(2)}×. '
        'OBV ${m.obvSlope > 0 ? 'зростає — ознака накопичення' : 'знижується — ознака розподілу'}. '
        'Beta до BTC: ${m.beta.toStringAsFixed(2)}, кореляція ${m.corrBtc.toStringAsFixed(2)}.';

    final sizeTxt = positionUsd > 0
        ? '${positionPct.toStringAsFixed(1)}% депозиту (≈\$${positionUsd.toStringAsFixed(0)})'
        : '${positionPct.toStringAsFixed(1)}% депозиту';
    final String entryPlan;
    switch (p.entryStatus) {
      case RadarEntryStatus.waitBreakout:
        entryPlan = 'ЧЕКАТИ ПРОБІЙ. Виставити stop-limit на купівлю \$${_fmt(p.triggerPrice)} '
            '(пробій 30-денного діапазону). Вхід валідний лише якщо денна свічка закриється вище рівня на обсязі '
            '≥1.5× від середнього. Якщо ціна закриє день нижче \$${_fmt(p.stop)} до пробою — сетап скасовано.\n'
            'Розмір позиції: $sizeTxt — при спрацюванні стопу втрата = ${riskPerTradePct.toStringAsFixed(2)}% депозиту.';
        break;
      case RadarEntryStatus.waitPullback:
        entryPlan = 'НЕ КУПУВАТИ ЗАРАЗ — ціна витягнута над зоною входу. Лімітні ордери: 60% на \$${_fmt(p.entryMax)} '
            'та 40% на \$${_fmt(p.entryMin)}. Якщо лімітки не виконались за ${p.timeStopDays} днів — сетап переглянути.\n'
            'Розмір позиції: $sizeTxt — при спрацюванні стопу втрата = ${riskPerTradePct.toStringAsFixed(2)}% депозиту.';
        break;
      default:
        entryPlan = 'КУПУВАТИ: 50% позиції зараз (≈\$${_fmt(m.price)}), 50% лімітом у нижній частині зони \$${_fmt(p.entryMin)}. '
            'Не докуповувати нижче зони — нижче лише стоп.\n'
            'Розмір позиції: $sizeTxt — при спрацюванні стопу втрата = ${riskPerTradePct.toStringAsFixed(2)}% депозиту.';
    }

    final tpRule = '1) TP1 \$${_fmt(p.tp1)} (+${p.tp1Pct.toStringAsFixed(1)}%, ${p.tp1Source}) — продати 50% позиції '
        'і перенести стоп у беззбиток (\$${_fmt(p.entryRef)}).\n'
        '2) TP2 \$${_fmt(p.tp2)} (+${p.tp2Pct.toStringAsFixed(1)}%, ${p.tp2Source}) — продати ще 30%.\n'
        '3) Залишок 20% — трейлінг: вихід при денному закритті нижче EMA20 (зараз \$${_fmt(m.ema20)}).\n'
        '4) Достроково: денний RSI > 78 + обсяг > 2.5× середнього + довга верхня тінь — зафіксувати ще 25–50%.';

    final slRule = 'Стоп \$${_fmt(p.stop)} (-${p.slPct.toStringAsFixed(1)}%): ${p.stopBasis}. '
        'Вихід при закритті денної свічки нижче рівня (проколи тінню з поверненням ігноруємо).\n'
        'Аварійний стоп-ордер на біржі: \$${_fmt(p.hardStop)} — на випадок різкого обвалу.\n'
        'Тайм-стоп: якщо за ${p.timeStopDays} днів TP1 не досягнуто, а ціна нижче входу +0.5R — закрити позицію (капітал простоює).\n'
        'Ринковий фільтр: денне закриття BTC нижче EMA200 (\$${_fmt(btcCtx.ema200)}) — скоротити всі альт-позиції на 50%.';

    return AiMarketOpportunity(
      symbol: m.symbol,
      name: m.symbol,
      sector: '',
      setupType: p.setupType,
      currentPrice: m.price,
      supportLevel: p.stop + 0.4 * m.atr14,
      entryZoneMin: p.entryMin,
      entryZoneMax: p.entryMax,
      targetPrice1: p.tp1,
      targetPrice2: p.tp2,
      stopLoss: p.stop,
      potentialPct: _r(p.tp2Pct, 1),
      riskRewardRatio: _r(p.rr2, 1),
      riskLevel: riskLevel,
      confidenceScore: p.score.round(),
      technicalReason: technical,
      smartMoneyCatalyst: flow,
      dcaStrategy: entryPlan,
      tpTriggerRule: tpRule,
      slTriggerRule: slRule,
      rsi: _r(m.rsi, 1),
      dropFromPeakPct: _r(m.dd250, 1),
      volume24hUsd: m.quoteVolume24h,
      takerBuyRatioPct: _r(m.takerRatio7d, 1),
      atrPct: _r(m.atrPct, 2),
      scannedAt: now,
      entryStatus: p.entryStatus,
      triggerPrice: p.triggerPrice,
      hardStopPrice: p.hardStop,
      timeStopDays: p.timeStopDays,
      tp1Source: p.tp1Source,
      tp2Source: p.tp2Source,
      rsVsBtc30d: _r(m.rs30, 1),
      rsVsBtc90d: _r(m.rs90, 1),
      takerDeltaPp: _r(m.takerDeltaPp, 2),
      upDownVolumeRatio: _r(m.udRatio, 2),
      betaToBtc: _r(m.beta, 2),
      blendedRR: _r(p.blendedRR, 2),
      tp1HitRatePct: _r(p.hitRate, 0),
      expectancyPct: _r(p.expectancy, 1),
      historicalSamples: p.samples,
      positionSizePct: _r(positionPct, 1),
      positionSizeUsd: _r(positionUsd, 0),
      riskPerTradePct: riskPerTradePct,
      scoreMomentum: _r(p.fMom * 100, 0),
      scoreTrend: _r(p.fTrend * 100, 0),
      scoreFlow: _r(p.fFlow * 100, 0),
      scoreContraction: _r(p.fContr * 100, 0),
      scoreEntry: _r(p.fEntry * 100, 0),
      scoreRiskReward: _r(p.fRR * 100, 0),
      warnings: warnings,
    );
  }

  // ===========================================================================
  // РЕЖИМ РИНКУ
  // ===========================================================================

  _BtcContext _btcContext(_Candles btc, double btcPrice) {
    final closes = btc.closes;
    final n = closes.length;
    final ema50 = _ema(closes, 50);
    final ema200 = _ema(closes, 200);
    final ema50Prev = _ema(closes.sublist(0, n - 10), 50);
    final rsi = _rsi(closes);
    final ret30 = closes[n - 31] > 0 ? (btcPrice / closes[n - 31] - 1.0) * 100.0 : 0.0;
    return _BtcContext(
      price: btcPrice,
      ema50: ema50,
      ema200: ema200,
      ema50Rising: ema50 >= ema50Prev,
      rsi: rsi,
      ret30: ret30,
      description: 'BTC \$${_fmt(btcPrice)} · ${btcPrice > ema200 ? 'вище' : 'нижче'} EMA200 (\$${_fmt(ema200)}) · '
          'EMA50 ${ema50 >= ema50Prev ? 'росте' : 'падає'} · RSI ${rsi.toStringAsFixed(0)} · 30D ${_signed(ret30)}%',
    );
  }

  _Regime _resolveRegime(_BtcContext b, double breadthPct) {
    int pts = 0;
    pts += b.price > b.ema200 ? 1 : -1;
    pts += b.ema50 > b.ema200 ? 1 : -1;
    pts += b.ema50Rising ? 1 : -1;
    if (breadthPct >= 55) {
      pts += 1;
    } else if (breadthPct <= 35) {
      pts -= 1;
    }
    if (pts >= 2) return _Regime.riskOn;
    if (pts <= -2) return _Regime.riskOff;
    return _Regime.neutral;
  }

  // ===========================================================================
  // ДОПОМІЖНІ РОЗРАХУНКИ
  // ===========================================================================

  static _Candles _parseKlines(List<dynamic> raw) {
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final c = _Candles();
    for (final k in raw) {
      final closeTime = (k[6] as num).toInt();
      if (closeTime > nowMs) continue; // поточна незакрита свічка спотворює RSI/обсяги/тіні
      c.opens.add(_d(k[1]));
      c.highs.add(_d(k[2]));
      c.lows.add(_d(k[3]));
      c.closes.add(_d(k[4]));
      c.volumes.add(_d(k[5]));
      c.quoteVolumes.add(_d(k[7]));
      c.takerBuy.add(_d(k[9]));
    }
    return c;
  }

  static double _d(dynamic v) => double.tryParse(v?.toString() ?? '') ?? 0.0;

  static double _r(double v, int digits) => double.parse(v.toStringAsFixed(digits));

  static String _signed(double v) => '${v >= 0 ? '+' : ''}${v.toStringAsFixed(1)}';

  static void _inc(Map<String, int> m, String k) => m[k] = (m[k] ?? 0) + 1;

  static String _fmt(double val) {
    if (val >= 1000) return val.toStringAsFixed(2);
    if (val >= 1) return val.toStringAsFixed(3);
    if (val >= 0.01) return val.toStringAsFixed(4);
    return val.toStringAsFixed(6);
  }

  static double _sma(List<double> v) => v.isEmpty ? 0.0 : v.reduce((a, b) => a + b) / v.length;

  static double _median(List<double> v) {
    if (v.isEmpty) return 0.0;
    final s = [...v]..sort();
    final mid = s.length ~/ 2;
    return s.length.isOdd ? s[mid] : (s[mid - 1] + s[mid]) / 2.0;
  }

  static double _std(List<double> v) {
    if (v.length < 2) return 0.0;
    final mean = _sma(v);
    double s = 0;
    for (final x in v) {
      s += (x - mean) * (x - mean);
    }
    return math.sqrt(s / (v.length - 1));
  }

  static double _covariance(List<double> a, List<double> b) {
    final n = math.min(a.length, b.length);
    if (n < 2) return 0.0;
    final ma = _sma(a.sublist(0, n)), mb = _sma(b.sublist(0, n));
    double s = 0;
    for (int i = 0; i < n; i++) {
      s += (a[i] - ma) * (b[i] - mb);
    }
    return s / (n - 1);
  }

  static double _correlation(List<double> a, List<double> b) {
    final n = math.min(a.length, b.length);
    if (n < 10) return 0.0;
    final sa = _std(a.sublist(0, n)), sb = _std(b.sublist(0, n));
    if (sa == 0 || sb == 0) return 0.0;
    return _covariance(a.sublist(0, n), b.sublist(0, n)) / (sa * sb);
  }

  static double _linRegSlope(List<double> ys) {
    final n = ys.length;
    if (n < 2) return 0.0;
    final xMean = (n - 1) / 2.0;
    final yMean = _sma(ys);
    double num = 0, den = 0;
    for (int i = 0; i < n; i++) {
      num += (i - xMean) * (ys[i] - yMean);
      den += (i - xMean) * (i - xMean);
    }
    return den > 0 ? num / den : 0.0;
  }

  /// Перцентильний ранг значення у відсортованому масиві (0..1).
  static double _pctRank(List<double> sorted, double v) {
    if (sorted.isEmpty) return 0.5;
    int below = 0, equal = 0;
    for (final x in sorted) {
      if (x < v) {
        below++;
      } else if (x == v) {
        equal++;
      }
    }
    return (below + 0.5 * equal) / sorted.length;
  }

  static List<double> _pivotHighs(List<double> highs, {int wing = 3}) {
    final res = <double>[];
    for (int i = wing; i < highs.length - wing; i++) {
      bool isPivot = true;
      for (int j = i - wing; j <= i + wing; j++) {
        if (j != i && highs[j] > highs[i]) {
          isPivot = false;
          break;
        }
      }
      if (isPivot) res.add(highs[i]);
    }
    return res;
  }

  /// Перцентиль поточної ширини смуг Боллінджера відносно останніх 120 днів (0 = максимальне стиснення).
  static double _bbWidthPercentile(List<double> closes, {int period = 20, int lookback = 120}) {
    final n = closes.length;
    if (n < period + 10) return 0.5;
    final widths = <double>[];
    for (int end = math.max(period, n - lookback); end <= n; end++) {
      final win = closes.sublist(end - period, end);
      final mean = _sma(win);
      if (mean <= 0) continue;
      double v = 0;
      for (final x in win) {
        v += (x - mean) * (x - mean);
      }
      widths.add(4.0 * math.sqrt(v / period) / mean);
    }
    if (widths.length < 5) return 0.5;
    final current = widths.last;
    final below = widths.where((w) => w < current).length;
    return below / (widths.length - 1);
  }

  static double _ema(List<double> prices, int period) {
    if (prices.isEmpty) return 0.0;
    if (prices.length < period) return _sma(prices);
    final k = 2.0 / (period + 1);
    double ema = _sma(prices.sublist(0, period));
    for (int i = period; i < prices.length; i++) {
      ema = prices[i] * k + ema * (1.0 - k);
    }
    return ema;
  }

  static List<double> _emaSeries(List<double> prices, int period) {
    final out = List<double>.filled(prices.length, 0.0);
    if (prices.isEmpty) return out;
    final k = 2.0 / (period + 1);
    double running = 0;
    for (int i = 0; i < prices.length; i++) {
      if (i < period) {
        running += prices[i];
        out[i] = running / (i + 1);
      } else {
        out[i] = prices[i] * k + out[i - 1] * (1.0 - k);
      }
    }
    return out;
  }

  static double _atr(List<double> highs, List<double> lows, List<double> closes, int period) {
    final n = closes.length;
    if (n < 2) return 0.0;
    final tr = <double>[];
    for (int i = 1; i < n; i++) {
      final hl = highs[i] - lows[i];
      final hc = (highs[i] - closes[i - 1]).abs();
      final lc = (lows[i] - closes[i - 1]).abs();
      tr.add(math.max(hl, math.max(hc, lc)));
    }
    if (tr.length <= period) return _sma(tr);
    double atr = _sma(tr.sublist(0, period));
    for (int i = period; i < tr.length; i++) {
      atr = (atr * (period - 1) + tr[i]) / period;
    }
    return atr;
  }

  static double _rsi(List<double> prices, {int period = 14}) {
    if (prices.length <= period) return 50.0;
    double gains = 0, losses = 0;
    for (int i = 1; i <= period; i++) {
      final diff = prices[i] - prices[i - 1];
      if (diff >= 0) {
        gains += diff;
      } else {
        losses -= diff;
      }
    }
    double avgGain = gains / period;
    double avgLoss = losses / period;
    for (int i = period + 1; i < prices.length; i++) {
      final diff = prices[i] - prices[i - 1];
      avgGain = (avgGain * (period - 1) + (diff > 0 ? diff : 0.0)) / period;
      avgLoss = (avgLoss * (period - 1) + (diff < 0 ? -diff : 0.0)) / period;
    }
    if (avgLoss == 0) return 100.0;
    return 100.0 - 100.0 / (1.0 + avgGain / avgLoss);
  }
}

class _BtcContext {
  const _BtcContext({
    required this.price,
    required this.ema50,
    required this.ema200,
    required this.ema50Rising,
    required this.rsi,
    required this.ret30,
    required this.description,
  });

  final double price;
  final double ema50;
  final double ema200;
  final bool ema50Rising;
  final double rsi;
  final double ret30;
  final String description;
}
