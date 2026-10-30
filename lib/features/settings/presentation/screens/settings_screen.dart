import '../../../../core/services/notification_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/models/models.dart';
import '../../data/settings_repository.dart';
import '../../../tasks/data/notification_expense_service.dart';
import '../../../tasks/presentation/screens/today_screen.dart';
import '../../../crypto/presentation/providers/crypto_portfolio_provider.dart';
import '../../../crypto/data/crypto_alert_service.dart';

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
  bool _isCryptoExpanded = false;

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
  final _groqKeyController = TextEditingController();
  final _binanceApiKeyController = TextEditingController();
  final _binanceApiSecretController = TextEditingController();
  final _solanaAddressController = TextEditingController();
  final _evmAddressController = TextEditingController();
  final _btcAddressController = TextEditingController();
  final _newAlertCoinController = TextEditingController();

  bool _cryptoAlertsInitialized = false;
  bool _cryptoAlertsEnabled = true;
  bool _cryptoAlertOnTp = true;
  bool _cryptoAlertOnTrailing = true;
  bool _cryptoAlertOnPreStop = true;
  bool _cryptoAlertOnHardStop = true;
  bool _cryptoAlertOnPeak = true;
  bool _cryptoAlertOnDcaBuy = true;
  Set<String> _cryptoAlertCoins = {'BTC', 'ETH', 'SOL'};

  @override
  void dispose() {
    _geminiKeyController.dispose();
    _groqKeyController.dispose();
    _binanceApiKeyController.dispose();
    _binanceApiSecretController.dispose();
    _solanaAddressController.dispose();
    _evmAddressController.dispose();
    _btcAddressController.dispose();
    _newAlertCoinController.dispose();
    _ageController.dispose();
    _weightController.dispose();
    _heightController.dispose();
    super.dispose();
  }

  Future<void> _calculateAndSave(UserSettings current) async {
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
      groqApiKey: _groqKeyController.text.trim().isEmpty ? null : _groqKeyController.text.trim(),
      binanceApiKey: _binanceApiKeyController.text.trim().isEmpty ? null : _binanceApiKeyController.text.trim(),
      binanceApiSecret: _binanceApiSecretController.text.trim().isEmpty ? null : _binanceApiSecretController.text.trim(),
      solanaAddress: _solanaAddressController.text.trim().isEmpty ? '' : _solanaAddressController.text.trim(),
      evmAddress: _evmAddressController.text.trim().isEmpty ? '' : _evmAddressController.text.trim(),
      btcAddress: _btcAddressController.text.trim().isEmpty ? '' : _btcAddressController.text.trim(),
      cryptoAlertsEnabled: _cryptoAlertsEnabled,
      cryptoAlertCoins: _cryptoAlertCoins.toList(),
      cryptoAlertOnTp: _cryptoAlertOnTp,
      cryptoAlertOnTrailing: _cryptoAlertOnTrailing,
      cryptoAlertOnPreStop: _cryptoAlertOnPreStop,
      cryptoAlertOnHardStop: _cryptoAlertOnHardStop,
      cryptoAlertOnPeak: _cryptoAlertOnPeak,
      cryptoAlertOnDcaBuy: _cryptoAlertOnDcaBuy,
      targetCalories: targetCalories,
      targetProtein: targetProtein,
      targetFats: targetFats,
      targetCarbs: targetCarbs,
    );

    await ref.read(settingsRepositoryProvider).updateSettings(updated);
    await CryptoAlertService().updateSettings(
      enabled: _cryptoAlertsEnabled,
      coins: _cryptoAlertCoins,
      notifyTp: _cryptoAlertOnTp,
      notifyTrailing: _cryptoAlertOnTrailing,
      notifyPreStop: _cryptoAlertOnPreStop,
      notifyHardStop: _cryptoAlertOnHardStop,
      notifyPeak: _cryptoAlertOnPeak,
      notifyDcaBuy: _cryptoAlertOnDcaBuy,
      currentSettings: updated,
      settingsRepo: ref.read(settingsRepositoryProvider),
    );
    // Автоматично перезавантажуємо криптопортфель та Web3 з новими адресами
    await ref.read(cryptoPortfolioProvider.notifier).refreshPortfolio();
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Дані оновлено! Криптопортфель синхронізовано з блокчейном.'), backgroundColor: AppColors.greenTask),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final settingsAsync = ref.watch(settingsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'ATHLETE PROFILE',
                  style: GoogleFonts.chakraPetch(
                    color: AppColors.accent,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.0,
                  ),
                ),
                Text(
                  'ПАРАМЕТРИ ТА ЦІЛІ',
                  style: GoogleFonts.chakraPetch(
                    color: AppColors.textPrimary,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.8,
                  ),
                ),
              ],
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF161922),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: AppColors.accent.withAlpha(180), width: 1.5),
              ),
              child: Text(
                'V2.4 // PRO',
                style: GoogleFonts.chakraPetch(
                  color: AppColors.accent,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                ),
              ),
            ),
          ],
        ),
      ),
      body: settingsAsync.when(
        data: (settings) {
          // Initialize controllers if empty
          if (_ageController.text.isEmpty) _ageController.text = settings.age.toString();
          if (_weightController.text.isEmpty) _weightController.text = settings.weight.toString();
          if (_heightController.text.isEmpty) _heightController.text = settings.height.toString();
          _gender = settings.gender;
          _goal = settings.goal;
          if (_geminiKeyController.text.isEmpty && settings.geminiApiKey != null) _geminiKeyController.text = settings.geminiApiKey!;
          if (_groqKeyController.text.isEmpty && settings.groqApiKey != null) _groqKeyController.text = settings.groqApiKey!;
          if (_binanceApiKeyController.text.isEmpty && settings.binanceApiKey != null) _binanceApiKeyController.text = settings.binanceApiKey!;
          if (_binanceApiSecretController.text.isEmpty && settings.binanceApiSecret != null) _binanceApiSecretController.text = settings.binanceApiSecret!;
          if (_solanaAddressController.text.isEmpty && settings.solanaAddress != null && settings.solanaAddress!.isNotEmpty) {
            _solanaAddressController.text = settings.solanaAddress!;
          }
          if (_evmAddressController.text.isEmpty && settings.evmAddress != null && settings.evmAddress!.isNotEmpty) {
            _evmAddressController.text = settings.evmAddress!;
          }
          if (_btcAddressController.text.isEmpty && settings.btcAddress != null && settings.btcAddress!.isNotEmpty) {
            _btcAddressController.text = settings.btcAddress!;
          }
          if (!_cryptoAlertsInitialized) {
            _cryptoAlertsEnabled = settings.cryptoAlertsEnabled;
            _cryptoAlertCoins = Set<String>.from(settings.cryptoAlertCoins);
            _cryptoAlertOnTp = settings.cryptoAlertOnTp;
            _cryptoAlertOnTrailing = settings.cryptoAlertOnTrailing;
            _cryptoAlertOnPreStop = settings.cryptoAlertOnPreStop;
            _cryptoAlertOnHardStop = settings.cryptoAlertOnHardStop;
            _cryptoAlertOnPeak = settings.cryptoAlertOnPeak;
            _cryptoAlertOnDcaBuy = settings.cryptoAlertOnDcaBuy;
            _cryptoAlertsInitialized = true;
          }

          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              _buildCaloriesSection(settings),
              const SizedBox(height: 20),
              _buildCryptoSection(settings),
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
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border, width: 1.5),
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
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Всі нагадування синхронізовано! Активних: $count'),
                      backgroundColor: AppColors.greenTask,
                    ),
                  );
                }
              },
              icon: const Icon(Icons.sync_rounded, color: Colors.black),
              label: const Text('Синхронізувати та відновити нагадування', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
                if (mounted) {
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
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border, width: 1.5),
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
                        onPressed: () async {
                          FocusScope.of(context).unfocus();
                          final updated = settings.copyWith(
                            geminiApiKey: _geminiKeyController.text.trim().isEmpty ? null : _geminiKeyController.text.trim(),
                          );
                          await ref.read(settingsRepositoryProvider).updateSettings(updated);
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('API Ключ збережено!'), backgroundColor: AppColors.greenTask),
                            );
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.accent,
                          foregroundColor: Colors.black,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        child: const Text('Зберегти', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
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
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border, width: 1.5),
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
                        icon: const Icon(Icons.security_rounded, size: 18, color: Colors.black),
                        label: const Text('Надати дозвіл у налаштуваннях Android', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.accent,
                          foregroundColor: Colors.black,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
                  const SizedBox(height: 12),
                  const Divider(color: AppColors.border),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.sync_rounded, size: 18),
                      label: const Text('🔍 Просканувати шторку сповіщень зараз'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.surfaceVariant,
                        foregroundColor: AppColors.textPrimary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: const BorderSide(color: AppColors.border),
                        ),
                      ),
                      onPressed: () async {
                        final scanned = await NotificationExpenseService().scanActiveNotifications();
                        if (mounted) {
                          setState(() {});
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                scanned.isNotEmpty
                                    ? 'Оброблено нових сповіщень: ${scanned.length}'
                                    : 'Шторку перевірено. Нових фінансових сповіщень не виявлено.',
                              ),
                              backgroundColor: scanned.isNotEmpty ? AppColors.greenTask : AppColors.surfaceVariant,
                            ),
                          );
                        }
                      },
                    ),
                  ),
                  if (NotificationExpenseService().diagnosticLogs.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Останні зчитані сповіщення:',
                          style: TextStyle(color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.bold),
                        ),
                        TextButton(
                          onPressed: () {
                            setState(() {
                              NotificationExpenseService().diagnosticLogs.clear();
                            });
                          },
                          child: const Text('Очистити', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Container(
                      constraints: const BoxConstraints(maxHeight: 250),
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: NotificationExpenseService().diagnosticLogs.length,
                        separatorBuilder: (_, __) => const Divider(color: AppColors.border, height: 8),
                        itemBuilder: (ctx, idx) {
                          final log = NotificationExpenseService().diagnosticLogs[idx];
                          return Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: log.parsed
                                  ? AppColors.greenTask.withAlpha(25)
                                  : AppColors.surfaceVariant.withAlpha(50),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: log.parsed
                                    ? AppColors.greenTask.withAlpha(80)
                                    : Colors.transparent,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      log.parsed ? Icons.check_circle_rounded : Icons.info_outline_rounded,
                                      size: 14,
                                      color: log.parsed ? AppColors.greenTask : AppColors.textSecondary,
                                    ),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        '${log.packageName.split('.').last} • ${log.title.isNotEmpty ? log.title : "(без заголовка)"}',
                                        style: const TextStyle(
                                          color: AppColors.textPrimary,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                                if (log.content.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Text(
                                      log.content,
                                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                if (log.parsedSummary != null)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Text(
                                      '✅ ${log.parsedSummary}',
                                      style: const TextStyle(
                                        color: AppColors.greenTask,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ],
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
    String goalText = 'ПІДТРИМКА ФОРМИ (БАЛАНС)';
    if (settings.goal == 'lose') {
      goalText = 'ДЕФІЦИТ (СПАЛЕННЯ ЖИРУ ТА РЕЛЬЄФ)';
    } else if (settings.goal == 'gain') {
      goalText = 'РЕКОМПОЗИЦІЯ (РІСТ СУХИХ М\'ЯЗІВ)';
    }

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.accent.withAlpha(180), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(90),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(11),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(width: 4, color: AppColors.accent),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'ФІЗИЧНІ ДАНІ СПОРТСМЕНА',
                            style: GoogleFonts.chakraPetch(
                              color: AppColors.accent,
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.8,
                            ),
                          ),
                          InkWell(
                            onTap: () => setState(() => _isCaloriesExpanded = !_isCaloriesExpanded),
                            child: Row(
                              children: [
                                Text(
                                  _isCaloriesExpanded ? 'ЗГОРНУТИ' : 'РЕДАГУВАТИ',
                                  style: GoogleFonts.chakraPetch(
                                    color: AppColors.textSecondary,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                Icon(
                                  _isCaloriesExpanded ? Icons.expand_less : Icons.expand_more,
                                  color: AppColors.textSecondary,
                                  size: 18,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'ВІК: ${settings.age} Р  •  ВАГА: ${settings.weight} КГ  •  ЗРІСТ: ${settings.height} СМ',
                        style: GoogleFonts.chakraPetch(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'ЦІЛЬ: $goalText',
                        style: GoogleFonts.chakraPetch(
                          color: AppColors.accent,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Divider(color: AppColors.border, height: 1),
                      const SizedBox(height: 10),
                      Text(
                        'РОЗРАХОВАНА НОРМА ТІЛА:',
                        style: GoogleFonts.chakraPetch(
                          color: const Color(0xFFA0AAB9),
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${settings.targetCalories} ККАЛ  |  ${settings.targetProtein}г БІЛКА  |  ${settings.targetFats}г ЖИРІВ  |  ${settings.targetCarbs}г ВУГЛЕВОДІВ',
                        style: GoogleFonts.chakraPetch(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.4,
                        ),
                      ),
                      if (_isCaloriesExpanded) ...[
                        const SizedBox(height: 16),
                        const Divider(color: AppColors.border, height: 1),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(child: _buildTextField('Вік (роки)', _ageController, TextInputType.number)),
                            const SizedBox(width: 16),
                            Expanded(child: _buildTextField('Вага (кг)', _weightController, const TextInputType.numberWithOptions(decimal: true))),
                            const SizedBox(width: 16),
                            Expanded(child: _buildTextField('Зріст (см)', _heightController, const TextInputType.numberWithOptions(decimal: true))),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Text('Стать', style: GoogleFonts.chakraPetch(color: AppColors.textSecondary, fontSize: 12)),
                        Row(
                          children: [
                            Expanded(
                              child: RadioListTile<String>(
                                title: Text('Чол', style: GoogleFonts.chakraPetch(color: AppColors.textPrimary, fontSize: 13)),
                                value: 'male',
                                groupValue: _gender,
                                activeColor: AppColors.accent,
                                contentPadding: EdgeInsets.zero,
                                onChanged: (v) => setState(() => _gender = v!),
                              ),
                            ),
                            Expanded(
                              child: RadioListTile<String>(
                                title: Text('Жін', style: GoogleFonts.chakraPetch(color: AppColors.textPrimary, fontSize: 13)),
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
                        Text('Мета тренувань', style: GoogleFonts.chakraPetch(color: AppColors.textSecondary, fontSize: 12)),
                        DropdownButtonFormField<String>(
                          value: _goal,
                          dropdownColor: AppColors.surface,
                          style: GoogleFonts.chakraPetch(color: AppColors.textPrimary, fontSize: 13),
                          decoration: const InputDecoration(
                            enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppColors.border)),
                            focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppColors.accent)),
                          ),
                          items: const [
                            DropdownMenuItem(value: 'lose', child: Text('Схуднення (дефіцит)')),
                            DropdownMenuItem(value: 'maintain', child: Text('Підтримка форми')),
                            DropdownMenuItem(value: 'gain', child: Text('Набір маси (рекомпозиція)')),
                          ],
                          onChanged: (v) => setState(() => _goal = v!),
                        ),
                        const SizedBox(height: 20),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () => _calculateAndSave(settings),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.accent,
                              foregroundColor: Colors.black,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            child: Text(
                              'РОЗРАХУВАТИ ТА ЗБЕРЕГТИ',
                              style: GoogleFonts.chakraPetch(color: Colors.black, fontWeight: FontWeight.w900, letterSpacing: 0.6),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
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

  Widget _buildCryptoAlertsSubSection(UserSettings settings) {
    final portfolioState = ref.watch(cryptoPortfolioProvider);
    final allHoldings = portfolioState.overview.holdings;
    final allDca = portfolioState.groupedDcaCoins;

    final Set<String> candidates = {'BTC', 'ETH', 'SOL'};
    for (final h in allHoldings) {
      final sym = h.symbol.toUpperCase();
      if (!const {'USDT', 'USDC', 'FDUSD', 'DAI', 'BUSD'}.contains(sym)) {
        candidates.add(sym);
      }
    }
    for (final d in allDca) {
      final sym = d.symbol.toUpperCase();
      if (!const {'USDT', 'USDC', 'FDUSD', 'DAI', 'BUSD'}.contains(sym)) {
        candidates.add(sym);
      }
    }
    for (final c in _cryptoAlertCoins) {
      final sym = c.toUpperCase();
      if (!const {'USDT', 'USDC', 'FDUSD', 'DAI', 'BUSD'}.contains(sym)) {
        candidates.add(sym);
      }
    }

    final sortedCoins = candidates.toList()
      ..sort((a, b) {
        final aMon = _cryptoAlertCoins.contains(a);
        final bMon = _cryptoAlertCoins.contains(b);
        if (aMon != bMon) return aMon ? -1 : 1;
        return a.compareTo(b);
      });

    final alertTargets = CryptoAlertService().targets;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.notifications_active_rounded,
                color: AppColors.accent, size: 18),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                '4. Фонові сповіщення та алерти (Take-Profit / Stop-Loss):',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        const Text(
          'Додаток моніторить ціни монет навіть коли він згорнутий або закритий. '
          'При досягненні Take-Profit, виснаженні піку, пробитті трейлінг-стопу чи небезпечної зони Stop-Loss '
          'ви отримаєте системне сповіщення з точною рекомендацією щодо закриття позиції.',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 12, height: 1.35),
        ),
        const SizedBox(height: 12),

        // Головний перемикач фонового моніторингу
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: _cryptoAlertsEnabled
                ? AppColors.accent.withValues(alpha: 0.10)
                : AppColors.surfaceVariant,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: _cryptoAlertsEnabled
                  ? AppColors.accent.withValues(alpha: 0.4)
                  : AppColors.border,
            ),
          ),
          child: Row(
            children: [
              Icon(
                _cryptoAlertsEnabled
                    ? Icons.notifications_on_rounded
                    : Icons.notifications_off_rounded,
                color: _cryptoAlertsEnabled ? AppColors.accent : AppColors.textDisabled,
                size: 22,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Фоновий моніторинг цін',
                      style: TextStyle(
                        color: _cryptoAlertsEnabled
                            ? AppColors.textPrimary
                            : AppColors.textSecondary,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    Text(
                      _cryptoAlertsEnabled
                          ? 'Алерти активні для ${_cryptoAlertCoins.length} обраних монет'
                          : 'Всі сповіщення вимкнено',
                      style: TextStyle(
                        color: _cryptoAlertsEnabled
                            ? AppColors.accentLight
                            : AppColors.textDisabled,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              Switch(
                value: _cryptoAlertsEnabled,
                activeColor: AppColors.accent,
                onChanged: (val) {
                  setState(() => _cryptoAlertsEnabled = val);
                },
              ),
            ],
          ),
        ),

        if (_cryptoAlertsEnabled) ...[
          const SizedBox(height: 14),
          const Text(
            'КАТЕГОРІЇ СИГНАЛІВ:',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.bold,
              fontSize: 11,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 6),
          _buildAlertOptionTile(
            title: '🎯 Take-Profit 1/2/3',
            subtitle: 'Фіксація цілей прибутку при рості',
            value: _cryptoAlertOnTp,
            onChanged: (v) => setState(() => _cryptoAlertOnTp = v),
          ),
          _buildAlertOptionTile(
            title: '💎 Зона добору за DCA (Відкуп дна)',
            subtitle: 'Ціна біля 1-го DCA лімітного ордера або зона перепроданості (RSI < 32)',
            value: _cryptoAlertOnDcaBuy,
            onChanged: (v) => setState(() => _cryptoAlertOnDcaBuy = v),
          ),
          _buildAlertOptionTile(
            title: '🔒 Трейлінг-стоп Chandelier',
            subtitle: 'Захист прибутку при відкаті від 20-денного піку',
            value: _cryptoAlertOnTrailing,
            onChanged: (v) => setState(() => _cryptoAlertOnTrailing = v),
          ),
          _buildAlertOptionTile(
            title: '🔥 Пікове виснаження (SELL PEAK)',
            subtitle: 'Перекупленість RSI > 75 та опір Боллінджера',
            value: _cryptoAlertOnPeak,
            onChanged: (v) => setState(() => _cryptoAlertOnPeak = v),
          ),
          _buildAlertOptionTile(
            title: '🚨 Пре-Стоп (Раннє попередження SL)',
            subtitle: 'Ймовірність падіння >65%, рекомендація скоротити 50%',
            value: _cryptoAlertOnPreStop,
            onChanged: (v) => setState(() => _cryptoAlertOnPreStop = v),
          ),
          _buildAlertOptionTile(
            title: '🛑 Hard Stop-Loss',
            subtitle: 'Критичне пробиття лінії стоп-лосу позиції',
            value: _cryptoAlertOnHardStop,
            onChanged: (v) => setState(() => _cryptoAlertOnHardStop = v),
          ),

          const SizedBox(height: 18),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Text(
                  'МОНІТОРИНГ ПО МОНЕТАХ:',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _cryptoAlertCoins.addAll(sortedCoins);
                      });
                    },
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text('Всі ON', style: TextStyle(color: AppColors.accent, fontSize: 11)),
                  ),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _cryptoAlertCoins.clear();
                      });
                    },
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text('Всі OFF', style: TextStyle(color: AppColors.redTask, fontSize: 11)),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Натискайте перемикач навпроти монети. Сповіщення надходитимуть виключно по тих монетах, які увімкнені.',
            style: TextStyle(color: AppColors.textDisabled, fontSize: 11),
          ),
          const SizedBox(height: 10),

          // Список монет з індивідуальними перемикачами
          Container(
            decoration: BoxDecoration(
              color: AppColors.surfaceVariant.withValues(alpha: 0.45),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.border),
            ),
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: sortedCoins.length,
              separatorBuilder: (_, __) =>
                  const Divider(color: AppColors.border, height: 1),
              itemBuilder: (ctx, idx) {
                final sym = sortedCoins[idx];
                final isMonitored = _cryptoAlertCoins.contains(sym);
                final target = alertTargets[sym];

                String subtitle = 'Монета портфеля';
                if (target != null) {
                  final tpStr = target.tp1 > 0 ? 'TP1: \$${_formatPriceCompact(target.tp1)}' : '';
                  final slStr = target.stopLoss > 0 ? 'SL: \$${_formatPriceCompact(target.stopLoss)}' : '';
                  final parts = [tpStr, slStr].where((s) => s.isNotEmpty).join(' • ');
                  if (parts.isNotEmpty) subtitle = parts;
                }

                return ListTile(
                  dense: true,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                  leading: CircleAvatar(
                    radius: 14,
                    backgroundColor: isMonitored
                        ? AppColors.accent.withValues(alpha: 0.15)
                        : AppColors.surfaceVariant,
                    child: Text(
                      sym.length > 3 ? sym.substring(0, 3) : sym,
                      style: TextStyle(
                        color: isMonitored
                            ? AppColors.accentLight
                            : AppColors.textDisabled,
                        fontSize: 9.5,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  title: Text(
                    sym,
                    style: TextStyle(
                      color: isMonitored
                          ? AppColors.textPrimary
                          : AppColors.textSecondary,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                  subtitle: Text(
                    subtitle,
                    style: const TextStyle(
                      color: AppColors.textDisabled,
                      fontSize: 10.5,
                    ),
                  ),
                  trailing: Switch(
                    value: isMonitored,
                    activeColor: AppColors.accent,
                    onChanged: (val) {
                      setState(() {
                        if (val) {
                          _cryptoAlertCoins.add(sym);
                        } else {
                          _cryptoAlertCoins.remove(sym);
                        }
                      });
                      CryptoAlertService().toggleCoinMonitoring(sym, val);
                    },
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: 12),
          // Додавання нової монети вручну
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _newAlertCoinController,
                  textCapitalization: TextCapitalization.characters,
                  style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
                  decoration: const InputDecoration(
                    hintText: 'Додати монету (напр. AVAX, TON)',
                    hintStyle: TextStyle(color: AppColors.textDisabled, fontSize: 12),
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: AppColors.border),
                      borderRadius: BorderRadius.all(Radius.circular(8)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: AppColors.accent),
                      borderRadius: BorderRadius.all(Radius.circular(8)),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.surfaceVariant,
                  foregroundColor: AppColors.accent,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: const BorderSide(color: AppColors.border),
                  ),
                ),
                onPressed: () {
                  final text = _newAlertCoinController.text.trim().toUpperCase();
                  if (text.isNotEmpty) {
                    setState(() {
                      _cryptoAlertCoins.add(text);
                      _newAlertCoinController.clear();
                    });
                    CryptoAlertService().toggleCoinMonitoring(text, true);
                  }
                },
                child: const Text('Додати', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),

          const SizedBox(height: 12),
          // Кнопка тесту сповіщення
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.accent,
              side: BorderSide(color: AppColors.accent.withValues(alpha: 0.5)),
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            icon: const Icon(Icons.notifications_active_outlined, size: 16),
            label: const Text(
              '🧪 Надіслати тестовий крипто-алерт зараз',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            ),
            onPressed: () async {
              await NotificationService().showCryptoNotification(
                id: 777777,
                title: '🔔 Тестове крипто-сповіщення Life Statistics',
                body:
                    'Фонові алерти працюють! Сповіщення про Take-Profit, виснаження піку та Stop-Loss налаштовані належним чином.',
              );
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Тестове сповіщення відправлено у шторку телефону!'),
                    backgroundColor: AppColors.greenTask,
                  ),
                );
              }
            },
          ),
        ],
      ],
    );
  }

  Widget _buildAlertOptionTile({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.borderLight),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: AppColors.textDisabled,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
            Switch(
              value: value,
              activeColor: AppColors.accent,
              onChanged: onChanged,
            ),
          ],
        ),
      ),
    );
  }

  String _formatPriceCompact(double val) {
    if (val == 0) return '0.00';
    final abs = val.abs();
    final sign = val < 0 ? '-' : '';
    if (abs >= 1000) {
      return '$sign${NumberFormat('#,##0.00', 'en_US').format(abs)}';
    } else if (abs >= 0.01) {
      return '$sign${abs.toStringAsFixed(2)}';
    } else {
      return '$sign${abs.toStringAsFixed(4)}';
    }
  }

  Widget _buildCryptoSection(UserSettings settings) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border, width: 1.5),
      ),
      child: Column(
        children: [
          ListTile(
            title: const Text(
              'Криптопортфель та AI (Groq / Binance / Web3)',
              style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              settings.groqApiKey != null ? 'Groq налаштовано • Llama 3.3 70B' : 'Вкажіть ключі для аудиту',
              style: TextStyle(
                color: settings.groqApiKey != null ? AppColors.greenTask : AppColors.textSecondary,
                fontSize: 12,
              ),
            ),
            leading: const Icon(Icons.currency_bitcoin_rounded, color: AppColors.accent),
            trailing: Icon(
              _isCryptoExpanded ? Icons.expand_less : Icons.expand_more,
              color: AppColors.textSecondary,
            ),
            onTap: () {
              setState(() => _isCryptoExpanded = !_isCryptoExpanded);
            },
          ),
          if (_isCryptoExpanded)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '1. Groq Cloud API (Штучний Інтелект):',
                    style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Безкоштовний надшвидкий API (~300 токенів/с) для Meta Llama 3.3 70B. Не навантажує ПК та не падає від лімітів.',
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                  ),
                  const SizedBox(height: 6),
                  TextButton.icon(
                    onPressed: () async {
                      final url = Uri.parse('https://console.groq.com/keys');
                      try {
                        await launchUrl(url);
                      } catch (_) {}
                    },
                    icon: const Icon(Icons.vpn_key_rounded, color: AppColors.accent, size: 16),
                    label: const Text(
                      'Отримати безкоштовний ключ на console.groq.com',
                      style: TextStyle(color: AppColors.accent, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                    style: TextButton.styleFrom(padding: EdgeInsets.zero, alignment: Alignment.centerLeft),
                  ),
                  TextField(
                    controller: _groqKeyController,
                    style: const TextStyle(color: AppColors.textPrimary),
                    decoration: const InputDecoration(
                      labelText: 'Groq API Key (gsk_...)',
                      labelStyle: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                      enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppColors.border)),
                      focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppColors.accent)),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    '2. Біржа Binance (Спот, Ф\'ючерси, Simple Earn):',
                    style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Рекомендується створити API ключ із дозволами ТІЛЬКИ на Читання (Read-Only) без права виведення коштів.',
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                  ),
                  TextField(
                    controller: _binanceApiKeyController,
                    style: const TextStyle(color: AppColors.textPrimary),
                    decoration: const InputDecoration(
                      labelText: 'Binance API Key',
                      labelStyle: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                      enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppColors.border)),
                      focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppColors.accent)),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _binanceApiSecretController,
                    obscureText: true,
                    style: const TextStyle(color: AppColors.textPrimary),
                    decoration: const InputDecoration(
                      labelText: 'Binance API Secret',
                      labelStyle: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                      enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppColors.border)),
                      focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppColors.accent)),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    '3. Web3 Блокчейн-гаманці:',
                    style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  TextField(
                    controller: _solanaAddressController,
                    style: const TextStyle(color: AppColors.textPrimary),
                    decoration: const InputDecoration(
                      labelText: 'Solana адреса (Phantom/Solflare)',
                      labelStyle: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                      enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppColors.border)),
                      focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppColors.accent)),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _evmAddressController,
                    style: const TextStyle(color: AppColors.textPrimary),
                    decoration: const InputDecoration(
                      labelText: 'EVM адреса (MetaMask/Trust Wallet 0x...)',
                      labelStyle: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                      enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppColors.border)),
                      focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppColors.accent)),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _btcAddressController,
                    style: const TextStyle(color: AppColors.textPrimary),
                    decoration: const InputDecoration(
                      labelText: 'Bitcoin адреса (On-chain bc1... або 1.../3...)',
                      labelStyle: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                      enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppColors.border)),
                      focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppColors.accent)),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Divider(color: AppColors.border, height: 1),
                  const SizedBox(height: 18),
                  _buildCryptoAlertsSubSection(settings),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.accent,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      icon: const Icon(Icons.save_rounded, color: Colors.black, size: 18),
                      label: const Text(
                        'Зберегти крипто-налаштування',
                        style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
                      ),
                      onPressed: () => _calculateAndSave(settings),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
