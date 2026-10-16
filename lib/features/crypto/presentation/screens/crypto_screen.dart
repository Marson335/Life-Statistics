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
                                color: (isLong ? AppColors.greenTask : AppColors.redTask).withOpacity(0.15),
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
                      color: AppColors.greenTask.withOpacity(0.15),
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
    final groupedCoins = state.groupedDcaCoins;

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
          const SizedBox(height: 18),

          // 2. ЗАГОЛОВОК СПИСКУ МОНЕТ
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'МОНЕТИ В НАКОПИЧЕННІ (${groupedCoins.length})',
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
                'Натисніть для траншів',
                style: TextStyle(color: AppColors.accentLight, fontSize: 11, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // 3. СПИСОК ГРУПОВАНИХ МОНЕТ З РОЗГОРТАННЯМ ТРАНШІВ
          if (groupedCoins.isEmpty)
            _buildEmptyState(
              'Немає активних покупок. Натисніть "З Binance (FIFO)" для автоматичного завантаження угод з біржі або "+ Вручну" щоб додати купівлю.',
            )
          else
            ...groupedCoins.map((coin) => _DcaCoinExpandableCard(
                  coin: coin,
                  notifier: notifier,
                )),
        ],
      ),
    );
  }

  // ==========================================
  // 5. ВКЛАДКА: AI-АУДИТ (LLAMA 3.3 70B НА GROQ)
  // ==========================================
  Widget _buildAiAuditTab(CryptoPortfolioState state, CryptoPortfolioNotifier notifier) {
    final report = state.auditReport;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Верхній банер аудиту
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppColors.accent.withOpacity(0.2),
                AppColors.surface,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.accent.withOpacity(0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.auto_awesome_rounded, color: AppColors.accentLight, size: 24),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'AI-Аудит Портфелю (Llama 3.3 70B)',
                      style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 17),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              const Text(
                'Професійний фінансовий аналіз концентрації активів, достатності кеш-подушки та сітки фіксації прибутку без використання домашнього ПК.',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: state.isAuditing
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : const Icon(Icons.psychology_rounded, color: Colors.white),
                  label: Text(
                    state.isAuditing ? 'Аналізуємо портфель...' : 'Запустити аудит портфелю',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  onPressed: state.isAuditing ? null : () => notifier.runAiAudit(),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        if (report != null) ...[
          // Оцінка здоров'я та Диверсифікація
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    children: [
                      const Text('Оцінка здоров\'я', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                      const SizedBox(height: 8),
                      Text(
                        '${report.overallHealthScore}/100',
                        style: TextStyle(
                          color: _getHealthScoreColor(report.overallHealthScore),
                          fontWeight: FontWeight.bold,
                          fontSize: 26,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    children: [
                      const Text('Диверсифікація', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                      const SizedBox(height: 8),
                      Text(
                        report.diversificationStatus,
                        style: const TextStyle(
                          color: AppColors.blueTask,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Стратегічний висновок
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
                const Row(
                  children: [
                    Icon(Icons.lightbulb_outline_rounded, color: AppColors.warning, size: 18),
                    SizedBox(width: 6),
                    Text('СТРАТЕГІЧНИЙ ВИСНОВОК ТРЕЙДЕРА:', style: TextStyle(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  report.strategicSummary,
                  style: const TextStyle(color: AppColors.textPrimary, fontSize: 14, height: 1.4),
                ),
                if (report.cashReserveComment.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Кеш-подушка: ${report.cashReserveComment}',
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Поради по кожній монеті
          const Text(
            'РЕКОМЕНДАЦІЇ ЩОДО АКТИВІВ:',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 0.8),
          ),
          const SizedBox(height: 8),
          ...report.assetRecommendations.map((item) {
            return Container(
              margin: const EdgeInsets.symmetric(vertical: 4),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(14),
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
                            Flexible(
                              child: Text(
                                item.symbol,
                                style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 16),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            _buildActionBadge(item.action),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      _buildRiskBadge(item.riskLevel),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    item.reason,
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.3),
                  ),
                ],
              ),
            );
          }),
        ] else ...[
          _buildEmptyState('Натисніть кнопку вище, щоб штучний інтелект проаналізував ваш портфель.'),
        ],
      ],
    );
  }

  Widget _buildActionBadge(String action) {
    Color color;
    switch (action.toUpperCase()) {
      case 'TAKE_PROFIT':
        color = AppColors.greenTask;
        break;
      case 'ACCUMULATE':
        color = AppColors.blueTask;
        break;
      case 'REDUCE':
        color = AppColors.redTask;
        break;
      default:
        color = AppColors.warning;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        action,
        style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 11),
      ),
    );
  }

  Widget _buildRiskBadge(String risk) {
    Color color = risk == 'HIGH' ? AppColors.redTask : (risk == 'MEDIUM' ? AppColors.warning : AppColors.greenTask);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        'Ризик: $risk',
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
        initialNotes: 'AI-Радар: Вхід \$${opp.entryZoneMin}-\$${opp.entryZoneMax}, TP1 \$${opp.targetPrice1}, TP2 \$${opp.targetPrice2}, SL \$${opp.stopLoss}. Стратегія: ${opp.dcaStrategy}',
        onAdd: (tx) => notifier.addDcaTransaction(tx),
      ),
    );
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
                            'AI-Радар Монет (350+ Spot пар)',
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
                            'Пошук точок розвороту та накопичення',
                            style: TextStyle(color: AppColors.textSecondary, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                const Text(
                  'Двоетапний сканер ринку: квантитативний аналіз просадок, RSI та ліквідності Binance + аналіз мульти-агентним інвестиційним AI-комітетом.',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 12, height: 1.3),
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
                            ? 'Запустити AI-Радар ринку'
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
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.groups_rounded, color: AppColors.blueTask, size: 18),
                          SizedBox(width: 6),
                          Text(
                            'ВИСНОВОК AI-КОМІТЕТУ',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ],
                      ),
                      _buildMarketRegimeBadge(report.marketRegime),
                    ],
                  ),
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
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'ТОП-ЗНАХІДКИ ДЛЯ DCA-НАБОРУ (${report.opportunities.length})',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.8,
                  ),
                ),
                Text(
                  '${report.totalCoinsScanned} пар перевірено',
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
          // Головний рядок монети
          InkWell(
            onTap: () => setState(() => _isExpanded = !_isExpanded),
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: AppColors.accent.withValues(alpha: 0.15),
                    child: Text(
                      coin.symbol.length > 3 ? coin.symbol.substring(0, 3) : coin.symbol,
                      style: const TextStyle(
                        color: AppColors.accentLight,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
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
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                              decoration: BoxDecoration(
                                color: AppColors.surfaceVariant,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '${coin.tranches.length} ${coin.tranches.length == 1 ? 'покупка' : 'покупки'}',
                                style: const TextStyle(color: AppColors.textSecondary, fontSize: 10, fontWeight: FontWeight.w600),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            '${_formatAmount(coin.totalAmount)} шт · Сер: \$${_formatPrice(coin.avgEntryPrice)}',
                            style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '\$${_formatPrice(coin.currentPrice)}',
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: pnlColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '${isPositive ? '+' : ''}${coin.pnlPct.toStringAsFixed(2)}%',
                          style: TextStyle(
                            color: pnlColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    _isExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                    color: AppColors.textSecondary,
                    size: 20,
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
    final isBinance = t.walletType == 'Binance Spot';
    final isConvert = t.notes.contains('Convert');

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Ліва колонка: Дата + бейдж джерела та Кількість монет і Ціна
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                      decoration: BoxDecoration(
                        color: isBinance
                            ? (isConvert
                                ? AppColors.accent.withValues(alpha: 0.15)
                                : const Color(0xFFF3BA2F).withValues(alpha: 0.15))
                            : AppColors.surfaceVariant,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        isBinance ? (isConvert ? 'Convert' : 'Binance') : 'Ручна',
                        style: TextStyle(
                          color: isBinance
                              ? (isConvert ? AppColors.accentLight : const Color(0xFFF3BA2F))
                              : AppColors.textSecondary,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
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
                const SizedBox(height: 4),
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
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        'по \$${_formatPrice(t.buyPrice)}',
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 1),
                Text(
                  'Разом: \$${((t.amount * t.buyPrice) + t.fee).toStringAsFixed(2)}',
                  style: const TextStyle(color: AppColors.textDisabled, fontSize: 10),
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
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
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
              const SizedBox(height: 2),
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

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _isExpanded ? AppColors.accent.withValues(alpha: 0.4) : AppColors.border,
        ),
      ),
      child: Column(
        children: [
          // Шапка картки: назва монети, поточна ціна, впевненість
          InkWell(
            onTap: () => setState(() => _isExpanded = !_isExpanded),
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
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
                                  child: const Text(
                                    'USDT',
                                    style: TextStyle(color: AppColors.textDisabled, fontSize: 9, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              opp.sector.isNotEmpty ? opp.sector : 'Spot',
                              style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
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
                          const SizedBox(height: 2),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: confidenceColor.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'AI: ${opp.confidenceScore}/100',
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

                  // Рядок метрик: Просадка, RSI, Об'єм
                  Row(
                    children: [
                      // Просадка від піку 60д
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceVariant,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Просадка 60д', style: TextStyle(color: AppColors.textDisabled, fontSize: 9)),
                              const SizedBox(height: 2),
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  '-${opp.dropFromPeakPct.toStringAsFixed(1)}%',
                                  style: const TextStyle(
                                    color: AppColors.redTask,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      // RSI 14
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceVariant,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('RSI (14D)', style: TextStyle(color: AppColors.textDisabled, fontSize: 9)),
                              const SizedBox(height: 2),
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  opp.rsi.toStringAsFixed(1),
                                  style: TextStyle(
                                    color: opp.rsi <= 35 ? AppColors.greenTask : AppColors.textPrimary,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      // Ризик-профіль
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceVariant,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Ризик / R:R', style: TextStyle(color: AppColors.textDisabled, fontSize: 9)),
                              const SizedBox(height: 2),
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  opp.riskRewardRatio > 0 ? '1:${opp.riskRewardRatio.toStringAsFixed(1)}' : opp.riskLevel,
                                  style: const TextStyle(
                                    color: AppColors.accentLight,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Роздільник
          const Divider(height: 1, color: AppColors.border),

          // Цілі та дія
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Text('Вхід: ', style: TextStyle(color: AppColors.textDisabled, fontSize: 11)),
                          Flexible(
                            child: Text(
                              '\$${_formatPrice(opp.entryZoneMin)} - \$${_formatPrice(opp.entryZoneMax)}',
                              style: const TextStyle(color: AppColors.textPrimary, fontSize: 11, fontWeight: FontWeight.w600),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          const Text('Цілі: ', style: TextStyle(color: AppColors.textDisabled, fontSize: 11)),
                          Flexible(
                            child: Text(
                              'TP1 \$${_formatPrice(opp.targetPrice1)} · TP2 \$${_formatPrice(opp.targetPrice2)}',
                              style: const TextStyle(color: AppColors.greenTask, fontSize: 11, fontWeight: FontWeight.bold),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accent.withValues(alpha: 0.15),
                    foregroundColor: AppColors.accentLight,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                      side: const BorderSide(color: AppColors.accent),
                    ),
                    elevation: 0,
                  ),
                  icon: const Icon(Icons.add_shopping_cart_rounded, size: 15),
                  label: const Text('В DCA', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  onPressed: widget.onAddToDca,
                ),
                const SizedBox(width: 4),
                IconButton(
                  icon: Icon(
                    _isExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                    color: AppColors.textSecondary,
                    size: 20,
                  ),
                  onPressed: () => setState(() => _isExpanded = !_isExpanded),
                  tooltip: _isExpanded ? 'Згорнути аналіз' : 'Розгорнути AI-аналіз',
                ),
              ],
            ),
          ),

          // Розгорнута секція multi-agent аналізу
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
                    title: '1. ТЕХНІЧНИЙ СЕТАП (1D / 4H)',
                    content: opp.technicalReason,
                  ),
                  const SizedBox(height: 10),

                  // 2. Каталізатори та наратив
                  _buildAnalysisBlock(
                    icon: Icons.bolt_rounded,
                    iconColor: AppColors.warning,
                    title: '2. СМАРТ-МАНІ & НОВИННІ КАТАЛІЗАТОРИ',
                    content: opp.smartMoneyCatalyst,
                  ),
                  const SizedBox(height: 10),

                  // 3. DCA Архітектура
                  _buildAnalysisBlock(
                    icon: Icons.pie_chart_outline_rounded,
                    iconColor: AppColors.greenTask,
                    title: '3. РЕКОМЕНДОВАНА DCA-СТРАТЕГІЯ',
                    content: opp.dcaStrategy,
                  ),
                  const SizedBox(height: 8),

                  // Stop Loss та Горизонт
                  Row(
                    children: [
                      const Icon(Icons.shield_outlined, color: AppColors.redTask, size: 14),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          'Stop-Loss (інвалідація): \$${_formatPrice(opp.stopLoss)}',
                          style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Ризик: ${opp.riskLevel}',
                        style: const TextStyle(color: AppColors.textDisabled, fontSize: 10),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
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
            Text(
              title,
              style: TextStyle(
                color: iconColor,
                fontSize: 10,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
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

