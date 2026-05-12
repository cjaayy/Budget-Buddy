import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:budgetbuddy/features/profile/profile_settings_screen.dart';
import 'package:budgetbuddy/core/state/app_controller.dart';
import 'package:budgetbuddy/core/models/budget_models.dart';

class TestController extends StateNotifier<BudgetBuddyState>
    implements BudgetBuddyController {
  TestController() : super(BudgetBuddyState.initial());

  // Implement only the methods used by the UI in tests
  @override
  void updateProfilePreferences({
    bool? notificationsEnabled,
    bool? budgetWarningNotificationsEnabled,
    bool? summaryNotificationsEnabled,
    bool? streakNotificationsEnabled,
    bool? notifyOnDailyReset,
    int? notificationReminderMinuteOfDay,
    NotificationFrequency? notificationFrequency,
    int? dayStartMinuteOfDay,
    bool? includeYesterdaySpentInSummary,
  }) {
    state = state.copyWith(
      settings: state.settings.copyWith(
        notificationsEnabled: notificationsEnabled,
        budgetWarningNotificationsEnabled: budgetWarningNotificationsEnabled,
        summaryNotificationsEnabled: summaryNotificationsEnabled,
        streakNotificationsEnabled: streakNotificationsEnabled,
        notifyOnDailyReset: notifyOnDailyReset,
        notificationReminderMinuteOfDay: notificationReminderMinuteOfDay,
        notificationFrequency: notificationFrequency,
        includeYesterdaySpentInSummary: includeYesterdaySpentInSummary,
        dayStartMinuteOfDay: dayStartMinuteOfDay,
      ),
    );
  }

  // The rest of BudgetBuddyController interface methods are not needed here.
  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  testWidgets('Preferences toggles are present and toggleable',
      (WidgetTester tester) async {
    final TestController testController = TestController();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          budgetBuddyControllerProvider.overrideWithProvider(
            StateNotifierProvider<BudgetBuddyController, BudgetBuddyState>(
                (ref) => testController as BudgetBuddyController),
          ),
        ],
        child: const MaterialApp(
          home: ProfileSettingsScreen(),
        ),
      ),
    );

    // Open Preferences sheet
    expect(find.text('Preferences'), findsOneWidget);
    await tester.tap(find.text('Preferences'));
    await tester.pumpAndSettle();

    // Verify toggles exist
    final Finder overspendTile =
        find.widgetWithText(SwitchListTile, 'Overspend alerts');
    final Finder summaryTile =
        find.widgetWithText(SwitchListTile, 'End-of-day summary');
    final Finder notifyResetTile =
        find.widgetWithText(SwitchListTile, 'Notify when daily budget resets');

    expect(overspendTile, findsOneWidget);
    expect(summaryTile, findsOneWidget);
    expect(notifyResetTile, findsOneWidget);

    // Toggle each and verify switch value changes
    Finder overspendSwitch =
        find.descendant(of: overspendTile, matching: find.byType(Switch));
    expect(overspendSwitch, findsOneWidget);
    Switch sw = tester.widget<Switch>(overspendSwitch);
    final bool initialOverspend = sw.value;

    await tester.tap(overspendTile);
    await tester.pumpAndSettle();
    sw = tester.widget<Switch>(overspendSwitch);
    expect(sw.value, equals(!initialOverspend));

    // Summary toggle
    Finder summarySwitch =
        find.descendant(of: summaryTile, matching: find.byType(Switch));
    expect(summarySwitch, findsOneWidget);
    sw = tester.widget<Switch>(summarySwitch);
    final bool initialSummary = sw.value;
    await tester.tap(summaryTile);
    await tester.pumpAndSettle();
    sw = tester.widget<Switch>(summarySwitch);
    expect(sw.value, equals(!initialSummary));

    // Notify on reset toggle
    Finder notifySwitch =
        find.descendant(of: notifyResetTile, matching: find.byType(Switch));
    expect(notifySwitch, findsOneWidget);
    sw = tester.widget<Switch>(notifySwitch);
    final bool initialNotify = sw.value;
    await tester.tap(notifyResetTile);
    await tester.pumpAndSettle();
    sw = tester.widget<Switch>(notifySwitch);
    expect(sw.value, equals(!initialNotify));
  });
}
