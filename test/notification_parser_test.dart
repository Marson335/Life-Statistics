import 'package:flutter_test/flutter_test.dart';
import 'package:life_statistics/features/tasks/data/notification_expense_service.dart';

void main() {
  final service = NotificationExpenseService();

  group('NotificationExpenseService Parser Tests', () {
    test('Google Wallet payment: MAGAZYN 0065 should be ignored to avoid duplicate with bank push', () {
      final parsed = service.parseNotification(
        packageName: 'com.google.android.apps.walletnfcrel',
        title: 'MAGAZYN 0065',
        content: '204,30 грн – monobank ••4394',
      );

      expect(parsed, isNull);
    });

    test('Google Wallet payment with trailing dots: KAFE MALENKA PE... should be ignored', () {
      final parsed = service.parseNotification(
        packageName: 'com.google.android.apps.walletnfcrel',
        title: 'KAFE MALENKA PE...',
        content: '40,00 грн – monobank ••4394',
      );

      expect(parsed, isNull);
    });

    test('Google Wallet payment: Zootovari should be ignored', () {
      final parsed = service.parseNotification(
        packageName: 'com.google.android.apps.walletnfcrel',
        title: 'Zootovari',
        content: '125,00 грн – monobank ••4394',
      );

      expect(parsed, isNull);
    });

    test('Google Pay notification with explicit title should be ignored', () {
      final parsed = service.parseNotification(
        packageName: 'com.google.android.gms',
        title: 'Google Pay',
        content: 'Оплата 150 ₴ в Сільпо',
      );

      expect(parsed, isNull);
    });

    test('Google Гаманець notification should be ignored', () {
      final parsed = service.parseNotification(
        packageName: 'com.google.android.apps.wallet',
        title: 'Google Гаманець',
        content: '58.00 ₴ – monobank ••4394',
      );

      expect(parsed, isNull);
    });

    test('Privat24 payment: Комуналка та Інтернет', () {
      final parsed = service.parseNotification(
        packageName: 'ua.privatbank.ap24',
        title: 'Privat24',
        content: 'Privat24: -21.3₴ Комуналка та Інтерне...',
      );

      expect(parsed, isNotNull);
      expect(parsed!.amount, equals(21.3));
      expect(parsed.isIncome, isFalse);
      expect(parsed.merchant, equals('Комуналка та Інтерне'));
    });

    test('Privat24 payment: Платежі за реквізитам...', () {
      final parsed = service.parseNotification(
        packageName: 'ua.privatbank.ap24',
        title: 'Privat24',
        content: 'Privat24: -269₴ Платежі за реквізитам...',
      );

      expect(parsed, isNotNull);
      expect(parsed!.amount, equals(269.0));
      expect(parsed.isIncome, isFalse);
      expect(parsed.merchant, equals('Платежі за реквізитам'));
    });

    test('Privat24 payment with decimal: -269.39₴', () {
      final parsed = service.parseNotification(
        packageName: 'ua.privatbank.ap24',
        title: 'Privat24',
        content: 'Privat24: -269.39₴ Комуналка та Інтер...',
      );

      expect(parsed, isNotNull);
      expect(parsed!.amount, equals(269.39));
      expect(parsed.isIncome, isFalse);
      expect(parsed.merchant, equals('Комуналка та Інтер'));
    });

    test('Monobank payment: Сільпо with balance', () {
      final parsed = service.parseNotification(
        packageName: 'com.ftband.mono',
        title: 'monobank',
        content: '-150 ₴\nСільпо\nБаланс: 1 200 ₴',
      );

      expect(parsed, isNotNull);
      expect(parsed!.amount, equals(150.0));
      expect(parsed.isIncome, isFalse);
      expect(parsed.merchant, equals('Сільпо'));
    });

    test('Monobank payment: Оплата у McDonald\'s', () {
      final parsed = service.parseNotification(
        packageName: 'com.ftband.mono',
        title: 'monobank',
        content: 'Оплата 520.50 ₴ у McDonald\'s. Картка *4394',
      );

      expect(parsed, isNotNull);
      expect(parsed!.amount, equals(520.50));
      expect(parsed.isIncome, isFalse);
      expect(parsed.merchant, equals('McDonald\'s'));
    });

    test('ADB Shell test notification: MAGAZYN 0065', () {
      final parsed = service.parseNotification(
        packageName: 'com.android.shell',
        title: 'MAGAZYN 0065',
        content: '204,30 грн – monobank ••4394',
      );

      expect(parsed, isNotNull);
      expect(parsed!.amount, equals(204.30));
      expect(parsed.isIncome, isFalse);
      expect(parsed.merchant, equals('MAGAZYN 0065'));
    });

    test('Income notification: Зарахування зарплати', () {
      final parsed = service.parseNotification(
        packageName: 'ua.privatbank.ap24',
        title: 'Privat24',
        content: 'Зарахування 15000.00 ₴ від ТОВ «Технолоджі». Баланс: 25000 ₴',
      );

      expect(parsed, isNotNull);
      expect(parsed!.amount, equals(15000.0));
      expect(parsed.isIncome, isTrue);
      expect(parsed.merchant, equals('ТОВ «Технолоджі»'));
    });

    test('Monobank real screenshot format: ☕ 58.00₴ Кешбек 1.... / KAFE MALENKA PEKARNIA', () {
      final parsed = service.parseNotification(
        packageName: 'com.ftband.mono',
        title: '☕ 58.00₴ Кешбек 1....',
        content: 'KAFE MALENKA PEKARNIA\nБаланс 3 336.18₴ 🥷',
      );

      expect(parsed, isNotNull);
      expect(parsed!.amount, equals(58.0));
      expect(parsed.isIncome, isFalse);
      expect(parsed.merchant, equals('KAFE MALENKA PEKARNIA'));
    });

    test('Monobank full title format: ☕ 58.00₴ Кешбек 1.16₴ / KAFE MALENKA PEKARNIA', () {
      final parsed = service.parseNotification(
        packageName: 'com.ftband.mono',
        title: '☕ 58.00₴ Кешбек 1.16₴',
        content: 'KAFE MALENKA PEKARNIA\nБаланс 3 336.18₴ 🥷',
      );

      expect(parsed, isNotNull);
      expect(parsed!.amount, equals(58.0));
      expect(parsed.isIncome, isFalse);
      expect(parsed.merchant, equals('KAFE MALENKA PEKARNIA'));
    });

    test('Monobank without cashback and without minus sign: 🛒 245.50₴ / Сільпо', () {
      final parsed = service.parseNotification(
        packageName: 'com.ftband.mono',
        title: '🛒 245.50₴',
        content: 'Сільпо\nБаланс 3 090.68₴ 🥷',
      );

      expect(parsed, isNotNull);
      expect(parsed!.amount, equals(245.50));
      expect(parsed.isIncome, isFalse);
      expect(parsed.merchant, equals('Сільпо'));
    });

    test('Monobank cashback payout (income): Виплата кешбеку 150.00₴', () {
      final parsed = service.parseNotification(
        packageName: 'com.ftband.mono',
        title: 'Виплата кешбеку 150.00₴',
        content: 'Баланс 3 486.18₴ 🥷',
      );

      expect(parsed, isNotNull);
      expect(parsed!.amount, equals(150.0));
      expect(parsed.isIncome, isTrue);
      expect(parsed.merchant, equals('Кешбек'));
    });

    test('Non-financial notification: should return null', () {
      final parsed = service.parseNotification(
        packageName: 'com.google.android.apps.messaging',
        title: 'Мама',
        content: 'Привіт! Як справи?',
      );

      expect(parsed, isNull);
    });
  });
}
