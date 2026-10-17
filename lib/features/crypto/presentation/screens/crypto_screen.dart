import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_theme.dart';
import '../../data/models/crypto_models.dart';
import '../../data/web3_service.dart';
import '../providers/crypto_portfolio_provider.dart';
import '../widgets/crypto_net_worth_card.dart';
import '../widgets/crypto_allocation_chart.dart';
import '../widgets/holding_list_tile.dart';
import '../widgets/dca_add_dialog.dart';
import '../widgets/crypto_rank_chart_card.dart';

class CryptoScreen extends ConsumerStatefulWidget {
  const CryptoScreen({super.key});

  @override
  ConsumerState<CryptoScreen> createState() => _CryptoScreenState();
}

class _CryptoScreenState extends ConsumerState<CryptoScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late TabController _tabController;
  int _binanceSubTab = 0; // 0: Spot, 1: Futures, 2: Earn
  int _dcaFilterIndex = 0; // 0: Всі, 1: Binance, 2: Ручні

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _tabController = TabController(length: 6, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(cryptoPortfolioProvider.notifier).startLiveStreaming();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      ref.read(cryptoPortfolioProvider.notifier).startLiveStreaming();
    } else if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      ref.read(cryptoPortfolioProvider.notifier).stopLiveStreaming();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(cryptoPortfolioProvider);
    final notifier = ref.read(cryptoPortfolioProvider.notifier);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        title: const Row(
          children: [
            Icon(Icons.currency_bitcoin_rounded, color: AppColors.accent, size: 26),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Криптопортфель & AI',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                ),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: state.isLoading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accent),
                  )
                : const Icon(Icons.refresh_rounded, color: AppColors.textSecondary),
            onPressed: state.isLoading ? null : () => notifier.refreshPortfolio(),
            tooltip: 'Оновити всі дані',
          ),
          const SizedBox(width: 8),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          indicatorColor: AppColors.accent,
          indicatorWeight: 3,
          labelColor: AppColors.accentLight,
          unselectedLabelColor: AppColors.textSecondary,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          tabs: const [
            Tab(icon: Icon(Icons.account_balance_wallet_rounded, size: 18), text: 'Огляд'),
            Tab(icon: Icon(Icons.currency_exchange_rounded, size: 18), text: 'Binance'),
            Tab(icon: Icon(Icons.hub_rounded, size: 18), text: 'Web3'),
            Tab(icon: Icon(Icons.history_rounded, size: 18), text: 'DCA Історія'),
            Tab(icon: Icon(Icons.radar_rounded, size: 18), text: 'AI-Радар'),
            Tab(icon: Icon(Icons.auto_awesome_rounded, size: 18), text: 'AI-Аудит'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // 1. ВКЛАДКА "ОГЛЯД"
          _buildOverviewTab(state, notifier),

          // 2. ВКЛАДКА "BINANCE" (Спот, Ф'ючерси, Simple Earn)
          _buildBinanceTab(state, notifier),

          // 3. ВКЛАДКА "WEB3" (Solana + EVM/MetaMask)
          _buildWeb3Tab(state),

          // 4. ВКЛАДКА "DCA ІСТОРІЯ"
          _buildDcaTab(state, notifier),

          // 5. ВКЛАДКА "AI-РАДАР" (Сканер 350+ пар Binance)
          _buildAiRadarTab(state, notifier),

          // 6. ВКЛАДКА "AI-АУДИТ" (Groq Llama 3.3 70B)
          _buildAiAuditTab(state, notifier),
        ],
      ),
    );
  }

  // ==========================================
  // 1. ВКЛАДКА: ОГЛЯД ПОРТФЕЛЮ
  // ==========================================
  Widget _buildOverviewTab(CryptoPortfolioState state, CryptoPortfolioNotifier notifier) {
    if (state.isLoading && state.overview.holdings.isEmpty) {
      return const Center(child: CircularProgressIndicator(color: AppColors.accent));
    }

    final overview = state.overview;

    return RefreshIndicator(
      color: AppColors.accent,
      backgroundColor: AppColors.surface,
      onRefresh: () => notifier.refreshPortfolio(),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          CryptoRankChartCard(
            dataset: state.historicalDataset,
            selectedPeriod: state.selectedPeriod,
            onPeriodChanged: (period) => notifier.changePeriod(period),
            onRefresh: () => notifier.refreshPortfolio(),
            isLoading: state.isLoading,
            isLive: state.isLive,
            initialCategory: PortfolioChartCategory.total,
          ),
          const SizedBox(height: 16),
          CryptoNetWorthCard(
            overview: overview,
            selectedPeriod: state.selectedPeriod,
            onPeriodChanged: (period) => notifier.changePeriod(period),
            onRefresh: () => notifier.refreshPortfolio(),
            isLoading: state.isLoading,
            isLive: state.isLive,
          ),
          const SizedBox(height: 16),
          if (overview.holdings.isNotEmpty) ...[
            CryptoAllocationChart(holdings: overview.holdings),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    'АКТИВИ В ПОРТФЕЛІ (${overview.holdings.length})',
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.8,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                const Text(
                  'Натисніть для TP/SL',
                  style: TextStyle(color: AppColors.accent, fontSize: 11, fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ...overview.holdings.map((h) => HoldingListTile(
                  holding: h,
                  selectedPeriod: state.selectedPeriod,
                )),
          ] else ...[
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                children: [
                  const Icon(Icons.account_balance_wallet_outlined, size: 48, color: AppColors.textDisabled),
                  const SizedBox(height: 12),
                  const Text(
                    'Портфель порожній або оновлюється',
                    style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Додайте API ключі біржі Binance у Налаштуваннях, вкажіть адреси гаманців або внесіть ручні покупки DCA.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.accent),
                    icon: const Icon(Icons.add, color: Colors.white),
                    label: const Text('Додати DCA покупку', style: TextStyle(color: Colors.white)),
                    onPressed: () => _openAddDcaDialog(notifier),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ==========================================
  // 2. ВКЛАДКА: BINANCE (СПОТ, Ф'ЮЧЕРСИ, EARN)
  // ==========================================
  Widget _buildBinanceTab(CryptoPortfolioState state, CryptoPortfolioNotifier notifier) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Підвкладки (Сегментний перемикач)
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              _buildSubTabItem(0, 'Спот (${state.binanceSpot.length})'),
              _buildSubTabItem(1, 'Ф\'ючерси (${state.binanceFuturesPositions.length})'),
              _buildSubTabItem(2, 'Simple Earn (${state.binanceEarnItems.length})'),
            ],
          ),
        ),
        const SizedBox(height: 16),

        if (_binanceSubTab == 0) _buildBinanceSpotView(state, notifier),
        if (_binanceSubTab == 1) _buildBinanceFuturesView(state, notifier),
        if (_binanceSubTab == 2) _buildBinanceEarnView(state),
      ],
    );
  }

  Widget _buildSubTabItem(int index, String title) {
    final isSelected = _binanceSubTab == index;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _binanceSubTab = index),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.accent : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          alignment: Alignment.center,
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isSelected ? Colors.white : AppColors.textSecondary,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              fontSize: 11,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBinanceSpotView(CryptoPortfolioState state, CryptoPortfolioNotifier notifier) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CryptoRankChartCard(
          dataset: state.historicalDataset,
          selectedPeriod: state.selectedPeriod,
          onPeriodChanged: (period) => notifier.changePeriod(period),
          onRefresh: () => notifier.refreshPortfolio(),
          isLoading: state.isLoading,
          isLive: state.isLive,
          initialCategory: PortfolioChartCategory.spot,
        ),
        const SizedBox(height: 16),
        if (state.binanceSpot.isEmpty)
          _buildEmptyState('Спотові баланси не виявлені або API ключі не налаштовані.')
        else
          ...state.binanceSpot.entries.map((e) {
            return Container(
              margin: const EdgeInsets.symmetric(vertical: 4),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 16,
                          backgroundColor: AppColors.surfaceVariant,
                          child: Text(
                            e.key.length > 3 ? e.key.substring(0, 3) : e.key,
                            style: const TextStyle(color: AppColors.accentLight, fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            e.key,
                            style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 15),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    e.value.toStringAsFixed(4),
                    style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                ],
              ),
            );
          }),
      ],
    );
  }

  Widget _buildBinanceFuturesView(CryptoPortfolioState state, CryptoPortfolioNotifier notifier) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CryptoRankChartCard(
          dataset: state.historicalDataset,
          selectedPeriod: state.selectedPeriod,
          onPeriodChanged: (period) => notifier.changePeriod(period),
          onRefresh: () => notifier.refreshPortfolio(),
          isLoading: state.isLoading,
          isLive: state.isLive,
          initialCategory: PortfolioChartCategory.futures,
        ),
        const SizedBox(height: 16),
        // Маржа та PnL картка
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              Column(
                children: [
                  const Text('Загальна маржа', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                  const SizedBox(height: 4),
                  Text(
                    '\$${state.binanceFuturesMargin.toStringAsFixed(2)}',
                    style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                ],
              ),
              Container(width: 1, height: 36, color: AppColors.border),
              Column(
                children: [
                  const Text('Нереалізований PnL', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                  const SizedBox(height: 4),
                  Text(
                    '${state.binanceFuturesPnl >= 0 ? '+' : ''}\$${state.binanceFuturesPnl.toStringAsFixed(2)}',
                    style: TextStyle(
                      color: state.binanceFuturesPnl >= 0 ? AppColors.greenTask : AppColors.redTask,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'ВІДКРИТІ ПОЗИЦІЇ',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 0.8),
        ),
        const SizedBox(height: 8),
        if (state.binanceFuturesPositions.isEmpty)
          _buildEmptyState('Немає відкритих ф\'ючерсних позицій.')
        else
          ...state.binanceFuturesPositions.map((p) {
            final isLong = p.direction == 'LONG';
            final isPnlPositive = p.unrealizedPnl >= 0;
            return Container(
              margin: const EdgeInsets.symmetric(vertical: 4),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: (isLong ? AppColors.greenTask : AppColors.redTask).withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '${p.direction} ${p.leverage}x',
                                style: TextStyle(
                                  color: isLong ? AppColors.greenTask : AppColors.redTask,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                p.symbol,
                                style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 15),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${isPnlPositive ? '+' : ''}\$${p.unrealizedPnl.toStringAsFixed(2)}',
                        style: TextStyle(
                          color: isPnlPositive ? AppColors.greenTask : AppColors.redTask,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(child: Text('Вхід: \$${p.entryPrice.toStringAsFixed(2)}', style: const TextStyle(color: AppColors.textSecondary, fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis)),
                      const SizedBox(width: 4),
                      Flexible(child: Text('Mark: \$${p.markPrice.toStringAsFixed(2)}', style: const TextStyle(color: AppColors.textSecondary, fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis)),
                      const SizedBox(width: 4),
                      Flexible(child: Text('Liq: \$${p.liquidationPrice.toStringAsFixed(2)}', style: const TextStyle(color: AppColors.warning, fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis)),
                    ],
                  ),
                ],
              ),
            );
          }),
      ],
    );
  }

  Widget _buildBinanceEarnView(CryptoPortfolioState state) {
    if (state.binanceEarnItems.isEmpty) {
      return _buildEmptyState('Немає активів у Binance Simple Earn або потрібні API дозволи.');
    }

    return Column(
      children: state.binanceEarnItems.map((e) {
        return Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 16,
                      backgroundColor: AppColors.surfaceVariant,
                      child: Text(
                        e.symbol.length > 3 ? e.symbol.substring(0, 3) : e.symbol,
                        style: const TextStyle(color: AppColors.accentLight, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(e.symbol, style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 15), maxLines: 1, overflow: TextOverflow.ellipsis),
                          Text(e.productName, style: const TextStyle(color: AppColors.textSecondary, fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(e.amount.toStringAsFixed(4), style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 14)),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(
                      color: AppColors.greenTask.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'APR: ${(e.apr * 100).toStringAsFixed(2)}%',
                      style: const TextStyle(color: AppColors.greenTask, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  // ==========================================
  // 3. ВКЛАДКА: WEB3 (SOLANA & EVM)
  // ==========================================
  Widget _buildWeb3Tab(CryptoPortfolioState state) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // SOLANA
        _buildWeb3ChainSection(
          chainName: 'Solana (Helius RPC)',
          icon: Icons.flash_on_rounded,
          iconColor: const Color(0xFF14F195),
          assets: state.solanaAssets,
        ),
        const SizedBox(height: 20),
        // EVM / METAMASK
        _buildWeb3ChainSection(
          chainName: 'Ethereum & EVM (Ethplorer)',
          icon: Icons.shield_rounded,
          iconColor: const Color(0xFF627EEA),
          assets: state.evmAssets,
        ),
      ],
    );
  }

  Widget _buildWeb3ChainSection({
    required String chainName,
    required IconData icon,
    required Color iconColor,
    required List<Web3Asset> assets,
  }) {
    double totalUsd = 0.0;
    for (final a in assets) {
      totalUsd += a.totalUsd;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Icon(icon, color: iconColor, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        chainName,
                        style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 15),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '\$${totalUsd.toStringAsFixed(2)}',
                style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 15),
              ),
            ],
          ),
          const Divider(color: AppColors.border, height: 20),
          if (assets.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'Токени не знайдені або адреса не налаштована в Налаштуваннях.',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
              ),
            )
          else
            ...assets.map((a) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            Text(a.symbol, style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 14)),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                a.name,
                                style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text('\$${a.totalUsd.toStringAsFixed(2)}', style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 13)),
                          Text('${a.amount.toStringAsFixed(4)} @ \$${a.priceUsd.toStringAsFixed(2)}', style: const TextStyle(color: AppColors.textSecondary, fontSize: 10)),
                        ],
                      ),
                    ],
                  ),
                )),
        ],
      ),
    );
  }

  // ==========================================
  // 4. ВКЛАДКА: DCA ІСТОРІЯ ПОКУПОК
  // ==========================================
  // ==========================================
  // 4. ВКЛАДКА: DCA ІСТОРІЯ ПОКУПОК (FIFO АКТИВНІ ЗАЛИШКИ ТА ГРУПУВАННЯ)
  // ==========================================
  Widget _buildDcaTab(CryptoPortfolioState state, CryptoPortfolioNotifier notifier) {
    final totals = state.dcaTotals;
    final isPnlPositive = totals.totalPnlUsd >= 0;
    final pnlColor = isPnlPositive ? AppColors.greenTask : AppColors.redTask;
    final binanceCoins = state.binanceDcaCoins;
    final manualCoins = state.manualDcaCoins;
    final allCoins = state.groupedDcaCoins;

    return RefreshIndicator(
      color: AppColors.accent,
      backgroundColor: AppColors.surface,
      onRefresh: () => notifier.refreshPortfolio(),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 1. ГОЛОВНА ЗВЕДЕНА КАРТКА DCA
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'АКТИВНИЙ DCA ПОРТФЕЛЬ (FIFO)',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.8,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: pnlColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '${isPnlPositive ? '+' : ''}${totals.totalPnlPct.toStringAsFixed(2)}%',
                        style: TextStyle(color: pnlColor, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Поточна вартість',
                            style: TextStyle(color: AppColors.textSecondary, fontSize: 11),
                          ),
                          const SizedBox(height: 2),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(
                              '\$${totals.totalValue.toStringAsFixed(2)}',
                              style: const TextStyle(
                                color: AppColors.textPrimary,
                                fontWeight: FontWeight.bold,
                                fontSize: 24,
                                letterSpacing: -0.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        const Text(
                          'Чистий PnL',
                          style: TextStyle(color: AppColors.textSecondary, fontSize: 11),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${isPnlPositive ? '+' : '-'}\$${totals.totalPnlUsd.abs().toStringAsFixed(2)}',
                          style: TextStyle(
                            color: pnlColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          'Вкладено: \$${totals.totalInvested.toStringAsFixed(2)}',
                          style: const TextStyle(color: AppColors.textDisabled, fontSize: 10),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(color: AppColors.border, height: 1),
                const SizedBox(height: 14),

                // Кнопки дій: Синхронізація Binance та Ручне додавання
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFF3BA2F).withValues(alpha: 0.15),
                          foregroundColor: const Color(0xFFF3BA2F),
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 11),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                            side: BorderSide(color: const Color(0xFFF3BA2F).withValues(alpha: 0.4)),
                          ),
                        ),
                        icon: const Icon(Icons.sync_rounded, size: 18),
                        label: const Text(
                          'З Binance (FIFO)',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                        onPressed: state.isLoading ? null : () => notifier.syncBinanceDca(),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.accent,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 11),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        icon: const Icon(Icons.add_rounded, size: 18),
                        label: const Text(
                          'Вручну',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                        onPressed: () => _openAddDcaDialog(notifier),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 2. ФІЛЬТР-СЕЛЕКТОР: ВСІ | BINANCE | РУЧНІ
          Row(
            children: [
              _buildDcaFilterChip(
                label: 'Всі (${allCoins.length})',
                isSelected: _dcaFilterIndex == 0,
                onTap: () => setState(() => _dcaFilterIndex = 0),
              ),
              const SizedBox(width: 8),
              _buildDcaFilterChip(
                label: 'Binance (${binanceCoins.length})',
                icon: Icons.currency_exchange_rounded,
                iconColor: const Color(0xFFF3BA2F),
                isSelected: _dcaFilterIndex == 1,
                onTap: () => setState(() => _dcaFilterIndex = 1),
              ),
              const SizedBox(width: 8),
              _buildDcaFilterChip(
                label: 'Ручні (${manualCoins.length})',
                icon: Icons.edit_note_rounded,
                iconColor: AppColors.accentLight,
                isSelected: _dcaFilterIndex == 2,
                onTap: () => setState(() => _dcaFilterIndex = 2),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // 3. ВІДОБРАЖЕННЯ СПИСКУ ЗА ОБРАНИМ ФІЛЬТРОМ
          if (_dcaFilterIndex == 1) ...[
            // Фільтр: Тільки Binance
            if (binanceCoins.isEmpty)
              _buildEmptyState(
                'Немає активних закупок з Binance.\n\nНатисніть кнопку "З Binance (FIFO)" вище для автоматичного розрахунку покупок та підтягування поточних активів.',
              )
            else ...[
              _buildDcaSectionHeader(
                title: '🟡 ЗАКУПКИ BINANCE',
                count: binanceCoins.length,
                subtitle: 'Синхронізовані ордери, конвертації та активні залишки',
                accentColor: const Color(0xFFF3BA2F),
              ),
              ...binanceCoins.map((coin) => _DcaCoinExpandableCard(
                    coin: coin,
                    notifier: notifier,
                  )),
            ],
          ] else if (_dcaFilterIndex == 2) ...[
            // Фільтр: Тільки Ручні
            if (manualCoins.isEmpty)
              _buildEmptyState(
                'Немає ручних DCA записів.\n\nНатисніть кнопку "Вручну", щоб додати покупку самостійно або зафіксувати вхід по монеті.',
              )
            else ...[
              _buildDcaSectionHeader(
                title: '✍️ РУЧНІ DCA ЗАПИСИ',
                count: manualCoins.length,
                subtitle: 'Транзакції додані користувачем вручну',
                accentColor: AppColors.accentLight,
              ),
              ...manualCoins.map((coin) => _DcaCoinExpandableCard(
                    coin: coin,
                    notifier: notifier,
                  )),
            ],
          ] else ...[
            // Фільтр: Всі (Розділені секціями)
            if (allCoins.isEmpty)
              _buildEmptyState(
                'Немає активних покупок.\n\nНатисніть "З Binance (FIFO)" для завантаження з біржі або "Вручну" щоб додати нову купівлю.',
              )
            else ...[
              if (binanceCoins.isNotEmpty) ...[
                _buildDcaSectionHeader(
                  title: '🟡 ЗАКУПКИ BINANCE',
                  count: binanceCoins.length,
                  subtitle: 'Синхронізовано з Binance (Спот / Convert FIFO)',
                  accentColor: const Color(0xFFF3BA2F),
                ),
                ...binanceCoins.map((coin) => _DcaCoinExpandableCard(
                      coin: coin,
                      notifier: notifier,
                    )),
              ],
              if (binanceCoins.isNotEmpty && manualCoins.isNotEmpty)
                const SizedBox(height: 16),
              if (manualCoins.isNotEmpty) ...[
                _buildDcaSectionHeader(
                  title: '✍️ РУЧНІ DCA ЗАПИСИ',
                  count: manualCoins.length,
                  subtitle: 'Додані самостійно користувачем',
                  accentColor: AppColors.accentLight,
                ),
                ...manualCoins.map((coin) => _DcaCoinExpandableCard(
                      coin: coin,
                      notifier: notifier,
                    )),
              ],
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildDcaFilterChip({
    required String label,
    IconData? icon,
    Color? iconColor,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isSelected ? AppColors.accent.withValues(alpha: 0.15) : AppColors.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? AppColors.accent : AppColors.border,
              width: isSelected ? 1.5 : 1,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 13, color: iconColor ?? AppColors.textSecondary),
                const SizedBox(width: 4),
              ],
              Flexible(
                child: Text(
                  label,
                  style: TextStyle(
                    color: isSelected ? AppColors.textPrimary : AppColors.textSecondary,
                    fontSize: 11,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDcaSectionHeader({
    required String title,
    required int count,
    required String subtitle,
    Color? accentColor,
  }) {
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 3.5,
            height: 24,
            decoration: BoxDecoration(
              color: accentColor ?? AppColors.accent,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$title ($count)',
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  subtitle,
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 10),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // 5. ВКЛАДКА: AI-АУДИТ (LLAMA 3.3 70B & QUANT ENGINE)
  // ==========================================
  Widget _buildAiAuditTab(CryptoPortfolioState state, CryptoPortfolioNotifier notifier) {
    final report = state.auditReport;
    final isPositiveTotal = (report?.totalPnlUsd ?? 0) >= 0;
    final totalPnlColor = isPositiveTotal ? AppColors.greenTask : AppColors.redTask;

    return RefreshIndicator(
      color: AppColors.accent,
      backgroundColor: AppColors.surface,
      onRefresh: () => notifier.runAiAudit(),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 1. Верхній банер запуску AI-Аудиту
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.accent.withValues(alpha: 0.2),
                  AppColors.surface,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.accent.withValues(alpha: 0.35)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.accent.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.auto_awesome_rounded, color: AppColors.accentLight, size: 22),
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'AI-Аудит & Квант-Ризик Портфеля',
                            style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 16),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Llama 3.3 70B · Аналіз закупок DCA · 3 Шари TP · ATR Stop-Loss',
                            style: TextStyle(color: AppColors.textSecondary, fontSize: 11),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                const Text(
                  'Глибока перевірка кожної позиції: порівнює вашу реальну ціну закупки (FIFO/DCA) з поточним ринком, оцінює перекіс капіталу, достатність кеш-подушки та розраховує точні рівні фіксації прибутку (TP1/TP2/TP3), добору на дні та захисного стопу.',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 12, height: 1.35),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                    icon: state.isAuditing
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          )
                        : const Icon(Icons.psychology_rounded, color: Colors.white, size: 20),
                    label: Text(
                      state.isAuditing
                          ? 'Аналізуємо структуру та індикатори...'
                          : (report == null ? 'Запустити повний аудит портфеля' : 'Оновити AI-аудит портфеля'),
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    onPressed: state.isAuditing ? null : () => notifier.runAiAudit(),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          if (report != null) ...[
            // 2. Картки: Оцінка здоров'я + Диверсифікація
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'ІНДЕКС ЗДОРОВ\'Я',
                          style: TextStyle(color: AppColors.textSecondary, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                '${report.overallHealthScore}',
                                style: TextStyle(
                                  color: _getHealthScoreColor(report.overallHealthScore),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 26,
                                ),
                              ),
                            ),
                            const Text(
                              '/100',
                              style: TextStyle(color: AppColors.textDisabled, fontSize: 13, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: (report.overallHealthScore / 100.0).clamp(0.0, 1.0),
                            minHeight: 5,
                            backgroundColor: AppColors.surfaceVariant,
                            valueColor: AlwaysStoppedAnimation<Color>(_getHealthScoreColor(report.overallHealthScore)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'ДИВЕРСИФІКАЦІЯ',
                          style: TextStyle(color: AppColors.textSecondary, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                        ),
                        const SizedBox(height: 6),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            report.diversificationStatus,
                            style: TextStyle(
                              color: report.diversificationStatus.contains('ПЕРЕКІС') || report.diversificationStatus.contains('КОНЦЕНТРАЦІЯ')
                                  ? AppColors.warning
                                  : AppColors.blueTask,
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Топ-актив: ${report.topAssetSymbol} (${report.topAssetSharePct.toStringAsFixed(1)}%)',
                            style: const TextStyle(color: AppColors.textDisabled, fontSize: 11),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // 3. Матриця Алокації Капіталу та Загальний PnL
            if (report.totalValueUsd > 0) ...[
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.pie_chart_rounded, size: 16, color: AppColors.accentLight),
                        const SizedBox(width: 6),
                        const Expanded(
                          child: Text(
                            'СТРУКТУРА КАПІТАЛУ ТА СУМАРНИЙ PNL',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 10.5,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.6,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                          decoration: BoxDecoration(
                            color: totalPnlColor.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '${isPositiveTotal ? '+' : ''}${report.totalPnlPct.toStringAsFixed(2)}% (${isPositiveTotal ? '+' : '-'}\$${report.totalPnlUsd.abs().toStringAsFixed(2)})',
                            style: TextStyle(color: totalPnlColor, fontSize: 10.5, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // Баланс vs Вкладено
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Поточний капітал', style: TextStyle(color: AppColors.textDisabled, fontSize: 10)),
                              const SizedBox(height: 2),
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  '\$${_formatPrice(report.totalValueUsd)}',
                                  style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 16),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              const Text('Вкладено (Закупка)', style: TextStyle(color: AppColors.textDisabled, fontSize: 10)),
                              const SizedBox(height: 2),
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerRight,
                                child: Text(
                                  '\$${_formatPrice(report.totalInvestedUsd)}',
                                  style: const TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.bold, fontSize: 15),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // Візуальний прогрес-бар алокації (Кеш / BTC+ETH / Альти)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: SizedBox(
                        height: 8,
                        child: Row(
                          children: [
                            if (report.cashPct > 0)
                              Expanded(
                                flex: (report.cashPct * 10).round().clamp(1, 1000),
                                child: Container(color: AppColors.greenTask),
                              ),
                            if (report.corePct > 0)
                              Expanded(
                                flex: (report.corePct * 10).round().clamp(1, 1000),
                                child: Container(color: AppColors.blueTask),
                              ),
                            if (report.altPct > 0)
                              Expanded(
                                flex: (report.altPct * 10).round().clamp(1, 1000),
                                child: Container(color: AppColors.accentLight),
                              ),
                            if (report.cashPct <= 0 && report.corePct <= 0 && report.altPct <= 0)
                              Expanded(child: Container(color: AppColors.surfaceVariant)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),

                    // 3 колонки алокації
                    Row(
                      children: [
                        _buildAuditAllocTile(
                          dotColor: AppColors.greenTask,
                          title: 'Кеш (Стейбли)',
                          pct: '${report.cashPct.toStringAsFixed(1)}%',
                          usd: '\$${report.cashUsd.toStringAsFixed(0)}',
                        ),
                        const SizedBox(width: 6),
                        _buildAuditAllocTile(
                          dotColor: AppColors.blueTask,
                          title: 'Ядро BTC/ETH',
                          pct: '${report.corePct.toStringAsFixed(1)}%',
                          usd: '\$${report.coreUsd.toStringAsFixed(0)}',
                        ),
                        const SizedBox(width: 6),
                        _buildAuditAllocTile(
                          dotColor: AppColors.accentLight,
                          title: 'Альткоїни',
                          pct: '${report.altPct.toStringAsFixed(1)}%',
                          usd: '\$${report.altUsd.toStringAsFixed(0)}',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],

            // 4. Стратегічний висновок, Кеш-подушка та Пріоритетні Дії
            Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.lightbulb_outline_rounded, color: AppColors.warning, size: 18),
                      const SizedBox(width: 6),
                      const Expanded(
                        child: Text(
                          'СТРАТЕГІЧНИЙ ВЕРДИКТ КЕРУЮЧОГО',
                          style: TextStyle(color: AppColors.textSecondary, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.6),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        DateFormat('HH:mm').format(report.auditedAt),
                        style: const TextStyle(color: AppColors.textDisabled, fontSize: 10),
                      ),
                    ],
                  ),
                  if (report.marketRegime.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceVariant,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.currency_bitcoin_rounded, size: 14, color: Color(0xFFF3BA2F)),
                          const SizedBox(width: 5),
                          Expanded(
                            child: Text(
                              report.marketRegime,
                              style: const TextStyle(color: AppColors.textSecondary, fontSize: 11, fontWeight: FontWeight.w600),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 10),
                  Text(
                    report.strategicSummary,
                    style: const TextStyle(color: AppColors.textPrimary, fontSize: 13, height: 1.4),
                  ),

                  if (report.riskSummary.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceVariant.withValues(alpha: 0.55),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.shield_outlined, size: 15, color: AppColors.blueTask),
                          const SizedBox(width: 7),
                          Expanded(
                            child: Text(
                              report.riskSummary,
                              style: const TextStyle(color: AppColors.textSecondary, fontSize: 11.5, height: 1.35),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  if (report.cashReserveComment.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.greenTask.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.greenTask.withValues(alpha: 0.25)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.account_balance_wallet_outlined, size: 15, color: AppColors.greenTask),
                          const SizedBox(width: 7),
                          Expanded(
                            child: Text(
                              report.cashReserveComment,
                              style: const TextStyle(color: AppColors.textPrimary, fontSize: 11.5, height: 1.35),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  if (report.priorityActions.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    const Text(
                      'ПЛАН ПЕРШОЧЕРГОВИХ ДІЙ:',
                      style: TextStyle(color: AppColors.accentLight, fontSize: 10.5, fontWeight: FontWeight.bold, letterSpacing: 0.6),
                    ),
                    const SizedBox(height: 6),
                    ...report.priorityActions.map((act) => Padding(
                          padding: const EdgeInsets.only(bottom: 5),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Padding(
                                padding: EdgeInsets.only(top: 2),
                                child: Icon(Icons.check_circle_outline_rounded, size: 14, color: AppColors.accentLight),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  act,
                                  style: const TextStyle(color: AppColors.textPrimary, fontSize: 12, height: 1.35),
                                ),
                              ),
                            ],
                          ),
                        )),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),

            // 5. Детальний розбір кожної позиції портфеля
            Row(
              children: [
                Expanded(
                  child: Text(
                    'ПОЗИЦІЙНИЙ АУДИТ АКТИВІВ (${report.assetRecommendations.length})',
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 0.8),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const Text(
                  'Натисніть для плану TP/SL',
                  style: TextStyle(color: AppColors.textDisabled, fontSize: 10.5),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ...report.assetRecommendations.map((item) => _buildAuditAssetCard(item)),
          ] else ...[
            _buildEmptyState(
              'Натисніть кнопку «Запустити повний аудит портфеля» вище, щоб проаналізувати ваші точки входу, PnL, концентрацію капіталу та отримати точні цілі фіксації прибутку.',
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAuditAllocTile({
    required Color dotColor,
    required String title,
    required String pct,
    required String usd,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 6),
        decoration: BoxDecoration(
          color: AppColors.surfaceVariant.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      title,
                      style: const TextStyle(color: AppColors.textDisabled, fontSize: 9),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 3),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                '$pct · $usd',
                style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 11),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAuditAssetCard(GroqAuditItem item) {
    final isPos = item.pnlUsd >= 0;
    final pnlColor = isPos ? AppColors.greenTask : AppColors.redTask;
    final isStable = item.symbol == 'USDT' || item.symbol == 'USDC' || item.symbol == 'FDUSD' || item.symbol == 'DAI';

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Шапка монети: Аватар, Символ, Частка в портфелі, Бейдж Дії та Ризику
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: AppColors.accent.withValues(alpha: 0.15),
                child: Text(
                  item.symbol.length > 3 ? item.symbol.substring(0, 3) : item.symbol,
                  style: const TextStyle(color: AppColors.accentLight, fontWeight: FontWeight.bold, fontSize: 11),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            item.symbol,
                            style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 16),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        if (item.totalUsd > 0)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceVariant,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              '${item.sharePct.toStringAsFixed(1)}% · \$${item.totalUsd.toStringAsFixed(0)}',
                              style: const TextStyle(color: AppColors.textSecondary, fontSize: 9.5, fontWeight: FontWeight.bold),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    _buildActionBadge(item.action, customLabel: item.actionLabelUk),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _buildRiskBadge(item.riskLevel),
                  if (!isStable && item.totalUsd > 0) ...[
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: pnlColor.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: Text(
                        '${isPos ? '+' : ''}${item.pnlPct.toStringAsFixed(1)}% (${isPos ? '+' : '-'}\$${item.pnlUsd.abs().toStringAsFixed(1)})',
                        style: TextStyle(color: pnlColor, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),

          if (!isStable && item.currentPrice > 0) ...[
            const SizedBox(height: 10),

            // 2. Панель порівняння: Ціна Закупки vs Поточна Ціна + 4 Квантові метрики
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant.withValues(alpha: 0.45),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.border.withValues(alpha: 0.6)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('ЦІНА ЗАКУПКИ (DCA)', style: TextStyle(color: AppColors.textDisabled, fontSize: 9, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 2),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            '\$${_formatPrice(item.avgEntryPrice)}',
                            style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 13.5),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: Icon(Icons.arrow_forward_rounded, size: 14, color: AppColors.textDisabled.withValues(alpha: 0.6)),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('ПОТОЧНА ЦІНА', style: TextStyle(color: AppColors.textDisabled, fontSize: 9, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 2),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            '\$${_formatPrice(item.currentPrice)}',
                            style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 13.5),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        const Text('RSI (14D) · R:R', style: TextStyle(color: AppColors.textDisabled, fontSize: 9, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 2),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerRight,
                          child: Text(
                            '${item.rsi.toStringAsFixed(1)} · 1:${item.riskRewardRatio.toStringAsFixed(1)}',
                            style: TextStyle(
                              color: item.rsi <= 40
                                  ? AppColors.greenTask
                                  : (item.rsi >= 68 ? AppColors.warning : AppColors.accentLight),
                              fontWeight: FontWeight.bold,
                              fontSize: 12.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),

            // 3. Торговий коридор монети: Добір DCA + Стоп-Лос + 3 Шари Тейків
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                    decoration: BoxDecoration(
                      color: AppColors.blueTask.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(7),
                      border: Border.all(color: AppColors.blueTask.withValues(alpha: 0.25)),
                    ),
                    child: Row(
                      children: [
                        const Text('Добір DCA: ', style: TextStyle(color: AppColors.blueTask, fontSize: 9.5, fontWeight: FontWeight.bold)),
                        Expanded(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(
                              '\$${_formatPrice(item.dcaBuyPrice)}',
                              style: const TextStyle(color: AppColors.textPrimary, fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                    decoration: BoxDecoration(
                      color: AppColors.redTask.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(7),
                      border: Border.all(color: AppColors.redTask.withValues(alpha: 0.25)),
                    ),
                    child: Row(
                      children: [
                        const Text('Стоп SL: ', style: TextStyle(color: AppColors.redTask, fontSize: 9.5, fontWeight: FontWeight.bold)),
                        Expanded(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(
                              '\$${_formatPrice(item.stopLossPrice)}',
                              style: const TextStyle(color: AppColors.redTask, fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              decoration: BoxDecoration(
                color: AppColors.greenTask.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(7),
                border: Border.all(color: AppColors.greenTask.withValues(alpha: 0.25)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.flag_outlined, size: 13, color: AppColors.greenTask),
                  const SizedBox(width: 5),
                  const Text('Тейки: ', style: TextStyle(color: AppColors.greenTask, fontSize: 9.5, fontWeight: FontWeight.bold)),
                  Expanded(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'TP1 (30%): \$${_formatPrice(item.tp1Price)}  ·  TP2 (35%): \$${_formatPrice(item.tp2Price)}  ·  TP3: \$${_formatPrice(item.tp3Price)}',
                        style: const TextStyle(color: AppColors.greenTask, fontSize: 10.5, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 10),
          // 4. Аналітичне обґрунтування
          Text(
            item.reason,
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 12, height: 1.35),
          ),

          // 5. Конкретний торговий план виконання
          if (item.executionPlan.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant.withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.accent.withValues(alpha: 0.25)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.playlist_add_check_rounded, size: 14, color: AppColors.accentLight),
                      SizedBox(width: 5),
                      Expanded(
                        child: Text(
                          'ТОРГОВИЙ ПЛАН ВИКОНАННЯ:',
                          style: TextStyle(color: AppColors.accentLight, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.4),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.executionPlan,
                    style: const TextStyle(color: AppColors.textPrimary, fontSize: 11.5, height: 1.35),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildActionBadge(String action, {String customLabel = ''}) {
    Color color;
    String defaultLabel;
    switch (action.toUpperCase()) {
      case 'TAKE_PROFIT':
        color = AppColors.greenTask;
        defaultLabel = 'ФІКСУВАТИ ЧАСТИНУ TP';
        break;
      case 'ACCUMULATE':
        color = AppColors.blueTask;
        defaultLabel = 'ДОБИРАТИ НА СПАДІ (DCA)';
        break;
      case 'REDUCE':
        color = AppColors.redTask;
        defaultLabel = 'СКОРОТИТИ КОНЦЕНТРАЦІЮ';
        break;
      case 'STOP_WATCH':
        color = AppColors.redTask;
        defaultLabel = 'КОНТРОЛЬ СТОПУ';
        break;
      default:
        color = AppColors.warning;
        defaultLabel = 'УТРИМУВАТИ В СТРУКТУРІ';
    }

    final displayLabel = customLabel.isNotEmpty ? customLabel : defaultLabel;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        displayLabel,
        style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 10),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  Widget _buildRiskBadge(String risk) {
    final r = risk.toUpperCase();
    final Color color = r == 'HIGH'
        ? AppColors.redTask
        : (r == 'MEDIUM' ? AppColors.warning : AppColors.greenTask);
    final String labelUk = r == 'HIGH'
        ? 'Високий'
        : (r == 'MEDIUM' ? 'Помірний' : 'Низький');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        'Ризик: $labelUk',
        style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w600),
      ),
    );
  }

  Color _getHealthScoreColor(int score) {
    if (score >= 80) return AppColors.greenTask;
    if (score >= 60) return AppColors.blueTask;
    if (score >= 40) return AppColors.warning;
    return AppColors.redTask;
  }

  Widget _buildEmptyState(String text) {
    return Container(
      padding: const EdgeInsets.all(24),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
      ),
    );
  }

  void _openAddDcaDialog(CryptoPortfolioNotifier notifier) {
    showDialog(
      context: context,
      builder: (ctx) => DcaAddDialog(
        onAdd: (tx) => notifier.addDcaTransaction(tx),
      ),
    );
  }

  void _openAddDcaFromRadar(AiMarketOpportunity opp, CryptoPortfolioNotifier notifier) {
    showDialog(
      context: context,
      builder: (ctx) => DcaAddDialog(
        initialSymbol: opp.symbol,
        initialPrice: opp.currentPrice,
        initialNotes:
            'AI-Радар [${opp.setupType}]: Вхід \$${_formatDialogPrice(opp.entryZoneMin)}-\$${_formatDialogPrice(opp.entryZoneMax)}, '
            'TP1 \$${_formatDialogPrice(opp.targetPrice1)} (50% + Б/З), '
            'TP2 \$${_formatDialogPrice(opp.targetPrice2)}, '
            'SL \$${_formatDialogPrice(opp.stopLoss)} (закриття 4H/1D нижче рівня).',
        onAdd: (tx) => notifier.addDcaTransaction(tx),
      ),
    );
  }

  String _formatDialogPrice(double val) {
    if (val >= 1000) return val.toStringAsFixed(2);
    if (val >= 1) return val.toStringAsFixed(3);
    if (val >= 0.01) return val.toStringAsFixed(4);
    return val.toStringAsFixed(6);
  }

  String _formatPrice(double val) {
    if (val >= 1000) {
      return NumberFormat('#,##0.00', 'en_US').format(val);
    } else if (val >= 1) {
      return val.toStringAsFixed(2);
    } else if (val >= 0.01) {
      return val.toStringAsFixed(4);
    } else if (val > 0) {
      return val.toStringAsFixed(6);
    } else {
      return '0.00';
    }
  }

  // ==========================================
  // 5. ВКЛАДКА: AI-РАДАР МОНЕТ (350+ ПАР BINANCE)
  // ==========================================
  Widget _buildAiRadarTab(CryptoPortfolioState state, CryptoPortfolioNotifier notifier) {
    final report = state.radarReport;
    final isScanning = state.isScanningMarket;

    return RefreshIndicator(
      color: AppColors.accent,
      backgroundColor: AppColors.surface,
      onRefresh: () => notifier.scanMarketRadar(),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Головний банер дії
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.surface,
                  AppColors.accent.withValues(alpha: 0.12),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.accent.withValues(alpha: 0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.accent.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.radar_rounded, color: AppColors.accentLight, size: 24),
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Smart Money AI-Радар (350+ пар)',
                            style: TextStyle(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Order Flow (Taker Buy) · R:R >= 1:3 · Точні TP1/TP2 та ATR Stop-Loss',
                            style: TextStyle(color: AppColors.textSecondary, fontSize: 11),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                const Text(
                  '5-ступеневий алго-скринер: відсікає «падаючі ножі», аналізує 90-денний потік ринкових покупок китів (Taker Buy Volume), бичачі дивергенції та розраховує структурні рівні Тейк-Профіту (Fibo 0.382/0.618) і захищеного Стоп-Лосу (Support - 1.2×ATR).',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 12, height: 1.35),
                ),
                const SizedBox(height: 14),
                if (isScanning) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: state.scanProgress > 0 ? state.scanProgress : null,
                      backgroundColor: AppColors.surfaceVariant,
                      valueColor: const AlwaysStoppedAnimation<Color>(AppColors.accent),
                      minHeight: 6,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accentLight),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          (state.scanProgressStatus != null && state.scanProgressStatus!.isNotEmpty)
                              ? state.scanProgressStatus!
                              : 'Скануємо ринок...',
                          style: const TextStyle(
                            color: AppColors.accentLight,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ] else ...[
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.accent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                      icon: const Icon(Icons.radar_rounded, size: 20),
                      label: Text(
                        (report == null || report.opportunities.isEmpty)
                            ? 'Запустити Smart Money AI-Радар'
                            : 'Пересканувати ринок (350+ монет)',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      onPressed: () => notifier.scanMarketRadar(),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Якщо є результати звіту
          if (report != null && report.opportunities.isNotEmpty) ...[
            // Картка режиму ринку та висновку комітету
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.groups_rounded, color: AppColors.blueTask, size: 18),
                      const SizedBox(width: 6),
                      const Expanded(
                        child: Text(
                          'ВИСНОВОК АЛГО-КОМІТЕТУ',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.8,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      _buildMarketRegimeBadge(report.marketRegime),
                    ],
                  ),
                  if (report.btcTrend.isNotEmpty && report.btcTrend != '—') ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceVariant,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.currency_bitcoin_rounded, size: 14, color: Color(0xFFF3BA2F)),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              'Контекст BTC: ${report.btcTrend}',
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 10),
                  Text(
                    report.macroSummary,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Згенеровано: ${DateFormat('dd.MM.yyyy HH:mm').format(report.scannedAt)}',
                    style: const TextStyle(color: AppColors.textDisabled, fontSize: 10),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Список можливостей
            Row(
              children: [
                Expanded(
                  child: Text(
                    'ТОП-ЗНАХІДКИ ДЛЯ DCA-НАБОРУ (${report.opportunities.length})',
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.8,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${report.totalCoinsScanned} пар',
                  style: const TextStyle(color: AppColors.textDisabled, fontSize: 11),
                ),
              ],
            ),
            const SizedBox(height: 8),

            ...report.opportunities.map((opp) => _RadarOpportunityCard(
                  opportunity: opp,
                  onAddToDca: () => _openAddDcaFromRadar(opp, notifier),
                )),
          ] else if (!isScanning) ...[
            _buildEmptyState(
              'AI-Радар ще не сканував ринок у цій сесії.\n\nНатисніть кнопку вище, щоб просканувати 350+ спотових пар Binance, виявити глибокі просадки, перепроданість по RSI та отримати готові DCA-стратегії.',
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMarketRegimeBadge(String regime) {
    Color color;
    String label = regime;
    switch (regime.toUpperCase()) {
      case 'ACCUMULATION':
        color = AppColors.greenTask;
        label = 'Зона накопичення';
        break;
      case 'BEARISH_DIP':
        color = AppColors.warning;
        label = 'Ведмежа просадка';
        break;
      case 'BULL_PULLBACK':
        color = AppColors.blueTask;
        label = 'Бичачий відкат';
        break;
      case 'CONSOLIDATION':
        color = AppColors.accentLight;
        label = 'Консолідація';
        break;
      default:
        color = AppColors.textSecondary;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 10),
      ),
    );
  }
}

class _DcaCoinExpandableCard extends StatefulWidget {
  final DcaGroupedCoin coin;
  final CryptoPortfolioNotifier notifier;

  const _DcaCoinExpandableCard({
    required this.coin,
    required this.notifier,
  });

  @override
  State<_DcaCoinExpandableCard> createState() => _DcaCoinExpandableCardState();
}

class _DcaCoinExpandableCardState extends State<_DcaCoinExpandableCard> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final coin = widget.coin;
    final isPositive = coin.pnlUsd >= 0;
    final pnlColor = isPositive ? AppColors.greenTask : AppColors.redTask;

    final hasBinance = coin.tranches.any((t) => t.walletType == 'Binance Spot' || t.walletType == 'BINANCE');
    final hasManual = coin.tranches.any((t) => t.walletType != 'Binance Spot' && t.walletType != 'BINANCE');

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _isExpanded ? AppColors.accent.withValues(alpha: 0.5) : AppColors.border,
        ),
      ),
      child: Column(
        children: [
          // Головний інтерактивний блок монети
          InkWell(
            onTap: () => setState(() => _isExpanded = !_isExpanded),
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Рядок 1: Аватар, Символ, Бейдж джерела та Кількість угод
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 18,
                        backgroundColor: AppColors.accent.withValues(alpha: 0.15),
                        child: Text(
                          coin.symbol.length > 3 ? coin.symbol.substring(0, 3) : coin.symbol,
                          style: const TextStyle(
                            color: AppColors.accentLight,
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Row(
                          children: [
                            Flexible(
                              child: Text(
                                coin.symbol,
                                style: const TextStyle(
                                  color: AppColors.textPrimary,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            // Бейдж джерела
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: (hasBinance && !hasManual)
                                    ? const Color(0xFFF3BA2F).withValues(alpha: 0.15)
                                    : (!hasBinance && hasManual)
                                        ? AppColors.surfaceVariant
                                        : AppColors.accent.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                (hasBinance && !hasManual)
                                    ? 'Binance'
                                    : (!hasBinance && hasManual)
                                        ? 'Ручна'
                                        : 'Binance + Ручна',
                                style: TextStyle(
                                  color: (hasBinance && !hasManual)
                                      ? const Color(0xFFF3BA2F)
                                      : (!hasBinance && hasManual)
                                          ? AppColors.textSecondary
                                          : AppColors.accentLight,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.surfaceVariant,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '${coin.tranches.length} ${coin.tranches.length == 1 ? 'покупка' : 'покупки'}',
                                style: const TextStyle(color: AppColors.textDisabled, fontSize: 9.5, fontWeight: FontWeight.w600),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 6),
                      Icon(
                        _isExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                        color: AppColors.textSecondary,
                        size: 20,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Рядок 2: ПАНЕЛЬ ПОРІВНЯННЯ ЦІН (ЦІНА ЗАКУПКИ vs ПОТОЧНА ЦІНА)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceVariant.withValues(alpha: 0.45),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border.withValues(alpha: 0.6)),
                    ),
                    child: Row(
                      children: [
                        // Колонка ліворуч: Ціна закупки (Вхід)
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Row(
                                children: [
                                  Icon(Icons.shopping_bag_outlined, size: 12, color: AppColors.accentLight),
                                  SizedBox(width: 4),
                                  Text(
                                    'ЦІНА ЗАКУПКИ',
                                    style: TextStyle(
                                      color: AppColors.textSecondary,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 0.4,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 3),
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  '\$${_formatPrice(coin.avgEntryPrice)}',
                                  style: const TextStyle(
                                    color: AppColors.textPrimary,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Вкладено: \$${_formatPrice(coin.totalCost)}',
                                style: const TextStyle(color: AppColors.textDisabled, fontSize: 9.5),
                              ),
                            ],
                          ),
                        ),

                        // Центральний роздільник зі стрілкою
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: Icon(
                            Icons.arrow_forward_rounded,
                            size: 16,
                            color: AppColors.textDisabled.withValues(alpha: 0.6),
                          ),
                        ),

                        // Колонка праворуч: Поточна ціна (Зараз на ринку)
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  const Text(
                                    'ПОТОЧНА ЦІНА',
                                    style: TextStyle(
                                      color: AppColors.textSecondary,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 0.4,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Icon(
                                    isPositive ? Icons.trending_up_rounded : Icons.trending_down_rounded,
                                    size: 12,
                                    color: pnlColor,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 3),
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerRight,
                                child: Text(
                                  '\$${_formatPrice(coin.currentPrice)}',
                                  style: const TextStyle(
                                    color: AppColors.textPrimary,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Вартість: \$${_formatPrice(coin.totalValueUsd)}',
                                style: const TextStyle(color: AppColors.textDisabled, fontSize: 9.5),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Рядок 3: Кількість монет та Загальний PnL результат
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: Text(
                          'Кількість: ${_formatAmount(coin.totalAmount)} ${coin.symbol}',
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: pnlColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: pnlColor.withValues(alpha: 0.3)),
                        ),
                        child: Text(
                          '${isPositive ? '+' : ''}${coin.pnlPct.toStringAsFixed(2)}% (${isPositive ? '+' : '-'}\$${coin.pnlUsd.abs().toStringAsFixed(2)})',
                          style: TextStyle(
                            color: pnlColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Розгорнутий список траншів
          if (_isExpanded) ...[
            const Divider(color: AppColors.border, height: 1),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              color: AppColors.surfaceVariant.withValues(alpha: 0.35),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'АКТИВНІ ПОКУПКИ (FIFO ЗАЛИШКИ)',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.6,
                        ),
                      ),
                      Text(
                        'Зараз: \$${_formatPrice(coin.currentPrice)}',
                        style: const TextStyle(
                          color: AppColors.accentLight,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ...coin.tranches.map((t) => _buildTrancheRow(t)),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTrancheRow(DcaTrancheItem t) {
    final isPos = t.pnlPct >= 0;
    final color = isPos ? AppColors.greenTask : AppColors.redTask;
    final isBinance = t.walletType == 'Binance Spot' || t.walletType == 'BINANCE';
    final isConvert = t.notes.contains('Convert');
    final isFallback = t.id.startsWith('binance_balance_');

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Ліва колонка: Джерело, дата, кількість, ціна закупки
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: isBinance
                            ? (isConvert
                                ? AppColors.accent.withValues(alpha: 0.15)
                                : const Color(0xFFF3BA2F).withValues(alpha: 0.15))
                            : AppColors.surfaceVariant,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        isBinance
                            ? (isConvert ? 'Convert' : (isFallback ? 'Актив гаманця' : 'Binance Spot'))
                            : 'Ручна DCA',
                        style: TextStyle(
                          color: isBinance
                              ? (isConvert ? AppColors.accentLight : const Color(0xFFF3BA2F))
                              : AppColors.textSecondary,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        _formatDate(t.date),
                        style: const TextStyle(color: AppColors.textSecondary, fontSize: 10),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Text(
                      '${_formatAmount(t.amount)} шт',
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceVariant,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'Ціна закупки: \$${_formatPrice(t.buyPrice)}',
                          style: const TextStyle(
                            color: AppColors.accentLight,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  'Разом закупка: \$${((t.amount * t.buyPrice) + t.fee).toStringAsFixed(2)} · Зараз ринок: \$${_formatPrice(t.currentPrice)}',
                  style: const TextStyle(color: AppColors.textDisabled, fontSize: 9.5),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),

          // Права колонка: Індивідуальний PnL з відсотками росту/падіння від ціни покупки
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '${isPos ? '+' : ''}${t.pnlPct.toStringAsFixed(2)}%',
                  style: TextStyle(
                    color: color,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 3),
              Text(
                '${isPos ? '+' : '-'}\$${t.pnlUsd.abs().toStringAsFixed(2)}',
                style: TextStyle(
                  color: color,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          if (!isBinance) ...[
            const SizedBox(width: 4),
            IconButton(
              icon: const Icon(Icons.close_rounded, color: AppColors.textDisabled, size: 16),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              onPressed: () => widget.notifier.deleteDcaTransaction(t.id),
              tooltip: 'Видалити',
            ),
          ],
        ],
      ),
    );
  }

  String _formatAmount(double amt) {
    if (amt >= 100) return amt.toStringAsFixed(2);
    if (amt >= 1) return amt.toStringAsFixed(4);
    return amt.toStringAsFixed(6).replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '');
  }

  String _formatPrice(double val) {
    if (val >= 1000) {
      return NumberFormat('#,##0.00', 'en_US').format(val);
    } else if (val >= 1) {
      return val.toStringAsFixed(2);
    } else if (val > 0) {
      return val.toStringAsFixed(4);
    } else {
      return '0.00';
    }
  }

  String _formatDate(DateTime dt) {
    return DateFormat('dd.MM.yy HH:mm').format(dt);
  }
}

class _RadarOpportunityCard extends StatefulWidget {
  final AiMarketOpportunity opportunity;
  final VoidCallback onAddToDca;

  const _RadarOpportunityCard({
    required this.opportunity,
    required this.onAddToDca,
  });

  @override
  State<_RadarOpportunityCard> createState() => _RadarOpportunityCardState();
}

class _RadarOpportunityCardState extends State<_RadarOpportunityCard> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final opp = widget.opportunity;
    final confidenceColor = opp.confidenceScore >= 75
        ? AppColors.greenTask
        : (opp.confidenceScore >= 60 ? AppColors.blueTask : AppColors.warning);

    final tp1Pct = opp.currentPrice > 0
        ? ((opp.targetPrice1 - opp.currentPrice) / opp.currentPrice) * 100.0
        : 25.0;
    final tp2Pct = opp.currentPrice > 0
        ? ((opp.targetPrice2 - opp.currentPrice) / opp.currentPrice) * 100.0
        : 55.0;
    final slPct = opp.currentPrice > 0
        ? ((opp.currentPrice - opp.stopLoss) / opp.currentPrice) * 100.0
        : 10.0;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _isExpanded ? AppColors.accent.withValues(alpha: 0.5) : AppColors.border,
        ),
      ),
      child: Column(
        children: [
          // Шапка картки: назва монети, сетап, поточна ціна, індекс Quant Score
          InkWell(
            onTap: () => setState(() => _isExpanded = !_isExpanded),
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 19,
                        backgroundColor: AppColors.accent.withValues(alpha: 0.15),
                        child: Text(
                          opp.symbol.length > 3 ? opp.symbol.substring(0, 3) : opp.symbol,
                          style: const TextStyle(
                            color: AppColors.accentLight,
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    opp.symbol,
                                    style: const TextStyle(
                                      color: AppColors.textPrimary,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                  decoration: BoxDecoration(
                                    color: AppColors.surfaceVariant,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    opp.sector.isNotEmpty ? opp.sector : 'Spot',
                                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 9, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 3),
                            // Бейдж архетипу сетапу (Order Flow / Дивергенція / Пружина Вайкоффа)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.accent.withValues(alpha: 0.14),
                                borderRadius: BorderRadius.circular(5),
                              ),
                              child: Text(
                                opp.setupType,
                                style: const TextStyle(
                                  color: AppColors.accentLight,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerRight,
                            child: Text(
                              '\$${_formatPrice(opp.currentPrice)}',
                              style: const TextStyle(
                                color: AppColors.textPrimary,
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                          ),
                          const SizedBox(height: 3),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: confidenceColor.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'Alpha: ${opp.confidenceScore}/100',
                              style: TextStyle(
                                color: confidenceColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 10,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // 4-колонковий рядок квантових метрик: Дисконт, RSI, Taker Buy, R:R
                  Row(
                    children: [
                      _buildMetricTile(
                        label: 'Дисконт 90D',
                        value: '-${opp.dropFromPeakPct.toStringAsFixed(1)}%',
                        valueColor: AppColors.redTask,
                      ),
                      const SizedBox(width: 4),
                      _buildMetricTile(
                        label: 'RSI (14D)',
                        value: opp.rsi.toStringAsFixed(1),
                        valueColor: opp.rsi <= 42 ? AppColors.greenTask : AppColors.textPrimary,
                      ),
                      const SizedBox(width: 4),
                      _buildMetricTile(
                        label: 'Викуп (Taker)',
                        value: '${opp.takerBuyRatioPct.toStringAsFixed(1)}%',
                        valueColor: opp.takerBuyRatioPct >= 51.5 ? AppColors.greenTask : AppColors.textPrimary,
                      ),
                      const SizedBox(width: 4),
                      _buildMetricTile(
                        label: 'R:R Профіт',
                        value: opp.riskRewardRatio > 0 ? '1:${opp.riskRewardRatio.toStringAsFixed(1)}' : opp.riskLevel,
                        valueColor: AppColors.accentLight,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Роздільник
          const Divider(height: 1, color: AppColors.border),

          // Математичні рівні Входу, TP1, TP2, Stop-Loss та Панель дій
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Рядок: Зона входу DCA та Захисний Стоп-Лос
                Row(
                  children: [
                    // Зона DCA
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceVariant.withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(7),
                          border: Border.all(color: AppColors.border.withValues(alpha: 0.6)),
                        ),
                        child: Row(
                          children: [
                            const Text('DCA: ', style: TextStyle(color: AppColors.textDisabled, fontSize: 10)),
                            Expanded(
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  '\$${_formatPrice(opp.entryZoneMin)} – \$${_formatPrice(opp.entryZoneMax)}',
                                  style: const TextStyle(color: AppColors.textPrimary, fontSize: 11, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    // Стоп-лос
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                        decoration: BoxDecoration(
                          color: AppColors.redTask.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(7),
                          border: Border.all(color: AppColors.redTask.withValues(alpha: 0.25)),
                        ),
                        child: Row(
                          children: [
                            const Text('SL: ', style: TextStyle(color: AppColors.redTask, fontSize: 10, fontWeight: FontWeight.bold)),
                            Expanded(
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  '\$${_formatPrice(opp.stopLoss)} (-${slPct.toStringAsFixed(1)}%)',
                                  style: const TextStyle(color: AppColors.redTask, fontSize: 11, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),

                // 2. Рядок: Тейк-профіти TP1 та TP2
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppColors.greenTask.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(7),
                    border: Border.all(color: AppColors.greenTask.withValues(alpha: 0.25)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.flag_outlined, size: 13, color: AppColors.greenTask),
                      const SizedBox(width: 5),
                      const Text('Тейки: ', style: TextStyle(color: AppColors.greenTask, fontSize: 10, fontWeight: FontWeight.bold)),
                      Expanded(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'TP1 \$${_formatPrice(opp.targetPrice1)} (+${tp1Pct.toStringAsFixed(0)}%)   ·   TP2 \$${_formatPrice(opp.targetPrice2)} (+${tp2Pct.toStringAsFixed(0)}%)',
                            style: const TextStyle(color: AppColors.greenTask, fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),

                // 3. Рядок дій: Перемикач плану + Кнопка "В DCA"
                Row(
                  children: [
                    // Кнопка розгортання/згортання
                    Expanded(
                      child: InkWell(
                        onTap: () => setState(() => _isExpanded = !_isExpanded),
                        borderRadius: BorderRadius.circular(8),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                _isExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                                color: AppColors.accentLight,
                                size: 18,
                              ),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  _isExpanded ? 'Згорнути план' : 'Деталі плану & TP/SL',
                                  style: const TextStyle(
                                    color: AppColors.accentLight,
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Кнопка додавання в DCA
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.accent.withValues(alpha: 0.15),
                        foregroundColor: AppColors.accentLight,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        minimumSize: const Size(0, 34),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(9),
                          side: const BorderSide(color: AppColors.accent),
                        ),
                        elevation: 0,
                      ),
                      icon: const Icon(Icons.add_shopping_cart_rounded, size: 14),
                      label: const Text(
                        'В DCA',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                      onPressed: widget.onAddToDca,
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Розгорнута секція: Повний торговий план + Умови Тейк-Профіту та Стоп-Лосу
          if (_isExpanded) ...[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant.withValues(alpha: 0.5),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(16),
                  bottomRight: Radius.circular(16),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. Технічний аналіз
                  _buildAnalysisBlock(
                    icon: Icons.trending_up_rounded,
                    iconColor: AppColors.blueTask,
                    title: '1. ТЕХНІЧНА СТРУКТУРА ТА ІНДИКАТОРИ (90D)',
                    content: opp.technicalReason,
                  ),
                  const SizedBox(height: 10),

                  // 2. Order Flow та Smart Money
                  _buildAnalysisBlock(
                    icon: Icons.bolt_rounded,
                    iconColor: AppColors.warning,
                    title: '2. ORDER FLOW (TAKER BUY) & ПОГЛИНАННЯ КИТІВ',
                    content: opp.smartMoneyCatalyst,
                  ),
                  const SizedBox(height: 10),

                  // 3. DCA Архітектура входу
                  _buildAnalysisBlock(
                    icon: Icons.pie_chart_outline_rounded,
                    iconColor: AppColors.accentLight,
                    title: '3. АРХІТЕКТУРА ВХОДУ ТА ДОБОРУ ПОЗИЦІЇ',
                    content: opp.dcaStrategy,
                  ),
                  const SizedBox(height: 12),

                  // 4. ПРОТОКОЛ ТЕЙК-ПРОФІТУ (КОЛИ ФІКСУВАТИ ПРИБУТОК)
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.greenTask.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.greenTask.withValues(alpha: 0.3)),
                    ),
                    child: _buildAnalysisBlock(
                      icon: Icons.ads_click_rounded,
                      iconColor: AppColors.greenTask,
                      title: '4. КОЛИ РОБИТИ ТЕЙК-ПРОФІТ (TP1 / TP2 / ДОСТРОКОВО)',
                      content: opp.tpTriggerRule.isNotEmpty
                          ? opp.tpTriggerRule
                          : 'На TP1 (\$${_formatPrice(opp.targetPrice1)}, +${tp1Pct.toStringAsFixed(1)}%) зафіксувати 50% позиції та перевести Stop-Loss у беззбиток. На TP2 (\$${_formatPrice(opp.targetPrice2)}, +${tp2Pct.toStringAsFixed(1)}%) закрити решту або увімкнути трейлінг по EMA 20.',
                    ),
                  ),
                  const SizedBox(height: 10),

                  // 5. ПРОТОКОЛ СТОП-ЛОСУ (КОЛИ ВИХОДИТИ В МІНУС)
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.redTask.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.redTask.withValues(alpha: 0.3)),
                    ),
                    child: _buildAnalysisBlock(
                      icon: Icons.shield_outlined,
                      iconColor: AppColors.redTask,
                      title: '5. КОЛИ РОБИТИ СТОП-ЛОС (ЗАХИСТ ВІД СВІПІВ)',
                      content: opp.slTriggerRule.isNotEmpty
                          ? opp.slTriggerRule
                          : 'Стоп-рівень \$${_formatPrice(opp.stopLoss)} (-${slPct.toStringAsFixed(1)}%) розрахований за структурною підтримкою мінус 1.2×ATR. Вихід тільки при закритті свічки 4H/1D нижче цього рівня.',
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMetricTile({
    required String label,
    required String value,
    required Color valueColor,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        decoration: BoxDecoration(
          color: AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                label,
                style: const TextStyle(color: AppColors.textDisabled, fontSize: 8.5),
                maxLines: 1,
              ),
            ),
            const SizedBox(height: 2),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value,
                style: TextStyle(
                  color: valueColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 11.5,
                ),
                maxLines: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnalysisBlock({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String content,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: iconColor, size: 14),
            const SizedBox(width: 5),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  color: iconColor,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          content,
          style: const TextStyle(color: AppColors.textPrimary, fontSize: 12, height: 1.35),
        ),
      ],
    );
  }

  String _formatPrice(double val) {
    if (val >= 1000) {
      return NumberFormat('#,##0.00', 'en_US').format(val);
    } else if (val >= 1) {
      return val.toStringAsFixed(2);
    } else if (val > 0) {
      return val.toStringAsFixed(4);
    } else {
      return '0.00';
    }
  }
}

