import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../shared/models/models.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/date_utils.dart' as app_date;
import '../../../../core/services/notification_service.dart';
import '../../data/task_repository.dart';
import '../../data/notification_expense_service.dart';
import '../../../settings/data/settings_repository.dart';
import '../../../targets/presentation/screens/targets_screen.dart'
    show targetsStreamProvider;

// Provider for selected date (always normalized to midnight local time)
final selectedDateProvider = StateProvider<DateTime>((ref) {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day);
});

// Provider for tasks on selected date (always normalized)
final tasksForDateProvider = StreamProvider.family<List<Task>, DateTime>((ref, rawDate) {
  final date = DateTime(rawDate.year, rawDate.month, rawDate.day);
  final repo = ref.watch(taskRepositoryProvider);
  return repo.getTasksForDate(date);
});

final taskRepositoryProvider = Provider<TaskRepository>((ref) => TaskRepository());

typedef StreakArgs = ({String groupId, DateTime date});

final taskStreakProvider = FutureProvider.family<({int streak, int antiStreak}), StreakArgs>((ref, args) async {
  final repo = ref.watch(taskRepositoryProvider);
  return repo.calculateTaskStreak(args.groupId, args.date);
});

class TodayScreen extends ConsumerStatefulWidget {
  const TodayScreen({super.key});

  @override
  ConsumerState<TodayScreen> createState() => _TodayScreenState();
}

class _TodayScreenState extends ConsumerState<TodayScreen> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      ref.read(selectedDateProvider.notifier).state = today;
      final repo = ref.read(taskRepositoryProvider);
      NotificationExpenseService().startListening(repo);
      repo.processMissedTaskPenalties();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final currentSelected = ref.read(selectedDateProvider);
      // Auto rollover to today if date changed while app was in background
      if (currentSelected.isBefore(today)) {
        ref.read(selectedDateProvider.notifier).state = today;
      }
      ref.read(taskRepositoryProvider).processMissedTaskPenalties();
    }
  }
  @override
  Widget build(BuildContext context) {
    final selectedDate = ref.watch(selectedDateProvider);
    final tasksAsync = ref.watch(tasksForDateProvider(selectedDate));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'NO EXCUSES // ${app_date.DateUtils.formatDate(selectedDate).toUpperCase()}',
              style: GoogleFonts.chakraPetch(
                color: AppColors.accent,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.0,
              ),
            ),
            Text(
              'HARD WORK GRIND',
              style: GoogleFonts.chakraPetch(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.8,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: () => context.go('/settings'),
            tooltip: 'Налаштування',
            icon: const Icon(Icons.settings_rounded, color: AppColors.textSecondary),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context, selectedDate),
            _buildDateNavigator(selectedDate),
            Expanded(
              child: tasksAsync.when(
                data: (tasks) => _buildTasksList(tasks),
                loading: () => const Center(
                  child: CircularProgressIndicator(color: AppColors.accent),
                ),
                error: (e, _) => Center(
                  child: Text(
                    'Помилка завантаження: $e',
                    style: const TextStyle(color: AppColors.redTask),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddTaskBottomSheet(context),
        backgroundColor: AppColors.accent,
        foregroundColor: Colors.black,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 6,
        child: const Icon(Icons.add_rounded, size: 36, color: Colors.black),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, DateTime date) {
    final isToday = app_date.DateUtils.isToday(date);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 6),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isToday ? 'СЬОГОДНІ' : app_date.DateUtils.formatDate(date).toUpperCase(),
                  style: GoogleFonts.chakraPetch(
                    color: AppColors.textPrimary,
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.8,
                  ),
                ),
                Text(
                  app_date.DateUtils.formatDayOfWeek(date).toUpperCase(),
                  style: GoogleFonts.chakraPetch(
                    color: AppColors.accent,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.6,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => _pickDate(context, date),
            icon: const Icon(Icons.calendar_month_rounded),
            color: AppColors.accent,
          ),
          if (!isToday)
            TextButton(
              onPressed: () {
                final now = DateTime.now();
                ref.read(selectedDateProvider.notifier).state = DateTime(now.year, now.month, now.day);
              },
              child: Text(
                'СЬОГОДНІ',
                style: GoogleFonts.chakraPetch(color: AppColors.accent, fontWeight: FontWeight.w800),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDateNavigator(DateTime selectedDate) {
    return const _WeekSelector();
  }

  Widget _buildTasksList(List<Task> tasks) {
    if (tasks.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.task_alt_rounded,
                size: 64, color: AppColors.textDisabled),
            SizedBox(height: 16),
            Text(
              'Немає задач на цей день',
              style:
                  TextStyle(color: AppColors.textSecondary, fontSize: 16),
            ),
            SizedBox(height: 8),
            Text(
              'Натисніть + щоб додати задачу',
              style:
                  TextStyle(color: AppColors.textDisabled, fontSize: 13),
            ),
          ],
        ),
      );
    }

    final greenTasks =
        tasks.where((t) => t.type == TaskType.green).toList();
    final blueTasks =
        tasks.where((t) => t.type == TaskType.blue).toList();
    final redTasks =
        tasks.where((t) => t.type == TaskType.red).toList();
    final yellowTasks =
        tasks.where((t) => t.type == TaskType.yellow).toList();
      final financeTasks = tasks.where((t) => t.type == TaskType.finance).toList();

    final checkable = tasks.where((t) => t.hasCheckbox).toList();
    final completedCount = checkable.where((t) => t.isCompleted).length;
    final progress =
        checkable.isEmpty ? 0.0 : completedCount / checkable.length;

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      children: [
        if (checkable.isNotEmpty) ...[
          _buildProgressCard(completedCount, checkable.length, progress),
          const SizedBox(height: 16),
        ],
        if (greenTasks.isNotEmpty) ...[
          _buildSectionHeader(
              'DAILY DRILLS // РЕЖИМ', AppColors.accent, Icons.repeat_rounded),
          ...greenTasks.map((t) => _TaskCard(task: t)),
          const SizedBox(height: 12),
        ],
        if (blueTasks.isNotEmpty) ...[
          _buildSectionHeader(
              'TARGETS // ФОКУС', Colors.white, Icons.flag_rounded),
          ...blueTasks.map((t) => _TaskCard(task: t)),
          const SizedBox(height: 12),
        ],
        if (redTasks.isNotEmpty) ...[
          _buildSectionHeader(
              'PENALTY ZONE // СЛАБКІСТЬ', AppColors.redTask, Icons.warning_rounded),
          ...redTasks.map((t) => _TaskCard(task: t)),
          const SizedBox(height: 12),
        ],
        if (yellowTasks.isNotEmpty) ...[
          _buildSectionHeader(
              'VICTORIES // РЕЗУЛЬТАТ', AppColors.accent, Icons.star_rounded),
          ...yellowTasks.map((t) => _TaskCard(task: t)),
        ],
        if (financeTasks.isNotEmpty) ...[
          _buildSectionHeader(
              'CAPITAL // ВИТРАТИ ТА ДОХОДИ', AppColors.accent, Icons.account_balance_wallet_rounded),
          ...financeTasks.map((t) => _TaskCard(task: t)),
          const SizedBox(height: 12),
        ],
        const SizedBox(height: 80),
      ],
    );
  }

  Widget _buildProgressCard(int completed, int total, double progress) {
    final percent = (progress * 100).round();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.accent.withAlpha(180), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(90),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'WORK CAPACITY // DAILY OUTPUT',
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                  style: GoogleFonts.chakraPetch(
                    color: AppColors.accent,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.6,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '$percent% MAX',
                style: GoogleFonts.chakraPetch(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            height: 14,
            width: double.infinity,
            decoration: BoxDecoration(
              color: const Color(0xFF0C0D10),
              borderRadius: BorderRadius.circular(4),
            ),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: progress.clamp(0.0, 1.0),
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.accent,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '$completed / $total СЕТІВ ЗАКРИТО  •  ${progress >= 1.0 ? "РЕКОРД ДОСЯГНУТО! 🔥" : "ТРИМАЙ ТЕМП!"}',
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
            style: GoogleFonts.chakraPetch(
              color: const Color(0xFFC8CDDC),
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, Color color, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, top: 4),
      child: Row(
        children: [
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: AppColors.border, width: 1.2),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, color: color, size: 14),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      title.toUpperCase(),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                      style: GoogleFonts.chakraPetch(
                        color: color,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            width: 24,
            height: 1,
            color: AppColors.border,
          ),
        ],
      ),
    );
  }

  void _pickDate(BuildContext context, DateTime current) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme:
              const ColorScheme.dark(primary: AppColors.accent),
        ),
        child: child!,
      ),
    );
    if (picked != null && mounted) {
      ref.read(selectedDateProvider.notifier).state = picked;
    }
  }

  void _showAddTaskBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => const AddTaskSheet(),
    );
  }
}

// ---- Task Card Widget ----
class _TaskCard extends ConsumerWidget {
  final Task task;
  const _TaskCard({required this.task});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final color = AppTheme.taskTypeColor(task.type);
    final repo = ref.read(taskRepositoryProvider);

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final taskDay = DateTime(task.date.year, task.date.month, task.date.day);
    
    final isToday = taskDay.isAtSameMomentAs(today);
    final isPast = taskDay.isBefore(today);

        final isUncategorizedFinance = task.type == TaskType.finance &&
        (task.tag == null || task.tag!.isEmpty || task.tag == 'Не вказано');
    final isIncomeTask = task.moneyEarned != null && task.moneyEarned! > 0;
    final highlightColor = isIncomeTask ? AppColors.greenTask : AppColors.accent;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isUncategorizedFinance ? highlightColor.withAlpha(160) : AppColors.border,
          width: 1.5,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(9),
        child: Stack(
          children: [
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              width: 4,
              child: ColoredBox(
                color: task.isCompleted ? AppColors.accent : color,
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(left: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ListTile(
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                    leading: task.hasCheckbox
                        ? GestureDetector(
                            onTap: isToday ? () => repo.toggleTaskCompletion(task.id, !task.isCompleted) : null,
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              width: 24,
                              height: 24,
                              decoration: BoxDecoration(
                                color: task.isCompleted
                                    ? AppColors.accent
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: task.isCompleted
                                      ? AppColors.accent
                                      : AppColors.accent.withAlpha(200),
                                  width: 1.8,
                                ),
                              ),
                              child: task.isCompleted
                                  ? const Icon(Icons.check_rounded,
                                      color: Colors.black, size: 16)
                                  : null,
                            ),
                          )
                        : Container(
                            width: 8,
                            height: 8,
                            decoration:
                                BoxDecoration(color: color, borderRadius: BorderRadius.circular(2)),
                          ),
                    title: Text(
                      task.title,
                      style: GoogleFonts.chakraPetch(
                        color: task.isCompleted
                            ? AppColors.textSecondary
                            : AppColors.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.3,
                        decoration:
                            task.isCompleted ? TextDecoration.lineThrough : null,
                      ),
                    ),
                    subtitle: _buildSubtitle(task, ref),
                    trailing: (task.type == TaskType.green && task.groupId != null)
                        ? StreakBadge(groupId: task.groupId!, date: task.date)
                        : null,
                    onLongPress: isPast ? null : () => _showTaskOptions(context, ref, task),
                  ),
                  if (isUncategorizedFinance)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Divider(color: AppColors.border, height: 1),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Icon(Icons.category_rounded, size: 14, color: highlightColor),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  isIncomeTask ? 'Оберіть категорію доходу:' : 'Оберіть категорію витрати:',
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                  style: TextStyle(
                                    color: highlightColor,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Consumer(
                            builder: (context, ref, child) {
                              final settings = ref.watch(settingsProvider).valueOrNull;
                              final tags = isIncomeTask
                                  ? (settings?.incomeTags ?? ['Зарплата', 'Подарунок', 'Кешбек', 'Інше'])
                                  : (settings?.expenseTags ?? ['Їжа', 'Транспорт', 'Розваги', 'Житло', 'Інше']);
                              return Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                children: tags.map((t) {
                                  return ActionChip(
                                    label: Text(
                                      t,
                                      style: const TextStyle(fontSize: 11, color: AppColors.textPrimary),
                                    ),
                                    backgroundColor: AppColors.surfaceVariant,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      side: const BorderSide(color: AppColors.border),
                                    ),
                                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
                                    onPressed: () {
                                      final updated = task.copyWith(tag: t);
                                      repo.updateTask(updated);
                                    },
                                  );
                                }).toList(),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget? _buildSubtitle(Task task, WidgetRef ref) {
    final parts = <String>[];
    if (task.timeSpentMinutes != null && task.timeSpentMinutes! > 0) {
      parts.add(
          '⏱ ${app_date.DateUtils.formatMinutes(task.timeSpentMinutes!)}');
    }
    if (task.moneySpent != null && task.moneySpent! > 0) {
      parts.add('💸 -${task.moneySpent!.toStringAsFixed(0)} грн');
    }
    if (task.moneyEarned != null && task.moneyEarned! > 0) {
      parts.add('💰 +${task.moneyEarned!.toStringAsFixed(0)} грн');
    }
    if (task.tag != null && task.tag!.isNotEmpty) {
      parts.add('🏷 ${task.tag}');
    } else if (task.type == TaskType.finance) {
      parts.add('⚠️ Без категорії');
    }

    final hasTargets =
        task.targetPoints.isNotEmpty || task.appliedTargetPoints.isNotEmpty;
    if (parts.isEmpty && !hasTargets) return null;

    final targetsList = ref.watch(targetsStreamProvider).valueOrNull ?? const [];
    final targetMap = {for (final t in targetsList) t.id: t};

    final targetChips = <Widget>[];
    if (hasTargets) {
      final allTargetIds = <String>{
        ...task.targetPoints.keys,
        ...task.appliedTargetPoints.keys,
      };
      for (final tId in allTargetIds) {
        final target = targetMap[tId];
        final targetName = target?.title ?? 'Таргет';
        final applied = task.appliedTargetPoints[tId];
        final basePts = task.targetPoints[tId] ?? 0;

        String ptsLabel;
        Color badgeColor;
        if (applied != null && applied != 0) {
          if (applied > 0) {
            ptsLabel = '+$applied TP';
            badgeColor = AppColors.greenTask;
          } else {
            ptsLabel = '$applied TP';
            badgeColor = AppColors.redTask;
          }
        } else {
          ptsLabel = '+$basePts TP';
          badgeColor = AppColors.accent;
        }

        targetChips.add(
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: badgeColor.withAlpha(25),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: badgeColor.withAlpha(110), width: 0.8),
            ),
            child: Text(
              '🎯 $targetName: $ptsLabel',
              style: GoogleFonts.chakraPetch(
                color: badgeColor,
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        );
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (parts.isNotEmpty)
          Text(
            parts.join('  '),
            style: GoogleFonts.chakraPetch(
              color: AppColors.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w500,
              letterSpacing: 0.3,
            ),
          ),
        if (targetChips.isNotEmpty) ...[
          if (parts.isNotEmpty) const SizedBox(height: 4),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: targetChips,
          ),
        ],
      ],
    );
  }

  void _showTaskOptions(
      BuildContext context, WidgetRef ref, Task task) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit_rounded,
                  color: AppColors.textSecondary),
              title: const Text('Редагувати',
                  style: TextStyle(color: AppColors.textPrimary)),
              onTap: () {
                Navigator.pop(ctx);
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: AppColors.surface,
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                  ),
                  builder: (ctx2) => AddTaskSheet(taskToEdit: task),
                );
              },
            ),
            if (task.type == TaskType.green && task.groupId != null) ...[
              ListTile(
                leading: const Icon(Icons.delete_sweep_rounded,
                    color: AppColors.redTask),
                title: const Text('Видалити цю та майбутні',
                    style: TextStyle(color: AppColors.redTask)),
                onTap: () async {
                  Navigator.pop(ctx);
                  final repo = ref.read(taskRepositoryProvider);
                  await repo.deleteTask(task.id);
                  await repo.deleteAllGreenTaskInstances(task.groupId!, task.date, currentTaskId: task.id);
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete_forever_rounded,
                    color: AppColors.redTask),
                title: const Text('Видалити повністю всю серію (скрізь)',
                    style: TextStyle(color: AppColors.redTask, fontWeight: FontWeight.bold)),
                subtitle: const Text('Видаляє завдання з усіх днів (минулих і майбутніх)',
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 11)),
                onTap: () async {
                  Navigator.pop(ctx);
                  final repo = ref.read(taskRepositoryProvider);
                  await repo.deleteTask(task.id);
                  await repo.deleteEntireGreenTaskSeries(task.groupId!, taskTitle: task.title);
                },
              ),
            ] else
              ListTile(
                leading: const Icon(Icons.delete_rounded,
                    color: AppColors.redTask),
                title: const Text('Видалити',
                    style: TextStyle(color: AppColors.redTask)),
                onTap: () async {
                  Navigator.pop(ctx);
                  final repo = ref.read(taskRepositoryProvider);
                  await repo.deleteTask(task.id);
                },
              ),
          ],
        ),
      ),
    );
  }
}

// ---- Add Task Bottom Sheet ----
class AddTaskSheet extends ConsumerStatefulWidget {
  final Task? taskToEdit;
  const AddTaskSheet({super.key, this.taskToEdit});

  @override
  ConsumerState<AddTaskSheet> createState() => _AddTaskSheetState();
}

class _AddTaskSheetState extends ConsumerState<AddTaskSheet> {
  final _titleController = TextEditingController();
  final _timeController = TextEditingController();
  final _moneyController = TextEditingController();
  TaskType _selectedType = TaskType.green;
  RecurrenceFrequency _recurrence = RecurrenceFrequency.daily;
  List<int> _selectedDays = [1, 2, 3, 4, 5];
  bool _isLoading = false;
  String? _reminderTime;
  bool _isIncome = false;
  String? _selectedTag;
  Map<String, int> _selectedTargetPoints = {};

  @override
  void initState() {
    super.initState();
    if (widget.taskToEdit != null) {
      final t = widget.taskToEdit!;
      _titleController.text = t.title;
      _timeController.text = t.timeSpentMinutes?.toString() ?? '';
      _isIncome = t.moneyEarned != null && t.moneyEarned! > 0;
      _moneyController.text = _isIncome ? (t.moneyEarned?.toString() ?? '') : (t.moneySpent?.toString() ?? '');
      _selectedTag = t.tag;
      _selectedType = t.type;
      _reminderTime = t.reminderTime;
      _selectedTargetPoints = Map<String, int>.from(t.targetPoints);
      if (t.recurrence != null) {
        _recurrence = t.recurrence!.frequency;
        if (t.recurrence!.daysOfWeek != null) {
          _selectedDays = List.from(t.recurrence!.daysOfWeek!);
        }
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _timeController.dispose();
    _moneyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + bottomInset),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.taskToEdit != null ? 'Редагувати задачу' : 'Нова задача',
                style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          _buildTypeSelector(),
          const SizedBox(height: 16),
          if (_selectedType != TaskType.finance) ...[
            TextField(
              controller: _titleController,
              autofocus: true,
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: const InputDecoration(
                hintText: 'Назва задачі...',
                labelText: 'Назва',
              ),
            ),
            const SizedBox(height: 12),
          ],
            if (_selectedType != TaskType.finance)
              TextField(
                controller: _timeController,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: const InputDecoration(
                  labelText: 'Час (хв)',
                  prefixIcon: Icon(Icons.timer_outlined, color: AppColors.textSecondary),
                ),
              ),
            if (_selectedType == TaskType.finance) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(_isIncome ? 'Прибуток (Дохід)' : 'Витрата', style: const TextStyle(color: AppColors.textPrimary, fontSize: 16)),
                  Switch(
                    value: _isIncome,
                    activeThumbColor: AppColors.accent,
                    inactiveThumbColor: AppColors.redTask,
                    inactiveTrackColor: AppColors.redTask.withAlpha(50),
                    onChanged: (val) => setState(() {
                      _isIncome = val;
                      _selectedTag = null; // reset tag on switch
                    }),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _moneyController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: const InputDecoration(
                  labelText: 'Сума (грн)',
                  prefixIcon: Icon(Icons.account_balance_wallet_outlined, color: AppColors.textSecondary),
                ),
              ),
              const SizedBox(height: 16),
              Consumer(
                builder: (context, ref, child) {
                  final settings = ref.watch(settingsProvider).valueOrNull;
                  if (settings == null) return const SizedBox.shrink();
                  final tags = _isIncome ? settings.incomeTags : settings.expenseTags;
                  
                  if (!tags.contains(_selectedTag) && _selectedTag != null) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      setState(() => _selectedTag = null);
                    });
                  }

                  return DropdownButtonFormField<String>(
                    initialValue: _selectedTag,
                    dropdownColor: AppColors.surface,
                    style: const TextStyle(color: AppColors.textPrimary),
                    decoration: const InputDecoration(
                      labelText: 'Категорія',
                      prefixIcon: Icon(Icons.label_outline, color: AppColors.textSecondary),
                    ),
                    items: tags.map((tag) => DropdownMenuItem(
                      value: tag,
                      child: Text(tag),
                    )).toList(),
                    onChanged: (val) => setState(() => _selectedTag = val),
                  );
                },
              ),
            ],
            if (_selectedType == TaskType.green) ...[
              const SizedBox(height: 16),
              _buildRecurrenceSelector(),
            ],
            if (_selectedType == TaskType.green || _selectedType == TaskType.blue) ...[
              const SizedBox(height: 16),
              _buildTargetsBindingSection(),
            ],
            const SizedBox(height: 16),
            _buildReminderSelector(),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _saveTask,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                            color: Colors.black, strokeWidth: 2))
                    : Text(widget.taskToEdit != null ? 'Зберегти' : 'Створити',
                        style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.black)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTargetsBindingSection() {
    final targetsAsync = ref.watch(targetsStreamProvider);
    final activeTargets = (targetsAsync.valueOrNull ?? const [])
        .where((t) => !t.isCompleted)
        .toList();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.track_changes_rounded,
                  color: AppColors.accent, size: 18),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'ПРИВ’ЯЗКА ДО ТАРГЕТІВ (ОЧКИ TP)',
                  style: GoogleFonts.chakraPetch(
                    color: AppColors.accent,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Оберіть таргети та скільки очок додавати за виконання (або списувати при пропуску).',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 11),
          ),
          const SizedBox(height: 10),
          if (activeTargets.isEmpty)
            const Text(
              'Немає активних таргетів. Створіть їх у вкладці «Таргет»!',
              style: TextStyle(color: AppColors.textDisabled, fontSize: 12),
            )
          else
            ...activeTargets.map((target) {
              final isBound = _selectedTargetPoints.containsKey(target.id);
              final currentPts = _selectedTargetPoints[target.id] ?? 20;
              final tColor = Color(target.colorValue);

              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: isBound
                      ? tColor.withAlpha(20)
                      : AppColors.surface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isBound ? tColor : AppColors.border,
                    width: isBound ? 1.4 : 1.0,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        GestureDetector(
                          onTap: () {
                            setState(() {
                              if (isBound) {
                                _selectedTargetPoints.remove(target.id);
                              } else {
                                _selectedTargetPoints[target.id] = 20;
                              }
                            });
                          },
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 20,
                                height: 20,
                                decoration: BoxDecoration(
                                  color:
                                      isBound ? tColor : Colors.transparent,
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(
                                    color: isBound
                                        ? tColor
                                        : AppColors.textSecondary,
                                    width: 1.5,
                                  ),
                                ),
                                child: isBound
                                    ? const Icon(Icons.check_rounded,
                                        size: 14, color: Colors.black)
                                    : null,
                              ),
                              const SizedBox(width: 8),
                            ],
                          ),
                        ),
                        Expanded(
                          child: GestureDetector(
                            onTap: () {
                              setState(() {
                                if (isBound) {
                                  _selectedTargetPoints.remove(target.id);
                                } else {
                                  _selectedTargetPoints[target.id] = 20;
                                }
                              });
                            },
                            child: Text(
                              '${target.title} (LVL ${target.currentLevel}/${target.targetLevel})',
                              style: TextStyle(
                                color: isBound
                                    ? AppColors.textPrimary
                                    : AppColors.textSecondary,
                                fontSize: 13,
                                fontWeight: isBound
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                            ),
                          ),
                        ),
                        if (isBound)
                          InkWell(
                            onTap: () =>
                                _promptCustomTargetPoints(target.id, currentPts),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: tColor.withAlpha(40),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '+$currentPts TP ✎',
                                style: GoogleFonts.chakraPetch(
                                  color: tColor,
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                    if (isBound) ...[
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [10, 20, 30, 50, 100].map((preset) {
                          final selectedPreset = currentPts == preset;
                          return GestureDetector(
                            onTap: () {
                              setState(() {
                                _selectedTargetPoints[target.id] = preset;
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: selectedPreset
                                    ? tColor
                                    : AppColors.surfaceVariant,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: selectedPreset
                                      ? tColor
                                      : AppColors.border,
                                ),
                              ),
                              child: Text(
                                '+$preset TP',
                                style: GoogleFonts.chakraPetch(
                                  color: selectedPreset
                                      ? Colors.black
                                      : AppColors.textSecondary,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  void _promptCustomTargetPoints(String targetId, int initialPts) {
    final ctrl = TextEditingController(text: initialPts.toString());
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Очки Таргета (TP)',
            style: TextStyle(color: AppColors.textPrimary)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          keyboardType: TextInputType.number,
          style: const TextStyle(color: AppColors.textPrimary),
          decoration: const InputDecoration(
            labelText: 'Базові очки за виконання',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Скасувати',
                style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () {
              final val = (int.tryParse(ctrl.text) ?? initialPts).clamp(1, 10000);
              setState(() {
                _selectedTargetPoints[targetId] = val;
              });
              Navigator.pop(ctx);
            },
            child: const Text('Зберегти'),
          ),
        ],
      ),
    );
  }

  Widget _buildTypeSelector() {
    final types = [
      TaskType.green,
      TaskType.blue,
      TaskType.red,
      TaskType.yellow,
      TaskType.finance
    ];
    final labels = ['Повторювані', 'Заплановані', 'Невдачі', 'Успіхи', 'Фінанси'];
    final icons = [
      Icons.repeat_rounded,
      Icons.event_note_rounded,
      Icons.warning_amber_rounded,
      Icons.star_rounded,
      Icons.account_balance_wallet_rounded
    ];

    return Row(
      children: types.map((type) {
        final isSelected = _selectedType == type;
        final color = AppTheme.taskTypeColor(type);
        return Expanded(
          child: GestureDetector(
            onTap: widget.taskToEdit == null ? () => setState(() => _selectedType = type) : null,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: isSelected
                    ? color.withAlpha(40)
                    : AppColors.surfaceVariant,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isSelected ? color : Colors.transparent,
                  width: 1.5,
                ),
              ),
              child: Column(
                children: [
                  Icon(icons[type.index],
                      color: isSelected
                          ? color
                          : AppColors.textSecondary,
                      size: 20),
                  const SizedBox(height: 4),
                  Text(
                    labels[type.index],
                    style: TextStyle(
                      color: isSelected
                          ? color
                          : AppColors.textSecondary,
                      fontSize: 9,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildRecurrenceSelector() {
    final weekDays = ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Нд'];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Повторення',
            style: TextStyle(
                color: AppColors.textSecondary, fontSize: 13)),
        const SizedBox(height: 8),
        Row(
          children: [
            _FreqChip(
              label: 'Щодня',
              selected: _recurrence == RecurrenceFrequency.daily,
              onTap: () => setState(
                  () => _recurrence = RecurrenceFrequency.daily),
            ),
            const SizedBox(width: 8),
            _FreqChip(
              label: 'По днях',
              selected: _recurrence == RecurrenceFrequency.custom,
              onTap: () => setState(
                  () => _recurrence = RecurrenceFrequency.custom),
            ),
          ],
        ),
        if (_recurrence == RecurrenceFrequency.custom) ...[
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: List.generate(7, (i) {
              final day = i + 1;
              final selected = _selectedDays.contains(day);
              return GestureDetector(
                onTap: () => setState(() {
                  if (selected) {
                    _selectedDays.remove(day);
                  } else {
                    _selectedDays.add(day);
                  }
                }),
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: selected
                        ? AppColors.greenTask
                        : AppColors.surfaceVariant,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    weekDays[i],
                    style: TextStyle(
                      color: selected
                          ? Colors.white
                          : AppColors.textSecondary,
                      fontWeight: selected
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
                ),
              );
            }),
          ),
        ],
      ],
    );
  }

  Widget _buildReminderSelector() {
    return Row(
      children: [
        const Icon(Icons.notifications_none_rounded, color: AppColors.textSecondary, size: 20),
        const SizedBox(width: 8),
        const Text('Нагадування:', style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
        const Spacer(),
        TextButton(
          onPressed: () async {
            if (_reminderTime != null) {
              setState(() => _reminderTime = null);
              return;
            }
            // Request permissions before opening time picker
            await NotificationService().requestPermissions();
            if (!mounted) return;
            
            final time = await showTimePicker(
              context: context,
              initialTime: TimeOfDay.now(),
              builder: (context, child) => Theme(
                data: ThemeData.dark().copyWith(
                  colorScheme: const ColorScheme.dark(primary: AppColors.accent),
                ),
                child: child!,
              ),
            );
            if (time != null && mounted) {
              setState(() {
                _reminderTime = '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
              });
            }
          },
          style: TextButton.styleFrom(
            foregroundColor: _reminderTime != null ? AppColors.accent : AppColors.textPrimary,
          ),
          child: Text(_reminderTime ?? 'Встановити'),
        ),
      ],
    );
  }

  Future<void> _saveTask() async {
    if (_isLoading) return;
    if (_selectedType != TaskType.finance && _titleController.text.trim().isEmpty) return;
    setState(() => _isLoading = true);

    final date = ref.read(selectedDateProvider);
    final repo = ref.read(taskRepositoryProvider);
    final uid = widget.taskToEdit?.id ?? DateTime.now().millisecondsSinceEpoch.toString();

    RecurrenceRule? rule;
    if (_selectedType == TaskType.green) {
      rule = RecurrenceRule(
        frequency: _recurrence,
        daysOfWeek:
            _recurrence == RecurrenceFrequency.custom ? _selectedDays : null,
        startDate: widget.taskToEdit?.recurrence?.startDate ?? date,
      );
    }

    final canBindTargets =
        _selectedType == TaskType.green || _selectedType == TaskType.blue;

    final task = Task(
      id: uid,
      userId: '',
      title: _selectedType == TaskType.finance ? (_selectedTag ?? 'Фінанси') : _titleController.text.trim(),
      type: _selectedType,
      tag: _selectedType == TaskType.finance ? _selectedTag : null,
      date: widget.taskToEdit?.date ?? date,
      timeSpentMinutes: int.tryParse(_timeController.text),
      moneySpent: !_isIncome ? double.tryParse(_moneyController.text) : null,
      moneyEarned: _isIncome ? double.tryParse(_moneyController.text) : null,
      recurrence: rule,
      createdAt: widget.taskToEdit?.createdAt ?? DateTime.now(),
      groupId: _selectedType == TaskType.green ? (widget.taskToEdit?.groupId ?? uid) : null,
      isCompleted: widget.taskToEdit?.isCompleted ?? false,
      reminderTime: _reminderTime,
      targetPoints: canBindTargets ? Map<String, int>.from(_selectedTargetPoints) : const {},
      appliedTargetPoints: widget.taskToEdit?.appliedTargetPoints ?? const {},
      targetPenaltyProcessed: widget.taskToEdit?.targetPenaltyProcessed ?? false,
    );

    if (widget.taskToEdit != null) {
      if (task.type == TaskType.green && task.groupId != null) {
        await repo.updateAllGreenTaskInstances(task, widget.taskToEdit!.date);
      } else {
        await repo.updateTask(task);
      }
    } else {
      await repo.addTask(task);
    }
    
    if (mounted) Navigator.pop(context);
  }
}

class _FreqChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FreqChip(
      {required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.greenTask.withAlpha(30)
              : AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: selected ? AppColors.greenTask : Colors.transparent),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? AppColors.greenTask : AppColors.textSecondary,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}

class _WeekSelector extends ConsumerStatefulWidget {
  const _WeekSelector();

  @override
  ConsumerState<_WeekSelector> createState() => _WeekSelectorState();
}

class _WeekSelectorState extends ConsumerState<_WeekSelector> {
  late ScrollController _scrollController;
  final int _middleIndex = 5000;
  final double _itemWidth = 54.0; // 48 width + 3+3 margin

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController(
      initialScrollOffset: (_middleIndex * _itemWidth) - 150, // rough center screen offset
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final selectedDate = ref.watch(selectedDateProvider);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    return SizedBox(
      height: 72,
      child: ListView.builder(
        controller: _scrollController,
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _middleIndex * 2, // 10000 days total
        itemExtent: _itemWidth, // O(1) scroll calculation for performance
        itemBuilder: (context, index) {
          // Calendar arithmetic immune to daylight saving time (DST) shifts
          final day = DateTime(today.year, today.month, today.day + (index - _middleIndex));
          final isSelected = app_date.DateUtils.isSameDay(day, selectedDate);
          final isToday = app_date.DateUtils.isSameDay(day, today);

          return GestureDetector(
            onTap: () {
              ref.read(selectedDateProvider.notifier).state = DateTime(day.year, day.month, day.day);
            },
            child: Container(
              width: 48,
              margin: const EdgeInsets.symmetric(horizontal: 3, vertical: 6),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.accent : AppColors.surface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isToday && !isSelected
                      ? AppColors.accent
                      : (isSelected ? AppColors.accent : AppColors.border),
                  width: isToday || isSelected ? 1.8 : 1.2,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    app_date.DateUtils.formatDayShort(day).toUpperCase(),
                    style: GoogleFonts.chakraPetch(
                      color: isSelected
                          ? Colors.black
                          : AppColors.textSecondary,
                      fontSize: 10,
                      fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${day.day}',
                    style: GoogleFonts.chakraPetch(
                      color: isSelected
                          ? Colors.black
                          : AppColors.textPrimary,
                      fontSize: 16,
                      fontWeight: isSelected ? FontWeight.w900 : FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }


}

class StreakBadge extends ConsumerWidget {
  final String groupId;
  final DateTime date;
  
  const StreakBadge({required this.groupId, required this.date, super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final taskDay = DateTime(date.year, date.month, date.day);
    
    // Hide streak badge for future days
    if (taskDay.isAfter(today)) {
      return const SizedBox.shrink();
    }

    final streakAsync = ref.watch(taskStreakProvider((groupId: groupId, date: date)));
    
    return streakAsync.when(
      data: (data) {
        final streak = data.streak;
        final antiStreak = data.antiStreak;

        if (streak == 0 && antiStreak == 0) return const SizedBox.shrink();
        
        if (streak > 0) {
          final double size = 16.0 + (streak * 0.5).clamp(0.0, 12.0);
          
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.local_fire_department_rounded, color: Colors.orange, size: size),
              const SizedBox(width: 2),
              Text(
                '$streak',
                style: TextStyle(
                  color: Colors.orange,
                  fontWeight: FontWeight.bold,
                  fontSize: size * 0.6,
                ),
              ),
            ],
          );
        } else {
          final double size = 16.0 + (antiStreak * 0.5).clamp(0.0, 12.0);
          
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.ac_unit_rounded, color: Colors.lightBlueAccent, size: size),
              const SizedBox(width: 2),
              Text(
                '$antiStreak',
                style: TextStyle(
                  color: Colors.lightBlueAccent,
                  fontWeight: FontWeight.bold,
                  fontSize: size * 0.6,
                ),
              ),
            ],
          );
        }
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}