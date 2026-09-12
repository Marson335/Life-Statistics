import 'package:flutter_local_notifications/flutter_local_notifications.dart';

Future<void> showTestNotification() async {
  final FlutterLocalNotificationsPlugin plugin = FlutterLocalNotificationsPlugin();
  
  const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
    'test_channel',
    'Test Channel',
    importance: Importance.max,
    priority: Priority.high,
  );
  
  const NotificationDetails details = NotificationDetails(android: androidDetails);
  
  try {
    await plugin.show(
      999,
      'Test Notification',
      'This is a test notification',
      details,
    );
    print("Test notification shown");
  } catch (e) {
    print("Failed to show notification: $e");
  }
}