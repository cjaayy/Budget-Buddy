import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../models/budget_models.dart';
import '../repositories/local_budget_repository.dart';
import '../services/budget_service.dart';
import '../services/notification_service.dart';
import '../services/report_service.dart';

final localBudgetRepositoryProvider =
    Provider<LocalBudgetRepository>((Ref<LocalBudgetRepository> ref) {
  return LocalBudgetRepository();
});

final budgetServiceProvider = Provider<BudgetService>((Ref<BudgetService> ref) {
  return BudgetService();
});

final reportServiceProvider = Provider<ReportService>((Ref<ReportService> ref) {
  return ReportService();
});

final notificationServiceProvider =
    Provider<NotificationService>((Ref<NotificationService> ref) {
  return NotificationService.instance;
});

final budgetBuddyControllerProvider =
    StateNotifierProvider<BudgetBuddyController, BudgetBuddyState>(
  (ref) {
    return BudgetBuddyController(
      repository: ref.watch(localBudgetRepositoryProvider),
      service: ref.watch(budgetServiceProvider),
      notificationService: ref.watch(notificationServiceProvider),
    );
  },
);

final budgetSummaryProvider = Provider<BudgetSummary>((Ref<BudgetSummary> ref) {
  final BudgetBuddyState state = ref.watch(budgetBuddyControllerProvider);
  final List<ExpenseEntry> mainExpenses = state.expenses
      .where((ExpenseEntry expense) => expense.source != 'togetherSpend')
      .toList();
  final BudgetBuddyState mainState = state.copyWith(expenses: mainExpenses);
  return ref.watch(budgetServiceProvider).computeSummary(mainState);
});

final budgetTogetherSummaryProvider =
    Provider<BudgetSummary>((Ref<BudgetSummary> ref) {
  final BudgetBuddyState state = ref.watch(budgetBuddyControllerProvider);
  final BudgetService service = ref.watch(budgetServiceProvider);
  final double togetherBudget = state.togetherBudget;
  final DateTime now = DateTime.now();
  final DateTime dailyStart = DateTime(now.year, now.month, now.day);
  final DateTime weeklyStart = DateTime(now.year, now.month, now.day)
      .subtract(Duration(days: now.weekday - DateTime.monday));
  final DateTime monthlyStart = DateTime(now.year, now.month, 1);
  final List<ExpenseEntry> spendExpenses = state.expenses
      .where((ExpenseEntry expense) => expense.source == 'togetherSpend')
      .toList();

  double sumSince(DateTime start) {
    return spendExpenses
        .where((ExpenseEntry expense) =>
            !expense.dateTime.isBefore(start) && !expense.dateTime.isAfter(now))
        .fold(0, (double sum, ExpenseEntry expense) => sum + expense.amount);
  }

  final BudgetBuddyState togetherState = state.copyWith(
    settings: state.settings.copyWith(
      dailyLimit: togetherBudget,
      weeklyLimit: null,
      monthlyLimit: null,
      hasConfiguredBudget: togetherBudget > 0,
    ),
    expenses: spendExpenses,
    dailySpent: sumSince(dailyStart),
    weeklySpent: sumSince(weeklyStart),
    monthlySpent: sumSince(monthlyStart),
    budgetEntries: <BudgetEntry>[],
  );

  return service.computeSummary(togetherState);
});

final mealSuggestionsProvider =
    Provider<List<MealSuggestion>>((Ref<List<MealSuggestion>> ref) {
  final BudgetBuddyState state = ref.watch(budgetBuddyControllerProvider);
  final BudgetSummary summary = ref.watch(budgetSummaryProvider);
  return ref.watch(budgetServiceProvider).recommendMeals(
        state: state,
        category: MealCategory.budgetMeals,
        remainingBudget: summary.remainingBalance,
      );
});

final activitySuggestionsProvider =
    Provider<List<ActivitySuggestion>>((Ref<List<ActivitySuggestion>> ref) {
  final BudgetSummary summary = ref.watch(budgetSummaryProvider);
  return ref.watch(budgetServiceProvider).recommendActivities(
        mood: GalaMood.chill,
        budget:
            summary.remainingBalance.clamp(0, summary.totalBudget).toDouble(),
        preferredDistanceKm: 5,
      );
});

class BudgetBuddyController extends StateNotifier<BudgetBuddyState> {
  BudgetBuddyController({
    required LocalBudgetRepository repository,
    required BudgetService service,
    required NotificationService notificationService,
  })  : _repository = repository,
        _service = service,
        _notificationService = notificationService,
        super(BudgetBuddyState.initial()) {
    _startMidnightCheckTimer();
    _bootstrap();
  }

  final LocalBudgetRepository _repository;
  final BudgetService _service;
  final NotificationService _notificationService;
  final Uuid _uuid = const Uuid();
  Timer? _midnightCheckTimer;
  DateTime? _simulatedDateTime;

  DateTime get now => _simulatedDateTime ?? DateTime.now();
  bool get isTimeSimulated => _simulatedDateTime != null;
  DateTime get currentEffectiveTime => now;

  Future<void> setSimulatedDateTime(DateTime dateTime) async {
    final DateTime currentNow = now;
    final DateTime currentTodayStart =
        DateTime(currentNow.year, currentNow.month, currentNow.day);
    final DateTime newTodayStart =
        DateTime(dateTime.year, dateTime.month, dateTime.day);

    final bool is12AM = dateTime.hour == 0 && dateTime.minute == 0;
    final bool isNewDay = newTodayStart.isAfter(currentTodayStart);
    final bool shouldForce = is12AM || isNewDay;

    _simulatedDateTime = dateTime;
    await syncDateAndCheckMidnightReset(forceReset: shouldForce);
  }

  Future<void> simulateMidnightReset() async {
    final DateTime current = now;
    final DateTime nextDayMidnight =
        DateTime(current.year, current.month, current.day + 1, 0, 0, 0);
    _simulatedDateTime = nextDayMidnight;
    await syncDateAndCheckMidnightReset(forceReset: true);
  }

  Future<void> fastForwardOneDay() async {
    final DateTime current = now;
    final DateTime nextDay = DateTime(
      current.year,
      current.month,
      current.day + 1,
      current.hour,
      current.minute,
      current.second,
    );
    _simulatedDateTime = nextDay;
    await syncDateAndCheckMidnightReset();
  }

  Future<void> setSimulatedTimeTo1159PM() async {
    final DateTime current = now;
    final DateTime tonite1159 =
        DateTime(current.year, current.month, current.day, 23, 59, 0);
    _simulatedDateTime = tonite1159;
    await syncDateAndCheckMidnightReset();
  }

  Future<void> resetSimulatedTime() async {
    _simulatedDateTime = null;
    await syncDateAndCheckMidnightReset();
  }

  double get savingsDebt => state.savingsDebt;
  double get totalSavings => state.totalSavings;

  /// Applies the budget surplus & savings debt logic:
  /// - If Today's Budget > Today's Expenses:
  ///     surplus = Today's Budget - Today's Expenses.
  ///     If savingsDebt > 0: Deduct surplus from savingsDebt first to pay off past over-budget debt.
  ///     Any leftover surplus after paying off debt goes to totalSavings.
  /// - If Today's Expenses > Today's Budget:
  ///     Add the over-budget difference to savingsDebt.
  void applyDailyBudgetSurplusAndDebt({
    required double budget,
    required double expenses,
  }) {
    double currentDebt = state.savingsDebt;
    double currentSavings = state.totalSavings;

    if (budget > expenses) {
      final double surplus = budget - expenses;
      if (currentDebt > 0) {
        if (surplus >= currentDebt) {
          final double leftoverSurplus = surplus - currentDebt;
          currentDebt = 0.0;
          currentSavings += leftoverSurplus;
        } else {
          currentDebt -= surplus;
        }
      } else {
        currentSavings += surplus;
      }
    } else if (expenses > budget) {
      final double overBudget = expenses - budget;
      currentDebt += overBudget;
    }

    state = state.copyWith(
      savingsDebt: currentDebt,
      totalSavings: currentSavings,
    );
    _persist();
  }

  /// Settle today's budget surplus & debt using today's active budget and today's expenses.
  void settleTodayBudgetSurplusAndDebt() {
    final double budget = state.settings.dailyLimit ?? 0.0;
    final double expenses = state.dailySpent;
    applyDailyBudgetSurplusAndDebt(budget: budget, expenses: expenses);
  }

  /// Sets savings debt directly (useful for testing or initial adjustments).
  void setSavingsDebt(double debt) {
    state = state.copyWith(savingsDebt: debt < 0 ? 0.0 : debt);
    _persist();
  }

  /// Sets total savings directly (useful for testing or initial adjustments).
  void setTotalSavings(double savings) {
    state = state.copyWith(totalSavings: savings < 0 ? 0.0 : savings);
    _persist();
  }

  BudgetSummary get summary => _service.computeSummary(
        state.copyWith(
          expenses: state.expenses
              .where((ExpenseEntry expense) => expense.source != 'togetherSpend')
              .toList(),
        ),
        now: now,
      );

  List<MealSuggestion> mealsFor(
      {MealCategory category = MealCategory.budgetMeals, MealType? mealType}) {
    return _service.recommendMeals(
      state: state,
      category: category,
      mealType: mealType,
      remainingBudget: summary.remainingBalance,
    );
  }

  List<ActivitySuggestion> activitiesFor(
      {GalaMood mood = GalaMood.chill, double preferredDistanceKm = 5}) {
    final double budget =
        state.settings.hasConfiguredBudget ? summary.totalBudget : 0;
    return _service.recommendActivities(
      mood: mood,
      budget: budget,
      preferredDistanceKm: preferredDistanceKm,
    );
  }

  void _startMidnightCheckTimer() {
    _midnightCheckTimer?.cancel();
    _midnightCheckTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      final DateTime currentNow = now;
      final DateTime todayStart =
          DateTime(currentNow.year, currentNow.month, currentNow.day);
      if (state.dailyPeriodStart != null &&
          state.dailyPeriodStart!.isBefore(todayStart)) {
        syncDateAndCheckMidnightReset();
      }
    });
  }

  @override
  void dispose() {
    _midnightCheckTimer?.cancel();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    final BudgetBuddyState loaded = await _repository.loadState();
    state = loaded.copyWith(isBootstrapping: false);
    _renewBudgetIfNeeded();
    await syncDateAndCheckMidnightReset();
  }

  Future<void> _persist() async {
    _renewBudgetIfNeeded();
    _refreshPeriodTracking();
    _backfillMissingDays();
    await _repository.saveState(state);
  }

  void _refreshPeriodTracking() {
    final DateTime currentNow = now;
    _archiveElapsedPeriods(currentNow);
    _recalculatePeriodSpending(currentNow);
  }

  void _archiveElapsedPeriods(DateTime now) {
    final DateTime currentDailyStart = _periodStart(BudgetPeriod.daily, now);
    final DateTime currentWeeklyStart = _periodStart(BudgetPeriod.weekly, now);
    final DateTime currentMonthlyStart =
        _periodStart(BudgetPeriod.monthly, now);

    final List<PeriodReport> updatedReports = <PeriodReport>[
      ...state.periodReports
    ];

    DateTime? dailyStart = state.dailyPeriodStart;
    DateTime? weeklyStart = state.weeklyPeriodStart;
    DateTime? monthlyStart = state.monthlyPeriodStart;

    if (dailyStart != null && dailyStart.isBefore(currentDailyStart)) {
      DateTime cursor = dailyStart;
      while (cursor.isBefore(currentDailyStart)) {
        final DateTime next = _nextPeriodStart(BudgetPeriod.daily, cursor);
        _appendPeriodReport(
          reports: updatedReports,
          period: BudgetPeriod.daily,
          start: cursor,
          endExclusive: next,
        );
        cursor = next;
      }
    }

    if (weeklyStart != null && weeklyStart.isBefore(currentWeeklyStart)) {
      DateTime cursor = weeklyStart;
      while (cursor.isBefore(currentWeeklyStart)) {
        final DateTime next = _nextPeriodStart(BudgetPeriod.weekly, cursor);
        _appendPeriodReport(
          reports: updatedReports,
          period: BudgetPeriod.weekly,
          start: cursor,
          endExclusive: next,
        );
        cursor = next;
      }
    }

    if (monthlyStart != null && monthlyStart.isBefore(currentMonthlyStart)) {
      DateTime cursor = monthlyStart;
      while (cursor.isBefore(currentMonthlyStart)) {
        final DateTime next = _nextPeriodStart(BudgetPeriod.monthly, cursor);
        _appendPeriodReport(
          reports: updatedReports,
          period: BudgetPeriod.monthly,
          start: cursor,
          endExclusive: next,
        );
        cursor = next;
      }
    }

    if (updatedReports.length > 300) {
      updatedReports.removeRange(0, updatedReports.length - 300);
    }

    state = state.copyWith(
      dailyPeriodStart: currentDailyStart,
      weeklyPeriodStart: currentWeeklyStart,
      monthlyPeriodStart: currentMonthlyStart,
      periodReports: updatedReports,
    );
  }

  void _appendPeriodReport({
    required List<PeriodReport> reports,
    required BudgetPeriod period,
    required DateTime start,
    required DateTime endExclusive,
  }) {
    final bool alreadyArchived = reports.any(
      (PeriodReport r) => r.period == period && _isSameDay(r.startDate, start),
    );
    if (alreadyArchived) {
      return;
    }

    double? limit = _periodLimit(period);
    if (period == BudgetPeriod.daily) {
      final BudgetEntry? entry = state.budgetEntries
          .cast<BudgetEntry?>()
          .firstWhere(
            (BudgetEntry? e) => e != null && _isSameDay(e.date, start),
            orElse: () => null,
          );
      if (entry != null && entry.amount > 0) {
        limit = entry.amount;
      }
    }
    if (limit == null || limit <= 0) {
      return;
    }

    final double spent = _sumExpensesInRange(start, endExclusive);
    reports.add(
      PeriodReport(
        period: period,
        startDate: start,
        endDate: endExclusive.subtract(const Duration(milliseconds: 1)),
        limit: limit,
        totalSpent: spent,
        savedAmount: limit - spent,
      ),
    );
  }

  void _recalculatePeriodSpending(DateTime now) {
    final DateTime dailyStart =
        state.dailyPeriodStart ?? _periodStart(BudgetPeriod.daily, now);
    final DateTime weeklyStart =
        state.weeklyPeriodStart ?? _periodStart(BudgetPeriod.weekly, now);
    final DateTime monthlyStart =
        state.monthlyPeriodStart ?? _periodStart(BudgetPeriod.monthly, now);

    state = state.copyWith(
      dailySpent: _sumExpensesSince(dailyStart, now),
      weeklySpent: _sumExpensesSince(weeklyStart, now),
      monthlySpent: _sumExpensesSince(monthlyStart, now),
      dailyPeriodStart: dailyStart,
      weeklyPeriodStart: weeklyStart,
      monthlyPeriodStart: monthlyStart,
    );
  }

  double _sumExpensesSince(DateTime start, DateTime endInclusive) {
    return state.expenses
        .where((ExpenseEntry expense) =>
            expense.source != 'togetherSpend' &&
            !expense.dateTime.isBefore(start) &&
            !expense.dateTime.isAfter(endInclusive))
        .fold(0, (double sum, ExpenseEntry expense) => sum + expense.amount);
  }

  double _sumExpensesInRange(DateTime start, DateTime endExclusive) {
    return state.expenses
        .where((ExpenseEntry expense) =>
            expense.source != 'togetherSpend' &&
            !expense.dateTime.isBefore(start) &&
            expense.dateTime.isBefore(endExclusive))
        .fold(0, (double sum, ExpenseEntry expense) => sum + expense.amount);
  }

  DateTime _periodStart(BudgetPeriod period, DateTime now) {
    return switch (period) {
      BudgetPeriod.daily => DateTime(now.year, now.month, now.day),
      BudgetPeriod.weekly => DateTime(now.year, now.month, now.day).subtract(
          Duration(days: now.weekday - DateTime.monday),
        ),
      BudgetPeriod.monthly => DateTime(now.year, now.month, 1),
    };
  }

  DateTime _nextPeriodStart(BudgetPeriod period, DateTime currentStart) {
    return switch (period) {
      BudgetPeriod.daily => currentStart.add(const Duration(days: 1)),
      BudgetPeriod.weekly => currentStart.add(const Duration(days: 7)),
      BudgetPeriod.monthly =>
        DateTime(currentStart.year, currentStart.month + 1, 1),
    };
  }

  double? _periodLimit(BudgetPeriod period) {
    return switch (period) {
      BudgetPeriod.daily => state.settings.dailyLimit,
      BudgetPeriod.weekly => state.settings.weeklyLimit,
      BudgetPeriod.monthly => state.settings.monthlyLimit,
    };
  }

  void _renewBudgetIfNeeded() {
    final BudgetSettings settings = state.settings;
    if (!settings.hasConfiguredBudget ||
        !settings.autoRenewBudget ||
        settings.budgetCreatedAt == null) {
      return;
    }

    if (!_isBudgetExpired(settings, now)) {
      return;
    }

    state = state.copyWith(
      settings: settings.copyWith(budgetCreatedAt: now),
    );
  }

  bool _isBudgetExpired(BudgetSettings settings, DateTime now) {
    final DateTime? createdAt = settings.budgetCreatedAt;
    if (createdAt == null) {
      return false;
    }

    final Duration cycle = switch (settings.budgetExpiryPeriod) {
      BudgetExpiryPeriod.daily => const Duration(days: 1),
      BudgetExpiryPeriod.weekly => const Duration(days: 7),
      BudgetExpiryPeriod.monthly => const Duration(days: 30),
    };
    return !createdAt.add(cycle).isAfter(now);
  }

  Future<void> syncDateAndCheckMidnightReset({bool forceReset = false}) async {
    final DateTime currentNow = now;
    final DateTime todayStart =
        DateTime(currentNow.year, currentNow.month, currentNow.day);
    final DateTime? lastDailyStart = state.dailyPeriodStart;

    if (lastDailyStart == null && !forceReset) {
      state = state.copyWith(dailyPeriodStart: todayStart);
      _recalculatePeriodSpending(now);
      _backfillMissingDays(currentDate: now);
      await _repository.saveState(state);
      return;
    }

    if (forceReset || (lastDailyStart != null && lastDailyStart.isBefore(todayStart))) {
      // 0. Settle the ending day's budget surplus & debt before clearing today
      final DateTime endingDay = lastDailyStart ?? todayStart;
      final BudgetEntry? endingEntry = state.budgetEntries
          .cast<BudgetEntry?>()
          .firstWhere(
            (BudgetEntry? e) => e != null && _isSameDay(e.date, endingDay),
            orElse: () => null,
          );
      final double endingBudget =
          endingEntry?.amount ?? (state.settings.dailyLimit ?? 0.0);
      final double endingExpenses = state.dailySpent;

      if (endingBudget > 0 || endingExpenses > 0) {
        applyDailyBudgetSurplusAndDebt(
          budget: endingBudget,
          expenses: endingExpenses,
        );
      }

      // 1. Archive elapsed periods up to today before clearing
      _archiveElapsedPeriods(now);

      // 2. Backfill records up to yesterday (or now if same-day force)
      final DateTime backfillCutoff =
          (lastDailyStart != null && lastDailyStart.isBefore(todayStart))
              ? todayStart.subtract(const Duration(seconds: 1))
              : now;
      _backfillMissingDays(currentDate: backfillCutoff);

      // 3. Reset today's active budget and expense entry
      final List<ExpenseEntry> pastExpenses = state.expenses
          .where((ExpenseEntry expense) =>
              expense.dateTime.isBefore(todayStart))
          .toList();
      final List<BudgetEntry> pastBudgetEntries = state.budgetEntries
          .where((BudgetEntry entry) => !_isSameDay(entry.date, todayStart))
          .toList();

      state = state.copyWith(
        expenses: pastExpenses,
        budgetEntries: pastBudgetEntries,
        dailySpent: 0,
        lastExpenseCategory: null,
        dailyPeriodStart: todayStart,
        settings: state.settings.copyWith(
          dailyLimit: null,
          hasConfiguredBudget: state.settings.weeklyLimit != null ||
              state.settings.monthlyLimit != null,
        ),
      );

      // 4. Notify if notifyOnDailyReset is enabled
      if (state.settings.notifyOnDailyReset) {
        _notificationService.showBudgetReminder(
          title: 'Daily Budget Reset',
          body:
              'A new day has started! Your daily budget and today\'s entries have reset.',
        );
      }

      // 5. Recalculate spending and backfill through today
      _recalculatePeriodSpending(now);
      _backfillMissingDays(currentDate: now);
      await _repository.saveState(state);
    } else {
      // Same day: ensure missing days are backfilled and save
      _refreshPeriodTracking();
      _backfillMissingDays(currentDate: now);
      await _repository.saveState(state);
    }
  }

  void _backfillMissingDays({DateTime? currentDate}) {
    final DateTime currentNow = currentDate ?? now;
    final DateTime today =
        DateTime(currentNow.year, currentNow.month, currentNow.day);

    final List<ExpenseEntry> mainExpenses = state.expenses
        .where((ExpenseEntry expense) => expense.source != 'togetherSpend')
        .toList();
    final BudgetSummary currentSummary =
        _service.computeSummary(state.copyWith(expenses: mainExpenses));

    final Set<DateTime> knownDateSet = <DateTime>{};

    for (final DailyRecord record in state.dailyRecords) {
      knownDateSet
          .add(DateTime(record.date.year, record.date.month, record.date.day));
    }
    for (final ExpenseEntry expense in state.expenses) {
      if (expense.source != 'togetherSpend') {
        knownDateSet.add(DateTime(
          expense.dateTime.year,
          expense.dateTime.month,
          expense.dateTime.day,
        ));
      }
    }
    for (final BudgetEntry entry in state.budgetEntries) {
      knownDateSet.add(DateTime(
        entry.date.year,
        entry.date.month,
        entry.date.day,
      ));
    }
    if (state.dailyPeriodStart != null) {
      final DateTime pStart = state.dailyPeriodStart!;
      knownDateSet.add(DateTime(pStart.year, pStart.month, pStart.day));
    }
    if (state.settings.budgetCreatedAt != null) {
      final DateTime cDate = state.settings.budgetCreatedAt!;
      knownDateSet.add(DateTime(cDate.year, cDate.month, cDate.day));
    }

    knownDateSet.add(today);

    final List<DateTime> sortedKnownDates = knownDateSet.toList()
      ..sort((DateTime a, DateTime b) => a.compareTo(b));

    DateTime earliest = sortedKnownDates.first;
    final DateTime maxPast = today.subtract(const Duration(days: 365));
    if (earliest.isBefore(maxPast)) {
      earliest = maxPast;
    }

    final List<DailyRecord> updatedRecords = <DailyRecord>[
      ...state.dailyRecords
    ];

    DateTime cursor = earliest;
    while (!cursor.isAfter(today)) {
      final int existingIndex = updatedRecords.indexWhere(
        (DailyRecord r) => _isSameDay(r.date, cursor),
      );

      if (existingIndex < 0) {
        // Missing day! Backfill record
        updatedRecords.add(_buildDailyRecordForDate(cursor));
      } else if (_isSameDay(cursor, today)) {
        // Update today's record with active data
        updatedRecords[existingIndex] = _buildDailyRecordForDate(
          today,
          todaySummary: currentSummary,
        );
      }

      cursor = DateTime(cursor.year, cursor.month, cursor.day + 1);
    }

    updatedRecords
        .sort((DailyRecord a, DailyRecord b) => a.date.compareTo(b.date));

    while (updatedRecords.length > 365) {
      updatedRecords.removeAt(0);
    }

    state = state.copyWith(dailyRecords: updatedRecords);
  }

  DailyRecord _buildDailyRecordForDate(
    DateTime date, {
    BudgetSummary? todaySummary,
  }) {
    final DateTime dayStart = DateTime(date.year, date.month, date.day);
    final DateTime currentNow = now;
    final bool isToday = _isSameDay(dayStart, currentNow);

    final BudgetEntry? entry = state.budgetEntries
        .cast<BudgetEntry?>()
        .firstWhere(
          (BudgetEntry? e) => e != null && _isSameDay(e.date, dayStart),
          orElse: () => null,
        );

    double dayBudget = entry?.amount ?? 0.0;
    if (dayBudget <= 0 && isToday) {
      dayBudget = state.settings.dailyLimit ?? 0.0;
    }

    if (isToday && todaySummary != null) {
      return DailyRecord(
        date: dayStart,
        budget: dayBudget,
        totalSpent: todaySummary.totalSpent,
        remainingBalance: todaySummary.remainingBalance,
        savings: todaySummary.savings,
        biggestExpenseCategory: todaySummary.biggestExpenseCategory,
        categoryTotals: todaySummary.categoryTotals,
      );
    }

    final List<ExpenseEntry> dayExpenses = state.expenses
        .where((ExpenseEntry expense) =>
            expense.source != 'togetherSpend' &&
            _isSameDay(expense.dateTime, dayStart))
        .toList();

    final double totalSpent = dayExpenses.fold(
      0.0,
      (double sum, ExpenseEntry expense) => sum + expense.amount,
    );

    final Map<String, double> categoryTotals = <String, double>{
      for (final BudgetCategory category in BudgetCategory.values)
        category.label: 0.0,
    };
    for (final ExpenseEntry expense in dayExpenses) {
      categoryTotals[expense.category.label] =
          (categoryTotals[expense.category.label] ?? 0.0) + expense.amount;
    }

    final String biggestExpenseCategory = dayExpenses.isEmpty
        ? BudgetCategory.miscellaneous.label
        : dayExpenses
            .reduce((ExpenseEntry a, ExpenseEntry b) =>
                a.amount >= b.amount ? a : b)
            .category
            .label;

    final double remainingBalance = dayBudget > 0
        ? (dayBudget - totalSpent)
        : (totalSpent > 0 ? -totalSpent : 0.0);
    final double savings = dayBudget > 0
        ? (dayBudget - totalSpent)
        : (totalSpent > 0 ? -totalSpent : 0.0);

    return DailyRecord(
      date: dayStart,
      budget: dayBudget,
      totalSpent: totalSpent,
      remainingBalance: remainingBalance,
      savings: savings,
      biggestExpenseCategory: biggestExpenseCategory,
      categoryTotals: categoryTotals,
    );
  }

  Future<void> _syncDailyRecord() async {
    _backfillMissingDays();
  }

  bool _isSameDay(DateTime left, DateTime right) {
    return left.year == right.year &&
        left.month == right.month &&
        left.day == right.day;
  }

  void updateBudget(BudgetSettings settings) {
    state = state.copyWith(
      settings: settings.copyWith(hasConfiguredBudget: settings.hasActiveLimit),
    );
    _persist();
  }

  void setTogetherBudget(double amount) {
    state = state.copyWith(togetherBudget: amount > 0 ? amount : 0);
    _persist();
  }

  void updateSavingsTarget({
    required double amount,
    required DateTime targetDate,
  }) {
    state = state.copyWith(
      settings: state.settings.copyWith(
        savingsTargetAmount: amount,
        savingsTargetDate: targetDate,
      ),
    );
    _persist();
  }

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
        notifyOnDailyReset: notifyOnDailyReset,
        streakNotificationsEnabled: streakNotificationsEnabled,
        notificationReminderMinuteOfDay: notificationReminderMinuteOfDay,
        notificationFrequency: notificationFrequency,
        includeYesterdaySpentInSummary: includeYesterdaySpentInSummary,
        dayStartMinuteOfDay: dayStartMinuteOfDay,
      ),
      notificationsEnabled: notificationsEnabled ?? state.notificationsEnabled,
    );
    _persist();
  }

  void restoreSnapshot(BudgetBuddyState snapshot) {
    // Only restore: Expenses, Savings (daily and monthly), and Budget Together data
    state = state.copyWith(
      expenses: snapshot.expenses,
      dailyRecords: snapshot.dailyRecords,
      periodReports: snapshot.periodReports,
      budgetEntries: snapshot.budgetEntries,
      togetherBudget: snapshot.togetherBudget,
      settings: state.settings.copyWith(
        dailyLimit: snapshot.settings.dailyLimit,
        weeklyLimit: snapshot.settings.weeklyLimit,
        monthlyLimit: snapshot.settings.monthlyLimit,
        hasConfiguredBudget: snapshot.settings.hasConfiguredBudget,
      ),
      dailySpent: snapshot.dailySpent,
      weeklySpent: snapshot.weeklySpent,
      monthlySpent: snapshot.monthlySpent,
      dailyPeriodStart: snapshot.dailyPeriodStart,
      weeklyPeriodStart: snapshot.weeklyPeriodStart,
      monthlyPeriodStart: snapshot.monthlyPeriodStart,
      isBootstrapping: false,
    );
    _persist();
  }

  void completeOnboarding() {
    state = state.copyWith(onboardingComplete: true);
    _persist();
  }

  void login(String displayName, {String city = 'Makati'}) {
    final String initials = displayName.trim().isEmpty
        ? 'BB'
        : displayName
            .trim()
            .split(RegExp(r'\s+'))
            .take(2)
            .map((String part) => part.isNotEmpty ? part[0] : '')
            .join()
            .toUpperCase();

    state = state.copyWith(
      loggedIn: true,
      profile: state.profile.copyWith(
          displayName: displayName.trim().isEmpty
              ? state.profile.displayName
              : displayName.trim(),
          city: city,
          avatarSeed: initials),
    );
    _persist();
  }

  Future<void> registerAccount(String displayName) async {
    login(displayName);
    await _repository.saveRegisteredProfile(state.profile);
    await _repository.saveState(state);
  }

  Future<void> loginRegisteredAccount() async {
    final UserProfile? saved = await _repository.loadRegisteredProfile();
    if (saved == null) {
      return;
    }
    final BudgetBuddyState loaded = await _repository.loadState();
    state = loaded.copyWith(profile: saved, loggedIn: true);
    _persist();
  }

  void logout() {
    state = state.copyWith(loggedIn: false);
    _persist();
  }

  void updateProfile(UserProfile profile) {
    state = state.copyWith(profile: profile);
    _persist();
  }

  void setThemeMode(ThemeMode mode) {
    state = state.copyWith(themeMode: mode);
    _persist();
  }

  void setNotificationsEnabled(bool enabled) {
    state = state.copyWith(notificationsEnabled: enabled);
    _persist();
  }

  void addExpense({
    required String title,
    required double amount,
    required BudgetCategory category,
    String note = '',
    DateTime? dateTime,
    String source = 'manual',
    String spendCategory = '',
  }) {
    final ExpenseEntry entry = ExpenseEntry(
      id: _uuid.v4(),
      title: title,
      amount: amount,
      category: category,
      dateTime: dateTime ?? now,
      note: note,
      source: source,
      spendCategory: spendCategory,
    );
    state = state.copyWith(
        expenses: <ExpenseEntry>[entry, ...state.expenses],
        lastExpenseCategory: category);
    _persist();
    _triggerWarningIfNeeded();
  }

  void recordDailyBudget({
    required double amount,
    DateTime? date,
  }) {
    final DateTime budgetDate = DateTime(
      (date ?? now).year,
      (date ?? now).month,
      (date ?? now).day,
    );
    final List<BudgetEntry> updatedEntries = <BudgetEntry>[
      ...state.budgetEntries.where(
        (BudgetEntry entry) => !_isSameDay(entry.date, budgetDate),
      ),
      if (amount > 0) BudgetEntry(date: budgetDate, amount: amount),
    ]..sort((BudgetEntry left, BudgetEntry right) {
        return left.date.compareTo(right.date);
      });

    state = state.copyWith(
      budgetEntries: updatedEntries,
      dailyPeriodStart: budgetDate,
      settings: state.settings.copyWith(
        dailyLimit: amount > 0 ? amount : null,
        hasConfiguredBudget: amount > 0 ||
            state.settings.weeklyLimit != null ||
            state.settings.monthlyLimit != null,
        budgetCreatedAt: now,
      ),
    );
    _persist();
  }

  void clearDailyBudget({DateTime? date}) {
    final DateTime targetDate = DateTime(
      (date ?? now).year,
      (date ?? now).month,
      (date ?? now).day,
    );

    final List<BudgetEntry> updatedEntries = state.budgetEntries
        .where((BudgetEntry entry) => !_isSameDay(entry.date, targetDate))
        .toList();

    // When budget is reset, also reset today's spend because there is no budget to spend
    final List<ExpenseEntry> remainingExpenses = state.expenses
        .where((ExpenseEntry entry) => !_isSameDay(entry.dateTime, targetDate))
        .toList();

    state = state.copyWith(
      expenses: remainingExpenses,
      budgetEntries: updatedEntries,
      dailySpent: 0,
      dailyPeriodStart: targetDate,
      settings: state.settings.copyWith(
        dailyLimit: null,
        hasConfiguredBudget: state.settings.weeklyLimit != null ||
            state.settings.monthlyLimit != null,
        budgetCreatedAt: now,
      ),
    );
    _persist();
  }

  void updateExpense(ExpenseEntry expense) {
    final List<ExpenseEntry> updated = state.expenses.map((ExpenseEntry entry) {
      return entry.id == expense.id ? expense : entry;
    }).toList();
    state = state.copyWith(
        expenses: updated, lastExpenseCategory: expense.category);
    _persist();
  }

  void deleteExpense(String id) {
    deleteExpenses(<String>[id]);
  }

  void deleteExpenses(Iterable<String> ids) {
    final Set<String> idSet = ids.toSet();
    state = state.copyWith(
      expenses: state.expenses
          .where((ExpenseEntry entry) => !idSet.contains(entry.id))
          .toList(),
    );
    _persist();
  }

  void restoreExpense(ExpenseEntry expense) {
    final List<ExpenseEntry> updated = <ExpenseEntry>[
      expense,
      ...state.expenses.where((ExpenseEntry entry) => entry.id != expense.id),
    ];
    state = state.copyWith(
      expenses: updated,
      lastExpenseCategory: expense.category,
    );
    _persist();
  }

  void addCustomMeal(MealSuggestion meal) {
    final List<MealSuggestion> updated = <MealSuggestion>[
      meal,
      ...state.customMeals
    ];
    state = state.copyWith(customMeals: updated);
    _persist();
  }

  void updateCustomMeal(MealSuggestion meal) {
    final List<MealSuggestion> updated = state.customMeals.map((m) {
      return m.id == meal.id ? meal : m;
    }).toList();
    state = state.copyWith(customMeals: updated);
    _persist();
  }

  void deleteCustomMeal(String mealId) {
    final List<MealSuggestion> updated =
        state.customMeals.where((m) => m.id != mealId).toList();
    state = state.copyWith(customMeals: updated);
    _persist();
  }

  void toggleFavoriteMeal(String mealId) {
    final Set<String> favorites = state.favoriteMealIds.toSet();
    if (favorites.contains(mealId)) {
      favorites.remove(mealId);
    } else {
      favorites.add(mealId);
    }
    state = state.copyWith(favoriteMealIds: favorites.toList());
    _persist();
  }

  void saveActivityPlan(ActivitySuggestion activitySuggestion) {
    final List<ActivitySuggestion> updated = <ActivitySuggestion>[
      activitySuggestion,
      ...state.savedActivityPlans.where((ActivitySuggestion activity) =>
          activity.id != activitySuggestion.id),
    ];
    state = state.copyWith(savedActivityPlans: updated.take(6).toList());
    _persist();
  }

  Future<void> exportReport() async {
    await _repository.saveState(state);
  }

  void setExpenseFilter(BudgetCategory? category) {
    state = state.copyWith(currentExpenseFilter: category);
  }

  void setDashboardPeriod(DashboardPeriod period) {
    state = state.copyWith(dashboardPeriod: period);
  }

  void resetForNextDay() {
    syncDateAndCheckMidnightReset(forceReset: true);
  }

  Future<void> resetApp() async {
    _simulatedDateTime = null;
    final DateTime currentRealNow = DateTime.now();
    final DateTime currentDayStart =
        DateTime(currentRealNow.year, currentRealNow.month, currentRealNow.day);

    // Reset to absolute zero state: all budgets, expenses, spending, savings, debts, and history logs cleared
    state = BudgetBuddyState.initial().copyWith(
      isBootstrapping: false,
      loggedIn: state.loggedIn,
      onboardingComplete: state.onboardingComplete,
      profile: state.profile.copyWith(savingsStreak: 0),
      themeMode: state.themeMode,
      notificationsEnabled: state.notificationsEnabled,
      expenses: <ExpenseEntry>[],
      budgetEntries: <BudgetEntry>[],
      dailyRecords: <DailyRecord>[],
      periodReports: const <PeriodReport>[],
      customMeals: <MealSuggestion>[],
      favoriteMealIds: <String>[],
      savedActivityPlans: <ActivitySuggestion>[],
      togetherBudget: 0.0,
      dailySpent: 0.0,
      weeklySpent: 0.0,
      monthlySpent: 0.0,
      savingsDebt: 0.0,
      totalSavings: 0.0,
      dailyPeriodStart: currentDayStart,
      weeklyPeriodStart: null,
      monthlyPeriodStart: null,
      currentExpenseFilter: null,
      lastExpenseCategory: null,
      settings: BudgetSettings.defaults().copyWith(
        dailyLimit: null,
        weeklyLimit: null,
        monthlyLimit: null,
        foodBudget: 0.0,
        transportationBudget: 0.0,
        leisureBudget: 0.0,
        savingsGoal: 0.0,
        savingsTargetAmount: 0.0,
        savingsTargetDate: null,
        hasConfiguredBudget: false,
        budgetCreatedAt: null,
      ),
    );
    await _repository.clearAll();
    await _repository.saveState(state);
  }

  void sendSummaryNotification() {
    final BudgetSummary currentSummary = summary;
    _notificationService.showEndOfDaySummary(
      title: 'BudgetBuddy summary',
      body:
          'You spent ${currentSummary.totalSpent.toStringAsFixed(0)} pesos and saved ${currentSummary.savings.toStringAsFixed(0)} pesos today.',
    );
  }

  void _triggerWarningIfNeeded() {
    final BudgetSummary currentSummary = summary;
    final BudgetPeriodSummary primarySummary = <BudgetPeriodSummary?>[
      currentSummary.periodSummaries[BudgetPeriod.daily],
      currentSummary.periodSummaries[BudgetPeriod.weekly],
      currentSummary.periodSummaries[BudgetPeriod.monthly],
    ].whereType<BudgetPeriodSummary>().firstWhere(
          (BudgetPeriodSummary summary) => summary.isActive,
          orElse: () => const BudgetPeriodSummary(
            period: BudgetPeriod.daily,
            limit: 0,
            spent: 0,
          ),
        );

    if (!primarySummary.isActive) {
      return;
    }

    if (primarySummary.isOverspent || primarySummary.isWarning) {
      _notificationService.showBudgetReminder(
        title: 'Budget warning',
        body: primarySummary.warningMessage,
      );
    }
  }
}
