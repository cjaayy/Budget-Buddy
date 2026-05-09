import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();

  Future<void> initialize() async {
    const AndroidInitializationSettings androidSettings = AndroidInitializationSettings('@android:drawable/ic_dialog_info');
    const InitializationSettings initializationSettings = InitializationSettings(android: androidSettings);
    await _plugin.initialize(initializationSettings);
  }

  Future<void> showBudgetReminder({required String title, required String body}) async {
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'budgetbuddy_reminders',
      'Budget reminders',
      channelDescription: 'Daily reminders and smart budget alerts',
      importance: Importance.high,
      priority: Priority.high,
    );

    await _plugin.show(
      1001,
      title,
      body,
      const NotificationDetails(android: androidDetails),
    );
  }

  Future<void> showEndOfDaySummary({required String title, required String body}) async {
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'budgetbuddy_summary',
      'End of day summaries',
      channelDescription: 'Daily savings and spending summary notifications',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
    );

    await _plugin.show(
      1002,
      title,
      body,
      const NotificationDetails(android: androidDetails),
    );
  }
}