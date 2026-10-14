import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../data/models/crypto_models.dart';

class TpSlDialog extends StatelessWidget {
  final HoldingItem holding;

  const TpSlDialog({super.key, required this.holding});

  static String _formatPrice(double p) {
    if (p >= 1000) {
      return p.toStringAsFixed(2).replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
        (Match m) => '${m[1]},',
      );
    }
    if (p >= 1) return p.toStringAsFixed(2);
    if (p >= 0.0001) return p.toStringAsFixed(4);
    return p.toStringAsFixed(6);
  }

  @override
  Widget build(BuildContext context) {
    final tpSl = holding.tpSl;
    final hasBollinger = tpSl.bollingerUpper > 0;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Шапка
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.accent.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            holding.symbol,
                            style: const TextStyle(
                              color: AppColors.accentLight,
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'Технічний аналіз 1D',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: AppColors.textSecondary),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const Divider(color: AppColors.border, height: 18),

              // Поточні цінові показники
              _buildPriceRow('Поточна ціна:', '\$${_formatPrice(holding.currentPrice)}', AppColors.textPrimary),
              _buildPriceRow('Середній вхід (DCA):', '\$${_formatPrice(holding.avgEntryPrice)}', AppColors.textSecondary),
              _buildPriceRow(
                'Поточний PnL:',
                '${holding.pnlPct >= 0 ? '+' : ''}${holding.pnlPct.toStringAsFixed(2)}% (${holding.pnlUsd >= 0 ? '+' : ''}\$${_formatPrice(holding.pnlUsd)})',
                holding.pnlPct >= 0 ? AppColors.greenTask : AppColors.redTask,
              ),
              const SizedBox(height: 14),

              // БЛОК 1: КАНАЛ БОЛЛІНДЖЕРА ТА СТРУКТУРА (1D)
              if (hasBollinger) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceVariant,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.accent.withOpacity(0.2)),
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
                                Text('\$${_formatPrice(tpSl.bollingerLower)}', style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 12)),
                              ],
                            ),
                          ),
                          Flexible(
                            child: Column(
                              children: [
                                const Text('Середня (SMA20)', style: TextStyle(color: AppColors.textSecondary, fontSize: 10)),
                                Text('\$${_formatPrice(tpSl.bollingerMiddle)}', style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 12)),
                              ],
                            ),
                          ),
                          Flexible(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                const Text('Верхня (Опір)', style: TextStyle(color: AppColors.warning, fontSize: 10)),
                                Text('\$${_formatPrice(tpSl.bollingerUpper)}', style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 12)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
              ],

              // БЛОК 2: 3 ШАРИ ФІКСАЦІЇ ПРИБУТКУ
              const Text(
                'ШАРИ ФІКСАЦІЇ ПРИБУТКУ (TAKE-PROFIT):',
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
                percentToSell: tpSl.tp1Pct,
                distPct: tpSl.distToTp1Pct,
                badgeColor: AppColors.greenTask,
                description: 'Фіксація ${tpSl.tp1Pct}% біля верхнього каналу Боллінджера',
              ),
              const SizedBox(height: 8),
              _buildTpCard(
                title: tpSl.tp2Label,
                price: tpSl.tp2,
                percentToSell: tpSl.tp2Pct,
                distPct: tpSl.distToTp2Pct,
                badgeColor: AppColors.blueTask,
                description: 'Фіксація ${tpSl.tp2Pct}% на рівні локального супротиву (Swing High)',
              ),
              const SizedBox(height: 8),
              _buildTpCard(
                title: tpSl.tp3Label,
                price: tpSl.tp3,
                percentToSell: tpSl.tp3Pct,
                distPct: tpSl.distToTp3Pct,
                badgeColor: AppColors.accentLight,
                description: 'Фіксація залишку ${tpSl.tp3Pct}% на піку 100d або розширенні циклу',
              ),
              const SizedBox(height: 14),

              // БЛОК 3: ЗОНА ДОЗАКУПКИ НА ДНІ
              if (tpSl.accumulatePrice > 0) ...[
                const Text(
                  'ЗОНА НАКОПИЧЕННЯ / ДОБОРУ (BUY THE DIP):',
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
                    color: AppColors.blueTask.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.blueTask.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Рівень закупки на дні',
                              style: TextStyle(
                                color: AppColors.blueTask,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 2),
                            const Text(
                              'Виставте лімітний ордер на відкуп біля нижнього Боллінджера / підтримки',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(color: AppColors.textSecondary, fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '\$${_formatPrice(tpSl.accumulatePrice)}',
                            style: const TextStyle(
                              color: AppColors.blueTask,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          Text(
                            '-${tpSl.distToAccumulatePct.toStringAsFixed(1)}%',
                            style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
              ],

              // БЛОК 4: СТРУКТУРНИЙ СТОП-ЛОС
              const Text(
                'СТРУКТУРНИЙ СТОП-ЛОС:',
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
                  color: AppColors.redTask.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.redTask.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Захисний стоп-лос',
                            style: TextStyle(
                              color: AppColors.redTask,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            tpSl.stopReason,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: AppColors.textSecondary.withOpacity(0.85),
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
                        Text(
                          '\$${_formatPrice(tpSl.stopLoss)}',
                          style: const TextStyle(
                            color: AppColors.redTask,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
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
          Text(value, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildTpCard({
    required String title,
    required double price,
    required int percentToSell,
    required double distPct,
    required Color badgeColor,
    required String description,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 6,
                  runSpacing: 2,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: badgeColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: badgeColor.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'Закрити $percentToSell%',
                        style: TextStyle(
                          color: badgeColor,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppColors.textSecondary.withOpacity(0.85),
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
              Text(
                '\$${_formatPrice(price)}',
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              Text(
                '+${distPct.toStringAsFixed(1)}%',
                style: TextStyle(
                  color: badgeColor,
                  fontWeight: FontWeight.w600,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
