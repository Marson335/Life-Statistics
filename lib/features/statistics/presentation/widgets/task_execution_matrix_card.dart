import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/models/models.dart';
import '../../../tasks/presentation/screens/today_screen.dart' show taskRepositoryProvider;
import '../screens/statistics_screen.dart' show statPeriodProvider, StatPeriod;

enum MatrixPeriod { week, month, year }

class MatrixBarData {
  final String label;
  final String? subLabel;
  final String fullLabel;
  final int completed;
  final int uncompleted;
  final bool isCurrent;
  final DateTime date;

  const MatrixBarData({
    required this.label,
    this.subLabel,
    required this.fullLabel,
    required this.completed,
    required this.uncompleted,
    required this.isCurrent,
    required this.date,
  });

  int get total => completed + uncompleted;
  double get completionRate => total > 0 ? (completed / total) * 100 : 0.0;
}

class TaskExecutionMatrixCard extends ConsumerStatefulWidget {
  const TaskExecutionMatrixCard({super.key});

  @override
  ConsumerState<TaskExecutionMatrixCard> createState() =>
      _TaskExecutionMatrixCardState();
}

class _TaskExecutionMatrixCardState
    extends ConsumerState<TaskExecutionMatrixCard> {
  MatrixPeriod _period = MatrixPeriod.week;
  int _offset = 0;
  int? _selectedBarIndex;

  @override
  void initState() {
    super.initState();
    // Synchronize initial period with statPeriodProvider
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final globalPeriod = ref.read(statPeriodProvider);
      _syncFromGlobalPeriod(globalPeriod);
    });
  }

  void _syncFromGlobalPeriod(StatPeriod globalPeriod) {
    MatrixPeriod mapped;
    switch (globalPeriod) {
      case StatPeriod.day:
      case StatPeriod.week:
        mapped = MatrixPeriod.week;
        break;
      case StatPeriod.month:
        mapped = MatrixPeriod.month;
        break;
      case StatPeriod.year:
        mapped = MatrixPeriod.year;
        break;
    }
    if (_period != mapped) {
      setState(() {
        _period = mapped;
        _offset = 0;
        _selectedBarIndex = null;
      });
    }
  }



  String _monthNameFull(int month) {
    const months = [
      'Січень',
      'Лютий',
      'Березень',
      'Квітень',
      'Травень',
      'Червень',
      'Липень',
      'Серпень',
      'Вересень',
      'Жовтень',
      'Листопад',
      'Грудень'
    ];
    return months[month - 1];
  }

  String _monthNameGenitive(int month) {
    const months = [
      'січня',
      'лютого',
      'березня',
      'квітня',
      'травня',
      'червня',
      'липня',
      'серпня',
      'вересня',
      'жовтня',
      'листопада',
      'грудня'
    ];
    return months[month - 1];
  }

  String _dayNameUkrainian(int weekday) {
    const days = [
      'Понеділок',
      'Вівторок',
      'Середа',
      'Четвер',
      "П'ятниця",
      'Субота',
      'Неділя'
    ];
    return days[weekday - 1];
  }

  ({DateTime start, DateTime end, String title}) _calculateRange() {
    final now = DateTime.now();

    switch (_period) {
      case MatrixPeriod.week:
        final targetDate = now.add(Duration(days: _offset * 7));
        final normalized =
            DateTime(targetDate.year, targetDate.month, targetDate.day);
        final monday =
            normalized.subtract(Duration(days: normalized.weekday - 1));
        final sunday = monday.add(const Duration(days: 6));
        final start = DateTime(monday.year, monday.month, monday.day);
        final end = start.add(const Duration(days: 7));

        final title = monday.month == sunday.month
            ? '${monday.day} – ${sunday.day} ${_monthNameGenitive(monday.month)} ${sunday.year}'
                .toUpperCase()
            : '${monday.day} ${_monthNameGenitive(monday.month)} – ${sunday.day} ${_monthNameGenitive(sunday.month)} ${sunday.year}'
                .toUpperCase();

        return (start: start, end: end, title: title);

      case MatrixPeriod.month:
        int targetYear = now.year;
        int targetMonth = now.month + _offset;
        while (targetMonth > 12) {
          targetMonth -= 12;
          targetYear += 1;
        }
        while (targetMonth < 1) {
          targetMonth += 12;
          targetYear -= 1;
        }

        final start = DateTime(targetYear, targetMonth, 1);
        final end = DateTime(targetYear, targetMonth + 1, 1);
        final title =
            '${_monthNameFull(targetMonth)} $targetYear'.toUpperCase();

        return (start: start, end: end, title: title);

      case MatrixPeriod.year:
        final targetYear = now.year + _offset;
        final start = DateTime(targetYear, 1, 1);
        final end = DateTime(targetYear + 1, 1, 1);
        final title = '$targetYear РІК';

        return (start: start, end: end, title: title);
    }
  }

  List<MatrixBarData> _generateBars(List<Task> allTasks, DateTime start) {
    final now = DateTime.now();
    final checkableTasks = allTasks.where((t) => t.hasCheckbox).toList();

    switch (_period) {
      case MatrixPeriod.week:
        const labels = ['ПН', 'ВТ', 'СР', 'ЧТ', 'ПТ', 'СБ', 'НД'];
        return List.generate(7, (i) {
          final day = start.add(Duration(days: i));
          final tasksInDay = checkableTasks
              .where((t) =>
                  t.date.year == day.year &&
                  t.date.month == day.month &&
                  t.date.day == day.day)
              .toList();

          final completed = tasksInDay.where((t) => t.isCompleted).length;
          final uncompleted = tasksInDay.where((t) => !t.isCompleted).length;
          final isCurrent = day.year == now.year &&
              day.month == now.month &&
              day.day == now.day;

          return MatrixBarData(
            label: labels[i],
            fullLabel:
                '${_dayNameUkrainian(day.weekday)}, ${day.day} ${_monthNameGenitive(day.month)}',
            completed: completed,
            uncompleted: uncompleted,
            isCurrent: isCurrent,
            date: day,
          );
        });

      case MatrixPeriod.month:
        final daysInMonth = DateTime(start.year, start.month + 1, 0).day;
        final intervals = <({int startDay, int endDay, String label})>[
          (startDay: 1, endDay: 7, label: 'Т1'),
          (startDay: 8, endDay: 14, label: 'Т2'),
          (startDay: 15, endDay: 21, label: 'Т3'),
          (startDay: 22, endDay: 28, label: 'Т4'),
          if (daysInMonth > 28)
            (startDay: 29, endDay: daysInMonth, label: 'Т5'),
        ];

        return intervals.map((interval) {
          final tasksInWeek = checkableTasks
              .where((t) =>
                  t.date.year == start.year &&
                  t.date.month == start.month &&
                  t.date.day >= interval.startDay &&
                  t.date.day <= interval.endDay)
              .toList();

          final completed = tasksInWeek.where((t) => t.isCompleted).length;
          final uncompleted = tasksInWeek.where((t) => !t.isCompleted).length;
          final isCurrent = now.year == start.year &&
              now.month == start.month &&
              now.day >= interval.startDay &&
              now.day <= interval.endDay;

          return MatrixBarData(
            label: interval.label,
            subLabel: '${interval.startDay}–${interval.endDay}',
            fullLabel:
                'Тиждень ${interval.label.substring(1)} (${interval.startDay}–${interval.endDay} ${_monthNameGenitive(start.month)})',
            completed: completed,
            uncompleted: uncompleted,
            isCurrent: isCurrent,
            date: DateTime(start.year, start.month, interval.startDay),
          );
        }).toList();

      case MatrixPeriod.year:
        const labels = [
          'СІЧ',
          'ЛЮТ',
          'БЕР',
          'КВІ',
          'ТРА',
          'ЧЕР',
          'ЛИП',
          'СЕР',
          'ВЕР',
          'ЖОВ',
          'ЛИС',
          'ГРУ'
        ];

        return List.generate(12, (i) {
          final month = i + 1;
          final tasksInMonth = checkableTasks
              .where((t) =>
                  t.date.year == start.year && t.date.month == month)
              .toList();

          final completed = tasksInMonth.where((t) => t.isCompleted).length;
          final uncompleted =
              tasksInMonth.where((t) => !t.isCompleted).length;
          final isCurrent = now.year == start.year && now.month == month;

          return MatrixBarData(
            label: labels[i],
            fullLabel: '${_monthNameFull(month)} ${start.year}',
            completed: completed,
            uncompleted: uncompleted,
            isCurrent: isCurrent,
            date: DateTime(start.year, month, 1),
          );
        });
    }
  }

  String _periodHeaderSubtitle() {
    switch (_period) {
      case MatrixPeriod.week:
        return 'ТИЖДЕНЬ';
      case MatrixPeriod.month:
        return 'МІСЯЦЬ';
      case MatrixPeriod.year:
        return 'РІК';
    }
  }

  @override
  Widget build(BuildContext context) {
    // Listen for global period changes to sync smoothly
    ref.listen<StatPeriod>(statPeriodProvider, (prev, next) {
      if (prev != next) {
        _syncFromGlobalPeriod(next);
      }
    });

    final repo = ref.watch(taskRepositoryProvider);
    final range = _calculateRange();

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(120),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: StreamBuilder<List<Task>>(
          stream: repo.getTasksForDateRange(range.start, range.end),
          builder: (context, snapshot) {
            final tasks = snapshot.data ?? [];
            final bars = _generateBars(tasks, range.start);

            final totalCompleted =
                bars.fold<int>(0, (sum, b) => sum + b.completed);
            final totalUncompleted =
                bars.fold<int>(0, (sum, b) => sum + b.uncompleted);
            final totalTasks = totalCompleted + totalUncompleted;

            final maxBarTasks = bars.fold<int>(
              1,
              (maxVal, b) => math.max(maxVal, b.total),
            );

            // Default selected bar to current (today/this week/this month) if not selected
            int? activeIndex = _selectedBarIndex;
            if (activeIndex != null && activeIndex >= bars.length) {
              activeIndex = null;
            }
            if (activeIndex == null) {
              final currentIndex = bars.indexWhere((b) => b.isCurrent);
              if (currentIndex != -1) {
                activeIndex = currentIndex;
              }
            }

            final activeBar = (activeIndex != null && activeIndex < bars.length)
                ? bars[activeIndex]
                : null;

            return Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 1. Matrix Header (Athletic Gym style matching reference)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          'МАТРИЦЯ ВИКОНАННЯ // ${_periodHeaderSubtitle()}',
                          style: GoogleFonts.chakraPetch(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.1,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'СУМА: $totalCompleted',
                        style: GoogleFonts.chakraPetch(
                          color: AppColors.accent,
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // 2. Date Range Navigation Row (< 13 – 19 ЖОВТНЯ 2026 >)
                  _buildDateNavigation(range.title),

                  const SizedBox(height: 10),

                  // 3. Legend row (Style 2: Iron & Steel - Wrapped to guarantee 0 overflow)
                  _buildLegend(),

                  const SizedBox(height: 14),

                  // 4. Matrix Bar Chart (Flat rectangular solid gym pillars - 0 OVERFLOW)
                  _buildBarChart(bars, maxBarTasks, activeIndex),

                  const SizedBox(height: 14),

                  // 5. Selected Bar Info HUD (3-column layout guaranteed 0 overflow)
                  if (activeBar != null) _buildDetailHud(activeBar, totalTasks),
                ],
              ),
            );
          },
        ),
      ),
    );
  }



  Widget _buildDateNavigation(String title) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left_rounded,
                color: AppColors.accent, size: 24),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            onPressed: () {
              setState(() {
                _offset--;
                _selectedBarIndex = null;
              });
            },
          ),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Flexible(
                  child: Text(
                    title,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.chakraPetch(
                      color: AppColors.textPrimary,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.7,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (_offset != 0) ...[
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () => setState(() {
                      _offset = 0;
                      _selectedBarIndex = null;
                    }),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.accent.withAlpha(35),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                            color: AppColors.accent.withAlpha(140), width: 1.2),
                      ),
                      child: Text(
                        'СЬОГОДНІ',
                        style: GoogleFonts.chakraPetch(
                          color: AppColors.accent,
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right_rounded,
                color: AppColors.accent, size: 24),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            onPressed: () {
              setState(() {
                _offset++;
                _selectedBarIndex = null;
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildLegend() {
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 12,
      runSpacing: 4,
      children: [
        _buildLegendItem('Виконано', AppColors.accent),
        _buildLegendItem('Залишилось', const Color(0xFF4A5263)),
        _buildLegendItem('Активний', AppColors.accent, isOutline: true),
      ],
    );
  }

  Widget _buildLegendItem(String text, Color color, {bool isOutline = false}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: isOutline ? Colors.transparent : color,
            borderRadius: BorderRadius.circular(1),
            border: isOutline ? Border.all(color: color, width: 1.5) : null,
          ),
        ),
        const SizedBox(width: 5),
        Text(
          text,
          style: GoogleFonts.chakraPetch(
            color: const Color(0xFF9DA4B0),
            fontSize: 10,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.3,
          ),
        ),
      ],
    );
  }

  Widget _buildBarChart(
      List<MatrixBarData> bars, int maxBarTasks, int? activeIndex) {
    const double chartHeight = 175.0;

    return Container(
      height: chartHeight,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF0D0F14), // Deep cast-iron inner cavity
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border, width: 1.2),
      ),
      child: Stack(
        children: [
          // Background grid lines (Athletic guide lines)
          Positioned.fill(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: List.generate(
                3,
                (_) => Container(
                  height: 1,
                  color: AppColors.border.withAlpha(70),
                ),
              ),
            ),
          ),

          // Bar Columns - 100% Guaranteed 0 Overflow
          Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: bars.asMap().entries.map((entry) {
              final index = entry.key;
              final bar = entry.value;
              final isSelected = activeIndex == index;

              return Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    setState(() {
                      _selectedBarIndex = index;
                    });
                  },
                  child: _buildSingleBarColumn(
                    bar: bar,
                    maxBarTasks: maxBarTasks,
                    isSelected: isSelected,
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildSingleBarColumn({
    required MatrixBarData bar,
    required int maxBarTasks,
    required bool isSelected,
  }) {
    // Overall height factor based on scheduled tasks
    final double totalRatio =
        maxBarTasks > 0 ? (bar.total / maxBarTasks).clamp(0.08, 1.0) : 0.08;

    final bool isHighlighted = isSelected || bar.isCurrent;

    // Pillar width
    final double pillarWidth = _period == MatrixPeriod.year
        ? 16.0
        : (_period == MatrixPeriod.month ? 36.0 : 32.0);

    // Value display on top of bar (e.g. 14/16, 4/16, 0/16)
    String topLabel = '${bar.completed}';
    if (bar.uncompleted > 0) {
      topLabel = '${bar.completed}/${bar.total}';
    }

    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        // Top value label
        SizedBox(
          height: 18,
          child: Center(
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 200),
              opacity: bar.total > 0 ? 1.0 : 0.4,
              child: Text(
                bar.total > 0 ? topLabel : '0',
                style: GoogleFonts.chakraPetch(
                  color: isHighlighted
                      ? AppColors.accent
                      : (bar.completed > 0 ? Colors.white : const Color(0xFF64748B)),
                  fontSize: _period == MatrixPeriod.year ? 9 : 11,
                  fontWeight: isHighlighted ? FontWeight.w900 : FontWeight.w700,
                  letterSpacing: 0.3,
                ),
                maxLines: 1,
                overflow: TextOverflow.clip,
              ),
            ),
          ),
        ),

        const SizedBox(height: 4),

        // The Flat Rectangular Solid Gym Pillar (Fills yellow proportionally to completed tasks!)
        Expanded(
          child: Align(
            alignment: Alignment.bottomCenter,
            child: FractionallySizedBox(
              heightFactor: bar.total > 0 ? totalRatio.clamp(0.08, 1.0) : 0.05,
              widthFactor: null,
              child: Container(
                width: pillarWidth,
                decoration: BoxDecoration(
                  color: const Color(0xFF262A36), // Deep steel background
                  borderRadius: BorderRadius.circular(2),
                  border: Border.all(
                    color: isHighlighted ? AppColors.accent : const Color(0xFF383E4E),
                    width: isHighlighted ? 1.8 : 1.0,
                  ),
                  boxShadow: isHighlighted
                      ? [
                          BoxShadow(
                            color: AppColors.accent.withAlpha(90),
                            blurRadius: 8,
                            spreadRadius: 0,
                          ),
                        ]
                      : null,
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(1),
                  child: Column(
                    children: [
                      // Top segment: uncompleted tasks (Steel gray)
                      if (bar.total > 0 && bar.uncompleted > 0)
                        Expanded(
                          flex: bar.uncompleted,
                          child: Container(
                            color: const Color(0xFF4A5263),
                          ),
                        ),
                      // Bottom segment: completed tasks (Solid Neon Lime / Yellow #D4FF00!)
                      if (bar.completed > 0)
                        Expanded(
                          flex: bar.completed,
                          child: Container(
                            color: AppColors.accent,
                          ),
                        ),
                      // If bar.total == 0
                      if (bar.total == 0)
                        Expanded(
                          child: Container(
                            color: const Color(0xFF1E212B),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),

        const SizedBox(height: 6),

        // Bottom Label (ПН, ВТ... or Т1, Т2... or СІЧ, ЛЮТ...)
        Text(
          bar.label,
          style: GoogleFonts.chakraPetch(
            color: isHighlighted
                ? AppColors.accent
                : (isSelected ? Colors.white : const Color(0xFF9DA4B0)),
            fontSize: _period == MatrixPeriod.year ? 9 : 11,
            fontWeight: isHighlighted ? FontWeight.w900 : FontWeight.w600,
            letterSpacing: 0.4,
          ),
        ),

        // Optional sub-label for Month (1-7, 8-14)
        if (bar.subLabel != null)
          Text(
            bar.subLabel!,
            style: GoogleFonts.chakraPetch(
              color: isHighlighted
                  ? AppColors.accent.withAlpha(200)
                  : const Color(0xFF64748B),
              fontSize: 8,
              fontWeight: FontWeight.w500,
            ),
          )
        else
          const SizedBox(height: 2),
      ],
    );
  }

  Widget _buildDetailHud(MatrixBarData bar, int overallTotal) {
    final bool isHighlighted = bar.isCurrent || (_selectedBarIndex != null && _selectedBarIndex != -1);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isHighlighted
              ? AppColors.accent.withAlpha(160)
              : AppColors.border,
          width: 1.2,
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
                    Icon(
                      Icons.calendar_today_rounded,
                      size: 13,
                      color: bar.isCurrent ? AppColors.accent : const Color(0xFF9DA4B0),
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        bar.fullLabel.toUpperCase(),
                        style: GoogleFonts.chakraPetch(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w700,
                          fontSize: 11,
                          letterSpacing: 0.5,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              if (bar.isCurrent)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    color: AppColors.accent.withAlpha(35),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                        color: AppColors.accent.withAlpha(140), width: 1.0),
                  ),
                  child: Text(
                    'СЬОГОДНІ',
                    style: GoogleFonts.chakraPetch(
                      color: AppColors.accent,
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _buildHudStat(
                  label: 'ВИКОНАНО',
                  value: '${bar.completed}',
                  color: AppColors.accent,
                  icon: Icons.check_circle_rounded,
                ),
              ),
              Expanded(
                child: _buildHudStat(
                  label: 'ЗАЛИШИЛОСЬ',
                  value: '${bar.uncompleted}',
                  color: const Color(0xFF9DA4B0),
                  icon: Icons.radio_button_unchecked_rounded,
                ),
              ),
              Expanded(
                child: _buildHudStat(
                  label: 'РЕЗУЛЬТАТ',
                  value: bar.total > 0
                      ? '${bar.completionRate.toStringAsFixed(0)}%'
                      : '0%',
                  color: bar.completionRate >= 100
                      ? AppColors.accent
                      : Colors.white,
                  icon: Icons.speed_rounded,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHudStat({
    required String label,
    required String value,
    required Color color,
    required IconData icon,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 12),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                label,
                style: GoogleFonts.chakraPetch(
                  color: const Color(0xFF9DA4B0),
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.4,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: 3),
        Text(
          value,
          style: GoogleFonts.chakraPetch(
            color: color,
            fontSize: 14,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }
}
