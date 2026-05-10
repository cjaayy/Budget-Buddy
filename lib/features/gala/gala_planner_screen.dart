import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/budget_models.dart';
import '../budget/budget_planner_screen.dart';
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
  final Set<String> _selectedActivityIds = <String>{};

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
                      label: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Icon(mood.icon, size: 16),
                          const SizedBox(width: 8),
                          Text(mood.label),
                        ],
                      ),
                      onSelected: (_) => setState(() => _mood = mood)))
                  .toList(),
            ),
            const SizedBox(height: 16),
            SectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: <Widget>[
                      Text(
                        'Budget range: ${formatPeso(suggestedBudget)}',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      if (configuredBudget <= 0)
                        FilledButton(
                          onPressed: () {
                            Navigator.of(context).push(MaterialPageRoute(
                                builder: (_) => const BudgetPlannerScreen()));
                          },
                          child: const Text('Set budget'),
                        ),
                    ],
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
                  Text(
                      'Preferred distance: ${_distance.toStringAsFixed(1)} km — ${_distanceLabel(_distance)}',
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
            ...activities.map((ActivitySuggestion activity) {
              final bool canAfford = activity.estimatedCost <= suggestedBudget;
              final bool selected = _selectedActivityIds.contains(activity.id);
              return Padding(
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
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: <Widget>[
                              Text(formatPeso(activity.estimatedCost),
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 16)),
                              const SizedBox(height: 6),
                              SoftPill(
                                text: canAfford ? 'Can afford' : 'Over budget',
                                color: canAfford
                                    ? const Color(0xFF16A34A)
                                    : const Color(0xFFDC2626),
                              ),
                            ],
                          ),
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
                              setState(() {
                                if (selected) {
                                  _selectedActivityIds.remove(activity.id);
                                } else {
                                  _selectedActivityIds.add(activity.id);
                                }
                              });
                            },
                            icon: Icon(
                                selected ? Icons.check : Icons.add_rounded),
                            label: Text(selected ? 'Added' : 'Add plan'),
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
                              // after saving single activity, ask to log it
                              _promptLogActivities(
                                  context, <ActivitySuggestion>[activity]);
                            },
                            child: const Text('Save'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            }),
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
            const SizedBox(height: 80),
          ],
        ),
      ),
      bottomSheet: _selectedActivityIds.isEmpty
          ? null
          : SafeArea(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withValues(alpha: 0.06),
                        blurRadius: 8)
                  ],
                ),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        '${_selectedActivityIds.length} activities selected — Est. ${formatPeso(_selectedActivityIds.fold(0.0, (double sum, String id) {
                          final act = activities.firstWhere((a) => a.id == id);
                          return sum + act.estimatedCost;
                        }))}',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                    FilledButton(
                      onPressed: () async {
                        final List<ActivitySuggestion> toCommit = activities
                            .where((a) => _selectedActivityIds.contains(a.id))
                            .toList();
                        final messenger = ScaffoldMessenger.of(context);
                        final bool? doLog = await showDialog<bool>(
                          context: context,
                          builder: (BuildContext ctx) {
                            return AlertDialog(
                              title: const Text('Commit plans'),
                              content: Text(
                                  'Log ${toCommit.length} activities as expenses now?'),
                              actions: <Widget>[
                                TextButton(
                                    onPressed: () =>
                                        Navigator.of(ctx).pop(false),
                                    child: const Text('No')),
                                FilledButton(
                                    onPressed: () =>
                                        Navigator.of(ctx).pop(true),
                                    child: const Text('Yes, log')),
                              ],
                            );
                          },
                        );
                        if (doLog == true) {
                          for (final ActivitySuggestion a in toCommit) {
                            ref
                                .read(budgetBuddyControllerProvider.notifier)
                                .addExpense(
                                  title: a.title,
                                  amount: a.estimatedCost,
                                  category: BudgetCategory.entertainment,
                                  note: 'Gala plan',
                                );
                          }
                          if (mounted) {
                            messenger.showSnackBar(SnackBar(
                                content: Text(
                                    'Logged ${toCommit.length} activities.')));
                          }
                        }
                        setState(() => _selectedActivityIds.clear());
                      },
                      child: const Text('Commit'),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton(
                      onPressed: () =>
                          setState(() => _selectedActivityIds.clear()),
                      child: const Text('Clear'),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  String _distanceLabel(double km) {
    if (km <= 2) return 'within your barangay';
    if (km <= 6) return 'within your city';
    return 'nearby town';
  }

  Future<void> _promptLogActivities(
      BuildContext context, List<ActivitySuggestion> activities) async {
    final messenger = ScaffoldMessenger.of(context);
    final bool? result = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) {
        return AlertDialog(
          title: const Text('Log activity as expense?'),
          content:
              Text('Log ${activities.length} activity(ies) as expenses now?'),
          actions: <Widget>[
            TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('No')),
            FilledButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text('Yes')),
          ],
        );
      },
    );
    if (result == true) {
      for (final ActivitySuggestion a in activities) {
        ref.read(budgetBuddyControllerProvider.notifier).addExpense(
              title: a.title,
              amount: a.estimatedCost,
              category: BudgetCategory.entertainment,
              note: 'Gala plan',
            );
      }
      if (mounted) {
        messenger.showSnackBar(
            const SnackBar(content: Text('Activities logged as expenses.')));
      }
    }
  }
}
