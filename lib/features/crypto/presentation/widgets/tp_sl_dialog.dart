import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_theme.dart';
import '../../data/models/crypto_models.dart';
import '../../data/crypto_alert_service.dart';

class TpSlDialog extends StatefulWidget {
  final HoldingItem holding;

  const TpSlDialog({super.key, required this.holding});

  @override
  State<TpSlDialog> createState() => _TpSlDialogState();
}

class _TpSlDialogState extends State<TpSlDialog> {
  late bool _isAlertEnabled;

  @override
  void initState() {
    super.initState();
    _isAlertEnabled =
        CryptoAlertService().isCoinMonitored(widget.holding.symbol);
  }

  @override
  Widget build(BuildContext context) {
    final holding = widget.holding;
    final tpSl = holding.tpSl;
    final hasBollinger = tpSl.bollingerUpper > 0;
    final hasDcaLadder = tpSl.dcaLadder.isNotEmpty;
    final isStable = tpSl.exitSignalCode == 'STABLECOIN';

    Color rrColor = AppColors.greenTask;
    if (tpSl.riskRewardGrade == 'POOR') {
      rrColor = AppColors.redTask;
    } else if (tpSl.riskRewardGrade == 'ACCEPTABLE') {
      rrColor = AppColors.warning;
    }

    Color rsiColor = AppColors.textPrimary;
    if (tpSl.rsi < 35) {
      rsiColor = AppColors.greenTask;
    } else if (tpSl.rsi > 70) {
      rsiColor = AppColors.redTask;
    } else if (tpSl.rsi > 60) {
      rsiColor = AppColors.warning;
    }

    final (Color exitColor, IconData exitIcon) = switch (tpSl.exitSignalCode) {
      'SELL_PEAK_NOW' => (const Color(0xFFF3BA2F), Icons.local_fire_department_rounded),
      'TAKE_PARTIAL_TP1' => (AppColors.greenTask, Icons.check_circle_rounded),
      'TRAILING_STOP_HIT' => (AppColors.warning, Icons.lock_clock_rounded),
      'PRE_STOP_DANGER' => (AppColors.redTask, Icons.warning_amber_rounded),
      'ACCUMULATE_ZONE' => (AppColors.blueTask, Icons.diamond_outlined),
      _ => (AppColors.accentLight, Icons.shield_outlined),
    };

    final Color slProbColor = tpSl.slProbabilityPct >= 62
        ? AppColors.redTask
        : (tpSl.slProbabilityPct >= 42 ? AppColors.warning : AppColors.greenTask);

    final Color peakExhaustColor = tpSl.peakExhaustionScore >= 65
        ? const Color(0xFFF3BA2F)
        : (tpSl.peakExhaustionScore >= 45 ? AppColors.greenTask : AppColors.accentLight);

    final double sellCoinAmt = holding.amount * (tpSl.recommendedSellPct / 100.0);
    final double sellUsdVal = holding.totalUsd * (tpSl.recommendedSellPct / 100.0);

    return Dialog(
      backgroundColor: AppColors.surface,
      insetPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 18),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 740),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: ListView(
            shrinkWrap: true,
            children: [
              // ШАПКА ДІАЛОГУ
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 18,
                          backgroundColor: AppColors.accent.withValues(alpha: 0.15),
                          child: Text(
                            holding.symbol.length > 3
                                ? holding.symbol.substring(0, 3)
                                : holding.symbol,
                            style: const TextStyle(
                              color: AppColors.accent,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${holding.symbol} — План Фіксації & Захисту',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: AppColors.textPrimary,
                                  fontSize: 15.5,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const Text(
                                'Квант-система виходу на піку та захисту від Stop-Loss',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(color: AppColors.textSecondary, fontSize: 10.5),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: () async {
                      final next = !_isAlertEnabled;
                      setState(() => _isAlertEnabled = next);
                      await CryptoAlertService().toggleCoinMonitoring(
                        widget.holding.symbol,
                        next,
                      );
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: _isAlertEnabled
                            ? AppColors.accent.withValues(alpha: 0.15)
                            : AppColors.surfaceVariant,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: _isAlertEnabled
                              ? AppColors.accent.withValues(alpha: 0.5)
                              : AppColors.border,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _isAlertEnabled
                                ? Icons.notifications_active_rounded
                                : Icons.notifications_off_outlined,
                            size: 13,
                            color: _isAlertEnabled
                                ? AppColors.accent
                                : AppColors.textDisabled,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _isAlertEnabled ? 'Алерти ON' : 'OFF',
                            style: TextStyle(
                              color: _isAlertEnabled
                                  ? AppColors.accent
                                  : AppColors.textDisabled,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.close, color: AppColors.textSecondary),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const Divider(color: AppColors.border, height: 16),

              // ПОТОЧНІ ЦІНОВІ МЕТРИКИ
              _buildPriceRow('Поточна ціна:', '\$${_formatPrice(holding.currentPrice)}', AppColors.textPrimary),
              _buildPriceRow('Середній вхід (DCA):', '\$${_formatPrice(holding.avgEntryPrice)}', AppColors.textSecondary),
              _buildPriceRow(
                'Поточний PnL:',
                '${holding.pnlPct >= 0 ? '+' : ''}${holding.pnlPct.toStringAsFixed(2)}% (${holding.pnlUsd >= 0 ? '+' : ''}\$${_formatMoney(holding.pnlUsd)})',
                holding.pnlPct >= 0 ? AppColors.greenTask : AppColors.redTask,
              ),
              const SizedBox(height: 12),

              // ============================================================
              // 1. ГОЛОВНИЙ БЛОК: ВЕРДИКТ ФІКСАЦІЇ ТА ЙМОВІРНІСТЬ СТОП-ЛОСУ
              // ============================================================
              if (!isStable) ...[
                Container(
                  padding: const EdgeInsets.all(13),
                  decoration: BoxDecoration(
                    color: exitColor.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: exitColor.withValues(alpha: 0.45), width: 1.4),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(exitIcon, color: exitColor, size: 18),
                          const SizedBox(width: 7),
                          Expanded(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Text(
                                tpSl.exitTitleUk,
                                style: TextStyle(
                                  color: exitColor,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (tpSl.recommendedSellPct > 0 && holding.amount > 0) ...[
                        const SizedBox(height: 8),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                          decoration: BoxDecoration(
                            color: AppColors.surface.withValues(alpha: 0.85),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: exitColor.withValues(alpha: 0.4)),
                          ),
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Row(
                              children: [
                                Icon(Icons.sell_rounded, size: 14, color: exitColor),
                                const SizedBox(width: 6),
                                Text(
                                  'Рекомендована дія: Продати ${tpSl.recommendedSellPct}% '
                                  '(${_formatAmount(sellCoinAmt)} ${holding.symbol} ≈ \$${_formatMoney(sellUsdVal)})',
                                  style: const TextStyle(
                                    color: AppColors.textPrimary,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 11.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 8),
                      Text(
                        tpSl.exitActionUk,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 11.5,
                          height: 1.35,
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Шкала 1: Виснаження піку (Коли продавати на максимумах)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Flexible(
                            child: Text(
                              'Виснаження піку (Сигнал фіксації верху):',
                              style: TextStyle(color: AppColors.textSecondary, fontSize: 10.5, fontWeight: FontWeight.w600),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '${tpSl.peakExhaustionScore}%',
                            style: TextStyle(color: peakExhaustColor, fontWeight: FontWeight.bold, fontSize: 11.5),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: SizedBox(
                          height: 6,
                          child: LinearProgressIndicator(
                            value: (tpSl.peakExhaustionScore / 100.0).clamp(0.0, 1.0),
                            backgroundColor: AppColors.background,
                            valueColor: AlwaysStoppedAnimation<Color>(peakExhaustColor),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),

                      // Шкала 2: Ймовірність падіння до Stop-Loss
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Flexible(
                            child: Text(
                              'Ймовірність падіння до Stop-Loss:',
                              style: TextStyle(color: AppColors.textSecondary, fontSize: 10.5, fontWeight: FontWeight.w600),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '${tpSl.slProbabilityPct}% (${tpSl.slProbabilityPct >= 62 ? 'ВИСОКА ЗАГРОЗА' : (tpSl.slProbabilityPct >= 42 ? 'ПОМІРНА' : 'НИЗЬКА')})',
                            style: TextStyle(color: slProbColor, fontWeight: FontWeight.bold, fontSize: 11),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: SizedBox(
                          height: 6,
                          child: LinearProgressIndicator(
                            value: (tpSl.slProbabilityPct / 100.0).clamp(0.0, 1.0),
                            backgroundColor: AppColors.background,
                            valueColor: AlwaysStoppedAnimation<Color>(slProbColor),
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Фактори ризику: ${tpSl.slRiskFactorsUk} • Потік покупок Taker: ${tpSl.takerBuyRatio.toStringAsFixed(0)}%',
                        style: const TextStyle(color: AppColors.textSecondary, fontSize: 10, height: 1.3),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // ============================================================
                // 2. МАТРИЦЯ ЗАХИСТУ ПОЗИЦІЇ (3 КРИТИЧНІ ЛІНІЇ ВИХОДУ)
                // ============================================================
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceVariant,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.security_rounded, color: Color(0xFFF3BA2F), size: 15),
                          SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'МАТРИЦЯ ЗАХИСТУ ПРИБУТКУ ТА РАННЬОГО ВИХОДУ',
                              style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 10.5,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.4,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      _buildProtectionLevelTile(
                        badge: '1. БЕЗЗБИТОК',
                        badgeColor: AppColors.greenTask,
                        title: 'Точка беззбитковості (+0.25% комісії)',
                        subtitle: 'Куди перенести стоп після фіксації TP1, щоб не піти в мінус',
                        price: tpSl.breakevenPrice,
                        currentPrice: holding.currentPrice,
                      ),
                      const SizedBox(height: 6),
                      _buildProtectionLevelTile(
                        badge: '2. ТРЕЙЛІНГ',
                        badgeColor: const Color(0xFFF3BA2F),
                        title: 'Chandelier Трейлінг-Стоп (Пік - 1.8 ATR)',
                        subtitle:
                            'Пік 20D: \$${_formatPrice(tpSl.recentPeak20d)} (відкат -${tpSl.pullbackFromPeakPct}%). Пробій вниз = фіксувати профіт!',
                        price: tpSl.trailingStopPrice,
                        currentPrice: holding.currentPrice,
                      ),
                      const SizedBox(height: 6),
                      _buildProtectionLevelTile(
                        badge: '3. ПРЕ-СТОП',
                        badgeColor: AppColors.warning,
                        title: 'Лінія ранньої евакуації (Pre-Stop Exit)',
                        subtitle: 'Вихід при зламі локальної підтримки, щоб не чекати глибокого Stop-Loss',
                        price: tpSl.earlyExitPrice,
                        currentPrice: holding.currentPrice,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],

              // 3. БЕЙДЖ СТАТУСУ РИЗИК/ПРИБУТОК (R:R) ТА BTC REGIME
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: rrColor.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: rrColor.withValues(alpha: 0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.balance_rounded, color: rrColor, size: 16),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            tpSl.riskRewardLabel,
                            style: TextStyle(
                              color: rrColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(Icons.currency_bitcoin_rounded, color: AppColors.accent, size: 14),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            tpSl.btcMarketRegime,
                            style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // 4. ІНДИКАТОРИ ІМПУЛЬСУ: RSI (14) + ОБ'ЄМ + ATR ВОЛАТИЛЬНІСТЬ
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.surfaceVariant,
                  borderRadius: BorderRadius.circular(14),
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
                            Icon(Icons.speed_rounded, color: AppColors.accent, size: 16),
                            SizedBox(width: 6),
                            Text(
                              'RSI (14)',
                              style: TextStyle(color: AppColors.textSecondary, fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        Text(
                          tpSl.rsi.toStringAsFixed(1),
                          style: TextStyle(color: rsiColor, fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: SizedBox(
                        height: 6,
                        child: LinearProgressIndicator(
                          value: (tpSl.rsi / 100).clamp(0.0, 1.0),
                          backgroundColor: AppColors.background,
                          valueColor: AlwaysStoppedAnimation<Color>(rsiColor),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      tpSl.rsiStatus,
                      style: TextStyle(color: rsiColor, fontSize: 11, fontWeight: FontWeight.w600),
                    ),
                    if (tpSl.rsiDivergence != 'Відсутня') ...[
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: (tpSl.rsiDivergence.contains('Ведмежа') ? AppColors.redTask : AppColors.greenTask)
                              .withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          tpSl.rsiDivergence,
                          style: TextStyle(
                            color: tpSl.rsiDivergence.contains('Ведмежа') ? AppColors.redTask : AppColors.greenTask,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                    const Divider(color: AppColors.border, height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Торговий об\'єм:', style: TextStyle(color: AppColors.textSecondary, fontSize: 10)),
                              Text(
                                tpSl.volumeStatus,
                                style: const TextStyle(color: AppColors.textPrimary, fontSize: 11, fontWeight: FontWeight.w600),
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
                            const Text('ATR волатильність:', style: TextStyle(color: AppColors.textSecondary, fontSize: 10)),
                            Text(
                              '±${tpSl.atrPct}% (\$${_formatPrice(tpSl.atr)})',
                              style: const TextStyle(color: AppColors.accentLight, fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // 5. КАНАЛ БОЛЛІНДЖЕРА (1D, SMA 20)
              if (hasBollinger) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceVariant,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.accent.withValues(alpha: 0.2)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.analytics_rounded, color: AppColors.accent, size: 16),
                          SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'СМУГИ БОЛЛІНДЖЕРА (1D, SMA 20)',
                              style: TextStyle(color: AppColors.textSecondary, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        tpSl.positionInChannel,
                        style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Flexible(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Нижня (Дно)', style: TextStyle(color: AppColors.blueTask, fontSize: 10)),
                                FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text('\$${_formatPrice(tpSl.bollingerLower)}', style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 12)),
                                ),
                              ],
                            ),
                          ),
                          Flexible(
                            child: Column(
                              children: [
                                const Text('Середня (SMA20)', style: TextStyle(color: AppColors.textSecondary, fontSize: 10)),
                                FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text('\$${_formatPrice(tpSl.bollingerMiddle)}', style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 12)),
                                ),
                              ],
                            ),
                          ),
                          Flexible(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                const Text('Верхня (Опір)', style: TextStyle(color: AppColors.warning, fontSize: 10)),
                                FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text('\$${_formatPrice(tpSl.bollingerUpper)}', style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 12)),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],

              // 6. 3 ШАРИ ФІКСАЦІЇ ПРИБУТКУ (КАСКАД ПРОДАЖУ НА МАКСИМУМАХ)
              const Text(
                'КАСКАД ФІКСАЦІЇ НА МАКСИМУМАХ (TAKE-PROFIT):',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.6,
                ),
              ),
              const SizedBox(height: 8),
              _buildTpCard(
                title: tpSl.tp1Label,
                price: tpSl.tp1,
                entryPrice: holding.avgEntryPrice,
                percentToSell: tpSl.tp1Pct,
                distPct: tpSl.distToTp1Pct,
                isReached: tpSl.isTp1Reached,
                badgeColor: AppColors.greenTask,
                description: tpSl.isTp1Reached
                    ? 'Ціль досягнута! Зафіксуйте ${tpSl.tp1Pct}% зараз та перенесіть стоп у беззбиток \$${_formatPrice(tpSl.breakevenPrice)}'
                    : 'Фіксація ${tpSl.tp1Pct}% біля верхнього каналу Боллінджера + стоп у беззбиток',
              ),
              const SizedBox(height: 8),
              _buildTpCard(
                title: tpSl.tp2Label,
                price: tpSl.tp2,
                entryPrice: holding.avgEntryPrice,
                percentToSell: tpSl.tp2Pct,
                distPct: tpSl.distToTp2Pct,
                isReached: holding.currentPrice >= tpSl.tp2 * 0.99,
                badgeColor: AppColors.blueTask,
                description: 'Фіксація ${tpSl.tp2Pct}% на рівні структурного опору (Swing High)',
              ),
              const SizedBox(height: 8),
              _buildTpCard(
                title: tpSl.tp3Label,
                price: tpSl.tp3,
                entryPrice: holding.avgEntryPrice,
                percentToSell: tpSl.tp3Pct,
                distPct: tpSl.distToTp3Pct,
                isReached: holding.currentPrice >= tpSl.tp3 * 0.99,
                badgeColor: AppColors.accentLight,
                description: 'Фіксація залишку ${tpSl.tp3Pct}% на глобальному максимумі 100d / ейфорії',
              ),
              const SizedBox(height: 14),

              // 7. РОЗУМНА DCA-СІТКА (3 ЛІМІТНІ ОРДЕРИ НА ВІДКУП ДНА)
              if (hasDcaLadder) ...[
                const Text(
                  'РОЗУМНА DCA-СІТКА ВІДКУПУ ДНА (3 ТРАНШІ):',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.6,
                  ),
                ),
                const SizedBox(height: 8),
                ...tpSl.dcaLadder.map((order) {
                  return Container(
                    margin: const EdgeInsets.symmetric(vertical: 3),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.blueTask.withValues(alpha: 0.07),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.blueTask.withValues(alpha: 0.2)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: AppColors.blueTask,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      'Ордер ${order.orderNumber} (${order.sharePct}%)',
                                      style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Flexible(
                                    child: FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: Text(
                                        '\$${_formatPrice(order.targetPrice)}',
                                        style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 13),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                order.rationale,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(color: AppColors.textSecondary, fontSize: 10),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '-${order.distFromCurrentPct.toStringAsFixed(1)}%',
                          style: const TextStyle(color: AppColors.blueTask, fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                      ],
                    ),
                  );
                }),
                const SizedBox(height: 14),
              ],

              // 8. АДАПТИВНИЙ СТОП-ЛОС ЗА ATR (КРАЙНІЙ РУБІЖ ЗАХИСТУ)
              const Text(
                'ЖОРСТКИЙ СТОП-ЛОС (КРАЙНІЙ РУБІЖ INVALIDATION):',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.6,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.redTask.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.redTask.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Flexible(
                                child: Text(
                                  'Адаптивний Stop-Loss',
                                  style: TextStyle(
                                    color: AppColors.redTask,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                decoration: BoxDecoration(
                                  color: slProbColor.withValues(alpha: 0.16),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  'Ймовірність: ${tpSl.slProbabilityPct}%',
                                  style: TextStyle(
                                    color: slProbColor,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 9.5,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Text(
                            tpSl.stopReason,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: AppColors.textSecondary.withValues(alpha: 0.85),
                              fontSize: 11,
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
                          child: Text(
                            '\$${_formatPrice(tpSl.stopLoss)}',
                            style: const TextStyle(
                              color: AppColors.redTask,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        Text(
                          'до стопу: -${tpSl.distToSlPct.toStringAsFixed(1)}%',
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProtectionLevelTile({
    required String badge,
    required Color badgeColor,
    required String title,
    required String subtitle,
    required double price,
    required double currentPrice,
  }) {
    final diffPct = currentPrice > 0 ? (((price - currentPrice) / currentPrice) * 100.0) : 0.0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: badgeColor.withValues(alpha: 0.28)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                      decoration: BoxDecoration(
                        color: badgeColor.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        badge,
                        style: TextStyle(color: badgeColor, fontWeight: FontWeight.bold, fontSize: 9),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.bold,
                          fontSize: 11.5,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 10),
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
                child: Text(
                  '\$${_formatPrice(price)}',
                  style: TextStyle(
                    color: badgeColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
              Text(
                '${diffPct >= 0 ? '+' : ''}${diffPct.toStringAsFixed(1)}%',
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 10),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPriceRow(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerRight,
              child: Text(
                value,
                style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTpCard({
    required String title,
    required double price,
    required double entryPrice,
    required int percentToSell,
    required double distPct,
    required bool isReached,
    required Color badgeColor,
    required String description,
  }) {
    final double gainFromEntryPct = (entryPrice > 0 && price > 0)
        ? (((price - entryPrice) / entryPrice) * 100.0)
        : distPct;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: badgeColor.withValues(alpha: isReached ? 0.15 : 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: badgeColor.withValues(alpha: isReached ? 0.65 : 0.3),
          width: isReached ? 1.5 : 1.0,
        ),
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
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: badgeColor,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        isReached ? 'ПРОДАТИ $percentToSell% ЗАРАЗ' : 'Фіксувати $percentToSell%',
                        style: const TextStyle(color: Colors.white, fontSize: 9.5, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.bold,
                          fontSize: 12.5,
                        ),
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
                    child: Text(
                      '\$${_formatPrice(price)}',
                      style: TextStyle(
                        color: badgeColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  Text(
                    entryPrice > 0
                        ? '${distPct >= 0 ? '+' : ''}${distPct.toStringAsFixed(1)}% (${gainFromEntryPct >= 0 ? '+' : ''}${gainFromEntryPct.toStringAsFixed(1)}% до входу)'
                        : '${distPct >= 0 ? '+' : ''}${distPct.toStringAsFixed(1)}%',
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 10),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            description,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: AppColors.textSecondary.withValues(alpha: 0.85),
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  String _formatAmount(double amt) {
    if (amt >= 100) return amt.toStringAsFixed(2);
    if (amt >= 1) return amt.toStringAsFixed(4);
    return amt.toStringAsFixed(6).replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '');
  }

  String _formatMoney(double val) {
    final abs = val.abs();
    if (abs >= 1000) return NumberFormat('#,##0.00', 'en_US').format(abs);
    if (abs >= 0.01) return abs.toStringAsFixed(2);
    return abs.toStringAsFixed(4);
  }

  String _formatPrice(double price) {
    if (price == 0) return '0.0000';
    final abs = price.abs();
    final sign = price < 0 ? '-' : '';
    if (abs >= 1000) {
      return '$sign${NumberFormat('#,##0.0000', 'en_US').format(abs)}';
    } else if (abs >= 0.0001) {
      return '$sign${abs.toStringAsFixed(4)}';
    } else {
      return '$sign${abs.toStringAsFixed(6)}';
    }
  }
}
