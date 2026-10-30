import 'dart:convert';
import 'dart:math' as math;
import 'package:http/http.dart' as http;
import 'models/crypto_models.dart';
import 'groq_ai_service.dart';

class _CoreL1Meta {
  final String symbol;
  final String name;
  final String roleLabel;

  const _CoreL1Meta(this.symbol, this.name, this.roleLabel);
}

class _DailyBars {
  final List<double> opens = [];
  final List<double> highs = [];
  final List<double> lows = [];
  final List<double> closes = [];
  final List<double> baseVolumes = [];
  final List<double> quoteVolumes = [];
  final List<double> takerBuyQuote = [];

  int get length => closes.length;
}

/// Інституційний аналізатор фундаментальних монет першого рівня (Layer-1 Core: BTC, ETH, SOL, BNB, XRP, SUI, TON, AVAX, ADA, TRX).
///
/// Працює за методологією довгострокового та середньострокового управління капіталом:
/// 1. 365 закритих денних свічок (1 повний рік) + агрегація у 52 тижневі свічки (1W).
/// 2. Оцінка інституційної собівартості (365D VWAP — аналог On-chain Realized Price / MVRV).
/// 3. Мультиплікатор Майєра (Mayer Multiple = Ціна / SMA200) для визначення фази циклу (недооцінка vs перегрів).
/// 4. 365-денний Volume Profile (24 цінові кошики) для пошуку Point of Control (POC — рівня максимальної ліквідності).
/// 5. Мультитаймфреймовий імпульс: Денний RSI (14D) + Тижневий RSI (14W) + потік ордерів китів (Taker Buy Delta).
/// 6. Трирівнева драбина закупки (Smart DCA) та трирівнева матриця фіксації прибутку (Cycle Distribution).
class CryptoFundamentalAnalysisService {
  final GroqAiService groqService;
  static const String _baseUrl = 'https://api.binance.com';
  static const int _klineLimit = 365;

  static const List<_CoreL1Meta> _coreUniverse = [
    _CoreL1Meta('BTC', 'Bitcoin', 'Цифрове золото · Макро-еталон L1'),
    _CoreL1Meta('ETH', 'Ethereum', 'Світовий розрахунковий шар & DeFi L1'),
    _CoreL1Meta('SOL', 'Solana', 'Високочастотний інституційний L1'),
    _CoreL1Meta('BNB', 'BNB Chain', 'Екосистемний та інфраструктурний L1'),
    _CoreL1Meta('XRP', 'XRP Ledger', 'Транскордонний платіжний L1-протокол'),
    _CoreL1Meta('SUI', 'Sui Network', 'Модульний об\'єктний Move L1'),
    _CoreL1Meta('TON', 'Toncoin', 'Масовий споживчий Web3 L1-шар'),
    _CoreL1Meta('AVAX', 'Avalanche', 'Інституційні сабнети та RWA L1'),
    _CoreL1Meta('ADA', 'Cardano', 'Академічний PoS L1-блокчейн'),
    _CoreL1Meta('TRX', 'TRON', 'Глобальний розрахунковий шар стейблкоїнів'),
  ];

  CryptoFundamentalAnalysisService({required this.groqService});

  Future<FundamentalAnalysisReport> analyzeFundamentals({
    void Function(String status, double progress)? onProgress,
  }) async {
    onProgress?.call('Етап 1/4: Завантаження 365 днів історії по фундаментальних L1 (BTC, ETH, SOL...)...', 0.12);

    // 1. Завантажуємо 24h тікери для миттєвих цін та добових змін
    final Map<String, ({double price, double chg24h})> liveTickers = {};
    try {
      final tickerResp = await http
          .get(Uri.parse('$_baseUrl/api/v3/ticker/24hr'))
          .timeout(const Duration(seconds: 10));
      if (tickerResp.statusCode == 200) {
        final list = jsonDecode(tickerResp.body) as List<dynamic>;
        for (final item in list) {
          final sym = item['symbol']?.toString() ?? '';
          if (!sym.endsWith('USDT')) continue;
          final base = sym.substring(0, sym.length - 4);
          final p = double.tryParse(item['lastPrice']?.toString() ?? '0') ?? 0.0;
          final chg = double.tryParse(item['priceChangePercent']?.toString() ?? '0') ?? 0.0;
          if (p > 0) {
            liveTickers[base] = (price: p, chg24h: chg);
          }
        }
      }
    } catch (_) {}

    onProgress?.call('Етап 2/4: Побудова 365D Volume Profile (POC), VWAP-собівартості та 1W свічок...', 0.35);

    // 2. Паралельне завантаження 365 денних свічок для всіх 10 фундаментальних активів
    final Map<String, _DailyBars> barsBySymbol = {};
    await Future.wait(_coreUniverse.map((meta) async {
      final bars = await _fetch365DailyBars('${meta.symbol}USDT');
      if (bars != null && bars.length >= 60) {
        barsBySymbol[meta.symbol] = bars;
      }
    }));

    final btcBars = barsBySymbol['BTC'];
    if (btcBars == null || btcBars.length < 60) {
      throw Exception('Не вдалося отримати історичні свічки BTCUSDT з Binance.');
    }

    final btcRet30 = _returnOverDays(btcBars.closes, 30);
    final btcRet90 = _returnOverDays(btcBars.closes, 90);

    onProgress?.call('Етап 3/4: Розрахунок Mayer Multiple, MVRV-проксі та рівнів закупки / продажу...', 0.68);

    final List<FundamentalCoinAnalysis> analyzedCoins = [];
    for (final meta in _coreUniverse) {
      final bars = barsBySymbol[meta.symbol];
      if (bars == null || bars.length < 60) continue;

      final ticker = liveTickers[meta.symbol];
      final livePrice = (ticker != null && ticker.price > 0) ? ticker.price : bars.closes.last;
      final chg24h = ticker?.chg24h ?? _returnOverDays(bars.closes, 1);

      final coinAnalysis = _evaluateCoreCoin(
        meta: meta,
        bars: bars,
        currentPrice: livePrice,
        chg24h: chg24h,
        btcRet30: btcRet30,
        btcRet90: btcRet90,
      );
      analyzedCoins.add(coinAnalysis);
    }

    // Сортуємо: BTC, ETH, SOL завжди зверху як тріада бази, далі — за індексом привабливості закупки (accumulationScore)
    const priorityOrder = {'BTC': 0, 'ETH': 1, 'SOL': 2, 'BNB': 3};
    analyzedCoins.sort((a, b) {
      final pa = priorityOrder[a.symbol] ?? 99;
      final pb = priorityOrder[b.symbol] ?? 99;
      if (pa != pb) return pa.compareTo(pb);
      return b.accumulationScore.compareTo(a.accumulationScore);
    });

    // 3. Формування макро-звіту циклу на основі BTC, ETH/BTC та SOL/BTC
    final btcCoin = analyzedCoins.firstWhere(
      (c) => c.symbol == 'BTC',
      orElse: () => analyzedCoins.first,
    );
    final ethCoin = analyzedCoins.where((c) => c.symbol == 'ETH').firstOrNull;
    final solCoin = analyzedCoins.where((c) => c.symbol == 'SOL').firstOrNull;

    final ethBtcRatio = (ethCoin != null && btcCoin.currentPrice > 0)
        ? ethCoin.currentPrice / btcCoin.currentPrice
        : 0.0;
    final solBtcRatio = (solCoin != null && btcCoin.currentPrice > 0)
        ? solCoin.currentPrice / btcCoin.currentPrice
        : 0.0;

    final ethBtcStatus = _describeCrossRatio('ETH', ethCoin?.rsVsBtc30d ?? 0, ethCoin?.rsVsBtc90d ?? 0);
    final solBtcStatus = _describeCrossRatio('SOL', solCoin?.rsVsBtc30d ?? 0, solCoin?.rsVsBtc90d ?? 0);

    final macroMeta = _buildMacroAllocationAndSummary(
      btc: btcCoin,
      eth: ethCoin,
      sol: solCoin,
      allCoins: analyzedCoins,
    );

    final baseReport = FundamentalAnalysisReport(
      analyzedAt: DateTime.now(),
      marketCycleLabel: macroMeta.cycleLabel,
      btcCyclePhase: btcCoin.cyclePhase,
      btcMayerMultiple: btcCoin.mayerMultiple,
      btcMvrvProxy: btcCoin.mvrvProxy,
      ethBtcRatio: ethBtcRatio,
      ethBtcStatus: ethBtcStatus,
      solBtcRatio: solBtcRatio,
      solBtcStatus: solBtcStatus,
      recommendedCoreAllocationPct: macroMeta.coreAllocPct,
      recommendedCashPct: macroMeta.cashPct,
      macroStrategySummary: macroMeta.summary,
      coins: analyzedCoins,
    );

    onProgress?.call('Етап 4/4: Формування інституційного макро-висновку AI...', 0.90);
    final enriched = await groqService.enrichFundamentalReport(baseReport);
    onProgress?.call('Готово!', 1.0);
    return enriched;
  }

  FundamentalCoinAnalysis _evaluateCoreCoin({
    required _CoreL1Meta meta,
    required _DailyBars bars,
    required double currentPrice,
    required double chg24h,
    required double btcRet30,
    required double btcRet90,
  }) {
    final closes = bars.closes;
    final highs = bars.highs;
    final lows = bars.lows;
    final n = closes.length;

    final chg30d = _returnOverDays(closes, 30);
    final chg90d = _returnOverDays(closes, 90);
    final chg365d = _returnOverDays(closes, math.min(n - 1, 360));

    // 1. Середні ковзні (EMA20, EMA50, EMA200, SMA200)
    final ema20 = _ema(closes, 20);
    final ema50 = _ema(closes, 50);
    final ema200 = _ema(closes, math.min(200, n));
    final sma200 = _sma(closes, math.min(200, n));

    // 2. Річний діапазон (365D ATH / ATL)
    double ath365 = currentPrice;
    double atl365 = currentPrice;
    for (int i = 0; i < n; i++) {
      if (highs[i] > ath365) ath365 = highs[i];
      if (lows[i] > 0 && lows[i] < atl365) atl365 = lows[i];
    }
    final dropFromAthPct = ath365 > 0 ? ((ath365 - currentPrice) / ath365) * 100.0 : 0.0;
    final rangeSpan = ath365 - atl365;
    final rangePositionPct = rangeSpan > 0
        ? (((currentPrice - atl365) / rangeSpan) * 100.0).clamp(0.0, 100.0)
        : 50.0;

    // 3. 365-денна об'ємно-зважена ціна (VWAP 365D = Realized Price Proxy)
    double sumTypVol = 0.0;
    double sumVol = 0.0;
    for (int i = 0; i < n; i++) {
      final typ = (highs[i] + lows[i] + closes[i]) / 3.0;
      final v = bars.baseVolumes[i];
      if (v > 0 && typ > 0) {
        sumTypVol += typ * v;
        sumVol += v;
      }
    }
    final vwap365 = sumVol > 0 ? (sumTypVol / sumVol) : sma200;

    // 4. 365-денний Volume Profile Point of Control (POC — 24 цінових рівні)
    final poc365 = _calculateVolumeProfilePoc(
      highs: highs,
      lows: lows,
      closes: closes,
      quoteVolumes: bars.quoteVolumes,
      minPrice: atl365,
      maxPrice: ath365,
      fallback: vwap365,
    );

    // 5. Мультиплікатор Майєра та MVRV-проксі
    final mayerMultiple = sma200 > 0 ? (currentPrice / sma200) : 1.0;
    final mvrvProxy = vwap365 > 0 ? (currentPrice / vwap365) : 1.0;

    // 6. Денний RSI (14D) та Тижневий RSI (14W на агрегованих 7-денних свічках)
    final rsi14d = _wilderRsi(closes, 14);
    final weeklyCloses = _buildWeeklyCloses(closes);
    final rsi14w = weeklyCloses.length >= 15
        ? _wilderRsi(weeklyCloses, 14)
        : _wilderRsi(closes, math.min(70, n - 1));

    // 7. Волатильність ATR (14D)
    final atr14 = _wilderAtr(highs, lows, closes, 14);
    final atrPct = currentPrice > 0 ? (atr14 / currentPrice) * 100.0 : 3.0;
    final atrFrac = (atrPct / 100.0).clamp(0.015, 0.12);

    // 8. Відносна сила до BTC та потік ордерів (Order Flow)
    final rsVsBtc30d = meta.symbol == 'BTC' ? 0.0 : (chg30d - btcRet30);
    final rsVsBtc90d = meta.symbol == 'BTC' ? 0.0 : (chg90d - btcRet90);

    final takerBuyRatio7d = _takerRatioDays(bars, 7);
    final takerBuyRatio60d = _takerRatioDays(bars, 60);
    final takerDeltaPp = takerBuyRatio7d - takerBuyRatio60d;
    final upDownVolRatio = _upDownVolumeRatio(bars, 30);

    // ------------------------------------------------------------------
    // 9. КВАНТОВА МОДЕЛЬ ОЦІНКИ: ЗАКУПКА (Accumulation) vs ПРОДАЖ (Distribution)
    // ------------------------------------------------------------------

    // Фактор 1 (30%): MVRV-проксі (відношення ціни до 365D VWAP собівартості ринку)
    // Якщо ціна <= 0.80 від VWAP365 -> 100 балів (глибока недооцінка); 1.0 -> 72 бали; >= 1.75 -> 5 балів
    final double scoreMvrv = _mapLinear(mvrvProxy, 1.75, 0.78, 5.0, 100.0);

    // Фактор 2 (25%): Mayer Multiple (відношення ціни до SMA200)
    // <= 0.80 -> 98 балів; 1.00 -> 75 балів; >= 1.85 -> 5 балів
    final double scoreMayer = _mapLinear(mayerMultiple, 1.85, 0.78, 5.0, 98.0);

    // Фактор 3 (20%): Мультитаймфреймовий RSI (55% Денний + 45% Тижневий)
    final double blendedRsi = 0.55 * rsi14d + 0.45 * rsi14w;
    final double scoreRsi = _mapLinear(blendedRsi, 74.0, 30.0, 6.0, 98.0);

    // Фактор 4 (15%): Дисконт від 365D максимуму та положення в річному коридорі
    final double scoreRange = _mapLinear(rangePositionPct, 95.0, 12.0, 10.0, 96.0);

    // Фактор 5 (10%): Інституційний потік ордерів (Taker Buy Delta + Up/Down Volume)
    final double flowRaw = 50.0 + (takerDeltaPp * 6.5) + ((upDownVolRatio - 1.0) * 28.0);
    final double scoreFlow = flowRaw.clamp(10.0, 95.0);

    final int accumulationScore = (0.30 * scoreMvrv +
            0.25 * scoreMayer +
            0.20 * scoreRsi +
            0.15 * scoreRange +
            0.10 * scoreFlow)
        .round()
        .clamp(5, 99);

    // Індекс перегріву / тиску на продаж (0..100)
    final double overheatMayer = _mapLinear(mayerMultiple, 1.05, 1.95, 0.0, 100.0);
    final double overhatMvrv = _mapLinear(mvrvProxy, 1.05, 1.85, 0.0, 100.0);
    final double overheatRsi = _mapLinear(blendedRsi, 52.0, 76.0, 0.0, 100.0);
    final double overheatRange = _mapLinear(rangePositionPct, 65.0, 98.0, 0.0, 100.0);

    final int sellPressureScore = (0.32 * overheatMayer +
            0.28 * overhatMvrv +
            0.25 * overheatRsi +
            0.15 * overheatRange)
        .round()
        .clamp(2, 99);

    // Визначення фази циклу та вердикту
    final String cyclePhase;
    final String actionTitleUk;
    final String recommendedActionShort;

    if (sellPressureScore >= 76 || (mayerMultiple >= 1.80 && rsi14d >= 70)) {
      cyclePhase = FundamentalCyclePhase.euphoriaSell;
      actionTitleUk = '🔴 ПРОДАЖ / РОЗПОДІЛ (Пік Циклу)';
      recommendedActionShort = 'Зупинити покупки · Фіксувати 50–70% прибутку каскадом';
    } else if (sellPressureScore >= 56 || (mayerMultiple >= 1.42 && rsi14d >= 64)) {
      cyclePhase = FundamentalCyclePhase.overheatedTakeProfit;
      actionTitleUk = '🟠 ЧАСТКОВА ФІКСАЦІЯ (Перегрів)';
      recommendedActionShort = 'Не купувати по ринку · Фіксувати 25–35% на TP1/TP2';
    } else if (accumulationScore >= 74 || (mvrvProxy <= 0.94 && rsi14d <= 44)) {
      cyclePhase = FundamentalCyclePhase.deepValue;
      actionTitleUk = '🟢 АГРЕСИВНА ЗАКУПКА (Недооцінка)';
      recommendedActionShort = 'Вигідна точка входу: 40% зараз + 60% лімітками нижче';
    } else if (accumulationScore >= 57) {
      cyclePhase = FundamentalCyclePhase.dcaAccumulation;
      actionTitleUk = '🔵 ПЛАНОВА ЗАКУПКА (Зона Smart DCA)';
      recommendedActionShort = 'Набирати позицію частинами (30% зараз / 40% база / 30% дно)';
    } else {
      cyclePhase = FundamentalCyclePhase.trendHold;
      actionTitleUk = '🟡 УТРИМАННЯ (HODL / Чекати відкату)';
      recommendedActionShort = 'Тримати базову позицію · Нові покупки лише лімітками на відкаті';
    }

    // ------------------------------------------------------------------
    // 10. РОЗРАХУНОК ТРИРІВНЕВОЇ ДРАБИНИ ЗАКУПКИ (КОЛИ І ПО СКІЛЬКИ КУПУВАТИ)
    // ------------------------------------------------------------------
    final support60d = _lowestLow(lows, 60);
    final support180d = _lowestLow(lows, math.min(180, n));

    double buyZone1Price;
    String buyZone1Label;
    int buyZone1SharePct;

    if (cyclePhase == FundamentalCyclePhase.deepValue ||
        cyclePhase == FundamentalCyclePhase.dcaAccumulation) {
      // Коли актив у зоні недооцінки або DCA — перший ордер виконується біля поточної ціни / EMA20
      buyZone1Price = math.min(currentPrice, math.max(currentPrice * 0.992, ema20));
      buyZone1Label = 'Ордер 1 (Вхід зараз / Локальна опора)';
      buyZone1SharePct = cyclePhase == FundamentalCyclePhase.deepValue ? 40 : 30;
    } else {
      // Коли актив у середині каналу або перегрітий — перший лімітний ордер ставиться на відкат до EMA50 / POC
      final candidate1 = math.min(ema50, currentPrice * (1.0 - 1.4 * atrFrac));
      buyZone1Price = candidate1.clamp(currentPrice * 0.78, currentPrice * 0.965);
      buyZone1Label = 'Ордер 1 (Лімітка на відкаті до EMA50)';
      buyZone1SharePct = 30;
    }

    // Другий ордер — інституційний рівень собівартості (VWAP 365D / SMA200 / POC)
    final structuralNodes = <double>[vwap365, poc365, sma200, ema200, support60d]
        .where((p) => p > 0 && p < buyZone1Price * 0.985)
        .toList();
    double buyZone2Price;
    String buyZone2Label;
    if (structuralNodes.isNotEmpty) {
      structuralNodes.sort((a, b) => b.compareTo(a)); // найближчий сильний вузол нижче Zone 1
      buyZone2Price = structuralNodes.first;
      if ((buyZone2Price - poc365).abs() / poc365 < 0.025) {
        buyZone2Label = 'Ордер 2 (Вузол об\'єму POC 365D)';
      } else if ((buyZone2Price - vwap365).abs() / vwap365 < 0.025) {
        buyZone2Label = 'Ордер 2 (Річна собівартість VWAP 365D)';
      } else {
        buyZone2Label = 'Ордер 2 (Інституційна база SMA200)';
      }
    } else {
      buyZone2Price = buyZone1Price * (1.0 - math.max(0.065, 2.0 * atrFrac));
      buyZone2Label = 'Ордер 2 (Глибока корекція -2×ATR)';
    }
    const int buyZone2SharePct = 40;

    // Третій ордер — екстремальний пролив / капітуляція (180D Low / 365D ATL)
    final deepNodes = <double>[support180d, atl365]
        .where((p) => p > 0 && p < buyZone2Price * 0.97 && p > buyZone2Price * 0.65)
        .toList();
    double buyZone3Price;
    String buyZone3Label;
    if (deepNodes.isNotEmpty) {
      deepNodes.sort((a, b) => b.compareTo(a));
      buyZone3Price = deepNodes.first;
      buyZone3Label = 'Ордер 3 (Дно капітуляції / Свінг-мінімум)';
    } else {
      buyZone3Price = buyZone2Price * (1.0 - math.max(0.085, 2.5 * atrFrac));
      buyZone3Label = 'Ордер 3 (Екстремальний пролив «Відро»)';
    }
    final int buyZone3SharePct = 100 - buyZone1SharePct - buyZone2SharePct;

    // ------------------------------------------------------------------
    // 11. РОЗРАХУНОК ТРИРІВНЕВОЇ ДРАБИНИ ПРОДАЖУ (КОЛИ І ПО СКІЛЬКИ ФІКСУВАТИ)
    // ------------------------------------------------------------------
    final high60d = _highestHigh(highs, 60);
    final high180d = _highestHigh(highs, math.min(180, n));

    // TP1 (25% обсягу): Локальний структурний опір або +3.5×ATR
    double tp1Price = math.max(high60d, currentPrice * (1.0 + math.max(0.11, 3.2 * atrFrac)));
    if (tp1Price < currentPrice * 1.08) {
      tp1Price = currentPrice * 1.12;
    }
    const String tp1Label = 'TP1 (Локальний свінг-опір · 25% обсягу)';
    const int tp1SharePct = 25;

    // TP2 (35% обсягу): Річний максимум (ATH 365D) або зона перегріву Mayer 1.65x
    double tp2Price = math.max(high180d, math.max(ath365, sma200 * 1.60));
    if (tp2Price <= tp1Price * 1.07) {
      tp2Price = tp1Price * (1.0 + math.max(0.14, 3.5 * atrFrac));
    }
    const String tp2Label = 'TP2 (Вершина 365D / Перегрів · 35% обсягу)';
    const int tp2SharePct = 35;

    // TP3 (40% обсягу або довгостроковий HODL): Ціль циклу (Mayer Multiple 2.1x / Fibo 1.382 від річного діапазону)
    final fiboExt = ath365 + 0.382 * (ath365 - atl365);
    double tp3Price = math.max(fiboExt, sma200 * 2.10);
    if (tp3Price <= tp2Price * 1.10) {
      tp3Price = tp2Price * 1.22;
    }
    const String tp3Label = 'TP3 (Ейфорія циклу Mayer 2.1x · 40% / HODL)';
    const int tp3SharePct = 40;

    // Рівень зламу макро-структури (Захисний стоп для середньострокового тренду)
    final invalidationStopPrice = math.min(
      buyZone3Price * 0.94,
      math.min(sma200 * 0.82, support180d * 0.96),
    );
    final invalidationRule =
        'Тижневе закриття свічки (1W) нижче \$${_fmtPrice(invalidationStopPrice)} ознаменує злам річної макро-структури. Для базових L1 монет не використовуйте короткі стопи (щоб маркет-мейкер не вибив позицію шпилькою) — працюйте каскадним добором від рівнів.';

    // ------------------------------------------------------------------
    // 12. ТЕКСТОВЕ ОБҐРУНТУВАННЯ ПРОФЕСІЙНОГО ТРЕЙДЕРА
    // ------------------------------------------------------------------
    final mayerState = mayerMultiple < 0.90
        ? 'глибока недооцінка відносно 200-денної середньої'
        : (mayerMultiple <= 1.25
            ? 'збалансована справедлива зона'
            : (mayerMultiple <= 1.60 ? 'активний бичачий імпульс' : 'сильний перегрів вище SMA200'));

    final mvrvState = mvrvProxy < 1.0
        ? 'нижче середньоринкової ціни покупок за рік (інституційна зона дисконту)'
        : 'вище річної об\'ємної собівартості VWAP (+${((mvrvProxy - 1.0) * 100).toStringAsFixed(1)}%)';

    final valuationSummary =
        'Мультиплікатор Майєра становить ${mayerMultiple.toStringAsFixed(2)}x ($mayerState), '
        'MVRV-проксі (Ціна / 365D VWAP): ${mvrvProxy.toStringAsFixed(2)}x ($mvrvState). '
        'Денний RSI: ${rsi14d.toStringAsFixed(1)}, Тижневий RSI (1W): ${rsi14w.toStringAsFixed(1)}. '
        'Найбільший проторгований об\'єм за 365 днів (POC) сконцентрований на рівні \$${_fmtPrice(poc365)}, '
        'а дисконт від річного піку становить -${dropFromAthPct.toStringAsFixed(1)}%.';

    final buyTriggerRule = isBuyPhase(cyclePhase)
        ? 'Актив знаходиться у вигідній зоні накопичення (Індекс закупки $accumulationScore/100). '
            'Рекомендовано відкрити $buyZone1SharePct% позиції біля \$${_fmtPrice(buyZone1Price)}, '
            'виставити лімітний ордер на $buyZone2SharePct% біля базової опори \$${_fmtPrice(buyZone2Price)} '
            'та залишити $buyZone3SharePct% резерву на випадок сквизу до \$${_fmtPrice(buyZone3Price)}.'
        : 'Поточна ціна знаходиться вище оптимальної зони ризик/прибуток для ринкової покупки. '
            'Не купуйте FOMO по ринку: виставте лімітні ордери на відкат до \$${_fmtPrice(buyZone1Price)} ($buyZone1SharePct%), '
            '\$${_fmtPrice(buyZone2Price)} ($buyZone2SharePct%) та \$${_fmtPrice(buyZone3Price)} ($buyZone3SharePct%).';

    final sellTriggerRule =
        'Фіксуйте прибуток частинами на опорах: 25% обсягу на TP1 (\$${_fmtPrice(tp1Price)}, +${((tp1Price - currentPrice) / currentPrice * 100).toStringAsFixed(1)}%), '
        '35% на TP2 біля річної вершини (\$${_fmtPrice(tp2Price)}, +${((tp2Price - currentPrice) / currentPrice * 100).toStringAsFixed(1)}%), '
        'а основне ядро (40%) тримайте до фази макро-ейфорії TP3 (\$${_fmtPrice(tp3Price)}) або при досягненні Тижневого RSI > 78 та Mayer Multiple > 2.0x.';

    return FundamentalCoinAnalysis(
      symbol: meta.symbol,
      name: meta.name,
      roleLabel: meta.roleLabel,
      currentPrice: currentPrice,
      chg24h: chg24h,
      chg30d: chg30d,
      chg90d: chg90d,
      chg365d: chg365d,
      sma200: sma200,
      ema50: ema50,
      ema200: ema200,
      vwap365: vwap365,
      poc365: poc365,
      ath365: ath365,
      atl365: atl365,
      dropFromAthPct: dropFromAthPct,
      rangePositionPct: rangePositionPct,
      mayerMultiple: mayerMultiple,
      mvrvProxy: mvrvProxy,
      rsi14d: rsi14d,
      rsi14w: rsi14w,
      atrPct: atrPct,
      rsVsBtc30d: rsVsBtc30d,
      rsVsBtc90d: rsVsBtc90d,
      takerBuyRatio7d: takerBuyRatio7d,
      takerDeltaPp: takerDeltaPp,
      upDownVolRatio: upDownVolRatio,
      cyclePhase: cyclePhase,
      actionTitleUk: actionTitleUk,
      recommendedActionShort: recommendedActionShort,
      accumulationScore: accumulationScore,
      sellPressureScore: sellPressureScore,
      buyZone1Price: buyZone1Price,
      buyZone1SharePct: buyZone1SharePct,
      buyZone1Label: buyZone1Label,
      buyZone2Price: buyZone2Price,
      buyZone2SharePct: buyZone2SharePct,
      buyZone2Label: buyZone2Label,
      buyZone3Price: buyZone3Price,
      buyZone3SharePct: buyZone3SharePct,
      buyZone3Label: buyZone3Label,
      tp1Price: tp1Price,
      tp1SharePct: tp1SharePct,
      tp1Label: tp1Label,
      tp2Price: tp2Price,
      tp2SharePct: tp2SharePct,
      tp2Label: tp2Label,
      tp3Price: tp3Price,
      tp3SharePct: tp3SharePct,
      tp3Label: tp3Label,
      invalidationStopPrice: invalidationStopPrice,
      invalidationRule: invalidationRule,
      valuationSummary: valuationSummary,
      buyTriggerRule: buyTriggerRule,
      sellTriggerRule: sellTriggerRule,
      aiCommentary:
          '${meta.name} (${meta.symbol}): індекс накопичення $accumulationScore/100, індекс перегріву $sellPressureScore/100. '
          'Ключовий рівень інституційної ліквідності POC: \$${_fmtPrice(poc365)}, собівартість 365D VWAP: \$${_fmtPrice(vwap365)}.',
    );
  }

  static bool isBuyPhase(String phase) =>
      phase == FundamentalCyclePhase.deepValue || phase == FundamentalCyclePhase.dcaAccumulation;

  static String _describeCrossRatio(String sym, double rs30, double rs90) {
    if (rs30 > 4.0 && rs90 > 0) {
      return '$sym випереджає BTC (+${rs30.toStringAsFixed(1)}% за 30Д) — перетік капіталу в L1';
    } else if (rs30 < -5.0 && rs90 < -8.0) {
      return '$sym у глибокому дисконті до BTC (${rs90.toStringAsFixed(1)}% за 90Д) — зона перепроданості крос-пари';
    }
    return 'Динаміка $sym/BTC збалансована (${rs30 >= 0 ? '+' : ''}${rs30.toStringAsFixed(1)}% за 30Д)';
  }

  static ({
    String cycleLabel,
    int coreAllocPct,
    int cashPct,
    String summary,
  }) _buildMacroAllocationAndSummary({
    required FundamentalCoinAnalysis btc,
    required FundamentalCoinAnalysis? eth,
    required FundamentalCoinAnalysis? sol,
    required List<FundamentalCoinAnalysis> allCoins,
  }) {
    final buyCount = allCoins.where((c) => c.isBuyRecommended).length;
    final sellCount = allCoins.where((c) => c.isSellRecommended).length;

    String cycleLabel;
    int coreAllocPct;
    int cashPct;

    if (btc.cyclePhase == FundamentalCyclePhase.deepValue || buyCount >= 6) {
      cycleLabel = '🟢 МАКРО-ФАЗА НАКОПИЧЕННЯ (Недооцінка Базових L1)';
      coreAllocPct = 75;
      cashPct = 25;
    } else if (btc.cyclePhase == FundamentalCyclePhase.dcaAccumulation || buyCount >= 3) {
      cycleLabel = '🔵 ФАЗА ПЛАНОВОГО НАБОРУ (Smart DCA Зона)';
      coreAllocPct = 65;
      cashPct = 35;
    } else if (btc.cyclePhase == FundamentalCyclePhase.euphoriaSell || sellCount >= 5) {
      cycleLabel = '🔴 ФАЗА РОЗПОДІЛУ ТА ЕЙФОРІЇ (Час фіксувати прибуток)';
      coreAllocPct = 35;
      cashPct = 65;
    } else if (btc.cyclePhase == FundamentalCyclePhase.overheatedTakeProfit || sellCount >= 3) {
      cycleLabel = '🟠 ФАЗА ЛОКАЛЬНОГО ПЕРЕГРІВУ (Часткова фіксація TP1/TP2)';
      coreAllocPct = 50;
      cashPct = 50;
    } else {
      cycleLabel = '🟡 ФАЗА РІВНОВАГИ ТА ТРЕНДУ (HODL + Лімітні ордери)';
      coreAllocPct = 60;
      cashPct = 40;
    }

    final bestBuys = allCoins
        .where((c) => c.isBuyRecommended)
        .map((c) => '${c.symbol} (${c.accumulationScore}/100)')
        .toList();
    final overheated = allCoins
        .where((c) => c.isSellRecommended)
        .map((c) => '${c.symbol} (перегрів ${c.sellPressureScore}/100)')
        .toList();

    final summaryParts = <String>[
      'Фундаментальний еталон BTC торгується з мультиплікатором Майєра ${btc.mayerMultiple.toStringAsFixed(2)}x (SMA200: \$${_fmtPrice(btc.sma200)}) та MVRV-проксі ${btc.mvrvProxy.toStringAsFixed(2)}x відносно річної собівартості ринку (\$${_fmtPrice(btc.vwap365)}).',
      if (bestBuys.isNotEmpty)
        'Найкращі фундаментальні монети для закупки зараз: ${bestBuys.join(', ')}.'
      else
        'Наразі більшість L1 активів торгуються вище зон дисконту — пріоритет на утриманні та виставленні лімітних ордерів на рівнях Ордер 1 та Ордер 2.',
      if (overheated.isNotEmpty)
        'Сигнал на фіксацію прибутку (перегрів): ${overheated.join(', ')}.',
      'Рекомендована макро-структура капіталу: $coreAllocPct% у базових L1 активах (BTC/ETH/SOL) та $cashPct% у стейблкоїнах (USDT/USDC) для відкупу лімітних рівнів.',
    ];

    return (
      cycleLabel: cycleLabel,
      coreAllocPct: coreAllocPct,
      cashPct: cashPct,
      summary: summaryParts.join(' '),
    );
  }

  Future<_DailyBars?> _fetch365DailyBars(String pair) async {
    try {
      final uri = Uri.parse('$_baseUrl/api/v3/klines?symbol=$pair&interval=1d&limit=$_klineLimit');
      final resp = await http.get(uri).timeout(const Duration(seconds: 9));
      if (resp.statusCode != 200) return null;

      final raw = jsonDecode(resp.body) as List<dynamic>;
      if (raw.length < 60) return null;

      final nowMs = DateTime.now().millisecondsSinceEpoch;
      final lastCloseTime = (raw.last[6] as num).toInt();
      final closed = lastCloseTime > nowMs ? raw.sublist(0, raw.length - 1) : raw;

      final bars = _DailyBars();
      for (final k in closed) {
        final o = double.tryParse(k[1].toString()) ?? 0.0;
        final h = double.tryParse(k[2].toString()) ?? 0.0;
        final l = double.tryParse(k[3].toString()) ?? 0.0;
        final c = double.tryParse(k[4].toString()) ?? 0.0;
        final v = double.tryParse(k[5].toString()) ?? 0.0;
        final qv = double.tryParse(k[7].toString()) ?? 0.0;
        final tbq = double.tryParse(k[10].toString()) ?? 0.0;
        if (c <= 0) continue;

        bars.opens.add(o);
        bars.highs.add(h);
        bars.lows.add(l);
        bars.closes.add(c);
        bars.baseVolumes.add(v);
        bars.quoteVolumes.add(qv);
        bars.takerBuyQuote.add(tbq);
      }
      return bars;
    } catch (_) {
      return null;
    }
  }

  static double _calculateVolumeProfilePoc({
    required List<double> highs,
    required List<double> lows,
    required List<double> closes,
    required List<double> quoteVolumes,
    required double minPrice,
    required double maxPrice,
    required double fallback,
  }) {
    const int binsCount = 24;
    final span = maxPrice - minPrice;
    if (span <= 0 || closes.isEmpty) return fallback;

    final binSize = span / binsCount;
    final binVolumes = List<double>.filled(binsCount, 0.0);

    for (int i = 0; i < closes.length; i++) {
      final typ = (highs[i] + lows[i] + closes[i]) / 3.0;
      int idx = ((typ - minPrice) / binSize).floor();
      if (idx < 0) idx = 0;
      if (idx >= binsCount) idx = binsCount - 1;
      binVolumes[idx] += quoteVolumes[i];
    }

    int maxIdx = 0;
    double maxVol = -1.0;
    for (int b = 0; b < binsCount; b++) {
      if (binVolumes[b] > maxVol) {
        maxVol = binVolumes[b];
        maxIdx = b;
      }
    }
    return minPrice + (maxIdx + 0.5) * binSize;
  }

  static List<double> _buildWeeklyCloses(List<double> dailyCloses) {
    final List<double> weekly = [];
    int i = dailyCloses.length - 1;
    while (i >= 0) {
      weekly.insert(0, dailyCloses[i]);
      i -= 7;
    }
    return weekly;
  }

  static double _returnOverDays(List<double> closes, int days) {
    if (closes.length <= days || days <= 0) return 0.0;
    final prev = closes[closes.length - 1 - days];
    final curr = closes.last;
    return prev > 0 ? ((curr - prev) / prev) * 100.0 : 0.0;
  }

  static double _sma(List<double> values, int period) {
    if (values.isEmpty) return 0.0;
    final count = math.min(period, values.length);
    double sum = 0.0;
    for (int i = values.length - count; i < values.length; i++) {
      sum += values[i];
    }
    return sum / count;
  }

  static double _ema(List<double> values, int period) {
    if (values.isEmpty) return 0.0;
    if (values.length < period) return _sma(values, values.length);
    final k = 2.0 / (period + 1);
    double ema = 0.0;
    for (int i = 0; i < period; i++) {
      ema += values[i];
    }
    ema /= period;
    for (int i = period; i < values.length; i++) {
      ema = values[i] * k + ema * (1.0 - k);
    }
    return ema;
  }

  static double _wilderRsi(List<double> closes, int period) {
    if (closes.length <= period) return 50.0;
    double gains = 0.0;
    double losses = 0.0;
    for (int i = 1; i <= period; i++) {
      final diff = closes[i] - closes[i - 1];
      if (diff >= 0) {
        gains += diff;
      } else {
        losses -= diff;
      }
    }
    double avgGain = gains / period;
    double avgLoss = losses / period;
    for (int i = period + 1; i < closes.length; i++) {
      final diff = closes[i] - closes[i - 1];
      final gain = diff > 0 ? diff : 0.0;
      final loss = diff < 0 ? -diff : 0.0;
      avgGain = (avgGain * (period - 1) + gain) / period;
      avgLoss = (avgLoss * (period - 1) + loss) / period;
    }
    if (avgLoss == 0) return 100.0;
    final rs = avgGain / avgLoss;
    return 100.0 - (100.0 / (1.0 + rs));
  }

  static double _wilderAtr(
    List<double> highs,
    List<double> lows,
    List<double> closes,
    int period,
  ) {
    if (closes.length <= period) return 0.0;
    final List<double> trs = [];
    for (int i = 1; i < closes.length; i++) {
      final hl = highs[i] - lows[i];
      final hc = (highs[i] - closes[i - 1]).abs();
      final lc = (lows[i] - closes[i - 1]).abs();
      trs.add(math.max(hl, math.max(hc, lc)));
    }
    if (trs.isEmpty) return 0.0;
    double atr = 0.0;
    final initLen = math.min(period, trs.length);
    for (int i = 0; i < initLen; i++) {
      atr += trs[i];
    }
    atr /= initLen;
    for (int i = initLen; i < trs.length; i++) {
      atr = (atr * (period - 1) + trs[i]) / period;
    }
    return atr;
  }

  static double _takerRatioDays(_DailyBars bars, int days) {
    final n = bars.length;
    final start = math.max(0, n - days);
    double totalQ = 0.0;
    double takerQ = 0.0;
    for (int i = start; i < n; i++) {
      totalQ += bars.quoteVolumes[i];
      takerQ += bars.takerBuyQuote[i];
    }
    return totalQ > 0 ? (takerQ / totalQ) * 100.0 : 50.0;
  }

  static double _upDownVolumeRatio(_DailyBars bars, int days) {
    final n = bars.length;
    final start = math.max(1, n - days);
    double upVol = 0.0;
    double downVol = 0.0;
    for (int i = start; i < n; i++) {
      if (bars.closes[i] >= bars.closes[i - 1]) {
        upVol += bars.quoteVolumes[i];
      } else {
        downVol += bars.quoteVolumes[i];
      }
    }
    if (downVol <= 0) return 1.5;
    return (upVol / downVol).clamp(0.3, 3.0);
  }

  static double _lowestLow(List<double> lows, int days) {
    if (lows.isEmpty) return 0.0;
    final start = math.max(0, lows.length - days);
    double m = lows[start];
    for (int i = start + 1; i < lows.length; i++) {
      if (lows[i] > 0 && lows[i] < m) m = lows[i];
    }
    return m;
  }

  static double _highestHigh(List<double> highs, int days) {
    if (highs.isEmpty) return 0.0;
    final start = math.max(0, highs.length - days);
    double m = highs[start];
    for (int i = start + 1; i < highs.length; i++) {
      if (highs[i] > m) m = highs[i];
    }
    return m;
  }

  static double _mapLinear(double x, double inStart, double inEnd, double outStart, double outEnd) {
    if ((inEnd - inStart).abs() < 1e-9) return outStart;
    final t = ((x - inStart) / (inEnd - inStart)).clamp(0.0, 1.0);
    return outStart + t * (outEnd - outStart);
  }

  static String _fmtPrice(double val) {
    if (val <= 0) return '0.0000';
    if (val >= 0.0001) return val.toStringAsFixed(4);
    return val.toStringAsFixed(6);
  }
}
