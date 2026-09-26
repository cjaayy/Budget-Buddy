import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  // ── Init ──────────────────────────────────────────────────────────────────

  Future<void> initialize() async {
    if (_initialized) return;
    // Use the launcher icon — @android:drawable/* icons are unreliable on
    // modern Android and can cause silent notification failures.
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const InitializationSettings initializationSettings =
        InitializationSettings(android: androidSettings);
    await _plugin.initialize(initializationSettings);
    _initialized = true;
  }

  // ── Generic helpers ───────────────────────────────────────────────────────

  Future<void> showBudgetReminder(
      {required String title, required String body}) async {
    await _show(
      1001,
      title,
      body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'bb_reminders_v2',
          'Budget Reminders',
          channelDescription: 'Daily reminders and smart budget alerts',
          importance: Importance.max,
          priority: Priority.max,
          enableVibration: true,
        ),
      ),
    );
  }

  Future<void> showEndOfDaySummary(
      {required String title, required String body}) async {
    await _show(
      1002,
      title,
      body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'bb_summary_v2',
          'End of Day Summaries',
          channelDescription: 'Daily savings and spending summary notifications',
          importance: Importance.max,
          priority: Priority.max,
          enableVibration: true,
        ),
      ),
    );
  }

  // ── Simulation helpers ────────────────────────────────────────────────────

  /// 🔄 Budget Reset — gentle chime (notif_budget_reset.wav)
  Future<bool> simulateBudgetReset({
    String title = '🔄 Daily Budget Reset',
    String body =
        'Your daily budget has been reset at midnight. A fresh start — stay on track today!',
  }) =>
      _show(
        2001,
        title,
        body,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'bb_reset_v2',
            'Budget Reset Alerts',
            channelDescription:
                'Fired when the daily budget auto-resets at midnight',
            importance: Importance.max,
            priority: Priority.max,
            enableVibration: true,
            sound: RawResourceAndroidNotificationSound('notif_budget_reset'),
            playSound: true,
          ),
        ),
      );

  /// ⚠️ Budget Exceeded — urgent beep (notif_overspent.wav)
  Future<bool> simulateOverspent({
    String title = '⚠️ Budget Exceeded!',
    String body =
        'You\'ve gone over today\'s spending limit. Consider logging the excess as a debt.',
  }) =>
      _show(
        2002,
        title,
        body,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'bb_overspent_v2',
            'Overspent Alerts',
            channelDescription:
                'Alerts when daily spending exceeds the budget limit',
            importance: Importance.max,
            priority: Priority.max,
            enableVibration: true,
            sound: RawResourceAndroidNotificationSound('notif_overspent'),
            playSound: true,
          ),
        ),
      );

  /// 💸 Zero Balance — soft descending tone (notif_zero_balance.wav)
  Future<bool> simulateZeroBalance({
    String title = '💸 Balance Reached Zero',
    String body =
        'Your remaining daily budget is ₱0.00. No more spending room left for today.',
  }) =>
      _show(
        2003,
        title,
        body,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'bb_zero_v2',
            'Zero Balance Alerts',
            channelDescription:
                'Alerts when the remaining daily balance hits zero',
            importance: Importance.max,
            priority: Priority.max,
            enableVibration: true,
            sound: RawResourceAndroidNotificationSound('notif_zero_balance'),
            playSound: true,
          ),
        ),
      );

  // ── Internal ──────────────────────────────────────────────────────────────

  Future<bool> _show(
      int id, String title, String body, NotificationDetails details) async {
    if (!_initialized) await initialize();
    try {
      await _plugin.show(id, title, body, details);
      return true;
    } catch (_) {
      return false;
    }
  }
}
