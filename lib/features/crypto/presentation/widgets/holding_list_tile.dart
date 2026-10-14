import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../data/models/crypto_models.dart';
import '../providers/crypto_portfolio_provider.dart';
import 'tp_sl_dialog.dart';

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
                      if (holding.sources.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Wrap(
                          spacing: 4,
                          children: holding.sources.map((s) => Container(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                            decoration: BoxDecoration(
                              color: AppColors.accent.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              s,
                              style: const TextStyle(
                                color: AppColors.accentLight,
                                fontSize: 9,
                              ),
                            ),
                          )).toList(),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // Вартість, Зміна періоду та PnL
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '\$${holding.totalUsd.toStringAsFixed(2)}',
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
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
                    Text(
                      'PnL: ${isPnlPositive ? '+' : ''}\$${holding.pnlUsd.toStringAsFixed(2)} (${isPnlPositive ? '+' : ''}${holding.pnlPct.toStringAsFixed(1)}%)',
                      style: TextStyle(
                        color: isPnlPositive ? AppColors.greenTask : AppColors.redTask,
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
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

  String _formatAmount(double amt) {
    if (amt >= 1000) return amt.toStringAsFixed(2);
    if (amt >= 1) return amt.toStringAsFixed(4);
    return amt.toStringAsFixed(6);
  }

  String _formatPrice(double p) {
    if (p >= 1000) return p.toStringAsFixed(2);
    if (p >= 1) return p.toStringAsFixed(4);
    return p.toStringAsFixed(6);
  }
}
