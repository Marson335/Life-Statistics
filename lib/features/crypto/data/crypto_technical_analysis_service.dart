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

  _CachedTechnicalData({
    required this.cachedAt,
    required this.bollingerUpper,
    required this.bollingerMiddle,
    required this.bollingerLower,
    required this.swingHigh,
    required this.swingLow,
    required this.globalPeak100d,
    required this.globalBottom100d,
  });

  bool get isExpired => DateTime.now().difference(cachedAt).inMinutes > 15;
}

class CryptoTechnicalAnalysisService {
  final Map<String, _CachedTechnicalData> _cache = {};

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

  /// Аналізує монету за 100-денними свічками (1D), розраховує смуги Боллінджера
  /// та знаходить історичні шари (Swing High, Swing Low, ATH/Дно).
  Future<TpSlInfo> analyzeSymbol({
    required String symbol,
    required double entryPrice,
    required double currentPrice,
  }) async {
    final sym = symbol.trim().toUpperCase();
    final effectiveEntry = entryPrice > 0 ? entryPrice : (currentPrice > 0 ? currentPrice : 1.0);
    final curPrice = currentPrice > 0 ? currentPrice : effectiveEntry;

    // Стейблкоїни мають фіксовані параметри
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
      );
    }

    _CachedTechnicalData? techData = _cache[sym];

    if (techData == null || techData.isExpired) {
      techData = await _fetchAndCalculateIndicators(sym, curPrice);
      if (techData != null) {
        _cache[sym] = techData;
      }
    }

    // Якщо не вдалося завантажити свічки (наприклад, рідкісний щиткоїн) — fallback
    if (techData == null) {
      return _generateFallbackTpSl(effectiveEntry, curPrice);
    }

    return _buildTpSlFromIndicators(
      entryPrice: effectiveEntry,
      currentPrice: curPrice,
      tech: techData,
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

      for (final k in klines) {
        if (k is List && k.length >= 5) {
          final h = double.tryParse(k[2].toString()) ?? 0.0;
          final l = double.tryParse(k[3].toString()) ?? 0.0;
          final c = double.tryParse(k[4].toString()) ?? 0.0;
          if (h > 0 && l > 0 && c > 0) {
            highs.add(h);
            lows.add(l);
            closes.add(c);
          }
        }
      }

      if (closes.length < 20) return null;

      // 1. РОЗРАХУНОК СМУГ БОЛЛІНДЖЕРА (SMA 20, 2 StdDev)
      final last20 = closes.sublist(closes.length - 20);
      final double sma20 = last20.reduce((a, b) => a + b) / 20.0;

      double varianceSum = 0.0;
      for (final p in last20) {
        varianceSum += math.pow(p - sma20, 2);
      }
      final double stdDev = math.sqrt(varianceSum / 20.0);
      final double upperBand = sma20 + (2.0 * stdDev);
      final double lowerBand = math.max(0.000001, sma20 - (2.0 * stdDev));

      // 2. ІСТОРИЧНІ ВЕРШИНИ ТА ДНО (Екстремуми за 100 днів)
      double globalPeak = highs.reduce(math.max);
      double globalBottom = lows.reduce(math.min);

      // Локальні Swing Highs (піки, вищі за сусідні дні)
      final List<double> localHighs = [];
      for (int i = 1; i < highs.length - 1; i++) {
        if (highs[i] >= highs[i - 1] && highs[i] >= highs[i + 1]) {
          localHighs.add(highs[i]);
        }
      }

      // Локальні Swing Lows (днища, нижчі за сусідні дні)
      final List<double> localLows = [];
      for (int i = 1; i < lows.length - 1; i++) {
        if (lows[i] <= lows[i - 1] && lows[i] <= lows[i + 1]) {
          localLows.add(lows[i]);
        }
      }

      // Знаходимо найближчий опір (Swing High вище поточної ціни)
      localHighs.sort();
      double swingHigh = globalPeak;
      for (final h in localHighs) {
        if (h > currentPrice * 1.03) {
          swingHigh = h;
          break;
        }
      }

      // Знаходимо найближчу підтримку (Swing Low нижче поточної ціни)
      localLows.sort((a, b) => b.compareTo(a)); // спадання
      double swingLow = globalBottom;
      for (final l in localLows) {
        if (l < currentPrice * 0.97) {
          swingLow = l;
          break;
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
      );
    } catch (_) {
      return null;
    }
  }

  TpSlInfo _buildTpSlFromIndicators({
    required double entryPrice,
    required double currentPrice,
    required _CachedTechnicalData tech,
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

    // 2. Розрахунок 3 ШАРІВ ТЕЙК-ПРОФІТУ (Take-Profit Layers)
    // Шар 1: Верхня межа Боллінджера (якщо вже вище неї — беремо +8% від поточної)
    double tp1 = tech.bollingerUpper > currentPrice * 1.02
        ? tech.bollingerUpper
        : double.parse((currentPrice * 1.08).toStringAsFixed(4));

    // Шар 2: Опір структури (Swing High). Повинен бути вищим за TP1 хоча б на 3%
    double tp2 = tech.swingHigh > tp1 * 1.03
        ? tech.swingHigh
        : double.parse((tp1 * 1.18).toStringAsFixed(4));

    // Шар 3: Глобальна вершина 100d / ATH / розширення циклу
    double tp3 = tech.globalPeak100d > tp2 * 1.03
        ? tech.globalPeak100d
        : double.parse((tp2 * 1.25).toStringAsFixed(4));

    // Відстані до TP
    final distTp1 = currentPrice > 0 ? (((tp1 - currentPrice) / currentPrice) * 100) : 0.0;
    final distTp2 = currentPrice > 0 ? (((tp2 - currentPrice) / currentPrice) * 100) : 0.0;
    final distTp3 = currentPrice > 0 ? (((tp3 - currentPrice) / currentPrice) * 100) : 0.0;

    // 3. Зона підбору / закупки на дні (Accumulate Zone)
    // Найкраща ціна підбору — біля нижнього Боллінджера або локальної підтримки
    double accumulatePrice = math.min(tech.bollingerLower, tech.swingLow);
    if (accumulatePrice >= currentPrice * 0.98) {
      accumulatePrice = currentPrice * 0.94; // як мінімум 6% просідання
    }
    accumulatePrice = double.parse(accumulatePrice.toStringAsFixed(4));
    final distToAccumulate = currentPrice > 0 ? (((currentPrice - accumulatePrice) / currentPrice) * 100) : 0.0;

    // 4. Структурний Стоп-Лосс: ставимо на 3% нижче за локальне дно (Swing Low)
    double stopLoss = double.parse((tech.swingLow * 0.97).toStringAsFixed(4));
    if (stopLoss >= currentPrice * 0.98) {
      stopLoss = double.parse((currentPrice * 0.91).toStringAsFixed(4));
    }
    final distSl = currentPrice > 0 ? (((currentPrice - stopLoss) / currentPrice) * 100) : 0.0;
    final stopReason = '-3% нижче локальної підтримки (\$${tech.swingLow}) для захисту від вибивання сквизом';

    return TpSlInfo(
      entryPrice: entryPrice,
      tp1: tp1,
      tp1Pct: 30, // 30% позиції фіксуємо на першому шарі
      distToTp1Pct: double.parse(distTp1.toStringAsFixed(1)),
      tp1Label: 'Шар 1: Верхній Боллінджер',
      tp2: tp2,
      tp2Pct: 35, // 35% позиції на локальному супротиві
      distToTp2Pct: double.parse(distTp2.toStringAsFixed(1)),
      tp2Label: 'Шар 2: Опір структури (Swing High)',
      tp3: tp3,
      tp3Pct: 35, // 35% залишку на глобальній вершині
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
      accumulatePrice: accumulatePrice,
      distToAccumulatePct: double.parse(distToAccumulate.toStringAsFixed(1)),
    );
  }

  TpSlInfo _generateFallbackTpSl(double entryPrice, double currentPrice) {
    final tp1 = double.parse((currentPrice * 1.30).toStringAsFixed(4));
    final tp2 = double.parse((currentPrice * 1.70).toStringAsFixed(4));
    final tp3 = double.parse((currentPrice * 2.50).toStringAsFixed(4));
    final stopLoss = double.parse((currentPrice * 0.85).toStringAsFixed(4));

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
      stopReason: '-15% від поточної ціни (базовий ризик-менеджмент)',
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
    );
  }
}
