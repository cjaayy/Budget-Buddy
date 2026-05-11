import '../models/budget_models.dart';

class BudgetService {
  BudgetSummary computeSummary(BudgetBuddyState state) {
    final DateTime now = DateTime.now();
    final BudgetPeriod primaryPeriod = _primaryPeriod(state.settings);
    final Map<BudgetPeriod, double> periodLimits =
        _periodLimits(state.settings);
    final Map<BudgetPeriod, double> periodSpent = <BudgetPeriod, double>{
      BudgetPeriod.daily: state.dailySpent,
      BudgetPeriod.weekly: state.weeklySpent,
      BudgetPeriod.monthly: state.monthlySpent,
    };
    final Map<BudgetPeriod, BudgetPeriodSummary> periodSummaries =
        <BudgetPeriod, BudgetPeriodSummary>{};

    for (final MapEntry<BudgetPeriod, double> entry in periodLimits.entries) {
      final double spent = periodSpent[entry.key] ?? 0;
      periodSummaries[entry.key] = BudgetPeriodSummary(
        period: entry.key,
        limit: entry.value,
        spent: spent,
      );
    }

    final BudgetPeriodSummary primarySummary = periodSummaries[primaryPeriod] ??
        const BudgetPeriodSummary(
          period: BudgetPeriod.daily,
          limit: 0,
          spent: 0,
        );

    final List<ExpenseEntry> primaryExpenses = _expensesSince(
      state.expenses,
      _periodStart(primaryPeriod, now),
    );

    if (!state.settings.hasActiveLimit) {
      return BudgetSummary(
        totalBudget: 0,
        totalSpent: 0,
        remainingBalance: 0,
        savings: 0,
        biggestExpenseCategory: BudgetCategory.miscellaneous.label,
        categoryTotals: <String, double>{
          for (final BudgetCategory category in BudgetCategory.values)
            category.label: 0,
        },
        categoryPercentages: <String, double>{
          for (final BudgetCategory category in BudgetCategory.values)
            category.label: 0,
        },
        overspendingCategories: <String>[],
        recommendedActions: <String>[
          'Set your budget to see live spending insights.'
        ],
        savingsProgress: 0,
        periodSummaries: periodSummaries,
        activeLimitCount: state.settings.activeLimitCount,
      );
    }

    final Map<String, double> categoryTotals = <String, double>{
      for (final BudgetCategory category in BudgetCategory.values)
        category.label: 0,
    };

    for (final ExpenseEntry expense in primaryExpenses) {
      categoryTotals[expense.category.label] =
          (categoryTotals[expense.category.label] ?? 0) + expense.amount;
    }

    final double totalSpent = categoryTotals.values
        .fold(0, (double sum, double value) => sum + value);
    final double remainingBalance = primarySummary.remaining;
    final double savings = primarySummary.saved;

    final Map<String, double> categoryPercentages = <String, double>{};
    final Map<String, double> limits =
        _categoryLimits(state.settings, primarySummary.limit);
    final List<String> overspendingCategories = <String>[];
    for (final MapEntry<String, double> entry in categoryTotals.entries) {
      final double limit = limits[entry.key] ?? primarySummary.limit;
      categoryPercentages[entry.key] =
          limit == 0 ? 0 : (entry.value / limit).clamp(0, 1.5).toDouble();
      if (entry.value > limit && entry.value > 0) {
        overspendingCategories.add(entry.key);
      }
    }

    final Map<String, double> nonZeroTotals = Map<String, double>.fromEntries(
      categoryTotals.entries
          .where((MapEntry<String, double> entry) => entry.value > 0),
    );
    final String biggestExpenseCategory = nonZeroTotals.isEmpty
        ? BudgetCategory.miscellaneous.label
        : nonZeroTotals.entries.reduce(
            (MapEntry<String, double> left, MapEntry<String, double> right) {
            return left.value >= right.value ? left : right;
          }).key;

    final List<String> recommendations = _buildRecommendations(
      settings: state.settings,
      totalSpent: totalSpent,
      remainingBalance: remainingBalance,
      overspendingCategories: overspendingCategories,
      categoryTotals: categoryTotals,
      categoryLimits: limits,
      primarySummary: primarySummary,
    );

    final double savingsProgress = state.settings.savingsGoal <= 0
        ? 1
        : (savings / state.settings.savingsGoal).clamp(0, 1.5).toDouble();

    return BudgetSummary(
      totalBudget: primarySummary.limit,
      totalSpent: totalSpent,
      remainingBalance: remainingBalance,
      savings: savings,
      biggestExpenseCategory: biggestExpenseCategory,
      categoryTotals: categoryTotals,
      categoryPercentages: categoryPercentages,
      overspendingCategories: overspendingCategories,
      recommendedActions: recommendations,
      savingsProgress: savingsProgress,
      periodSummaries: periodSummaries,
      activeLimitCount: state.settings.activeLimitCount,
    );
  }

  List<MealSuggestion> recommendMeals({
    required BudgetBuddyState state,
    required MealCategory category,
    MealType? mealType,
    double? remainingBudget,
  }) {
    final double budget =
        remainingBudget ?? computeSummary(state).remainingBalance;
    final List<MealSuggestion> catalog = <MealSuggestion>[
      ...MealSuggestion.sampleCatalog(),
      ...state.customMeals,
    ];

    final List<MealSuggestion> filtered = catalog.where((MealSuggestion meal) {
      final bool withinBudget = meal.estimatedPrice <= budget;
      final bool matchesCategory =
          meal.category == category || category == MealCategory.budgetMeals;
      final bool matchesMealType =
          mealType == null || meal.mealType == mealType;
      return withinBudget && matchesCategory && matchesMealType;
    }).toList();

    filtered.sort((MealSuggestion left, MealSuggestion right) {
      final bool leftFavorite = state.favoriteMealIds.contains(left.id);
      final bool rightFavorite = state.favoriteMealIds.contains(right.id);
      if (leftFavorite != rightFavorite) {
        return leftFavorite ? -1 : 1;
      }
      return left.estimatedPrice.compareTo(right.estimatedPrice);
    });

    if (filtered.isNotEmpty) {
      return filtered.take(6).map((MealSuggestion meal) {
        return meal.copyWith(
            isFavorite: state.favoriteMealIds.contains(meal.id));
      }).toList();
    }

    return catalog
        .where((MealSuggestion meal) => meal.estimatedPrice <= budget + 40)
        .take(3)
        .map((MealSuggestion meal) =>
            meal.copyWith(isFavorite: state.favoriteMealIds.contains(meal.id)))
        .toList();
  }

  List<ActivitySuggestion> recommendActivities({
    required GalaMood mood,
    required double budget,
    required double preferredDistanceKm,
  }) {
    final List<ActivitySuggestion> catalog = ActivitySuggestion.sampleCatalog();
    final List<ActivitySuggestion> filtered =
        catalog.where((ActivitySuggestion activity) {
      final bool moodMatch = activity.mood == mood || mood == GalaMood.chill;
      final bool budgetMatch = activity.estimatedCost <= budget;
      final bool distanceMatch = activity.distanceKm <= preferredDistanceKm ||
          preferredDistanceKm == 0;
      return moodMatch && budgetMatch && distanceMatch;
    }).toList();

    filtered.sort((ActivitySuggestion left, ActivitySuggestion right) {
      if (left.estimatedCost != right.estimatedCost) {
        return left.estimatedCost.compareTo(right.estimatedCost);
      }
      return left.distanceKm.compareTo(right.distanceKm);
    });

    if (filtered.isNotEmpty) {
      return filtered.take(4).toList();
    }

    return catalog
        .where((ActivitySuggestion activity) =>
            activity.estimatedCost <= budget + 100)
        .take(3)
        .toList();
  }

  Map<String, double> _categoryLimits(BudgetSettings settings, double budget) {
    return <String, double>{
      BudgetCategory.food.label: settings.foodBudget,
      BudgetCategory.transportation.label: settings.transportationBudget,
      BudgetCategory.entertainment.label: settings.leisureBudget,
      BudgetCategory.shopping.label: budget * 0.15,
      BudgetCategory.miscellaneous.label: budget * 0.10,
    };
  }

  List<String> _buildRecommendations({
    required BudgetSettings settings,
    required double totalSpent,
    required double remainingBalance,
    required List<String> overspendingCategories,
    required Map<String, double> categoryTotals,
    required Map<String, double> categoryLimits,
    required BudgetPeriodSummary primarySummary,
  }) {
    final List<String> tips = <String>[];

    if (primarySummary.isOverspent) {
      tips.add(
          'You are overspending by ${remainingBalance.abs().toStringAsFixed(0)} pesos in your ${primarySummary.period.label.toLowerCase()} budget.');
    } else if (primarySummary.isWarning) {
      tips.add(primarySummary.warningMessage);
    } else if (remainingBalance < settings.savingsGoal * 0.4) {
      tips.add(
          'Your savings buffer is getting thin. Try a cheaper meal or skip one extra ride.');
    }

    if (overspendingCategories.contains(BudgetCategory.food.label)) {
      tips.add(
          'Food is above budget. A street-food meal can save around ₱40 to ₱70 per meal.');
    }
    if (overspendingCategories.contains(BudgetCategory.entertainment.label)) {
      tips.add(
          'Leisure is high today. Consider a coffee walk or window shopping instead of a full outing.');
    }
    if (totalSpent > settings.totalDailyBudget * 0.85) {
      tips.add(
          'You are close to your daily budget cap. Keep the next purchase under ₱50 if possible.');
    }

    final double foodLimit =
        categoryLimits[BudgetCategory.food.label] ?? settings.foodBudget;
    final double foodSpent = categoryTotals[BudgetCategory.food.label] ?? 0;
    if (foodSpent > foodLimit * 0.7) {
      tips.add('Instead of milk tea ₱120, try street food + water around ₱60.');
    }

    if (tips.isEmpty) {
      tips.add(
          'Nice pace today. Keep an eye on one more small expense and you can still save money.');
    }

    return tips;
  }

  Map<BudgetPeriod, double> _periodLimits(BudgetSettings settings) {
    return <BudgetPeriod, double>{
      BudgetPeriod.daily: settings.totalDailyBudget,
      BudgetPeriod.weekly: settings.weeklyBudget ?? 0,
      BudgetPeriod.monthly: settings.monthlyBudget ?? 0,
    };
  }

  BudgetPeriod _primaryPeriod(BudgetSettings settings) {
    if (settings.totalDailyBudget > 0) {
      return BudgetPeriod.daily;
    }
    if ((settings.weeklyBudget ?? 0) > 0) {
      return BudgetPeriod.weekly;
    }
    if ((settings.monthlyBudget ?? 0) > 0) {
      return BudgetPeriod.monthly;
    }
    return BudgetPeriod.daily;
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

  List<ExpenseEntry> _expensesSince(
      List<ExpenseEntry> expenses, DateTime start) {
    return expenses
        .where((ExpenseEntry expense) =>
            !expense.dateTime.isBefore(start) &&
            !expense.dateTime.isAfter(DateTime.now()))
        .toList();
  }
}
