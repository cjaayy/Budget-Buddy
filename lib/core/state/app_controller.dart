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
    return _service.recommendActivities(
      mood: mood,
      budget: summary.remainingBalance.clamp(0, summary.totalBudget).toDouble(),
      preferredDistanceKm: preferredDistanceKm,
    );
  }

  Future<void> _bootstrap() async {
    final BudgetBuddyState loaded = await _repository.loadState();
    state = loaded.copyWith(isBootstrapping: false);
    await _syncDailyRecord();
    await _repository.saveState(state);
  }

  Future<void> _persist() async {
    await _syncDailyRecord();
    await _repository.saveState(state);
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
    state = state.copyWith(settings: settings);
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
    state = state.copyWith(expenses: <ExpenseEntry>[entry, ...state.expenses]);
    _persist();
    _triggerWarningIfNeeded();
  }

  void updateExpense(ExpenseEntry expense) {
    final List<ExpenseEntry> updated = state.expenses.map((ExpenseEntry entry) {
      return entry.id == expense.id ? expense : entry;
    }).toList();
    state = state.copyWith(expenses: updated);
    _persist();
  }

  void deleteExpense(String id) {
    state = state.copyWith(
        expenses: state.expenses
            .where((ExpenseEntry entry) => entry.id != id)
            .toList());
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

  void resetForNextDay() {
    state = state.copyWith(expenses: <ExpenseEntry>[]);
    _persist();
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
    if (currentSummary.remainingBalance <= 0) {
      _notificationService.showBudgetReminder(
        title: 'Budget warning',
        body: 'You have reached your daily budget cap.',
      );
    }
  }
}
