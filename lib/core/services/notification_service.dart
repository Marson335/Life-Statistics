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
    tz.setLocalLocation(tz.getLocation('Europe/Kyiv'));

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

    _isInitialized = true;
  }

  Future<void> requestPermissions() async {
    if (Platform.isAndroid) {
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

  Future<void> scheduleTaskReminder(Task task) async {
    if (task.reminderTime == null) return;
    
    final timeParts = task.reminderTime!.split(':');
    final hour = int.parse(timeParts[0]);
    final minute = int.parse(timeParts[1]);

    // Calculate when to show the notification
    DateTime scheduledDate = DateTime(
      task.date.year,
      task.date.month,
      task.date.day,
      hour,
      minute,
    );

    if (scheduledDate.isBefore(DateTime.now())) {
      if (task.type == TaskType.green) {
        // If recurring task time passed today, start from tomorrow
        scheduledDate = scheduledDate.add(const Duration(days: 1));
      } else {
        return; // Past date, don't schedule
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

    try {
      await _notificationsPlugin.zonedSchedule(
        id,
        'Нагадування: ${task.title}',
        'Час виконати заплановану задачу!',
        tz.TZDateTime.from(scheduledDate, tz.local),
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'life_statistics_tasks',
            'Task Reminders',
            channelDescription: 'Notifications for task reminders',
            importance: Importance.max,
            priority: Priority.high,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: matchComponents,
      );
    } catch (e) {
      print('Error scheduling notification: $e');
    }
  }

  Future<void> cancelTaskReminder(String taskId) async {
    await _notificationsPlugin.cancel(taskId.hashCode);
  }
}