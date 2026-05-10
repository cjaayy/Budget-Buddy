import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/budget_models.dart';
import '../../core/state/app_controller.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/section_title.dart';
import '../../core/widgets/budget_cards.dart';

class MealSuggestionsScreen extends ConsumerStatefulWidget {
  const MealSuggestionsScreen({super.key});

  @override
  ConsumerState<MealSuggestionsScreen> createState() =>
      _MealSuggestionsScreenState();
}

class _MealSuggestionsScreenState extends ConsumerState<MealSuggestionsScreen> {
  MealCategory _category = MealCategory.budgetMeals;
  MealType? _mealType;
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final List<MealSuggestion> mealsRaw =
        ref.read(budgetBuddyControllerProvider.notifier).mealsFor(
              category: _category,
              mealType: _mealType,
            );
    final String query = _searchController.text.trim().toLowerCase();
    final BudgetSummary summary = ref.watch(budgetSummaryProvider);
    List<MealSuggestion> meals = mealsRaw.where((MealSuggestion meal) {
      if (query.isEmpty) return true;
      return meal.name.toLowerCase().contains(query) ||
          meal.note.toLowerCase().contains(query);
    }).toList();
    // pinned/favorites to top
    final List<String> favorites =
        ref.watch(budgetBuddyControllerProvider).favoriteMealIds;
    meals.sort((a, b) {
      final int fa = favorites.contains(a.id) ? 0 : 1;
      final int fb = favorites.contains(b.id) ? 0 : 1;
      return fa.compareTo(fb);
    });

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showMealDialog(context),
        icon: const Icon(Icons.add),
        label: const Text('Custom meal'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: <Widget>[
            SectionTitle(
              title: 'Meal planner',
              subtitle:
                  'Smart suggestions based on your remaining budget ${formatPeso(summary.remainingBalance)}.',
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                labelText: 'Search meals',
                prefixIcon: Icon(Icons.search_rounded),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: MealCategory.values
                  .map(
                    (MealCategory category) => ChoiceChip(
                      selected: _category == category,
                      label: Text(category.label),
                      onSelected: (_) => setState(() => _category = category),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                ChoiceChip(
                  selected: _mealType == null,
                  label: const Text('All meals'),
                  onSelected: (_) => setState(() => _mealType = null),
                ),
                ...MealType.values.map(
                  (MealType type) => ChoiceChip(
                    selected: _mealType == type,
                    label: Text(type.label),
                    onSelected: (_) => setState(() => _mealType = type),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            if (summary.remainingBalance > 0)
              SectionCard(
                child: Text(
                  'You still have ${formatPeso(summary.remainingBalance)} left. Try a smart meal that fits the budget instead of a random splurge.',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
            const SizedBox(height: 18),
            ...meals.map((MealSuggestion meal) {
              final bool favorite = ref
                  .watch(budgetBuddyControllerProvider)
                  .favoriteMealIds
                  .contains(meal.id);
              final bool overBudget =
                  meal.estimatedPrice > summary.remainingBalance;
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: GestureDetector(
                  onLongPress: () => _showMealDialog(context, existing: meal),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: overBudget
                          ? Border.all(
                              color: const Color(0xFFDC2626), width: 1.5)
                          : null,
                    ),
                    child: SectionCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Row(
                            children: <Widget>[
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: <Widget>[
                                    Text(meal.name,
                                        style: const TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.w700)),
                                    const SizedBox(height: 4),
                                    Text(
                                        '${meal.category.label} • ${meal.mealType.label}'),
                                  ],
                                ),
                              ),
                              IconButton(
                                onPressed: () => ref
                                    .read(
                                        budgetBuddyControllerProvider.notifier)
                                    .toggleFavoriteMeal(meal.id),
                                icon: Icon(favorite
                                    ? Icons.favorite_rounded
                                    : Icons.favorite_border_rounded),
                                color: favorite ? Colors.pink : null,
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(meal.note),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            alignment: WrapAlignment.start,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: <Widget>[
                              SoftPill(
                                  text: formatPeso(meal.estimatedPrice),
                                  color: const Color(0xFF16A34A),
                                  icon: Icons.attach_money_rounded),
                              if (meal.calories != null)
                                SoftPill(
                                  text: '${meal.calories} cal',
                                  color: const Color(0xFFF59E0B),
                                  icon: Icons.local_fire_department_rounded,
                                ),
                              if (overBudget)
                                SoftPill(
                                  text: 'Over budget',
                                  color: const Color(0xFFDC2626),
                                  icon: Icons.warning_rounded,
                                ),
                              FilledButton.tonalIcon(
                                onPressed: () {
                                  ref
                                      .read(budgetBuddyControllerProvider
                                          .notifier)
                                      .addExpense(
                                        title: meal.name,
                                        amount: meal.estimatedPrice,
                                        category: BudgetCategory.food,
                                        note: meal.note,
                                        dateTime: DateTime.now(),
                                      );
                                  final double remaining = ref
                                      .read(budgetSummaryProvider)
                                      .remainingBalance;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                          content: Text(
                                              '${meal.name} logged. ${formatPeso(remaining)} remaining today.')));
                                },
                                icon: const Icon(Icons.add_chart_rounded),
                                label: const Text('Log meal'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  void _showMealDialog(BuildContext context, {MealSuggestion? existing}) {
    final TextEditingController nameController =
        TextEditingController(text: existing?.name ?? '');
    final TextEditingController priceController = TextEditingController(
        text:
            existing != null ? existing.estimatedPrice.toStringAsFixed(0) : '');
    final TextEditingController noteController =
        TextEditingController(text: existing?.note ?? '');
    MealType mealType = existing?.mealType ?? MealType.snack;
    MealCategory mealCategory = existing?.category ?? MealCategory.budgetMeals;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext context) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
          ),
          child: StatefulBuilder(
            builder: (BuildContext context,
                void Function(void Function()) setModalState) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  TextField(
                      controller: nameController,
                      decoration:
                          const InputDecoration(labelText: 'Meal name')),
                  const SizedBox(height: 12),
                  TextField(
                    controller: priceController,
                    keyboardType: TextInputType.number,
                    decoration:
                        const InputDecoration(labelText: 'Estimated price'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                      controller: noteController,
                      decoration: const InputDecoration(labelText: 'Note')),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<MealType>(
                    initialValue: mealType,
                    items: MealType.values
                        .map((MealType type) => DropdownMenuItem<MealType>(
                            value: type, child: Text(type.label)))
                        .toList(),
                    onChanged: (MealType? value) {
                      if (value != null) setModalState(() => mealType = value);
                    },
                    decoration: const InputDecoration(labelText: 'Meal type'),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<MealCategory>(
                    initialValue: mealCategory,
                    items: MealCategory.values
                        .map((MealCategory category) =>
                            DropdownMenuItem<MealCategory>(
                                value: category, child: Text(category.label)))
                        .toList(),
                    onChanged: (MealCategory? value) {
                      if (value != null) {
                        setModalState(() => mealCategory = value);
                      }
                    },
                    decoration: const InputDecoration(labelText: 'Category'),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: FilledButton(
                          onPressed: () {
                            final MealSuggestion meal = MealSuggestion(
                              id: existing?.id ??
                                  DateTime.now()
                                      .microsecondsSinceEpoch
                                      .toString(),
                              name: nameController.text.trim().isEmpty
                                  ? 'Custom meal'
                                  : nameController.text.trim(),
                              estimatedPrice:
                                  double.tryParse(priceController.text) ?? 0,
                              mealType: mealType,
                              category: mealCategory,
                              note: noteController.text.trim(),
                            );
                            if (existing != null) {
                              ref
                                  .read(budgetBuddyControllerProvider.notifier)
                                  .updateCustomMeal(meal);
                            } else {
                              ref
                                  .read(budgetBuddyControllerProvider.notifier)
                                  .addCustomMeal(meal);
                            }
                            Navigator.of(context).pop();
                          },
                          child: Text(
                              existing != null ? 'Save changes' : 'Save meal'),
                        ),
                      ),
                      if (existing != null) ...<Widget>[
                        const SizedBox(width: 8),
                        FilledButton.tonal(
                          onPressed: () {
                            ref
                                .read(budgetBuddyControllerProvider.notifier)
                                .deleteCustomMeal(existing.id);
                            Navigator.of(context).pop();
                          },
                          child: const Text('Delete'),
                        ),
                      ],
                    ],
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }
}
