import 'dart:convert';
import 'package:http/http.dart' as http;
import 'models/crypto_models.dart';
import '../presentation/providers/crypto_portfolio_provider.dart';

class CryptoPortfolioHistoryService {
  final Map<String, List<List<dynamic>>> _klineCache = {};
  DateTime? _lastCacheTime;

  /// Отримує свічки для символу з Binance API
  Future<List<List<dynamic>>> _fetchKlines(String symbol, String interval, int limit) async {
    final sym = symbol.toUpperCase();
    final cacheKey = '${sym}_${interval}_$limit';

    final now = DateTime.now();
    if (_lastCacheTime != null && now.difference(_lastCacheTime!).inMinutes < 15) {
      if (_klineCache.containsKey(cacheKey)) {
        return _klineCache[cacheKey]!;
      }
    }

    try {
      final pair = sym == 'USDT' || sym == 'USDC' || sym == 'FDUSD' ? 'BTCUSDT' : '${sym}USDT';
      final url = Uri.parse(
        'https://api.binance.com/api/v3/klines?symbol=$pair&interval=$interval&limit=$limit',
      );
      final resp = await http.get(url).timeout(const Duration(seconds: 5));
      if (resp.statusCode == 200) {
        final data = json.decode(resp.body) as List<dynamic>;
        final typedList = data.map((e) => e as List<dynamic>).toList();
        _klineCache[cacheKey] = typedList;
        _lastCacheTime = now;
        return typedList;
      }
    } catch (_) {
      // Офлайн або помилка мережі
    }

    return [];
  }

  /// Генерує історичний набір даних для Споту, Ф'ючерсів та Загального портфелю
  Future<PortfolioHistoricalDataset> generateHistoricalData({
    required List<HoldingItem> holdings,
    required double futuresMargin,
    required double futuresPnl,
    required List<BinancePositionItem> futuresPositions,
    required TimePeriod period,
  }) async {
    String interval;
    int limit;

    switch (period) {
      case TimePeriod.h24:
        interval = '1h';
        limit = 24;
        break;
      case TimePeriod.d7:
        interval = '4h';
        limit = 42;
        break;
      case TimePeriod.d30:
        interval = '1d';
        limit = 30;
        break;
      case TimePeriod.d90:
        interval = '1d';
        limit = 90;
        break;
      case TimePeriod.y1:
        interval = '1w';
        limit = 52;
        break;
      case TimePeriod.all:
        interval = '1w';
        limit = 100;
        break;
    }

    // 1. Знаходимо ключові символи для споту
    final spotHoldings = holdings.where((h) => h.amount > 0).toList();
    final topSymbols = spotHoldings.take(5).map((h) => h.symbol.toUpperCase()).toSet();
    if (topSymbols.isEmpty) {
      topSymbols.add('BTC');
    }

    // Завантажуємо свічки для топових монет та для BTC (як базового орієнтиру ринку)
    final Map<String, List<List<dynamic>>> candlesMap = {};
    for (final sym in {...topSymbols, 'BTC'}) {
      if (sym != 'USDT' && sym != 'USDC' && sym != 'FDUSD' && sym != 'DAI') {
        final klines = await _fetchKlines(sym, interval, limit);
        if (klines.isNotEmpty) {
          candlesMap[sym] = klines;
        }
      }
    }

    // Базові таймстемпи беремо з BTC або створюємо синтетичні
    final btcCandles = candlesMap['BTC'] ?? (candlesMap.isNotEmpty ? candlesMap.values.first : []);
    final int pointsCount = btcCandles.isNotEmpty ? btcCandles.length : limit;

    final List<ChartPoint> spotPoints = [];
    final List<ChartPoint> futuresPoints = [];
    final List<ChartPoint> totalPoints = [];

    // Розрахунок поточних підсумків для калібрування останньої точки
    double currentSpotTotal = 0.0;
    double spotCostBasis = 0.0;
    for (final h in spotHoldings) {
      currentSpotTotal += h.totalUsd;
      spotCostBasis += h.amount * (h.avgEntryPrice > 0 ? h.avgEntryPrice : h.currentPrice);
    }
    final currentSpotPnl = currentSpotTotal - spotCostBasis;
    final currentSpotPnlPct = spotCostBasis > 0 ? (currentSpotPnl / spotCostBasis) * 100 : 0.0;

    final currentFuturesMargin = futuresMargin;
    final currentFuturesPnl = futuresPnl;
    final futuresCostBasis = (currentFuturesMargin - currentFuturesPnl) > 0
        ? (currentFuturesMargin - currentFuturesPnl)
        : currentFuturesMargin;
    final currentFuturesPnlPct = futuresCostBasis > 0 ? (currentFuturesPnl / futuresCostBasis) * 100 : 0.0;

    final currentTotalBalance = currentSpotTotal + currentFuturesMargin;
    final currentTotalPnl = currentSpotPnl + currentFuturesPnl;
    final totalCostBasis = spotCostBasis + futuresCostBasis;
    final currentTotalPnlPct = totalCostBasis > 0 ? (currentTotalPnl / totalCostBasis) * 100 : 0.0;

    final now = DateTime.now();

    for (int i = 0; i < pointsCount; i++) {
      DateTime pointTime;
      if (btcCandles.isNotEmpty && i < btcCandles.length) {
        final openTimeMs = (btcCandles[i][0] as num).toInt();
        pointTime = DateTime.fromMillisecondsSinceEpoch(openTimeMs);
      } else {
        // Синтетичний таймстемп
        final durationStep = _getStepDuration(period, pointsCount);
        pointTime = now.subtract(durationStep * (pointsCount - 1 - i));
      }

      // 1. Спотова вартість у точці i
      double spotValAtT = 0.0;
      if (spotHoldings.isEmpty) {
        spotValAtT = 0.0;
      } else {
        for (final h in spotHoldings) {
          final sym = h.symbol.toUpperCase();
          if (sym == 'USDT' || sym == 'USDC' || sym == 'DAI' || sym == 'FDUSD') {
            spotValAtT += h.amount;
          } else {
            final candles = candlesMap[sym] ?? candlesMap['BTC'];
            if (candles != null && candles.isNotEmpty) {
              final candleIdx = (i < candles.length) ? i : (candles.length - 1);
              final closePrice = double.tryParse(candles[candleIdx][4]?.toString() ?? '') ?? h.currentPrice;
              spotValAtT += h.amount * closePrice;
            } else {
              spotValAtT += h.totalUsd;
            }
          }
        }
      }

      // Якщо це остання точка — точно прирівнюємо до поточного балансу
      if (i == pointsCount - 1 && currentSpotTotal > 0) {
        spotValAtT = currentSpotTotal;
      }

      final spotPnlAtT = spotValAtT - spotCostBasis;
      final spotPnlPctAtT = spotCostBasis > 0 ? (spotPnlAtT / spotCostBasis) * 100 : 0.0;

      spotPoints.add(ChartPoint(
        timestamp: pointTime,
        balance: double.parse(spotValAtT.toStringAsFixed(2)),
        pnl: double.parse(spotPnlAtT.toStringAsFixed(2)),
        pnlPct: double.parse(spotPnlPctAtT.toStringAsFixed(2)),
      ));

      // 2. Ф'ючерсна маржа та PnL у точці i
      double futuresMarginAtT = currentFuturesMargin;
      double futuresPnlAtT = currentFuturesPnl;

      if (futuresPositions.isNotEmpty) {
        double simulatedPosPnl = 0.0;
        for (final pos in futuresPositions) {
          final cleanSym = pos.symbol.replaceAll('USDT', '').toUpperCase();
          final candles = candlesMap[cleanSym] ?? candlesMap['BTC'];
          if (candles != null && candles.isNotEmpty) {
            final candleIdx = (i < candles.length) ? i : (candles.length - 1);
            final priceAtT = double.tryParse(candles[candleIdx][4]?.toString() ?? '') ?? pos.markPrice;
            final isLong = pos.direction == 'LONG';
            final diff = isLong ? (priceAtT - pos.entryPrice) : (pos.entryPrice - priceAtT);
            simulatedPosPnl += diff * pos.amount;
          } else {
            simulatedPosPnl += pos.unrealizedPnl;
          }
        }
        futuresPnlAtT = simulatedPosPnl;
        futuresMarginAtT = futuresCostBasis + futuresPnlAtT;
        if (futuresMarginAtT < 0) futuresMarginAtT = 0;
      }

      if (i == pointsCount - 1) {
        futuresMarginAtT = currentFuturesMargin;
        futuresPnlAtT = currentFuturesPnl;
      }

      final futuresPnlPctAtT = futuresCostBasis > 0 ? (futuresPnlAtT / futuresCostBasis) * 100 : 0.0;

      futuresPoints.add(ChartPoint(
        timestamp: pointTime,
        balance: double.parse(futuresMarginAtT.toStringAsFixed(2)),
        pnl: double.parse(futuresPnlAtT.toStringAsFixed(2)),
        pnlPct: double.parse(futuresPnlPctAtT.toStringAsFixed(2)),
      ));

      // 3. Загальний портфель у точці i
      final totalBalAtT = spotValAtT + futuresMarginAtT;
      final totalPnlAtT = spotPnlAtT + futuresPnlAtT;
      final totalPnlPctAtT = totalCostBasis > 0 ? (totalPnlAtT / totalCostBasis) * 100 : 0.0;

      totalPoints.add(ChartPoint(
        timestamp: pointTime,
        balance: double.parse(totalBalAtT.toStringAsFixed(2)),
        pnl: double.parse(totalPnlAtT.toStringAsFixed(2)),
        pnlPct: double.parse(totalPnlPctAtT.toStringAsFixed(2)),
      ));
    }

    return PortfolioHistoricalDataset(
      spotPoints: spotPoints,
      futuresPoints: futuresPoints,
      totalPoints: totalPoints,
      spotBalance: currentSpotTotal,
      spotPnlUsd: currentSpotPnl,
      spotPnlPct: currentSpotPnlPct,
      futuresMargin: currentFuturesMargin,
      futuresPnlUsd: currentFuturesPnl,
      futuresPnlPct: currentFuturesPnlPct,
      totalBalance: currentTotalBalance,
      totalPnlUsd: currentTotalPnl,
      totalPnlPct: currentTotalPnlPct,
    );
  }

  Duration _getStepDuration(TimePeriod period, int count) {
    if (count <= 1) return const Duration(hours: 1);
    switch (period) {
      case TimePeriod.h24:
        return const Duration(hours: 1);
      case TimePeriod.d7:
        return const Duration(hours: 4);
      case TimePeriod.d30:
        return const Duration(days: 1);
      case TimePeriod.d90:
        return const Duration(days: 1);
      case TimePeriod.y1:
        return const Duration(days: 7);
      case TimePeriod.all:
        return const Duration(days: 7);
    }
  }
}
