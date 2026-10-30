import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
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
import '../widgets/tp_sl_dialog.dart';

class CryptoScreen extends ConsumerStatefulWidget {
  const CryptoScreen({super.key});

  @override
  ConsumerState<CryptoScreen> createState() => _CryptoScreenState();
}

class _CryptoScreenState extends ConsumerState<CryptoScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late TabController _tabController;
  int _binanceSubTab = 0; // 0: Spot, 1: Futures, 2: Earn
  int _dcaFilterIndex = 0; // 0: Всі, 1: Binance, 2: Web3, 3: Ручні
  int _radarFilterIndex = 0; // 0: Всі, 1: Купувати зараз, 2: Лімітка / Пробій
  int _fundamentalFilterIndex = 0; // 0: Всі L1, 1: Купувати, 2: Утримання, 3: Фіксація

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _tabController = TabController(length: 7, vsync: this);
    _tabController.addListener(_onTabChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(cryptoPortfolioProvider.notifier).startLiveStreaming();
    });
  }

  void _onTabChanged() {
    if (!_tabController.indexIsChanging && _tabController.index == 4) {
      final st = ref.read(cryptoPortfolioProvider);
      if (st.fundamentalReport == null && !st.isAnalyzingFundamentals) {
        ref.read(cryptoPortfolioProvider.notifier).runFundamentalAnalysis();
      }
    }
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
    _tabController.removeListener(_onTabChanged);
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
          IconButton(
            icon: const Icon(Icons.settings_outlined, color: AppColors.textSecondary, size: 22),
            tooltip: 'Налаштування',
            onPressed: () => context.go('/settings'),
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
            Tab(icon: Icon(Icons.layers_rounded, size: 18), text: 'Фундамент L1'),
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

          // 3. ВКЛАДКА "WEB3" (Solana + EVM/MetaMask + Bitcoin On-chain)
          _buildWeb3Tab(state, notifier),

          // 4. ВКЛАДКА "DCA ІСТОРІЯ"
          _buildDcaTab(state, notifier),

          // 5. ВКЛАДКА "ФУНДАМЕНТ L1" (Базові монети першого шару: BTC, ETH, SOL, BNB...)
          _buildFundamentalL1Tab(state, notifier),

          // 6. ВКЛАДКА "AI-РАДАР" (Сканер 350+ пар Binance)
          _buildAiRadarTab(state, notifier),

          // 7. ВКЛАДКА "AI-АУДИТ" (Groq Llama 3.3 70B)
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
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accent,
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: const Icon(Icons.add, color: Colors.black),
                    label: const Text('Додати DCA покупку', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
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
              color: isSelected ? Colors.black : AppColors.textSecondary,
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
                      Flexible(child: Text('Вхід: \$${_formatPrice(p.entryPrice)}', style: const TextStyle(color: AppColors.textSecondary, fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis)),
                      const SizedBox(width: 4),
                      Flexible(child: Text('Mark: \$${_formatPrice(p.markPrice)}', style: const TextStyle(color: AppColors.textSecondary, fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis)),
                      const SizedBox(width: 4),
                      Flexible(child: Text('Liq: \$${_formatPrice(p.liquidationPrice)}', style: const TextStyle(color: AppColors.warning, fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis)),
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
  // 3. ВКЛАДКА: WEB3 (ETHEREUM/EVM, SOLANA & BITCOIN)
  // ==========================================
  Widget _buildWeb3Tab(CryptoPortfolioState state, CryptoPortfolioNotifier notifier) {
    final allWeb3Empty = state.evmAssets.isEmpty && state.solanaAssets.isEmpty && state.btcAssets.isEmpty;

    return RefreshIndicator(
      color: AppColors.accent,
      backgroundColor: AppColors.surface,
      onRefresh: () => notifier.refreshPortfolio(),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 1. ETHEREUM & EVM / METAMASK
          _buildWeb3ChainSection(
            chainName: 'Ethereum & EVM (MetaMask / Trust)',
            subtitle: 'ERC-20, ETH, WBTC та сумісні токени',
            icon: Icons.shield_rounded,
            iconColor: const Color(0xFF627EEA),
            assets: state.evmAssets,
          ),
          const SizedBox(height: 16),

          // 2. SOLANA
          _buildWeb3ChainSection(
            chainName: 'Solana (Phantom / Solflare)',
            subtitle: 'SPL токени та нативний баланс SOL',
            icon: Icons.flash_on_rounded,
            iconColor: const Color(0xFF14F195),
            assets: state.solanaAssets,
          ),
          const SizedBox(height: 16),

          // 3. BITCOIN ON-CHAIN
          _buildWeb3ChainSection(
            chainName: 'Bitcoin (On-chain / Mempool)',
            subtitle: 'Нативний BTC баланс у блокчейні Bitcoin',
            icon: Icons.currency_bitcoin_rounded,
            iconColor: const Color(0xFFF7931A),
            assets: state.btcAssets,
          ),

          if (allWeb3Empty) ...[
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.accent.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.account_balance_wallet_outlined, color: AppColors.accentLight, size: 32),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Блокчейн-гаманці не підключені',
                    style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Додайте ваші адреси (MetaMask EVM 0x..., Phantom Solana, Bitcoin) у Налаштуваннях, і їхні баланси будуть автоматично підвантажені в портфель.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 12, height: 1.4),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildWeb3ChainSection({
    required String chainName,
    String? subtitle,
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
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: iconColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(icon, color: iconColor, size: 18),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            chainName,
                            style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 13.5),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (subtitle != null) ...[
                            const SizedBox(height: 1),
                            Text(
                              subtitle,
                              style: const TextStyle(color: AppColors.textDisabled, fontSize: 9.5),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ],
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
                            CircleAvatar(
                              radius: 12,
                              backgroundColor: iconColor.withValues(alpha: 0.15),
                              child: Text(
                                a.symbol.length > 3 ? a.symbol.substring(0, 3) : a.symbol,
                                style: TextStyle(color: iconColor, fontSize: 8.5, fontWeight: FontWeight.bold),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(a.symbol, style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 13)),
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
                          Text(
                            a.totalUsd > 0 ? '\$${a.totalUsd.toStringAsFixed(2)}' : (a.priceUsd > 0 ? '\$${(a.amount * a.priceUsd).toStringAsFixed(2)}' : '—'),
                            style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 13),
                          ),
                          Text(
                            '${_formatAmount(a.amount)} ${a.priceUsd > 0 ? '@ \$${_formatPrice(a.priceUsd)}' : ''}',
                            style: const TextStyle(color: AppColors.textSecondary, fontSize: 10),
                          ),
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
    final web3Coins = state.web3DcaCoins;
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
                    Flexible(
                      child: Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          const Text(
                            'АКТИВНИЙ DCA (FIFO)',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.8,
                            ),
                          ),
                          if (state.isLive)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                              decoration: BoxDecoration(
                                color: AppColors.greenTask.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: AppColors.greenTask.withValues(alpha: 0.4)),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  CircleAvatar(radius: 2.5, backgroundColor: AppColors.greenTask),
                                  SizedBox(width: 3),
                                  Text(
                                    'LIVE',
                                    style: TextStyle(
                                      color: AppColors.greenTask,
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Container(
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
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const Text(
                            'Чистий PnL',
                            style: TextStyle(color: AppColors.textSecondary, fontSize: 11),
                          ),
                          const SizedBox(height: 2),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerRight,
                            child: Text(
                              '${isPnlPositive ? '+' : '-'}\$${totals.totalPnlUsd.abs().toStringAsFixed(2)}',
                              style: TextStyle(
                                color: pnlColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerRight,
                            child: Text(
                              'Вкладено: \$${totals.totalInvested.toStringAsFixed(2)}',
                              style: const TextStyle(color: AppColors.textDisabled, fontSize: 10),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(color: AppColors.border, height: 1),
                const SizedBox(height: 14),

                // Кнопки дій: Синхронізація Binance, Web3 On-chain та Ручне додавання
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFF3BA2F).withValues(alpha: 0.15),
                          foregroundColor: const Color(0xFFF3BA2F),
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                            side: BorderSide(color: const Color(0xFFF3BA2F).withValues(alpha: 0.4)),
                          ),
                        ),
                        onPressed: state.isLoading ? null : () => notifier.syncBinanceDca(),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.sync_rounded, size: 14),
                            SizedBox(width: 4),
                            Flexible(
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  'Binance',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.accent.withValues(alpha: 0.15),
                          foregroundColor: AppColors.accentLight,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                            side: BorderSide(color: AppColors.accent.withValues(alpha: 0.4)),
                          ),
                        ),
                        onPressed: state.isLoading ? null : () => notifier.syncWeb3Dca(),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.account_balance_wallet_rounded, size: 14),
                            SizedBox(width: 4),
                            Flexible(
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  'З Web3',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.accent,
                          foregroundColor: Colors.black,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: () => _openAddDcaDialog(notifier),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.add_rounded, size: 15, color: Colors.black),
                            SizedBox(width: 4),
                            Flexible(
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  'Вручну',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.black),
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
          const SizedBox(height: 16),

          // 2. ФІЛЬТР-СЕЛЕКТОР: ВСІ | BINANCE | WEB3 ON-CHAIN | РУЧНІ
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
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
                  label: 'Web3 On-chain (${web3Coins.length})',
                  icon: Icons.account_balance_wallet_rounded,
                  iconColor: AppColors.accentLight,
                  isSelected: _dcaFilterIndex == 2,
                  onTap: () => setState(() => _dcaFilterIndex = 2),
                ),
                const SizedBox(width: 8),
                _buildDcaFilterChip(
                  label: 'Ручні (${manualCoins.length})',
                  icon: Icons.edit_note_rounded,
                  iconColor: AppColors.greenTask,
                  isSelected: _dcaFilterIndex == 3,
                  onTap: () => setState(() => _dcaFilterIndex = 3),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // 3. ВІДОБРАЖЕННЯ СПИСКУ ЗА ОБРАНИМ ФІЛЬТРОМ
          if (_dcaFilterIndex == 1) ...[
            // Фільтр: Тільки Binance
            if (binanceCoins.isEmpty)
              _buildEmptyState(
                'Немає активних закупок з Binance.\n\nНатисніть кнопку "Binance" вище для автоматичного розрахунку покупок та підтягування поточних активів.',
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
                    holdingItem: _findHoldingForCoin(state, coin),
                  )),
            ],
          ] else if (_dcaFilterIndex == 2) ...[
            // Фільтр: Тільки Web3 On-chain (Bitcoin, Ethereum/MetaMask, Solana)
            if (web3Coins.isEmpty)
              _buildEmptyState(
                'Немає активних Web3 монет.\n\nВкажіть адреси гаманців (Bitcoin On-chain, MetaMask / EVM або Solana) у Налаштуваннях або натисніть "З Web3" для синхронізації.',
              )
            else ...[
              _buildDcaSectionHeader(
                title: '🌐 НЕКАСТОДІАЛЬНІ WEB3 ГАМАНЦІ',
                count: web3Coins.length,
                subtitle: 'Bitcoin On-chain, MetaMask (EVM) та Solana',
                accentColor: AppColors.accentLight,
              ),
              ...web3Coins.map((coin) => _DcaCoinExpandableCard(
                    coin: coin,
                    notifier: notifier,
                    holdingItem: _findHoldingForCoin(state, coin),
                  )),
            ],
          ] else if (_dcaFilterIndex == 3) ...[
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
                accentColor: AppColors.greenTask,
              ),
              ...manualCoins.map((coin) => _DcaCoinExpandableCard(
                    coin: coin,
                    notifier: notifier,
                    holdingItem: _findHoldingForCoin(state, coin),
                  )),
            ],
          ] else ...[
            // Фільтр: Всі (Розділені секціями)
            if (allCoins.isEmpty)
              _buildEmptyState(
                'Немає активних покупок.\n\nНатисніть "Binance", "З Web3" або "Вручну" щоб додати активи до портфеля.',
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
                      holdingItem: _findHoldingForCoin(state, coin),
                    )),
              ],
              if (binanceCoins.isNotEmpty && (web3Coins.isNotEmpty || manualCoins.isNotEmpty))
                const SizedBox(height: 16),
              if (web3Coins.isNotEmpty) ...[
                _buildDcaSectionHeader(
                  title: '🌐 НЕКАСТОДІАЛЬНІ WEB3 ГАМАНЦІ',
                  count: web3Coins.length,
                  subtitle: 'Bitcoin On-chain, MetaMask (EVM) та Solana',
                  accentColor: AppColors.accentLight,
                ),
                ...web3Coins.map((coin) => _DcaCoinExpandableCard(
                      coin: coin,
                      notifier: notifier,
                      holdingItem: _findHoldingForCoin(state, coin),
                    )),
              ],
              if (web3Coins.isNotEmpty && manualCoins.isNotEmpty)
                const SizedBox(height: 16),
              if (manualCoins.isNotEmpty) ...[
                _buildDcaSectionHeader(
                  title: '✍️ РУЧНІ DCA ЗАПИСИ',
                  count: manualCoins.length,
                  subtitle: 'Додані самостійно користувачем',
                  accentColor: AppColors.greenTask,
                ),
                ...manualCoins.map((coin) => _DcaCoinExpandableCard(
                      coin: coin,
                      notifier: notifier,
                      holdingItem: _findHoldingForCoin(state, coin),
                    )),
              ],
            ],
          ],
        ],
      ),
    );
  }

  HoldingItem? _findHoldingForCoin(CryptoPortfolioState state, DcaGroupedCoin coin) {
    final sym = coin.symbol.toUpperCase();
    for (final h in state.overview.holdings) {
      if (h.symbol.toUpperCase() == sym) {
        return h;
      }
    }
    return null;
  }

  Widget _buildDcaFilterChip({
    required String label,
    IconData? icon,
    Color? iconColor,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
              Icon(icon, size: 14, color: iconColor ?? AppColors.textSecondary),
              const SizedBox(width: 5),
            ],
            Text(
              label,
              style: TextStyle(
                color: isSelected ? AppColors.textPrimary : AppColors.textSecondary,
                fontSize: 11.5,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              ),
              maxLines: 1,
            ),
          ],
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
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      elevation: 0,
                    ),
                    icon: state.isAuditing
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2),
                          )
                        : const Icon(Icons.psychology_rounded, color: Colors.black, size: 20),
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
    final statusTxt = switch (opp.entryStatus) {
      RadarEntryStatus.waitBreakout => 'STOP-LIMIT ПРОБІЙ \$${_formatDialogPrice(opp.triggerPrice)}',
      RadarEntryStatus.waitPullback => 'ЛІМІТКА НА ВІДКАТІ \$${_formatDialogPrice(opp.triggerPrice)}',
      _ => 'ВХІД ЗАРАЗ \$${_formatDialogPrice(opp.currentPrice)}',
    };
    final sizeTxt = opp.positionSizeUsd > 0
        ? '${opp.positionSizePct.toStringAsFixed(1)}% депозиту (~\$${opp.positionSizeUsd.toStringAsFixed(0)})'
        : '${opp.positionSizePct.toStringAsFixed(1)}% депозиту';

    showDialog(
      context: context,
      builder: (ctx) => DcaAddDialog(
        initialSymbol: opp.symbol,
        initialPrice: opp.entryReference,
        initialNotes:
            'AI-Радар v3 [${opp.setupType} | $statusTxt]: '
            'Зона \$${_formatDialogPrice(opp.entryZoneMin)}-\$${_formatDialogPrice(opp.entryZoneMax)}, '
            'Розмір: $sizeTxt (ризик ${opp.riskPerTradePct.toStringAsFixed(2)}%), '
            'TP1 \$${_formatDialogPrice(opp.targetPrice1)} (50% + Б/З), '
            'TP2 \$${_formatDialogPrice(opp.targetPrice2)} (30% + 20% трейлінг EMA20), '
            'SL \$${_formatDialogPrice(opp.stopLoss)} (закриття 1D, авар. \$${_formatDialogPrice(opp.hardStopPrice > 0 ? opp.hardStopPrice : opp.stopLoss * 0.95)}, тайм-стоп ${opp.timeStopDays}д).',
        onAdd: (tx) => notifier.addDcaTransaction(tx),
      ),
    );
  }

  String _formatDialogPrice(double val) {
    if (val == 0) return '0.0000';
    final abs = val.abs();
    final sign = val < 0 ? '-' : '';
    if (abs >= 0.0001) return '$sign${abs.toStringAsFixed(4)}';
    return '$sign${abs.toStringAsFixed(6)}';
  }

  String _formatAmount(double amt) {
    if (amt >= 100) return amt.toStringAsFixed(2);
    if (amt >= 1) return amt.toStringAsFixed(4);
    return amt.toStringAsFixed(6).replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '');
  }

  String _formatPrice(double val) {
    if (val == 0) return '0.0000';
    final abs = val.abs();
    final sign = val < 0 ? '-' : '';
    if (abs >= 1000) {
      return '$sign${NumberFormat('#,##0.0000', 'en_US').format(abs)}';
    } else if (abs >= 0.0001) {
      return '$sign${abs.toStringAsFixed(4)}';
    } else {
      return '$sign${abs.toStringAsFixed(6)}';
    }
  }

  // ==========================================
  // 5. ВКЛАДКА: AI-РАДАР МОНЕТ (КВАНТОВИЙ ДВИГУН v3)
  // ==========================================
  Widget _buildAiRadarTab(CryptoPortfolioState state, CryptoPortfolioNotifier notifier) {
    final report = state.radarReport;
    final isScanning = state.isScanningMarket;

    final allOpps = report?.opportunities ?? const <AiMarketOpportunity>[];
    final buyNowOpps = allOpps.where((o) => o.entryStatus == RadarEntryStatus.buyNow).toList();
    final pendingOpps = allOpps.where((o) => o.entryStatus != RadarEntryStatus.buyNow).toList();

    final filteredOpps = switch (_radarFilterIndex) {
      1 => buyNowOpps,
      2 => pendingOpps,
      _ => allOpps,
    };

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
                            'Quant Smart Money Радар v3 (350+ пар)',
                            style: TextStyle(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.bold,
                              fontSize: 15.5,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          SizedBox(height: 2),
                          Text(
                            '230D Закриті свічки · RS vs BTC · Order Flow Δ · Історичний Hit-Rate TP1',
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
                  'Режимно-адаптивний алго-скринер: визначає фазу ринку (Risk-On / Neutral / Risk-Off) та ширину ринку (% монет > EMA50), аналізує до 200 ліквідних пар за 6 крос-секційними факторами, перевіряє історичний Hit-Rate досягнення TP1 за 200 днів, відсікає корельовані клони та розраховує точний розмір позиції від ризику.',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 11.5, height: 1.35),
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
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        elevation: 0,
                      ),
                      icon: const Icon(Icons.radar_rounded, size: 20, color: Colors.black),
                      label: Text(
                        (report == null || report.totalCoinsScanned == 0)
                            ? 'Запустити Quant AI-Радар v3'
                            : 'Пересканувати ринок (230D Квант-Аналіз)',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black),
                      ),
                      onPressed: () => notifier.scanMarketRadar(),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Якщо є результати звіту (навіть якщо 0 монет пройшли жорсткий фільтр — показуємо режим і воронку!)
          if (report != null && (report.opportunities.isNotEmpty || report.totalCoinsScanned > 0)) ...[
            // Картка режиму ринку, ширини ринку та воронки відбору
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
                      const Icon(Icons.analytics_outlined, color: AppColors.blueTask, size: 18),
                      const SizedBox(width: 6),
                      const Expanded(
                        child: Text(
                          'МАКРО-РЕЖИМ ТА ВОРОНКА ВІДБОРУ',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.7,
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
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceVariant,
                        borderRadius: BorderRadius.circular(7),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.currency_bitcoin_rounded, size: 15, color: Color(0xFFF3BA2F)),
                          const SizedBox(width: 5),
                          Expanded(
                            child: Text(
                              report.btcTrend,
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  // 3-колонкова панель макро-показників (Ширина ринку, Ризик на угоду, Воронка)
                  if (report.breadthPct >= 0 || report.coinsDeepAnalyzed > 0) ...[
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        _buildRadarSummaryStat(
                          label: 'Ширина (>EMA50)',
                          value: report.breadthPct >= 0 ? '${report.breadthPct.toStringAsFixed(0)}%' : '—',
                          valueColor: report.breadthPct >= 55
                              ? AppColors.greenTask
                              : (report.breadthPct <= 35 ? AppColors.redTask : AppColors.warning),
                        ),
                        const SizedBox(width: 6),
                        _buildRadarSummaryStat(
                          label: 'Ризик / угоду',
                          value: '${report.riskPerTradePct.toStringAsFixed(2)}%',
                          valueColor: AppColors.accentLight,
                        ),
                        const SizedBox(width: 6),
                        _buildRadarSummaryStat(
                          label: 'Аналіз 230D',
                          value: '${report.coinsDeepAnalyzed} пар',
                          valueColor: AppColors.blueTask,
                        ),
                        const SizedBox(width: 6),
                        _buildRadarSummaryStat(
                          label: 'Сетапи ➔ Топ',
                          value: '${report.setupsFound} ➔ ${report.opportunities.length}',
                          valueColor: AppColors.greenTask,
                        ),
                      ],
                    ),
                  ],

                  // Деталізація воронки відсіву (чому відсіяні інші монети)
                  if (report.funnel.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 5,
                      children: [
                        if ((report.funnel['illiquid'] ?? 0) > 0)
                          _buildRadarFunnelChip('Низька ліквідність: -${report.funnel['illiquid']}'),
                        if ((report.funnel['newListing'] ?? 0) > 0)
                          _buildRadarFunnelChip('Нові <120д: -${report.funnel['newListing']}'),
                        if ((report.funnel['pumpDump'] ?? 0) > 0)
                          _buildRadarFunnelChip('Памп/Дамп >45%: -${report.funnel['pumpDump']}'),
                        if ((report.funnel['noSetup'] ?? 0) > 0)
                          _buildRadarFunnelChip('Без сетапу: -${report.funnel['noSetup']}'),
                        if ((report.funnel['lowRR'] ?? 0) > 0)
                          _buildRadarFunnelChip('Слабкий R:R: -${report.funnel['lowRR']}'),
                        if ((report.funnel['wideStop'] ?? 0) > 0)
                          _buildRadarFunnelChip('Широкий стоп >18%: -${report.funnel['wideStop']}'),
                        if ((report.funnel['correlated'] ?? 0) > 0)
                          _buildRadarFunnelChip('Дублікати (корел. >0.85): -${report.funnel['correlated']}'),
                      ],
                    ),
                  ],

                  const SizedBox(height: 10),
                  Text(
                    report.macroSummary,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 12.5,
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
            const SizedBox(height: 14),

            // Перемикач фільтрів точок входу (Всі / Купувати зараз / Лімітка або Пробій)
            if (allOpps.isNotEmpty) ...[
              Row(
                children: [
                  _buildRadarFilterPill(
                    index: 0,
                    label: 'Всі (${allOpps.length})',
                    activeColor: AppColors.accentLight,
                  ),
                  const SizedBox(width: 6),
                  _buildRadarFilterPill(
                    index: 1,
                    label: '🟢 Купувати зараз (${buyNowOpps.length})',
                    activeColor: AppColors.greenTask,
                  ),
                  const SizedBox(width: 6),
                  _buildRadarFilterPill(
                    index: 2,
                    label: '⏳ Очікування (${pendingOpps.length})',
                    activeColor: AppColors.warning,
                  ),
                ],
              ),
              const SizedBox(height: 12),
            ],

            // Заголовок списку можливостей
            Row(
              children: [
                Expanded(
                  child: Text(
                    'КВАНТОВІ СИГНАЛИ (${filteredOpps.length})',
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
                  'Усього пар: ${report.totalCoinsScanned}',
                  style: const TextStyle(color: AppColors.textDisabled, fontSize: 11),
                ),
              ],
            ),
            const SizedBox(height: 8),

            if (filteredOpps.isEmpty)
              _buildEmptyState(
                _radarFilterIndex == 1
                    ? 'Зараз немає сетапів зі статусом «Купувати зараз».\nПерегляньте вкладку «⏳ Очікування» — там монети, де варто виставити лімітний ордер на відкаті або stop-limit на пробій.'
                    : 'У вибраній категорії немає активних сигналів.',
              )
            else
              ...filteredOpps.map((opp) => _RadarOpportunityCard(
                    opportunity: opp,
                    onAddToDca: () => _openAddDcaFromRadar(opp, notifier),
                  )),
          ] else if (!isScanning) ...[
            _buildEmptyState(
              'AI-Радар ще не сканував ринок у цій сесії.\n\nНатисніть кнопку вище, щоб проаналізувати до 200 ліквідних пар Binance за 230 закритими денними свічками, оцінити режим ринку, перевірити історичний Hit-Rate TP1 та отримати чіткі точки входу.',
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRadarSummaryStat({
    required String label,
    required String value,
    required Color valueColor,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 5),
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
                style: const TextStyle(color: AppColors.textDisabled, fontSize: 9),
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

  Widget _buildRadarFunnelChip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.6)),
      ),
      child: Text(
        text,
        style: const TextStyle(color: AppColors.textSecondary, fontSize: 9.5),
      ),
    );
  }

  Widget _buildRadarFilterPill({
    required int index,
    required String label,
    required Color activeColor,
  }) {
    final isSelected = _radarFilterIndex == index;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _radarFilterIndex = index),
        borderRadius: BorderRadius.circular(9),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 6),
          decoration: BoxDecoration(
            color: isSelected ? activeColor.withValues(alpha: 0.16) : AppColors.surface,
            borderRadius: BorderRadius.circular(9),
            border: Border.all(
              color: isSelected ? activeColor : AppColors.border,
              width: isSelected ? 1.2 : 1.0,
            ),
          ),
          alignment: Alignment.center,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              style: TextStyle(
                color: isSelected ? activeColor : AppColors.textSecondary,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                fontSize: 11,
              ),
              maxLines: 1,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMarketRegimeBadge(String regime) {
    Color color;
    String label = regime;
    switch (regime.toUpperCase()) {
      case 'RISK_ON':
      case 'ACCUMULATION':
        color = AppColors.greenTask;
        label = regime.toUpperCase() == 'RISK_ON' ? '🟢 RISK-ON (Бичачий)' : 'Зона накопичення';
        break;
      case 'NEUTRAL':
      case 'BULL_PULLBACK':
      case 'CONSOLIDATION':
        color = AppColors.blueTask;
        label = regime.toUpperCase() == 'NEUTRAL' ? '🟡 NEUTRAL (Змішаний)' : 'Консолідація';
        break;
      case 'RISK_OFF':
      case 'BEARISH_DIP':
        color = AppColors.warning;
        label = regime.toUpperCase() == 'RISK_OFF' ? '🛡️ RISK-OFF (Захисний)' : 'Ведмежа просадка';
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

  // ==========================================
  // 5. ВКЛАДКА: ФУНДАМЕНТАЛЬНІ МОНЕТИ ПЕРШОГО ШАРУ (LAYER-1 CORE)
  // ==========================================
  Widget _buildFundamentalL1Tab(CryptoPortfolioState state, CryptoPortfolioNotifier notifier) {
    final report = state.fundamentalReport;
    final isAnalyzing = state.isAnalyzingFundamentals;

    final allCoins = report?.coins ?? const <FundamentalCoinAnalysis>[];
    final buyCoins = allCoins.where((c) => c.isBuyRecommended).toList();
    final holdCoins = allCoins
        .where((c) => !c.isBuyRecommended && !c.isSellRecommended)
        .toList();
    final sellCoins = allCoins.where((c) => c.isSellRecommended).toList();

    final filteredCoins = switch (_fundamentalFilterIndex) {
      1 => buyCoins,
      2 => holdCoins,
      3 => sellCoins,
      _ => allCoins,
    };

    return RefreshIndicator(
      color: AppColors.accent,
      backgroundColor: AppColors.surface,
      onRefresh: () => notifier.runFundamentalAnalysis(),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Головний інституційний банер вкладки Фундамент L1
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.surface,
                  const Color(0xFFF7931A).withValues(alpha: 0.12),
                  AppColors.accent.withValues(alpha: 0.10),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
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
                        color: const Color(0xFFF7931A).withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.layers_rounded,
                        color: Color(0xFFF7931A),
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Фундаментальні L1 (База Крипторинку)',
                            style: TextStyle(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.bold,
                              fontSize: 15.5,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          SizedBox(height: 2),
                          Text(
                            'BTC · ETH · SOL · BNB · XRP · SUI · TON · AVAX · ADA · TRX',
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
                  'Інституційний циклічний алгоритм для базових блокчейнів першого рівня (без спекулятивних альткоїнів та стейблкоїнів). Аналізує 365 денних + 52 тижневі свічки, собівартість ринку (365D VWAP / MVRV), мультиплікатор Майєра (Ціна/SMA200) та об\'ємний рівень POC, щоб чітко показати: КОЛИ ЗАКУПАТИ частинами (Smart DCA) і КОЛИ ПРОДАВАТИ (TP1/TP2/TP3).',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 11.5, height: 1.35),
                ),
                const SizedBox(height: 14),
                if (isAnalyzing) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: state.fundamentalProgress > 0 ? state.fundamentalProgress : null,
                      backgroundColor: AppColors.surfaceVariant,
                      valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFF7931A)),
                      minHeight: 6,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Color(0xFFF7931A),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          state.fundamentalProgressStatus ?? 'Аналізуємо 365 днів історії базових L1...',
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
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        elevation: 0,
                      ),
                      icon: const Icon(Icons.layers_rounded, size: 20, color: Colors.black),
                      label: Text(
                        report == null
                            ? 'Запустити Аналіз Фундаментальних L1 (365D)'
                            : 'Оновити Інституційний Аналіз L1 (365D + 1W)',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: Colors.black),
                      ),
                      onPressed: () => notifier.runFundamentalAnalysis(),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),

          if (report != null && allCoins.isNotEmpty) ...[
            // Макро-панель циклу Bitcoin, ротації ETH/BTC & SOL/BTC та розподілу капіталу
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
                      const Icon(Icons.public_rounded, color: Color(0xFFF7931A), size: 18),
                      const SizedBox(width: 6),
                      const Expanded(
                        child: Text(
                          'МАКРО-ЦИКЛ РИНКУ ТА АЛОКАЦІЯ БАЗИ',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.7,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        DateFormat('dd.MM HH:mm').format(report.analyzedAt),
                        style: const TextStyle(color: AppColors.textDisabled, fontSize: 10),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.accent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.accent.withValues(alpha: 0.3)),
                    ),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        report.marketCycleLabel,
                        style: const TextStyle(
                          color: AppColors.accentLight,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),

                  // 4 ключові макро-індикатори циклу
                  Row(
                    children: [
                      _buildRadarSummaryStat(
                        label: 'BTC Mayer (SMA200)',
                        value: '${report.btcMayerMultiple.toStringAsFixed(2)}x',
                        valueColor: report.btcMayerMultiple < 1.0
                            ? AppColors.greenTask
                            : (report.btcMayerMultiple > 1.55 ? AppColors.warning : AppColors.textPrimary),
                      ),
                      const SizedBox(width: 6),
                      _buildRadarSummaryStat(
                        label: 'BTC MVRV (365D)',
                        value: '${report.btcMvrvProxy.toStringAsFixed(2)}x',
                        valueColor: report.btcMvrvProxy <= 1.0
                            ? AppColors.greenTask
                            : (report.btcMvrvProxy > 1.50 ? AppColors.warning : AppColors.blueTask),
                      ),
                      const SizedBox(width: 6),
                      _buildRadarSummaryStat(
                        label: 'Крос ETH/BTC',
                        value: report.ethBtcRatio.toStringAsFixed(4),
                        valueColor: AppColors.accentLight,
                      ),
                      const SizedBox(width: 6),
                      _buildRadarSummaryStat(
                        label: 'Ядро L1 / Кеш',
                        value: '${report.recommendedCoreAllocationPct}% / ${report.recommendedCashPct}%',
                        valueColor: AppColors.greenTask,
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Крос-пари ETH/BTC та SOL/BTC
                  Wrap(
                    spacing: 6,
                    runSpacing: 5,
                    children: [
                      _buildRadarFunnelChip('ETH/BTC: ${report.ethBtcStatus}'),
                      _buildRadarFunnelChip('SOL/BTC: ${report.solBtcStatus}'),
                    ],
                  ),
                  const SizedBox(height: 10),

                  Text(
                    report.macroStrategySummary,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 12.5,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Фільтри за фазою: Всі / Час купувати / Утримання / Фіксація
            Row(
              children: [
                _buildFundamentalFilterPill(
                  index: 0,
                  label: 'Всі (${allCoins.length})',
                  activeColor: AppColors.accentLight,
                ),
                const SizedBox(width: 5),
                _buildFundamentalFilterPill(
                  index: 1,
                  label: '🟢 Купувати (${buyCoins.length})',
                  activeColor: AppColors.greenTask,
                ),
                const SizedBox(width: 5),
                _buildFundamentalFilterPill(
                  index: 2,
                  label: '🟡 HODL (${holdCoins.length})',
                  activeColor: AppColors.blueTask,
                ),
                const SizedBox(width: 5),
                _buildFundamentalFilterPill(
                  index: 3,
                  label: '🟠 Продаж (${sellCoins.length})',
                  activeColor: AppColors.warning,
                ),
              ],
            ),
            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: Text(
                    'ФУНДАМЕНТАЛЬНІ АКТИВИ ПЕРШОГО ШАРУ (${filteredCoins.length})',
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
                  '4 знаки після коми',
                  style: TextStyle(color: AppColors.textDisabled, fontSize: 10.5),
                ),
              ],
            ),
            const SizedBox(height: 8),

            if (filteredCoins.isEmpty)
              _buildEmptyState(
                _fundamentalFilterIndex == 1
                    ? 'Зараз жодна з фундаментальних L1 монет не перебуває у зоні миттєвої ринкової недооцінки.\nПерегляньте вкладку «Всі» або «🟡 HODL» — для кожної монети розраховано 3 точні лімітні рівні закупки на відкаті.'
                    : (_fundamentalFilterIndex == 3
                        ? 'Наразі жодна з фундаментальних монет не перебуває у стадії критичного перегріву. Орієнтири фіксації прибутку (TP1, TP2, TP3) доступні в картці кожної монети.'
                        : 'У вибраній категорії немає монет.'),
              )
            else
              ...filteredCoins.map((coin) {
                final livePrice = state.livePrices[coin.symbol.toUpperCase()];
                final userDca = state.groupedDcaCoins
                    .where((d) => d.symbol.toUpperCase() == coin.symbol.toUpperCase())
                    .firstOrNull;
                final userHolding = state.overview.holdings
                    .where((h) => h.symbol.toUpperCase() == coin.symbol.toUpperCase())
                    .firstOrNull;

                return _FundamentalCoinCard(
                  coin: coin,
                  livePriceOverride: (livePrice != null && livePrice > 0) ? livePrice : null,
                  userDcaCoin: userDca,
                  userHolding: userHolding,
                  onAddToDca: () => _openAddDcaFromFundamental(coin, notifier),
                );
              }),
          ] else if (!isAnalyzing) ...[
            _buildEmptyState(
              'Натисніть кнопку вище, щоб завантажити 365-денну історію базових монет першого рівня (BTC, ETH, SOL, BNB, XRP, SUI, TON, AVAX, ADA, TRX) і розрахувати точні рівні закупки та продажу.',
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFundamentalFilterPill({
    required int index,
    required String label,
    required Color activeColor,
  }) {
    final isSelected = _fundamentalFilterIndex == index;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _fundamentalFilterIndex = index),
        borderRadius: BorderRadius.circular(9),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 4),
          decoration: BoxDecoration(
            color: isSelected ? activeColor.withValues(alpha: 0.16) : AppColors.surface,
            borderRadius: BorderRadius.circular(9),
            border: Border.all(
              color: isSelected ? activeColor : AppColors.border,
              width: isSelected ? 1.2 : 1.0,
            ),
          ),
          alignment: Alignment.center,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              style: TextStyle(
                color: isSelected ? activeColor : AppColors.textSecondary,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                fontSize: 10.5,
              ),
              maxLines: 1,
            ),
          ),
        ),
      ),
    );
  }

  void _openAddDcaFromFundamental(
    FundamentalCoinAnalysis coin,
    CryptoPortfolioNotifier notifier,
  ) {
    final entryRef = coin.isBuyRecommended ? coin.currentPrice : coin.buyZone1Price;
    showDialog(
      context: context,
      builder: (ctx) => DcaAddDialog(
        initialSymbol: coin.symbol,
        initialPrice: entryRef,
        initialNotes:
            'Фундамент L1 [${coin.actionTitleUk}]: '
            'Драбина закупки: Ордер 1 (${coin.buyZone1SharePct}%) \$${_formatDialogPrice(coin.buyZone1Price)}, '
            'Ордер 2 (${coin.buyZone2SharePct}%) \$${_formatDialogPrice(coin.buyZone2Price)}, '
            'Ордер 3 (${coin.buyZone3SharePct}%) \$${_formatDialogPrice(coin.buyZone3Price)}. '
            'Цілі продажу: TP1 (${coin.tp1SharePct}%) \$${_formatDialogPrice(coin.tp1Price)}, '
            'TP2 (${coin.tp2SharePct}%) \$${_formatDialogPrice(coin.tp2Price)}, '
            'TP3 (${coin.tp3SharePct}%) \$${_formatDialogPrice(coin.tp3Price)}.',
        onAdd: (tx) => notifier.addDcaTransaction(tx),
      ),
    );
  }
}

class _DcaCoinExpandableCard extends StatefulWidget {
  final DcaGroupedCoin coin;
  final CryptoPortfolioNotifier notifier;
  final HoldingItem? holdingItem;

  const _DcaCoinExpandableCard({
    required this.coin,
    required this.notifier,
    this.holdingItem,
  });

  @override
  State<_DcaCoinExpandableCard> createState() => _DcaCoinExpandableCardState();
}

class _DcaCoinExpandableCardState extends State<_DcaCoinExpandableCard> {
  bool _isExpanded = false;

  bool _isBinance(String walletType) {
    final w = walletType.toUpperCase();
    return w == 'BINANCE' || w == 'BINANCE SPOT' || w.contains('CONVERT');
  }

  bool _isWeb3(String walletType) {
    final w = walletType.toUpperCase();
    return w.startsWith('WEB3') ||
        w.contains('ON-CHAIN') ||
        w.contains('METAMASK') ||
        w.contains('EVM') ||
        w.contains('SOLANA') ||
        w == 'BTC';
  }

  bool _isManual(String walletType) {
    return !_isBinance(walletType) && !_isWeb3(walletType);
  }

  @override
  Widget build(BuildContext context) {
    final coin = widget.coin;
    final isPositive = coin.pnlPct >= 0;
    final pnlColor = isPositive ? AppColors.greenTask : AppColors.redTask;

    final hasBinance = coin.tranches.any((t) => _isBinance(t.walletType));
    final hasWeb3 = coin.tranches.any((t) => _isWeb3(t.walletType));
    final hasManual = coin.tranches.any((t) => _isManual(t.walletType));

    final String badgeLabel;
    final Color badgeColor;
    final Color badgeBg;

    if (hasWeb3 && !hasBinance && !hasManual) {
      badgeLabel = 'Web3 On-chain';
      badgeColor = AppColors.accentLight;
      badgeBg = AppColors.accent.withValues(alpha: 0.15);
    } else if (hasBinance && !hasWeb3 && !hasManual) {
      badgeLabel = 'Binance';
      badgeColor = const Color(0xFFF3BA2F);
      badgeBg = const Color(0xFFF3BA2F).withValues(alpha: 0.15);
    } else if (hasManual && !hasBinance && !hasWeb3) {
      badgeLabel = 'Ручна';
      badgeColor = AppColors.greenTask;
      badgeBg = AppColors.greenTask.withValues(alpha: 0.15);
    } else {
      final parts = <String>[];
      if (hasBinance) parts.add('Binance');
      if (hasWeb3) parts.add('Web3');
      if (hasManual) parts.add('Ручна');
      badgeLabel = parts.join(' + ');
      badgeColor = AppColors.accentLight;
      badgeBg = AppColors.accent.withValues(alpha: 0.15);
    }

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
                        child: Wrap(
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 6,
                          runSpacing: 4,
                          children: [
                            Text(
                              coin.symbol,
                              style: const TextStyle(
                                color: AppColors.textPrimary,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            // Бейдж джерела
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: badgeBg,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                badgeLabel,
                                style: TextStyle(
                                  color: badgeColor,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
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
                              const FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerLeft,
                                child: Row(
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
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  'Вкладено: \$${_formatMoney(coin.totalCost)}',
                                  style: const TextStyle(color: AppColors.textDisabled, fontSize: 9.5),
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Центральний роздільник зі стрілкою
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 6),
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
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerRight,
                                child: Row(
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
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerRight,
                                child: Text(
                                  'Вартість: \$${_formatMoney(coin.totalValueUsd)}',
                                  style: const TextStyle(color: AppColors.textDisabled, fontSize: 9.5),
                                ),
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
                      Expanded(
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
                      Flexible(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerRight,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: pnlColor.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: pnlColor.withValues(alpha: 0.3)),
                            ),
                            child: Text(
                              '${isPositive ? '+' : ''}${coin.pnlPct.toStringAsFixed(2)}% (${_formatPnlUsd(coin.pnlUsd)})',
                              style: TextStyle(
                                color: pnlColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (widget.holdingItem != null &&
                      widget.holdingItem!.tpSl.stopLoss > 0 &&
                      !const {'USDT', 'USDC', 'FDUSD', 'DAI', 'BUSD', 'TUSD'}
                          .contains(coin.symbol.toUpperCase())) ...[
                    const SizedBox(height: 10),
                    _buildFixationExitStrip(context, widget.holdingItem!),
                  ],
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
                      const Flexible(
                        child: Text(
                          'АКТИВНІ ПОКУПКИ (FIFO ЗАЛИШКИ)',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.6,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerRight,
                        child: Text(
                          'Зараз: \$${_formatPrice(coin.currentPrice)}',
                          style: const TextStyle(
                            color: AppColors.accentLight,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ...coin.tranches.asMap().entries.map((entry) => _buildTrancheRow(
                        entry.value,
                        entry.key + 1,
                        coin.tranches.length,
                        coin.symbol,
                      )),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTrancheRow(DcaTrancheItem t, int index, int totalTranches, String symbol) {
    final isPos = t.pnlPct >= 0;
    final color = isPos ? AppColors.greenTask : AppColors.redTask;
    final isBinance = _isBinance(t.walletType);
    final isWeb3 = _isWeb3(t.walletType);
    final isConvert = t.notes.contains('Convert');
    final isFallback = t.id.startsWith('binance_balance_');
    final isAutoWeb3 = t.id.startsWith('web3_auto_');

    final String trancheLabel;
    final Color trancheColor;
    final Color trancheBg;

    if (isBinance) {
      if (isConvert) {
        trancheLabel = 'Binance Convert';
        trancheColor = AppColors.accentLight;
        trancheBg = AppColors.accent.withValues(alpha: 0.15);
      } else if (isFallback) {
        trancheLabel = 'Binance Spot';
        trancheColor = const Color(0xFFF3BA2F);
        trancheBg = const Color(0xFFF3BA2F).withValues(alpha: 0.15);
      } else {
        trancheLabel = 'Binance Spot';
        trancheColor = const Color(0xFFF3BA2F);
        trancheBg = const Color(0xFFF3BA2F).withValues(alpha: 0.15);
      }
    } else if (isWeb3) {
      final wUpper = t.walletType.toUpperCase();
      if (wUpper.contains('BITCOIN') || t.symbol == 'BTC') {
        trancheLabel = 'Web3 · Bitcoin On-chain';
        trancheColor = const Color(0xFFF7931A);
        trancheBg = const Color(0xFFF7931A).withValues(alpha: 0.15);
      } else if (wUpper.contains('METAMASK') || wUpper.contains('EVM') || t.symbol == 'ETH') {
        trancheLabel = 'Web3 · MetaMask (EVM)';
        trancheColor = const Color(0xFF627EEA);
        trancheBg = const Color(0xFF627EEA).withValues(alpha: 0.15);
      } else if (wUpper.contains('SOLANA') || t.symbol == 'SOL') {
        trancheLabel = 'Web3 · Solana';
        trancheColor = const Color(0xFF14F195);
        trancheBg = const Color(0xFF14F195).withValues(alpha: 0.15);
      } else {
        trancheLabel = 'Web3 On-chain';
        trancheColor = AppColors.accentLight;
        trancheBg = AppColors.accent.withValues(alpha: 0.15);
      }
    } else {
      trancheLabel = 'Ручна DCA';
      trancheColor = AppColors.greenTask;
      trancheBg = AppColors.greenTask.withValues(alpha: 0.15);
    }

    final double trancheInvested = (t.amount * t.buyPrice) + t.fee;
    final double trancheCurrentVal = t.amount * t.currentPrice;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 5),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Рядок 1: Верхня шапка партії - Бейджі зліва, PnL та дія справа
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Flexible(
                child: Wrap(
                  spacing: 5,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: trancheBg,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        trancheLabel,
                        style: TextStyle(
                          color: trancheColor,
                          fontSize: 9.5,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceVariant,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        totalTranches > 1 ? 'Партія #$index з $totalTranches' : 'Партія #$index',
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 9.5,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: Text(
                        '${isPos ? '+' : ''}${t.pnlPct.toStringAsFixed(2)}% (${_formatPnlUsd(t.pnlUsd)})',
                        style: TextStyle(
                          color: color,
                          fontSize: 10.5,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  if (!isBinance && !isAutoWeb3) ...[
                    const SizedBox(width: 4),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: AppColors.textDisabled, size: 16),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () => widget.notifier.deleteDcaTransaction(t.id),
                      tooltip: 'Видалити покупку',
                    ),
                  ],
                ],
              ),
            ],
          ),
          const SizedBox(height: 5),

          // Дата покупки (окремим акуратним рядком, щоб ніколи не вилазити за межі)
          Row(
            children: [
              const Icon(Icons.access_time_rounded, size: 11, color: AppColors.textDisabled),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  _formatDate(t.date),
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 10),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 9),

          // Рядок 2: ЖОВТИМ ОБВЕДЕНА ЦІНА ЗАКУПКИ ТА КІЛЬКІСТЬ ЦІЄЇ ПАРТІЇ
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(
              color: const Color(0xFFF3BA2F).withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: const Color(0xFFF3BA2F), // Чітка жовта рамка для ціни закупки!
                width: 1.5,
              ),
            ),
            child: Row(
              children: [
                // Ліва колонка: Ціна закупки цієї партії
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Row(
                          children: [
                            Icon(Icons.sell_outlined, size: 12, color: Color(0xFFF3BA2F)),
                            SizedBox(width: 4),
                            Text(
                              'ЦІНА ЗАКУПКИ ПАРТІЇ',
                              style: TextStyle(
                                color: Color(0xFFF3BA2F),
                                fontSize: 9.5,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 3),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          '\$${_formatPrice(t.buyPrice)}',
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.bold,
                            fontSize: 16.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Вертикальний золотий роздільник
                Container(
                  height: 32,
                  width: 1,
                  color: const Color(0xFFF3BA2F).withValues(alpha: 0.35),
                  margin: const EdgeInsets.symmetric(horizontal: 10),
                ),

                // Права колонка: Кількість монет у цій партії
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerRight,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Icon(Icons.inventory_2_outlined, size: 12, color: AppColors.textSecondary),
                            SizedBox(width: 4),
                            Text(
                              'ЗАКУПЛЕНО ЗА РАЗ',
                              style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 9.5,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 3),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerRight,
                        child: Text(
                          '${_formatAmount(t.amount)} $symbol',
                          style: const TextStyle(
                            color: AppColors.accentLight,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
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

          // Рядок 3: Підсумки партії (Вкладено грошей -> Поточна ринкова вартість)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Вкладено: \$${_formatMoney(trancheInvested)}${t.fee > 0 ? ' (комісія: \$${_formatMoney(t.fee)})' : ''}',
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 10.5),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerRight,
                  child: Text(
                    'Вартість зараз: \$${_formatMoney(trancheCurrentVal)}',
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (t.notes.isNotEmpty && !t.notes.startsWith('Синхронізовано') && !t.notes.startsWith('Автоматичний')) ...[
            const SizedBox(height: 4),
            Text(
              t.notes,
              style: const TextStyle(color: AppColors.textDisabled, fontSize: 9.5, fontStyle: FontStyle.italic),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFixationExitStrip(BuildContext context, HoldingItem h) {
    final t = h.tpSl;
    Color accent;
    IconData icon;

    switch (t.exitSignalCode) {
      case 'SELL_PEAK_NOW':
        accent = const Color(0xFFF3BA2F);
        icon = Icons.local_fire_department_rounded;
        break;
      case 'TRAILING_STOP_HIT':
        accent = AppColors.warning;
        icon = Icons.lock_clock_rounded;
        break;
      case 'TAKE_PARTIAL_TP1':
        accent = AppColors.greenTask;
        icon = Icons.verified_rounded;
        break;
      case 'PRE_STOP_DANGER':
        accent = AppColors.redTask;
        icon = Icons.warning_amber_rounded;
        break;
      default:
        accent = t.slProbabilityPct >= 50
            ? AppColors.warning
            : AppColors.accentLight;
        icon = Icons.shield_outlined;
    }

    final sellAmountCoins =
        widget.coin.totalAmount * (t.recommendedSellPct / 100.0);
    final sellValueUsd =
        widget.coin.totalValueUsd * (t.recommendedSellPct / 100.0);

    return InkWell(
      onTap: () {
        showDialog(
          context: context,
          builder: (_) => TpSlDialog(holding: h),
        );
      },
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: accent.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: accent.withValues(alpha: 0.45)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 15, color: accent),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    t.exitTitleUk,
                    style: TextStyle(
                      color: accent,
                      fontWeight: FontWeight.bold,
                      fontSize: 11.5,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceVariant,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'План виходу',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 9.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(width: 2),
                      Icon(
                        Icons.open_in_new_rounded,
                        size: 10,
                        color: AppColors.textSecondary,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (t.recommendedSellPct > 0 && widget.coin.totalAmount > 0) ...[
              const SizedBox(height: 4),
              Text(
                'Рекомендовано продати зараз: ${t.recommendedSellPct}% (${_formatAmount(sellAmountCoins)} ${widget.coin.symbol} ≈ \$${_formatMoney(sellValueUsd)})',
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                _buildMiniExitPill(
                  label: 'TP1 (${t.tp1Pct >= 0 ? '+' : ''}${t.tp1Pct.toStringAsFixed(1)}%)',
                  value: '\$${_formatPrice(t.tp1)}',
                  color: AppColors.greenTask,
                ),
                if (t.trailingStopPrice > 0)
                  _buildMiniExitPill(
                    label: 'Трейлінг',
                    value: '\$${_formatPrice(t.trailingStopPrice)}',
                    color: AppColors.accentLight,
                  ),
                if (t.earlyExitPrice > 0)
                  _buildMiniExitPill(
                    label: 'Пре-Стоп',
                    value: '\$${_formatPrice(t.earlyExitPrice)}',
                    color: AppColors.warning,
                  ),
                _buildMiniExitPill(
                  label: 'Ризик SL',
                  value: '${t.slProbabilityPct.toStringAsFixed(0)}%',
                  color: t.slProbabilityPct >= 60
                      ? AppColors.redTask
                      : t.slProbabilityPct >= 35
                          ? AppColors.warning
                          : AppColors.greenTask,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMiniExitPill({
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(fontSize: 9.5),
          children: [
            TextSpan(
              text: '$label: ',
              style: const TextStyle(color: AppColors.textSecondary),
            ),
            TextSpan(
              text: value,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatAmount(double amt) {
    if (amt >= 100) return amt.toStringAsFixed(2);
    if (amt >= 1) return amt.toStringAsFixed(4);
    return amt.toStringAsFixed(6).replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '');
  }

  String _formatPnlUsd(double pnl) {
    if (pnl == 0.0) return '\$0.00';
    final sign = pnl >= 0 ? '+' : '-';
    final abs = pnl.abs();
    if (abs >= 1000) {
      return '$sign\$${NumberFormat('#,##0.00', 'en_US').format(abs)}';
    } else if (abs >= 0.01) {
      return '$sign\$${abs.toStringAsFixed(2)}';
    } else {
      return '$sign\$${abs.toStringAsFixed(4)}';
    }
  }

  String _formatMoney(double val) {
    if (val == 0) return '0.00';
    final abs = val.abs();
    final sign = val < 0 ? '-' : '';
    if (abs >= 1000) {
      return '$sign${NumberFormat('#,##0.00', 'en_US').format(abs)}';
    } else if (abs >= 0.01) {
      return '$sign${abs.toStringAsFixed(2)}';
    } else {
      return '$sign${abs.toStringAsFixed(4)}';
    }
  }

  String _formatPrice(double val) {
    if (val == 0) return '0.0000';
    final abs = val.abs();
    final sign = val < 0 ? '-' : '';
    if (abs >= 1000) {
      return '$sign${NumberFormat('#,##0.0000', 'en_US').format(abs)}';
    } else if (abs >= 0.0001) {
      return '$sign${abs.toStringAsFixed(4)}';
    } else {
      return '$sign${abs.toStringAsFixed(6)}';
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

    final tp1Pct = opp.tp1Pct > 0
        ? opp.tp1Pct
        : (opp.currentPrice > 0 ? ((opp.targetPrice1 - opp.currentPrice) / opp.currentPrice) * 100.0 : 20.0);
    final tp2Pct = opp.tp2Pct > 0
        ? opp.tp2Pct
        : (opp.currentPrice > 0 ? ((opp.targetPrice2 - opp.currentPrice) / opp.currentPrice) * 100.0 : 40.0);
    final slPct = opp.slPct > 0
        ? opp.slPct
        : (opp.currentPrice > 0 ? ((opp.currentPrice - opp.stopLoss) / opp.currentPrice) * 100.0 : 10.0);

    // Колір та текст статусу точки входу
    final (Color statusColor, IconData statusIcon, String statusLabel) = switch (opp.entryStatus) {
      RadarEntryStatus.waitBreakout => (
          AppColors.blueTask,
          Icons.trending_up_rounded,
          'STOP-LIMIT НА ПРОБІЙ \$${_formatPrice(opp.triggerPrice)}',
        ),
      RadarEntryStatus.waitPullback => (
          AppColors.warning,
          Icons.hourglass_bottom_rounded,
          'ЧЕКАТИ ВІДКАТ · ЛІМІТКА \$${_formatPrice(opp.triggerPrice)}',
        ),
      _ => (
          AppColors.greenTask,
          Icons.check_circle_outline_rounded,
          'КУПУВАТИ ЗАРАЗ · У ЗОНІ ВХОДУ',
        ),
    };

    final hasFactorScores = (opp.scoreMomentum +
            opp.scoreTrend +
            opp.scoreFlow +
            opp.scoreContraction +
            opp.scoreEntry +
            opp.scoreRiskReward) >
        0;

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
          // Шапка картки: назва монети, сетап, статус входу, поточна ціна, індекс Quant Score
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
                                    (opp.name.isNotEmpty && opp.name.toUpperCase() != opp.symbol.toUpperCase())
                                        ? '${opp.symbol} · ${opp.name}'
                                        : opp.symbol,
                                    style: const TextStyle(
                                      color: AppColors.textPrimary,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15.5,
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
                                    style: const TextStyle(
                                      color: AppColors.textSecondary,
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 3),
                            // Бейдж архетипу сетапу
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
                              'Quant: ${opp.confidenceScore}/100',
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
                  const SizedBox(height: 9),

                  // Смуга дії: Статус входу (КУПУВАТИ ЗАРАЗ / ЛІМІТКА / ПРОБІЙ) + Рекомендований розмір позиції
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.11),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: statusColor.withValues(alpha: 0.35)),
                    ),
                    child: Row(
                      children: [
                        Icon(statusIcon, size: 14, color: statusColor),
                        const SizedBox(width: 5),
                        Expanded(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(
                              statusLabel,
                              style: TextStyle(
                                color: statusColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                              ),
                            ),
                          ),
                        ),
                        if (opp.positionSizePct > 0) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(5),
                            ),
                            child: Text(
                              opp.positionSizeUsd > 0
                                  ? 'Алокація: ${opp.positionSizePct.toStringAsFixed(1)}% (~\$${opp.positionSizeUsd.toStringAsFixed(0)})'
                                  : 'Алокація: ${opp.positionSizePct.toStringAsFixed(1)}% депо',
                              style: const TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 9.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 9),

                  // 4-колонковий рядок квантових метрик v3: RS vs BTC, Order Flow Δ, Hit-Rate TP1, Зважений R:R
                  Row(
                    children: [
                      _buildMetricTile(
                        label: 'RS vs BTC (30D)',
                        value: '${opp.rsVsBtc30d >= 0 ? '+' : ''}${opp.rsVsBtc30d.toStringAsFixed(1)}%',
                        valueColor: opp.rsVsBtc30d >= 0 ? AppColors.greenTask : AppColors.redTask,
                      ),
                      const SizedBox(width: 4),
                      _buildMetricTile(
                        label: 'Order Flow Δ',
                        value: '${opp.takerDeltaPp >= 0 ? '+' : ''}${opp.takerDeltaPp.toStringAsFixed(1)} п.п.',
                        valueColor: opp.takerDeltaPp >= 0.5
                            ? AppColors.greenTask
                            : (opp.takerDeltaPp < -0.5 ? AppColors.redTask : AppColors.textPrimary),
                      ),
                      const SizedBox(width: 4),
                      _buildMetricTile(
                        label: 'Істор. Hit TP1',
                        value: opp.tp1HitRatePct >= 0
                            ? '${opp.tp1HitRatePct.toStringAsFixed(0)}% (${opp.historicalSamples})'
                            : 'RSI ${opp.rsi.toStringAsFixed(0)}',
                        valueColor: opp.tp1HitRatePct >= 52
                            ? AppColors.greenTask
                            : (opp.tp1HitRatePct >= 0 && opp.tp1HitRatePct < 40
                                ? AppColors.warning
                                : AppColors.textPrimary),
                      ),
                      const SizedBox(width: 4),
                      _buildMetricTile(
                        label: 'R:R · Очік. EV',
                        value: opp.blendedRR > 0
                            ? '1:${opp.blendedRR.toStringAsFixed(1)} (${opp.expectancyPct >= 0 ? '+' : ''}${opp.expectancyPct.toStringAsFixed(1)}%)'
                            : '1:${opp.riskRewardRatio.toStringAsFixed(1)}',
                        valueColor: AppColors.accentLight,
                      ),
                    ],
                  ),

                  // 6-факторна шкала декомпозиції Quant Score
                  if (hasFactorScores) ...[
                    const SizedBox(height: 7),
                    Row(
                      children: [
                        _buildFactorChip('Імп', opp.scoreMomentum),
                        const SizedBox(width: 3),
                        _buildFactorChip('Тренд', opp.scoreTrend),
                        const SizedBox(width: 3),
                        _buildFactorChip('Flow', opp.scoreFlow),
                        const SizedBox(width: 3),
                        _buildFactorChip('Стисн', opp.scoreContraction),
                        const SizedBox(width: 3),
                        _buildFactorChip('Вхід', opp.scoreEntry),
                        const SizedBox(width: 3),
                        _buildFactorChip('R:R', opp.scoreRiskReward),
                      ],
                    ),
                  ],
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
                // 1. Рядок: Зона входу DCA та Захисний Стоп-Лос + Тайм-стоп
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
                            const Text('Вхід: ', style: TextStyle(color: AppColors.textDisabled, fontSize: 10)),
                            Expanded(
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  '\$${_formatPrice(opp.entryZoneMin)} – \$${_formatPrice(opp.entryZoneMax)}',
                                  style: const TextStyle(
                                    color: AppColors.textPrimary,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
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
                            const Text(
                              'SL: ',
                              style: TextStyle(color: AppColors.redTask, fontSize: 10, fontWeight: FontWeight.bold),
                            ),
                            Expanded(
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  '\$${_formatPrice(opp.stopLoss)} (-${slPct.toStringAsFixed(1)}%) · ${opp.timeStopDays}д',
                                  style: const TextStyle(
                                    color: AppColors.redTask,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
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
                      const Text(
                        'Цілі: ',
                        style: TextStyle(color: AppColors.greenTask, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                      Expanded(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'TP1 \$${_formatPrice(opp.targetPrice1)} (+${tp1Pct.toStringAsFixed(1)}%)   ·   TP2 \$${_formatPrice(opp.targetPrice2)} (+${tp2Pct.toStringAsFixed(1)}%)',
                            style: const TextStyle(
                              color: AppColors.greenTask,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
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
                                  _isExpanded
                                      ? 'Згорнути торговий план'
                                      : 'Детальний план, Бектест & Ризики${opp.warnings.isNotEmpty ? ' (${opp.warnings.length} ⚠️)' : ''}',
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

          // Розгорнута секція: AI-Коментар, Попередження, Повний торговий план + Умови TP/SL
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
                  // AI-коментар (якщо присутній)
                  if (opp.aiCommentary.isNotEmpty) ...[
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.accent.withValues(alpha: 0.09),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.accent.withValues(alpha: 0.3)),
                      ),
                      child: _buildAnalysisBlock(
                        icon: Icons.psychology_rounded,
                        iconColor: AppColors.accentLight,
                        title: 'РЕЗЮМЕ КВАНТОВОГО AI-АНАЛІТИКА',
                        content: opp.aiCommentary,
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],

                  // Чесні попередження про ризики (якщо є)
                  if (opp.warnings.isNotEmpty) ...[
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.warning.withValues(alpha: 0.09),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.warning.withValues(alpha: 0.35)),
                      ),
                      child: _buildAnalysisBlock(
                        icon: Icons.warning_amber_rounded,
                        iconColor: AppColors.warning,
                        title: 'ОБ\'ЄКТИВНІ ФАКТОРИ РИЗИКУ (${opp.warnings.length})',
                        content: opp.warnings.map((w) => '• $w').join('\n'),
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],

                  // 1. Технічний аналіз (230D)
                  _buildAnalysisBlock(
                    icon: Icons.trending_up_rounded,
                    iconColor: AppColors.blueTask,
                    title: '1. ТЕХНІЧНА СТРУКТУРА ТА ВОЛАТИЛЬНІСТЬ (230D)',
                    content: opp.technicalReason,
                  ),
                  const SizedBox(height: 10),

                  // 2. Відносна сила та Order Flow
                  _buildAnalysisBlock(
                    icon: Icons.bolt_rounded,
                    iconColor: AppColors.warning,
                    title: '2. ВІДНОСНА СИЛА (RS VS BTC) & ORDER FLOW',
                    content: opp.smartMoneyCatalyst,
                  ),
                  const SizedBox(height: 10),

                  // 3. DCA Архітектура входу та розмір позиції
                  _buildAnalysisBlock(
                    icon: Icons.pie_chart_outline_rounded,
                    iconColor: AppColors.accentLight,
                    title: '3. ТОЧКА ВХОДУ ТА РОЗМІР ПОЗИЦІЇ',
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
                      title: '4. КОЛИ РОБИТИ ТЕЙК-ПРОФІТ (TP1 / TP2 / ТРЕЙЛІНГ)',
                      content: opp.tpTriggerRule.isNotEmpty
                          ? opp.tpTriggerRule
                          : 'На TP1 (\$${_formatPrice(opp.targetPrice1)}, +${tp1Pct.toStringAsFixed(1)}%) зафіксувати 50% позиції та перевести Stop-Loss у беззбиток. На TP2 (\$${_formatPrice(opp.targetPrice2)}, +${tp2Pct.toStringAsFixed(1)}%) закрити 30%, залишок 20% вести по денній EMA 20.',
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
                      title: '5. ПРОТОКОЛ СТОП-ЛОСУ (СТРУКТУРНИЙ + АВАРІЙНИЙ + ТАЙМ-СТОП)',
                      content: opp.slTriggerRule.isNotEmpty
                          ? opp.slTriggerRule
                          : 'Стоп-рівень \$${_formatPrice(opp.stopLoss)} (-${slPct.toStringAsFixed(1)}%). Вихід при закритті денної свічки нижче рівня. Аварійний стоп у стакані: \$${_formatPrice(opp.hardStopPrice > 0 ? opp.hardStopPrice : opp.stopLoss * 0.95)}. Тайм-стоп: ${opp.timeStopDays} днів.',
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

  Widget _buildFactorChip(String label, double score) {
    final s = score.round().clamp(0, 100);
    final c = s >= 68
        ? AppColors.greenTask
        : (s >= 45 ? AppColors.blueTask : AppColors.textSecondary);
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 3),
        decoration: BoxDecoration(
          color: c.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(5),
          border: Border.all(color: c.withValues(alpha: 0.25)),
        ),
        alignment: Alignment.center,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            '$label $s',
            style: TextStyle(
              color: c,
              fontSize: 8.5,
              fontWeight: FontWeight.bold,
            ),
            maxLines: 1,
          ),
        ),
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
    if (val == 0) return '0.0000';
    final abs = val.abs();
    final sign = val < 0 ? '-' : '';
    if (abs >= 1000) {
      return '$sign${NumberFormat('#,##0.0000', 'en_US').format(abs)}';
    } else if (abs >= 0.0001) {
      return '$sign${abs.toStringAsFixed(4)}';
    } else {
      return '$sign${abs.toStringAsFixed(6)}';
    }
  }
}

class _FundamentalCoinCard extends StatefulWidget {
  final FundamentalCoinAnalysis coin;
  final double? livePriceOverride;
  final DcaGroupedCoin? userDcaCoin;
  final HoldingItem? userHolding;
  final VoidCallback onAddToDca;

  const _FundamentalCoinCard({
    required this.coin,
    this.livePriceOverride,
    this.userDcaCoin,
    this.userHolding,
    required this.onAddToDca,
  });

  @override
  State<_FundamentalCoinCard> createState() => _FundamentalCoinCardState();
}

class _FundamentalCoinCardState extends State<_FundamentalCoinCard> {
  bool _isExpanded = false;

  Color _brandColor(String sym) {
    return switch (sym.toUpperCase()) {
      'BTC' => const Color(0xFFF7931A),
      'ETH' => const Color(0xFF627EEA),
      'SOL' => const Color(0xFF14F195),
      'BNB' => const Color(0xFFF3BA2F),
      'XRP' => const Color(0xFF38BDF8),
      'SUI' => const Color(0xFF4DA2FF),
      'TON' => const Color(0xFF0098EA),
      'AVAX' => const Color(0xFFE84142),
      'ADA' => const Color(0xFF3CC8C8),
      _ => AppColors.accentLight,
    };
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.coin;
    final price = widget.livePriceOverride ?? c.currentPrice;
    final brand = _brandColor(c.symbol);

    final (Color phaseColor, IconData phaseIcon) = switch (c.cyclePhase) {
      FundamentalCyclePhase.deepValue => (AppColors.greenTask, Icons.diamond_outlined),
      FundamentalCyclePhase.dcaAccumulation => (AppColors.blueTask, Icons.shopping_cart_checkout_rounded),
      FundamentalCyclePhase.overheatedTakeProfit => (AppColors.warning, Icons.local_fire_department_rounded),
      FundamentalCyclePhase.euphoriaSell => (AppColors.redTask, Icons.warning_amber_rounded),
      _ => (AppColors.accentLight, Icons.shield_outlined),
    };

    // Розрахунок відсотків до рівнів купівлі та продажу відносно актуальної ціни
    final buy1DiffPct = price > 0 ? ((c.buyZone1Price - price) / price) * 100.0 : 0.0;
    final buy2DiffPct = price > 0 ? ((c.buyZone2Price - price) / price) * 100.0 : 0.0;
    final buy3DiffPct = price > 0 ? ((c.buyZone3Price - price) / price) * 100.0 : 0.0;

    final tp1GainPct = price > 0 ? ((c.tp1Price - price) / price) * 100.0 : 0.0;
    final tp2GainPct = price > 0 ? ((c.tp2Price - price) / price) * 100.0 : 0.0;
    final tp3GainPct = price > 0 ? ((c.tp3Price - price) / price) * 100.0 : 0.0;

    // Дані про особисту позицію користувача (якщо монета вже є в портфелі або DCA)
    final double userAmount = widget.userDcaCoin?.totalAmount ?? widget.userHolding?.amount ?? 0.0;
    final double userEntry = widget.userDcaCoin?.avgEntryPrice ?? widget.userHolding?.avgEntryPrice ?? 0.0;
    final bool hasUserPos = userAmount > 0.000001 && userEntry > 0;
    final double userPnlPct = hasUserPos ? ((price - userEntry) / userEntry) * 100.0 : 0.0;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _isExpanded ? brand.withValues(alpha: 0.6) : AppColors.border,
        ),
      ),
      child: Column(
        children: [
          // 1. Шапка картки: Логотип, Символ, Роль, Поточна ціна та Індекси Закупки / Перегріву
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
                        radius: 20,
                        backgroundColor: brand.withValues(alpha: 0.16),
                        child: Text(
                          c.symbol.length > 3 ? c.symbol.substring(0, 3) : c.symbol,
                          style: TextStyle(
                            color: brand,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
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
                                    '${c.symbol} · ${c.name}',
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
                                    color: brand.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    'CORE L1',
                                    style: TextStyle(
                                      color: brand,
                                      fontSize: 8.5,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              c.roleLabel,
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 10.5,
                              ),
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
                              '\$${_formatPrice(price)}',
                              style: const TextStyle(
                                color: AppColors.textPrimary,
                                fontWeight: FontWeight.bold,
                                fontSize: 15.5,
                              ),
                            ),
                          ),
                          const SizedBox(height: 3),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                decoration: BoxDecoration(
                                  color: (c.chg24h >= 0 ? AppColors.greenTask : AppColors.redTask)
                                      .withValues(alpha: 0.14),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  '24h: ${c.chg24h >= 0 ? '+' : ''}${c.chg24h.toStringAsFixed(1)}%',
                                  style: TextStyle(
                                    color: c.chg24h >= 0 ? AppColors.greenTask : AppColors.redTask,
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                decoration: BoxDecoration(
                                  color: AppColors.surfaceVariant,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  '1Y: ${c.chg365d >= 0 ? '+' : ''}${c.chg365d.toStringAsFixed(0)}%',
                                  style: TextStyle(
                                    color: c.chg365d >= 0 ? AppColors.greenTask : AppColors.textSecondary,
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // 2. Вердикт алгоритму: Фаза циклу + Індекс Закупки vs Перегріву
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: phaseColor.withValues(alpha: 0.11),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: phaseColor.withValues(alpha: 0.35)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(phaseIcon, size: 15, color: phaseColor),
                            const SizedBox(width: 6),
                            Expanded(
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  c.actionTitleUk,
                                  style: TextStyle(
                                    color: phaseColor,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.greenTask.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(5),
                              ),
                              child: Text(
                                'Закупка: ${c.accumulationScore}/100',
                                style: const TextStyle(
                                  color: AppColors.greenTask,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 9.5,
                                ),
                              ),
                            ),
                            const SizedBox(width: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.warning.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(5),
                              ),
                              child: Text(
                                'Перегрів: ${c.sellPressureScore}/100',
                                style: const TextStyle(
                                  color: AppColors.warning,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 9.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          c.recommendedActionShort,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),

                  // Якщо монета вже є в портфелі користувача — показуємо його точку входу та пораду
                  if (hasUserPos) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceVariant.withValues(alpha: 0.55),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.account_balance_wallet_outlined, size: 13, color: AppColors.accentLight),
                          const SizedBox(width: 6),
                          Expanded(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Text(
                                'У вашому портфелі: ${_formatAmount(userAmount)} ${c.symbol} · Вхід: \$${_formatPrice(userEntry)}',
                                style: const TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '${userPnlPct >= 0 ? '+' : ''}${userPnlPct.toStringAsFixed(2)}%',
                            style: TextStyle(
                              color: userPnlPct >= 0 ? AppColors.greenTask : AppColors.redTask,
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 10),

                  // 3. Візуальна шкала положення в 365-денному коридорі (Дно 365D -> Пік 365D)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Flexible(
                            child: Text(
                              'Дно 365D: \$${_formatPrice(c.atl365)}',
                              style: const TextStyle(color: AppColors.textDisabled, fontSize: 9.5),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 6),
                            child: Text(
                              'Дисконт від ATH: -${c.dropFromAthPct.toStringAsFixed(1)}%',
                              style: const TextStyle(
                                color: AppColors.accentLight,
                                fontSize: 9.5,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          Flexible(
                            child: Text(
                              'Пік 365D: \$${_formatPrice(c.ath365)}',
                              style: const TextStyle(color: AppColors.textDisabled, fontSize: 9.5),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.right,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(5),
                        child: LinearProgressIndicator(
                          value: (c.rangePositionPct / 100.0).clamp(0.03, 1.0),
                          backgroundColor: AppColors.surfaceVariant,
                          valueColor: AlwaysStoppedAnimation<Color>(phaseColor),
                          minHeight: 6,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // 4. Чотири інституційні метрики оцінки вартості
                  Row(
                    children: [
                      _buildQuantTile(
                        label: 'Mayer (SMA200)',
                        value: '${c.mayerMultiple.toStringAsFixed(2)}x',
                        sub: '\$${_formatPrice(c.sma200)}',
                        valueColor: c.mayerMultiple < 0.95
                            ? AppColors.greenTask
                            : (c.mayerMultiple > 1.50 ? AppColors.warning : AppColors.textPrimary),
                      ),
                      const SizedBox(width: 4),
                      _buildQuantTile(
                        label: 'MVRV (365D VWAP)',
                        value: '${c.mvrvProxy.toStringAsFixed(2)}x',
                        sub: '\$${_formatPrice(c.vwap365)}',
                        valueColor: c.mvrvProxy <= 1.0
                            ? AppColors.greenTask
                            : (c.mvrvProxy > 1.45 ? AppColors.warning : AppColors.blueTask),
                      ),
                      const SizedBox(width: 4),
                      _buildQuantTile(
                        label: 'RSI (1D / 1W)',
                        value: '${c.rsi14d.toStringAsFixed(0)} / ${c.rsi14w.toStringAsFixed(0)}',
                        sub: c.rsi14w <= 45
                            ? 'Перепроданий'
                            : (c.rsi14w >= 70 ? 'Перегрітий' : 'Нейтральний'),
                        valueColor: c.rsi14d <= 42
                            ? AppColors.greenTask
                            : (c.rsi14d >= 68 ? AppColors.warning : AppColors.textPrimary),
                      ),
                      const SizedBox(width: 4),
                      _buildQuantTile(
                        label: 'POC Об\'єму 365D',
                        value: '\$${_formatPrice(c.poc365)}',
                        sub: 'Flow: ${c.takerDeltaPp >= 0 ? '+' : ''}${c.takerDeltaPp.toStringAsFixed(1)} п.п.',
                        valueColor: AppColors.accentLight,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const Divider(height: 1, color: AppColors.border),

          // 5. ГОЛОВНИЙ БЛОК ТРЕЙДЕРА: КОЛИ КУПУВАТИ (3 РІВНІ DCA) vs КОЛИ ПРОДАВАТИ (TP1/TP2/TP3)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // БЛОК ЗАКУПКИ (ЗЕЛЕНИЙ)
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.greenTask.withValues(alpha: 0.07),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.greenTask.withValues(alpha: 0.28)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.download_rounded, size: 14, color: AppColors.greenTask),
                          SizedBox(width: 5),
                          Expanded(
                            child: Text(
                              'КОЛИ ЗАКУПАТИ (ДРАБИНА НАКОПИЧЕННЯ SMART DCA)',
                              style: TextStyle(
                                color: AppColors.greenTask,
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
                      const SizedBox(height: 6),
                      _buildLadderRow(
                        badge: '${c.buyZone1SharePct}%',
                        badgeColor: AppColors.greenTask,
                        label: c.buyZone1Label,
                        priceStr: '\$${_formatPrice(c.buyZone1Price)}',
                        diffStr: buy1DiffPct.abs() < 0.8
                            ? 'Зараз'
                            : '${buy1DiffPct >= 0 ? '+' : ''}${buy1DiffPct.toStringAsFixed(1)}%',
                      ),
                      const SizedBox(height: 4),
                      _buildLadderRow(
                        badge: '${c.buyZone2SharePct}%',
                        badgeColor: AppColors.greenTask,
                        label: c.buyZone2Label,
                        priceStr: '\$${_formatPrice(c.buyZone2Price)}',
                        diffStr: '${buy2DiffPct >= 0 ? '+' : ''}${buy2DiffPct.toStringAsFixed(1)}%',
                      ),
                      const SizedBox(height: 4),
                      _buildLadderRow(
                        badge: '${c.buyZone3SharePct}%',
                        badgeColor: AppColors.greenTask,
                        label: c.buyZone3Label,
                        priceStr: '\$${_formatPrice(c.buyZone3Price)}',
                        diffStr: '${buy3DiffPct >= 0 ? '+' : ''}${buy3DiffPct.toStringAsFixed(1)}%',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),

                // БЛОК ПРОДАЖУ / ФІКСАЦІЇ ПРИБУТКУ (ПОМАРАНЧЕВО-ЗОЛОТИЙ)
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withValues(alpha: 0.07),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.warning.withValues(alpha: 0.28)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.upload_rounded, size: 14, color: AppColors.warning),
                          SizedBox(width: 5),
                          Expanded(
                            child: Text(
                              'КОЛИ ПРОДАВАТИ (КАСКАД ФІКСАЦІЇ ПРИБУТКУ TP1–TP3)',
                              style: TextStyle(
                                color: AppColors.warning,
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
                      const SizedBox(height: 6),
                      _buildLadderRow(
                        badge: '${c.tp1SharePct}%',
                        badgeColor: AppColors.warning,
                        label: c.tp1Label,
                        priceStr: '\$${_formatPrice(c.tp1Price)}',
                        diffStr: '+${tp1GainPct.toStringAsFixed(1)}%',
                      ),
                      const SizedBox(height: 4),
                      _buildLadderRow(
                        badge: '${c.tp2SharePct}%',
                        badgeColor: AppColors.warning,
                        label: c.tp2Label,
                        priceStr: '\$${_formatPrice(c.tp2Price)}',
                        diffStr: '+${tp2GainPct.toStringAsFixed(1)}%',
                      ),
                      const SizedBox(height: 4),
                      _buildLadderRow(
                        badge: '${c.tp3SharePct}%',
                        badgeColor: AppColors.warning,
                        label: c.tp3Label,
                        priceStr: '\$${_formatPrice(c.tp3Price)}',
                        diffStr: '+${tp3GainPct.toStringAsFixed(1)}%',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),

                // Кнопки дій: Детальний розбір + Додати в DCA
                Row(
                  children: [
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
                                _isExpanded
                                    ? Icons.keyboard_arrow_up_rounded
                                    : Icons.keyboard_arrow_down_rounded,
                                color: AppColors.accentLight,
                                size: 18,
                              ),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  _isExpanded
                                      ? 'Згорнути аналітику трейдера'
                                      : 'Повний розбір: Собівартість, Правила купівлі/продажу & AI',
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

          // 6. Розгорнута секція з детальним інституційним обґрунтуванням
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
                  if (c.aiCommentary.isNotEmpty) ...[
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.accent.withValues(alpha: 0.09),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.accent.withValues(alpha: 0.3)),
                      ),
                      child: _buildBlock(
                        icon: Icons.psychology_rounded,
                        iconColor: AppColors.accentLight,
                        title: 'ВЕРДИКТ ІНСТИТУЦІЙНОГО СТРАТЕГА AI',
                        content: c.aiCommentary,
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                  _buildBlock(
                    icon: Icons.analytics_outlined,
                    iconColor: AppColors.blueTask,
                    title: '1. ОЦІНКА СПРАВЕДЛИВОЇ ВАРТОСТІ ТА СОБІВАРТОСТІ (365D)',
                    content: c.valuationSummary,
                  ),
                  const SizedBox(height: 10),
                  _buildBlock(
                    icon: Icons.shopping_bag_outlined,
                    iconColor: AppColors.greenTask,
                    title: '2. ЛОГІКА ЗАКУПКИ (КОЛИ ТА ЯК НАБИРАТИ ПОЗИЦІЮ)',
                    content: c.buyTriggerRule,
                  ),
                  const SizedBox(height: 10),
                  _buildBlock(
                    icon: Icons.monetization_on_outlined,
                    iconColor: AppColors.warning,
                    title: '3. ЛОГІКА ПРОДАЖУ (КОЛИ ФІКСУВАТИ ПРИБУТОК ПО ЦИКЛУ)',
                    content: c.sellTriggerRule,
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.redTask.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.redTask.withValues(alpha: 0.28)),
                    ),
                    child: _buildBlock(
                      icon: Icons.shield_outlined,
                      iconColor: AppColors.redTask,
                      title: '4. РІВЕНЬ ЗЛАМУ МАКРО-СТРУКТУРИ ТА ЗАХИСТ КАПІТАЛУ',
                      content: c.invalidationRule,
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

  Widget _buildQuantTile({
    required String label,
    required String value,
    required String sub,
    required Color valueColor,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 5),
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
            const SizedBox(height: 1),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                sub,
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 8.5),
                maxLines: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLadderRow({
    required String badge,
    required Color badgeColor,
    required String label,
    required String priceStr,
    required String diffStr,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
          decoration: BoxDecoration(
            color: badgeColor.withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            badge,
            style: TextStyle(
              color: badgeColor,
              fontSize: 9.5,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 10.5,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 6),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            priceStr,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.bold,
              fontSize: 11.5,
            ),
          ),
        ),
        const SizedBox(width: 5),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            diffStr,
            style: TextStyle(
              color: badgeColor,
              fontSize: 9.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBlock({
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

  String _formatAmount(double amt) {
    if (amt >= 100) return amt.toStringAsFixed(2);
    if (amt >= 1) return amt.toStringAsFixed(4);
    return amt.toStringAsFixed(6).replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '');
  }

  String _formatPrice(double val) {
    if (val == 0) return '0.0000';
    final abs = val.abs();
    final sign = val < 0 ? '-' : '';
    if (abs >= 1000) {
      return '$sign${NumberFormat('#,##0.0000', 'en_US').format(abs)}';
    } else if (abs >= 0.0001) {
      return '$sign${abs.toStringAsFixed(4)}';
    } else {
      return '$sign${abs.toStringAsFixed(6)}';
    }
  }
}


