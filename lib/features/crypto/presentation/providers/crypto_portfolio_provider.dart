import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../settings/data/settings_repository.dart';
import '../../data/binance_service.dart';
import '../../data/binance_websocket_service.dart';
import '../../data/crypto_technical_analysis_service.dart';
import '../../data/web3_service.dart';
import '../../data/crypto_pricing_service.dart';
import '../../data/groq_ai_service.dart';
import '../../data/crypto_repository.dart';
import '../../data/models/crypto_models.dart';
import '../../data/crypto_portfolio_history_service.dart';
import '../../data/crypto_market_scanner_service.dart';

enum TimePeriod { h24, d7, d30, d90, y1, all }

class CryptoPortfolioState {
  final bool isLoading;
  final bool isAuditing;
  final bool isScanningMarket;
  final String? scanProgressStatus;
  final double scanProgress;
  final bool isLive;
  final PortfolioOverview overview;
  final Map<String, double> binanceSpot;
  final double binanceFuturesMargin;
  final double binanceFuturesPnl;
  final List<BinancePositionItem> binanceFuturesPositions;
  final List<BinanceEarnItem> binanceEarnItems;
  final List<Web3Asset> solanaAssets;
  final List<Web3Asset> evmAssets;
  final List<DcaTransaction> dcaTransactions;
  final TimePeriod selectedPeriod;
  final PortfolioHistoricalDataset? historicalDataset;
  final GroqAuditReport? auditReport;
  final AiMarketRadarReport? radarReport;
  final String? errorMessage;
  final DateTime? lastUpdated;

  CryptoPortfolioState({
    required this.isLoading,
    required this.isAuditing,
    this.isScanningMarket = false,
    this.scanProgressStatus,
    this.scanProgress = 0.0,
    required this.isLive,
    required this.overview,
    required this.binanceSpot,
    required this.binanceFuturesMargin,
    required this.binanceFuturesPnl,
    required this.binanceFuturesPositions,
    required this.binanceEarnItems,
    required this.solanaAssets,
    required this.evmAssets,
    required this.dcaTransactions,
    required this.selectedPeriod,
    this.historicalDataset,
    this.auditReport,
    this.radarReport,
    this.errorMessage,
    this.lastUpdated,
  });

  factory CryptoPortfolioState.initial() {
    return CryptoPortfolioState(
      isLoading: false,
      isAuditing: false,
      isScanningMarket: false,
      scanProgressStatus: null,
      scanProgress: 0.0,
      isLive: false,
      overview: PortfolioOverview.empty(),
      binanceSpot: {},
      binanceFuturesMargin: 0.0,
      binanceFuturesPnl: 0.0,
      binanceFuturesPositions: [],
      binanceEarnItems: [],
      solanaAssets: [],
      evmAssets: [],
      dcaTransactions: [],
      selectedPeriod: TimePeriod.h24,
      historicalDataset: null,
      auditReport: null,
      radarReport: null,
      errorMessage: null,
      lastUpdated: null,
    );
  }

  CryptoPortfolioState copyWith({
    bool? isLoading,
    bool? isAuditing,
    bool? isScanningMarket,
    String? scanProgressStatus,
    double? scanProgress,
    bool? isLive,
    PortfolioOverview? overview,
    Map<String, double>? binanceSpot,
    double? binanceFuturesMargin,
    double? binanceFuturesPnl,
    List<BinancePositionItem>? binanceFuturesPositions,
    List<BinanceEarnItem>? binanceEarnItems,
    List<Web3Asset>? solanaAssets,
    List<Web3Asset>? evmAssets,
    List<DcaTransaction>? dcaTransactions,
    TimePeriod? selectedPeriod,
    PortfolioHistoricalDataset? historicalDataset,
    GroqAuditReport? auditReport,
    AiMarketRadarReport? radarReport,
    String? errorMessage,
    DateTime? lastUpdated,
  }) {
    return CryptoPortfolioState(
      isLoading: isLoading ?? this.isLoading,
      isAuditing: isAuditing ?? this.isAuditing,
      isScanningMarket: isScanningMarket ?? this.isScanningMarket,
      scanProgressStatus: scanProgressStatus ?? this.scanProgressStatus,
      scanProgress: scanProgress ?? this.scanProgress,
      isLive: isLive ?? this.isLive,
      overview: overview ?? this.overview,
      binanceSpot: binanceSpot ?? this.binanceSpot,
      binanceFuturesMargin: binanceFuturesMargin ?? this.binanceFuturesMargin,
      binanceFuturesPnl: binanceFuturesPnl ?? this.binanceFuturesPnl,
      binanceFuturesPositions: binanceFuturesPositions ?? this.binanceFuturesPositions,
      binanceEarnItems: binanceEarnItems ?? this.binanceEarnItems,
      solanaAssets: solanaAssets ?? this.solanaAssets,
      evmAssets: evmAssets ?? this.evmAssets,
      dcaTransactions: dcaTransactions ?? this.dcaTransactions,
      selectedPeriod: selectedPeriod ?? this.selectedPeriod,
      historicalDataset: historicalDataset ?? this.historicalDataset,
      auditReport: auditReport ?? this.auditReport,
      radarReport: radarReport ?? this.radarReport,
      errorMessage: errorMessage,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }

  /// Допоміжний метод групування транзакцій
  List<DcaGroupedCoin> _groupTransactions(List<DcaTransaction> txs) {
    if (txs.isEmpty) return [];

    final Map<String, List<DcaTransaction>> grouped = {};
    for (final tx in txs) {
      final sym = tx.symbol.toUpperCase();
      grouped.putIfAbsent(sym, () => []).add(tx);
    }

    final List<DcaGroupedCoin> result = [];

    for (final sym in grouped.keys) {
      final txList = grouped[sym]!;
      // Знаходимо актуальну ціну
      double currentPrice = 0.0;
      final match = overview.holdings.where((h) => h.symbol.toUpperCase() == sym);
      if (match.isNotEmpty) {
        currentPrice = match.first.currentPrice;
      }
      if (currentPrice <= 0 && txList.isNotEmpty) {
        currentPrice = txList.first.buyPrice;
      }

      double totalAmount = 0.0;
      double totalCost = 0.0;
      final List<DcaTrancheItem> tranches = [];

      for (final tx in txList) {
        totalAmount += tx.amount;
        final effectiveBuyPrice = tx.buyPrice > 0 ? tx.buyPrice : currentPrice;
        final cost = (tx.amount * effectiveBuyPrice) + tx.fee;
        totalCost += cost;

        final tranchePnlPct = effectiveBuyPrice > 0
            ? ((currentPrice - effectiveBuyPrice) / effectiveBuyPrice) * 100
            : 0.0;
        final tranchePnlUsd = tx.amount * (currentPrice - effectiveBuyPrice);

        tranches.add(DcaTrancheItem(
          id: tx.id,
          symbol: sym,
          amount: tx.amount,
          buyPrice: effectiveBuyPrice,
          fee: tx.fee,
          date: tx.txDate,
          walletType: tx.walletType,
          notes: tx.notes,
          currentPrice: currentPrice,
          pnlPct: double.parse(tranchePnlPct.toStringAsFixed(2)),
          pnlUsd: double.parse(tranchePnlUsd.toStringAsFixed(2)),
        ));
      }

      final avgEntryPrice = totalAmount > 0 ? totalCost / totalAmount : 0.0;
      final totalValueUsd = totalAmount * currentPrice;
      final pnlUsd = totalValueUsd - totalCost;
      final pnlPct = totalCost > 0 ? (pnlUsd / totalCost) * 100 : 0.0;

      // Сортуємо транші всередині монети від найновіших до найстаріших
      tranches.sort((a, b) => b.date.compareTo(a.date));

      result.add(DcaGroupedCoin(
        symbol: sym,
        totalAmount: totalAmount,
        avgEntryPrice: double.parse(avgEntryPrice.toStringAsFixed(4)),
        totalCost: double.parse(totalCost.toStringAsFixed(2)),
        currentPrice: currentPrice,
        totalValueUsd: double.parse(totalValueUsd.toStringAsFixed(2)),
        pnlUsd: double.parse(pnlUsd.toStringAsFixed(2)),
        pnlPct: double.parse(pnlPct.toStringAsFixed(2)),
        tranches: tranches,
      ));
    }

    // Сортуємо за загальною цінністю в доларах від найбільшої до найменшої
    result.sort((a, b) => b.totalValueUsd.compareTo(a.totalValueUsd));
    return result;
  }

  /// Всі груповані DCA монети
  List<DcaGroupedCoin> get groupedDcaCoins => _groupTransactions(dcaTransactions);

  /// Тільки транзакції з біржі Binance (Spot & Convert FIFO)
  List<DcaGroupedCoin> get binanceDcaCoins => _groupTransactions(
        dcaTransactions.where((t) => t.walletType == 'Binance Spot' || t.walletType == 'BINANCE').toList(),
      );

  /// Тільки додані користувачем власноруч (Ручні DCA)
  List<DcaGroupedCoin> get manualDcaCoins => _groupTransactions(
        dcaTransactions.where((t) => t.walletType != 'Binance Spot' && t.walletType != 'BINANCE').toList(),
      );

  /// Підсумкові показники для DCA картки
  ({double totalInvested, double totalValue, double totalPnlUsd, double totalPnlPct}) get dcaTotals {
    double totalInvested = 0.0;
    double totalValue = 0.0;
    for (final c in groupedDcaCoins) {
      totalInvested += c.totalCost;
      totalValue += c.totalValueUsd;
    }
    final totalPnlUsd = totalValue - totalInvested;
    final totalPnlPct = totalInvested > 0 ? (totalPnlUsd / totalInvested) * 100 : 0.0;
    return (
      totalInvested: totalInvested,
      totalValue: totalValue,
      totalPnlUsd: totalPnlUsd,
      totalPnlPct: totalPnlPct,
    );
  }
}


final cryptoRepositoryProvider = Provider<CryptoRepository>((ref) => CryptoRepository());
final cryptoPricingServiceProvider = Provider<CryptoPricingService>((ref) => CryptoPricingService());

final cryptoPortfolioProvider =
    StateNotifierProvider<CryptoPortfolioNotifier, CryptoPortfolioState>((ref) {
  final repo = ref.watch(cryptoRepositoryProvider);
  final pricing = ref.watch(cryptoPricingServiceProvider);
  return CryptoPortfolioNotifier(ref, repo, pricing);
});

class CryptoPortfolioNotifier extends StateNotifier<CryptoPortfolioState> {
  final Ref _ref;
  final CryptoRepository _repo;
  final CryptoPricingService _pricing;
  final BinanceWebSocketService _wsService = BinanceWebSocketService();
  final CryptoTechnicalAnalysisService _techService = CryptoTechnicalAnalysisService();
  final CryptoPortfolioHistoryService _historyService = CryptoPortfolioHistoryService();

  final Map<String, ({double price, double chg24h})> _bufferedTicks = {};
  Timer? _throttleTimer;

  CryptoPortfolioNotifier(this._ref, this._repo, this._pricing)
      : super(CryptoPortfolioState.initial()) {
    refreshPortfolio();
  }

  Future<void> changePeriod(TimePeriod period) async {
    state = state.copyWith(selectedPeriod: period);
    if (state.overview.holdings.isNotEmpty || state.binanceFuturesMargin > 0) {
      try {
        final dataset = await _historyService.generateHistoricalData(
          holdings: state.overview.holdings,
          futuresMargin: state.binanceFuturesMargin,
          futuresPnl: state.binanceFuturesPnl,
          futuresPositions: state.binanceFuturesPositions,
          period: period,
        );
        state = state.copyWith(historicalDataset: dataset);
      } catch (_) {}
    }
  }

  Future<void> refreshPortfolio() async {
    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      final settings = await _ref.read(settingsRepositoryProvider).getSettings();

      final binanceSvc = BinanceService(
        apiKey: settings.binanceApiKey,
        apiSecret: settings.binanceApiSecret,
      );
      final web3Svc = Web3Service();

      // 1. Паралельне завантаження даних бірж, блокчейнів, цін та DCA
      final spotFuture = binanceSvc.getSpotBalances();
      final futuresFuture = binanceSvc.getFuturesData();
      final earnFuture = binanceSvc.getSimpleEarnHoldings();
      final solanaFuture = web3Svc.getSolanaAssets(settings.solanaAddress ?? '');
      final evmFuture = web3Svc.getEvmAssets(settings.evmAddress ?? '');
      final dcaTxsFuture = _repo.getDcaTransactions();
      final dcaSummaryFuture = _repo.getAggregatedDcaSummary();
      final pricesFuture = _pricing.getPricesAndChanges();

      final results = await Future.wait([
        spotFuture,
        futuresFuture,
        earnFuture,
        solanaFuture,
        evmFuture,
        dcaTxsFuture,
        dcaSummaryFuture,
        pricesFuture,
      ]);

      final spotBalances = results[0] as Map<String, double>;
      final futuresData = results[1] as Map<String, dynamic>;
      final earnItems = results[2] as List<BinanceEarnItem>;
      final solanaAssets = results[3] as List<Web3Asset>;
      final evmAssets = results[4] as List<Web3Asset>;
      List<DcaTransaction> dcaTxs = results[5] as List<DcaTransaction>;
      Map<String, DcaAggregatedSummary> dcaSummary = results[6] as Map<String, DcaAggregatedSummary>;
      final priceMap = results[7] as Map<String, CryptoPriceData>;

      // Автоматична синхронізація угод Binance Spot + Convert (FIFO)
      if (binanceSvc.isConfigured && spotBalances.isNotEmpty) {
        try {
          final spotSymbols = spotBalances.keys.toList();
          final simplePrices = priceMap.map((k, v) => MapEntry(k, v.price));
          final binanceTranches = await binanceSvc.getSpotTradeHistoryWithFifo(
            spotSymbols,
            currentSpotBalances: spotBalances,
            currentPrices: simplePrices,
            existingTranches: dcaTxs,
          );
          if (binanceTranches.isNotEmpty) {
            await _repo.syncBinanceDcaTranches(binanceTranches);
            dcaTxs = await _repo.getDcaTransactions();
            dcaSummary = await _repo.getAggregatedDcaSummary();
          }
        } catch (_) {}
      }

      final futuresMargin = futuresData['totalMarginUsd'] as double? ?? 0.0;
      final futuresPnl = futuresData['unrealizedPnlUsd'] as double? ?? 0.0;
      final futuresPositions = futuresData['positions'] as List<BinancePositionItem>? ?? [];

      // 2. Агрегація активів за символами
      final Map<String, double> aggregatedAmounts = {};
      final Map<String, List<String>> sourcesMap = {};

      void addAsset(String symbol, double amount, String source) {
        if (amount <= 0.000001) return;
        final sym = symbol.toUpperCase();
        aggregatedAmounts[sym] = (aggregatedAmounts[sym] ?? 0.0) + amount;
        sourcesMap.putIfAbsent(sym, () => []);
        if (!sourcesMap[sym]!.contains(source)) {
          sourcesMap[sym]!.add(source);
        }
      }

      // Додаємо зі Споту
      spotBalances.forEach((sym, amt) => addAsset(sym, amt, 'Binance Spot'));

      // Додаємо із Solana
      for (final a in solanaAssets) {
        addAsset(a.symbol, a.amount, 'Solana');
      }

      // Додаємо із EVM
      for (final a in evmAssets) {
        addAsset(a.symbol, a.amount, 'EVM / MetaMask');
      }

      // Додаємо із Earn
      for (final e in earnItems) {
        addAsset(e.symbol, e.amount, 'Binance Earn');
      }

      // Додаємо із ручного DCA
      for (final sym in dcaSummary.keys) {
        final dcaItem = dcaSummary[sym]!;
        // Якщо монета не підтягнута з гаманців, враховуємо ручну кількість
        if (!aggregatedAmounts.containsKey(sym)) {
          addAsset(sym, dcaItem.totalAmount, 'Ручний облік (DCA)');
        }
      }

      // 3. Технічний аналіз 1D свічок, Смуг Боллінджера та шарів фіксації
      final Map<String, TpSlInfo> tpSlMap = {};
      final List<Future<void>> techTasks = [];

      for (final sym in aggregatedAmounts.keys) {
        final priceData = priceMap[sym];
        final currentPrice = priceData?.price ?? (kStablecoins.contains(sym) ? 1.0 : 0.0);
        final dca = dcaSummary[sym];
        final avgEntryPrice = (dca != null && dca.avgEntryPrice > 0)
            ? dca.avgEntryPrice
            : currentPrice;

        techTasks.add(() async {
          final tpSl = await _techService.analyzeSymbol(
            symbol: sym,
            entryPrice: avgEntryPrice,
            currentPrice: currentPrice,
          );
          tpSlMap[sym] = tpSl;
        }());
      }

      await Future.wait(techTasks);

      // 4. Розрахунок вартості, змін та PnL для кожного активу
      double totalPortfolioUsd = 0.0;
      double totalPortfolioPnlUsd = futuresPnl;
      final List<HoldingItem> holdings = [];

      for (final sym in aggregatedAmounts.keys) {
        final amount = aggregatedAmounts[sym]!;
        final priceData = priceMap[sym];
        final currentPrice = priceData?.price ?? (kStablecoins.contains(sym) ? 1.0 : 0.0);
        final totalUsd = amount * currentPrice;

        // Середня точка входу
        final dca = dcaSummary[sym];
        final avgEntryPrice = (dca != null && dca.avgEntryPrice > 0)
            ? dca.avgEntryPrice
            : currentPrice;

        final costUsd = amount * avgEntryPrice;
        final pnlUsd = totalUsd - costUsd;
        final pnlPct = costUsd > 0 ? ((pnlUsd / costUsd) * 100) : 0.0;

        final tpSl = tpSlMap[sym] ?? CryptoPricingService.calculateTpSl(avgEntryPrice, currentPrice);

        holdings.add(HoldingItem(
          symbol: sym,
          amount: amount,
          currentPrice: currentPrice,
          totalUsd: totalUsd,
          avgEntryPrice: avgEntryPrice,
          pnlUsd: double.parse(pnlUsd.toStringAsFixed(2)),
          pnlPct: double.parse(pnlPct.toStringAsFixed(2)),
          chg24h: priceData?.chg24h ?? 0.0,
          chg7d: priceData?.chg7d ?? 0.0,
          chg30d: priceData?.chg30d ?? 0.0,
          chg1y: priceData?.chg1y ?? 0.0,
          sharePct: 0.0, // розрахується після суми
          sources: sourcesMap[sym] ?? [],
          tpSl: tpSl,
        ));

        totalPortfolioUsd += totalUsd;
        totalPortfolioPnlUsd += pnlUsd;
      }

      // Додаємо ф'ючерсну маржу до загального капіталу
      totalPortfolioUsd += futuresMargin;

      // Розрахунок відсоткової частки кожної монети в портфелі
      final List<HoldingItem> normalizedHoldings = [];
      for (final h in holdings) {
        final share = totalPortfolioUsd > 0
            ? double.parse(((h.totalUsd / totalPortfolioUsd) * 100).toStringAsFixed(1))
            : 0.0;
        normalizedHoldings.add(HoldingItem(
          symbol: h.symbol,
          amount: h.amount,
          currentPrice: h.currentPrice,
          totalUsd: h.totalUsd,
          avgEntryPrice: h.avgEntryPrice,
          pnlUsd: h.pnlUsd,
          pnlPct: h.pnlPct,
          chg24h: h.chg24h,
          chg7d: h.chg7d,
          chg30d: h.chg30d,
          chg1y: h.chg1y,
          sharePct: share,
          sources: h.sources,
          tpSl: h.tpSl,
        ));
      }

      // Сортуємо від найбільших до найменших позицій
      normalizedHoldings.sort((a, b) => b.totalUsd.compareTo(a.totalUsd));

      final cashRatio = CryptoPricingService.calculateCashRatio(normalizedHoldings);
      final totalPnlPct = (totalPortfolioUsd - totalPortfolioPnlUsd) > 0
          ? double.parse(((totalPortfolioPnlUsd / (totalPortfolioUsd - totalPortfolioPnlUsd)) * 100).toStringAsFixed(2))
          : 0.0;

      final overview = PortfolioOverview(
        totalNetWorthUsd: double.parse(totalPortfolioUsd.toStringAsFixed(2)),
        totalPnlUsd: double.parse(totalPortfolioPnlUsd.toStringAsFixed(2)),
        totalPnlPct: totalPnlPct,
        cashRatio: cashRatio,
        holdingsCount: normalizedHoldings.length,
        holdings: normalizedHoldings,
      );

      PortfolioHistoricalDataset? historicalDataset;
      try {
        historicalDataset = await _historyService.generateHistoricalData(
          holdings: normalizedHoldings,
          futuresMargin: futuresMargin,
          futuresPnl: futuresPnl,
          futuresPositions: futuresPositions,
          period: state.selectedPeriod,
        );
      } catch (_) {}

      state = state.copyWith(
        isLoading: false,
        isLive: _wsService.isConnected,
        overview: overview,
        binanceSpot: spotBalances,
        binanceFuturesMargin: futuresMargin,
        binanceFuturesPnl: futuresPnl,
        binanceFuturesPositions: futuresPositions,
        binanceEarnItems: earnItems,
        solanaAssets: solanaAssets,
        evmAssets: evmAssets,
        dcaTransactions: dcaTxs,
        historicalDataset: historicalDataset,
        lastUpdated: DateTime.now(),
      );

      // Підключаємо / оновлюємо підписку на WebSocket стрім для монет портфеля
      _updateWsSubscriptions(normalizedHoldings);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Помилка оновлення портфелю: $e',
      );
    }
  }

  void _startWs(List<String> symbols) {
    _wsService.connect(
      symbols: symbols,
      onTick: (symbol, price, chg24h) {
        _bufferedTicks[symbol] = (price: price, chg24h: chg24h);
        _scheduleThrottleFlush();
      },
      onStatusChanged: (connected) {
        if (state.isLive != connected) {
          state = state.copyWith(isLive: connected);
        }
      },
    );
  }

  void _scheduleThrottleFlush() {
    if (_throttleTimer?.isActive ?? false) return;
    _throttleTimer = Timer(const Duration(milliseconds: 700), () {
      _flushBufferedTicks();
    });
  }

  void _flushBufferedTicks() {
    if (_bufferedTicks.isEmpty || state.overview.holdings.isEmpty) return;

    final ticks = Map<String, ({double price, double chg24h})>.from(_bufferedTicks);
    _bufferedTicks.clear();

    final currentHoldings = state.overview.holdings;
    final updatedHoldings = <HoldingItem>[];
    double totalPortfolioUsd = 0.0;
    double totalPortfolioPnlUsd = state.binanceFuturesPnl;
    bool anyChanged = false;

    for (final h in currentHoldings) {
      final tick = ticks[h.symbol];
      if (tick != null) {
        anyChanged = true;
        final newPrice = tick.price;
        final newChg24h = tick.chg24h;
        final newTotalUsd = h.amount * newPrice;
        final costUsd = h.amount * h.avgEntryPrice;
        final newPnlUsd = newTotalUsd - costUsd;
        final newPnlPct = costUsd > 0 ? ((newPnlUsd / costUsd) * 100) : 0.0;
        final oldTpSl = h.tpSl;
        final distTp1 = newPrice > 0 ? (((oldTpSl.tp1 - newPrice) / newPrice) * 100) : 0.0;
        final distTp2 = newPrice > 0 ? (((oldTpSl.tp2 - newPrice) / newPrice) * 100) : 0.0;
        final distTp3 = newPrice > 0 ? (((oldTpSl.tp3 - newPrice) / newPrice) * 100) : 0.0;
        final distSl = newPrice > 0 ? (((newPrice - oldTpSl.stopLoss) / newPrice) * 100) : 0.0;
        final distAcc = newPrice > 0 ? (((newPrice - oldTpSl.accumulatePrice) / newPrice) * 100) : 0.0;

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

        final newTpSl = TpSlInfo(
          entryPrice: oldTpSl.entryPrice,
          tp1: oldTpSl.tp1,
          tp1Pct: oldTpSl.tp1Pct,
          distToTp1Pct: double.parse(distTp1.toStringAsFixed(1)),
          tp1Label: oldTpSl.tp1Label,
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
        );

        updatedHoldings.add(HoldingItem(
          symbol: h.symbol,
          amount: h.amount,
          currentPrice: newPrice,
          totalUsd: newTotalUsd,
          avgEntryPrice: h.avgEntryPrice,
          pnlUsd: double.parse(newPnlUsd.toStringAsFixed(2)),
          pnlPct: double.parse(newPnlPct.toStringAsFixed(2)),
          chg24h: newChg24h,
          chg7d: h.chg7d,
          chg30d: h.chg30d,
          chg1y: h.chg1y,
          sharePct: h.sharePct,
          sources: h.sources,
          tpSl: newTpSl,
        ));

        totalPortfolioUsd += newTotalUsd;
        totalPortfolioPnlUsd += newPnlUsd;
      } else {
        updatedHoldings.add(h);
        totalPortfolioUsd += h.totalUsd;
        final costUsd = h.amount * h.avgEntryPrice;
        totalPortfolioPnlUsd += (h.totalUsd - costUsd);
      }
    }

    if (!anyChanged) return;

    totalPortfolioUsd += state.binanceFuturesMargin;

    // Рекалькулюємо частки в портфелі (sharePct)
    final List<HoldingItem> normalizedHoldings = [];
    for (final h in updatedHoldings) {
      final share = totalPortfolioUsd > 0
          ? double.parse(((h.totalUsd / totalPortfolioUsd) * 100).toStringAsFixed(1))
          : 0.0;
      normalizedHoldings.add(HoldingItem(
        symbol: h.symbol,
        amount: h.amount,
        currentPrice: h.currentPrice,
        totalUsd: h.totalUsd,
        avgEntryPrice: h.avgEntryPrice,
        pnlUsd: h.pnlUsd,
        pnlPct: h.pnlPct,
        chg24h: h.chg24h,
        chg7d: h.chg7d,
        chg30d: h.chg30d,
        chg1y: h.chg1y,
        sharePct: share,
        sources: h.sources,
        tpSl: h.tpSl,
      ));
    }

    normalizedHoldings.sort((a, b) => b.totalUsd.compareTo(a.totalUsd));

    final cashRatio = CryptoPricingService.calculateCashRatio(normalizedHoldings);
    final totalPnlPct = (totalPortfolioUsd - totalPortfolioPnlUsd) > 0
        ? double.parse(((totalPortfolioPnlUsd / (totalPortfolioUsd - totalPortfolioPnlUsd)) * 100).toStringAsFixed(2))
        : 0.0;

    final newOverview = PortfolioOverview(
      totalNetWorthUsd: double.parse(totalPortfolioUsd.toStringAsFixed(2)),
      totalPnlUsd: double.parse(totalPortfolioPnlUsd.toStringAsFixed(2)),
      totalPnlPct: totalPnlPct,
      cashRatio: cashRatio,
      holdingsCount: normalizedHoldings.length,
      holdings: normalizedHoldings,
    );

    state = state.copyWith(
      overview: newOverview,
      isLive: _wsService.isConnected,
      lastUpdated: DateTime.now(),
    );
  }

  void _updateWsSubscriptions(List<HoldingItem> holdings) {
    final symbols = holdings.map((h) => h.symbol).toList();
    if (_wsService.isConnected) {
      _wsService.updateSymbols(symbols);
    } else {
      _startWs(symbols);
    }
  }

  void startLiveStreaming() {
    if (state.overview.holdings.isNotEmpty) {
      _updateWsSubscriptions(state.overview.holdings);
    }
  }

  void stopLiveStreaming() {
    _wsService.disconnect();
    state = state.copyWith(isLive: false);
  }

  Future<void> runAiAudit() async {
    if (state.overview.holdings.isEmpty) return;

    state = state.copyWith(isAuditing: true);

    try {
      final settings = await _ref.read(settingsRepositoryProvider).getSettings();
      final groqSvc = GroqAiService(apiKey: settings.groqApiKey);

      final report = await groqSvc.auditPortfolio(
        holdings: state.overview.holdings,
        cashRatio: state.overview.cashRatio,
      );

      state = state.copyWith(
        isAuditing: false,
        auditReport: report,
      );
    } catch (e) {
      state = state.copyWith(
        isAuditing: false,
        errorMessage: 'Помилка AI-аудиту: $e',
      );
    }
  }

  Future<void> addDcaTransaction(DcaTransaction tx) async {
    await _repo.addDcaTransaction(tx);
    await refreshPortfolio();
  }

  Future<void> deleteDcaTransaction(String id) async {
    await _repo.deleteDcaTransaction(id);
    await refreshPortfolio();
  }

  /// Ручний виклик повної синхронізації угод з Binance Spot (FIFO)
  Future<void> syncBinanceDca() async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final settings = await _ref.read(settingsRepositoryProvider).getSettings();
      final binanceSvc = BinanceService(
        apiKey: settings.binanceApiKey,
        apiSecret: settings.binanceApiSecret,
      );

      if (!binanceSvc.isConfigured) {
        state = state.copyWith(
          isLoading: false,
          errorMessage: 'Вкажіть API ключ та Secret біржі Binance у Налаштуваннях.',
        );
        return;
      }

      final spotBalances = await binanceSvc.getSpotBalances();
      final spotSymbols = spotBalances.keys.toList();
      if (spotSymbols.isEmpty) {
        state = state.copyWith(
          isLoading: false,
          errorMessage: 'На спотовому балансі Binance немає активних монет для синхронізації.',
        );
        return;
      }

      final currentPrices = {for (final h in state.overview.holdings) h.symbol.toUpperCase(): h.currentPrice};
      final binanceTranches = await binanceSvc.getSpotTradeHistoryWithFifo(
        spotSymbols,
        currentSpotBalances: spotBalances,
        currentPrices: currentPrices,
        existingTranches: state.dcaTransactions,
      );
      await _repo.syncBinanceDcaTranches(binanceTranches);

      await refreshPortfolio();
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Помилка синхронізації угод з Binance: $e',
      );
    }
  }

  /// Запуск повного AI-сканування ринку (350+ спотових пар Binance)
  Future<void> scanMarketRadar() async {
    state = state.copyWith(
      isScanningMarket: true,
      scanProgressStatus: 'Підключення до ринку Binance...',
      scanProgress: 0.05,
      errorMessage: null,
    );

    try {
      final settings = await _ref.read(settingsRepositoryProvider).getSettings();
      final groq = GroqAiService(apiKey: settings.groqApiKey);
      final scanner = CryptoMarketScannerService(groqService: groq);

      final report = await scanner.scanMarket(
        onProgress: (status, progress) {
          state = state.copyWith(
            scanProgressStatus: status,
            scanProgress: progress,
          );
        },
      );

      state = state.copyWith(
        isScanningMarket: false,
        scanProgressStatus: null,
        scanProgress: 1.0,
        radarReport: report,
      );
    } catch (e) {
      state = state.copyWith(
        isScanningMarket: false,
        scanProgressStatus: null,
        errorMessage: 'Помилка під час сканування ринку: $e',
      );
    }
  }

  @override
  void dispose() {
    _throttleTimer?.cancel();
    _wsService.disconnect();
    super.dispose();
  }
}
