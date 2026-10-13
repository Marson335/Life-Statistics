import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'dart:io';

import '../../shared/models/models.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  bool _isInitialized = false;

  Future<void> init() async {
    if (_isInitialized) return;

    tz.initializeTimeZones();
    try {
      tz.setLocalLocation(tz.getLocation('Europe/Kyiv'));
    } catch (_) {
      try {
        tz.setLocalLocation(tz.getLocation('Europe/Kiev'));
      } catch (_) {
        tz.setLocalLocation(tz.local);
      }
    }

    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
    );

    await _notificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (response) {
        // Handle notification tap
      },
    );

    // Explicitly create required notification channels on Android
    if (!kIsWeb && Platform.isAndroid) {
      final androidImplementation = _notificationsPlugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();

      await androidImplementation?.createNotificationChannel(
        const AndroidNotificationChannel(
          'life_statistics_tasks',
          'Нагадування про завдання',
          description: 'Сповіщення для нагадування про заплановані задачі',
          importance: Importance.max,
          playSound: true,
          enableVibration: true,
        ),
      );

      await androidImplementation?.createNotificationChannel(
        const AndroidNotificationChannel(
          'life_statistics_finance',
          'Фінансові сповіщення',
          description: 'Сповіщення про нові витрати та доходи',
          importance: Importance.max,
          playSound: true,
          enableVibration: true,
        ),
      );
    }

    _isInitialized = true;
  }

  Future<void> requestPermissions() async {
    if (!kIsWeb && Platform.isAndroid) {
      final androidImplementation = _notificationsPlugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      
      // Request standard notifications permission
      await androidImplementation?.requestNotificationsPermission();
      
      // Check and request exact alarms permission
      final bool? hasExactAlarms = await androidImplementation?.canScheduleExactNotifications();
      if (hasExactAlarms != null && !hasExactAlarms) {
        await androidImplementation?.requestExactAlarmsPermission();
      }
    }
  }

  Future<bool> scheduleTaskReminder(Task task) async {
    if (task.reminderTime == null || task.reminderTime!.isEmpty) return false;
    
    final timeParts = task.reminderTime!.split(':');
    if (timeParts.length < 2) return false;
    final hour = int.tryParse(timeParts[0]);
    final minute = int.tryParse(timeParts[1]);
    if (hour == null || minute == null) return false;

    // Build TZDateTime directly in local location
    var scheduledTz = tz.TZDateTime(
      tz.local,
      task.date.year,
      task.date.month,
      task.date.day,
      hour,
      minute,
    );

    final nowTz = tz.TZDateTime.now(tz.local);

    if (scheduledTz.isBefore(nowTz)) {
      if (task.type == TaskType.green) {
        // If recurring task time passed today, start from tomorrow
        scheduledTz = scheduledTz.add(const Duration(days: 1));
      } else {
        return false; // Past date, don't schedule
      }
    }

    final id = (task.groupId ?? task.id).hashCode & 0x7FFFFFFF;

    DateTimeComponents? matchComponents;
    if (task.type == TaskType.green && task.recurrence != null) {
      if (task.recurrence!.frequency == RecurrenceFrequency.daily) {
        matchComponents = DateTimeComponents.time;
      } else if (task.recurrence!.frequency == RecurrenceFrequency.weekly) {
        matchComponents = DateTimeComponents.dayOfWeekAndTime;
      }
    }

    const notificationDetails = NotificationDetails(
      android: AndroidNotificationDetails(
        'life_statistics_tasks',
        'Нагадування про завдання',
        channelDescription: 'Сповіщення для нагадування про заплановані задачі',
        importance: Importance.max,
        priority: Priority.high,
        playSound: true,
        enableVibration: true,
      ),
    );

    try {
      final androidImpl = _notificationsPlugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      final bool canExact = await androidImpl?.canScheduleExactNotifications() ?? false;
      final scheduleMode = canExact
          ? AndroidScheduleMode.exactAllowWhileIdle
          : AndroidScheduleMode.inexactAllowWhileIdle;

      await _notificationsPlugin.zonedSchedule(
        id,
        'Нагадування: ${task.title}',
        'Час виконати заплановану задачу!',
        scheduledTz,
        notificationDetails,
        androidScheduleMode: scheduleMode,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: matchComponents,
      );
      print('[NotificationService] ⏰ Scheduled reminder for "${task.title}" (id: $id) at $scheduledTz (mode: $scheduleMode)');
      return true;
    } catch (e) {
      print('[NotificationService] ⚠️ Exact schedule failed, retrying with inexact mode: $e');
      try {
        await _notificationsPlugin.zonedSchedule(
          id,
          'Нагадування: ${task.title}',
          'Час виконати заплановану задачу!',
          scheduledTz,
          notificationDetails,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          matchDateTimeComponents: matchComponents,
        );
        print('[NotificationService] ⏰ Inexact reminder scheduled for "${task.title}" (id: $id)');
        return true;
      } catch (e2) {
        print('[NotificationService] ❌ Failed to schedule reminder: $e2');
        return false;
      }
    }
  }

  Future<void> scheduleTestReminder() async {
    final scheduledTz = tz.TZDateTime.now(tz.local).add(const Duration(seconds: 5));
    const notificationDetails = NotificationDetails(
      android: AndroidNotificationDetails(
        'life_statistics_tasks',
        'Нагадування про завдання',
        channelDescription: 'Сповіщення для нагадування про заплановані задачі',
        importance: Importance.max,
        priority: Priority.high,
        playSound: true,
        enableVibration: true,
      ),
    );

    try {
      final androidImpl = _notificationsPlugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      final bool canExact = await androidImpl?.canScheduleExactNotifications() ?? false;
      final scheduleMode = canExact
          ? AndroidScheduleMode.exactAllowWhileIdle
          : AndroidScheduleMode.inexactAllowWhileIdle;

      await _notificationsPlugin.zonedSchedule(
        888888,
        'Тестове сповіщення 🔔',
        'Нагадування у Life Statistics працюють правильно!',
        scheduledTz,
        notificationDetails,
        androidScheduleMode: scheduleMode,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
      print('[NotificationService] 🧪 Test notification scheduled for 5 seconds from now');
    } catch (e) {
      print('[NotificationService] ❌ Failed to schedule test notification: $e');
      // If zonedSchedule fails, show instant notification
      await showInstantNotification(
        id: 888888,
        title: 'Тестове сповіщення 🔔',
        body: 'Миттєве сповіщення працює!',
      );
    }
  }

  Future<int> rescheduleAllTaskReminders(dynamic taskRepo) async {
    if (kIsWeb) return 0;
    try {
      final tasks = await taskRepo.getActiveTasksWithReminders();
      print('[NotificationService] 🔄 Rescheduling reminders for ${tasks.length} active tasks...');
      int count = 0;
      final Set<int> scheduledIds = {};
      for (final task in tasks) {
        final id = (task.groupId ?? task.id).hashCode & 0x7FFFFFFF;
        if (task.type == TaskType.green && scheduledIds.contains(id)) {
          continue;
        }
        final ok = await scheduleTaskReminder(task);
        if (ok) {
          scheduledIds.add(id);
          count++;
        }
      }
      print('[NotificationService] ✅ Successfully rescheduled $count reminders.');
      return count;
    } catch (e) {
      print('[NotificationService] ❌ Error in rescheduleAllTaskReminders: $e');
      return 0;
    }
  }

  Future<void> showInstantNotification({
    required int id,
    required String title,
    required String body,
  }) async {
    try {
      await _notificationsPlugin.show(
        id,
        title,
        body,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'life_statistics_finance',
            'Фінансові сповіщення',
            channelDescription: 'Сповіщення про нові витрати',
            importance: Importance.max,
            priority: Priority.high,
            playSound: true,
            enableVibration: true,
          ),
        ),
      );
    } catch (e) {
      print('Error showing instant notification: $e');
    }
  }

  Future<void> cancelTaskReminder(String taskId) async {
    final id = taskId.hashCode & 0x7FFFFFFF;
    await _notificationsPlugin.cancel(id);
  }
  
  Future<void> cancelAllNotifications() async {
    await _notificationsPlugin.cancelAll();
  }
}