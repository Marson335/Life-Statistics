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

class NotificationDiagnosticEntry {
  final DateTime timestamp;
  final String packageName;
  final String title;
  final String content;
  final bool parsed;
  final String? parsedSummary;

  NotificationDiagnosticEntry({
    required this.timestamp,
    required this.packageName,
    required this.title,
    required this.content,
    required this.parsed,
    this.parsedSummary,
  });
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
  final List<NotificationDiagnosticEntry> diagnosticLogs = [];

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

    // Always scan active and background queue notifications on launch
    await scanActiveNotifications();
  }

  /// Scans notifications sitting in native pending queue or in the status bar.
  Future<List<NotificationDiagnosticEntry>> scanActiveNotifications() async {
    if (kIsWeb || !Platform.isAndroid) return [];
    final enabled = await isAutoTrackEnabled();
    if (!enabled) return [];
    final hasPerm = await isPermissionGranted();
    if (!hasPerm) return [];

    await _initProcessedKeys();

    final initialCount = diagnosticLogs.length;

    // 1. Process notifications stored in background native queue while Flutter was asleep
    try {
      final pending = await NotificationListenerService.getPendingNotifications();
      if (pending.isNotEmpty) {
        print('[NotificationExpenseService] 📬 Processing ${pending.length} pending background notifications...');
        bool anyPostponedForAuth = false;
        for (final item in pending) {
          final pkg = (item['packageName'] ?? '').toString();
          final title = (item['title'] ?? '').toString();
          final content = (item['content'] ?? '').toString();
          final id = item['id'] is int ? item['id'] as int : 0;
          final postTime = item['postTime'] is int ? item['postTime'] as int : 0;
          final completed = await _handleRawNotification(
            packageName: pkg,
            title: title,
            content: content,
            id: id,
            timestamp: postTime,
          );
          if (!completed) {
            anyPostponedForAuth = true;
          }
        }
        if (!anyPostponedForAuth) {
          await NotificationListenerService.clearPendingNotifications();
        }
      }
    } catch (e) {
      print('[NotificationExpenseService] ⚠️ Error retrieving pending notifications: $e');
    }

    // 2. Scan notifications currently sitting in the Android status bar
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

    final newCount = diagnosticLogs.length;
    if (newCount > initialCount) {
      return diagnosticLogs.sublist(0, newCount - initialCount);
    }
    return [];
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

  /// Returns `false` only if a valid financial transaction was parsed but postponed because user is not yet authenticated.
  Future<bool> _handleRawNotification({
    required String packageName,
    required String title,
    required String content,
    required int id,
    required int timestamp,
    bool isRemoved = false,
  }) async {
    if (packageName.contains('life_statistics')) return true;
    if (title.isEmpty && content.isEmpty) return true;

    final lowerCheck = '$title $content'.toLowerCase();
    if (lowerCheck.contains('чутливий вміст') ||
        lowerCheck.contains('sensitive notification') ||
        lowerCheck.contains('скрыто содержимое') ||
        lowerCheck.contains('content hidden')) {
      return true;
    }

    await _initProcessedKeys();

    // Check unique key for this notification to avoid re-processing identical notification
    final notiKey = '${packageName}_${id}_${timestamp}_${title}_$content';
    if (_processedNotificationKeys.contains(notiKey)) {
      return true;
    }

    final parsed = parseNotification(
      packageName: packageName,
      title: title,
      content: content,
    );

    // If this is a notification removal event and not a financial transaction, ignore quietly
    if (isRemoved && parsed == null) {
      return true;
    }

    // Record diagnostic entry for UI inspection
    final diagnostic = NotificationDiagnosticEntry(
      timestamp: DateTime.now(),
      packageName: packageName,
      title: title,
      content: content,
      parsed: parsed != null,
      parsedSummary: parsed != null
          ? '${parsed.isIncome ? "Дохід" : "Витрата"}: ${parsed.amount.toStringAsFixed(2)} грн (${parsed.merchant ?? "Невідомо"})'
          : null,
    );
    diagnosticLogs.insert(0, diagnostic);
    if (diagnosticLogs.length > 30) {
      diagnosticLogs.removeLast();
    }

    print(
        '[NotificationExpenseService] 📥 Received from "$packageName": title="$title", content="$content" (removed=$isRemoved)');

    if (parsed != null) {
      print(
          '[NotificationExpenseService] ✅ Parsed financial transaction: ${parsed.isIncome ? "Income" : "Expense"} ${parsed.amount} грн, merchant="${parsed.merchant}"');
      _taskRepo ??= TaskRepository();
      final success = await _processTransaction(parsed);
      if (success) {
        await _saveProcessedKey(notiKey);
        return true;
      }
      return false;
    }
    return true;
  }

  ParsedTransaction? parseNotification({
    required String packageName,
    required String title,
    required String content,
  }) {
    if (packageName.contains('life_statistics')) return null;

    // 1. Normalize spaces, non-breaking spaces (\u00A0), en-dash (\u2013), em-dash (\u2014), minus (\u2212)
    final cleanTitle = title.replaceAll('\u00A0', ' ').trim();
    final cleanContent = content.replaceAll('\u00A0', ' ').trim();
    final combinedText = '$cleanTitle $cleanContent';
    final lowerCombined = combinedText.toLowerCase();

    // Ignore Android lockscreen redacted placeholders
    if (lowerCombined.contains('чутливий вміст') ||
        lowerCombined.contains('sensitive notification') ||
        lowerCombined.contains('скрыто содержимое')) {
      return null;
    }

    // 2. Known banking & payment applications
    final knownBankPackages = [
      'com.ftband.mono', // Monobank
      'ua.privatbank.ap24', // Privat24
      'com.google.android.apps.walletnfcrel', // Google Wallet / Pay
      'com.google.android.apps.wallet',
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
      'com.android.shell', // For ADB and test simulation
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
      'кешбек', // In Monobank, "☕ 58.00₴ Кешбек 1.16₴" is a purchase with cashback reward
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
      'поповнення картки',
      'поповнення рахунку',
      'надходження',
      'зарплата',
      'зарплат',
      'переказ від',
      'від:',
      'виплата кешбеку',
      'виведення кешбеку',
      'зарахування кешбеку',
      'received',
      'top-up',
      'credited',
      'incoming',
      'salary',
      'zarakhuvannia',
      'popovnennia',
    ];

    // Check standalone "поповнення" only when not followed by "мобільного"
    final hasStandaloneTopUp = lowerCombined.contains('поповнення') &&
        !lowerCombined.contains('поповнення мобільного');

    final hasExpenseKeyword =
        expenseKeywords.any((kw) => lowerCombined.contains(kw));
    final hasIncomeKeyword =
        incomeKeywords.any((kw) => lowerCombined.contains(kw)) ||
            hasStandaloneTopUp;

    final hasCurrency =
        RegExp(r'(?:₴|грн|uah|\$|€)', caseSensitive: false).hasMatch(combinedText);
    final hasCardOrBankIndicator = lowerCombined.contains('monobank') ||
        lowerCombined.contains('privat') ||
        lowerCombined.contains('приват') ||
        lowerCombined.contains('гаманець') ||
        lowerCombined.contains('wallet') ||
        lowerCombined.contains('картк') ||
        lowerCombined.contains('card') ||
        lowerCombined.contains('пумб') ||
        lowerCombined.contains('ощад') ||
        lowerCombined.contains('баланс') ||
        RegExp(r'(?:••|\*\*|\*)\s*\d{2,4}').hasMatch(combinedText);

    // Must be a recognized bank app OR contain financial keywords OR (has currency + card/bank indicator)
    if (!isBankPackage &&
        !hasExpenseKeyword &&
        !hasIncomeKeyword &&
        !(hasCurrency && hasCardOrBankIndicator)) {
      return null;
    }

    // 3. Determine direction (Income vs Expense)
    bool isIncome = false;
    if (hasIncomeKeyword && !hasExpenseKeyword) {
      isIncome = true;
    } else if (hasIncomeKeyword &&
        (lowerCombined.contains('виплата кешбеку') ||
            lowerCombined.contains('виведення кешбеку') ||
            lowerCombined.contains('зарахування кешбеку') ||
            lowerCombined.contains('зарахування') ||
            hasStandaloneTopUp)) {
      isIncome = true;
    } else if (RegExp(r'\+\s*\d+').hasMatch(cleanContent) ||
        RegExp(r'\+\s*\d+').hasMatch(cleanTitle)) {
      isIncome = true;
    }
    // Explicit negative sign indicates expense
    if (RegExp(r'[−\-–—]\s*\d+').hasMatch(cleanContent) ||
        RegExp(r'[−\-–—]\s*\d+').hasMatch(cleanTitle)) {
      isIncome = false;
    }

    // 4. Strip balance section so we never extract the account balance instead of the transaction amount
    final textBeforeBalance = cleanContent
        .split(RegExp(
            r'(?:баланс|залишок|доступно|dostupno|balance)\s*:?',
            caseSensitive: false))
        .first
        .trim();
    final searchBody = '$cleanTitle\n$textBeforeBalance';

    // 5. Extract Amount
    double? amount;

    // Pattern A: Amount followed by currency: "-150 ₴", "58.00₴", "150,00 ₴", "-21.3₴", "150.00UAH", "204,30 грн"
    final regexA = RegExp(
      r'(?:^|[^\w])(?:[+−\-–—])?\s*(\d{1,3}(?:[\s]\d{3})*(?:[.,]\d{1,2})?|\d+(?:[.,]\d{1,2})?)\s*(?:₴|грн|uah|\$|€)',
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
        r'(?:₴|грн|uah|\$|€)\s*(?:[+−\-–—])?\s*(\d{1,3}(?:[\s]\d{3})*(?:[.,]\d{1,2})?|\d+(?:[.,]\d{1,2})?)',
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
        r'(?:оплата|oplata|списання|покупка|купівля|зняття|зарахування|поповнення|надходження|чек|платіж|переказ)\s*:?\s*(?:[+−\-–—])?\s*(\d+(?:[.,]\d{1,2})?)',
        caseSensitive: false,
      );
      final matchC = regexC.firstMatch(searchBody);
      if (matchC != null) {
        final rawNum =
            matchC.group(1)!.replaceAll(' ', '').replaceAll(',', '.');
        amount = double.tryParse(rawNum);
      }
    }

    // Pattern D: Signed number for bank apps or Wallet: "-150" or "+15000"
    if (amount == null && (isBankPackage || hasCardOrBankIndicator)) {
      final regexD = RegExp(
        r'(?:^|[^\w])([+−\-–—]\s*\d+(?:[.,]\d{1,2})?)',
        caseSensitive: false,
      );
      final matchD = regexD.firstMatch(searchBody);
      if (matchD != null) {
        final rawNum = matchD
            .group(1)!
            .replaceAll(RegExp(r'[+−\-–—\s]'), '')
            .replaceAll(',', '.');
        amount = double.tryParse(rawNum);
      }
    }

    if (amount == null || amount <= 0) return null;

    // 6. Extract Merchant / Category / Recipient
    String? merchant;

    if (isIncome) {
      final senderMatch = RegExp(
        r'(?:від|from)\s*:?\s*([^,.\n]+)',
        caseSensitive: false,
      ).firstMatch(cleanContent);
      if (senderMatch != null) {
        var cand = senderMatch.group(1)?.trim();
        cand = cand
            ?.split(RegExp(r'\s*(?:баланс|картк|\.\.\.)', caseSensitive: false))
            .first
            .trim();
        merchant = cand;
      }
      if (merchant == null && lowerCombined.contains('зарплат')) {
        merchant = 'Зарплата';
      } else if (merchant == null && lowerCombined.contains('кешбек')) {
        merchant = 'Кешбек';
      }
    } else {
      // 1) Explicit "[Action/Currency] у / в / at / in [Merchant]" (e.g. "Оплата 520.50 ₴ у McDonald's" or "Покупка в Сільпо")
      final merchantMatch = RegExp(
        r'(?:оплата|покупка|купівля|списання|платіж|₴|грн|uah|\$|€)\s+(?:у|в|at|in)\s+([^,.\n]+)',
        caseSensitive: false,
      ).firstMatch(textBeforeBalance);
      if (merchantMatch != null) {
        String cand = merchantMatch.group(1)?.trim() ?? '';
        cand = cand
            .split(RegExp(r'\s*(?:картк|card|баланс|\*|\.\.\.)',
                caseSensitive: false))
            .first
            .trim();
        cand = cand.replaceAll(RegExp(r'^[•–\-—,\s]+|[•–\-—,\s]+$'), '').trim();
        if (cand.isNotEmpty && !cand.toLowerCase().contains('баланс')) {
          merchant = cand;
        }
      }

      // 2) PRIVAT24: e.g. "Privat24: -21.3₴ Комуналка та Інтернет" or "-619₴ Платежі за реквізитами"
      if (merchant == null &&
          (packageName.contains('privat') ||
              cleanContent.startsWith('Privat24:') ||
              cleanTitle.contains('Privat24'))) {
        final clean = textBeforeBalance
            .replaceFirst(RegExp(r'^Privat24\s*:\s*', caseSensitive: false), '')
            .replaceFirst(
                RegExp(
                    r'^[+−\-–—]?\s*\d+(?:[\s]\d{3})*(?:[.,]\d{1,2})?\s*(?:₴|грн|uah)?\s*[,.:–\-\s]*',
                    caseSensitive: false),
                '')
            .trim();

        if (clean.isNotEmpty) {
          final firstLine = clean.split('\n').first.trim();
          String cand = firstLine
              .split(RegExp(r'\s*(?:Картка|Karta|\*|\.\.\.)',
                  caseSensitive: false))
              .first
              .trim();
          cand = cand.replaceAll(RegExp(r'^[•–\-,\s]+|[•–\-,\s]+$'), '').trim();
          if (cand.isNotEmpty && !cand.toLowerCase().contains('баланс')) {
            merchant = cand;
          }
        }
      }

      // 3) MONOBANK: e.g. Title="☕ 58.00₴ Кешбек 1...." Body="KAFE MALENKA PEKARNIA\nБаланс 3 336.18₴ 🥷"
      // or Body="-150 ₴\nСільпо\nБаланс..."
      if (merchant == null &&
          (packageName.contains('mono') ||
              lowerCombined.contains('кешбек') ||
              lowerCombined.contains('monobank'))) {
        final lines = textBeforeBalance.split('\n');
        for (final rawLine in lines) {
          var line = rawLine
              .replaceFirst(
                  RegExp(r'^monobank\s*:\s*', caseSensitive: false), '')
              .replaceAll(
                  RegExp(
                      r'кешбек\s*\d*(?:[.,]\d+)?\s*(?:₴|грн|uah|%|\.{2,})?',
                      caseSensitive: false),
                  '')
              .replaceAll(
                  RegExp(
                      r'[+−\-–—]?\s*\d+(?:[\s]\d{3})*(?:[.,]\d{1,2})?\s*(?:₴|грн|uah|\$|€)',
                      caseSensitive: false),
                  '')
              .replaceFirst(
                  RegExp(r'^(?:оплата|списання|купівля|покупка)\s*:?\s*',
                      caseSensitive: false),
                  '')
              .trim();

          // Strip leading/trailing emojis, bullets, dashes, dots
          line = line
              .replaceAll(
                  RegExp(r'^[^\p{L}\p{N}]+|[^\p{L}\p{N})]+$', unicode: true),
                  '')
              .trim();

          final lowerLine = line.toLowerCase();
          if (line.isNotEmpty &&
              !lowerLine.contains('баланс') &&
              !lowerLine.contains('monobank') &&
              !lowerLine.contains('карткою') &&
              !lowerLine.contains('mastercard') &&
              !lowerLine.contains('visa') &&
              !RegExp(r'^\d+$').hasMatch(line)) {
            merchant = line;
            break;
          }
        }
      }

      // 4) GOOGLE WALLET: Title is the merchant (e.g. "MAGAZYN 0065", "KAFE MALENKA PE...", "Zootovari")
      if (merchant == null &&
          (packageName.contains('wallet') ||
              packageName.contains('gms') ||
              cleanContent.contains('••') ||
              cleanTitle.contains('Google'))) {
        final lowerTitle = cleanTitle.toLowerCase();
        if (!lowerTitle.contains('google') &&
            !lowerTitle.contains('wallet') &&
            !lowerTitle.contains('гаманець') &&
            !RegExp(r'(?:₴|грн|uah|\$|€)', caseSensitive: false)
                .hasMatch(cleanTitle) &&
            cleanTitle.isNotEmpty) {
          merchant = cleanTitle;
        }

        // If title was "Google Гаманець", extract from content before or after dash
        if (merchant == null) {
          final parts = cleanContent.split(RegExp(r'[•–\-—]\s*'));
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

      // 5) Fallback: if title is not generic and not an amount, use cleaned title as merchant
      if (merchant == null && cleanTitle.isNotEmpty) {
        var cleanedTitle = cleanTitle
            .replaceAll(
                RegExp(
                    r'кешбек\s*\d*(?:[.,]\d+)?\s*(?:₴|грн|uah|%|\.{2,})?',
                    caseSensitive: false),
                '')
            .replaceAll(
                RegExp(
                    r'[+−\-–—]?\s*\d+(?:[\s]\d{3})*(?:[.,]\d{1,2})?\s*(?:₴|грн|uah|\$|€)',
                    caseSensitive: false),
                '')
            .replaceAll(
                RegExp(r'^[^\p{L}\p{N}]+|[^\p{L}\p{N})]+$', unicode: true), '')
            .trim();
        final lowerTitle = cleanedTitle.toLowerCase();
        if (cleanedTitle.isNotEmpty &&
            !lowerTitle.contains('сповіщення') &&
            !lowerTitle.contains('повідомлення') &&
            !lowerTitle.contains('notification') &&
            !lowerTitle.contains('приват24') &&
            !lowerTitle.contains('privat24') &&
            !lowerTitle.contains('monobank') &&
            !lowerTitle.contains('shell')) {
          merchant = cleanedTitle;
        }
      }
    }

    // Clean up merchant name
    if (merchant != null) {
      if ((merchant.startsWith('"') && merchant.endsWith('"')) ||
          (merchant.startsWith('«') && merchant.endsWith('»'))) {
        merchant = merchant.substring(1, merchant.length - 1).trim();
      }
      merchant = merchant.replaceAll(RegExp(r'\.{2,}$'), '').trim();
      merchant =
          merchant.replaceAll(RegExp(r'^[•–\-—,\s]+|[•–\-—,\s]+$'), '').trim();
      if (merchant.length > 50) {
        merchant = merchant.substring(0, 50).trim();
      }
    }

    return ParsedTransaction(
      amount: amount,
      merchant: merchant,
      rawText: combinedText,
      isIncome: isIncome,
    );
  }

  Future<bool> _processTransaction(ParsedTransaction parsed) async {
    var user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      try {
        user = await FirebaseAuth.instance
            .authStateChanges()
            .firstWhere((u) => u != null)
            .timeout(const Duration(seconds: 4));
      } catch (_) {}
    }

    if (user == null) {
      print('[NotificationExpenseService] ⚠️ User not logged in, postponing transaction.');
      return false;
    }

    final now = DateTime.now();

    // 1. Precise time-window deduplication (prevents duplicates when Google Wallet and Bank both notify simultaneously)
    _recentTransactions.removeWhere((item) => now.difference(item.time).inSeconds > 90);
    final isDuplicate = _recentTransactions.any((item) =>
        item.isIncome == parsed.isIncome &&
        (item.amount - parsed.amount).abs() < 0.01);

    if (isDuplicate) {
      print('[NotificationExpenseService] ⏭ Duplicate transaction ignored (within 90s dual-notification window): ${parsed.amount} грн');
      return true; // Mark as processed since it's an intentional duplicate
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
      return true;
    } catch (e) {
      print('[NotificationExpenseService] ❌ Failed to add auto-tracked task: $e');
      return false;
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
