import 'package:flutter_test/flutter_test.dart';

import 'package:budgetbuddy/core/models/budget_models.dart';
import 'package:budgetbuddy/core/services/budget_service.dart';

void main() {
  test('monthly budget sums recorded daily budget entries', () {
    final BudgetService service = BudgetService();
    final DateTime dayOne = DateTime(2026, 6, 1);
    final BudgetBuddyState state = BudgetBuddyState.initial().copyWith(
      settings: BudgetSettings.defaults().copyWith(
        dailyLimit: 200,
        hasConfiguredBudget: true,
      ),
      budgetEntries: <BudgetEntry>[
        BudgetEntry(
            date: dayOne.subtract(const Duration(days: 2)), amount: 150),
        BudgetEntry(
            date: dayOne.subtract(const Duration(days: 1)), amount: 300),
        BudgetEntry(date: dayOne, amount: 200),
      ],
    );

    final BudgetSummary summary = service.computeSummary(
      state,
      now: DateTime(2026, 6, 4),
    );

    expect(summary.periodSummaries[BudgetPeriod.daily]?.limit, 200);
    expect(summary.periodSummaries[BudgetPeriod.monthly]?.limit, 650);
  });
}
