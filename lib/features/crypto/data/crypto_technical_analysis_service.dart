import 'dart:convert';
import 'dart:math' as math;
import 'package:http/http.dart' as http;
import 'models/crypto_models.dart';

class _CachedTechnicalData {
  final DateTime cachedAt;
  final double bollingerUpper;
  final double bollingerMiddle;
  final double bollingerLower;
  final double swingHigh;
  final double swingLow;
  final double globalPeak100d;
  final double globalBottom100d;
  final double rsi;
  final String rsiStatus;
  final String rsiDivergence;
  final double atr;
  final double atrPct;
  final double volumeRatio;
  final String volumeStatus;

  _CachedTechnicalData({
    required this.cachedAt,
    required this.bollingerUpper,
    required this.bollingerMiddle,
    required this.bollingerLower,
    required this.swingHigh,
    required this.swingLow,
    required this.globalPeak100d,
    required this.globalBottom100d,
    required this.rsi,
    required this.rsiStatus,
    required this.rsiDivergence,
    required this.atr,
    required this.atrPct,
    required this.volumeRatio,
    required this.volumeStatus,
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
  /// Смуги Боллінджера, RSI (14), ATR (14), Об'єм, Рівні Swing High/Low, R:R та DCA-сітку.
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
        dcaLadder: [],
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

  Future<_CachedTechnicalData?> _fetchAndCalculateIndicators(String symbol, double currentPrice) async {
    try {
      final url = Uri.parse('https://api.binance.com/api/v3/klines?symbol=${symbol}USDT&interval=1d&limit=100');
      final resp = await http.get(url).timeout(const Duration(seconds: 6));

      if (resp.statusCode != 200) return null;

      final klines = json.decode(resp.body) as List<dynamic>;
      if (klines.length < 20) return null;

      final List<double> highs = [];
      final List<double> lows = [];
      final List<double> closes = [];
      final List<double> volumes = [];

      for (final k in klines) {
        if (k is List && k.length >= 8) {
          final h = double.tryParse(k[2].toString()) ?? 0.0;
          final l = double.tryParse(k[3].toString()) ?? 0.0;
          final c = double.tryParse(k[4].toString()) ?? 0.0;
          final v = double.tryParse(k[7].toString()) ?? (double.tryParse(k[5].toString()) ?? 0.0);
          if (h > 0 && l > 0 && c > 0) {
            highs.add(h);
            lows.add(l);
            closes.add(c);
            volumes.add(v);
          }
        }
      }

      if (closes.length < 20) return null;

      // 1. СМУГИ БОЛЛІНДЖЕРА (SMA 20, 2 StdDev)
      final last20 = closes.sublist(closes.length - 20);
      final double sma20 = last20.reduce((a, b) => a + b) / 20.0;

      double varianceSum = 0.0;
      for (final p in last20) {
        varianceSum += math.pow(p - sma20, 2);
      }
      final double stdDev = math.sqrt(varianceSum / 20.0);
      final double upperBand = sma20 + (2.0 * stdDev);
      final double lowerBand = math.max(0.000001, sma20 - (2.0 * stdDev));

      // 2. ІСТОРИЧНІ ЕКСТРЕМУМИ ТА ФРАКТАЛИ (5-денне підтвердження для відсікання шуму)
      final double globalPeak = highs.reduce(math.max);
      final double globalBottom = lows.reduce(math.min);

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

      // 3. RSI (14 періодів, Wilder's Smoothing) ТА ДИВЕРГЕНЦІЇ
      double rsi = 50.0;
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

      // 5. ОБ'ЄМ (Volume Confirmation)
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

      return _CachedTechnicalData(
        cachedAt: DateTime.now(),
        bollingerUpper: double.parse(upperBand.toStringAsFixed(4)),
        bollingerMiddle: double.parse(sma20.toStringAsFixed(4)),
        bollingerLower: double.parse(lowerBand.toStringAsFixed(4)),
        swingHigh: double.parse(swingHigh.toStringAsFixed(4)),
        swingLow: double.parse(swingLow.toStringAsFixed(4)),
        globalPeak100d: double.parse(globalPeak.toStringAsFixed(4)),
        globalBottom100d: double.parse(globalBottom.toStringAsFixed(4)),
        rsi: rsi,
        rsiStatus: rsiStatus,
        rsiDivergence: rsiDivergence,
        atr: double.parse(atr.toStringAsFixed(4)),
        atrPct: atrPct,
        volumeRatio: volumeRatio,
        volumeStatus: volumeStatus,
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

    // 2. Розрахунок 3 ШАРІВ ТЕЙК-ПРОФІТУ
    double tp1 = tech.bollingerUpper > currentPrice * 1.03
        ? tech.bollingerUpper
        : double.parse((currentPrice * 1.08).toStringAsFixed(4));

    double tp2 = tech.swingHigh > tp1 * 1.03
        ? tech.swingHigh
        : double.parse((tp1 * 1.18).toStringAsFixed(4));

    double tp3 = tech.globalPeak100d > tp2 * 1.03
        ? tech.globalPeak100d
        : double.parse((tp2 * 1.25).toStringAsFixed(4));

    final distTp1 = currentPrice > 0 ? (((tp1 - currentPrice) / currentPrice) * 100) : 0.0;
    final distTp2 = currentPrice > 0 ? (((tp2 - currentPrice) / currentPrice) * 100) : 0.0;
    final distTp3 = currentPrice > 0 ? (((tp3 - currentPrice) / currentPrice) * 100) : 0.0;

    // 3. Адаптивний Стоп-Лосс: SwingLow - 1.2 ATR
    final double atrBuffer = tech.atr > 0 ? (1.2 * tech.atr) : (tech.swingLow * 0.04);
    double stopLoss = double.parse((tech.swingLow - atrBuffer).toStringAsFixed(4));
    if (stopLoss >= currentPrice * 0.98) {
      final fallbackDist = tech.atr > 0 ? (1.5 * tech.atr) : (currentPrice * 0.08);
      stopLoss = double.parse((currentPrice - fallbackDist).toStringAsFixed(4));
    }
    final distSl = currentPrice > 0 ? (((currentPrice - stopLoss) / currentPrice) * 100) : 0.0;
    final stopReason = 'Адаптивний буфер (-${distSl.toStringAsFixed(1)}%, 1.2 ATR (\$${tech.atr}) нижче підтримки \$${tech.swingLow})';

    // 4. Співвідношення Ризик/Прибуток (Risk-to-Reward Ratio)
    final potentialGain = (tp1 - currentPrice) > 0 ? (tp1 - currentPrice) : (currentPrice * 0.05);
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

    return TpSlInfo(
      entryPrice: entryPrice,
      tp1: tp1,
      tp1Pct: 30,
      distToTp1Pct: double.parse(distTp1.toStringAsFixed(1)),
      tp1Label: 'Шар 1: Верхній Боллінджер',
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
    );
  }

  TpSlInfo _generateFallbackTpSl(double entryPrice, double currentPrice, String btcRegime) {
    final tp1 = double.parse((currentPrice * 1.30).toStringAsFixed(4));
    final tp2 = double.parse((currentPrice * 1.70).toStringAsFixed(4));
    final tp3 = double.parse((currentPrice * 2.50).toStringAsFixed(4));
    final stopLoss = double.parse((currentPrice * 0.88).toStringAsFixed(4));

    final distTp1 = (((tp1 - currentPrice) / currentPrice) * 100);
    final distTp2 = (((tp2 - currentPrice) / currentPrice) * 100);
    final distTp3 = (((tp3 - currentPrice) / currentPrice) * 100);
    final distSl = (((currentPrice - stopLoss) / currentPrice) * 100);

    return TpSlInfo(
      entryPrice: entryPrice,
      tp1: tp1,
      tp1Pct: 30,
      distToTp1Pct: double.parse(distTp1.toStringAsFixed(1)),
      tp1Label: 'Шар 1 (+30% Фіксація)',
      tp2: tp2,
      tp2Pct: 35,
      distToTp2Pct: double.parse(distTp2.toStringAsFixed(1)),
      tp2Label: 'Шар 2 (+70% Супротив)',
      tp3: tp3,
      tp3Pct: 35,
      distToTp3Pct: double.parse(distTp3.toStringAsFixed(1)),
      tp3Label: 'Шар 3 (+150% Пік)',
      stopLoss: stopLoss,
      distToSlPct: double.parse(distSl.toStringAsFixed(1)),
      stopReason: '-12% від поточної ціни (базовий стоп)',
      bollingerUpper: currentPrice * 1.15,
      bollingerMiddle: currentPrice,
      bollingerLower: currentPrice * 0.85,
      swingHigh: currentPrice * 1.5,
      swingLow: currentPrice * 0.8,
      globalPeak100d: currentPrice * 2.0,
      globalBottom100d: currentPrice * 0.7,
      positionInChannel: 'Базова математична модель',
      accumulatePrice: double.parse((currentPrice * 0.88).toStringAsFixed(4)),
      distToAccumulatePct: 12.0,
      rsi: 50.0,
      rsiStatus: 'Очікування свічок',
      rsiDivergence: 'Відсутня',
      atr: currentPrice * 0.05,
      atrPct: 5.0,
      volumeRatio: 1.0,
      volumeStatus: 'Базовий',
      riskRewardRatio: 2.5,
      riskRewardGrade: 'GOOD',
      riskRewardLabel: '🟢 Базовий R:R (2.5 : 1)',
      btcMarketRegime: btcRegime,
      dcaLadder: [],
    );
  }
}
