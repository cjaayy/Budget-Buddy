import 'package:flutter_test/flutter_test.dart';
import 'package:budgetbuddy/core/models/budget_models.dart';
import 'package:budgetbuddy/core/repositories/local_budget_repository.dart';
import 'package:budgetbuddy/core/services/budget_service.dart';
import 'package:budgetbuddy/core/services/notification_service.dart';
import 'package:budgetbuddy/core/state/app_controller.dart';

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

  test('Day 1 has 100 budget and 88 spent (12 left); Day 2 has no new budget; savings remains 12 and daily budget/savings is never 112', () async {
    final repo = _FakeLocalRepository();
    final service = BudgetService();
    final notificationService = NotificationService.instance;

    final controller = BudgetBuddyController(
      repository: repo,
      service: service,
      notificationService: notificationService,
    );
    await Future<void>.delayed(Duration.zero);

    // Day 1: User sets budget 100
    controller.recordDailyBudget(amount: 100);
    // Day 1: User spends 88 -> 12 left
    controller.addExpense(title: 'Lunch', amount: 88, category: BudgetCategory.food);

    expect(controller.state.settings.dailyLimit, equals(100.0));
    expect(controller.state.dailySpent, equals(88.0));
    expect(controller.summary.remainingBalance, equals(12.0));

    // Simulate 12am midnight reset (rollover to Day 2)
    await controller.simulateMidnightReset();

    // After midnight reset, without adding 100:
    // Today's budget is unset (null / 0)
    expect(controller.state.settings.dailyLimit, isNull);
    expect(controller.state.dailySpent, equals(0.0));
    expect(controller.summary.totalBudget, equals(0.0));
    expect(controller.summary.savings, equals(0.0));

    // Total savings accumulated is strictly 12.0 (NOT 112!)
    expect(controller.state.totalSavings, equals(12.0));
    expect(controller.state.savingsDebt, equals(0.0));

    // Daily records: Day 1 has 12 savings; Day 2 has 0 savings (empty state)
    final records = controller.state.dailyRecords;
    expect(records.length, equals(2));

    final day1Record = records.first;
    expect(day1Record.budget, equals(100.0));
    expect(day1Record.totalSpent, equals(88.0));
    expect(day1Record.remainingBalance, equals(12.0));
    expect(day1Record.savings, equals(12.0));
    expect(day1Record.isZeroActivity, isFalse);

    final day2Record = records.last;
    expect(day2Record.budget, equals(0.0));
    expect(day2Record.totalSpent, equals(0.0));
    expect(day2Record.remainingBalance, equals(0.0));
    expect(day2Record.savings, equals(0.0));
    expect(day2Record.isZeroActivity, isTrue);

    // Sum of daily savings across all days is strictly 12.0 (NOT 112!)
    final double sumDailyRecordsSavings = records.fold(0.0, (sum, r) => sum + r.savings);
    expect(sumDailyRecordsSavings, equals(12.0));

    controller.dispose();
  });
}
