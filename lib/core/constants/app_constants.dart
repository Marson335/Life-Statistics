class AppConstants {
  // Firestore collections
  static const String usersCollection = 'users';
  static const String tasksCollection = 'tasks';
  static const String mindsetCollection = 'mindset';

  // Shared prefs keys
  static const String languageKey = 'app_language';
  static const String notificationTimeKey = 'notification_time';
  static const String notificationsEnabledKey = 'notifications_enabled';
  static const String viewModeKey = 'view_mode'; // 'day' or 'week'

  // Notification IDs
  static const int dailyReminderNotifId = 1001;

  // Task generation lookahead days
  static const int recurrenceLookaheadDays = 90;
}
