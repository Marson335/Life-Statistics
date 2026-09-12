import 'package:intl/intl.dart';

class DateUtils {
  static String formatDate(DateTime date) {
    return DateFormat('d MMMM yyyy', 'uk').format(date);
  }

  static String formatDateShort(DateTime date) {
    return DateFormat('d MMM', 'uk').format(date);
  }

  static String formatDayOfWeek(DateTime date) {
    return DateFormat('EEEE', 'uk').format(date);
  }

  static String formatDayShort(DateTime date) {
    return DateFormat('EE', 'uk').format(date);
  }

  static DateTime startOfDay(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  static DateTime endOfDay(DateTime date) {
    return DateTime(date.year, date.month, date.day, 23, 59, 59);
  }

  static DateTime startOfWeek(DateTime date) {
    final weekday = date.weekday;
    return startOfDay(date.subtract(Duration(days: weekday - 1)));
  }

  static DateTime endOfWeek(DateTime date) {
    return startOfWeek(date).add(const Duration(days: 7));
  }

  static DateTime startOfMonth(DateTime date) {
    return DateTime(date.year, date.month, 1);
  }

  static DateTime startOfYear(DateTime date) {
    return DateTime(date.year, 1, 1);
  }

  static bool isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  static bool isToday(DateTime date) => isSameDay(date, DateTime.now());

  static String timeAgoOrDate(DateTime date) {
    final now = DateTime.now();
    if (isSameDay(date, now)) return 'Сьогодні';
    if (isSameDay(date, now.subtract(const Duration(days: 1)))) return 'Вчора';
    return formatDate(date);
  }

  static String formatMinutes(int minutes) {
    if (minutes < 60) return '$minutesхв';
    final hours = minutes ~/ 60;
    final mins = minutes % 60;
    return mins == 0 ? '$hoursгод' : '$hoursгод $minsхв';
  }
}
