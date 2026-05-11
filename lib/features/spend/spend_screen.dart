import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/budget_models.dart';
import '../../core/state/app_controller.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/budget_cards.dart';
import '../../core/widgets/section_title.dart';

class SpendScreen extends ConsumerStatefulWidget {
  const SpendScreen({super.key});

  @override
  ConsumerState<SpendScreen> createState() => _SpendScreenState();
}

class _SpendScreenState extends ConsumerState<SpendScreen> {
  BudgetCategory _category = BudgetCategory.food;
  final TextEditingController _searchController = TextEditingController();
  final Set<String> _plannedIds = <String>{};

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final BudgetSummary summary = ref.watch(budgetSummaryProvider);
    final String query = _searchController.text.trim().toLowerCase();

    final List<_SpendIdea> ideas = _catalog.where((_SpendIdea idea) {
      final bool matchesCategory = idea.category == _category;
      final bool matchesQuery = query.isEmpty ||
          idea.title.toLowerCase().contains(query) ||
          idea.note.toLowerCase().contains(query);
      return matchesCategory && matchesQuery;
    }).toList();

    final List<_SpendIdea> plannedItems = _catalog
        .where((_SpendIdea idea) => _plannedIds.contains(idea.id))
        .toList();
    final double plannedTotal = plannedItems.fold<double>(
      0,
      (double sum, _SpendIdea idea) => sum + idea.estimatedPrice,
    );

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _logPlannedItems(context, plannedItems),
        icon: const Icon(Icons.playlist_add_check_rounded),
        label: const Text('Log planned'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: <Widget>[
            const SectionTitle(
              title: 'Spend',
              subtitle:
                  'Plan food, transport, entertainment, and shopping before you log anything.',
            ),
            const SizedBox(height: 12),
            BudgetMetricCard(
              label: 'Remaining budget',
              value: formatPeso(summary.remainingBalance),
              subtitle: plannedItems.isEmpty
                  ? 'No spend planned yet'
                  : '${plannedItems.length} planned • ${formatPeso(plannedTotal)} total',
              icon: Icons.savings_rounded,
              color: const Color(0xFF0F766E),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                labelText: 'Search spend ideas',
                prefixIcon: Icon(Icons.search_rounded),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: BudgetCategory.values
                  .map(
                    (BudgetCategory category) => ChoiceChip(
                      selected: _category == category,
                      label: Text(category.label),
                      avatar: Icon(category.colorIcon, size: 16),
                      onSelected: (_) => setState(() => _category = category),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 16),
            SectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          _category.label,
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                      ),
                      SoftPill(
                        text: _category.hint,
                        color: _category.color,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Build a short plan, then tap Log to turn it into a real expense. Anything logged here still counts against your daily, weekly, and monthly limits.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
            if (plannedItems.isNotEmpty) ...<Widget>[
              const SizedBox(height: 16),
              SectionCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            'Planned so far',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                        ),
                        Text(
                          '${plannedItems.length} items',
                          style: Theme.of(context).textTheme.labelLarge,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: plannedItems
                          .map(
                            (_SpendIdea idea) => ActionChip(
                              avatar: Icon(idea.icon, size: 18),
                              label: Text(
                                  '${idea.title} • ${formatPeso(idea.estimatedPrice)}'),
                              onPressed: () => setState(() {
                                _plannedIds.remove(idea.id);
                              }),
                            ),
                          )
                          .toList(),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.tonalIcon(
                        onPressed: () =>
                            _logPlannedItems(context, plannedItems),
                        icon: const Icon(Icons.playlist_add_check_rounded),
                        label: const Text('Log all planned items'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),
            ...ideas.map((_SpendIdea idea) {
              final bool planned = _plannedIds.contains(idea.id);
              final bool overBudget =
                  idea.estimatedPrice > summary.remainingBalance;
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: SectionCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color:
                                  idea.category.color.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Icon(idea.icon, color: idea.category.color),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(
                                  idea.title,
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium
                                      ?.copyWith(fontWeight: FontWeight.w800),
                                ),
                                const SizedBox(height: 4),
                                Text(idea.note),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: <Widget>[
                              Text(
                                formatPeso(idea.estimatedPrice),
                                style: Theme.of(context)
                                    .textTheme
                                    .titleSmall
                                    ?.copyWith(fontWeight: FontWeight.w800),
                              ),
                              const SizedBox(height: 6),
                              SoftPill(
                                text:
                                    overBudget ? 'Over budget' : 'Fits budget',
                                color: overBudget
                                    ? const Color(0xFFDC2626)
                                    : const Color(0xFF16A34A),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: <Widget>[
                          SoftPill(
                            text: idea.category.label,
                            color: idea.category.color,
                            icon: idea.icon,
                          ),
                          SoftPill(
                            text: idea.category.hint,
                            color: const Color(0xFF475569),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: <Widget>[
                          FilledButton.tonalIcon(
                            onPressed: () => setState(() {
                              if (planned) {
                                _plannedIds.remove(idea.id);
                              } else {
                                _plannedIds.add(idea.id);
                              }
                            }),
                            icon: Icon(
                              planned ? Icons.check_rounded : Icons.add_rounded,
                            ),
                            label: Text(planned ? 'Planned' : 'Plan'),
                          ),
                          const SizedBox(width: 8),
                          OutlinedButton.icon(
                            onPressed: () => _logIdea(context, idea),
                            icon: const Icon(Icons.play_arrow_rounded),
                            label: const Text('Log'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            }),
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }

  void _logIdea(BuildContext context, _SpendIdea idea) {
    ref.read(budgetBuddyControllerProvider.notifier).addExpense(
          title: idea.title,
          amount: idea.estimatedPrice,
          category: idea.category,
          note: idea.note,
          dateTime: DateTime.now(),
        );

    final double remaining = ref.read(budgetSummaryProvider).remainingBalance;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content:
            Text('${idea.title} logged. ${formatPeso(remaining)} remaining.'),
      ),
    );
  }

  void _logPlannedItems(BuildContext context, List<_SpendIdea> plannedItems) {
    if (plannedItems.isEmpty) {
      return;
    }

    for (final _SpendIdea idea in plannedItems) {
      ref.read(budgetBuddyControllerProvider.notifier).addExpense(
            title: idea.title,
            amount: idea.estimatedPrice,
            category: idea.category,
            note: idea.note,
            dateTime: DateTime.now(),
          );
    }

    setState(() {
      _plannedIds.clear();
    });

    final double remaining = ref.read(budgetSummaryProvider).remainingBalance;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '${plannedItems.length} planned item${plannedItems.length == 1 ? '' : 's'} logged. ${formatPeso(remaining)} remaining.',
        ),
      ),
    );
  }
}

class _SpendIdea {
  const _SpendIdea({
    required this.id,
    required this.title,
    required this.note,
    required this.category,
    required this.estimatedPrice,
    required this.icon,
  });

  final String id;
  final String title;
  final String note;
  final BudgetCategory category;
  final double estimatedPrice;
  final IconData icon;
}

const List<_SpendIdea> _catalog = <_SpendIdea>[
  _SpendIdea(
    id: 'food-breakfast',
    title: 'Budget breakfast',
    note: 'Rice meal, coffee, or a quick snack before class or work.',
    category: BudgetCategory.food,
    estimatedPrice: 85,
    icon: Icons.free_breakfast_rounded,
  ),
  _SpendIdea(
    id: 'food-lunch',
    title: 'Lunch combo',
    note: 'A full meal that keeps lunch predictable and affordable.',
    category: BudgetCategory.food,
    estimatedPrice: 140,
    icon: Icons.lunch_dining_rounded,
  ),
  _SpendIdea(
    id: 'transport-commute',
    title: 'Commute fare',
    note: 'Jeep, bus, or train money for the day.',
    category: BudgetCategory.transportation,
    estimatedPrice: 60,
    icon: Icons.directions_bus_rounded,
  ),
  _SpendIdea(
    id: 'transport-ride',
    title: 'Ride share buffer',
    note: 'Extra room for a grab ride when you need to get there faster.',
    category: BudgetCategory.transportation,
    estimatedPrice: 180,
    icon: Icons.local_taxi_rounded,
  ),
  _SpendIdea(
    id: 'entertainment-movie',
    title: 'Movie night',
    note: 'Ticket, popcorn, and a little cushion for a drink.',
    category: BudgetCategory.entertainment,
    estimatedPrice: 320,
    icon: Icons.local_movies_rounded,
  ),
  _SpendIdea(
    id: 'entertainment-games',
    title: 'Game / arcade break',
    note: 'Small entertainment spend for a short reset.',
    category: BudgetCategory.entertainment,
    estimatedPrice: 240,
    icon: Icons.sports_esports_rounded,
  ),
  _SpendIdea(
    id: 'shopping-essentials',
    title: 'Essentials restock',
    note: 'Toiletries, household basics, or school supplies.',
    category: BudgetCategory.shopping,
    estimatedPrice: 260,
    icon: Icons.shopping_cart_rounded,
  ),
  _SpendIdea(
    id: 'shopping-gift',
    title: 'Gift / errand stop',
    note: 'A planned errand with a fixed budget cap.',
    category: BudgetCategory.shopping,
    estimatedPrice: 420,
    icon: Icons.redeem_rounded,
  ),
  _SpendIdea(
    id: 'misc-buffer',
    title: 'Emergency buffer',
    note: 'Keep a little extra aside for unexpected costs.',
    category: BudgetCategory.miscellaneous,
    estimatedPrice: 150,
    icon: Icons.shield_rounded,
  ),
  _SpendIdea(
    id: 'misc-fees',
    title: 'Fees and small extras',
    note: 'Convenience fees, supplies, or random small charges.',
    category: BudgetCategory.miscellaneous,
    estimatedPrice: 95,
    icon: Icons.payments_rounded,
  ),
];

extension _BudgetCategoryColorIcon on BudgetCategory {
  IconData get colorIcon => switch (this) {
        BudgetCategory.food => Icons.restaurant_rounded,
        BudgetCategory.transportation => Icons.directions_bus_rounded,
        BudgetCategory.entertainment => Icons.local_activity_rounded,
        BudgetCategory.shopping => Icons.shopping_bag_rounded,
        BudgetCategory.miscellaneous => Icons.more_horiz_rounded,
      };
}
