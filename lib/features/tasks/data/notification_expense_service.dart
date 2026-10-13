import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:notification_listener_service/notification_listener_service.dart';
import 'package:notification_listener_service/notification_event.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/services/notification_service.dart';
import '../../../shared/models/models.dart';
import 'task_repository.dart';

class ParsedTransaction {
  final double amount;
  final String? merchant;
  final String rawText;
  final bool isIncome;

  ParsedTransaction({
    required this.amount,
    this.merchant,
    required this.rawText,
    this.isIncome = false,
  });

  @override
  String toString() =>
      'ParsedTransaction(amount: $amount, merchant: "$merchant", isIncome: $isIncome)';
}

class NotificationExpenseService {
  static final NotificationExpenseService _instance =
      NotificationExpenseService._internal();
  factory NotificationExpenseService() => _instance;
  NotificationExpenseService._internal();

  static const String prefKeyAutoTrack = 'auto_track_expenses';
  static const String prefKeyProcessedIds = 'processed_notification_keys';

  StreamSubscription? _subscription;
  TaskRepository? _taskRepo;
  bool _isListening = false;

  final Set<String> _processedNotificationKeys = {};
  final List<({double amount, bool isIncome, DateTime time})> _recentTransactions = [];

  bool get isListening => _isListening;

  Future<void> _initProcessedKeys() async {
    if (_processedNotificationKeys.isNotEmpty) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getStringList(prefKeyProcessedIds) ?? [];
      _processedNotificationKeys.addAll(saved);
    } catch (_) {}
  }

  Future<void> _saveProcessedKey(String key) async {
    _processedNotificationKeys.add(key);
    // Keep set bounded
    if (_processedNotificationKeys.length > 200) {
      final list = _processedNotificationKeys.toList();
      _processedNotificationKeys.clear();
      _processedNotificationKeys.addAll(list.sublist(list.length - 100));
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(prefKeyProcessedIds, _processedNotificationKeys.toList());
    } catch (_) {}
  }

  Future<bool> isAutoTrackEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(prefKeyAutoTrack) ?? true;
  }

  Future<void> setAutoTrackEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(prefKeyAutoTrack, enabled);
    if (enabled) {
      _taskRepo ??= TaskRepository();
      startListening(_taskRepo!);
      await reconnectService();
      await scanActiveNotifications();
    } else {
      stopListening();
    }
  }

  Future<bool> isPermissionGranted() async {
    if (kIsWeb || !Platform.isAndroid) return false;
    try {
      return await NotificationListenerService.isPermissionGranted();
    } catch (e) {
      debugPrint('Error checking notification listener permission: $e');
      return false;
    }
  }

  Future<void> requestPermission() async {
    if (kIsWeb || !Platform.isAndroid) return;
    try {
      await NotificationListenerService.requestPermission();
    } catch (e) {
      debugPrint('Error requesting notification listener permission: $e');
    }
  }

  Future<void> reconnectService() async {
    if (kIsWeb || !Platform.isAndroid) return;
    try {
      const MethodChannel('x-slayer/notifications_channel')
          .invokeMethod('reconnectService');
      print('[NotificationExpenseService] 🔄 reconnectService invoked.');
    } catch (e) {
      print('[NotificationExpenseService] Error invoking reconnectService: $e');
    }
  }

  void startListening([TaskRepository? taskRepo]) async {
    if (taskRepo != null) {
      _taskRepo = taskRepo;
    } else {
      _taskRepo ??= TaskRepository();
    }

    if (kIsWeb || !Platform.isAndroid) return;

    final enabled = await isAutoTrackEnabled();
    if (!enabled) return;

    final hasPerm = await isPermissionGranted();
    if (!hasPerm) return;

    await _initProcessedKeys();

    if (!_isListening) {
      try {
        await reconnectService();
        _subscription = NotificationListenerService.notificationsStream.listen(
          (event) {
            _handleNotificationEvent(event);
          },
          onError: (err) {
            print('[NotificationExpenseService] ❌ Stream error: $err');
          },
        );
        _isListening = true;
        print('[NotificationExpenseService] 🚀 Started listening to notifications.');
      } catch (e) {
        print('[NotificationExpenseService] ❌ Failed to start listener: $e');
      }
    }

    // Always scan active notifications on launch
    await scanActiveNotifications();
  }

  /// Scans notifications currently sitting in the Android status bar.
  /// This ensures transactions that occurred while the app was in the background
  /// or when the phone was locked are caught immediately.
  Future<void> scanActiveNotifications() async {
    if (kIsWeb || !Platform.isAndroid) return;
    final enabled = await isAutoTrackEnabled();
    if (!enabled) return;
    final hasPerm = await isPermissionGranted();
    if (!hasPerm) return;

    try {
      const channel = MethodChannel('x-slayer/notifications_channel');
      final dynamic raw = await channel.invokeMethod('getActiveNotifications');
      if (raw is List) {
        print('[NotificationExpenseService] 🔍 Scanning ${raw.length} active status bar notifications...');
        for (final item in raw) {
          if (item is Map) {
            final pkg = (item['packageName'] ?? '').toString();
            final title = (item['title'] ?? '').toString();
            final content = (item['content'] ?? '').toString();
            final id = item['id'] is int ? item['id'] as int : 0;
            final postTime = item['postTime'] is int ? item['postTime'] as int : 0;
            await _handleRawNotification(
              packageName: pkg,
              title: title,
              content: content,
              id: id,
              timestamp: postTime,
            );
          }
        }
      }
    } catch (e) {
      print('[NotificationExpenseService] ⚠️ Error scanning active notifications: $e');
    }
  }

  void stopListening() {
    _subscription?.cancel();
    _subscription = null;
    _isListening = false;
    print('[NotificationExpenseService] ⏹ Stopped listening.');
  }

  Future<void> _handleNotificationEvent(ServiceNotificationEvent event) async {
    await _handleRawNotification(
      packageName: event.packageName,
      title: event.title,
      content: event.content,
      id: event.id,
      timestamp: event.timestamp,
      isRemoved: event.hasRemoved,
    );
  }

  Future<void> _handleRawNotification({
    required String packageName,
    required String title,
    required String content,
    required int id,
    required int timestamp,
    bool isRemoved = false,
  }) async {
    if (isRemoved) return;
    if (title.isEmpty && content.isEmpty) return;

    // Check unique key for this notification to avoid re-processing identical notification
    final notiKey = '${packageName}_${id}_${timestamp}_${title}_$content';
    if (_processedNotificationKeys.contains(notiKey)) {
      return;
    }

    print(
        '[NotificationExpenseService] 📥 Received from "$packageName": title="$title", content="$content"');

    final parsed = parseNotification(
      packageName: packageName,
      title: title,
      content: content,
    );

    if (parsed != null) {
      print(
          '[NotificationExpenseService] ✅ Parsed financial transaction: ${parsed.isIncome ? "Income" : "Expense"} ${parsed.amount} грн, merchant="${parsed.merchant}"');
      await _saveProcessedKey(notiKey);
      _taskRepo ??= TaskRepository();
      await _processTransaction(parsed);
    }
  }

  ParsedTransaction? parseNotification({
    required String packageName,
    required String title,
    required String content,
  }) {
    // 1. Normalize spaces, non-breaking spaces (\u00A0), and trim
    final cleanTitle = title.replaceAll('\u00A0', ' ').trim();
    final cleanContent = content.replaceAll('\u00A0', ' ').trim();
    final combinedText = '$cleanTitle $cleanContent';
    final lowerCombined = combinedText.toLowerCase();

    // 2. Known banking & payment applications
    final knownBankPackages = [
      'com.ftband.mono', // Monobank
      'ua.privatbank.ap24', // Privat24
      'com.google.android.apps.walletnfcrel', // Google Wallet / Pay
      'com.google.android.gms', // Google Play Services (Google Pay tap)
      'ua.pumb.mobile', // PUMB
      'com.pumb',
      'ua.sensebank.sense', // Sense Bank
      'com.ukrsibbank.mobile', // Ukrsibbank
      'com.raiffeisen.aval', // Raiffeisen
      'ua.aval',
      'ua.oschadbank.mobile', // Oschadbank
      'com.oschadbank',
      'ua.com.abank', // A-Bank
      'ua.sportbank', // Sportbank
      'ua.izibank', // IziBank
      'com.revolut.revolut', // Revolut
      'com.transferwise.android', // Wise
    ];

    final isBankPackage =
        knownBankPackages.any((pkg) => packageName.contains(pkg));

    final expenseKeywords = [
      'списано',
      'списання',
      'оплата',
      'купівля',
      'покупка',
      'зняття',
      'витрата',
      'переказ',
      'платежі',
      'платіж',
      'комуналка',
      'поповнення мобільного',
      'oplata',
      'kupivlya',
      'pokupka',
      'paid',
      'purchase',
      'spent',
      'charge',
      'transfer',
    ];

    final incomeKeywords = [
      'зарахування',
      'поповнення',
      'надходження',
      'зарплата',
      'зарплат',
      'переказ від',
      'кешбек',
      'cashback',
      'received',
      'top-up',
      'credited',
      'incoming',
      'salary',
      'zarakhuvannia',
      'popovnennia',
    ];

    final hasExpenseKeyword =
        expenseKeywords.any((kw) => lowerCombined.contains(kw));
    final hasIncomeKeyword =
        incomeKeywords.any((kw) => lowerCombined.contains(kw));

    // Must be a bank app OR contain transaction keywords
    if (!isBankPackage && (!hasExpenseKeyword && !hasIncomeKeyword)) {
      return null;
    }

    // 3. Determine direction (Income vs Expense)
    bool isIncome = false;
    if (hasIncomeKeyword && !hasExpenseKeyword) {
      isIncome = true;
    } else if (RegExp(r'\+\s*\d+').hasMatch(cleanContent) ||
        RegExp(r'\+\s*\d+').hasMatch(cleanTitle)) {
      isIncome = true;
    }
    // If explicitly has a minus sign, it is definitely an expense
    if (cleanContent.contains('-') || cleanContent.contains('−')) {
      isIncome = false;
    }

    // 4. Strip balance section so we never extract the account balance instead of the transaction amount
    final textBeforeBalance = cleanContent
        .split(RegExp(
            r'(?:баланс|залишок|доступно|dostupno|balance)\s*:?',
            caseSensitive: false))
        .first
        .trim();
    final searchBody = '$cleanTitle $textBeforeBalance';

    // 5. Extract Amount
    double? amount;

    // Pattern A: Amount followed by currency: "-150 ₴", "150,00 ₴", "-21.3₴", "150.00UAH", "150 грн"
    final regexA = RegExp(
      r'(?:^|[^\w])(?:[+−\-])?\s*(\d{1,3}(?:[\s]\d{3})*(?:[.,]\d{1,2})?|\d+(?:[.,]\d{1,2})?)\s*(?:₴|грн|uah|\$|€)',
      caseSensitive: false,
    );
    final matchA = regexA.firstMatch(searchBody);
    if (matchA != null) {
      final rawNum = matchA.group(1)!.replaceAll(' ', '').replaceAll(',', '.');
      amount = double.tryParse(rawNum);
    }

    // Pattern B: Currency followed by amount: "₴150.00", "$150", "€150.50"
    if (amount == null) {
      final regexB = RegExp(
        r'(?:₴|грн|uah|\$|€)\s*(\d{1,3}(?:[\s]\d{3})*(?:[.,]\d{1,2})?|\d+(?:[.,]\d{1,2})?)',
        caseSensitive: false,
      );
      final matchB = regexB.firstMatch(searchBody);
      if (matchB != null) {
        final rawNum =
            matchB.group(1)!.replaceAll(' ', '').replaceAll(',', '.');
        amount = double.tryParse(rawNum);
      }
    }

    // Pattern C: Action word followed by amount: "Оплата: 150.00", "Списання 200"
    if (amount == null) {
      final regexC = RegExp(
        r'(?:оплата|oplata|списання|покупка|купівля|зняття|зарахування|поповнення|надходження|чек|платіж|переказ)\s*:?\s*(\d+(?:[.,]\d{1,2})?)',
        caseSensitive: false,
      );
      final matchC = regexC.firstMatch(searchBody);
      if (matchC != null) {
        final rawNum =
            matchC.group(1)!.replaceAll(' ', '').replaceAll(',', '.');
        amount = double.tryParse(rawNum);
      }
    }

    // Pattern D: For known bank apps or Wallet, standalone signed number: "-150" or "+15000"
    if (amount == null && isBankPackage) {
      final regexD = RegExp(
        r'(?:^|[^\w])([+−\-]\s*\d+(?:[.,]\d{1,2})?)',
        caseSensitive: false,
      );
      final matchD = regexD.firstMatch(searchBody);
      if (matchD != null) {
        final rawNum = matchD
            .group(1)!
            .replaceAll(RegExp(r'[+−\-\s]'), '')
            .replaceAll(',', '.');
        amount = double.tryParse(rawNum);
      }
    }

    if (amount == null || amount <= 0) return null;

    // 6. Extract Merchant / Category / Recipient
    String? merchant;

    if (isIncome) {
      final senderMatch = RegExp(r'(?:від|from)\s+["«]?([^"»,.\n]+)["»]?',
              caseSensitive: false)
          .firstMatch(cleanContent);
      if (senderMatch != null) {
        merchant = senderMatch.group(1)?.trim();
      }
      if (merchant == null && lowerCombined.contains('зарплат')) {
        merchant = 'Зарплата';
      } else if (merchant == null && lowerCombined.contains('кешбек')) {
        merchant = 'Кешбек';
      }
    } else {
      // 1) PRIVAT24: e.g. "Privat24: -21.3₴ Комуналка та Інтернет" or "Privat24: -269₴ Платежі за реквізитами"
      if (packageName.contains('privat') || cleanContent.startsWith('Privat24:')) {
        final clean = textBeforeBalance
            .replaceFirst(RegExp(r'^Privat24\s*:\s*', caseSensitive: false), '')
            .replaceFirst(RegExp(r'^[+−\-]?\s*\d+(?:[.,]\d{1,2})?\s*(?:₴|грн|uah)?\s*[,.:–\-\s]*', caseSensitive: false), '')
            .trim();

        if (clean.isNotEmpty) {
          String cand = clean.split(RegExp(r'\s*(?:Картка|Karta|\*|\.\.\.)', caseSensitive: false)).first.trim();
          cand = cand.replaceAll(RegExp(r'^[•–\-,\s]+|[•–\-,\s]+$'), '').trim();
          if (cand.isNotEmpty && !cand.toLowerCase().contains('баланс')) {
            merchant = cand;
          }
        }
      }

      // 2) GOOGLE WALLET: title is usually the merchant name
      if (merchant == null && (packageName.contains('wallet') || packageName.contains('gms'))) {
        final lowerTitle = cleanTitle.toLowerCase();
        if (!lowerTitle.contains('google') &&
            !lowerTitle.contains('wallet') &&
            !lowerTitle.contains('гаманець') &&
            cleanTitle.isNotEmpty) {
          merchant = cleanTitle;
        }

        // If title was "Google Гаманець", check after dash or bullet in content
        if (merchant == null) {
          final parts = cleanContent.split(RegExp(r'[•–\-]\s*'));
          for (final p in parts) {
            final trimmed = p.trim();
            final lower = trimmed.toLowerCase();
            if (!lower.contains('картк') &&
                !lower.contains('mastercard') &&
                !lower.contains('visa') &&
                !lower.contains('monobank') &&
                !lower.contains('privat') &&
                !lower.contains('грн') &&
                !lower.contains('uah') &&
                !lower.contains('₴') &&
                !RegExp(r'^\d+').hasMatch(trimmed) &&
                trimmed.isNotEmpty) {
              merchant = trimmed;
              break;
            }
          }
        }
      }

      // 3) MONOBANK: e.g. "-150 ₴\nСільпо\nБаланс..." or "-150 ₴, Сільпо" or "-500 ₴\nПереказ на картку *1234"
      if (merchant == null && packageName.contains('mono')) {
        final clean = textBeforeBalance
            .replaceFirst(RegExp(r'^monobank\s*:\s*', caseSensitive: false), '')
            .replaceFirst(RegExp(r'^[+−\-]?\s*\d+(?:[.,]\d{1,2})?\s*(?:₴|грн|uah)?\s*[,.:–\-\n\s]*', caseSensitive: false), '')
            .trim();

        if (clean.isNotEmpty) {
          String cand = clean.split(RegExp(r'[\n.]')).first.trim();
          cand = cand.replaceAll(RegExp(r'^[•–\-,\s]+|[•–\-,\s]+$'), '').trim();
          if (cand.isNotEmpty && !cand.toLowerCase().contains('баланс') && !cand.toLowerCase().contains('monobank')) {
            merchant = cand;
          }
        }
      }

      // 4) General "у/в/at/in [Merchant]"
      if (merchant == null) {
        final merchantMatch = RegExp(
          r'(?:у|в|at|in|на)\s+["«]?([^"»,.\n]+)["»]?',
          caseSensitive: false,
        ).firstMatch(textBeforeBalance);
        if (merchantMatch != null) {
          final cand = merchantMatch.group(1)?.trim();
          if (cand != null &&
              !cand.toLowerCase().contains('картк') &&
              !cand.toLowerCase().contains('баланс')) {
            merchant = cand;
          }
        }
      }
    }

    // Clean up merchant if formatted with quotes
    if (merchant != null) {
      merchant = merchant.replaceAll(RegExp(r'^[«"]|[»"]$'), '').trim();
      merchant = merchant.replaceAll(RegExp(r'\.{2,}$'), '').trim();
      if (merchant.length > 40) {
        merchant = merchant.substring(0, 40).trim();
      }
    }

    return ParsedTransaction(
      amount: amount,
      merchant: merchant,
      rawText: combinedText,
      isIncome: isIncome,
    );
  }

  Future<void> _processTransaction(ParsedTransaction parsed) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      print('[NotificationExpenseService] ⚠️ User not logged in, skipping transaction storage.');
      return;
    }

    final now = DateTime.now();

    // 1. Precise time-window deduplication (prevents duplicates when Google Wallet and Bank both notify simultaneously)
    _recentTransactions.removeWhere((item) => now.difference(item.time).inSeconds > 90);
    final isDuplicate = _recentTransactions.any((item) =>
        item.isIncome == parsed.isIncome &&
        (item.amount - parsed.amount).abs() < 0.01);

    if (isDuplicate) {
      print('[NotificationExpenseService] ⏭ Duplicate transaction ignored (within 90s dual-notification window): ${parsed.amount} грн');
      return;
    }
    _recentTransactions.add((amount: parsed.amount, isIncome: parsed.isIncome, time: now));

    final taskTitle = parsed.merchant != null && parsed.merchant!.isNotEmpty
        ? parsed.merchant!
        : (parsed.isIncome
            ? 'Дохід +${parsed.amount.toStringAsFixed(0)} грн'
            : 'Витрата ${parsed.amount.toStringAsFixed(0)} грн');

    final task = Task(
      id: now.millisecondsSinceEpoch.toString(),
      userId: user.uid,
      title: taskTitle,
      type: TaskType.finance,
      date: now,
      moneySpent: !parsed.isIncome ? parsed.amount : null,
      moneyEarned: parsed.isIncome ? parsed.amount : null,
      tag: null, // Left null so user can choose tag!
      createdAt: now,
      isCompleted: true,
    );

    try {
      _taskRepo ??= TaskRepository();
      await _taskRepo!.addTask(task);
      print(
          '[NotificationExpenseService] 💾 Successfully created financial task: "${task.title}" (Income: ${parsed.isIncome}, ${parsed.amount} грн)');

      // Show instant notification to the user
      final notiTitle = parsed.isIncome
          ? '💰 Зафіксовано дохід: +${parsed.amount.toStringAsFixed(0)} грн'
          : '💳 Зафіксовано витрату: ${parsed.amount.toStringAsFixed(0)} грн';
      final notiBody = parsed.isIncome
          ? '$taskTitle. Відкрийте додаток, щоб обрати категорію доходу!'
          : '$taskTitle. Відкрийте додаток, щоб обрати категорію витрати!';

      await NotificationService().showInstantNotification(
        id: (now.millisecondsSinceEpoch ~/ 1000) & 0x7FFFFFFF,
        title: notiTitle,
        body: notiBody,
      );
    } catch (e) {
      print('[NotificationExpenseService] ❌ Failed to add auto-tracked task: $e');
    }
  }

  // Simulation methods for testing from settings
  Future<void> simulateTestTransaction(TaskRepository taskRepo,
      {bool isIncome = false}) async {
    _taskRepo = taskRepo;
    final simulated = isIncome
        ? ParsedTransaction(
            amount: 15000.0,
            merchant: 'Зарплата (Тест)',
            rawText: 'Зарахування 15000.00 ₴ від ТОВ «Компанія». Баланс: ...',
            isIncome: true,
          )
        : ParsedTransaction(
            amount: 150.0,
            merchant: 'Сільпо (Тест)',
            rawText: 'Оплата 150.00 ₴ у Сільпо. Картка *1234',
            isIncome: false,
          );
    await _processTransaction(simulated);
  }
}
