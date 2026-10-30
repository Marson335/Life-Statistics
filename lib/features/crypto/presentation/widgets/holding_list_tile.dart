import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_theme.dart';
import '../../data/models/crypto_models.dart';
import '../providers/crypto_portfolio_provider.dart';
import 'tp_sl_dialog.dart';
import '../../data/crypto_alert_service.dart';

class HoldingListTile extends StatelessWidget {
  final HoldingItem holding;
  final TimePeriod selectedPeriod;

  const HoldingListTile({
    super.key,
    required this.holding,
    required this.selectedPeriod,
  });

  double _getPeriodChange() {
    switch (selectedPeriod) {
      case TimePeriod.h24:
        return holding.chg24h;
      case TimePeriod.d7:
        return holding.chg7d;
      case TimePeriod.d30:
        return holding.chg30d;
      case TimePeriod.d90:
        return holding.chg30d * 1.5;
      case TimePeriod.y1:
        return holding.chg1y;
      case TimePeriod.all:
        return holding.pnlPct;
    }
  }

  String _getPeriodLabel() {
    switch (selectedPeriod) {
      case TimePeriod.h24:
        return '24г';
      case TimePeriod.d7:
        return '7д';
      case TimePeriod.d30:
        return '30д';
      case TimePeriod.d90:
        return '90д';
      case TimePeriod.y1:
        return '1р';
      case TimePeriod.all:
        return 'Всі';
    }
  }

  @override
  Widget build(BuildContext context) {
    final periodChg = _getPeriodChange();
    final isChgPositive = periodChg >= 0;
    final isPnlPositive = holding.pnlUsd >= 0;
    final tpSl = holding.tpSl;
    final isStable = tpSl.exitSignalCode == 'STABLECOIN';

    final (Color signalColor, String signalShortLabel) = switch (tpSl.exitSignalCode) {
      'SELL_PEAK_NOW' => (
          const Color(0xFFF3BA2F),
          '🔥 Фіксувати ${tpSl.recommendedSellPct}% (Пік ${tpSl.peakExhaustionScore}%)',
        ),
      'TRAILING_STOP_HIT' => (
          AppColors.warning,
          '🔒 Трейлінг пробито (Продати ${tpSl.recommendedSellPct}%)',
        ),
      'TAKE_PARTIAL_TP1' => (
          AppColors.greenTask,
          '🟢 Частковий TP1 (30%)',
        ),
      'PRE_STOP_DANGER' => (
          AppColors.redTask,
          '🚨 Загроза SL ${tpSl.slProbabilityPct}% (Пре-стоп \$${_formatPrice(tpSl.earlyExitPrice)})',
        ),
      'ACCUMULATE_ZONE' => (
          AppColors.blueTask,
          '💎 Зона добору (RSI ${tpSl.rsi.toStringAsFixed(0)})',
        ),
      _ => (
          AppColors.textSecondary,
          '🛡️ Тримати · Ризик SL ${tpSl.slProbabilityPct}%',
        ),
    };

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            showDialog(
              context: context,
              builder: (ctx) => TpSlDialog(holding: holding),
            );
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                // Іконка активу
                CircleAvatar(
                  radius: 20,
                  backgroundColor: AppColors.surfaceVariant,
                  child: Text(
                    holding.symbol.length > 3
                        ? holding.symbol.substring(0, 3)
                        : holding.symbol,
                    style: const TextStyle(
                      color: AppColors.accentLight,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Назва та кількість
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              holding.symbol,
                              style: const TextStyle(
                                color: AppColors.textPrimary,
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
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
                            child: Text(
                              '${holding.sharePct.toStringAsFixed(1)}%',
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          if (CryptoAlertService().isCoinMonitored(holding.symbol)) ...[
                            const SizedBox(width: 4),
                            const Icon(
                              Icons.notifications_active_rounded,
                              size: 11,
                              color: AppColors.accent,
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${_formatAmount(holding.amount)} @ \$${_formatPrice(holding.currentPrice)}',
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 4,
                        runSpacing: 4,
                        children: [
                          if (!isStable)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                              decoration: BoxDecoration(
                                color: signalColor.withValues(alpha: 0.14),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: signalColor.withValues(alpha: 0.35), width: 0.8),
                              ),
                              child: Text(
                                signalShortLabel,
                                style: TextStyle(
                                  color: signalColor,
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ...holding.sources.map((s) => Container(
                                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1.5),
                                decoration: BoxDecoration(
                                  color: AppColors.accent.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  s,
                                  style: const TextStyle(
                                    color: AppColors.accentLight,
                                    fontSize: 9,
                                  ),
                                ),
                              )),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // Вартість, Зміна періоду та PnL
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerRight,
                      child: Text(
                        '\$${_formatTotalUsd(holding.totalUsd)}',
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${_getPeriodLabel()}: ',
                          style: const TextStyle(color: AppColors.textDisabled, fontSize: 11),
                        ),
                        Text(
                          '${isChgPositive ? '+' : ''}${periodChg.toStringAsFixed(1)}%',
                          style: TextStyle(
                            color: isChgPositive ? AppColors.greenTask : AppColors.redTask,
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerRight,
                      child: Text(
                        'PnL: ${_formatPnlUsd(holding.pnlUsd)} (${isPnlPositive ? '+' : ''}${holding.pnlPct.toStringAsFixed(2)}%)',
                        style: TextStyle(
                          color: isPnlPositive ? AppColors.greenTask : AppColors.redTask,
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 4),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.textDisabled,
                  size: 18,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatTotalUsd(double val) {
    if (val == 0) return '0.00';
    final abs = val.abs();
    if (abs >= 1000) return NumberFormat('#,##0.00', 'en_US').format(abs);
    if (abs >= 0.01) return abs.toStringAsFixed(2);
    return abs.toStringAsFixed(4);
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

  String _formatAmount(double amt) {
    if (amt >= 1000) return amt.toStringAsFixed(2);
    if (amt >= 1) return amt.toStringAsFixed(4);
    return amt.toStringAsFixed(6);
  }

  String _formatPrice(double p) {
    if (p == 0) return '0.0000';
    final abs = p.abs();
    final sign = p < 0 ? '-' : '';
    if (abs >= 1000) {
      return '$sign${NumberFormat('#,##0.0000', 'en_US').format(abs)}';
    } else if (abs >= 0.0001) {
      return '$sign${abs.toStringAsFixed(4)}';
    } else {
      return '$sign${abs.toStringAsFixed(6)}';
    }
  }
}
