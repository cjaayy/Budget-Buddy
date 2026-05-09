import '../models/budget_models.dart';

class BudgetService {
  BudgetSummary computeSummary(BudgetBuddyState state) {
    final Map<String, double> categoryTotals = <String, double>{
      for (final BudgetCategory category in BudgetCategory.values) category.label: 0,
    };

    for (final ExpenseEntry expense in state.expenses) {
      categoryTotals[expense.category.label] = (categoryTotals[expense.category.label] ?? 0) + expense.amount;
    }

    final double totalSpent = categoryTotals.values.fold(0, (double sum, double value) => sum + value);
    final double remainingBalance = state.settings.totalDailyBudget - totalSpent;
    final double savings = remainingBalance.clamp(0, state.settings.totalDailyBudget).toDouble();

    final Map<String, double> categoryPercentages = <String, double>{};
    final Map<String, double> limits = _categoryLimits(state.settings);
    final List<String> overspendingCategories = <String>[];
    for (final MapEntry<String, double> entry in categoryTotals.entries) {
      final double limit = limits[entry.key] ?? state.settings.totalDailyBudget;
      categoryPercentages[entry.key] = limit == 0 ? 0 : (entry.value / limit).clamp(0, 1.5).toDouble();
      if (entry.value > limit && entry.value > 0) {
        overspendingCategories.add(entry.key);
      }
    }

    final Map<String, double> nonZeroTotals = Map<String, double>.fromEntries(
      categoryTotals.entries.where((MapEntry<String, double> entry) => entry.value > 0),
    );
    final String biggestExpenseCategory = nonZeroTotals.isEmpty
        ? BudgetCategory.miscellaneous.label
        : nonZeroTotals.entries.reduce((MapEntry<String, double> left, MapEntry<String, double> right) {
            return left.value >= right.value ? left : right;
          }).key;

    final List<String> recommendations = _buildRecommendations(
      settings: state.settings,
      totalSpent: totalSpent,
      remainingBalance: remainingBalance,
      overspendingCategories: overspendingCategories,
      categoryTotals: categoryTotals,
      categoryLimits: limits,
    );

    final double savingsProgress = state.settings.savingsGoal <= 0
        ? 1
          : (savings / state.settings.savingsGoal).clamp(0, 1.5).toDouble();

    return BudgetSummary(
      totalBudget: state.settings.totalDailyBudget,
      totalSpent: totalSpent,
      remainingBalance: remainingBalance,
      savings: savings,
      biggestExpenseCategory: biggestExpenseCategory,
      categoryTotals: categoryTotals,
      categoryPercentages: categoryPercentages,
      overspendingCategories: overspendingCategories,
      recommendedActions: recommendations,
      savingsProgress: savingsProgress,
    );
  }

  List<MealSuggestion> recommendMeals({
    required BudgetBuddyState state,
    required MealCategory category,
    MealType? mealType,
    double? remainingBudget,
  }) {
    final double budget = remainingBudget ?? computeSummary(state).remainingBalance;
    final List<MealSuggestion> catalog = <MealSuggestion>[
      ...MealSuggestion.sampleCatalog(),
      ...state.customMeals,
    ];

    final List<MealSuggestion> filtered = catalog.where((MealSuggestion meal) {
      final bool withinBudget = meal.estimatedPrice <= budget;
      final bool matchesCategory = meal.category == category || category == MealCategory.budgetMeals;
      final bool matchesMealType = mealType == null || meal.mealType == mealType;
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
        return meal.copyWith(isFavorite: state.favoriteMealIds.contains(meal.id));
      }).toList();
    }

    return catalog
        .where((MealSuggestion meal) => meal.estimatedPrice <= budget + 40)
        .take(3)
        .map((MealSuggestion meal) => meal.copyWith(isFavorite: state.favoriteMealIds.contains(meal.id)))
        .toList();
  }

  List<ActivitySuggestion> recommendActivities({
    required GalaMood mood,
    required double budget,
    required double preferredDistanceKm,
  }) {
    final List<ActivitySuggestion> catalog = ActivitySuggestion.sampleCatalog();
    final List<ActivitySuggestion> filtered = catalog.where((ActivitySuggestion activity) {
      final bool moodMatch = activity.mood == mood || mood == GalaMood.chill;
      final bool budgetMatch = activity.estimatedCost <= budget;
      final bool distanceMatch = activity.distanceKm <= preferredDistanceKm || preferredDistanceKm == 0;
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

    return catalog.where((ActivitySuggestion activity) => activity.estimatedCost <= budget + 100).take(3).toList();
  }

  Map<String, double> _categoryLimits(BudgetSettings settings) {
    return <String, double>{
      BudgetCategory.food.label: settings.foodBudget,
      BudgetCategory.transportation.label: settings.transportationBudget,
      BudgetCategory.entertainment.label: settings.leisureBudget,
      BudgetCategory.shopping.label: settings.totalDailyBudget * 0.15,
      BudgetCategory.miscellaneous.label: settings.totalDailyBudget * 0.10,
    };
  }

  List<String> _buildRecommendations({
    required BudgetSettings settings,
    required double totalSpent,
    required double remainingBalance,
    required List<String> overspendingCategories,
    required Map<String, double> categoryTotals,
    required Map<String, double> categoryLimits,
  }) {
    final List<String> tips = <String>[];

    if (remainingBalance < 0) {
      tips.add('You are overspending by ${remainingBalance.abs().toStringAsFixed(0)} pesos. Reduce non-essential purchases today.');
    } else if (remainingBalance < settings.savingsGoal * 0.4) {
      tips.add('Your savings buffer is getting thin. Try a cheaper meal or skip one extra ride.');
    }

    if (overspendingCategories.contains(BudgetCategory.food.label)) {
      tips.add('Food is above budget. A street-food meal can save around ₱40 to ₱70 per meal.');
    }
    if (overspendingCategories.contains(BudgetCategory.entertainment.label)) {
      tips.add('Leisure is high today. Consider a coffee walk or window shopping instead of a full outing.');
    }
    if (totalSpent > settings.totalDailyBudget * 0.85) {
      tips.add('You are close to your daily budget cap. Keep the next purchase under ₱50 if possible.');
    }

    final double foodLimit = categoryLimits[BudgetCategory.food.label] ?? settings.foodBudget;
    final double foodSpent = categoryTotals[BudgetCategory.food.label] ?? 0;
    if (foodSpent > foodLimit * 0.7) {
      tips.add('Instead of milk tea ₱120, try street food + water around ₱60.');
    }

    if (tips.isEmpty) {
      tips.add('Nice pace today. Keep an eye on one more small expense and you can still save money.');
    }

    return tips;
  }
}