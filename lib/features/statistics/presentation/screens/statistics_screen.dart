import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/models/models.dart';
import '../../../tasks/presentation/screens/today_screen.dart' show taskRepositoryProvider;
import '../../../calories/data/calories_repository.dart';
import '../../../settings/data/settings_repository.dart';
import 'dart:math' as math;

enum StatPeriod { day, week, month, year }

final statPeriodProvider = StateProvider<StatPeriod>((ref) => StatPeriod.week);

final statisticsProvider = StreamProvider.family<Map<String, dynamic>, StatPeriod>((ref, period) {
  final repo = ref.watch(taskRepositoryProvider);
  final now = DateTime.now();
  final startOfDay = DateTime(now.year, now.month, now.day);
  
  DateTime start;
  DateTime end = startOfDay.add(const Duration(days: 1));
  
  switch (period) {
    case StatPeriod.day:
      start = startOfDay;
      break;
    case StatPeriod.week:
      start = startOfDay.subtract(Duration(days: now.weekday - 1));
      break;
    case StatPeriod.month:
      start = DateTime(now.year, now.month, 1);
      break;
    case StatPeriod.year:
      start = DateTime(now.year, 1, 1);
      break;
  }
  
  return repo.watchStatisticsForRange(start, end, isYearly: period == StatPeriod.year);
});

final perfectDaysProvider = StreamProvider.family<int, StatPeriod>((ref, period) {
  final repo = ref.watch(taskRepositoryProvider);
  final now = DateTime.now();
  final startOfDay = DateTime(now.year, now.month, now.day);
  
  DateTime start;
  DateTime end = startOfDay.add(const Duration(days: 1));
  
  switch (period) {
    case StatPeriod.day:
      start = startOfDay;
      break;
    case StatPeriod.week:
      start = startOfDay.subtract(Duration(days: now.weekday - 1));
      break;
    case StatPeriod.month:
      start = DateTime(now.year, now.month, 1);
      break;
    case StatPeriod.year:
      start = DateTime(now.year, 1, 1);
      break;
  }
  return repo.watchPerfectDaysForRange(start, end);
});

final habitStreaksProvider = StreamProvider<Map<String, Map<String, dynamic>>>((ref) {
  final repo = ref.watch(taskRepositoryProvider);
  return repo.watchHabitStreaks();
});

class AnimatedCountText extends StatelessWidget {
  final num count;
  final TextStyle style;
  final String suffix;
  final String prefix;
  final String Function(num)? formatter;

  const AnimatedCountText({
    super.key,
    required this.count,
    required this.style,
    this.suffix = '',
    this.prefix = '',
    this.formatter,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: count.toDouble()),
      duration: const Duration(milliseconds: 1000),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        String displayValue;
        if (formatter != null) {
          displayValue = formatter!(value);
        } else {
          displayValue = count is int ? value.toInt().toString() : value.toStringAsFixed(0);
        }
        return Text('$prefix$displayValue$suffix', style: style);
      },
    );
  }
}
class StatisticsScreen extends ConsumerStatefulWidget {
  const StatisticsScreen({super.key});

  @override
  ConsumerState<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends ConsumerState<StatisticsScreen> {
  bool _isTasksExpanded = true;
  bool _isHabitsExpanded = true;
  bool _isTimeExpanded = true;
  bool _isFinanceExpanded = true;
  bool _isMindsetExpanded = true;
  bool _isCaloriesExpanded = true;

  Widget _buildExpandableSection({
    required String title,
    required IconData icon,
    required Color iconColor,
    required bool isExpanded,
    required VoidCallback onTap,
    required Widget child,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListTile(
            title: Text(title, style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 16)),
            leading: Icon(icon, color: iconColor),
            trailing: Icon(isExpanded ? Icons.expand_less : Icons.expand_more, color: AppColors.textSecondary),
            onTap: onTap,
          ),
          if (isExpanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: child,
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final period = ref.watch(statPeriodProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Статистика',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            _buildPeriodSelector(ref, period),
            const SizedBox(height: 16),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                children: [
                  _buildExpandableSection(
                    title: 'Прогрес задач',
                    icon: Icons.check_circle_outline_rounded,
                    iconColor: AppColors.greenTask,
                    isExpanded: _isTasksExpanded,
                    onTap: () => setState(() => _isTasksExpanded = !_isTasksExpanded),
                    child: Column(
                      children: [
                        _buildPieChartSection(ref, period),
                        const SizedBox(height: 24),
                        _buildPerfectDaysSection(ref, period),
                      ],
                    ),
                  ),
                  _buildExpandableSection(
                    title: 'Зал слави звичок',
                    icon: Icons.emoji_events_rounded,
                    iconColor: Colors.orange,
                    isExpanded: _isHabitsExpanded,
                    onTap: () => setState(() => _isHabitsExpanded = !_isHabitsExpanded),
                    child: const _HabitHallOfFame(),
                  ),
                  _buildExpandableSection(
                    title: 'Час виконання',
                    icon: Icons.timer_rounded,
                    iconColor: AppColors.blueTask,
                    isExpanded: _isTimeExpanded,
                    onTap: () => setState(() => _isTimeExpanded = !_isTimeExpanded),
                    child: _buildTimeAnalyticsSection(ref, period),
                  ),
                  _buildExpandableSection(
                    title: 'Фінанси',
                    icon: Icons.account_balance_wallet_rounded,
                    iconColor: AppColors.yellowTask,
                    isExpanded: _isFinanceExpanded,
                    onTap: () => setState(() => _isFinanceExpanded = !_isFinanceExpanded),
                    child: _buildFinancialTrackerSection(ref, period),
                  ),
                  _buildExpandableSection(
                    title: 'Ментал (Успіх)',
                    icon: Icons.self_improvement_rounded,
                    iconColor: AppColors.accent,
                    isExpanded: _isMindsetExpanded,
                    onTap: () => setState(() => _isMindsetExpanded = !_isMindsetExpanded),
                    child: _buildSuccessBalanceSection(ref, period),
                  ),
                  _buildExpandableSection(
                    title: 'Калорії та Нутрієнти',
                    icon: Icons.local_fire_department_rounded,
                    iconColor: Colors.redAccent,
                    isExpanded: _isCaloriesExpanded,
                    onTap: () => setState(() => _isCaloriesExpanded = !_isCaloriesExpanded),
                    child: _buildCaloriesAnalyticsSection(ref, period),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPeriodSelector(WidgetRef ref, StatPeriod currentPeriod) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            _buildPeriodTab(ref, 'День', StatPeriod.day, currentPeriod),
            _buildPeriodTab(ref, 'Тиждень', StatPeriod.week, currentPeriod),
            _buildPeriodTab(ref, 'Місяць', StatPeriod.month, currentPeriod),
            _buildPeriodTab(ref, 'Рік', StatPeriod.year, currentPeriod),
          ],
        ),
      ),
    );
  }

  Widget _buildPeriodTab(WidgetRef ref, String label, StatPeriod period, StatPeriod currentPeriod) {
    final isSelected = currentPeriod == period;
    return Expanded(
      child: GestureDetector(
        onTap: () => ref.read(statPeriodProvider.notifier).state = period,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.accent : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isSelected ? Colors.white : AppColors.textSecondary,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPieChartSection(WidgetRef ref, StatPeriod period) {
    final statsAsync = ref.watch(statisticsProvider(period));

    return statsAsync.when(
      data: (stats) {
        final int total = stats['total'] ?? 0;
        final int completed = stats['completed'] ?? 0;
        final int uncompleted = total - completed;

        if (total == 0) {
          return _buildEmptyCard('Немає задач за цей період');
        }

        final double completePercent = total > 0 ? (completed / total) * 100 : 0;
        
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Прогрес задач',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                height: 200,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    PieChart(
                      swapAnimationDuration: const Duration(milliseconds: 1000),
                      swapAnimationCurve: Curves.easeOutCubic,
                      PieChartData(
                        sectionsSpace: 4,
                        centerSpaceRadius: 60,
                        startDegreeOffset: -90,
                        sections: [
                          PieChartSectionData(
                            color: AppColors.accent,
                            value: completed.toDouble(),
                            title: '$completed',
                            radius: 20,
                            titleStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                          PieChartSectionData(
                            color: AppColors.surfaceVariant,
                            value: uncompleted.toDouble(),
                            title: '$uncompleted',
                            radius: 20,
                            titleStyle: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        AnimatedCountText(
                          count: completePercent,
                          suffix: '%',
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Text(
                          'Виконано',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => _buildEmptyCard('Помилка завантаження'),
    );
  }

  Widget _buildPerfectDaysSection(WidgetRef ref, StatPeriod period) {
    final perfectDaysAsync = ref.watch(perfectDaysProvider(period));

    return perfectDaysAsync.when(
      data: (count) {
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.greenTask.withAlpha(30),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.emoji_events_rounded, color: AppColors.greenTask, size: 32),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Ідеальні дні',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 14,
                      ),
                    ),
                    AnimatedCountText(
                      count: count,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (err, stack) => Text("Помилка: $err", style: const TextStyle(color: Colors.red)),
    );
  }


  Widget _buildTimeAnalyticsSection(WidgetRef ref, StatPeriod period) {
    final statsAsync = ref.watch(statisticsProvider(period));

    return statsAsync.when(
      data: (stats) {
        final int totalTime = stats['totalTimeMinutes'] ?? 0;
        final Map<String, int> breakdown = stats['greenTimeBreakdown'] ?? {};

        if (totalTime == 0) return const SizedBox.shrink();



        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Аналітика часу',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Icon(Icons.timer_rounded, color: AppColors.blueTask, size: 28),
                  const SizedBox(width: 12),
                  AnimatedCountText(
                    count: totalTime,
                    formatter: (val) {
                      final h = val.toInt() ~/ 60;
                      final m = val.toInt() % 60;
                      return '${h > 0 ? '$h год ' : ''}$m хв';
                    },
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              if (breakdown.isNotEmpty) ...[
                const SizedBox(height: 20),
                const Text(
                  'Витрачено на звички:',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
                ),
                const SizedBox(height: 12),
                                ...(breakdown.entries.toList()..sort((a, b) => b.value.compareTo(a.value))).map((e) {
                    final h = e.value ~/ 60;
                    final m = e.value % 60;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              e.key,
                              style: const TextStyle(color: AppColors.textPrimary),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(
                            '${h > 0 ? '${h}г ' : ''}${m}хв',
                            style: const TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
              ],
            ],
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (err, stack) => Text("Помилка: $err", style: const TextStyle(color: Colors.red)),
    );
  }

  Widget _buildFinancialTrackerSection(WidgetRef ref, StatPeriod period) {
    final statsAsync = ref.watch(statisticsProvider(period));

    return statsAsync.when(
      data: (stats) {
        final totalExpense = stats['totalExpense'] as double? ?? 0.0;
        final totalIncome = stats['totalIncome'] as double? ?? 0.0;
        final balance = stats['balance'] as double? ?? 0.0;
        
        final expensesBreakdown = stats['expensesBreakdown'] as Map<String, double>? ?? {};
        final incomeBreakdown = stats['incomeBreakdown'] as Map<String, double>? ?? {};
        
        final maxExpense = expensesBreakdown.isEmpty ? 1.0 : expensesBreakdown.values.reduce((a, b) => a > b ? a : b);
        final maxIncome = incomeBreakdown.isEmpty ? 1.0 : incomeBreakdown.values.reduce((a, b) => a > b ? a : b);

        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Фінансовий трекер',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Icon(
                    balance >= 0 ? Icons.account_balance_wallet_rounded : Icons.money_off_rounded,
                    color: balance >= 0 ? AppColors.greenTask : AppColors.redTask,
                    size: 28,
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Баланс', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                      AnimatedCountText(
                        count: balance.abs(),
                        prefix: balance >= 0 ? '+ ' : '- ',
                        suffix: ' грн',
                        style: TextStyle(
                          color: balance >= 0 ? AppColors.greenTask : AppColors.redTask,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              
                              const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.greenTask.withAlpha(20),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.greenTask.withAlpha(50)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Прибуток', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                            const SizedBox(height: 4),
                            Text('+${totalIncome.toStringAsFixed(0)} грн', style: const TextStyle(color: AppColors.greenTask, fontWeight: FontWeight.bold, fontSize: 16)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.redTask.withAlpha(20),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.redTask.withAlpha(50)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Витрати', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                            const SizedBox(height: 4),
                            Text('-${totalExpense.toStringAsFixed(0)} грн', style: const TextStyle(color: AppColors.redTask, fontWeight: FontWeight.bold, fontSize: 16)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                
                if (incomeBreakdown.isNotEmpty) ...[
                const SizedBox(height: 24),
                const Text('Топ Прибутків 📈', style: TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                ...(incomeBreakdown.entries.toList()..sort((a, b) => b.value.compareTo(a.value))).map((e) {
                  final fraction = e.value / maxIncome;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(child: Text(e.key, style: const TextStyle(color: AppColors.textPrimary), maxLines: 1, overflow: TextOverflow.ellipsis)),
                            Text('+${e.value.toStringAsFixed(0)} грн', style: const TextStyle(color: AppColors.greenTask, fontWeight: FontWeight.bold)),
                          ],
                        ),
                        const SizedBox(height: 4),
                        TweenAnimationBuilder<double>(
                          tween: Tween<double>(begin: 0, end: fraction),
                          duration: const Duration(milliseconds: 1000),
                          curve: Curves.easeOutCubic,
                          builder: (context, value, child) {
                            return Align(
                              alignment: Alignment.centerLeft,
                              child: FractionallySizedBox(
                                widthFactor: value,
                                child: Container(
                                  height: 6,
                                  decoration: BoxDecoration(
                                    color: AppColors.greenTask,
                                    borderRadius: BorderRadius.circular(3),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  );
                }),
              ],

              if (expensesBreakdown.isNotEmpty) ...[
                const SizedBox(height: 24),
                const Text('Топ Витрат 📉', style: TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                ...(expensesBreakdown.entries.toList()..sort((a, b) => b.value.compareTo(a.value))).map((e) {
                  final fraction = e.value / maxExpense;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(child: Text(e.key, style: const TextStyle(color: AppColors.textPrimary), maxLines: 1, overflow: TextOverflow.ellipsis)),
                            Text('-${e.value.toStringAsFixed(0)} грн', style: const TextStyle(color: AppColors.redTask, fontWeight: FontWeight.bold)),
                          ],
                        ),
                        const SizedBox(height: 4),
                        TweenAnimationBuilder<double>(
                          tween: Tween<double>(begin: 0, end: fraction),
                          duration: const Duration(milliseconds: 1000),
                          curve: Curves.easeOutCubic,
                          builder: (context, value, child) {
                            return Align(
                              alignment: Alignment.centerLeft,
                              child: FractionallySizedBox(
                                widthFactor: value,
                                child: Container(
                                  height: 6,
                                  decoration: BoxDecoration(
                                    color: AppColors.redTask,
                                    borderRadius: BorderRadius.circular(3),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ],
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (err, stack) => Text("Помилка: $err", style: const TextStyle(color: Colors.red)),
    );
  }

    Widget _buildSuccessBalanceSection(WidgetRef ref, StatPeriod period) {
    final statsAsync = ref.watch(statisticsProvider(period));

    return statsAsync.when(
      data: (stats) => _buildSuccessBalanceCard(stats),
      loading: () => const SizedBox.shrink(),
      error: (err, stack) => Text("Помилка: $err", style: const TextStyle(color: Colors.red)),
    );
  }

  Widget _buildSuccessBalanceCard(Map<String, dynamic> stats) {
    final int yellow = stats['byType']?['yellow'] ?? 0;
    final int red = stats['byType']?['red'] ?? 0;

    if (yellow == 0 && red == 0) return const SizedBox.shrink();

    return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.star_rounded, color: AppColors.yellowTask, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    '$yellow Успіхів',
                    style: const TextStyle(color: AppColors.yellowTask, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              Row(
                children: [
                  Text(
                    '$red Невдач',
                    style: const TextStyle(color: AppColors.redTask, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(width: 8),
                  const Icon(Icons.warning_amber_rounded, color: AppColors.redTask, size: 20),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: SizedBox(
              height: 12,
              child: Row(
                children: [
                  Expanded(
                    flex: yellow == 0 && red == 0 ? 1 : yellow,
                    child: Container(color: yellow == 0 && red == 0 ? AppColors.surfaceVariant : AppColors.yellowTask),
                  ),
                  Expanded(
                    flex: yellow == 0 && red == 0 ? 1 : red,
                    child: Container(color: yellow == 0 && red == 0 ? AppColors.surfaceVariant : AppColors.redTask),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: Text(
              yellow > red ? 'Чудовий настрій! Продовжуй так само 🚀' : 
              yellow < red ? 'Не засмучуйся, завтра буде краще 🫂' : 
              'Абсолютний баланс ⚖️',
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
          ),
        ],
      );
  }

  Widget _buildCaloriesAnalyticsSection(WidgetRef ref, StatPeriod period) {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    
    DateTime start;
    DateTime end = startOfDay.add(const Duration(days: 1));
    
    switch (period) {
      case StatPeriod.day:
        start = startOfDay;
        break;
      case StatPeriod.week:
        start = startOfDay.subtract(Duration(days: now.weekday - 1));
        break;
      case StatPeriod.month:
        start = DateTime(now.year, now.month, 1);
        break;
      case StatPeriod.year:
        start = DateTime(now.year, 1, 1);
        break;
    }

    final rangeParams = (start, end);
    final macrosAsync = ref.watch(macrosRangeProvider(rangeParams));
    final settingsAsync = ref.watch(settingsProvider);

    return macrosAsync.when(
      data: (macrosList) {
        return settingsAsync.when(
          data: (settings) {
            return Column(
              children: [
                _buildMacrosAverages(macrosList, settings),
                const SizedBox(height: 24),
                _buildMacrosBarChart(macrosList, settings, start, end, period),
              ],
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, stack) => Text("Помилка: $err", style: const TextStyle(color: Colors.red)),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Text("Помилка: $err", style: const TextStyle(color: Colors.red)),
    );
  }

  Widget _buildMacrosAverages(List<DailyMacros> macrosList, UserSettings settings) {
    if (macrosList.isEmpty) {
      return const Text('Немає даних за цей період', style: TextStyle(color: AppColors.textSecondary));
    }

    int totalCal = 0;
    int totalPro = 0;
    int totalFat = 0;
    int totalCarb = 0;

    for (var m in macrosList) {
      totalCal += m.calories;
      totalPro += m.protein;
      totalFat += m.fats;
      totalCarb += m.carbs;
    }

    final avgCal = totalCal ~/ macrosList.length;
    final avgPro = totalPro ~/ macrosList.length;
    final avgFat = totalFat ~/ macrosList.length;
    final avgCarb = totalCarb ~/ macrosList.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Середнє споживання:', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildAvgStat('Калорії', avgCal, settings.targetCalories, AppColors.accent),
            _buildAvgStat('Білки', avgPro, settings.targetProtein, AppColors.blueTask),
            _buildAvgStat('Жири', avgFat, settings.targetFats, AppColors.yellowTask),
            _buildAvgStat('Вугл', avgCarb, settings.targetCarbs, AppColors.greenTask),
          ],
        ),
      ],
    );
  }

  Widget _buildAvgStat(String label, int avg, int target, Color color) {
    return Column(
      children: [
        Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
        const SizedBox(height: 4),
        Text('$avg', style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 16)),
        Text('з $target', style: const TextStyle(color: AppColors.textSecondary, fontSize: 10)),
      ],
    );
  }

  Widget _buildMacrosBarChart(List<DailyMacros> macrosList, UserSettings settings, DateTime start, DateTime end, StatPeriod period) {
    List<DateTime> dates = [];
    DateTime curr = start;
    while (curr.isBefore(end)) {
      dates.add(curr);
      curr = curr.add(const Duration(days: 1));
    }

    if (dates.length > 31) {
      return const Text('Графік доступний лише для тижня/місяця', style: TextStyle(color: AppColors.textSecondary));
    }

    final maxCal = math.max(settings.targetCalories.toDouble(), macrosList.fold<double>(0, (prev, el) => math.max(prev, el.calories.toDouble())));

    return SizedBox(
      height: 150,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: dates.map((d) {
          final dateStr = "${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}";
          final macro = macrosList.firstWhere((m) => m.dateStr == dateStr, orElse: () => DailyMacros.empty(dateStr));
          
          final isOver = macro.calories > settings.targetCalories;
          final barColor = isOver ? AppColors.redTask : AppColors.greenTask;
          final heightFactor = maxCal > 0 ? (macro.calories / maxCal) : 0.0;

          return Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (macro.calories > 0)
                  Text('${macro.calories}', style: const TextStyle(color: AppColors.textSecondary, fontSize: 8), maxLines: 1, overflow: TextOverflow.clip),
                const SizedBox(height: 4),
                Expanded(
                  child: FractionallySizedBox(
                    alignment: Alignment.bottomCenter,
                    heightFactor: heightFactor,
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      decoration: BoxDecoration(
                        color: macro.calories == 0 ? AppColors.surfaceVariant : barColor,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text('${d.day}', style: const TextStyle(color: AppColors.textSecondary, fontSize: 10)),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }


  Widget _buildEmptyCard(String msg) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      alignment: Alignment.center,
      child: Text(msg, style: const TextStyle(color: AppColors.textSecondary)),
    );
  }
}

class _HabitHallOfFame extends ConsumerStatefulWidget {
  const _HabitHallOfFame();

  @override
  ConsumerState<_HabitHallOfFame> createState() => _HabitHallOfFameState();
}

class _HabitHallOfFameState extends ConsumerState<_HabitHallOfFame> {
  bool _showCurrent = true;

  @override
  Widget build(BuildContext context) {
    final streaksAsync = ref.watch(habitStreaksProvider);

    return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Toggle
          Container(
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                _buildToggleTab('Теперішні рекорди', true),
                _buildToggleTab('Абсолютний рекорд', false),
              ],
            ),
          ),
          const SizedBox(height: 16),
          streaksAsync.when(
            data: (data) {
              if (data.isEmpty) {
                return const Text('Немає звичок', style: TextStyle(color: AppColors.textSecondary));
              }

              final list = data.values.toList();
              
              if (_showCurrent) {
                list.sort((a, b) => (b['currentStreak'] as int).compareTo(a['currentStreak'] as int));
              } else {
                list.sort((a, b) => (b['maxStreak'] as int).compareTo(a['maxStreak'] as int));
              }

              final top3 = list.take(3).toList();

              return Column(
                children: top3.map((item) {
                  final streak = _showCurrent ? item['currentStreak'] as int : item['maxStreak'] as int;
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            item['title'] as String,
                            style: const TextStyle(color: AppColors.textPrimary, fontSize: 16),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(
                          Icons.local_fire_department_rounded,
                          color: streak > 0 ? Colors.orange : AppColors.textDisabled,
                          size: 20,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '$streak',
                          style: TextStyle(
                            color: streak > 0 ? Colors.orange : AppColors.textDisabled,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, __) => const Text('Помилка', style: TextStyle(color: Colors.red)),
          ),
        ],
      );
  }

  Widget _buildToggleTab(String label, bool isCurrentTab) {
    final isSelected = _showCurrent == isCurrentTab;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _showCurrent = isCurrentTab),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.accent.withAlpha(50) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: isSelected ? Border.all(color: AppColors.accent) : Border.all(color: Colors.transparent),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isSelected ? AppColors.accent : AppColors.textSecondary,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }
}















