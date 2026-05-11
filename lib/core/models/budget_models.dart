import 'dart:convert';

import 'package:flutter/material.dart';

enum BudgetCategory {
  food,
  transportation,
  entertainment,
  shopping,
  miscellaneous
}

enum MealType { breakfast, lunch, dinner, snack }

enum MealCategory {
  budgetMeals,
  healthyMeals,
  highProteinMeals,
  fastFood,
  streetFood
}

enum GalaMood { chill, foodTrip, date, gaming, cafeHopping, mallStroll }

extension BudgetCategoryX on BudgetCategory {
  String get label => switch (this) {
        BudgetCategory.food => 'Food',
        BudgetCategory.transportation => 'Transportation',
        BudgetCategory.entertainment => 'Entertainment',
        BudgetCategory.shopping => 'Shopping',
        BudgetCategory.miscellaneous => 'Miscellaneous',
      };

  String get hint => switch (this) {
        BudgetCategory.food => 'Meals, drinks, snacks',
        BudgetCategory.transportation => 'Jeep, bus, grab, train',
        BudgetCategory.entertainment => 'Arcade, movies, games',
        BudgetCategory.shopping => 'Errands, essentials',
        BudgetCategory.miscellaneous => 'Unexpected costs',
      };

  Color get color => switch (this) {
        BudgetCategory.food => const Color(0xFF0F766E),
        BudgetCategory.transportation => const Color(0xFF2563EB),
        BudgetCategory.entertainment => const Color(0xFFF97316),
        BudgetCategory.shopping => const Color(0xFF7C3AED),
        BudgetCategory.miscellaneous => const Color(0xFF64748B),
      };

  static BudgetCategory fromString(String value) {
    return BudgetCategory.values.firstWhere(
      (category) => category.name == value,
      orElse: () => BudgetCategory.miscellaneous,
    );
  }
}

extension MealTypeX on MealType {
  String get label => switch (this) {
        MealType.breakfast => 'Breakfast',
        MealType.lunch => 'Lunch',
        MealType.dinner => 'Dinner',
        MealType.snack => 'Snack',
      };

  static MealType fromString(String value) {
    return MealType.values.firstWhere(
      (type) => type.name == value,
      orElse: () => MealType.snack,
    );
  }
}

extension MealCategoryX on MealCategory {
  String get label => switch (this) {
        MealCategory.budgetMeals => 'Budget meals',
        MealCategory.healthyMeals => 'Healthy meals',
        MealCategory.highProteinMeals => 'High-protein meals',
        MealCategory.fastFood => 'Fast food',
        MealCategory.streetFood => 'Street food',
      };

  static MealCategory fromString(String value) {
    return MealCategory.values.firstWhere(
      (category) => category.name == value,
      orElse: () => MealCategory.budgetMeals,
    );
  }
}

extension GalaMoodX on GalaMood {
  String get label => switch (this) {
        GalaMood.chill => 'Chill',
        GalaMood.foodTrip => 'Food trip',
        GalaMood.date => 'Date',
        GalaMood.gaming => 'Gaming',
        GalaMood.cafeHopping => 'Café hopping',
        GalaMood.mallStroll => 'Mall stroll',
      };

  IconData get icon => switch (this) {
        GalaMood.chill => Icons.self_improvement_rounded,
        GalaMood.foodTrip => Icons.restaurant_rounded,
        GalaMood.date => Icons.favorite_rounded,
        GalaMood.gaming => Icons.sports_esports_rounded,
        GalaMood.cafeHopping => Icons.local_cafe_rounded,
        GalaMood.mallStroll => Icons.storefront_rounded,
      };

  static GalaMood fromString(String value) {
    return GalaMood.values.firstWhere(
      (mood) => mood.name == value,
      orElse: () => GalaMood.chill,
    );
  }
}

enum BudgetExpiryPeriod { daily, weekly, monthly }

enum DashboardPeriod { daily, weekly, monthly }

enum BudgetPeriod { daily, weekly, monthly }

extension BudgetPeriodX on BudgetPeriod {
  String get label => switch (this) {
        BudgetPeriod.daily => 'Daily',
        BudgetPeriod.weekly => 'Weekly',
        BudgetPeriod.monthly => 'Monthly',
      };

  String get resetLabel => switch (this) {
        BudgetPeriod.daily => 'Resets every midnight',
        BudgetPeriod.weekly => 'Resets every Monday',
        BudgetPeriod.monthly => 'Resets on the 1st of the month',
      };
}

enum NotificationFrequency { daily, weekly }

extension NotificationFrequencyX on NotificationFrequency {
  String get label => switch (this) {
        NotificationFrequency.daily => 'Daily',
        NotificationFrequency.weekly => 'Weekly',
      };

  static NotificationFrequency fromString(String value) {
    return NotificationFrequency.values.firstWhere(
      (NotificationFrequency frequency) => frequency.name == value,
      orElse: () => NotificationFrequency.daily,
    );
  }
}

extension DashboardPeriodX on DashboardPeriod {
  String get label => switch (this) {
        DashboardPeriod.daily => 'Daily',
        DashboardPeriod.weekly => 'Weekly',
        DashboardPeriod.monthly => 'Monthly',
      };

  double get multiplier => switch (this) {
        DashboardPeriod.daily => 1.0,
        DashboardPeriod.weekly => 7.0,
        DashboardPeriod.monthly => 30.0,
      };

  static DashboardPeriod fromString(String value) {
    return DashboardPeriod.values.firstWhere(
      (DashboardPeriod period) => period.name == value,
      orElse: () => DashboardPeriod.daily,
    );
  }
}

class BudgetSettings {
  const BudgetSettings({
    required this.totalDailyBudget,
    required this.foodBudget,
    required this.transportationBudget,
    required this.leisureBudget,
    required this.savingsGoal,
    this.weeklyBudget,
    this.monthlyBudget,
    this.savingsTargetAmount = 0,
    this.savingsTargetDate,
    this.notificationsEnabled = true,
    this.budgetWarningNotificationsEnabled = true,
    this.summaryNotificationsEnabled = true,
    this.streakNotificationsEnabled = true,
    this.notificationReminderMinuteOfDay = 21 * 60,
    this.notificationFrequency = NotificationFrequency.daily,
    this.dayStartMinuteOfDay = 0,
    this.hasConfiguredBudget = false,
    this.autoRenewBudget = false,
    this.budgetExpiryPeriod = BudgetExpiryPeriod.daily,
    this.budgetCreatedAt,
  });

  final double totalDailyBudget;
  final double foodBudget;
  final double transportationBudget;
  final double leisureBudget;
  final double savingsGoal;
  final double? weeklyBudget;
  final double? monthlyBudget;
  final double savingsTargetAmount;
  final DateTime? savingsTargetDate;
  final bool notificationsEnabled;
  final bool budgetWarningNotificationsEnabled;
  final bool summaryNotificationsEnabled;
  final bool streakNotificationsEnabled;
  final int notificationReminderMinuteOfDay;
  final NotificationFrequency notificationFrequency;
  final int dayStartMinuteOfDay;
  final bool hasConfiguredBudget;
  final bool autoRenewBudget;
  final BudgetExpiryPeriod budgetExpiryPeriod;
  final DateTime? budgetCreatedAt;

  factory BudgetSettings.defaults() {
    return const BudgetSettings(
      totalDailyBudget: 0,
      foodBudget: 0,
      transportationBudget: 0,
      leisureBudget: 0,
      savingsGoal: 0,
      weeklyBudget: null,
      monthlyBudget: null,
      savingsTargetAmount: 0,
      notificationsEnabled: true,
      budgetWarningNotificationsEnabled: true,
      summaryNotificationsEnabled: true,
      streakNotificationsEnabled: true,
      notificationReminderMinuteOfDay: 21 * 60,
      notificationFrequency: NotificationFrequency.daily,
      dayStartMinuteOfDay: 0,
    );
  }

  double get allocatedTotal =>
      foodBudget + transportationBudget + leisureBudget + savingsGoal;

  bool get hasActiveLimit =>
      totalDailyBudget > 0 ||
      (weeklyBudget ?? 0) > 0 ||
      (monthlyBudget ?? 0) > 0;

  int get activeLimitCount {
    int count = 0;
    if (totalDailyBudget > 0) count++;
    if ((weeklyBudget ?? 0) > 0) count++;
    if ((monthlyBudget ?? 0) > 0) count++;
    return count;
  }

  BudgetSettings copyWith({
    double? totalDailyBudget,
    double? foodBudget,
    double? transportationBudget,
    double? leisureBudget,
    double? savingsGoal,
    double? weeklyBudget,
    double? monthlyBudget,
    double? savingsTargetAmount,
    DateTime? savingsTargetDate,
    bool? notificationsEnabled,
    bool? budgetWarningNotificationsEnabled,
    bool? summaryNotificationsEnabled,
    bool? streakNotificationsEnabled,
    int? notificationReminderMinuteOfDay,
    NotificationFrequency? notificationFrequency,
    int? dayStartMinuteOfDay,
    bool? hasConfiguredBudget,
    bool? autoRenewBudget,
    BudgetExpiryPeriod? budgetExpiryPeriod,
    DateTime? budgetCreatedAt,
  }) {
    return BudgetSettings(
      totalDailyBudget: totalDailyBudget ?? this.totalDailyBudget,
      foodBudget: foodBudget ?? this.foodBudget,
      transportationBudget: transportationBudget ?? this.transportationBudget,
      leisureBudget: leisureBudget ?? this.leisureBudget,
      savingsGoal: savingsGoal ?? this.savingsGoal,
      weeklyBudget: weeklyBudget ?? this.weeklyBudget,
      monthlyBudget: monthlyBudget ?? this.monthlyBudget,
      savingsTargetAmount: savingsTargetAmount ?? this.savingsTargetAmount,
      savingsTargetDate: savingsTargetDate ?? this.savingsTargetDate,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      budgetWarningNotificationsEnabled: budgetWarningNotificationsEnabled ??
          this.budgetWarningNotificationsEnabled,
      summaryNotificationsEnabled:
          summaryNotificationsEnabled ?? this.summaryNotificationsEnabled,
      streakNotificationsEnabled:
          streakNotificationsEnabled ?? this.streakNotificationsEnabled,
      notificationReminderMinuteOfDay: notificationReminderMinuteOfDay ??
          this.notificationReminderMinuteOfDay,
      notificationFrequency:
          notificationFrequency ?? this.notificationFrequency,
      dayStartMinuteOfDay: dayStartMinuteOfDay ?? this.dayStartMinuteOfDay,
      hasConfiguredBudget: hasConfiguredBudget ?? this.hasConfiguredBudget,
      autoRenewBudget: autoRenewBudget ?? this.autoRenewBudget,
      budgetExpiryPeriod: budgetExpiryPeriod ?? this.budgetExpiryPeriod,
      budgetCreatedAt: budgetCreatedAt ?? this.budgetCreatedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'totalDailyBudget': totalDailyBudget,
      'foodBudget': foodBudget,
      'transportationBudget': transportationBudget,
      'leisureBudget': leisureBudget,
      'savingsGoal': savingsGoal,
      'weeklyBudget': weeklyBudget,
      'monthlyBudget': monthlyBudget,
      'savingsTargetAmount': savingsTargetAmount,
      'savingsTargetDate': savingsTargetDate?.toIso8601String(),
      'notificationsEnabled': notificationsEnabled,
      'budgetWarningNotificationsEnabled': budgetWarningNotificationsEnabled,
      'summaryNotificationsEnabled': summaryNotificationsEnabled,
      'streakNotificationsEnabled': streakNotificationsEnabled,
      'notificationReminderMinuteOfDay': notificationReminderMinuteOfDay,
      'notificationFrequency': notificationFrequency.name,
      'dayStartMinuteOfDay': dayStartMinuteOfDay,
      'hasConfiguredBudget': hasConfiguredBudget,
      'autoRenewBudget': autoRenewBudget,
      'budgetExpiryPeriod': budgetExpiryPeriod.name,
      'budgetCreatedAt': budgetCreatedAt?.toIso8601String(),
    };
  }

  factory BudgetSettings.fromJson(Map<String, dynamic> json) {
    return BudgetSettings(
      totalDailyBudget: (json['totalDailyBudget'] as num?)?.toDouble() ?? 0,
      foodBudget: (json['foodBudget'] as num?)?.toDouble() ?? 0,
      transportationBudget:
          (json['transportationBudget'] as num?)?.toDouble() ?? 0,
      leisureBudget: (json['leisureBudget'] as num?)?.toDouble() ?? 0,
      savingsGoal: (json['savingsGoal'] as num?)?.toDouble() ?? 0,
      weeklyBudget: (json['weeklyBudget'] as num?)?.toDouble(),
      monthlyBudget: (json['monthlyBudget'] as num?)?.toDouble(),
      savingsTargetAmount:
          (json['savingsTargetAmount'] as num?)?.toDouble() ?? 0,
      savingsTargetDate: json['savingsTargetDate'] != null
          ? DateTime.tryParse(json['savingsTargetDate'] as String)
          : null,
      notificationsEnabled: json['notificationsEnabled'] as bool? ?? true,
      budgetWarningNotificationsEnabled:
          json['budgetWarningNotificationsEnabled'] as bool? ?? true,
      summaryNotificationsEnabled:
          json['summaryNotificationsEnabled'] as bool? ?? true,
      streakNotificationsEnabled:
          json['streakNotificationsEnabled'] as bool? ?? true,
      notificationReminderMinuteOfDay:
          (json['notificationReminderMinuteOfDay'] as num?)?.toInt() ?? 21 * 60,
      notificationFrequency: NotificationFrequencyX.fromString(
        json['notificationFrequency'] as String? ??
            NotificationFrequency.daily.name,
      ),
      dayStartMinuteOfDay: (json['dayStartMinuteOfDay'] as num?)?.toInt() ?? 0,
      hasConfiguredBudget: json['hasConfiguredBudget'] as bool? ?? false,
      autoRenewBudget: json['autoRenewBudget'] as bool? ?? false,
      budgetExpiryPeriod: BudgetExpiryPeriod.values.firstWhere(
        (p) => p.name == (json['budgetExpiryPeriod'] as String?),
        orElse: () => BudgetExpiryPeriod.daily,
      ),
      budgetCreatedAt: json['budgetCreatedAt'] != null
          ? DateTime.tryParse(json['budgetCreatedAt'] as String)
          : null,
    );
  }
}

class ExpenseEntry {
  const ExpenseEntry({
    required this.id,
    required this.title,
    required this.amount,
    required this.category,
    required this.dateTime,
    this.note = '',
    this.source = 'manual',
  });

  final String id;
  final String title;
  final double amount;
  final BudgetCategory category;
  final DateTime dateTime;
  final String note;
  final String source;

  ExpenseEntry copyWith({
    String? id,
    String? title,
    double? amount,
    BudgetCategory? category,
    DateTime? dateTime,
    String? note,
    String? source,
  }) {
    return ExpenseEntry(
      id: id ?? this.id,
      title: title ?? this.title,
      amount: amount ?? this.amount,
      category: category ?? this.category,
      dateTime: dateTime ?? this.dateTime,
      note: note ?? this.note,
      source: source ?? this.source,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'title': title,
      'amount': amount,
      'category': category.name,
      'dateTime': dateTime.toIso8601String(),
      'note': note,
      'source': source,
    };
  }

  factory ExpenseEntry.fromJson(Map<String, dynamic> json) {
    return ExpenseEntry(
      id: json['id'] as String? ??
          DateTime.now().microsecondsSinceEpoch.toString(),
      title: json['title'] as String? ?? 'Expense',
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
      category: BudgetCategoryX.fromString(
          json['category'] as String? ?? BudgetCategory.miscellaneous.name),
      dateTime: DateTime.tryParse(json['dateTime'] as String? ?? '') ??
          DateTime.now(),
      note: json['note'] as String? ?? '',
      source: json['source'] as String? ?? 'manual',
    );
  }

  static List<ExpenseEntry> sampleList() {
    final now = DateTime.now();
    return <ExpenseEntry>[
      ExpenseEntry(
        id: 'sample-1',
        title: 'Lugaw + egg',
        amount: 45,
        category: BudgetCategory.food,
        dateTime: now.subtract(const Duration(hours: 6)),
        note: 'Budget breakfast',
        source: 'meal',
      ),
      ExpenseEntry(
        id: 'sample-2',
        title: 'Jeepney fare',
        amount: 20,
        category: BudgetCategory.transportation,
        dateTime: now.subtract(const Duration(hours: 5, minutes: 10)),
        note: 'Morning commute',
      ),
      ExpenseEntry(
        id: 'sample-3',
        title: 'Chicken adobo meal',
        amount: 85,
        category: BudgetCategory.food,
        dateTime: now.subtract(const Duration(hours: 3, minutes: 20)),
        note: 'Affordable lunch',
        source: 'meal',
      ),
      ExpenseEntry(
        id: 'sample-4',
        title: 'Milk tea',
        amount: 120,
        category: BudgetCategory.entertainment,
        dateTime: now.subtract(const Duration(hours: 2)),
        note: 'Treat with friends',
      ),
      ExpenseEntry(
        id: 'sample-5',
        title: 'Turon snack',
        amount: 25,
        category: BudgetCategory.miscellaneous,
        dateTime: now.subtract(const Duration(minutes: 45)),
        note: 'Street snack',
      ),
    ];
  }
}

class MealSuggestion {
  const MealSuggestion({
    required this.id,
    required this.name,
    required this.estimatedPrice,
    required this.mealType,
    required this.category,
    this.calories,
    this.note = '',
    this.isFavorite = false,
  });

  final String id;
  final String name;
  final double estimatedPrice;
  final MealType mealType;
  final MealCategory category;
  final int? calories;
  final String note;
  final bool isFavorite;

  MealSuggestion copyWith({
    String? id,
    String? name,
    double? estimatedPrice,
    MealType? mealType,
    MealCategory? category,
    int? calories,
    String? note,
    bool? isFavorite,
  }) {
    return MealSuggestion(
      id: id ?? this.id,
      name: name ?? this.name,
      estimatedPrice: estimatedPrice ?? this.estimatedPrice,
      mealType: mealType ?? this.mealType,
      category: category ?? this.category,
      calories: calories ?? this.calories,
      note: note ?? this.note,
      isFavorite: isFavorite ?? this.isFavorite,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'name': name,
      'estimatedPrice': estimatedPrice,
      'mealType': mealType.name,
      'category': category.name,
      'calories': calories,
      'note': note,
      'isFavorite': isFavorite,
    };
  }

  factory MealSuggestion.fromJson(Map<String, dynamic> json) {
    return MealSuggestion(
      id: json['id'] as String? ??
          DateTime.now().microsecondsSinceEpoch.toString(),
      name: json['name'] as String? ?? 'Meal',
      estimatedPrice: (json['estimatedPrice'] as num?)?.toDouble() ?? 0,
      mealType: MealTypeX.fromString(
          json['mealType'] as String? ?? MealType.snack.name),
      category: MealCategoryX.fromString(
          json['category'] as String? ?? MealCategory.budgetMeals.name),
      calories: (json['calories'] as num?)?.toInt(),
      note: json['note'] as String? ?? '',
      isFavorite: json['isFavorite'] as bool? ?? false,
    );
  }

  static List<MealSuggestion> sampleCatalog() {
    return <MealSuggestion>[
      const MealSuggestion(
        id: 'meal-1',
        name: 'Lugaw + egg',
        estimatedPrice: 45,
        mealType: MealType.breakfast,
        category: MealCategory.budgetMeals,
        calories: 320,
        note: 'Warm and filling',
      ),
      const MealSuggestion(
        id: 'meal-2',
        name: 'Chicken adobo + rice',
        estimatedPrice: 85,
        mealType: MealType.lunch,
        category: MealCategory.healthyMeals,
        calories: 540,
        note: 'Affordable lunch',
      ),
      const MealSuggestion(
        id: 'meal-3',
        name: 'Tapsilog',
        estimatedPrice: 95,
        mealType: MealType.breakfast,
        category: MealCategory.highProteinMeals,
        calories: 610,
        note: 'Protein boost',
      ),
      const MealSuggestion(
        id: 'meal-4',
        name: 'Burger + iced tea',
        estimatedPrice: 140,
        mealType: MealType.dinner,
        category: MealCategory.fastFood,
        calories: 760,
        note: 'Fast comfort option',
      ),
      const MealSuggestion(
        id: 'meal-5',
        name: 'Fishball + tubig',
        estimatedPrice: 40,
        mealType: MealType.snack,
        category: MealCategory.streetFood,
        calories: 220,
        note: 'Street-food saver',
      ),
      const MealSuggestion(
        id: 'meal-6',
        name: 'Sinigang na gulay',
        estimatedPrice: 110,
        mealType: MealType.dinner,
        category: MealCategory.healthyMeals,
        calories: 430,
        note: 'Light and balanced',
      ),
    ];
  }
}

class ActivitySuggestion {
  const ActivitySuggestion({
    required this.id,
    required this.title,
    required this.estimatedCost,
    required this.mood,
    required this.distanceKm,
    this.details = const <String>[],
  });

  final String id;
  final String title;
  final double estimatedCost;
  final GalaMood mood;
  final double distanceKm;
  final List<String> details;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'title': title,
      'estimatedCost': estimatedCost,
      'mood': mood.name,
      'distanceKm': distanceKm,
      'details': details,
    };
  }

  factory ActivitySuggestion.fromJson(Map<String, dynamic> json) {
    return ActivitySuggestion(
      id: json['id'] as String? ??
          DateTime.now().microsecondsSinceEpoch.toString(),
      title: json['title'] as String? ?? 'Activity',
      estimatedCost: (json['estimatedCost'] as num?)?.toDouble() ?? 0,
      mood:
          GalaMoodX.fromString(json['mood'] as String? ?? GalaMood.chill.name),
      distanceKm: (json['distanceKm'] as num?)?.toDouble() ?? 0,
      details: (json['details'] as List<dynamic>?)
              ?.map((dynamic e) => e.toString())
              .toList() ??
          <String>[],
    );
  }

  static List<ActivitySuggestion> sampleCatalog() {
    return <ActivitySuggestion>[
      const ActivitySuggestion(
        id: 'activity-1',
        title: 'Coffee + lakeside walk',
        estimatedCost: 180,
        mood: GalaMood.chill,
        distanceKm: 2.5,
        details: <String>['Coffee ₱120', 'Snack ₱60'],
      ),
      const ActivitySuggestion(
        id: 'activity-2',
        title: 'Budget food trip',
        estimatedCost: 320,
        mood: GalaMood.foodTrip,
        distanceKm: 4,
        details: <String>['Street food ₱120', 'Drink ₱50', 'Fare ₱150'],
      ),
      const ActivitySuggestion(
        id: 'activity-3',
        title: 'Arcade + dinner',
        estimatedCost: 450,
        mood: GalaMood.gaming,
        distanceKm: 5,
        details: <String>['Arcade ₱150', 'Dinner ₱220', 'Fare ₱80'],
      ),
      const ActivitySuggestion(
        id: 'activity-4',
        title: 'Café hopping + study',
        estimatedCost: 260,
        mood: GalaMood.cafeHopping,
        distanceKm: 3,
        details: <String>['Drinks ₱180', 'Fare ₱80'],
      ),
      const ActivitySuggestion(
        id: 'activity-5',
        title: 'Mall stroll budget plan',
        estimatedCost: 500,
        mood: GalaMood.mallStroll,
        distanceKm: 6,
        details: <String>['Snack ₱80', 'Movie promo ₱250', 'Fare ₱120'],
      ),
    ];
  }
}

class DailyRecord {
  const DailyRecord({
    required this.date,
    required this.totalSpent,
    required this.remainingBalance,
    required this.savings,
    required this.biggestExpenseCategory,
    required this.categoryTotals,
  });

  final DateTime date;
  final double totalSpent;
  final double remainingBalance;
  final double savings;
  final String biggestExpenseCategory;
  final Map<String, double> categoryTotals;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'date': date.toIso8601String(),
      'totalSpent': totalSpent,
      'remainingBalance': remainingBalance,
      'savings': savings,
      'biggestExpenseCategory': biggestExpenseCategory,
      'categoryTotals': categoryTotals,
    };
  }

  factory DailyRecord.fromJson(Map<String, dynamic> json) {
    final totals = <String, double>{};
    final rawTotals =
        json['categoryTotals'] as Map<String, dynamic>? ?? <String, dynamic>{};
    for (final MapEntry<String, dynamic> entry in rawTotals.entries) {
      totals[entry.key] = (entry.value as num?)?.toDouble() ?? 0;
    }
    return DailyRecord(
      date: DateTime.tryParse(json['date'] as String? ?? '') ?? DateTime.now(),
      totalSpent: (json['totalSpent'] as num?)?.toDouble() ?? 0,
      remainingBalance: (json['remainingBalance'] as num?)?.toDouble() ?? 0,
      savings: (json['savings'] as num?)?.toDouble() ?? 0,
      biggestExpenseCategory: json['biggestExpenseCategory'] as String? ??
          BudgetCategory.miscellaneous.label,
      categoryTotals: totals,
    );
  }

  static List<DailyRecord> sampleList() {
    final now = DateTime.now();
    return <DailyRecord>[
      DailyRecord(
        date: now.subtract(const Duration(days: 6)),
        totalSpent: 390,
        remainingBalance: 110,
        savings: 110,
        biggestExpenseCategory: BudgetCategory.food.label,
        categoryTotals: <String, double>{
          BudgetCategory.food.label: 180,
          BudgetCategory.transportation.label: 60,
          BudgetCategory.entertainment.label: 90,
          BudgetCategory.shopping.label: 40,
          BudgetCategory.miscellaneous.label: 20,
        },
      ),
      DailyRecord(
        date: now.subtract(const Duration(days: 5)),
        totalSpent: 420,
        remainingBalance: 80,
        savings: 80,
        biggestExpenseCategory: BudgetCategory.food.label,
        categoryTotals: <String, double>{
          BudgetCategory.food.label: 210,
          BudgetCategory.transportation.label: 50,
          BudgetCategory.entertainment.label: 100,
          BudgetCategory.shopping.label: 40,
          BudgetCategory.miscellaneous.label: 20,
        },
      ),
      DailyRecord(
        date: now.subtract(const Duration(days: 4)),
        totalSpent: 360,
        remainingBalance: 140,
        savings: 140,
        biggestExpenseCategory: BudgetCategory.entertainment.label,
        categoryTotals: <String, double>{
          BudgetCategory.food.label: 160,
          BudgetCategory.transportation.label: 40,
          BudgetCategory.entertainment.label: 120,
          BudgetCategory.shopping.label: 30,
          BudgetCategory.miscellaneous.label: 10,
        },
      ),
      DailyRecord(
        date: now.subtract(const Duration(days: 3)),
        totalSpent: 470,
        remainingBalance: 30,
        savings: 30,
        biggestExpenseCategory: BudgetCategory.food.label,
        categoryTotals: <String, double>{
          BudgetCategory.food.label: 260,
          BudgetCategory.transportation.label: 50,
          BudgetCategory.entertainment.label: 110,
          BudgetCategory.shopping.label: 30,
          BudgetCategory.miscellaneous.label: 20,
        },
      ),
      DailyRecord(
        date: now.subtract(const Duration(days: 2)),
        totalSpent: 315,
        remainingBalance: 185,
        savings: 185,
        biggestExpenseCategory: BudgetCategory.food.label,
        categoryTotals: <String, double>{
          BudgetCategory.food.label: 150,
          BudgetCategory.transportation.label: 45,
          BudgetCategory.entertainment.label: 80,
          BudgetCategory.shopping.label: 20,
          BudgetCategory.miscellaneous.label: 20,
        },
      ),
      DailyRecord(
        date: now.subtract(const Duration(days: 1)),
        totalSpent: 440,
        remainingBalance: 60,
        savings: 60,
        biggestExpenseCategory: BudgetCategory.shopping.label,
        categoryTotals: <String, double>{
          BudgetCategory.food.label: 170,
          BudgetCategory.transportation.label: 40,
          BudgetCategory.entertainment.label: 90,
          BudgetCategory.shopping.label: 120,
          BudgetCategory.miscellaneous.label: 20,
        },
      ),
    ];
  }
}

class UserProfile {
  const UserProfile({
    required this.displayName,
    required this.city,
    required this.savingsStreak,
    required this.avatarSeed,
  });

  final String displayName;
  final String city;
  final int savingsStreak;
  final String avatarSeed;

  factory UserProfile.defaults() {
    return const UserProfile(
      displayName: 'Budget Buddy',
      city: 'Makati',
      savingsStreak: 7,
      avatarSeed: 'BB',
    );
  }

  UserProfile copyWith({
    String? displayName,
    String? city,
    int? savingsStreak,
    String? avatarSeed,
  }) {
    return UserProfile(
      displayName: displayName ?? this.displayName,
      city: city ?? this.city,
      savingsStreak: savingsStreak ?? this.savingsStreak,
      avatarSeed: avatarSeed ?? this.avatarSeed,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'displayName': displayName,
      'city': city,
      'savingsStreak': savingsStreak,
      'avatarSeed': avatarSeed,
    };
  }

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      displayName: json['displayName'] as String? ?? 'Budget Buddy',
      city: json['city'] as String? ?? 'Makati',
      savingsStreak: (json['savingsStreak'] as num?)?.toInt() ?? 0,
      avatarSeed: json['avatarSeed'] as String? ?? 'BB',
    );
  }
}

class BudgetBuddyState {
  const BudgetBuddyState({
    required this.settings,
    required this.expenses,
    required this.lastExpenseCategory,
    required this.customMeals,
    required this.favoriteMealIds,
    required this.savedActivityPlans,
    required this.dailyRecords,
    required this.profile,
    required this.loggedIn,
    required this.onboardingComplete,
    required this.themeMode,
    required this.notificationsEnabled,
    required this.isBootstrapping,
    required this.currentExpenseFilter,
    required this.dashboardPeriod,
  });

  final BudgetSettings settings;
  final List<ExpenseEntry> expenses;
  final BudgetCategory? lastExpenseCategory;
  final List<MealSuggestion> customMeals;
  final List<String> favoriteMealIds;
  final List<ActivitySuggestion> savedActivityPlans;
  final List<DailyRecord> dailyRecords;
  final UserProfile profile;
  final bool loggedIn;
  final bool onboardingComplete;
  final ThemeMode themeMode;
  final bool notificationsEnabled;
  final bool isBootstrapping;
  final BudgetCategory? currentExpenseFilter;
  final DashboardPeriod dashboardPeriod;

  factory BudgetBuddyState.initial() {
    return BudgetBuddyState(
      settings: BudgetSettings.defaults(),
      expenses: <ExpenseEntry>[],
      lastExpenseCategory: null,
      customMeals: <MealSuggestion>[],
      favoriteMealIds: <String>[],
      savedActivityPlans: <ActivitySuggestion>[],
      dailyRecords: <DailyRecord>[],
      profile: UserProfile.defaults(),
      loggedIn: false,
      onboardingComplete: false,
      themeMode: ThemeMode.system,
      notificationsEnabled: true,
      isBootstrapping: true,
      currentExpenseFilter: null,
      dashboardPeriod: DashboardPeriod.daily,
    );
  }

  BudgetBuddyState copyWith({
    BudgetSettings? settings,
    List<ExpenseEntry>? expenses,
    Object? lastExpenseCategory = _lastExpenseCategorySentinel,
    List<MealSuggestion>? customMeals,
    List<String>? favoriteMealIds,
    List<ActivitySuggestion>? savedActivityPlans,
    List<DailyRecord>? dailyRecords,
    UserProfile? profile,
    bool? loggedIn,
    bool? onboardingComplete,
    ThemeMode? themeMode,
    bool? notificationsEnabled,
    bool? isBootstrapping,
    Object? currentExpenseFilter = _currentExpenseFilterSentinel,
    DashboardPeriod? dashboardPeriod,
  }) {
    return BudgetBuddyState(
      settings: settings ?? this.settings,
      expenses: expenses ?? this.expenses,
      lastExpenseCategory:
          identical(lastExpenseCategory, _lastExpenseCategorySentinel)
              ? this.lastExpenseCategory
              : lastExpenseCategory as BudgetCategory?,
      customMeals: customMeals ?? this.customMeals,
      favoriteMealIds: favoriteMealIds ?? this.favoriteMealIds,
      savedActivityPlans: savedActivityPlans ?? this.savedActivityPlans,
      dailyRecords: dailyRecords ?? this.dailyRecords,
      profile: profile ?? this.profile,
      loggedIn: loggedIn ?? this.loggedIn,
      onboardingComplete: onboardingComplete ?? this.onboardingComplete,
      themeMode: themeMode ?? this.themeMode,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      isBootstrapping: isBootstrapping ?? this.isBootstrapping,
      currentExpenseFilter:
          identical(currentExpenseFilter, _currentExpenseFilterSentinel)
              ? this.currentExpenseFilter
              : currentExpenseFilter as BudgetCategory?,
      dashboardPeriod: dashboardPeriod ?? this.dashboardPeriod,
    );
  }

  static const Object _lastExpenseCategorySentinel = Object();

  static const Object _currentExpenseFilterSentinel = Object();

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'settings': settings.toJson(),
      'expenses': expenses.map((ExpenseEntry entry) => entry.toJson()).toList(),
      'lastExpenseCategory': lastExpenseCategory?.name,
      'customMeals':
          customMeals.map((MealSuggestion meal) => meal.toJson()).toList(),
      'favoriteMealIds': favoriteMealIds,
      'savedActivityPlans': savedActivityPlans
          .map((ActivitySuggestion activity) => activity.toJson())
          .toList(),
      'dailyRecords':
          dailyRecords.map((DailyRecord record) => record.toJson()).toList(),
      'profile': profile.toJson(),
      'loggedIn': loggedIn,
      'onboardingComplete': onboardingComplete,
      'themeMode': themeMode.name,
      'notificationsEnabled': notificationsEnabled,
      'currentExpenseFilter': currentExpenseFilter?.name,
      'dashboardPeriod': dashboardPeriod.name,
    };
  }

  factory BudgetBuddyState.fromJson(Map<String, dynamic> json) {
    return BudgetBuddyState(
      settings: BudgetSettings.fromJson(
          (json['settings'] as Map?)?.cast<String, dynamic>() ??
              <String, dynamic>{}),
      expenses: (json['expenses'] as List<dynamic>?)
              ?.map((dynamic item) =>
                  ExpenseEntry.fromJson((item as Map).cast<String, dynamic>()))
              .toList() ??
          ExpenseEntry.sampleList(),
      lastExpenseCategory: json['lastExpenseCategory'] == null
          ? null
          : BudgetCategoryX.fromString(json['lastExpenseCategory'] as String),
      customMeals: (json['customMeals'] as List<dynamic>?)
              ?.map((dynamic item) => MealSuggestion.fromJson(
                  (item as Map).cast<String, dynamic>()))
              .toList() ??
          <MealSuggestion>[],
      favoriteMealIds: (json['favoriteMealIds'] as List<dynamic>?)
              ?.map((dynamic item) => item.toString())
              .toList() ??
          <String>[],
      savedActivityPlans: (json['savedActivityPlans'] as List<dynamic>?)
              ?.map((dynamic item) => ActivitySuggestion.fromJson(
                  (item as Map).cast<String, dynamic>()))
              .toList() ??
          ActivitySuggestion.sampleCatalog(),
      dailyRecords: (json['dailyRecords'] as List<dynamic>?)
              ?.map((dynamic item) =>
                  DailyRecord.fromJson((item as Map).cast<String, dynamic>()))
              .toList() ??
          DailyRecord.sampleList(),
      profile: UserProfile.fromJson(
          (json['profile'] as Map?)?.cast<String, dynamic>() ??
              <String, dynamic>{}),
      loggedIn: json['loggedIn'] as bool? ?? false,
      onboardingComplete: json['onboardingComplete'] as bool? ?? false,
      themeMode: ThemeMode.values.firstWhere(
        (ThemeMode mode) =>
            mode.name ==
            (json['themeMode'] as String? ?? ThemeMode.system.name),
        orElse: () => ThemeMode.system,
      ),
      notificationsEnabled: json['notificationsEnabled'] as bool? ?? true,
      isBootstrapping: false,
      currentExpenseFilter: json['currentExpenseFilter'] == null
          ? null
          : BudgetCategoryX.fromString(json['currentExpenseFilter'] as String),
      dashboardPeriod: DashboardPeriodX.fromString(
        json['dashboardPeriod'] as String? ?? DashboardPeriod.daily.name,
      ),
    );
  }

  String encode() => jsonEncode(toJson());

  factory BudgetBuddyState.decode(String raw) {
    return BudgetBuddyState.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }
}

class BudgetSummary {
  const BudgetSummary({
    required this.totalBudget,
    required this.totalSpent,
    required this.remainingBalance,
    required this.savings,
    required this.biggestExpenseCategory,
    required this.categoryTotals,
    required this.categoryPercentages,
    required this.overspendingCategories,
    required this.recommendedActions,
    required this.savingsProgress,
    required this.periodSummaries,
    required this.activeLimitCount,
  });

  final double totalBudget;
  final double totalSpent;
  final double remainingBalance;
  final double savings;
  final String biggestExpenseCategory;
  final Map<String, double> categoryTotals;
  final Map<String, double> categoryPercentages;
  final List<String> overspendingCategories;
  final List<String> recommendedActions;
  final double savingsProgress;
  final Map<BudgetPeriod, BudgetPeriodSummary> periodSummaries;
  final int activeLimitCount;
}

class BudgetPeriodSummary {
  const BudgetPeriodSummary({
    required this.period,
    required this.limit,
    required this.spent,
  });

  final BudgetPeriod period;
  final double limit;
  final double spent;

  double get remaining => limit - spent;

  double get saved => remaining > 0 ? remaining : 0;

  double get overspentAmount => remaining < 0 ? remaining.abs() : 0;

  double get warningThreshold => limit * 0.8;

  double get usageRatio =>
      limit <= 0 ? 0 : (spent / limit).clamp(0, 2).toDouble();

  bool get isActive => limit > 0;

  bool get isWarning => isActive && spent >= warningThreshold && spent < limit;

  bool get isOverspent => isActive && spent >= limit;

  String get statusLabel => switch (isOverspent) {
        true => 'Overspent',
        false => isWarning ? 'Warning' : 'On track',
      };

  String get resetLabel => period.resetLabel;

  String get warningMessage {
    if (!isActive) {
      return 'No limit set for ${period.label.toLowerCase()}.';
    }
    if (isOverspent) {
      return 'You are over your ${period.label.toLowerCase()} limit by ₱${overspentAmount.toStringAsFixed(0)}.';
    }
    return 'You\'re ₱${remaining.toStringAsFixed(0)} from your ${period.label.toLowerCase()} limit.';
  }
}
