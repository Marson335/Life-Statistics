import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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

  void _onPeriodChanged(MatrixPeriod newPeriod) {
    setState(() {
      _period = newPeriod;
      _offset = 0;
      _selectedBarIndex = null;
    });

    // Optionally update global period to keep screen cohesive
    switch (newPeriod) {
      case MatrixPeriod.week:
        ref.read(statPeriodProvider.notifier).state = StatPeriod.week;
        break;
      case MatrixPeriod.month:
        ref.read(statPeriodProvider.notifier).state = StatPeriod.month;
        break;
      case MatrixPeriod.year:
        ref.read(statPeriodProvider.notifier).state = StatPeriod.year;
        break;
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
        return 'WEEK';
      case MatrixPeriod.month:
        return 'MONTH';
      case MatrixPeriod.year:
        return 'YEAR';
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
        color: const Color(0xFF0A101D),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF16253B), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(90),
            blurRadius: 18,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
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
                  // 1. Matrix Header (Cyberpunk Sci-Fi style matching screenshot)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          'TASK EXECUTION MATRIX // ${_periodHeaderSubtitle()}',
                          style: const TextStyle(
                            color: Color(0xFF38BDF8),
                            fontFamily: 'monospace',
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.1,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'SUM: $totalCompleted',
                        style: const TextStyle(
                          color: Color(0xFFFFB300),
                          fontFamily: 'monospace',
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // 2. Period Switcher Buttons (Тиждень, Місяць, Рік)
                  _buildPeriodPills(),

                  const SizedBox(height: 12),

                  // 3. Date Range Navigation Row (< 13-19 ЖОВТНЯ 2026 >)
                  _buildDateNavigation(range.title),

                  const SizedBox(height: 8),

                  // 4. Legend row (Виконано vs Не виконано vs Поточний)
                  _buildLegend(),

                  const SizedBox(height: 16),

                  // 5. Matrix Bar Chart
                  _buildBarChart(bars, maxBarTasks, activeIndex),

                  const SizedBox(height: 16),

                  // 6. Selected Bar Info HUD
                  if (activeBar != null) _buildDetailHud(activeBar, totalTasks),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildPeriodPills() {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF1E293B)),
      ),
      child: Row(
        children: [
          _buildPillTab('ТИЖДЕНЬ', MatrixPeriod.week),
          _buildPillTab('МІСЯЦЬ', MatrixPeriod.month),
          _buildPillTab('РІК', MatrixPeriod.year),
        ],
      ),
    );
  }

  Widget _buildPillTab(String label, MatrixPeriod period) {
    final isSelected = _period == period;
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _onPeriodChanged(period),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 7),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF0284C7) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: const Color(0xFF0284C7).withAlpha(90),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isSelected ? Colors.white : const Color(0xFF94A3B8),
              fontSize: 11,
              fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
              letterSpacing: 0.8,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDateNavigation(String title) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left_rounded,
                color: Color(0xFF38BDF8), size: 24),
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
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.6,
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
                        color: const Color(0xFF38BDF8).withAlpha(40),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                            color: const Color(0xFF38BDF8).withAlpha(120)),
                      ),
                      child: const Text(
                        'Сьогодні',
                        style: TextStyle(
                          color: Color(0xFF38BDF8),
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
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
                color: Color(0xFF38BDF8), size: 24),
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
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildLegendItem('Виконано', const Color(0xFF29B6F6)),
        const SizedBox(width: 14),
        _buildLegendItem('Не виконано', const Color(0xFFFF5252)),
        const SizedBox(width: 14),
        _buildLegendItem('Поточний', const Color(0xFFFF6D00)),
      ],
    );
  }

  Widget _buildLegendItem(String text, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 5),
        Text(
          text,
          style: const TextStyle(
            color: Color(0xFF94A3B8),
            fontSize: 10,
            fontWeight: FontWeight.w500,
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
      padding: const EdgeInsets.only(top: 8, bottom: 2),
      decoration: BoxDecoration(
        color: const Color(0xFF070B14),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF131D2E)),
      ),
      child: Stack(
        children: [
          // Background grid lines (subtle sci-fi guides)
          Positioned.fill(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: List.generate(
                3,
                (_) => Container(
                  height: 1,
                  color: const Color(0xFF132033).withAlpha(90),
                ),
              ),
            ),
          ),

          // Bar Columns
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
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
                    availableHeight: chartHeight - 48,
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
    required double availableHeight,
  }) {
    // Height factor based on total scheduled tasks
    final double totalRatio =
        maxBarTasks > 0 ? (bar.total / maxBarTasks).clamp(0.0, 1.0) : 0.0;
    final double fullBarHeight =
        (totalRatio * availableHeight).clamp(4.0, availableHeight);

    // Completed vs Uncompleted distribution
    final double completedShare =
        bar.total > 0 ? (bar.completed / bar.total) : 0.0;
    final double completedHeight = fullBarHeight * completedShare;
    final double uncompletedHeight = fullBarHeight - completedHeight;

    // Bar colors matching user image
    final Color completedColor = bar.isCurrent
        ? const Color(0xFFFF6D00) // Orange for current active day/week/month
        : const Color(0xFF29B6F6); // Vibrant Blue for other completed tasks

    const Color uncompletedColor =
        Color(0xFFFF5252); // Coral Red for uncompleted tasks

    // Value display on top of bar
    String topLabel = '${bar.completed}';
    if (bar.uncompleted > 0) {
      topLabel = '${bar.completed}/${bar.total}';
    }

    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        // Top value label (e.g. 4 or 4/5)
        AnimatedOpacity(
          duration: const Duration(milliseconds: 200),
          opacity: bar.total > 0 ? 1.0 : 0.35,
          child: Text(
            bar.total > 0 ? topLabel : '0',
            style: TextStyle(
              color: isSelected
                  ? const Color(0xFFFFB300)
                  : (bar.isCurrent
                      ? const Color(0xFFFF9100)
                      : (bar.total > 0
                          ? Colors.white
                          : const Color(0xFF64748B))),
              fontSize: _period == MatrixPeriod.year ? 9 : 11,
              fontWeight:
                  isSelected || bar.isCurrent ? FontWeight.w900 : FontWeight.w700,
              fontFamily: 'monospace',
            ),
            maxLines: 1,
            overflow: TextOverflow.clip,
          ),
        ),

        const SizedBox(height: 5),

        // The Bar Graphic
        Container(
          width: _period == MatrixPeriod.year
              ? 16
              : (_period == MatrixPeriod.month ? 38 : 30),
          height: bar.total > 0 ? fullBarHeight : 4,
          decoration: BoxDecoration(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: (bar.isCurrent ? completedColor : const Color(0xFF38BDF8))
                          .withAlpha(120),
                      blurRadius: 8,
                      spreadRadius: 1,
                    ),
                  ]
                : null,
          ),
          child: ClipRRect(
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(4)),
            child: bar.total == 0
                ? Container(
                    color: const Color(0xFF1E293B),
                  )
                : Column(
                    children: [
                      // Top segment: Uncompleted tasks
                      if (bar.uncompleted > 0)
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeOutCubic,
                          height: uncompletedHeight,
                          color: uncompletedColor,
                        ),
                      // Bottom segment: Completed tasks
                      if (bar.completed > 0)
                        Expanded(
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeOutCubic,
                            color: completedColor,
                          ),
                        ),
                    ],
                  ),
          ),
        ),

        const SizedBox(height: 6),

        // Bottom Label (ПН, ВТ... or Т1, Т2... or СІЧ, ЛЮТ...)
        Text(
          bar.label,
          style: TextStyle(
            color: bar.isCurrent
                ? const Color(0xFFFF851B)
                : (isSelected ? Colors.white : const Color(0xFF94A3B8)),
            fontSize: _period == MatrixPeriod.year ? 9 : 11,
            fontWeight:
                bar.isCurrent || isSelected ? FontWeight.w800 : FontWeight.w600,
          ),
        ),

        // Optional sub-label for Month (1-7, 8-14)
        if (bar.subLabel != null)
          Text(
            bar.subLabel!,
            style: TextStyle(
              color: bar.isCurrent
                  ? const Color(0xFFFF851B).withAlpha(180)
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: bar.isCurrent
              ? const Color(0xFFFF6D00).withAlpha(120)
              : const Color(0xFF0284C7).withAlpha(100),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.event_note_rounded,
                    size: 15,
                    color: bar.isCurrent
                        ? const Color(0xFFFF851B)
                        : const Color(0xFF38BDF8),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    bar.fullLabel,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              if (bar.isCurrent)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF6D00).withAlpha(40),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                        color: const Color(0xFFFF6D00).withAlpha(140)),
                  ),
                  child: const Text(
                    'Поточний',
                    style: TextStyle(
                      color: Color(0xFFFF851B),
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildHudStat(
                label: 'Виконано',
                value: '${bar.completed}',
                color: const Color(0xFF29B6F6),
                icon: Icons.check_circle_outline_rounded,
              ),
              _buildHudStat(
                label: 'Не виконано',
                value: '${bar.uncompleted}',
                color: const Color(0xFFFF5252),
                icon: Icons.cancel_outlined,
              ),
              _buildHudStat(
                label: 'Успішність',
                value: bar.total > 0
                    ? '${bar.completionRate.toStringAsFixed(0)}%'
                    : '—',
                color: const Color(0xFFFFB300),
                icon: Icons.percent_rounded,
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
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 14),
        const SizedBox(width: 4),
        Text(
          '$label: ',
          style: const TextStyle(
            color: Color(0xFF94A3B8),
            fontSize: 11,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 12,
            fontWeight: FontWeight.bold,
            fontFamily: 'monospace',
          ),
        ),
      ],
    );
  }
}
