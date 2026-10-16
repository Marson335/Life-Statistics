import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_theme.dart';
import '../../data/models/crypto_models.dart';

class TpSlDialog extends StatelessWidget {
  final HoldingItem holding;

  const TpSlDialog({super.key, required this.holding});

  @override
  Widget build(BuildContext context) {
    final tpSl = holding.tpSl;
    final hasBollinger = tpSl.bollingerUpper > 0;
    final hasDcaLadder = tpSl.dcaLadder.isNotEmpty;

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

    return Dialog(
      backgroundColor: AppColors.surface,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480, maxHeight: 680),
        child: Padding(
          padding: const EdgeInsets.all(18),
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
                          backgroundColor: AppColors.accent.withOpacity(0.15),
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
                                '${holding.symbol} — Професійний Аудит',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: AppColors.textPrimary,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const Text(
                                'Денний таймфрейм (1D свічки)',
                                style: TextStyle(color: AppColors.textSecondary, fontSize: 11),
                              ),
                            ],
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
              const Divider(color: AppColors.border, height: 16),

              // ПОТОЧНІ ЦІНОВІ МЕТРИКИ
              _buildPriceRow('Поточна ціна:', '\$${_formatPrice(holding.currentPrice)}', AppColors.textPrimary),
              _buildPriceRow('Середній вхід (DCA):', '\$${_formatPrice(holding.avgEntryPrice)}', AppColors.textSecondary),
              _buildPriceRow(
                'Поточний PnL:',
                '${holding.pnlPct >= 0 ? '+' : ''}${holding.pnlPct.toStringAsFixed(2)}% (${holding.pnlUsd >= 0 ? '+' : ''}\$${_formatPrice(holding.pnlUsd)})',
                holding.pnlPct >= 0 ? AppColors.greenTask : AppColors.redTask,
              ),
              const SizedBox(height: 12),

              // 1. БЕЙДЖ СТАТУСУ РИЗИК/ПРИБУТОК (R:R) ТА BTC REGIME
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: rrColor.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: rrColor.withOpacity(0.3)),
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

              // 2. ІНДИКАТОРИ ІМПУЛЬСУ: RSI (14) + ОБ'ЄМ + ATR ВОЛАТИЛЬНІСТЬ
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
                    // RSI прогрес бар
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
                          color: AppColors.greenTask.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          tpSl.rsiDivergence,
                          style: const TextStyle(color: AppColors.greenTask, fontSize: 10, fontWeight: FontWeight.bold),
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

              // 3. КАНАЛ БОЛЛІНДЖЕРА (1D, SMA 20)
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
                const SizedBox(height: 12),
              ],

              // 4. 3 ШАРИ ФІКСАЦІЇ ПРИБУТКУ
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

              // 5. РОЗУМНА DCA-СІТКА (3 ЛІМІТНІ ОРДЕРИ НА ВІДКУП ДНА)
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
                      color: AppColors.blueTask.withOpacity(0.07),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.blueTask.withOpacity(0.2)),
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
                                  Text(
                                    '\$${_formatPrice(order.targetPrice)}',
                                    style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 13),
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

              // 6. АДАПТИВНИЙ СТОП-ЛОС ЗА ATR
              const Text(
                'АДАПТИВНИЙ СТОП-ЛОС (ЗАХИСТ ВІД СКВИЗІВ):',
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
                            'Адаптивний Stop-Loss',
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
          Text(
            value,
            style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.bold),
          ),
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
        color: badgeColor.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: badgeColor.withOpacity(0.3)),
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
                        'Фіксувати $percentToSell%',
                        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
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
                          fontSize: 13,
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
                  Text(
                    '\$${_formatPrice(price)}',
                    style: TextStyle(
                      color: badgeColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    '${distPct >= 0 ? '+' : ''}${distPct.toStringAsFixed(1)}%',
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            description,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: AppColors.textSecondary.withOpacity(0.8),
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  String _formatPrice(double price) {
    if (price >= 1000) {
      return NumberFormat('#,##0.00', 'en_US').format(price);
    } else if (price >= 1) {
      return price.toStringAsFixed(2);
    } else if (price >= 0.0001) {
      return price.toStringAsFixed(4);
    } else {
      return price.toStringAsFixed(6);
    }
  }
}
