import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/budget_models.dart';
import '../../core/state/app_controller.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/budget_cards.dart';
import '../../core/widgets/section_title.dart';

class GalaPlannerScreen extends ConsumerStatefulWidget {
  const GalaPlannerScreen({super.key});

  @override
  ConsumerState<GalaPlannerScreen> createState() => _GalaPlannerScreenState();
}

class _GalaPlannerScreenState extends ConsumerState<GalaPlannerScreen> {
  GalaMood _mood = GalaMood.chill;
  double _budget = 0;
  double _distance = 5;

  @override
  Widget build(BuildContext context) {
    final BudgetBuddyState state = ref.watch(budgetBuddyControllerProvider);
    final double configuredBudget = state.settings.hasConfiguredBudget
        ? state.settings.totalDailyBudget
        : 0;
    if (_budget != configuredBudget) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _budget != configuredBudget) {
          setState(() {
            _budget = configuredBudget;
          });
        }
      });
    }

    final double suggestedBudget =
        _budget.clamp(0, configuredBudget).toDouble();
    final List<ActivitySuggestion> activities =
        ref.read(budgetBuddyControllerProvider.notifier).activitiesFor(
              mood: _mood,
              preferredDistanceKm: _distance,
            );

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: <Widget>[
            const SectionTitle(
              title: 'Stroll / gala planner',
              subtitle:
                  'Choose a mood, budget, and distance, then let the app assemble a plan.',
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: GalaMood.values
                  .map((GalaMood mood) => ChoiceChip(
                      selected: _mood == mood,
                      label: Text(mood.label),
                      onSelected: (_) => setState(() => _mood = mood)))
                  .toList(),
            ),
            const SizedBox(height: 16),
            SectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Budget range: ${formatPeso(suggestedBudget)}',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  Slider(
                    value: suggestedBudget,
                    min: 0,
                    max: configuredBudget > 0 ? configuredBudget : 1000,
                    divisions: configuredBudget > 0 ? 20 : 20,
                    label: formatPeso(suggestedBudget),
                    onChanged: configuredBudget <= 0
                        ? null
                        : (double value) => setState(() => _budget = value),
                  ),
                  const SizedBox(height: 4),
                  Text('Preferred distance: ${_distance.toStringAsFixed(1)} km',
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                  Slider(
                    value: _distance,
                    min: 1,
                    max: 15,
                    divisions: 14,
                    label: '${_distance.toStringAsFixed(1)} km',
                    onChanged: (double value) =>
                        setState(() => _distance = value),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            BudgetMetricCard(
              label: 'Suggested gala budget',
              value: formatPeso(suggestedBudget),
              subtitle: configuredBudget <= 0
                  ? 'Set a budget first'
                  : 'Based on your set budget',
              icon: Icons.explore_rounded,
              color: const Color(0xFF7C3AED),
            ),
            const SizedBox(height: 16),
            const SectionTitle(
                title: 'Activity suggestions',
                subtitle: 'Budget-friendly alternatives for the day'),
            ...activities.map(
              (ActivitySuggestion activity) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
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
                                Text(activity.title,
                                    style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w700)),
                                const SizedBox(height: 4),
                                Text(
                                    '${activity.mood.label} • ${activity.distanceKm.toStringAsFixed(1)} km away'),
                              ],
                            ),
                          ),
                          Chip(label: Text(formatPeso(activity.estimatedCost))),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ...activity.details.map((String detail) => Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Text('• $detail'),
                          )),
                      const SizedBox(height: 6),
                      Row(
                        children: <Widget>[
                          FilledButton.tonalIcon(
                            onPressed: () {
                              ref
                                  .read(budgetBuddyControllerProvider.notifier)
                                  .addExpense(
                                    title: activity.title,
                                    amount: activity.estimatedCost,
                                    category: BudgetCategory.entertainment,
                                    note: 'Gala plan',
                                  );
                            },
                            icon: const Icon(Icons.add_rounded),
                            label: const Text('Add plan'),
                          ),
                          const SizedBox(width: 8),
                          OutlinedButton(
                            onPressed: () {
                              ref
                                  .read(budgetBuddyControllerProvider.notifier)
                                  .saveActivityPlan(activity);
                              ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content: Text(
                                          'Plan saved to your activity list.')));
                            },
                            child: const Text('Save'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 4),
            SectionCard(
              child: Text(
                configuredBudget <= 0
                    ? 'Set your budget in the Budget Planner first, then this trip budget will follow it.'
                    : suggestedBudget < configuredBudget * 0.5
                        ? 'Budget-friendly alternative: focus on coffee, walking, and one snack stop.'
                        : 'You can mix food, activities, and fare while staying inside your target.',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
