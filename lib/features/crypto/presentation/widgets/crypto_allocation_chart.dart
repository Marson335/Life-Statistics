import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../../core/theme/app_theme.dart';
import '../../data/models/crypto_models.dart';

class CryptoAllocationChart extends StatefulWidget {
  final List<HoldingItem> holdings;

  const CryptoAllocationChart({super.key, required this.holdings});

  @override
  State<CryptoAllocationChart> createState() => _CryptoAllocationChartState();
}

class _CryptoAllocationChartState extends State<CryptoAllocationChart> {
  int _touchedIndex = -1;

  static const List<Color> _sliceColors = [
    Color(0xFF7C4DFF), // Accent Purple
    Color(0xFF00C896), // Mint Green
    Color(0xFF4D9FFF), // Blue
    Color(0xFFFFD740), // Gold
    Color(0xFFFF5252), // Red
    Color(0xFFFF9100), // Orange
    Color(0xFF00E5FF), // Cyan
    Color(0xFFE040FB), // Magenta
  ];

  @override
  Widget build(BuildContext context) {
    if (widget.holdings.isEmpty) {
      return const SizedBox.shrink();
    }

    final topHoldings = widget.holdings.take(5).toList();
    final otherHoldings = widget.holdings.skip(5).toList();

    double otherShare = 0.0;
    double otherUsd = 0.0;
    for (final h in otherHoldings) {
      otherShare += h.sharePct;
      otherUsd += h.totalUsd;
    }

    final List<PieChartSectionData> sections = [];

    for (int i = 0; i < topHoldings.length; i++) {
      final h = topHoldings[i];
      final isTouched = i == _touchedIndex;
      final radius = isTouched ? 36.0 : 28.0;
      final color = _sliceColors[i % _sliceColors.length];

      sections.add(
        PieChartSectionData(
          color: color,
          value: h.sharePct.clamp(0.1, 100),
          title: '${h.sharePct.toStringAsFixed(1)}%',
          radius: radius,
          titleStyle: TextStyle(
            fontSize: isTouched ? 13 : 11,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      );
    }

    if (otherShare > 0.1) {
      final isTouched = topHoldings.length == _touchedIndex;
      sections.add(
        PieChartSectionData(
          color: const Color(0xFF6E7681),
          value: otherShare.clamp(0.1, 100),
          title: '${otherShare.toStringAsFixed(1)}%',
          radius: isTouched ? 36.0 : 28.0,
          titleStyle: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.pie_chart_rounded, color: AppColors.blueTask, size: 20),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'РОЗПОДІЛ ПОРТФЕЛЮ (ALLOCATION)',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.8,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 180,
            child: PieChart(
              PieChartData(
                pieTouchData: PieTouchData(
                  touchCallback: (FlTouchEvent event, pieTouchResponse) {
                    setState(() {
                      if (!event.isInterestedForInteractions ||
                          pieTouchResponse == null ||
                          pieTouchResponse.touchedSection == null) {
                        _touchedIndex = -1;
                        return;
                      }
                      _touchedIndex = pieTouchResponse.touchedSection!.touchedSectionIndex;
                    });
                  },
                ),
                borderData: FlBorderData(show: false),
                sectionsSpace: 3,
                centerSpaceRadius: 46,
                sections: sections,
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Легенда
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              for (int i = 0; i < topHoldings.length; i++)
                _buildLegendItem(
                  color: _sliceColors[i % _sliceColors.length],
                  label: topHoldings[i].symbol,
                  pct: topHoldings[i].sharePct,
                  usd: topHoldings[i].totalUsd,
                ),
              if (otherShare > 0.1)
                _buildLegendItem(
                  color: const Color(0xFF6E7681),
                  label: 'Інші (${otherHoldings.length})',
                  pct: otherShare,
                  usd: otherUsd,
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem({
    required Color color,
    required String label,
    required double pct,
    required double usd,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          '$label: ${pct.toStringAsFixed(1)}%',
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
