import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
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

    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const InitializationSettings initializationSettings =
        InitializationSettings(android: androidSettings);
    await _plugin.initialize(initializationSettings);

    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlugin != null) {
      await androidPlugin.createNotificationChannel(
        const AndroidNotificationChannel(
          'bb_reminders_v2',
          'Budget Reminders',
          description: 'Daily reminders and smart budget alerts',
          importance: Importance.max,
        ),
      );
      await androidPlugin.createNotificationChannel(
        const AndroidNotificationChannel(
          'bb_summary_v2',
          'End of Day Summaries',
          description: 'Daily savings and spending summary notifications',
          importance: Importance.max,
        ),
      );
      await androidPlugin.createNotificationChannel(
        const AndroidNotificationChannel(
          'bb_reset_v2',
          'Budget Reset Alerts',
          description: 'Fired when the daily budget auto-resets at midnight',
          importance: Importance.max,
          sound: RawResourceAndroidNotificationSound('notif_budget_reset'),
          playSound: true,
        ),
      );
      await androidPlugin.createNotificationChannel(
        const AndroidNotificationChannel(
          'bb_overspent_v2',
          'Overspent Alerts',
          description: 'Alerts when daily spending exceeds the budget limit',
          importance: Importance.max,
          sound: RawResourceAndroidNotificationSound('notif_overspent'),
          playSound: true,
        ),
      );
      await androidPlugin.createNotificationChannel(
        const AndroidNotificationChannel(
          'bb_zero_v2',
          'Zero Balance Alerts',
          description: 'Alerts when the remaining daily balance hits zero',
          importance: Importance.max,
          sound: RawResourceAndroidNotificationSound('notif_zero_balance'),
          playSound: true,
        ),
      );
    }

    _initialized = true;
  }

  // ── Permissions ──────────────────────────────────────────────────────────

  Future<bool> requestPermission() async {
    if (!_initialized) await initialize();
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android == null) return true;
    final bool? granted = await android.requestNotificationsPermission();
    return granted ?? false;
  }

  Future<bool> areNotificationsEnabled() async {
    if (!_initialized) await initialize();
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android == null) return true;
    final bool? enabled = await android.areNotificationsEnabled();
    return enabled ?? false;
  }

  Future<void> openNotificationSettings() async {
    const channel = MethodChannel('budgetbuddy/storage');
    try {
      await channel.invokeMethod<void>('openNotificationSettings');
    } catch (e) {
      debugPrint('[NotificationService] openNotificationSettings error: $e');
    }
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
      final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      if (androidPlugin != null) {
        final bool? enabled = await androidPlugin.areNotificationsEnabled();
        if (enabled == false) {
          final bool? granted =
              await androidPlugin.requestNotificationsPermission();
          if (granted != true) {
            final bool? checkAgain =
                await androidPlugin.areNotificationsEnabled();
            if (checkAgain != true) {
              return false;
            }
          }
        }
      }

      await _plugin.show(id, title, body, details);
      return true;
    } catch (e) {
      debugPrint('[NotificationService] Show failed: $e, trying fallback');
      try {
        final fallback = NotificationDetails(
          android: AndroidNotificationDetails(
            details.android?.channelId ?? 'bb_general_v2',
            details.android?.channelName ?? 'Budget Buddy',
            channelDescription: details.android?.channelDescription,
            importance: Importance.max,
            priority: Priority.max,
            enableVibration: true,
            playSound: true,
          ),
        );
        await _plugin.show(id, title, body, fallback);
        return true;
      } catch (fallbackErr) {
        debugPrint('[NotificationService] Fallback also failed: $fallbackErr');
        return false;
      }
    }
  }
}
