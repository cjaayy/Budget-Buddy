import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:budgetbuddy/features/budget/budget_planner_screen.dart';
import 'package:budgetbuddy/core/state/app_controller.dart';
import 'package:budgetbuddy/core/models/budget_models.dart';
import 'package:budgetbuddy/core/repositories/local_budget_repository.dart';
import 'package:budgetbuddy/core/services/budget_service.dart';
import 'package:budgetbuddy/core/services/notification_service.dart';

class _FakeLocalRepository extends LocalBudgetRepository {
  BudgetBuddyState? storedState;

  @override
  Future<BudgetBuddyState> loadState() async {
    return storedState ?? BudgetBuddyState.initial();
  }

  @override
  Future<void> saveState(BudgetBuddyState state) async {
    storedState = state;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _FakeLocalRepository repo;
  late BudgetService service;
  late NotificationService notificationService;

  setUp(() {
    repo = _FakeLocalRepository();
    service = BudgetService();
    notificationService = NotificationService.instance;
  });

  Widget buildTestWidget(BudgetBuddyController controller) {
    return ProviderScope(
      overrides: [
        budgetBuddyControllerProvider.overrideWith((ref) => controller),
      ],
      child: const MaterialApp(
        home: BudgetPlannerScreen(),
      ),
    );
  }

  testWidgets('sets budget and locks input, then unlocks to edit',
      (WidgetTester tester) async {
    repo.storedState = BudgetBuddyState.initial();

    final controller = BudgetBuddyController(
      repository: repo,
      service: service,
      notificationService: notificationService,
    );
    await tester.pumpWidget(buildTestWidget(controller));
    await tester.pumpAndSettle();

    // Initial state: No budget set, input is editable
    final Finder textFieldFinder = find.byType(TextField);
    expect(textFieldFinder, findsOneWidget);
    TextField tf = tester.widget<TextField>(textFieldFinder);
    expect(tf.readOnly, isFalse);

    // Enter 500
    await tester.enterText(textFieldFinder, '500');
    await tester.pumpAndSettle();

    // Tap Save & Lock Today's Budget
    final Finder saveButton = find.text('Save & Lock Today\'s Budget');
    expect(saveButton, findsOneWidget);
    await tester.tap(saveButton);
    await tester.pumpAndSettle();

    // Budget is now saved in controller
    expect(controller.state.settings.dailyLimit, equals(500));

    // Input should now be LOCKED (readOnly: true)
    tf = tester.widget<TextField>(textFieldFinder);
    expect(tf.readOnly, isTrue);

    // Unlock button should now be present
    final Finder unlockButton = find.text('Unlock to Edit');
    expect(unlockButton, findsOneWidget);

    // Tap Unlock
    await tester.tap(unlockButton);
    await tester.pumpAndSettle();

    // Input is unlocked again
    tf = tester.widget<TextField>(textFieldFinder);
    expect(tf.readOnly, isFalse);

    // Cancel editing
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    // Re-locked
    tf = tester.widget<TextField>(textFieldFinder);
    expect(tf.readOnly, isTrue);
  });

  testWidgets('update budget shows 5s confirmation dialog and auto-confirms or updates',
      (WidgetTester tester) async {
    repo.storedState = BudgetBuddyState.initial().copyWith(
      settings: BudgetSettings.defaults().copyWith(
        dailyLimit: 500,
        hasConfiguredBudget: true,
      ),
      budgetEntries: [
        BudgetEntry(date: DateTime.now(), amount: 500),
      ],
    );

    final controller = BudgetBuddyController(
      repository: repo,
      service: service,
      notificationService: notificationService,
    );
    await tester.pumpWidget(buildTestWidget(controller));
    await tester.pumpAndSettle();

    // Unlock to edit
    await tester.tap(find.text('Unlock to Edit'));
    await tester.pumpAndSettle();

    // Enter 800
    final Finder textFieldFinder = find.byType(TextField);
    await tester.enterText(textFieldFinder, '800');
    await tester.pumpAndSettle();

    // Tap Update Budget
    await tester.tap(find.text('Update Budget'));
    await tester.pumpAndSettle();

    // 5-second confirmation dialog should appear
    expect(find.text('Confirm Budget Update'), findsOneWidget);
    expect(find.textContaining('Auto-confirming in'), findsOneWidget);

    // Tap Update Now to confirm immediately
    await tester.tap(find.text('Update Now'));
    await tester.pumpAndSettle();

    // Budget updated to 800 and locked again
    expect(controller.state.settings.dailyLimit, equals(800));
    final TextField tf = tester.widget<TextField>(textFieldFinder);
    expect(tf.readOnly, isTrue);
  });

  testWidgets('reset budget shows 5s confirmation dialog and auto-confirms reset',
      (WidgetTester tester) async {
    repo.storedState = BudgetBuddyState.initial().copyWith(
      settings: BudgetSettings.defaults().copyWith(
        dailyLimit: 500,
        hasConfiguredBudget: true,
      ),
      budgetEntries: [
        BudgetEntry(date: DateTime.now(), amount: 500),
      ],
      dailySpent: 120,
    );

    final controller = BudgetBuddyController(
      repository: repo,
      service: service,
      notificationService: notificationService,
    );
    await tester.pumpWidget(buildTestWidget(controller));
    await tester.pumpAndSettle();

    // Tap Reset Budget
    await tester.tap(find.text('Reset Budget'));
    await tester.pumpAndSettle();

    // Confirmation dialog appears with 5s countdown
    expect(find.text('Confirm Budget Reset'), findsOneWidget);

    // Let 5 seconds pass to test auto-confirmation!
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    // Budget is reset, daily limit is null, and input is unlocked for new day
    expect(controller.state.settings.dailyLimit, isNull);
    expect(controller.state.settings.hasConfiguredBudget, isFalse);
    final TextField tf = tester.widget<TextField>(find.byType(TextField));
    expect(tf.readOnly, isFalse);
  });
}
