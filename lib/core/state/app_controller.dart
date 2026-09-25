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

final homeShellIndexProvider = StateProvider<int>((Ref ref) => 0);

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
  final BudgetBuddyController controller =
      ref.watch(budgetBuddyControllerProvider.notifier);
  final BudgetBuddyState state = ref.watch(budgetBuddyControllerProvider);
  final List<ExpenseEntry> mainExpenses = state.expenses
      .where((ExpenseEntry expense) => expense.source != 'togetherSpend')
      .toList();
  final BudgetBuddyState mainState = state.copyWith(expenses: mainExpenses);
  return ref
      .watch(budgetServiceProvider)
      .computeSummary(mainState, now: controller.now);
});

final budgetTogetherSummaryProvider =
    Provider<BudgetSummary>((Ref<BudgetSummary> ref) {
  final BudgetBuddyController controller =
      ref.watch(budgetBuddyControllerProvider.notifier);
  final BudgetBuddyState state = ref.watch(budgetBuddyControllerProvider);
  final BudgetService service = ref.watch(budgetServiceProvider);
  final double togetherBudget = state.togetherBudget;
  final DateTime now = controller.now;
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

  final double grossDailyTogetherSpent = sumSince(dailyStart);
  final double togetherOverspent = togetherBudget > 0
      ? (grossDailyTogetherSpent - togetherBudget).clamp(0.0, double.infinity)
      : grossDailyTogetherSpent;
  final double togetherPaidDebt = state.vaultLog
      .where((VaultLogEntry log) =>
          log.type == VaultLogType.payDebt &&
          (log.isTogether == true ||
              log.description.toLowerCase().contains('together')) &&
          log.description.toLowerCase().contains('deficit payment') &&
          DateUtils.isSameDay(log.dateTime, now))
      .fold(0.0, (double sum, VaultLogEntry log) => sum + log.amount);
  final double togetherDebtRelief =
      togetherPaidDebt.clamp(0.0, togetherOverspent);
  final double netDailyTogetherSpent =
      (grossDailyTogetherSpent - togetherDebtRelief)
          .clamp(0.0, double.infinity);

  final BudgetBuddyState togetherState = state.copyWith(
    settings: state.settings.copyWith(
      dailyLimit: togetherBudget,
      weeklyLimit: null,
      monthlyLimit: null,
      hasConfiguredBudget: togetherBudget > 0,
    ),
    expenses: spendExpenses,
    dailySpent: netDailyTogetherSpent,
    weeklySpent: (sumSince(weeklyStart) - togetherDebtRelief)
        .clamp(0.0, double.infinity),
    monthlySpent: (sumSince(monthlyStart) - togetherDebtRelief)
        .clamp(0.0, double.infinity),
    budgetEntries: <BudgetEntry>[],
  );

  return service.computeSummary(togetherState, now: now);
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
  DateTime? _lastSettledDate;

  DateTime get now => state.simulatedDateTime ?? DateTime.now();
  bool get isTimeSimulated => state.isTimeSimulated;
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

    state = state.copyWith(simulatedDateTime: dateTime);
    await syncDateAndCheckMidnightReset(
      forceReset: shouldForce,
      endingDateOverride: shouldForce ? currentTodayStart : null,
    );
  }

  Future<void> simulateMidnightReset() async {
    final DateTime current = now;
    final DateTime endingDay =
        DateTime(current.year, current.month, current.day);
    final DateTime nextDayMidnight =
        DateTime(current.year, current.month, current.day + 1, 0, 0, 0);
    state = state.copyWith(simulatedDateTime: nextDayMidnight);
    await syncDateAndCheckMidnightReset(
      forceReset: true,
      endingDateOverride: endingDay,
    );
  }

  Future<void> fastForwardOneDay() async {
    final DateTime current = now;
    final DateTime endingDay =
        DateTime(current.year, current.month, current.day);
    final DateTime nextDayMidnight =
        DateTime(current.year, current.month, current.day + 1);
    state = state.copyWith(simulatedDateTime: nextDayMidnight);
    await syncDateAndCheckMidnightReset(
      forceReset: true,
      endingDateOverride: endingDay,
    );
  }

  Future<void> setSimulatedTimeTo1159PM() async {
    final DateTime current = now;
    final DateTime tonite1159 =
        DateTime(current.year, current.month, current.day, 23, 59, 0);
    state = state.copyWith(simulatedDateTime: tonite1159);
    await syncDateAndCheckMidnightReset();
  }

  Future<void> resetSimulatedTime() async {
    state = state.copyWith(clearSimulatedDateTime: true);
    await syncDateAndCheckMidnightReset();
  }

  double get savingsDebt => state.savingsDebt;
  double get totalSavings => state.totalSavings;

  /// Applies the budget surplus & savings debt logic at midnight settlement:
  /// - If Today's Budget > Today's Expenses: surplus goes directly to totalSavings.
  ///   Debt is NEVER auto-paid from surplus — it must be paid explicitly via paySavingsDebt.
  /// - If Today's Expenses > Today's Budget: Add the over-budget difference to savingsDebt.
  void applyDailyBudgetSurplusAndDebt({
    required double budget,
    required double expenses,
  }) {
    double currentDebt = state.savingsDebt;
    double currentSavings = state.totalSavings;

    if (budget > expenses) {
      final double surplus = budget - expenses;
      // Surplus goes directly to savings. Debt is separate and paid only explicitly.
      currentSavings += surplus;
    } else if (expenses > budget) {
      final double overBudget = expenses - budget;
      currentDebt += overBudget;
    }

    final double prevSavings = state.totalSavings;
    state = state.copyWith(
      savingsDebt: currentDebt,
      totalSavings: currentSavings,
    );
    // Log auto-save if surplus went to vault
    final double savedAmount = currentSavings - prevSavings;
    if (savedAmount > 0) {
      addVaultLog(
        type: VaultLogType.autoSave,
        amount: savedAmount,
        description: 'Daily budget surplus auto-saved at midnight',
      );
    }
    _persist();
  }

  /// Settle today's budget surplus & debt using today's active budget and today's expenses.
  void settleTodayBudgetSurplusAndDebt() {
    final double budget = state.settings.dailyLimit ?? 0.0;
    final double expenses = state.dailySpent;
    applyDailyBudgetSurplusAndDebt(budget: budget, expenses: expenses);
  }

  /// Adds an entry to the vault transaction log.
  void addVaultLog({
    required VaultLogType type,
    required double amount,
    required String description,
    bool isTogether = false,
  }) {
    if (amount <= 0) return;
    final VaultLogEntry entry = VaultLogEntry(
      id: _uuid.v4(),
      type: type,
      amount: amount,
      description: description,
      dateTime: now,
      isTogether: isTogether,
    );
    final List<VaultLogEntry> updated =
        <VaultLogEntry>[entry, ...state.vaultLog];
    // Keep at most 500 entries
    if (updated.length > 500) {
      updated.removeRange(500, updated.length);
    }
    state = state.copyWith(vaultLog: updated);
    _persist();
  }

  /// Sets savings debt directly (useful for testing or initial adjustments).
  void setSavingsDebt(double debt) {
    state = state.copyWith(savingsDebt: debt < 0 ? 0.0 : debt);
    _persist();
  }

  /// Sets total savings directly (manual deposit — logs as deposit).
  void setTotalSavings(double savings, {String? logDescription, bool isTogether = false}) {
    final double prev = state.totalSavings;
    final double newVal = savings < 0 ? 0.0 : savings;
    state = state.copyWith(totalSavings: newVal);
    _persist();
    if (logDescription != null && newVal > prev) {
      addVaultLog(
        type: VaultLogType.deposit,
        amount: newVal - prev,
        description: logDescription,
        isTogether: isTogether,
      );
    }
  }

  /// Pay down savings debt, optionally deducting from today's active budget.
  void paySavingsDebt({
    required double amount,
    bool deductFromBudget = false,
    String? description,
    bool isTogether = false,
  }) {
    if (amount <= 0) return;
    final double currentDebt = state.savingsDebt;
    final double newDebt = (currentDebt - amount).clamp(0.0, double.infinity);

    if (deductFromBudget) {
      if (isTogether) {
        final double currentTogether = state.togetherBudget;
        final double newTogether =
            (currentTogether - amount).clamp(0.0, double.infinity);
        setTogetherBudget(newTogether);
      } else {
        final double currentBudget = state.settings.dailyLimit ?? 0.0;
        final double newBudget =
            (currentBudget - amount).clamp(0.0, double.infinity);
        recordDailyBudget(amount: newBudget);
      }
    }

    setSavingsDebt(newDebt);
    addVaultLog(
      type: VaultLogType.payDebt,
      amount: amount,
      description: description ??
          (deductFromBudget
              ? (isTogether
                  ? 'Together debt payment from today\'s budget allowance'
                  : 'Debt payment from today\'s budget allowance')
              : (isTogether
                  ? 'Together debt payment from savings vault / direct'
                  : 'Debt payment from savings vault / direct')),
      isTogether: isTogether,
    );
  }

  /// Withdraw from savings vault, optionally transferring directly into today's active budget.
  void withdrawFromSavings({
    required double amount,
    bool addToDailyBudget = false,
    bool isTogether = false,
  }) {
    if (amount <= 0) return;
    final double currentSavings = state.totalSavings;
    final double newSavings =
        (currentSavings - amount).clamp(0.0, double.infinity);
    state = state.copyWith(totalSavings: newSavings);

    if (addToDailyBudget) {
      if (isTogether) {
        final double currentTogether = state.togetherBudget;
        setTogetherBudget(currentTogether + amount);
      } else {
        final double currentBudget = state.settings.dailyLimit ?? 0.0;
        recordDailyBudget(amount: currentBudget + amount);
      }
      addVaultLog(
        type: VaultLogType.withdraw,
        amount: amount,
        description: isTogether
            ? 'Withdrawn from vault → added to today\'s together budget'
            : 'Withdrawn from vault → added to today\'s budget',
        isTogether: isTogether,
      );
    } else {
      addVaultLog(
        type: VaultLogType.withdraw,
        amount: amount,
        description: isTogether
            ? 'Cash out from together vault (external)'
            : 'Cash out from vault (external)',
        isTogether: isTogether,
      );
    }
    _persist();
  }

  BudgetSummary get summary => _service.computeSummary(
        state.copyWith(
          expenses: state.expenses
              .where(
                  (ExpenseEntry expense) => expense.source != 'togetherSpend')
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
    final DateTime realToday = DateTime(
      DateTime.now().year,
      DateTime.now().month,
      DateTime.now().day,
    );
    DateTime? recoveredSimulation = loaded.simulatedDateTime;
    if (recoveredSimulation == null &&
        loaded.dailyPeriodStart != null &&
        loaded.dailyPeriodStart!.isAfter(realToday)) {
      recoveredSimulation = loaded.dailyPeriodStart;
    }
    state = loaded.copyWith(
      isBootstrapping: false,
      simulatedDateTime: recoveredSimulation,
    );
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
      final BudgetEntry? entry =
          state.budgetEntries.cast<BudgetEntry?>().firstWhere(
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

    final double grossDailySpent = _sumExpensesSince(dailyStart, now);
    final double grossWeeklySpent = _sumExpensesSince(weeklyStart, now);
    final double grossMonthlySpent = _sumExpensesSince(monthlyStart, now);

    final double todayBudget = state.settings.dailyLimit ?? 0.0;
    final double todayPaidDebt = state.vaultLog
        .where((VaultLogEntry log) =>
            log.type == VaultLogType.payDebt &&
            log.isTogether != true &&
            !log.description.toLowerCase().contains('together') &&
            log.description.toLowerCase().contains('deficit payment') &&
            DateUtils.isSameDay(log.dateTime, now))
        .fold(0.0, (double sum, VaultLogEntry log) => sum + log.amount);

    final bool hasAddToday = state.lastAddBase != null &&
        state.lastAddAmount != null &&
        state.lastAddDate != null &&
        _isSameDay(state.lastAddDate!, now);

    final double baseAbsorbedDebt = hasAddToday
        ? (state.lastAddDebtAbsorbed ?? 0.0)
        : 0.0;

    final double legitimateGross =
        (grossDailySpent - baseAbsorbedDebt).clamp(0.0, double.infinity);

    final double extraOverspend = todayBudget > 0
        ? (legitimateGross - todayBudget).clamp(0.0, double.infinity)
        : legitimateGross;

    final double todayDebtAbsorbed = baseAbsorbedDebt + extraOverspend;

    final double dailyDebtRelief = todayPaidDebt.clamp(0.0, todayDebtAbsorbed);

    // netDailySpent excludes debt-absorbed overspend so remaining = budget - legitimate spend
    final double netDailySpent =
        (grossDailySpent - todayDebtAbsorbed - dailyDebtRelief).clamp(0.0, double.infinity);
    final double netWeeklySpent =
        (grossWeeklySpent - dailyDebtRelief).clamp(0.0, double.infinity);
    final double netMonthlySpent =
        (grossMonthlySpent - dailyDebtRelief).clamp(0.0, double.infinity);

    state = state.copyWith(
      dailySpent: netDailySpent,
      weeklySpent: netWeeklySpent,
      monthlySpent: netMonthlySpent,
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

  Future<void> syncDateAndCheckMidnightReset({
    bool forceReset = false,
    DateTime? endingDateOverride,
  }) async {
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

    if (forceReset ||
        (lastDailyStart != null && lastDailyStart.isBefore(todayStart))) {
      // 0. Settle the ending day's budget surplus & debt before clearing today
      final List<DateTime> daysToSettle = <DateTime>[];

      if (endingDateOverride != null) {
        daysToSettle.add(DateTime(
          endingDateOverride.year,
          endingDateOverride.month,
          endingDateOverride.day,
        ));
      } else if (lastDailyStart != null &&
          lastDailyStart.isBefore(todayStart)) {
        DateTime cursor = DateTime(
          lastDailyStart.year,
          lastDailyStart.month,
          lastDailyStart.day,
        );
        final DateTime endBeforeToday =
            todayStart.subtract(const Duration(days: 1));
        while (!cursor.isAfter(endBeforeToday)) {
          daysToSettle.add(cursor);
          cursor = DateTime(cursor.year, cursor.month, cursor.day + 1);
        }
      } else if (forceReset) {
        // Same-day force reset: settle today before clearing
        daysToSettle.add(lastDailyStart ?? todayStart);
      }

      for (final DateTime day in daysToSettle) {
        if (_lastSettledDate != null && _isSameDay(day, _lastSettledDate!)) {
          continue; // Already settled, do not re-settle!
        }

        final BudgetEntry? entry =
            state.budgetEntries.cast<BudgetEntry?>().firstWhere(
                  (BudgetEntry? e) => e != null && _isSameDay(e.date, day),
                  orElse: () => null,
                );

        // If this is the active day before reset, allow fallback to dailyLimit.
        // If this is an unconfigured past day without a budget entry, budget is 0.0.
        final bool isCurrentActiveDay = _isSameDay(day, todayStart) ||
            (endingDateOverride != null && _isSameDay(day, endingDateOverride));

        final double dayBudget = entry?.amount ??
            (isCurrentActiveDay ? (state.settings.dailyLimit ?? 0.0) : 0.0);

        final double dayExpenses = state.expenses
            .where((ExpenseEntry expense) =>
                expense.source != 'togetherSpend' &&
                _isSameDay(expense.dateTime, day))
            .fold(0.0,
                (double sum, ExpenseEntry expense) => sum + expense.amount);

        final double dayPaidDebt = state.vaultLog
            .where((VaultLogEntry log) =>
                log.type == VaultLogType.payDebt &&
                log.isTogether != true &&
                !log.description.toLowerCase().contains('together') &&
                log.description.toLowerCase().contains('deficit payment') &&
                _isSameDay(log.dateTime, day))
            .fold(0.0, (double sum, VaultLogEntry log) => sum + log.amount);

        final double dayOverspent = dayBudget > 0
            ? (dayExpenses - dayBudget).clamp(0.0, double.infinity)
            : dayExpenses;
        final double dayDebtRelief = dayPaidDebt.clamp(0.0, dayOverspent);
        final double effectiveDayExpenses =
            (dayExpenses - dayDebtRelief).clamp(0.0, double.infinity);

        if (dayBudget > 0 || effectiveDayExpenses > 0) {
          applyDailyBudgetSurplusAndDebt(
            budget: dayBudget,
            expenses: effectiveDayExpenses,
          );
        }

        _lastSettledDate = day;
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
          .where(
              (ExpenseEntry expense) => expense.dateTime.isBefore(todayStart))
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
        lastAddBase: null,
        lastAddAmount: null,
        lastAddDate: null,
        lastAddDebtAbsorbed: null,
        settings: state.settings.copyWith(
          dailyLimit: null,
          hasConfiguredBudget: state.settings.weeklyLimit != null ||
              state.settings.monthlyLimit != null,
        ),
      );

      // 4. Notify if notifyOnDailyReset is enabled
      if (state.settings.notifyOnDailyReset) {
        _notificationService.showBudgetReminder(
          title: 'Today\'s Budget Reset',
          body:
              'A new day has started! Today\'s budget and entries have reset.',
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

      final DailyRecord newRecord =
          _buildDailyRecordForDate(cursor, currentDate: currentNow);

      if (existingIndex < 0) {
        // Missing day! Backfill record
        updatedRecords.add(newRecord);
      } else {
        // Update record with active data
        updatedRecords[existingIndex] = newRecord;
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
    DateTime? currentDate,
  }) {
    final DateTime dayStart = DateTime(date.year, date.month, date.day);
    final DateTime currentNow = currentDate ?? now;
    final bool isToday = _isSameDay(dayStart, currentNow);

    final BudgetEntry? entry =
        state.budgetEntries.cast<BudgetEntry?>().firstWhere(
              (BudgetEntry? e) => e != null && _isSameDay(e.date, dayStart),
              orElse: () => null,
            );

    double dayBudget;
    if (entry != null) {
      dayBudget = entry.amount;
    } else if (state.settings.hasConfiguredBudget) {
      dayBudget = state.settings.dailyLimit ?? 0.0;
    } else {
      dayBudget = 0.0;
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

    final double dayPaidDebt = state.vaultLog
        .where((VaultLogEntry log) =>
            log.type == VaultLogType.payDebt &&
            log.isTogether != true &&
            !log.description.toLowerCase().contains('together') &&
            log.description.toLowerCase().contains('deficit payment') &&
            _isSameDay(log.dateTime, dayStart))
        .fold(0.0, (double sum, VaultLogEntry log) => sum + log.amount);

    final double dayOverspent = dayBudget > 0
        ? (totalSpent - dayBudget).clamp(0.0, double.infinity)
        : totalSpent;
    final double dayDebtRelief = dayPaidDebt.clamp(0.0, dayOverspent);
    final double effectiveSpent =
        (totalSpent - dayDebtRelief).clamp(0.0, double.infinity);

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
        ? (dayBudget - effectiveSpent)
        : (effectiveSpent > 0 ? -effectiveSpent : 0.0);
    final double savings = dayBudget > 0
        ? (dayBudget - effectiveSpent)
        : (effectiveSpent > 0 ? -effectiveSpent : 0.0);

    return DailyRecord(
      date: dayStart,
      budget: dayBudget,
      totalSpent: effectiveSpent,
      remainingBalance: remainingBalance,
      savings: savings,
      biggestExpenseCategory: biggestExpenseCategory,
      categoryTotals: categoryTotals,
    );
  }

  bool _isSameDay(DateTime left, DateTime right) {
    return left.year == right.year &&
        left.month == right.month &&
        left.day == right.day;
  }

  void updateBudget(BudgetSettings settings) {
    final double? daily = settings.dailyLimit;
    final DateTime today = DateTime(now.year, now.month, now.day);
    List<BudgetEntry> updatedEntries = state.budgetEntries;
    if (daily != null && daily > 0) {
      updatedEntries = <BudgetEntry>[
        ...state.budgetEntries.where((e) => !_isSameDay(e.date, today)),
        BudgetEntry(date: today, amount: daily),
      ];
    }
    state = state.copyWith(
      settings: settings.copyWith(hasConfiguredBudget: settings.hasActiveLimit),
      budgetEntries: updatedEntries,
      dailyPeriodStart: state.dailyPeriodStart ?? today,
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

  void addDailyBudget({
    required double addedAmount,
    DateTime? date,
  }) {
    if (addedAmount <= 0) return;
    final double lockedDebt = state.savingsDebt;

    final DateTime targetDate = date ?? now;
    final DateTime budgetDate = DateTime(
      targetDate.year,
      targetDate.month,
      targetDate.day,
    );

    final double currentBudget = state.settings.dailyLimit ?? 0.0;
    final double newTotalBudget = currentBudget + addedAmount;

    final DateTime dailyStart =
        state.dailyPeriodStart ?? _periodStart(BudgetPeriod.daily, now);
    final double grossSpentBeforeAdd = _sumExpensesSince(dailyStart, now);

    // Any spending prior to the add that exceeded currentBudget is absorbed into debt.
    // It must NOT reduce the newly added budget allowance.
    final double debtAbsorbed = currentBudget > 0
        ? (grossSpentBeforeAdd - currentBudget).clamp(0.0, double.infinity)
        : grossSpentBeforeAdd;

    final List<BudgetEntry> updatedEntries = <BudgetEntry>[
      ...state.budgetEntries.where(
        (BudgetEntry entry) => !_isSameDay(entry.date, budgetDate),
      ),
      if (newTotalBudget > 0)
        BudgetEntry(date: budgetDate, amount: newTotalBudget),
    ]..sort((BudgetEntry left, BudgetEntry right) {
        return left.date.compareTo(right.date);
      });

    state = state.copyWith(
      budgetEntries: updatedEntries,
      dailyPeriodStart: budgetDate,
      lastAddBase: currentBudget > 0 ? currentBudget : null,
      lastAddAmount: addedAmount,
      lastAddDate: budgetDate,
      lastAddDebtAbsorbed: debtAbsorbed,
      settings: state.settings.copyWith(
        dailyLimit: newTotalBudget > 0 ? newTotalBudget : null,
        hasConfiguredBudget: newTotalBudget > 0 ||
            state.settings.weeklyLimit != null ||
            state.settings.monthlyLimit != null,
        budgetCreatedAt: now,
      ),
    );
    _recalculatePeriodSpending(now);
    _backfillMissingDays(currentDate: now);
    _persist();

    if (state.savingsDebt != lockedDebt) {
      state = state.copyWith(savingsDebt: lockedDebt);
      _repository.saveState(state);
    }
  }

  void recordDailyBudget({
    required double amount,
    DateTime? date,
  }) {
    // GUARD: recordDailyBudget must NEVER reduce savingsDebt.
    // Snapshot debt before any internal chain and restore it after.
    final double lockedDebt = state.savingsDebt;

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
      lastAddBase: null,
      lastAddAmount: null,
      lastAddDate: null,
      lastAddDebtAbsorbed: null,
      settings: state.settings.copyWith(
        dailyLimit: amount > 0 ? amount : null,
        hasConfiguredBudget: amount > 0 ||
            state.settings.weeklyLimit != null ||
            state.settings.monthlyLimit != null,
        budgetCreatedAt: now,
      ),
    );
    _recalculatePeriodSpending(now);
    _backfillMissingDays(currentDate: now);
    _persist();

    // Restore debt if anything in the chain accidentally changed it.
    if (state.savingsDebt != lockedDebt) {
      state = state.copyWith(savingsDebt: lockedDebt);
      _repository.saveState(state);
    }
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

    state = state.copyWith(
      budgetEntries: updatedEntries,
      dailySpent: 0,
      dailyPeriodStart: targetDate,
      lastAddBase: null,
      lastAddAmount: null,
      lastAddDate: null,
      lastAddDebtAbsorbed: null,
      settings: state.settings.copyWith(
        dailyLimit: null,
        hasConfiguredBudget: state.settings.weeklyLimit != null ||
            state.settings.monthlyLimit != null,
        budgetCreatedAt: now,
      ),
    );
    _recalculatePeriodSpending(now);
    _backfillMissingDays(currentDate: now);
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
    _lastSettledDate = null;
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
