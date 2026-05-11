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
  return ref.watch(budgetServiceProvider).computeSummary(state);
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
    _bootstrap();
  }

  final LocalBudgetRepository _repository;
  final BudgetService _service;
  final NotificationService _notificationService;
  final Uuid _uuid = const Uuid();

  BudgetSummary get summary => _service.computeSummary(state);

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

  Future<void> _bootstrap() async {
    final BudgetBuddyState loaded = await _repository.loadState();
    state = loaded.copyWith(isBootstrapping: false);
    _renewBudgetIfNeeded();
    _refreshPeriodTracking();
    await _syncDailyRecord();
    await _repository.saveState(state);
  }

  Future<void> _persist() async {
    _renewBudgetIfNeeded();
    _refreshPeriodTracking();
    await _syncDailyRecord();
    await _repository.saveState(state);
  }

  void _refreshPeriodTracking() {
    final DateTime now = DateTime.now();
    _archiveElapsedPeriods(now);
    _recalculatePeriodSpending(now);
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
    final double? limit = _periodLimit(period);
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
            !expense.dateTime.isBefore(start) &&
            !expense.dateTime.isAfter(endInclusive))
        .fold(0, (double sum, ExpenseEntry expense) => sum + expense.amount);
  }

  double _sumExpensesInRange(DateTime start, DateTime endExclusive) {
    return state.expenses
        .where((ExpenseEntry expense) =>
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

    if (!_isBudgetExpired(settings, DateTime.now())) {
      return;
    }

    state = state.copyWith(
      settings: settings.copyWith(budgetCreatedAt: DateTime.now()),
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

  Future<void> _syncDailyRecord() async {
    final BudgetSummary currentSummary = _service.computeSummary(state);
    final DateTime now = DateTime.now();
    final List<DailyRecord> updatedRecords = <DailyRecord>[
      ...state.dailyRecords
    ];
    final int existingIndex = updatedRecords
        .indexWhere((DailyRecord record) => _isSameDay(record.date, now));
    final DailyRecord record = DailyRecord(
      date: now,
      totalSpent: currentSummary.totalSpent,
      remainingBalance: currentSummary.remainingBalance,
      savings: currentSummary.savings,
      biggestExpenseCategory: currentSummary.biggestExpenseCategory,
      categoryTotals: currentSummary.categoryTotals,
    );

    if (existingIndex >= 0) {
      updatedRecords[existingIndex] = record;
    } else {
      updatedRecords.add(record);
    }

    while (updatedRecords.length > 30) {
      updatedRecords.removeAt(0);
    }

    state = state.copyWith(dailyRecords: updatedRecords);
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
    int? notificationReminderMinuteOfDay,
    NotificationFrequency? notificationFrequency,
    int? dayStartMinuteOfDay,
  }) {
    state = state.copyWith(
      settings: state.settings.copyWith(
        notificationsEnabled: notificationsEnabled,
        budgetWarningNotificationsEnabled: budgetWarningNotificationsEnabled,
        summaryNotificationsEnabled: summaryNotificationsEnabled,
        streakNotificationsEnabled: streakNotificationsEnabled,
        notificationReminderMinuteOfDay: notificationReminderMinuteOfDay,
        notificationFrequency: notificationFrequency,
        dayStartMinuteOfDay: dayStartMinuteOfDay,
      ),
      notificationsEnabled: notificationsEnabled ?? state.notificationsEnabled,
    );
    _persist();
  }

  void restoreSnapshot(BudgetBuddyState snapshot) {
    state = snapshot.copyWith(isBootstrapping: false);
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
  }) {
    final ExpenseEntry entry = ExpenseEntry(
      id: _uuid.v4(),
      title: title,
      amount: amount,
      category: category,
      dateTime: dateTime ?? DateTime.now(),
      note: note,
    );
    state = state.copyWith(
        expenses: <ExpenseEntry>[entry, ...state.expenses],
        lastExpenseCategory: category);
    _persist();
    _triggerWarningIfNeeded();
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

  void updateProfileImage(String imagePath) {
    final UserProfile updatedProfile =
        state.profile.copyWith(profileImagePath: imagePath);
    state = state.copyWith(profile: updatedProfile);
    _persist();
  }

  void resetForNextDay() {
    _persist();
  }

  Future<void> resetApp() async {
    // Reset to initial state with all data cleared and budgets at 0
    state = BudgetBuddyState.initial().copyWith(
      loggedIn: state.loggedIn,
      onboardingComplete: state.onboardingComplete,
      profile: state.profile,
      themeMode: state.themeMode,
      notificationsEnabled: state.notificationsEnabled,
    );
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
