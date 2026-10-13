import '../../../../core/services/notification_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/models/models.dart';
import '../../data/settings_repository.dart';
import '../../../tasks/data/notification_expense_service.dart';
import '../../../tasks/presentation/screens/today_screen.dart';

final notificationServiceProvider = Provider<NotificationService>((ref) => NotificationService());

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _isCaloriesExpanded = true;
  bool _isAiExpanded = false;
  bool _isAutoExpenseExpanded = false;
  bool _isFinanceExpanded = false;
  bool _isAutoExpenseEnabled = false;
  bool _hasNotificationPermission = false;

  @override
  void initState() {
    super.initState();
    _checkAutoExpenseStatus();
  }

  void _checkAutoExpenseStatus() async {
    final enabled = await NotificationExpenseService().isAutoTrackEnabled();
    final hasPerm = await NotificationExpenseService().isPermissionGranted();
    if (mounted) {
      setState(() {
        _isAutoExpenseEnabled = enabled;
        _hasNotificationPermission = hasPerm;
      });
    }
  }
  
  // Controllers
  final _ageController = TextEditingController();
  final _weightController = TextEditingController();
  final _heightController = TextEditingController();
  
  String _gender = 'male';
  String _goal = 'maintain';
  final _geminiKeyController = TextEditingController();

  @override
  void dispose() {
    _geminiKeyController.dispose();
    _ageController.dispose();
    _weightController.dispose();
    _heightController.dispose();
    super.dispose();
  }

  void _calculateAndSave(UserSettings current) {
    final age = int.tryParse(_ageController.text) ?? current.age;
    final weight = double.tryParse(_weightController.text) ?? current.weight;
    final height = double.tryParse(_heightController.text) ?? current.height;

    // Mifflin-St Jeor Equation
    double bmr = (10 * weight) + (6.25 * height) - (5 * age);
    bmr += (_gender == 'male') ? 5 : -161;
    
    // TDEE (Moderate activity assumed)
    double tdee = bmr * 1.55;

    // Goal adjustment
    if (_goal == 'lose') tdee -= 500;
    if (_goal == 'gain') tdee += 500;

    int targetCalories = tdee.round();
    
    // Macros
    int targetProtein = (weight * 2).round(); // 2g per kg
    int targetFats = weight.round(); // 1g per kg
    
    int proteinKcal = targetProtein * 4;
    int fatsKcal = targetFats * 9;
    
    int carbsKcal = targetCalories - proteinKcal - fatsKcal;
    int targetCarbs = (carbsKcal / 4).round();
    if (targetCarbs < 0) targetCarbs = 0;

    final updated = current.copyWith(
      age: age,
      weight: weight,
      height: height,
      gender: _gender,
      goal: _goal,
      geminiApiKey: _geminiKeyController.text.trim().isEmpty ? null : _geminiKeyController.text.trim(),
      targetCalories: targetCalories,
      targetProtein: targetProtein,
      targetFats: targetFats,
      targetCarbs: targetCarbs,
    );

    ref.read(settingsRepositoryProvider).updateSettings(updated);
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Дані оновлено!'), backgroundColor: AppColors.greenTask),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settingsAsync = ref.watch(settingsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Налаштування',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: settingsAsync.when(
        data: (settings) {
          // Initialize controllers if empty
          if (_ageController.text.isEmpty) {
            _ageController.text = settings.age.toString();
            _weightController.text = settings.weight.toString();
            _heightController.text = settings.height.toString();
            _gender = settings.gender;
            _goal = settings.goal;
            if (settings.geminiApiKey != null) _geminiKeyController.text = settings.geminiApiKey!;
          }

          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              _buildCaloriesSection(settings),
              // More settings can be added here in the future
              const SizedBox(height: 20),
              _buildAiSection(settings),
              const SizedBox(height: 20),
              _buildAutoExpenseSection(),
              const SizedBox(height: 20),
              _buildFinanceTagsSection(settings),
              const SizedBox(height: 20),
              _buildNotificationResetSection(),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Помилка: $e', style: const TextStyle(color: Colors.red))),
      ),
    );
  }

  Widget _buildNotificationResetSection() {
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
          const Text(
            'Нагадування та сповіщення',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Якщо сповіщення перестали надходити або виникають подвійні нагадування, натисніть кнопку нижче. Додаток автоматично очистить старі системні будильники та заново синхронізує всі нагадування для ваших актуальних завдань.',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.4),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () async {
                final notiService = ref.read(notificationServiceProvider);
                final taskRepo = ref.read(taskRepositoryProvider);
                await notiService.requestPermissions();
                await notiService.cancelAllNotifications();
                final count = await notiService.rescheduleAllTaskReminders(taskRepo);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Всі нагадування синхронізовано! Активних: $count'),
                      backgroundColor: AppColors.greenTask,
                    ),
                  );
                }
              },
              icon: const Icon(Icons.sync_rounded, color: Colors.white),
              label: const Text('Синхронізувати та відновити нагадування', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () async {
                final notiService = ref.read(notificationServiceProvider);
                await notiService.requestPermissions();
                await notiService.scheduleTestReminder();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Тестове сповіщення заплановано! Воно надійде через 5 секунд.'),
                      backgroundColor: AppColors.accent,
                    ),
                  );
                }
              },
              icon: const Icon(Icons.alarm_on_rounded, color: AppColors.accent, size: 20),
              label: const Text('Перевірити сповіщення (тест через 5 сек)', style: TextStyle(color: AppColors.textPrimary)),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppColors.accent),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAiSection(UserSettings settings) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          ListTile(
            title: const Text('Штучний Інтелект (Gemini)', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
            leading: const Icon(Icons.auto_awesome, color: AppColors.accent),
            trailing: Icon(_isAiExpanded ? Icons.expand_less : Icons.expand_more, color: AppColors.textSecondary),
            onTap: () {
              setState(() => _isAiExpanded = !_isAiExpanded);
            },
          ),
          if (_isAiExpanded)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Введіть ваш Gemini API Key, щоб мати змогу додавати калорії по фото їжі.',
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                  ),
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: () async {
                      final url = Uri.parse('https://ai.google.dev/gemini-api/docs/api-key');
                      try {
                        await launchUrl(url);
                      } catch (e) {
                        debugPrint('Could not launch $url');
                      }
                    },
                    icon: const Icon(Icons.menu_book, color: AppColors.accent, size: 18),
                    label: const Text(
                      'Офіційна інструкція: як отримати API ключ',
                      style: TextStyle(
                        color: AppColors.accent,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        decoration: TextDecoration.underline,
                        decorationColor: AppColors.accent,
                      ),
                    ),
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      alignment: Alignment.centerLeft,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _geminiKeyController,
                          style: const TextStyle(color: AppColors.textPrimary),
                          decoration: const InputDecoration(
                            labelText: 'Gemini API Key',
                            labelStyle: TextStyle(color: AppColors.textSecondary),
                            enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppColors.border)),
                            focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppColors.accent)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: () {
                          FocusScope.of(context).unfocus();
                          final updated = UserSettings(
                            age: settings.age,
                            weight: settings.weight,
                            height: settings.height,
                            gender: settings.gender,
                            goal: settings.goal,
                            targetCalories: settings.targetCalories,
                            targetProtein: settings.targetProtein,
                            targetFats: settings.targetFats,
                            targetCarbs: settings.targetCarbs,
                            expenseTags: settings.expenseTags,
                            incomeTags: settings.incomeTags,
                            geminiApiKey: _geminiKeyController.text.trim().isEmpty ? null : _geminiKeyController.text.trim(),
                          );
                          ref.read(settingsRepositoryProvider).updateSettings(updated);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('API Ключ збережено!'), backgroundColor: AppColors.greenTask),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.accent,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text('Зберегти', style: TextStyle(color: Colors.white)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

    Widget _buildAutoExpenseSection() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          ListTile(
            title: const Text(
              'Автоматичний облік витрат (Google Pay / Банки)',
              style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              _isAutoExpenseEnabled ? 'Увімкнено (слухає сповіщення)' : 'Вимкнено',
              style: TextStyle(
                color: _isAutoExpenseEnabled ? AppColors.greenTask : AppColors.textSecondary,
                fontSize: 12,
              ),
            ),
            leading: const Icon(Icons.notifications_active_rounded, color: AppColors.accent),
            trailing: Icon(
              _isAutoExpenseExpanded ? Icons.expand_less : Icons.expand_more,
              color: AppColors.textSecondary,
            ),
            onTap: () {
              setState(() => _isAutoExpenseExpanded = !_isAutoExpenseExpanded);
            },
          ),
          if (_isAutoExpenseExpanded)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Додаток може автоматично перехоплювати сповіщення про списання коштів від банків (Monobank, Приват24, ПУМБ тощо) та Google Pay / Wallet, одразу створювати задачу витрати з точною сумою та назвою магазину, залишаючи вам лише обрати категорію витрати в один клік!',
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.4),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceVariant,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _hasNotificationPermission ? AppColors.greenTask.withAlpha(80) : AppColors.warning.withAlpha(80),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _hasNotificationPermission ? Icons.check_circle_rounded : Icons.warning_amber_rounded,
                          color: _hasNotificationPermission ? AppColors.greenTask : AppColors.warning,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _hasNotificationPermission
                                    ? 'Доступ до сповіщень надано'
                                    : 'Потрібен доступ до сповіщень',
                                style: TextStyle(
                                  color: _hasNotificationPermission ? AppColors.greenTask : AppColors.warning,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                              Text(
                                _hasNotificationPermission
                                    ? 'Система дозволяє читати пуші від банків'
                                    : 'Натисніть кнопку нижче, щоб надати дозвіл в Android',
                                style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (!_hasNotificationPermission)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.security_rounded, size: 18),
                        label: const Text('Надати дозвіл у налаштуваннях Android'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.accent,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () async {
                          await NotificationExpenseService().requestPermission();
                          await Future.delayed(const Duration(seconds: 1));
                          _checkAutoExpenseStatus();
                        },
                      ),
                    ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Автоматично додавати витрати',
                        style: TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w600),
                      ),
                      Switch(
                        value: _isAutoExpenseEnabled,
                        activeColor: AppColors.accent,
                        onChanged: (val) async {
                          if (val && !_hasNotificationPermission) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Спочатку надайте дозвіл до сповіщень!'),
                                backgroundColor: AppColors.error,
                              ),
                            );
                            await NotificationExpenseService().requestPermission();
                            return;
                          }
                          await NotificationExpenseService().setAutoTrackEnabled(val);
                          setState(() => _isAutoExpenseEnabled = val);
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Divider(color: AppColors.border),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.science_outlined, size: 18, color: AppColors.accent),
                      label: const Text(
                        '🧪 Симулювати витрату 150 грн (Сільпо)',
                        style: TextStyle(color: AppColors.accent),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppColors.accent),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () async {
                        final taskRepo = ref.read(taskRepositoryProvider);
                        await NotificationExpenseService().simulateTestTransaction(taskRepo, isIncome: false);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('🎉 Тестову витрату додано! Перевір вкладку "Сьогодні".'),
                              backgroundColor: AppColors.greenTask,
                            ),
                          );
                        }
                      },
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.savings_outlined, size: 18, color: AppColors.greenTask),
                      label: const Text(
                        '💰 Симулювати дохід 15 000 грн (Зарплата)',
                        style: TextStyle(color: AppColors.greenTask),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppColors.greenTask),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () async {
                        final taskRepo = ref.read(taskRepositoryProvider);
                        await NotificationExpenseService().simulateTestTransaction(taskRepo, isIncome: true);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('🎉 Тестовий дохід додано! Перевір вкладку "Сьогодні".'),
                              backgroundColor: AppColors.greenTask,
                            ),
                          );
                        }
                      },
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFinanceTagsSection(UserSettings settings) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          ListTile(
            title: const Text('Фінансові теги', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
            leading: const Icon(Icons.account_balance_wallet, color: AppColors.greenTask),
            trailing: Icon(_isFinanceExpanded ? Icons.expand_less : Icons.expand_more, color: AppColors.textSecondary),
            onTap: () {
              setState(() => _isFinanceExpanded = !_isFinanceExpanded);
            },
          ),
          if (_isFinanceExpanded)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Теги витрат',
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
                  ),
                  const SizedBox(height: 8),
                  _buildTagList(settings.expenseTags, true, settings),
                  const SizedBox(height: 16),
                  const Text(
                    'Теги доходів',
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
                  ),
                  const SizedBox(height: 8),
                  _buildTagList(settings.incomeTags, false, settings),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTagList(List<String> tags, bool isExpense, UserSettings settings) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        ...tags.map((tag) => Chip(
              label: Text(tag),
              onDeleted: () {
                final newList = List<String>.from(tags)..remove(tag);
                final updated = isExpense 
                    ? settings.copyWith(expenseTags: newList)
                    : settings.copyWith(incomeTags: newList);
                ref.read(settingsRepositoryProvider).updateSettings(updated);
              },
              deleteIconColor: AppColors.redTask,
              backgroundColor: AppColors.background,
              side: const BorderSide(color: AppColors.border),
            )),
        ActionChip(
          label: const Icon(Icons.add, size: 18, color: AppColors.textPrimary),
          backgroundColor: AppColors.surface,
          side: const BorderSide(color: AppColors.border),
          onPressed: () => _showAddTagDialog(isExpense, tags, settings),
        ),
      ],
    );
  }

  Future<void> _showAddTagDialog(bool isExpense, List<String> currentTags, UserSettings settings) async {
    final controller = TextEditingController();
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(
          isExpense ? 'Новий тег витрат' : 'Новий тег доходів',
          style: const TextStyle(color: AppColors.textPrimary),
        ),
        content: TextField(
          controller: controller,
          style: const TextStyle(color: AppColors.textPrimary),
          decoration: const InputDecoration(
            hintText: 'Назва тегу',
            hintStyle: TextStyle(color: AppColors.textSecondary),
            enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppColors.border)),
            focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppColors.accent)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Скасувати', style: TextStyle(color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () {
              final newTag = controller.text.trim();
              if (newTag.isNotEmpty && !currentTags.contains(newTag)) {
                final newList = List<String>.from(currentTags)..add(newTag);
                final updated = isExpense 
                    ? settings.copyWith(expenseTags: newList)
                    : settings.copyWith(incomeTags: newList);
                ref.read(settingsRepositoryProvider).updateSettings(updated);
              }
              Navigator.pop(context);
            },
            child: const Text('Додати', style: TextStyle(color: AppColors.accent)),
          ),
        ],
      ),
    );
  }

  Widget _buildCaloriesSection(UserSettings settings) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          ListTile(
            title: const Text('Калькулятор калорій', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
            leading: const Icon(Icons.local_fire_department_rounded, color: AppColors.accent),
            trailing: Icon(_isCaloriesExpanded ? Icons.expand_less : Icons.expand_more, color: AppColors.textSecondary),
            onTap: () {
              setState(() => _isCaloriesExpanded = !_isCaloriesExpanded);
            },
          ),
          if (_isCaloriesExpanded)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(child: _buildTextField('Вік (роки)', _ageController, TextInputType.number)),
                      const SizedBox(width: 16),
                      Expanded(child: _buildTextField('Вага (кг)', _weightController, const TextInputType.numberWithOptions(decimal: true))),
                      const SizedBox(width: 16),
                      Expanded(child: _buildTextField('Зріст (см)', _heightController, const TextInputType.numberWithOptions(decimal: true))),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text('Стать', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                  Row(
                    children: [
                      Expanded(
                        child: RadioListTile<String>(
                          title: const Text('Чол', style: TextStyle(color: AppColors.textPrimary, fontSize: 14)),
                          value: 'male',
                          groupValue: _gender,
                          activeColor: AppColors.accent,
                          contentPadding: EdgeInsets.zero,
                          onChanged: (v) => setState(() => _gender = v!),
                        ),
                      ),
                      Expanded(
                        child: RadioListTile<String>(
                          title: const Text('Жін', style: TextStyle(color: AppColors.textPrimary, fontSize: 14)),
                          value: 'female',
                          groupValue: _gender,
                          activeColor: AppColors.accent,
                          contentPadding: EdgeInsets.zero,
                          onChanged: (v) => setState(() => _gender = v!),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text('Мета', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                  DropdownButtonFormField<String>(
                    value: _goal,
                    dropdownColor: AppColors.surface,
                    style: const TextStyle(color: AppColors.textPrimary),
                    decoration: const InputDecoration(
                      enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppColors.border)),
                      focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppColors.accent)),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'lose', child: Text('Схуднення')),
                      DropdownMenuItem(value: 'maintain', child: Text('Підтримка')),
                      DropdownMenuItem(value: 'gain', child: Text('Набір маси')),
                    ],
                    onChanged: (v) => setState(() => _goal = v!),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => _calculateAndSave(settings),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.accent,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Розрахувати та Зберегти', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Divider(color: AppColors.border),
                  const SizedBox(height: 16),
                  const Text('Твоя щоденна норма:', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  _buildMacroRow('Калорії', '${settings.targetCalories} ккал', AppColors.accent),
                  _buildMacroRow('Білки', '${settings.targetProtein} г', AppColors.blueTask),
                  _buildMacroRow('Жири', '${settings.targetFats} г', AppColors.yellowTask),
                  _buildMacroRow('Вуглеводи', '${settings.targetCarbs} г', AppColors.greenTask),
                ],
              ),
            )
        ],
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller, TextInputType type) {
    return TextField(
      controller: controller,
      keyboardType: type,
      style: const TextStyle(color: AppColors.textPrimary),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
        enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: AppColors.border)),
        focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: AppColors.accent)),
      ),
    );
  }

  Widget _buildMacroRow(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
              const SizedBox(width: 8),
              Text(label, style: const TextStyle(color: AppColors.textSecondary)),
            ],
          ),
          Text(value, style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
