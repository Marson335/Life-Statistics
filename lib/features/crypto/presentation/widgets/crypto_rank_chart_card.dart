import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_theme.dart';
import '../../data/models/crypto_models.dart';
import '../providers/crypto_portfolio_provider.dart';

enum PortfolioChartCategory {
  spot,
  futures,
  total,
}

enum ChartMetricType {
  balance,
  pnl,
  percent,
}

class CryptoRankChartCard extends StatefulWidget {
  final PortfolioHistoricalDataset? dataset;
  final TimePeriod selectedPeriod;
  final Function(TimePeriod) onPeriodChanged;
  final VoidCallback onRefresh;
  final bool isLoading;
  final bool isLive;
  final PortfolioChartCategory initialCategory;

  const CryptoRankChartCard({
    super.key,
    required this.dataset,
    required this.selectedPeriod,
    required this.onPeriodChanged,
    required this.onRefresh,
    required this.isLoading,
    this.isLive = false,
    this.initialCategory = PortfolioChartCategory.spot,
  });

  @override
  State<CryptoRankChartCard> createState() => _CryptoRankChartCardState();
}

class _CryptoRankChartCardState extends State<CryptoRankChartCard> {
  late PortfolioChartCategory _category;
  ChartMetricType _metric = ChartMetricType.balance;
  bool _hideBalance = false;
  int? _touchedIndex;

  @override
  void initState() {
    super.initState();
    _category = widget.initialCategory;
  }

  @override
  void didUpdateWidget(covariant CryptoRankChartCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialCategory != widget.initialCategory) {
      _category = widget.initialCategory;
    }
  }

  List<ChartPoint> _getActivePoints() {
    final ds = widget.dataset;
    if (ds == null) return [];

    switch (_category) {
      case PortfolioChartCategory.spot:
        return ds.spotPoints;
      case PortfolioChartCategory.futures:
        return ds.futuresPoints;
      case PortfolioChartCategory.total:
        return ds.totalPoints;
    }
  }

  double _getPointValue(ChartPoint pt) {
    switch (_metric) {
      case ChartMetricType.balance:
        return pt.balance;
      case ChartMetricType.pnl:
        return pt.pnl;
      case ChartMetricType.percent:
        return pt.pnlPct;
    }
  }

  String _getCategoryTitle() {
    switch (_category) {
      case PortfolioChartCategory.spot:
        return 'СПОТОВИЙ БАЛАНС';
      case PortfolioChartCategory.futures:
        return 'Ф\'ЮЧЕРСНИЙ БАЛАНС';
      case PortfolioChartCategory.total:
        return 'ЗАГАЛЬНИЙ БАЛАНС';
    }
  }

  @override
  Widget build(BuildContext context) {
    final ds = widget.dataset ?? PortfolioHistoricalDataset.empty();
    final points = _getActivePoints();

    // Визначаємо поточні значення залежно від того, чи тримає користувач палець на графіку
    ChartPoint? touchedPoint;
    if (_touchedIndex != null && _touchedIndex! >= 0 && _touchedIndex! < points.length) {
      touchedPoint = points[_touchedIndex!];
    }

    double displayBalance;
    double displayPnl;
    double displayPnlPct;
    DateTime? displayDate;

    if (touchedPoint != null) {
      displayBalance = touchedPoint.balance;
      displayPnl = touchedPoint.pnl;
      displayPnlPct = touchedPoint.pnlPct;
      displayDate = touchedPoint.timestamp;
    } else {
      switch (_category) {
        case PortfolioChartCategory.spot:
          displayBalance = ds.spotBalance;
          displayPnl = ds.spotPnlUsd;
          displayPnlPct = ds.spotPnlPct;
          break;
        case PortfolioChartCategory.futures:
          displayBalance = ds.futuresMargin;
          displayPnl = ds.futuresPnlUsd;
          displayPnlPct = ds.futuresPnlPct;
          break;
        case PortfolioChartCategory.total:
          displayBalance = ds.totalBalance;
          displayPnl = ds.totalPnlUsd;
          displayPnlPct = ds.totalPnlPct;
          break;
      }
    }

    final isPnlPositive = displayPnl >= 0;
    final chartColor = isPnlPositive ? AppColors.greenTask : AppColors.redTask;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. ПЕРЕМИКАЧ КАТЕГОРІЇ: [ Спот | Ф'ючерси | Загальний ]
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: AppColors.surfaceVariant,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _buildCategorySegment(
                    category: PortfolioChartCategory.spot,
                    icon: Icons.pie_chart_outline_rounded,
                    label: 'Спот',
                  ),
                ),
                Expanded(
                  child: _buildCategorySegment(
                    category: PortfolioChartCategory.futures,
                    icon: Icons.bolt_rounded,
                    label: 'Ф\'ючерси',
                  ),
                ),
                Expanded(
                  child: _buildCategorySegment(
                    category: PortfolioChartCategory.total,
                    icon: Icons.all_inclusive_rounded,
                    label: 'Загальний',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 2. ВЕРХНІЙ РЯДОК: Заголовок + Око (приховати баланс) + Live + Refresh
          Row(
            children: [
              Expanded(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        _getCategoryTitle(),
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.6,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 6),
                    GestureDetector(
                      onTap: () => setState(() => _hideBalance = !_hideBalance),
                      child: Icon(
                        _hideBalance ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                        color: AppColors.textSecondary,
                        size: 18,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (widget.isLive) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.greenTask.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AppColors.greenTask.withValues(alpha: 0.3)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.fiber_manual_record, color: AppColors.greenTask, size: 7),
                      SizedBox(width: 3),
                      Text(
                        'LIVE',
                        style: TextStyle(
                          color: AppColors.greenTask,
                          fontWeight: FontWeight.bold,
                          fontSize: 9,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
              ],
              IconButton(
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                icon: widget.isLoading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accent),
                      )
                    : const Icon(Icons.refresh_rounded, color: AppColors.textSecondary, size: 18),
                onPressed: widget.isLoading ? null : widget.onRefresh,
                tooltip: 'Оновити',
              ),
            ],
          ),
          const SizedBox(height: 6),

          // 3. БАЛАНС ТА PNL (Стиль CryptoRank)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                flex: 6,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        _hideBalance ? '••••••' : '\$ ${_formatCurrency(displayBalance)}',
                        maxLines: 1,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 30,
                          fontWeight: FontWeight.bold,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ),
                    if (displayDate != null) ...[
                      const SizedBox(height: 3),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.touch_app_rounded, color: AppColors.accent, size: 12),
                          const SizedBox(width: 4),
                          Text(
                            _formatFullDate(displayDate),
                            style: const TextStyle(
                              color: AppColors.accentLight,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 5,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerRight,
                      child: Text(
                        _hideBalance
                            ? '••••'
                            : '${isPnlPositive ? '+' : '-'}\$ ${_formatCurrency(displayPnl.abs())}',
                        maxLines: 1,
                        style: TextStyle(
                          color: chartColor,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 2),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerRight,
                      child: Text(
                        _hideBalance
                            ? '••••'
                            : '${isPnlPositive ? '+' : '-'}${displayPnlPct.abs().toStringAsFixed(2)}%',
                        maxLines: 1,
                        style: TextStyle(
                          color: chartColor,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // 4. ГРАФІК CRYPTORANK З ГРАДІЄНТОМ ТА ТАЧ-ІНСПЕКТОРОМ
          SizedBox(
            height: 160,
            child: points.isEmpty
                ? const Center(
                    child: Text('Завантаження графіка...', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                  )
                : LineChart(
                    _buildChartData(points, chartColor),
                    duration: const Duration(milliseconds: 300),
                  ),
          ),
          const SizedBox(height: 16),

          // 5. СЕЛЕКТОР ТАЙМФРЕЙМІВ: [ 24 год | 7 днів | 30 днів | 90 днів | 1 рік | Всі ]
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildPeriodChip(TimePeriod.h24, '24 ч.'),
                const SizedBox(width: 6),
                _buildPeriodChip(TimePeriod.d7, '7 д.'),
                const SizedBox(width: 6),
                _buildPeriodChip(TimePeriod.d30, '30 д.'),
                const SizedBox(width: 6),
                _buildPeriodChip(TimePeriod.d90, '3 м.'),
                const SizedBox(width: 6),
                _buildPeriodChip(TimePeriod.y1, '1 г.'),
                const SizedBox(width: 6),
                _buildPeriodChip(TimePeriod.all, 'Все'),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // 6. ПЕРЕМИКАЧ МЕТРИКИ: [ Баланс | Прибуток | % Зміни ]
          Row(
            children: [
              _buildMetricChip(ChartMetricType.balance, 'Баланс'),
              const SizedBox(width: 8),
              _buildMetricChip(ChartMetricType.pnl, 'Прибуток'),
              const SizedBox(width: 8),
              _buildMetricChip(ChartMetricType.percent, '% Зміни'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCategorySegment({
    required PortfolioChartCategory category,
    required IconData icon,
    required String label,
  }) {
    final isSelected = _category == category;
    return GestureDetector(
      onTap: () {
        setState(() {
          _category = category;
          _touchedIndex = null;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.accent : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 14,
              color: isSelected ? Colors.white : AppColors.textSecondary,
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : AppColors.textSecondary,
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPeriodChip(TimePeriod period, String label) {
    final isSelected = widget.selectedPeriod == period;
    return InkWell(
      onTap: () {
        setState(() => _touchedIndex = null);
        widget.onPeriodChanged(period);
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.accent : AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? AppColors.accent : AppColors.border,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : AppColors.textSecondary,
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildMetricChip(ChartMetricType metric, String label) {
    final isSelected = _metric == metric;
    return InkWell(
      onTap: () {
        setState(() {
          _metric = metric;
          _touchedIndex = null;
        });
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.surfaceVariant : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? AppColors.accent.withOpacity(0.5) : AppColors.border,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? AppColors.accentLight : AppColors.textSecondary,
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  LineChartData _buildChartData(List<ChartPoint> points, Color chartColor) {
    final List<FlSpot> spots = [];
    double minY = double.infinity;
    double maxY = -double.infinity;

    for (int i = 0; i < points.length; i++) {
      final val = _getPointValue(points[i]);
      spots.add(FlSpot(i.toDouble(), val));
      if (val < minY) minY = val;
      if (val > maxY) maxY = val;
    }

    // Відступи зверху та знизу для гарного відображення графіка
    if (minY == maxY) {
      if (minY == 0) {
        minY = -1;
        maxY = 1;
      } else {
        minY = minY * 0.95;
        maxY = maxY * 1.05;
      }
    }
    final padding = (maxY - minY) * 0.1;
    minY = minY - padding;
    maxY = maxY + padding;

    return LineChartData(
      gridData: const FlGridData(show: false),
      titlesData: const FlTitlesData(show: false),
      borderData: FlBorderData(show: false),
      minX: 0,
      maxX: (points.length - 1).toDouble(),
      minY: minY,
      maxY: maxY,
      lineTouchData: LineTouchData(
        enabled: true,
        handleBuiltInTouches: true,
        touchTooltipData: LineTouchTooltipData(
          getTooltipColor: (_) => AppColors.surfaceVariant,
          tooltipRoundedRadius: 8,
          tooltipPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          getTooltipItems: (touchedSpots) {
            return touchedSpots.map((spot) {
              final idx = spot.x.toInt();
              if (idx < 0 || idx >= points.length) return null;
              final pt = points[idx];
              final isPositive = pt.pnl >= 0;
              final sign = isPositive ? '+' : '-';

              return LineTooltipItem(
                '\$ ${_formatCurrency(pt.balance)}\n',
                const TextStyle(color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.bold),
                children: [
                  TextSpan(
                    text: '$sign\$${_formatCurrency(pt.pnl.abs())} ($sign${pt.pnlPct.abs().toStringAsFixed(2)}%)\n',
                    style: TextStyle(
                      color: isPositive ? AppColors.greenTask : AppColors.redTask,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  TextSpan(
                    text: _formatFullDate(pt.timestamp),
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 10),
                  ),
                ],
              );
            }).toList();
          },
        ),
        touchCallback: (event, touchResponse) {
          if (event is FlTapUpEvent ||
              event is FlPanEndEvent ||
              event is FlPointerExitEvent ||
              event is FlTapCancelEvent ||
              event is FlPanCancelEvent) {
            if (_touchedIndex != null) {
              setState(() => _touchedIndex = null);
            }
          } else if (touchResponse != null &&
              touchResponse.lineBarSpots != null &&
              touchResponse.lineBarSpots!.isNotEmpty) {
            final spotIdx = touchResponse.lineBarSpots!.first.spotIndex;
            if (spotIdx >= 0 && spotIdx < points.length && _touchedIndex != spotIdx) {
              setState(() => _touchedIndex = spotIdx);
            }
          } else {
            if (_touchedIndex != null) {
              setState(() => _touchedIndex = null);
            }
          }
        },
      ),
      lineBarsData: [
        LineChartBarData(
          spots: spots,
          isCurved: true,
          curveSmoothness: 0.25,
          color: chartColor,
          barWidth: 2.5,
          isStrokeCapRound: true,
          dotData: const FlDotData(show: false),
          belowBarData: BarAreaData(
            show: true,
            gradient: LinearGradient(
              colors: [
                chartColor.withOpacity(0.35),
                chartColor.withOpacity(0.0),
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
        ),
      ],
    );
  }

  String _formatCurrency(double val) {
    final absVal = val.abs();
    final sign = val < 0 ? '-' : '';
    if (absVal >= 1000) {
      return '$sign${NumberFormat('#,##0.00', 'en_US').format(absVal)}';
    } else if (absVal >= 1) {
      return '$sign${absVal.toStringAsFixed(2)}';
    } else if (absVal > 0) {
      return '$sign${absVal.toStringAsFixed(4)}';
    } else {
      return '0.00';
    }
  }

  String _formatFullDate(DateTime dt) {
    return DateFormat('dd.MM.yyyy HH:mm').format(dt);
  }
}
