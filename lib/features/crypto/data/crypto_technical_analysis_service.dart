import 'dart:convert';
import 'dart:math' as math;
import 'package:http/http.dart' as http;
import 'models/crypto_models.dart';

class _CachedTechnicalData {
  final DateTime cachedAt;
  final double bollingerUpper;
  final double bollingerMiddle;
  final double bollingerLower;
  final double ema50;
  final double swingHigh;
  final double swingLow;
  final double recentPeak20d;
  final double min5dLow;
  final double globalPeak100d;
  final double globalBottom100d;
  final double rsi;
  final double rsiSlope;
  final String rsiStatus;
  final String rsiDivergence;
  final double atr;
  final double atrPct;
  final double volumeRatio;
  final String volumeStatus;
  final double takerBuyRatio;
  final double downUpVolRatio;
  final double upperWickRatio;

  _CachedTechnicalData({
    required this.cachedAt,
    required this.bollingerUpper,
    required this.bollingerMiddle,
    required this.bollingerLower,
    required this.ema50,
    required this.swingHigh,
    required this.swingLow,
    required this.recentPeak20d,
    required this.min5dLow,
    required this.globalPeak100d,
    required this.globalBottom100d,
    required this.rsi,
    required this.rsiSlope,
    required this.rsiStatus,
    required this.rsiDivergence,
    required this.atr,
    required this.atrPct,
    required this.volumeRatio,
    required this.volumeStatus,
    required this.takerBuyRatio,
    required this.downUpVolRatio,
    required this.upperWickRatio,
  });

  bool get isExpired => DateTime.now().difference(cachedAt).inMinutes > 15;
}

class CryptoTechnicalAnalysisService {
  final Map<String, _CachedTechnicalData> _cache = {};
  String _cachedBtcRegime = '⚪ BTC ринок аналізується...';
  DateTime? _lastBtcCheck;

  static const Set<String> _stablecoins = {
    'USDT',
    'USDC',
    'FDUSD',
    'DAI',
    'TUSD',
    'USDE',
    'BUSD',
    'PYUSD',
    'USDD',
    'GUSD',
  };

  /// Отримує актуальний статус ринку BTC (Trend Filter за 50 SMA)
  Future<String> _getBtcMarketRegime() async {
    final now = DateTime.now();
    if (_lastBtcCheck != null && now.difference(_lastBtcCheck!).inMinutes < 30) {
      return _cachedBtcRegime;
    }

    try {
      final url = Uri.parse('https://api.binance.com/api/v3/klines?symbol=BTCUSDT&interval=1d&limit=55');
      final resp = await http.get(url).timeout(const Duration(seconds: 4));
      if (resp.statusCode == 200) {
        final klines = json.decode(resp.body) as List<dynamic>;
        if (klines.length >= 50) {
          double sum = 0.0;
          for (int i = klines.length - 50; i < klines.length; i++) {
            sum += double.tryParse(klines[i][4].toString()) ?? 0.0;
          }
          final sma50 = sum / 50.0;
          final currentBtc = double.tryParse(klines.last[4].toString()) ?? 0.0;

          if (currentBtc >= sma50) {
            _cachedBtcRegime = '🟢 Бичачий тренд BTC (Вище SMA 50 — сприятливий фон для альтів)';
          } else {
            _cachedBtcRegime = '⚠️ Ведмежа/Корекційна фаза BTC (Нижче SMA 50 — обережно з покупками)';
          }
          _lastBtcCheck = now;
        }
      }
    } catch (_) {}

    return _cachedBtcRegime;
  }

  /// Аналізує монету за 100-денними свічками (1D):
  /// Смуги Боллінджера, EMA50, RSI (14), ATR (14), Об'єм, Taker Order Flow,
  /// Ймовірність розвороту з піку, Ймовірність падіння до Stop-Loss та DCA-сітку.
  Future<TpSlInfo> analyzeSymbol({
    required String symbol,
    required double entryPrice,
    required double currentPrice,
  }) async {
    final sym = symbol.toUpperCase();
    final effectiveEntry = entryPrice > 0 ? entryPrice : (currentPrice > 0 ? currentPrice : 1.0);
    final curPrice = currentPrice > 0 ? currentPrice : effectiveEntry;
    final btcRegime = await _getBtcMarketRegime();

    // Стейблкоїни не потребують волатильного аналізу
    if (_stablecoins.contains(sym)) {
      return TpSlInfo(
        entryPrice: 1.0,
        tp1: 1.0,
        tp1Pct: 100,
        distToTp1Pct: 0.0,
        tp1Label: 'Стейблкоїн (\$1.00)',
        tp2: 1.0,
        tp2Pct: 0,
        distToTp2Pct: 0.0,
        tp2Label: 'Фіксація не потрібна',
        tp3: 1.0,
        tp3Pct: 0,
        distToTp3Pct: 0.0,
        tp3Label: 'Рівень \$1.00',
        stopLoss: 0.98,
        distToSlPct: 2.0,
        stopReason: 'Захист від депегу стейблкоїна (-2%)',
        bollingerUpper: 1.001,
        bollingerMiddle: 1.0,
        bollingerLower: 0.999,
        swingHigh: 1.005,
        swingLow: 0.995,
        globalPeak100d: 1.01,
        globalBottom100d: 0.99,
        positionInChannel: 'Нейтральна (Стейблкоїн \$1.00)',
        accumulatePrice: 0.998,
        distToAccumulatePct: 0.2,
        rsi: 50.0,
        rsiStatus: 'Стейблкоїн \$1.00',
        rsiDivergence: 'Відсутня',
        atr: 0.005,
        atrPct: 0.5,
        volumeRatio: 1.0,
        volumeStatus: 'Стабільна ліквідність',
        riskRewardRatio: 5.0,
        riskRewardGrade: 'GOOD',
        riskRewardLabel: '🟢 Стейблкоїн',
        btcMarketRegime: btcRegime,
        dcaLadder: const [],
        exitSignalCode: 'STABLECOIN',
        exitTitleUk: '💵 РЕЗЕРВ ЛІКВІДНОСТІ (Стейблкоїн \$1.00)',
        exitActionUk: 'Кеш-подушка для відкупу просідань за сигналами AI-Радара або лімітної DCA-сітки.',
        recommendedSellPct: 0,
        peakExhaustionScore: 0,
        slProbabilityPct: 1,
        slRiskFactorsUk: 'Стейблкоїн прив\'язаний до \$1.00 USD',
        recentPeak20d: 1.0,
        pullbackFromPeakPct: 0.0,
        trailingStopPrice: 0.995,
        breakevenPrice: 1.0,
        earlyExitPrice: 0.99,
        takerBuyRatio: 50.0,
        ema50: 1.0,
        isTp1Reached: false,
      );
    }

    _CachedTechnicalData? techData = _cache[sym];

    if (techData == null || techData.isExpired) {
      techData = await _fetchAndCalculateIndicators(sym, curPrice);
      if (techData != null) {
        _cache[sym] = techData;
      }
    }

    if (techData == null) {
      return _generateFallbackTpSl(effectiveEntry, curPrice, btcRegime);
    }

    return _buildTpSlFromIndicators(
      entryPrice: effectiveEntry,
      currentPrice: curPrice,
      tech: techData,
      btcRegime: btcRegime,
    );
  }

  /// Швидке синхронне перерахування динамічних сигналів виходу та ризику Stop-Loss
  /// при надходженні нових WebSocket тіків у реальному часі.
  TpSlInfo recalculateWithLivePrice(TpSlInfo oldTpSl, double newPrice) {
    if (newPrice <= 0 || oldTpSl.exitSignalCode == 'STABLECOIN') {
      return oldTpSl;
    }

    final effectiveEntry = oldTpSl.entryPrice > 0 ? oldTpSl.entryPrice : newPrice;
    final distTp1 = (((oldTpSl.tp1 - newPrice) / newPrice) * 100);
    final distTp2 = (((oldTpSl.tp2 - newPrice) / newPrice) * 100);
    final distTp3 = (((oldTpSl.tp3 - newPrice) / newPrice) * 100);
    final distSl = (((newPrice - oldTpSl.stopLoss) / newPrice) * 100);
    final distAcc = (((newPrice - oldTpSl.accumulatePrice) / newPrice) * 100);

    String pos = oldTpSl.positionInChannel;
    if (oldTpSl.bollingerUpper > 0 && oldTpSl.bollingerLower > 0) {
      if (newPrice >= oldTpSl.bollingerUpper) {
        pos = '🔥 Зона перекупленості (Вище верхнього Боллінджера)';
      } else if (newPrice <= oldTpSl.bollingerLower) {
        pos = '💎 Зона накопичення / Дно (Біля нижнього Боллінджера)';
      } else if (newPrice > oldTpSl.bollingerMiddle) {
        pos = '📈 Бичача зона (Вище середньої лінії SMA 20)';
      } else {
        pos = '📉 Ведмежа зона (Нижче середньої лінії SMA 20)';
      }
    }

    final recentPeak = math.max(oldTpSl.recentPeak20d, newPrice);
    final atr = oldTpSl.atr > 0 ? oldTpSl.atr : (newPrice * 0.04);

    final exitEval = _evaluateExitAndStopProbability(
      entryPrice: effectiveEntry,
      currentPrice: newPrice,
      tp1: oldTpSl.tp1,
      tp2: oldTpSl.tp2,
      stopLoss: oldTpSl.stopLoss,
      bollingerUpper: oldTpSl.bollingerUpper,
      bollingerMiddle: oldTpSl.bollingerMiddle,
      bollingerLower: oldTpSl.bollingerLower,
      ema50: oldTpSl.ema50 > 0 ? oldTpSl.ema50 : oldTpSl.bollingerMiddle,
      recentPeak20d: recentPeak,
      min5dLow: oldTpSl.earlyExitPrice > 0 ? (oldTpSl.earlyExitPrice + 0.35 * atr) : (newPrice * 0.96),
      rsi: oldTpSl.rsi,
      rsiSlope: 0.0,
      rsiDivergence: oldTpSl.rsiDivergence,
      atr: atr,
      takerBuyRatio: oldTpSl.takerBuyRatio,
      downUpVolRatio: 1.0,
      upperWickRatio: 0.25,
      btcRegime: oldTpSl.btcMarketRegime,
    );

    final String updatedTp1Label = exitEval.isTp1Reached
        ? '✅ Шар 1 ДОСЯГНУТО (Фіксувати 30% зараз!)'
        : 'Шар 1: Верхній Боллінджер';

    return TpSlInfo(
      entryPrice: oldTpSl.entryPrice,
      tp1: oldTpSl.tp1,
      tp1Pct: oldTpSl.tp1Pct,
      distToTp1Pct: double.parse(distTp1.toStringAsFixed(1)),
      tp1Label: updatedTp1Label,
      tp2: oldTpSl.tp2,
      tp2Pct: oldTpSl.tp2Pct,
      distToTp2Pct: double.parse(distTp2.toStringAsFixed(1)),
      tp2Label: oldTpSl.tp2Label,
      tp3: oldTpSl.tp3,
      tp3Pct: oldTpSl.tp3Pct,
      distToTp3Pct: double.parse(distTp3.toStringAsFixed(1)),
      tp3Label: oldTpSl.tp3Label,
      stopLoss: oldTpSl.stopLoss,
      distToSlPct: double.parse(distSl.toStringAsFixed(1)),
      stopReason: oldTpSl.stopReason,
      bollingerUpper: oldTpSl.bollingerUpper,
      bollingerMiddle: oldTpSl.bollingerMiddle,
      bollingerLower: oldTpSl.bollingerLower,
      swingHigh: oldTpSl.swingHigh,
      swingLow: oldTpSl.swingLow,
      globalPeak100d: oldTpSl.globalPeak100d,
      globalBottom100d: oldTpSl.globalBottom100d,
      positionInChannel: pos,
      accumulatePrice: oldTpSl.accumulatePrice,
      distToAccumulatePct: double.parse(distAcc.toStringAsFixed(1)),
      rsi: oldTpSl.rsi,
      rsiStatus: oldTpSl.rsiStatus,
      rsiDivergence: oldTpSl.rsiDivergence,
      atr: oldTpSl.atr,
      atrPct: oldTpSl.atrPct,
      volumeRatio: oldTpSl.volumeRatio,
      volumeStatus: oldTpSl.volumeStatus,
      riskRewardRatio: oldTpSl.riskRewardRatio,
      riskRewardGrade: oldTpSl.riskRewardGrade,
      riskRewardLabel: oldTpSl.riskRewardLabel,
      btcMarketRegime: oldTpSl.btcMarketRegime,
      dcaLadder: oldTpSl.dcaLadder,
      exitSignalCode: exitEval.exitSignalCode,
      exitTitleUk: exitEval.exitTitleUk,
      exitActionUk: exitEval.exitActionUk,
      recommendedSellPct: exitEval.recommendedSellPct,
      peakExhaustionScore: exitEval.peakExhaustionScore,
      slProbabilityPct: exitEval.slProbabilityPct,
      slRiskFactorsUk: exitEval.slRiskFactorsUk,
      recentPeak20d: recentPeak,
      pullbackFromPeakPct: exitEval.pullbackFromPeakPct,
      trailingStopPrice: exitEval.trailingStopPrice,
      breakevenPrice: exitEval.breakevenPrice,
      earlyExitPrice: exitEval.earlyExitPrice,
      takerBuyRatio: oldTpSl.takerBuyRatio,
      ema50: oldTpSl.ema50,
      isTp1Reached: exitEval.isTp1Reached,
    );
  }

  Future<_CachedTechnicalData?> _fetchAndCalculateIndicators(String symbol, double currentPrice) async {
    try {
      final url = Uri.parse('https://api.binance.com/api/v3/klines?symbol=${symbol}USDT&interval=1d&limit=100');
      final resp = await http.get(url).timeout(const Duration(seconds: 6));

      if (resp.statusCode != 200) return null;

      final klines = json.decode(resp.body) as List<dynamic>;
      if (klines.length < 20) return null;

      final List<double> opens = [];
      final List<double> highs = [];
      final List<double> lows = [];
      final List<double> closes = [];
      final List<double> volumes = [];
      final List<double> takerBuyVolumes = [];

      for (final k in klines) {
        if (k is List && k.length >= 11) {
          final o = double.tryParse(k[1].toString()) ?? 0.0;
          final h = double.tryParse(k[2].toString()) ?? 0.0;
          final l = double.tryParse(k[3].toString()) ?? 0.0;
          final c = double.tryParse(k[4].toString()) ?? 0.0;
          final quoteVol = double.tryParse(k[7].toString()) ?? 0.0;
          final baseVol = double.tryParse(k[5].toString()) ?? 0.0;
          final takerQuoteVol = double.tryParse(k[10].toString()) ?? 0.0;
          final takerBaseVol = double.tryParse(k[9].toString()) ?? 0.0;

          if (h > 0 && l > 0 && c > 0) {
            opens.add(o > 0 ? o : c);
            highs.add(h);
            lows.add(l);
            closes.add(c);
            volumes.add(quoteVol > 0 ? quoteVol : baseVol);
            takerBuyVolumes.add(quoteVol > 0 ? takerQuoteVol : takerBaseVol);
          }
        }
      }

      if (closes.length < 20) return null;

      // 1. СМУГИ БОЛЛІНДЖЕРА (SMA 20, 2 StdDev) та EMA 50
      final last20 = closes.sublist(closes.length - 20);
      final double sma20 = last20.reduce((a, b) => a + b) / 20.0;

      double varianceSum = 0.0;
      for (final p in last20) {
        varianceSum += math.pow(p - sma20, 2);
      }
      final double stdDev = math.sqrt(varianceSum / 20.0);
      final double upperBand = sma20 + (2.0 * stdDev);
      final double lowerBand = math.max(0.000001, sma20 - (2.0 * stdDev));

      // EMA 50
      double ema50 = sma20;
      if (closes.length >= 50) {
        double sum50 = 0.0;
        for (int i = 0; i < 50; i++) {
          sum50 += closes[i];
        }
        ema50 = sum50 / 50.0;
        const double k50 = 2.0 / 51.0;
        for (int i = 50; i < closes.length; i++) {
          ema50 = (closes[i] - ema50) * k50 + ema50;
        }
      } else {
        ema50 = closes.reduce((a, b) => a + b) / closes.length;
      }

      // 2. ІСТОРИЧНІ ЕКСТРЕМУМИ ТА ФРАКТАЛИ (5-денне підтвердження + 20D/5D локальні рівні)
      final double globalPeak = highs.reduce(math.max);
      final double globalBottom = lows.reduce(math.min);

      final last20Highs = highs.sublist(math.max(0, highs.length - 20));
      final double recentPeak20d = math.max(last20Highs.reduce(math.max), currentPrice);

      final last5Lows = lows.sublist(math.max(0, lows.length - 5));
      final double min5dLow = last5Lows.reduce(math.min);

      final List<double> confirmedHighs = [];
      for (int i = 2; i < highs.length - 2; i++) {
        if (highs[i] >= highs[i - 1] &&
            highs[i] >= highs[i - 2] &&
            highs[i] >= highs[i + 1] &&
            highs[i] >= highs[i + 2]) {
          confirmedHighs.add(highs[i]);
        }
      }

      final List<double> confirmedLows = [];
      for (int i = 2; i < lows.length - 2; i++) {
        if (lows[i] <= lows[i - 1] &&
            lows[i] <= lows[i - 2] &&
            lows[i] <= lows[i + 1] &&
            lows[i] <= lows[i + 2]) {
          confirmedLows.add(lows[i]);
        }
      }

      confirmedHighs.sort();
      double swingHigh = globalPeak;
      for (final h in confirmedHighs) {
        if (h > currentPrice * 1.03) {
          swingHigh = h;
          break;
        }
      }

      confirmedLows.sort((a, b) => b.compareTo(a));
      double swingLow = globalBottom;
      for (final l in confirmedLows) {
        if (l < currentPrice * 0.97) {
          swingLow = l;
          break;
        }
      }

      // 3. RSI (14 періодів, Wilder's Smoothing), нахил RSI та Дивергенції
      double rsi = 50.0;
      double rsiSlope = 0.0;
      String rsiStatus = 'Нейтральний (RSI 50.0)';
      String rsiDivergence = 'Відсутня';

      if (closes.length >= 15) {
        double gains = 0.0;
        double losses = 0.0;
        for (int i = 1; i <= 14; i++) {
          final diff = closes[i] - closes[i - 1];
          if (diff > 0) {
            gains += diff;
          } else {
            losses += diff.abs();
          }
        }
        double avgGain = gains / 14.0;
        double avgLoss = losses / 14.0;

        final List<double> rsiSeries = [];
        for (int i = 15; i < closes.length; i++) {
          final diff = closes[i] - closes[i - 1];
          final curGain = diff > 0 ? diff : 0.0;
          final curLoss = diff < 0 ? diff.abs() : 0.0;
          avgGain = (avgGain * 13 + curGain) / 14.0;
          avgLoss = (avgLoss * 13 + curLoss) / 14.0;
          final rs = avgLoss == 0 ? 100.0 : (avgGain / avgLoss);
          rsiSeries.add(100.0 - (100.0 / (1.0 + rs)));
        }

        if (rsiSeries.isNotEmpty) {
          rsi = double.parse(rsiSeries.last.toStringAsFixed(1));
          if (rsiSeries.length >= 4) {
            rsiSlope = rsiSeries.last - rsiSeries[rsiSeries.length - 4];
          }
          if (rsi < 30) {
            rsiStatus = '💎 Екстремальна перепроданість (RSI $rsi < 30) — Дно';
          } else if (rsi < 45) {
            rsiStatus = '📉 Охолодження / Зона накопичення (RSI $rsi)';
          } else if (rsi <= 60) {
            rsiStatus = '⚖️ Нейтральна рівновага (RSI $rsi)';
          } else if (rsi <= 70) {
            rsiStatus = '📈 Сильний бичачий імпульс (RSI $rsi)';
          } else {
            rsiStatus = '🔥 Сильний перегрів (RSI $rsi > 70) — Фіксувати';
          }

          // Пошук бичачої/ведмежої дивергенції
          if (rsiSeries.length >= 10 && closes.length >= 10) {
            final recentClose = closes.last;
            final prevMinClose = closes.sublist(closes.length - 10, closes.length - 1).reduce(math.min);
            final recentRsi = rsiSeries.last;
            final prevMinRsi = rsiSeries.sublist(rsiSeries.length - 10, rsiSeries.length - 1).reduce(math.min);

            if (recentClose <= prevMinClose && recentRsi > prevMinRsi + 2.0) {
              rsiDivergence = '🔥 Бичача дивергенція (Ціна падає, але RSI зростає — ознака сильного розвороту вгору)';
            } else {
              final recentHigh = closes.last;
              final prevMaxClose = closes.sublist(closes.length - 10, closes.length - 1).reduce(math.max);
              final prevMaxRsi = rsiSeries.sublist(rsiSeries.length - 10, rsiSeries.length - 1).reduce(math.max);
              if (recentHigh >= prevMaxClose && recentRsi < prevMaxRsi - 2.0) {
                rsiDivergence = '⚠️ Ведмежа дивергенція (Ціна зростає, але RSI слабшає — загроза спаду)';
              }
            }
          }
        }
      }

      // 4. ATR (14 періодів) ТА ВОЛАТИЛЬНІСТЬ
      double atr = currentPrice * 0.04;
      if (highs.length >= 15 && lows.length >= 15 && closes.length >= 15) {
        final List<double> trList = [];
        for (int i = 1; i < highs.length; i++) {
          final tr = math.max(
            highs[i] - lows[i],
            math.max(
              (highs[i] - closes[i - 1]).abs(),
              (lows[i] - closes[i - 1]).abs(),
            ),
          );
          trList.add(tr);
        }
        if (trList.length >= 14) {
          double curAtr = trList.take(14).reduce((a, b) => a + b) / 14.0;
          for (int i = 14; i < trList.length; i++) {
            curAtr = (curAtr * 13 + trList[i]) / 14.0;
          }
          atr = curAtr;
        }
      }
      final double atrPct = currentPrice > 0 ? double.parse(((atr / currentPrice) * 100).toStringAsFixed(1)) : 4.0;

      // 5. ОБ'ЄМ, TAKER ORDER FLOW ТА ТІНІ ВІДХИЛЕННЯ НА ВЕРШИНІ
      double volumeRatio = 1.0;
      String volumeStatus = '⚖️ Середній об\'єм';
      if (volumes.length >= 20) {
        final last20Vol = volumes.sublist(volumes.length - 20);
        final avgVol = last20Vol.reduce((a, b) => a + b) / 20.0;
        final curVol = volumes.last;
        if (avgVol > 0) {
          volumeRatio = double.parse((curVol / avgVol).toStringAsFixed(2));
          if (volumeRatio >= 1.5) {
            volumeStatus = '🔥 Вибуховий об\'єм (+${((volumeRatio - 1) * 100).toInt()}%) — Інтерес Smart Money';
          } else if (volumeRatio >= 1.15) {
            volumeStatus = '📈 Підвищений об\'єм (+${((volumeRatio - 1) * 100).toInt()}%)';
          } else if (volumeRatio <= 0.65) {
            volumeStatus = '💤 Низький об\'єм (-${((1 - volumeRatio) * 100).toInt()}%) — Затишшя / флет';
          }
        }
      }

      // Taker Buy Ratio за останні 5 днів (частка агресивних ринкових покупок)
      double takerBuyRatio = 50.0;
      if (volumes.length >= 5 && takerBuyVolumes.length >= 5) {
        double sumVol5 = 0.0;
        double sumTaker5 = 0.0;
        for (int i = volumes.length - 5; i < volumes.length; i++) {
          sumVol5 += volumes[i];
          sumTaker5 += takerBuyVolumes[i];
        }
        if (sumVol5 > 0) {
          takerBuyRatio = double.parse(((sumTaker5 / sumVol5) * 100.0).clamp(10.0, 90.0).toStringAsFixed(1));
        }
      }

      // Співвідношення об'ємів на червоних свічках до зелених за останні 10 днів
      double downUpVolRatio = 1.0;
      if (closes.length >= 11 && volumes.length >= 11) {
        double downVol = 0.0;
        int downDays = 0;
        double upVol = 0.0;
        int upDays = 0;
        for (int i = closes.length - 10; i < closes.length; i++) {
          if (closes[i] < closes[i - 1]) {
            downVol += volumes[i];
            downDays++;
          } else {
            upVol += volumes[i];
            upDays++;
          }
        }
        final avgDown = downDays > 0 ? downVol / downDays : 1.0;
        final avgUp = upDays > 0 ? upVol / upDays : 1.0;
        if (avgUp > 0) {
          downUpVolRatio = (avgDown / avgUp).clamp(0.3, 3.0);
        }
      }

      // Максимальна верхня тінь свічки (Shooting Star / відбій від опору) за останні 3 дні
      double upperWickRatio = 0.0;
      if (highs.length >= 3 && lows.length >= 3 && opens.length >= 3 && closes.length >= 3) {
        for (int i = highs.length - 3; i < highs.length; i++) {
          final range = highs[i] - lows[i];
          if (range > 0) {
            final bodyTop = math.max(opens[i], closes[i]);
            final uw = (highs[i] - bodyTop) / range;
            if (uw > upperWickRatio) {
              upperWickRatio = uw;
            }
          }
        }
      }

      return _CachedTechnicalData(
        cachedAt: DateTime.now(),
        bollingerUpper: double.parse(upperBand.toStringAsFixed(4)),
        bollingerMiddle: double.parse(sma20.toStringAsFixed(4)),
        bollingerLower: double.parse(lowerBand.toStringAsFixed(4)),
        ema50: double.parse(ema50.toStringAsFixed(4)),
        swingHigh: double.parse(swingHigh.toStringAsFixed(4)),
        swingLow: double.parse(swingLow.toStringAsFixed(4)),
        recentPeak20d: double.parse(recentPeak20d.toStringAsFixed(4)),
        min5dLow: double.parse(min5dLow.toStringAsFixed(4)),
        globalPeak100d: double.parse(globalPeak.toStringAsFixed(4)),
        globalBottom100d: double.parse(globalBottom.toStringAsFixed(4)),
        rsi: rsi,
        rsiSlope: rsiSlope,
        rsiStatus: rsiStatus,
        rsiDivergence: rsiDivergence,
        atr: double.parse(atr.toStringAsFixed(4)),
        atrPct: atrPct,
        volumeRatio: volumeRatio,
        volumeStatus: volumeStatus,
        takerBuyRatio: takerBuyRatio,
        downUpVolRatio: downUpVolRatio,
        upperWickRatio: upperWickRatio,
      );
    } catch (_) {
      return null;
    }
  }

  TpSlInfo _buildTpSlFromIndicators({
    required double entryPrice,
    required double currentPrice,
    required _CachedTechnicalData tech,
    required String btcRegime,
  }) {
    // 1. Положення в каналі Боллінджера
    String positionInChannel;
    if (currentPrice >= tech.bollingerUpper) {
      positionInChannel = '🔥 Зона перекупленості (Вище верхнього Боллінджера)';
    } else if (currentPrice <= tech.bollingerLower) {
      positionInChannel = '💎 Зона накопичення / Дно (Біля нижнього Боллінджера)';
    } else if (currentPrice > tech.bollingerMiddle) {
      positionInChannel = '📈 Бичача зона (Вище середньої лінії SMA 20)';
    } else {
      positionInChannel = '📉 Ведмежа зона (Нижче середньої лінії SMA 20)';
    }

    // 2. Розрахунок 3 ШАРІВ ТЕЙК-ПРОФІТУ (прив'язаних до реального входу DCA та структури ринку)
    // Більше не "відсуваємо" TP1 нескінченно вгору, якщо ціна вже прийшла на пік!
    final double baseRef = (entryPrice > 0 && entryPrice < currentPrice) ? entryPrice : currentPrice;
    double tp1 = tech.bollingerUpper >= baseRef * 1.04
        ? tech.bollingerUpper
        : double.parse((baseRef * 1.10).toStringAsFixed(4));

    // Якщо поточна ціна вже значно вище і входу, і Боллінджера — фіксуємо TP1 як актуальний пік для негайного виконання
    if (tp1 < currentPrice * 0.92 && entryPrice > 0 && currentPrice >= entryPrice * 1.12) {
      tp1 = double.parse(math.max(tech.bollingerUpper, currentPrice).toStringAsFixed(4));
    }

    double tp2 = tech.swingHigh > math.max(tp1, currentPrice) * 1.03
        ? tech.swingHigh
        : double.parse((math.max(tp1, currentPrice) * 1.16).toStringAsFixed(4));

    double tp3 = tech.globalPeak100d > tp2 * 1.03
        ? tech.globalPeak100d
        : double.parse((tp2 * 1.24).toStringAsFixed(4));

    final distTp1 = currentPrice > 0 ? (((tp1 - currentPrice) / currentPrice) * 100) : 0.0;
    final distTp2 = currentPrice > 0 ? (((tp2 - currentPrice) / currentPrice) * 100) : 0.0;
    final distTp3 = currentPrice > 0 ? (((tp3 - currentPrice) / currentPrice) * 100) : 0.0;

    // 3. Адаптивний Стоп-Лосс: SwingLow - 1.2 ATR
    final double atrBuffer = tech.atr > 0 ? (1.2 * tech.atr) : (tech.swingLow * 0.04);
    double stopLoss = double.parse((tech.swingLow - atrBuffer).toStringAsFixed(4));
    if (stopLoss >= currentPrice * 0.98 || stopLoss <= 0) {
      final fallbackDist = tech.atr > 0 ? (1.6 * tech.atr) : (currentPrice * 0.08);
      stopLoss = double.parse(math.max(0.000001, currentPrice - fallbackDist).toStringAsFixed(4));
    }
    final distSl = currentPrice > 0 ? (((currentPrice - stopLoss) / currentPrice) * 100) : 0.0;
    final stopReason = 'Адаптивний буфер (-${distSl.toStringAsFixed(1)}%, 1.2 ATR (\$${tech.atr}) нижче підтримки \$${tech.swingLow})';

    // 4. Співвідношення Ризик/Прибуток (Risk-to-Reward Ratio)
    final targetRef = currentPrice >= tp1 ? tp2 : tp1;
    final potentialGain = (targetRef - currentPrice) > 0 ? (targetRef - currentPrice) : (currentPrice * 0.05);
    final potentialRisk = (currentPrice - stopLoss) > 0 ? (currentPrice - stopLoss) : (currentPrice * 0.05);
    final double rr = potentialRisk > 0 ? double.parse((potentialGain / potentialRisk).toStringAsFixed(2)) : 1.0;

    String rrGrade;
    String rrLabel;
    if (rr >= 2.0) {
      rrGrade = 'GOOD';
      rrLabel = '🟢 Відмінний R:R ($rr : 1) — Потенціал значно перевищує ризик';
    } else if (rr >= 1.4) {
      rrGrade = 'ACCEPTABLE';
      rrLabel = '🟡 Помірний R:R ($rr : 1) — Робочий баланс';
    } else {
      rrGrade = 'POOR';
      rrLabel = '🔴 Невигідний R:R ($rr : 1) — Ризик перевищує прибуток';
    }

    // 5. Розумна DCA-сітка (3 лімітні ордери на відкуп дна)
    double dca1Price = math.min(tech.bollingerLower, tech.swingLow);
    if (dca1Price >= currentPrice * 0.99) {
      dca1Price = currentPrice * 0.95;
    }
    double dca2Price = dca1Price - (tech.atr > 0 ? tech.atr : (dca1Price * 0.05));
    double dca3Price = math.max(tech.globalBottom100d, dca2Price * 0.94);

    dca1Price = double.parse(dca1Price.toStringAsFixed(4));
    dca2Price = double.parse(dca2Price.toStringAsFixed(4));
    dca3Price = double.parse(dca3Price.toStringAsFixed(4));

    final dcaLadder = [
      DcaOrderLevel(
        orderNumber: 1,
        sharePct: 30,
        targetPrice: dca1Price,
        distFromCurrentPct: double.parse((((currentPrice - dca1Price) / currentPrice) * 100).toStringAsFixed(1)),
        rationale: 'Нижній Боллінджер / локальна підтримка',
      ),
      DcaOrderLevel(
        orderNumber: 2,
        sharePct: 35,
        targetPrice: dca2Price,
        distFromCurrentPct: double.parse((((currentPrice - dca2Price) / currentPrice) * 100).toStringAsFixed(1)),
        rationale: 'Усереднення на просіданні (-1.0 ATR волатильності)',
      ),
      DcaOrderLevel(
        orderNumber: 3,
        sharePct: 35,
        targetPrice: dca3Price,
        distFromCurrentPct: double.parse((((currentPrice - dca3Price) / currentPrice) * 100).toStringAsFixed(1)),
        rationale: 'Глобальне 100-денне дно (ліквідаційний сквиз)',
      ),
    ];

    // 6. АЛГОРИТМ ФІКСАЦІЇ НА МАКСИМУМАХ ТА ЗАХИСТУ ВІД STOP-LOSS
    final exitEval = _evaluateExitAndStopProbability(
      entryPrice: entryPrice,
      currentPrice: currentPrice,
      tp1: tp1,
      tp2: tp2,
      stopLoss: stopLoss,
      bollingerUpper: tech.bollingerUpper,
      bollingerMiddle: tech.bollingerMiddle,
      bollingerLower: tech.bollingerLower,
      ema50: tech.ema50,
      recentPeak20d: tech.recentPeak20d,
      min5dLow: tech.min5dLow,
      rsi: tech.rsi,
      rsiSlope: tech.rsiSlope,
      rsiDivergence: tech.rsiDivergence,
      atr: tech.atr,
      takerBuyRatio: tech.takerBuyRatio,
      downUpVolRatio: tech.downUpVolRatio,
      upperWickRatio: tech.upperWickRatio,
      btcRegime: btcRegime,
    );

    final String tp1Label = exitEval.isTp1Reached
        ? '✅ Шар 1 ДОСЯГНУТО (Фіксувати 30% зараз!)'
        : 'Шар 1: Верхній Боллінджер';

    return TpSlInfo(
      entryPrice: entryPrice,
      tp1: tp1,
      tp1Pct: 30,
      distToTp1Pct: double.parse(distTp1.toStringAsFixed(1)),
      tp1Label: tp1Label,
      tp2: tp2,
      tp2Pct: 35,
      distToTp2Pct: double.parse(distTp2.toStringAsFixed(1)),
      tp2Label: 'Шар 2: Опір структури (Swing High)',
      tp3: tp3,
      tp3Pct: 35,
      distToTp3Pct: double.parse(distTp3.toStringAsFixed(1)),
      tp3Label: 'Шар 3: Глобальна вершина / ATH',
      stopLoss: stopLoss,
      distToSlPct: double.parse(distSl.toStringAsFixed(1)),
      stopReason: stopReason,
      bollingerUpper: tech.bollingerUpper,
      bollingerMiddle: tech.bollingerMiddle,
      bollingerLower: tech.bollingerLower,
      swingHigh: tech.swingHigh,
      swingLow: tech.swingLow,
      globalPeak100d: tech.globalPeak100d,
      globalBottom100d: tech.globalBottom100d,
      positionInChannel: positionInChannel,
      accumulatePrice: dca1Price,
      distToAccumulatePct: double.parse((((currentPrice - dca1Price) / currentPrice) * 100).toStringAsFixed(1)),
      rsi: tech.rsi,
      rsiStatus: tech.rsiStatus,
      rsiDivergence: tech.rsiDivergence,
      atr: tech.atr,
      atrPct: tech.atrPct,
      volumeRatio: tech.volumeRatio,
      volumeStatus: tech.volumeStatus,
      riskRewardRatio: rr,
      riskRewardGrade: rrGrade,
      riskRewardLabel: rrLabel,
      btcMarketRegime: btcRegime,
      dcaLadder: dcaLadder,
      exitSignalCode: exitEval.exitSignalCode,
      exitTitleUk: exitEval.exitTitleUk,
      exitActionUk: exitEval.exitActionUk,
      recommendedSellPct: exitEval.recommendedSellPct,
      peakExhaustionScore: exitEval.peakExhaustionScore,
      slProbabilityPct: exitEval.slProbabilityPct,
      slRiskFactorsUk: exitEval.slRiskFactorsUk,
      recentPeak20d: tech.recentPeak20d,
      pullbackFromPeakPct: exitEval.pullbackFromPeakPct,
      trailingStopPrice: exitEval.trailingStopPrice,
      breakevenPrice: exitEval.breakevenPrice,
      earlyExitPrice: exitEval.earlyExitPrice,
      takerBuyRatio: tech.takerBuyRatio,
      ema50: tech.ema50,
      isTp1Reached: exitEval.isTp1Reached,
    );
  }

  /// Кількісне ядро оцінки:
  /// 1) Виcнаження піку (Peak Exhaustion Score 0..100%) — коли час фіксувати прибуток на вершині;
  /// 2) Динамічний Трейлінг-Стоп (Chandelier Exit) — коли ціна відкотилася з піку й час рятувати профіт;
  /// 3) Ймовірність досягнення Stop-Loss (0..99%) та Лінія ранньої евакуації (Early Invalidation Exit).
  ({
    String exitSignalCode,
    String exitTitleUk,
    String exitActionUk,
    int recommendedSellPct,
    int peakExhaustionScore,
    int slProbabilityPct,
    String slRiskFactorsUk,
    double pullbackFromPeakPct,
    double trailingStopPrice,
    double breakevenPrice,
    double earlyExitPrice,
    bool isTp1Reached,
  }) _evaluateExitAndStopProbability({
    required double entryPrice,
    required double currentPrice,
    required double tp1,
    required double tp2,
    required double stopLoss,
    required double bollingerUpper,
    required double bollingerMiddle,
    required double bollingerLower,
    required double ema50,
    required double recentPeak20d,
    required double min5dLow,
    required double rsi,
    required double rsiSlope,
    required String rsiDivergence,
    required double atr,
    required double takerBuyRatio,
    required double downUpVolRatio,
    required double upperWickRatio,
    required String btcRegime,
  }) {
    final double effectiveEntry = entryPrice > 0 ? entryPrice : currentPrice;
    final double pnlPct = effectiveEntry > 0
        ? ((currentPrice - effectiveEntry) / effectiveEntry) * 100.0
        : 0.0;

    // 1. Розрахунок ключових захисних рівнів (Breakeven, Chandelier Trailing Stop, Early Exit)
    final double breakevenPrice = double.parse((effectiveEntry * 1.0025).toStringAsFixed(4));
    final double safeAtr = atr > 0 ? atr : (currentPrice * 0.04);

    // Пік для трейлінг-стопу має сенс ВИКЛЮЧНО тоді, коли позиція реально побувала в прибутку ПІСЛЯ покупки.
    // Якщо поточний PnL <= 0%, ринкові піки тижневої давнини ДО покупки є нерелевантними для захисту прибутку.
    final double effectivePeak = (pnlPct <= 0.0)
        ? currentPrice
        : math.max(currentPrice, math.min(recentPeak20d, effectiveEntry * 2.0));

    final double pullbackFromPeakPct = effectivePeak > 0
        ? double.parse((((effectivePeak - currentPrice) / effectivePeak) * 100.0).clamp(0.0, 99.0).toStringAsFixed(1))
        : 0.0;

    // Chandelier Trailing Stop активується ЛИШЕ тоді, коли позиція заробила мінімум +4% прибутку від входу.
    // Трейлінг існує для захисту НАКОПИЧЕНОГО профіту, а не для передчасного продажу активу в нулі чи міні-просіданні!
    double trailingStopPrice = 0.0;
    if (pnlPct >= 4.0 || (effectivePeak >= effectiveEntry * 1.05 && currentPrice >= effectiveEntry)) {
      double rawTrailing = effectivePeak - (1.8 * safeAtr);
      if (pnlPct >= 7.0 && rawTrailing < breakevenPrice) {
        rawTrailing = breakevenPrice;
      }
      if (rawTrailing > effectiveEntry * 0.99) {
        trailingStopPrice = double.parse(rawTrailing.toStringAsFixed(4));
      }
    }

    // Лінія ранньої евакуації (Pre-Stop Invalidation): трохи нижче 5-денного мінімуму або SMA20 - 0.5 ATR,
    // але завжди вище жорсткого стоп-лоса, щоб зберегти 50-65% ризикованого капіталу при зламі структури
    double rawEarlyExit = math.min(min5dLow, bollingerMiddle) - (0.35 * safeAtr);
    if (rawEarlyExit >= currentPrice * 0.992) {
      rawEarlyExit = currentPrice - (0.85 * safeAtr);
    }
    if (rawEarlyExit <= stopLoss * 1.015) {
      rawEarlyExit = stopLoss + ((currentPrice - stopLoss) * 0.45);
    }
    final double earlyExitPrice = double.parse(math.max(0.000001, rawEarlyExit).toStringAsFixed(4));

    // Чи досягнуто вже TP1?
    final bool isTp1Reached = (currentPrice >= tp1 * 0.988 && pnlPct >= 5.0) ||
        (pnlPct >= 12.0 && currentPrice >= bollingerUpper * 0.985);

    // 2. ОЦІНКА ВИСНАЖЕННЯ ПІКУ (Peak Exhaustion Score 0..100%)
    int peakScore = 10;
    final double bandWidth = (bollingerUpper - bollingerLower).abs();
    final double percentB = bandWidth > 0 ? ((currentPrice - bollingerLower) / bandWidth) : 0.5;

    if (percentB >= 1.0) {
      peakScore += 30;
    } else if (percentB >= 0.85) {
      peakScore += 22;
    } else if (percentB >= 0.70) {
      peakScore += 12;
    }

    if (rsi >= 74) {
      peakScore += 28;
    } else if (rsi >= 68) {
      peakScore += 20;
    } else if (rsi >= 61) {
      peakScore += 12;
    }

    if (rsiDivergence.contains('Ведмежа')) {
      peakScore += 18;
    }
    if (upperWickRatio >= 0.45 && percentB >= 0.65) {
      peakScore += 14;
    }
    if (pnlPct >= 25.0) {
      peakScore += 16;
    } else if (pnlPct >= 12.0) {
      peakScore += 10;
    } else if (pnlPct >= 6.0) {
      peakScore += 5;
    }
    final int peakExhaustionScore = peakScore.clamp(5, 98);

    // 3. ОЦІНКА ЙМОВІРНОСТІ ПАДІННЯ ДО STOP-LOSS (slProbabilityPct 0..99%)
    int slProb = 10;
    final List<String> riskReasons = [];

    final double atrToSl = safeAtr > 0 ? ((currentPrice - stopLoss) / safeAtr) : 2.5;
    if (currentPrice <= stopLoss) {
      slProb = 98;
      riskReasons.add('Ціна вже пробила рівень Stop-Loss');
    } else if (atrToSl <= 0.85) {
      slProb += 44;
      riskReasons.add('До стопу критичні ${atrToSl.toStringAsFixed(1)} ATR');
    } else if (atrToSl <= 1.35) {
      slProb += 30;
      riskReasons.add('Близько до стопу (${atrToSl.toStringAsFixed(1)} ATR)');
    } else if (atrToSl <= 2.0) {
      slProb += 16;
    }

    if (currentPrice < bollingerMiddle && currentPrice < ema50) {
      slProb += 18;
      riskReasons.add('Пробито тренд SMA20 та EMA50 вниз');
    } else if (currentPrice < bollingerMiddle) {
      slProb += 10;
      riskReasons.add('Торгується нижче SMA20');
    }

    if (takerBuyRatio < 45.5) {
      slProb += 15;
      riskReasons.add('Агресивний продаж по ринку (Taker Buy ${takerBuyRatio.toStringAsFixed(0)}%)');
    } else if (takerBuyRatio < 48.5) {
      slProb += 8;
      riskReasons.add('Перевага продавців в ордерфлоу (${takerBuyRatio.toStringAsFixed(0)}%)');
    }

    if (downUpVolRatio >= 1.25) {
      slProb += 10;
      riskReasons.add('Об\'єм падіння перевищує ріст у ${downUpVolRatio.toStringAsFixed(1)}x');
    }

    if (rsi < 46 && rsi >= 31 && rsiSlope < -1.0) {
      slProb += 9;
      riskReasons.add('Імпульс RSI ($rsi) падає без ознак дна');
    }

    if (btcRegime.contains('Ведмежа')) {
      slProb += 8;
      riskReasons.add('Слабкість ринку BTC (< SMA50)');
    }

    if (pnlPct <= -3.0) {
      slProb += 6;
    }

    // Якщо актив вже на глибокому перепроданому дні або має бичачу дивергенцію — ризик пробою стопу знижується (високий шанс відскоку)
    if (rsi < 29 || rsiDivergence.contains('Бичача')) {
      slProb -= 14;
      if (riskReasons.isEmpty) {
        riskReasons.add('Перепроданість (RSI $rsi) підвищує шанс технічного відскоку');
      }
    }

    final int slProbabilityPct = slProb.clamp(5, 97);
    final String slRiskFactorsUk = riskReasons.isNotEmpty
        ? riskReasons.take(3).join(' • ')
        : 'Структура вище ключових підтримок • До стопу ${atrToSl.toStringAsFixed(1)} ATR';

    // 4. ВИЗНАЧЕННЯ ГОЛОВНОГО ТОРГОВОГО СИГНАЛУ ВИХОДУ / ФІКСАЦІЇ
    String exitSignalCode;
    String exitTitleUk;
    String exitActionUk;
    int recommendedSellPct;

    // Справжнє пробиття трейлінг-стопу: актив побував у плюсі, трейлінг вище входу, ціна відкотилася
    final bool brokeTrailingStop = trailingStopPrice > effectiveEntry &&
        currentPrice <= trailingStopPrice &&
        pnlPct >= 1.5;

    // Фіксація на піку: актив знаходиться на вершині САМЕ ЗАРАЗ (відкат не більше 2.5%) та має гарний профіт
    final bool isNearPeakNow = pullbackFromPeakPct <= 2.5;

    if (pnlPct >= 6.0 && isNearPeakNow && (peakExhaustionScore >= 68 || (pnlPct >= 18.0 && peakExhaustionScore >= 52))) {
      recommendedSellPct = (peakExhaustionScore >= 78 || pnlPct >= 25.0) ? 65 : 50;
      exitSignalCode = 'SELL_PEAK_NOW';
      exitTitleUk = '🔥 ФІКСУВАТИ НА ПІКУ ЗАРАЗ ($recommendedSellPct% ПОЗИЦІЇ)';
      exitActionUk =
          'Ціна досягла зони перегріву / локального максимуму (Виснаження піку: $peakExhaustionScore%, RSI: $rsi, PnL: +${pnlPct.toStringAsFixed(1)}%). '
          'Продайте $recommendedSellPct% активу за поточною ціною \$${_fmt(currentPrice)}, щоб забрати прибуток, '
          'а на залишок перенесіть стоп у беззбиток (\$${_fmt(breakevenPrice)}).';
    } else if (brokeTrailingStop) {
      recommendedSellPct = pnlPct >= 8.0 ? 60 : 75;
      exitSignalCode = 'TRAILING_STOP_HIT';
      exitTitleUk = '🔒 ПРОБИТО ТРЕЙЛІНГ-СТОП — ЗАХИСТ ПРОФІТУ ($recommendedSellPct%)';
      exitActionUk =
          'Після росту до піку \$${_fmt(effectivePeak)} ціна відкотилася на -$pullbackFromPeakPct% і пробила динамічний Chandelier-стоп (\$${_fmt(trailingStopPrice)}). '
          'Зафіксуйте $recommendedSellPct% заробленого прибутку (поточний PnL: +${pnlPct.toStringAsFixed(1)}%), не чекаючи зливу в нуль чи мінус.';
    } else if (pnlPct >= 5.0 && (isTp1Reached || percentB >= 0.85)) {
      recommendedSellPct = 30;
      exitSignalCode = 'TAKE_PARTIAL_TP1';
      exitTitleUk = '🟢 ЧАСТКОВА ФІКСАЦІЯ TP1 (30% ОБСЯГУ)';
      exitActionUk =
          'Позиція в плюсі (+${pnlPct.toStringAsFixed(1)}%) і тестує зону першого опору (\$${_fmt(tp1)}). '
          'Зафіксуйте перші 30% обсягу для гарантованого результату та перенесіть захисний стоп у точку беззбитковості (\$${_fmt(breakevenPrice)}).';
    } else if (pnlPct <= -3.0 && slProbabilityPct >= 65 && currentPrice <= earlyExitPrice && rsi >= 28) {
      final double savedLossPct = (((earlyExitPrice - stopLoss) / currentPrice) * 100.0).abs().clamp(1.5, 25.0);
      recommendedSellPct = slProbabilityPct >= 76 ? 100 : 50;
      exitSignalCode = 'PRE_STOP_DANGER';
      exitTitleUk = '🚨 ЗАГРОЗА СТОП-ЛОСУ ($slProbabilityPct%) — РАННІЙ ВИХІД';
      exitActionUk =
          'Локальна структура слабшає ($slRiskFactorsUk, PnL: ${pnlPct.toStringAsFixed(1)}%). Ймовірність подальшого падіння до Stop-Loss (\$${_fmt(stopLoss)}) становить $slProbabilityPct%. '
          'Не чекайте повного збитку: скоротіть $recommendedSellPct% позиції зараз або по лінії ранньої евакуації \$${_fmt(earlyExitPrice)} (це збереже ~${savedLossPct.toStringAsFixed(1)}% капіталу).';
    } else if (currentPrice <= bollingerLower * 1.015 || rsi <= 35 || rsiDivergence.contains('Бичача')) {
      recommendedSellPct = 0;
      exitSignalCode = 'ACCUMULATE_ZONE';
      exitTitleUk = '💎 ЗОНА ПЕРЕПРОДАНОСТІ / ДНО — НЕ ПРОДАВАТИ';
      exitActionUk =
          'Актив знаходиться поблизу підтримки (RSI: $rsi). Продаж на дні зафіксує невигідну ціну. '
          'Утримуйте позицію або використовуйте лімітну DCA-сітку для планового відкупу зі стопом \$${_fmt(stopLoss)}.';
    } else {
      recommendedSellPct = 0;
      exitSignalCode = 'HOLD_WAIT_TARGETS';
      exitTitleUk = '🛡️ УТРИМУВАТИ ПОЗИЦІЮ (У межах норми)';
      exitActionUk =
          'Позиція торгується біля точки входу (PnL: ${pnlPct >= 0 ? '+' : ''}${pnlPct.toStringAsFixed(2)}%). '
          'Ймовірність падіння до стопу низька ($slProbabilityPct%), ознак критичного перегріву немає ($peakExhaustionScore%). '
          'Утримуйте актив до цілі TP1 (\$${_fmt(tp1)}). Лінія захисту прибутку (Трейлінг): \$${_fmt(trailingStopPrice)}, лінія раннього виходу при зламі: \$${_fmt(earlyExitPrice)}.';
    }

    return (
      exitSignalCode: exitSignalCode,
      exitTitleUk: exitTitleUk,
      exitActionUk: exitActionUk,
      recommendedSellPct: recommendedSellPct,
      peakExhaustionScore: peakExhaustionScore,
      slProbabilityPct: slProbabilityPct,
      slRiskFactorsUk: slRiskFactorsUk,
      pullbackFromPeakPct: pullbackFromPeakPct,
      trailingStopPrice: trailingStopPrice,
      breakevenPrice: breakevenPrice,
      earlyExitPrice: earlyExitPrice,
      isTp1Reached: isTp1Reached,
    );
  }

  String _fmt(double p) {
    if (p >= 1000) return p.toStringAsFixed(2);
    if (p >= 0.0001) return p.toStringAsFixed(4);
    return p.toStringAsFixed(6);
  }

  TpSlInfo _generateFallbackTpSl(double entryPrice, double currentPrice, String btcRegime) {
    final tp1 = double.parse((currentPrice * 1.15).toStringAsFixed(4));
    final tp2 = double.parse((currentPrice * 1.35).toStringAsFixed(4));
    final tp3 = double.parse((currentPrice * 1.75).toStringAsFixed(4));
    final stopLoss = double.parse((currentPrice * 0.88).toStringAsFixed(4));
    final earlyExit = double.parse((currentPrice * 0.94).toStringAsFixed(4));
    final trailingStop = double.parse((currentPrice * 0.93).toStringAsFixed(4));
    final breakeven = double.parse(((entryPrice > 0 ? entryPrice : currentPrice) * 1.0025).toStringAsFixed(4));

    final distTp1 = (((tp1 - currentPrice) / currentPrice) * 100);
    final distTp2 = (((tp2 - currentPrice) / currentPrice) * 100);
    final distTp3 = (((tp3 - currentPrice) / currentPrice) * 100);
    final distSl = (((currentPrice - stopLoss) / currentPrice) * 100);

    return TpSlInfo(
      entryPrice: entryPrice,
      tp1: tp1,
      tp1Pct: 30,
      distToTp1Pct: double.parse(distTp1.toStringAsFixed(1)),
      tp1Label: 'Шар 1 (+15% Фіксація)',
      tp2: tp2,
      tp2Pct: 35,
      distToTp2Pct: double.parse(distTp2.toStringAsFixed(1)),
      tp2Label: 'Шар 2 (+35% Супротив)',
      tp3: tp3,
      tp3Pct: 35,
      distToTp3Pct: double.parse(distTp3.toStringAsFixed(1)),
      tp3Label: 'Шар 3 (+75% Пік)',
      stopLoss: stopLoss,
      distToSlPct: double.parse(distSl.toStringAsFixed(1)),
      stopReason: '-12% від поточної ціни (базовий стоп)',
      bollingerUpper: currentPrice * 1.15,
      bollingerMiddle: currentPrice,
      bollingerLower: currentPrice * 0.85,
      swingHigh: currentPrice * 1.35,
      swingLow: currentPrice * 0.88,
      globalPeak100d: currentPrice * 1.75,
      globalBottom100d: currentPrice * 0.75,
      positionInChannel: 'Базова математична модель',
      accumulatePrice: double.parse((currentPrice * 0.90).toStringAsFixed(4)),
      distToAccumulatePct: 10.0,
      rsi: 50.0,
      rsiStatus: 'Очікування свічок',
      rsiDivergence: 'Відсутня',
      atr: currentPrice * 0.04,
      atrPct: 4.0,
      volumeRatio: 1.0,
      volumeStatus: 'Базовий',
      riskRewardRatio: 2.5,
      riskRewardGrade: 'GOOD',
      riskRewardLabel: '🟢 Базовий R:R (2.5 : 1)',
      btcMarketRegime: btcRegime,
      dcaLadder: const [],
      exitSignalCode: 'HOLD_WAIT_TARGETS',
      exitTitleUk: '🛡️ УТРИМУВАТИ ПОЗИЦІЮ (Базова модель)',
      exitActionUk: 'Орієнтуйтесь на фіксацію 30% при досягненні \$${_fmt(tp1)} та захисний рівень раннього виходу \$${_fmt(earlyExit)}.',
      recommendedSellPct: 0,
      peakExhaustionScore: 25,
      slProbabilityPct: 25,
      slRiskFactorsUk: 'Базовий розрахунок волатильності',
      recentPeak20d: currentPrice,
      pullbackFromPeakPct: 0.0,
      trailingStopPrice: trailingStop,
      breakevenPrice: breakeven,
      earlyExitPrice: earlyExit,
      takerBuyRatio: 50.0,
      ema50: currentPrice,
      isTp1Reached: false,
    );
  }
}
