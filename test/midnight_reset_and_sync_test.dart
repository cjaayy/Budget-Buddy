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

  group('12:00 AM Midnight Auto-Reset & Date Sync', () {
    late _FakeLocalRepository repo;
    late BudgetService service;
    late NotificationService notificationService;

    setUp(() {
      repo = _FakeLocalRepository();
      service = BudgetService();
      notificationService = NotificationService.instance;
    });

    test(
        'resets active daily budget and today expense entry when new day starts',
        () async {
      final DateTime now = DateTime.now();
      final DateTime yesterday = now.subtract(const Duration(days: 1));
      final DateTime yesterdayDate =
          DateTime(yesterday.year, yesterday.month, yesterday.day);

      repo.storedState = BudgetBuddyState.initial().copyWith(
        dailyPeriodStart: yesterdayDate,
        settings: BudgetSettings.defaults().copyWith(
          dailyLimit: 500,
          hasConfiguredBudget: true,
        ),
        budgetEntries: <BudgetEntry>[
          BudgetEntry(date: yesterdayDate, amount: 500),
        ],
        expenses: <ExpenseEntry>[
          ExpenseEntry(
            id: 'exp-1',
            title: 'Lunch',
            amount: 150,
            category: BudgetCategory.food,
            dateTime: yesterdayDate.add(const Duration(hours: 12)),
          ),
        ],
        dailySpent: 150,
      );

      final controller = BudgetBuddyController(
        repository: repo,
        service: service,
        notificationService: notificationService,
      );
      await Future<void>.delayed(Duration.zero);

      // Today's active daily budget must be reset
      expect(controller.state.settings.dailyLimit, isNull);
      expect(controller.state.settings.hasConfiguredBudget, isFalse);

      // Today's daily spent must be reset
      expect(controller.state.dailySpent, equals(0));

      // Yesterday's expense is preserved
      expect(controller.state.expenses.length, equals(1));
      expect(controller.state.expenses.first.id, equals('exp-1'));

      // Yesterday's budget entry is preserved
      expect(controller.state.budgetEntries.length, equals(1));
      expect(controller.state.budgetEntries.first.amount, equals(500));

      controller.dispose();
    });

    test(
        'automatically backfills missing past days so every calendar day has a record',
        () async {
      final DateTime now = DateTime.now();
      final DateTime threeDaysAgo = now.subtract(const Duration(days: 3));
      final DateTime threeDaysAgoDate =
          DateTime(threeDaysAgo.year, threeDaysAgo.month, threeDaysAgo.day);

      repo.storedState = BudgetBuddyState.initial().copyWith(
        dailyPeriodStart: threeDaysAgoDate,
        dailyRecords: <DailyRecord>[
          DailyRecord(
            date: threeDaysAgoDate,
            totalSpent: 200,
            remainingBalance: 300,
            savings: 300,
            biggestExpenseCategory: BudgetCategory.food.label,
            categoryTotals: <String, double>{},
          ),
        ],
      );

      final controller = BudgetBuddyController(
        repository: repo,
        service: service,
        notificationService: notificationService,
      );
      await Future<void>.delayed(Duration.zero);

      // Should have records for threeDaysAgo, 2 days ago, yesterday, and today (at least 4 consecutive days)
      expect(controller.state.dailyRecords.length, greaterThanOrEqualTo(4));

      // Ensure no gaps between threeDaysAgo and today
      DateTime cursor = threeDaysAgoDate;
      final DateTime today = DateTime(now.year, now.month, now.day);
      while (!cursor.isAfter(today)) {
        final bool found = controller.state.dailyRecords.any(
          (DailyRecord r) =>
              r.date.year == cursor.year &&
              r.date.month == cursor.month &&
              r.date.day == cursor.day,
        );
        expect(found, isTrue, reason: 'Missing record for date: $cursor');
        cursor = cursor.add(const Duration(days: 1));
      }

      controller.dispose();
    });

    test(
        'Dev Mode simulateMidnightReset() resets active daily budget and rolls over to 12:00 AM',
        () async {
      repo.storedState = BudgetBuddyState.initial();

      final controller = BudgetBuddyController(
        repository: repo,
        service: service,
        notificationService: notificationService,
      );
      await Future<void>.delayed(Duration.zero);

      final DateTime today = controller.now;
      final DateTime todayDate = DateTime(today.year, today.month, today.day);

      // Set today's budget to ₱500 and log an expense of ₱200
      controller.state = controller.state.copyWith(
        dailyPeriodStart: todayDate,
        settings: controller.state.settings.copyWith(
          dailyLimit: 500,
          hasConfiguredBudget: true,
        ),
        budgetEntries: <BudgetEntry>[
          BudgetEntry(date: todayDate, amount: 500),
        ],
        expenses: <ExpenseEntry>[
          ExpenseEntry(
            id: 'exp-today',
            title: 'Dinner',
            amount: 200,
            category: BudgetCategory.food,
            dateTime: todayDate.add(const Duration(hours: 19)),
          ),
        ],
        dailySpent: 200,
      );

      // User in Dev Mode clicks "Click 12:00 AM Midnight Reset"
      await controller.simulateMidnightReset();

      // Effective clock should now be 12:00 AM of the next day
      expect(controller.isTimeSimulated, isTrue);
      expect(controller.now.hour, equals(0));
      expect(controller.now.minute, equals(0));
      expect(controller.now.day, equals(today.day + 1));

      // Today's active daily budget limit should be reset
      expect(controller.state.settings.dailyLimit, isNull);
      expect(controller.state.settings.hasConfiguredBudget, isFalse);

      // Today's daily spent should be reset to 0
      expect(controller.state.dailySpent, equals(0));

      // Yesterday's expense is preserved in historical records
      expect(controller.state.expenses.any((e) => e.id == 'exp-today'), isTrue);

      // Revert simulated time
      await controller.resetSimulatedTime();
      expect(controller.isTimeSimulated, isFalse);

      controller.dispose();
    });

    test('Dev Mode fastForwardOneDay() starts a fresh day at 12:00 AM',
        () async {
      repo.storedState = BudgetBuddyState.initial();

      final controller = BudgetBuddyController(
        repository: repo,
        service: service,
        notificationService: notificationService,
      );
      await Future<void>.delayed(Duration.zero);

      final DateTime today = controller.now;
      controller.state = controller.state.copyWith(
        dailyPeriodStart: DateTime(today.year, today.month, today.day),
        settings: controller.state.settings.copyWith(
          dailyLimit: 500,
          hasConfiguredBudget: true,
        ),
        budgetEntries: <BudgetEntry>[
          BudgetEntry(
            date: DateTime(today.year, today.month, today.day),
            amount: 500,
          ),
        ],
        dailySpent: 200,
      );

      await controller.fastForwardOneDay();

      expect(controller.now,
          equals(DateTime(today.year, today.month, today.day + 1)));
      expect(controller.state.settings.dailyLimit, isNull);
      expect(controller.state.settings.hasConfiguredBudget, isFalse);
      expect(controller.state.dailySpent, equals(0));

      controller.recordDailyBudget(amount: 300);
      controller.addExpense(
        title: 'Breakfast',
        amount: 75,
        category: BudgetCategory.food,
      );
      expect(controller.state.settings.dailyLimit, equals(300));
      expect(controller.state.dailySpent, equals(75));

      controller.dispose();
    });

    test(
        'Dev Mode setSimulatedDateTime() triggers reset when setting time to 12:00 AM or future day',
        () async {
      repo.storedState = BudgetBuddyState.initial();

      final controller = BudgetBuddyController(
        repository: repo,
        service: service,
        notificationService: notificationService,
      );
      await Future<void>.delayed(Duration.zero);

      final DateTime today = controller.now;
      final DateTime todayDate = DateTime(today.year, today.month, today.day);

      controller.state = controller.state.copyWith(
        dailyPeriodStart: todayDate,
        settings: controller.state.settings.copyWith(
          dailyLimit: 750,
          hasConfiguredBudget: true,
        ),
        budgetEntries: <BudgetEntry>[
          BudgetEntry(date: todayDate, amount: 750),
        ],
        dailySpent: 300,
      );

      // Simulate user setting time to 12:00 AM tomorrow
      final DateTime tomorrow12AM =
          DateTime(today.year, today.month, today.day + 1, 0, 0);
      await controller.setSimulatedDateTime(tomorrow12AM);

      // Active budget reset
      expect(controller.state.settings.dailyLimit, isNull);
      expect(controller.state.settings.hasConfiguredBudget, isFalse);
      expect(controller.state.dailySpent, equals(0));

      controller.dispose();
    });

    test(
        'after budget reset, spending is 0 and user can set a new budget for today',
        () async {
      repo.storedState = BudgetBuddyState.initial();

      final controller = BudgetBuddyController(
        repository: repo,
        service: service,
        notificationService: notificationService,
      );
      await Future<void>.delayed(Duration.zero);

      final DateTime today = controller.now;
      final DateTime todayDate = DateTime(today.year, today.month, today.day);

      // Yesterday had budget ₱500 and ₱250 spent
      controller.state = controller.state.copyWith(
        dailyPeriodStart: todayDate,
        settings: controller.state.settings.copyWith(
          dailyLimit: 500,
          hasConfiguredBudget: true,
        ),
        budgetEntries: <BudgetEntry>[
          BudgetEntry(date: todayDate, amount: 500),
        ],
        expenses: <ExpenseEntry>[
          ExpenseEntry(
            id: 'exp-prev',
            title: 'Coffee',
            amount: 250,
            category: BudgetCategory.food,
            dateTime: todayDate.add(const Duration(hours: 10)),
          ),
        ],
        dailySpent: 250,
      );

      // Midnight reset triggers (new day starts)
      await controller.simulateMidnightReset();

      // Everything for the new day is reset
      expect(controller.state.settings.dailyLimit, isNull);
      expect(controller.state.settings.hasConfiguredBudget, isFalse);
      expect(controller.state.dailySpent, equals(0));

      // User sets a new budget for today (e.g. ₱800)
      controller.recordDailyBudget(amount: 800);

      // New budget is configured and active
      expect(controller.state.settings.dailyLimit, equals(800));
      expect(controller.state.settings.hasConfiguredBudget, isTrue);
      expect(controller.state.dailySpent, equals(0));
      expect(controller.summary.remainingBalance, equals(800));

      // User logs an expense for the new day
      controller.addExpense(
        title: 'Breakfast',
        amount: 150,
        category: BudgetCategory.food,
      );

      // Spending updates accurately from 0
      expect(controller.state.dailySpent, equals(150));
      expect(controller.summary.remainingBalance, equals(650));

      controller.dispose();
    });

    test(
        'Zero-Activity Days (Empty State): records Budget = 0.0, Expenses = 0.0, and preserves date in history logs',
        () async {
      final DateTime now = DateTime.now();
      final DateTime twoDaysAgo = now.subtract(const Duration(days: 2));
      final DateTime twoDaysAgoDate =
          DateTime(twoDaysAgo.year, twoDaysAgo.month, twoDaysAgo.day);

      // Stored state has a record from 2 days ago with budget and expense, but yesterday had zero activity
      repo.storedState = BudgetBuddyState.initial().copyWith(
        dailyPeriodStart: twoDaysAgoDate,
        dailyRecords: <DailyRecord>[
          DailyRecord(
            date: twoDaysAgoDate,
            budget: 400,
            totalSpent: 250,
            remainingBalance: 150,
            savings: 150,
            biggestExpenseCategory: BudgetCategory.food.label,
            categoryTotals: <String, double>{
              BudgetCategory.food.label: 250,
            },
          ),
        ],
      );

      final controller = BudgetBuddyController(
        repository: repo,
        service: service,
        notificationService: notificationService,
      );
      await Future<void>.delayed(Duration.zero);

      // Yesterday had no budget and no expenses logged
      final DateTime yesterday = now.subtract(const Duration(days: 1));
      final DateTime yesterdayDate =
          DateTime(yesterday.year, yesterday.month, yesterday.day);

      final DailyRecord? yesterdayRecord =
          controller.state.dailyRecords.cast<DailyRecord?>().firstWhere(
                (DailyRecord? r) =>
                    r != null &&
                    r.date.year == yesterdayDate.year &&
                    r.date.month == yesterdayDate.month &&
                    r.date.day == yesterdayDate.day,
                orElse: () => null,
              );

      expect(yesterdayRecord, isNotNull,
          reason: 'Zero-activity date must be in history logs');
      expect(yesterdayRecord!.budget, equals(0.0));
      expect(yesterdayRecord.totalSpent, equals(0.0));
      expect(yesterdayRecord.remainingBalance, equals(0.0));
      expect(yesterdayRecord.savings, equals(0.0));
      expect(yesterdayRecord.isZeroActivity, isTrue);

      // Also check today's record when no budget and no expenses logged
      final DateTime todayDate = DateTime(now.year, now.month, now.day);
      final DailyRecord? todayRecord =
          controller.state.dailyRecords.cast<DailyRecord?>().firstWhere(
                (DailyRecord? r) =>
                    r != null &&
                    r.date.year == todayDate.year &&
                    r.date.month == todayDate.month &&
                    r.date.day == todayDate.day,
                orElse: () => null,
              );

      expect(todayRecord, isNotNull,
          reason: 'Today zero-activity date must be in history logs');
      expect(todayRecord!.budget, equals(0.0));
      expect(todayRecord.totalSpent, equals(0.0));
      expect(todayRecord.remainingBalance, equals(0.0));
      expect(todayRecord.savings, equals(0.0));
      expect(todayRecord.isZeroActivity, isTrue);

      controller.dispose();
    });

    test(
        'Budget Surplus & Savings Debt Logic: maintains savingsDebt and totalSavings correctly',
        () async {
      repo.storedState = BudgetBuddyState.initial();

      final controller = BudgetBuddyController(
        repository: repo,
        service: service,
        notificationService: notificationService,
      );
      await Future<void>.delayed(Duration.zero);

      expect(controller.state.savingsDebt, equals(0.0));
      expect(controller.state.totalSavings, equals(0.0));

      // 1. If Today's Expenses > Today's Budget: add over-budget difference to savingsDebt
      // Example: Budget = 500, Expenses = 700 -> over by 200
      controller.applyDailyBudgetSurplusAndDebt(budget: 500, expenses: 700);
      expect(controller.state.savingsDebt, equals(200.0));
      expect(controller.state.totalSavings, equals(0.0));

      // 2. If Today's Budget > Today's Expenses (e.g. user set budget 500 and had 0 expense):
      // Calculate surplus = 500 - 0 = 500.
      // Deduct surplus from savingsDebt first (200 debt paid off -> debt = 0).
      // Leftover surplus (500 - 200 = 300) goes to totalSavings.
      controller.applyDailyBudgetSurplusAndDebt(budget: 500, expenses: 0);
      expect(controller.state.savingsDebt, equals(0.0));
      expect(controller.state.totalSavings, equals(300.0));

      // 3. Additional surplus when savingsDebt is 0 goes straight to totalSavings
      // Example: Budget = 400, Expenses = 100 -> surplus 300
      controller.applyDailyBudgetSurplusAndDebt(budget: 400, expenses: 100);
      expect(controller.state.savingsDebt, equals(0.0));
      expect(controller.state.totalSavings, equals(600.0));

      // 4. Over-budget again: Expenses = 600, Budget = 400 -> over by 200 added to savingsDebt
      controller.applyDailyBudgetSurplusAndDebt(budget: 400, expenses: 600);
      expect(controller.state.savingsDebt, equals(200.0));
      expect(controller.state.totalSavings, equals(600.0));

      // 5. Partial debt payoff: Budget = 300, Expenses = 200 -> surplus 100
      // 100 deducted from savingsDebt (200 - 100 = 100 remaining debt), 0 leftover for totalSavings
      controller.applyDailyBudgetSurplusAndDebt(budget: 300, expenses: 200);
      expect(controller.state.savingsDebt, equals(100.0));
      expect(controller.state.totalSavings, equals(600.0));

      controller.dispose();
    });

    test(
        'Budget Surplus & Savings Debt: automatic settlement on midnight reset',
        () async {
      repo.storedState = BudgetBuddyState.initial();

      final controller = BudgetBuddyController(
        repository: repo,
        service: service,
        notificationService: notificationService,
      );
      await Future<void>.delayed(Duration.zero);

      final DateTime today = controller.now;
      final DateTime todayDate = DateTime(today.year, today.month, today.day);

      // Day 1: Budget 500, Expenses 700 (over-budget by 200)
      controller.recordDailyBudget(amount: 500);
      controller.addExpense(
        title: 'Dinner',
        amount: 700,
        category: BudgetCategory.food,
      );

      expect(controller.state.dailySpent, equals(700.0));

      // Day 1 ends: simulate midnight reset
      await controller.simulateMidnightReset();

      // savingsDebt is now 200, totalSavings is 0
      expect(controller.state.savingsDebt, equals(200.0));
      expect(controller.state.totalSavings, equals(0.0));
      expect(controller.state.dailySpent, equals(0.0));

      // Day 2: User sets budget 500 and has 0 expenses (exact user example!)
      controller.recordDailyBudget(amount: 500);

      // Day 2 ends: simulate midnight reset
      await controller.simulateMidnightReset();

      // Surplus was 500. It paid off the 200 debt, leaving 300 in totalSavings!
      expect(controller.state.savingsDebt, equals(0.0));
      expect(controller.state.totalSavings, equals(300.0));

      controller.dispose();
    });

    test(
        'budget left goes to savings only (not full budget) and is NOT added to next day budget',
        () async {
      repo.storedState = BudgetBuddyState.initial();

      final controller = BudgetBuddyController(
        repository: repo,
        service: service,
        notificationService: notificationService,
      );
      await Future<void>.delayed(Duration.zero);

      // User sets budget ₱200 today
      controller.recordDailyBudget(amount: 200);

      // User spends ₱100 today
      controller.addExpense(
        title: 'Lunch',
        amount: 100,
        category: BudgetCategory.food,
      );

      expect(controller.state.settings.dailyLimit, equals(200.0));
      expect(controller.state.dailySpent, equals(100.0));
      expect(controller.summary.remainingBalance, equals(100.0));

      // Day ends: simulate midnight reset
      await controller.simulateMidnightReset();

      // Only the ₱100 left goes to totalSavings (NOT ₱200!)
      expect(controller.state.totalSavings, equals(100.0));
      expect(controller.state.savingsDebt, equals(0.0));

      // Today's budget is reset to 0/null (starts fresh, 100 savings is NOT added to today's budget)
      expect(controller.state.settings.dailyLimit, isNull);
      expect(controller.state.dailySpent, equals(0.0));

      // On the new day, user adds again ₱200 (or any budget)
      controller.recordDailyBudget(amount: 200);

      // Today's budget is exactly ₱200 (the ₱100 savings is NOT added to today's budget)
      expect(controller.state.settings.dailyLimit, equals(200.0));
      expect(controller.summary.totalBudget, equals(200.0));
      expect(controller.summary.remainingBalance, equals(200.0));
      // Savings remains strictly in savings
      expect(controller.state.totalSavings, equals(100.0));

      controller.dispose();
    });

    test(
        'Day 1 has 12 left (100 budget, 88 spent); Day 2 has no new budget; 12am reset does NOT copy 100 into savings',
        () async {
      repo.storedState = BudgetBuddyState.initial();

      final controller = BudgetBuddyController(
        repository: repo,
        service: service,
        notificationService: notificationService,
      );
      await Future<void>.delayed(Duration.zero);

      // Day 1: User sets budget ₱100
      controller.recordDailyBudget(amount: 100);

      // Day 1: User spends ₱88 -> ₱12 left
      controller.addExpense(
        title: 'Lunch',
        amount: 88,
        category: BudgetCategory.food,
      );

      expect(controller.state.settings.dailyLimit, equals(100.0));
      expect(controller.state.dailySpent, equals(88.0));
      expect(controller.summary.remainingBalance, equals(12.0));

      // Day 1 ends: 12:00 AM Midnight auto reset rolls over to Day 2
      await controller.simulateMidnightReset();

      // Only the ₱12 left was settled into totalSavings (NOT ₱100!)
      expect(controller.state.totalSavings, equals(12.0));
      expect(controller.state.savingsDebt, equals(0.0));

      // Day 2 has started: budget is null (unset), spending is 0
      expect(controller.state.settings.dailyLimit, isNull);
      expect(controller.state.dailySpent, equals(0.0));

      // User does NOT put again a new budget for today (Day 2)

      // Day 2 ends: 12:00 AM Midnight auto reset rolls over to Day 3
      await controller.simulateMidnightReset();

      // Total savings MUST REMAIN ₱12! It must NOT copy the ₱100 from yesterday's budget!
      expect(controller.state.totalSavings, equals(12.0));
      expect(controller.state.savingsDebt, equals(0.0));
      expect(controller.state.settings.dailyLimit, isNull);
      expect(controller.state.dailySpent, equals(0.0));

      // History records check
      final records = controller.state.dailyRecords;
      expect(records.length, greaterThanOrEqualTo(2));

      controller.dispose();
    });
  });
}
