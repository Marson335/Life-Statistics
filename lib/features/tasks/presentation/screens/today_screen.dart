import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../shared/models/models.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/date_utils.dart' as app_date;
import '../../../../core/services/notification_service.dart';
import '../../data/task_repository.dart';
import '../../data/notification_expense_service.dart';
import '../../../settings/data/settings_repository.dart';

// Provider for selected date
final selectedDateProvider = StateProvider<DateTime>((ref) => DateTime.now());

// Provider for tasks on selected date
final tasksForDateProvider = StreamProvider.family<List<Task>, DateTime>((ref, date) {
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

class _TodayScreenState extends ConsumerState<TodayScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      NotificationExpenseService().startListening(ref.read(taskRepositoryProvider));
    });
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
              'Привіт!',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
              ),
            ),
            const Text(
              'Твої задачі',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddTaskBottomSheet(context),
        backgroundColor: AppColors.accent,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Задача'),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, DateTime date) {
    final isToday = app_date.DateUtils.isToday(date);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isToday ? 'Сьогодні' : app_date.DateUtils.formatDate(date),
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  app_date.DateUtils.formatDayOfWeek(date),
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => _pickDate(context, date),
            icon: const Icon(Icons.calendar_month_rounded),
            color: AppColors.textSecondary,
          ),
          if (!isToday)
            TextButton(
              onPressed: () =>
                  ref.read(selectedDateProvider.notifier).state = DateTime.now(),
              child: const Text('Сьогодні',
                  style: TextStyle(color: AppColors.accent)),
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
              'Повторювані', AppColors.greenTask, Icons.repeat_rounded),
          ...greenTasks.map((t) => _TaskCard(task: t)),
          const SizedBox(height: 12),
        ],
        if (blueTasks.isNotEmpty) ...[
          _buildSectionHeader(
              'Заплановані', AppColors.blueTask, Icons.event_note_rounded),
          ...blueTasks.map((t) => _TaskCard(task: t)),
          const SizedBox(height: 12),
        ],
        if (redTasks.isNotEmpty) ...[
          _buildSectionHeader(
              'Невдачі', AppColors.redTask, Icons.warning_amber_rounded),
          ...redTasks.map((t) => _TaskCard(task: t)),
          const SizedBox(height: 12),
        ],
        if (yellowTasks.isNotEmpty) ...[
          _buildSectionHeader(
              'Успіхи', AppColors.yellowTask, Icons.star_rounded),
          ...yellowTasks.map((t) => _TaskCard(task: t)),
        ],
          if (financeTasks.isNotEmpty) ...[
            _buildSectionHeader(
                'Фінанси', AppColors.accent, Icons.account_balance_wallet_rounded),
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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 56,
            height: 56,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CircularProgressIndicator(
                  value: progress,
                  backgroundColor: AppColors.surfaceVariant,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    progress >= 1.0
                        ? AppColors.greenTask
                        : AppColors.accent,
                  ),
                  strokeWidth: 5,
                ),
                Text(
                  '$percent%',
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$completed з $total виконано',
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                progress >= 1.0
                    ? '🎉 Відмінна робота!'
                    : 'Залишилось ${total - completed} задач',
                style: TextStyle(
                  color: progress >= 1.0
                      ? AppColors.greenTask
                      : AppColors.textSecondary,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, Color color, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 6),
          Text(
            title,
            style: TextStyle(
              color: color,
              fontSize: 13,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
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
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isUncategorizedFinance ? highlightColor.withAlpha(120) : AppColors.border,
          width: isUncategorizedFinance ? 1.5 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: color.withAlpha(20),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListTile(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            leading: task.hasCheckbox
                ? GestureDetector(
                    onTap: isToday ? () => repo.toggleTaskCompletion(task.id, !task.isCompleted) : null,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: task.isCompleted
                            ? color
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: task.isCompleted
                              ? color
                              : AppColors.textSecondary,
                          width: 1.5,
                        ),
                      ),
                      child: task.isCompleted
                          ? const Icon(Icons.check_rounded,
                              color: Colors.white, size: 16)
                          : null,
                    ),
                  )
                : Container(
                    width: 10,
                    height: 10,
                    decoration:
                        BoxDecoration(color: color, shape: BoxShape.circle),
                  ),
            title: Text(
              task.title,
              style: TextStyle(
                color: task.isCompleted
                    ? AppColors.textSecondary
                    : AppColors.textPrimary,
                fontSize: 15,
                decoration:
                    task.isCompleted ? TextDecoration.lineThrough : null,
              ),
            ),
            subtitle: _buildSubtitle(task),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (task.type == TaskType.green && task.groupId != null)
                  StreakBadge(groupId: task.groupId!, date: task.date),
                Container(
                  width: 4,
                  height: 40,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ],
            ),
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
                      Text(
                        isIncomeTask ? 'Оберіть категорію доходу:' : 'Оберіть категорію витрати:',
                        style: TextStyle(
                          color: highlightColor,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
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
    );
  }

  Widget? _buildSubtitle(Task task) {
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
    if (parts.isEmpty) return null;
    return Text(
      parts.join('  '),
      style:
          const TextStyle(color: AppColors.textSecondary, fontSize: 12),
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
            ListTile(
              leading: const Icon(Icons.delete_rounded,
                  color: AppColors.redTask),
              title: const Text('Видалити',
                  style: TextStyle(color: AppColors.redTask)),
              onTap: () async {
                Navigator.pop(ctx);
                final repo = ref.read(taskRepositoryProvider);
                if (task.type == TaskType.green && task.groupId != null) {
                  await repo.deleteAllGreenTaskInstances(task.groupId!, task.date);
                } else {
                  await repo.deleteTask(task.id);
                }
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
                    activeColor: AppColors.greenTask,
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
                    value: _selectedTag,
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
            const SizedBox(height: 16),
            _buildReminderSelector(),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _saveTask,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.greenTask,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : Text(widget.taskToEdit != null ? 'Зберегти' : 'Створити',
                        style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white)),
              ),
            ),
          ],
        ),
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

    return SizedBox(
      height: 72,
      child: ListView.builder(
        controller: _scrollController,
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _middleIndex * 2, // 10000 days total
        itemExtent: _itemWidth, // O(1) scroll calculation for performance
        itemBuilder: (context, index) {
          final day = DateTime.now().add(Duration(days: index - _middleIndex));
          final isSelected = app_date.DateUtils.isSameDay(day, selectedDate);
          final isToday = app_date.DateUtils.isToday(day);

          return GestureDetector(
            onTap: () {
              ref.read(selectedDateProvider.notifier).state = day;
            },
            child: Container(
              width: 48,
              margin: const EdgeInsets.symmetric(horizontal: 3, vertical: 6),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.accent : AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isToday && !isSelected
                      ? AppColors.accent
                      : AppColors.border,
                  width: isToday && !isSelected ? 1.5 : 1,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    app_date.DateUtils.formatDayShort(day),
                    style: TextStyle(
                      color: isSelected
                          ? Colors.white
                          : AppColors.textSecondary,
                      fontSize: 10,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${day.day}',
                    style: TextStyle(
                      color: isSelected
                          ? Colors.white
                          : AppColors.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
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