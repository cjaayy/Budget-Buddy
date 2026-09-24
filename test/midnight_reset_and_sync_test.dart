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

    test('resets active daily budget and today expense entry when new day starts', () async {
      final DateTime now = DateTime.now();
      final DateTime yesterday = now.subtract(const Duration(days: 1));
      final DateTime yesterdayDate = DateTime(yesterday.year, yesterday.month, yesterday.day);

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

    test('automatically backfills missing past days so every calendar day has a record', () async {
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

    test('Dev Mode simulateMidnightReset() resets active daily budget and rolls over to 12:00 AM', () async {
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

    test('Dev Mode setSimulatedDateTime() triggers reset when setting time to 12:00 AM or future day', () async {
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
      final DateTime tomorrow12AM = DateTime(today.year, today.month, today.day + 1, 0, 0);
      await controller.setSimulatedDateTime(tomorrow12AM);

      // Active budget reset
      expect(controller.state.settings.dailyLimit, isNull);
      expect(controller.state.settings.hasConfiguredBudget, isFalse);
      expect(controller.state.dailySpent, equals(0));

      controller.dispose();
    });

    test('after budget reset, spending is 0 and user can set a new budget for today', () async {
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
  });
}
