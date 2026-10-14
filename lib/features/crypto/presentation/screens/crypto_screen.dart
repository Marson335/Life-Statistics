import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
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
    _tabController = TabController(length: 5, vsync: this);
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

          // 5. ВКЛАДКА "AI-АУДИТ" (Groq Llama 3.3 70B)
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
          }).toList(),
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
  Widget _buildDcaTab(CryptoPortfolioState state, CryptoPortfolioNotifier notifier) {
    double totalInvested = 0.0;
    for (final tx in state.dcaTransactions) {
      totalInvested += (tx.amount * tx.buyPrice) + tx.fee;
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Загальна DCA картка
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Всього інвестовано (DCA)',
                          style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '\$${totalInvested.toStringAsFixed(2)}',
                          style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 20),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accent,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: const Icon(Icons.add, color: Colors.white, size: 18),
                    label: const Text('Додати', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    onPressed: () => _openAddDcaDialog(notifier),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                'ІСТОРІЯ ТРАНЗАКЦІЙ (${state.dcaTransactions.length})',
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 0.8),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (state.dcaTransactions.isEmpty)
          _buildEmptyState('Немає збережених транзакцій DCA. Натисніть "+ Додати" щоб зафіксувати вхід у монету.')
        else
          ...state.dcaTransactions.map((tx) {
            final totalCost = (tx.amount * tx.buyPrice) + tx.fee;
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
                          radius: 18,
                          backgroundColor: AppColors.accent.withOpacity(0.15),
                          child: Text(
                            tx.symbol.length > 3 ? tx.symbol.substring(0, 3) : tx.symbol,
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
                                      tx.symbol,
                                      style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 15),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                    decoration: BoxDecoration(
                                      color: AppColors.surfaceVariant,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(tx.walletType, style: const TextStyle(color: AppColors.textSecondary, fontSize: 9)),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${tx.amount} шт @ \$${tx.buyPrice.toStringAsFixed(2)}',
                                style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (tx.notes.isNotEmpty)
                                Text(
                                  tx.notes,
                                  style: const TextStyle(color: AppColors.accentLight, fontSize: 10),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text('\$${totalCost.toStringAsFixed(2)}', style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 14)),
                          Text(
                            '${tx.txDate.day.toString().padLeft(2, '0')}.${tx.txDate.month.toString().padLeft(2, '0')}.${tx.txDate.year}',
                            style: const TextStyle(color: AppColors.textDisabled, fontSize: 11),
                          ),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline_rounded, color: AppColors.textDisabled, size: 18),
                        onPressed: () => notifier.deleteDcaTransaction(tx.id),
                        tooltip: 'Видалити',
                        padding: const EdgeInsets.all(4),
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }),
      ],
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
}
