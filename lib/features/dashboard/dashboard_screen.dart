import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/budget_models.dart';
import '../../core/state/app_controller.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/budget_cards.dart';
import '../../core/widgets/section_title.dart';
import '../meals/meal_suggestions_screen.dart';
import '../gala/gala_planner_screen.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final BudgetBuddyState state = ref.watch(budgetBuddyControllerProvider);
    final BudgetSummary summary = ref.watch(budgetSummaryProvider);
    // suggestions moved to dedicated screens; no inline lists needed here
    final double totalBudget = summary.totalBudget;

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showQuickExpenseSheet(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Quick add'),
      ),
      body: SafeArea(
        child: CustomScrollView(
          slivers: <Widget>[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: _Header(summary: summary, profile: state.profile),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 220,
                  mainAxisExtent: 150,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                ),
                delegate: SliverChildListDelegate(
                  <Widget>[
                    BudgetMetricCard(
                      label: 'Remaining budget',
                      value: formatPeso(summary.remainingBalance),
                      subtitle: 'Today',
                      icon: Icons.savings_rounded,
                      color: const Color(0xFF0F766E),
                      onTap: () => _showMetricDetails(
                        context,
                        title: 'Remaining budget',
                        value: formatPeso(summary.remainingBalance),
                        detail: 'Money still available for spending today.',
                        extra: 'This card tracks how much budget is left.',
                      ),
                    ),
                    BudgetMetricCard(
                      label: 'Today spent',
                      value: formatPeso(summary.totalSpent),
                      subtitle: 'Out of ${formatPeso(totalBudget)}',
                      icon: Icons.payments_rounded,
                      color: const Color(0xFF2563EB),
                      onTap: () => _showMetricDetails(
                        context,
                        title: 'Today spent',
                        value: formatPeso(summary.totalSpent),
                        detail: 'Total expenses recorded for today.',
                        extra:
                            'This helps compare spending against the daily budget.',
                      ),
                    ),
                    BudgetMetricCard(
                      label: 'Savings',
                      value: formatPeso(summary.savings),
                      subtitle:
                          'Goal ${formatPeso(state.settings.savingsGoal)}',
                      icon: Icons.lock_rounded,
                      color: const Color(0xFFF97316),
                      onTap: () => _showMetricDetails(
                        context,
                        title: 'Savings',
                        value: formatPeso(summary.savings),
                        detail: 'Amount set aside compared with your goal.',
                        extra:
                            'Goal: ${formatPeso(state.settings.savingsGoal)}',
                      ),
                    ),
                    BudgetMetricCard(
                      label: 'Top category',
                      value: summary.biggestExpenseCategory,
                      subtitle: summary.overspendingCategories.isEmpty
                          ? 'Healthy pace'
                          : 'Watch overspending',
                      icon: Icons.pie_chart_rounded,
                      color: const Color(0xFF7C3AED),
                      onTap: () => _showMetricDetails(
                        context,
                        title: 'Top category',
                        value: summary.biggestExpenseCategory,
                        detail: summary.overspendingCategories.isEmpty
                            ? 'This is your highest-spending category right now.'
                            : 'This category is spending the most and needs attention.',
                        extra: summary.overspendingCategories.isEmpty
                            ? 'No overspending categories detected.'
                            : 'Watch: ${summary.overspendingCategories.join(', ')}',
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: SectionCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      const SectionTitle(
                          title: 'Spending breakdown',
                          subtitle: 'Real-time category totals and trend'),
                      SizedBox(
                        height: 220,
                        child: PieChart(
                          PieChartData(
                            sectionsSpace: 3,
                            centerSpaceRadius: 44,
                            sections: summary.categoryTotals.entries
                                .map((MapEntry<String, double> entry) {
                              final BudgetCategory category =
                                  BudgetCategoryX.fromString(
                                      entry.key.toLowerCase());
                              final double total = summary.totalSpent == 0
                                  ? 1
                                  : summary.totalSpent;
                              return PieChartSectionData(
                                value: entry.value,
                                title: entry.value <= 0
                                    ? ''
                                    : '${(entry.value / total * 100).toStringAsFixed(0)}%',
                                color: category.color,
                                radius: 64,
                                titleStyle: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                    fontSize: 12),
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: BudgetCategory.values
                            .map((BudgetCategory category) => SoftPill(
                                text: category.label,
                                color: category.color,
                                icon: Icons.circle))
                            .toList(),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: SectionCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      const SectionTitle(
                        title: 'Plan & suggestions',
                        subtitle: 'Open planners and suggestions',
                      ),
                      const SizedBox(height: 8),
                      Column(
                        children: <Widget>[
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(Icons.restaurant_menu_rounded),
                            title: const Text('Meal planner'),
                            subtitle: const Text('Plan meals and log recipes'),
                            trailing: const Icon(Icons.chevron_right_rounded),
                            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const MealSuggestionsScreen())),
                          ),
                          const Divider(height: 1),
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(Icons.explore_rounded),
                            title: const Text('Gala planner'),
                            subtitle: const Text('Ideas for strolls and activities'),
                            trailing: const Icon(Icons.chevron_right_rounded),
                            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const GalaPlannerScreen())),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: SectionTitle(
                    title: 'Insights',
                    subtitle: 'What the app wants you to know today'),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                child: SectionCard(
                  child: Column(
                    children: summary.recommendedActions
                        .map(
                          (String tip) => ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(Icons.auto_awesome_rounded),
                            title: Text(tip),
                          ),
                        )
                        .toList(),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showMetricDetails(
    BuildContext context, {
    required String title,
    required String value,
    required String detail,
    required String extra,
  }) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (BuildContext context) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                title,
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              Text(
                value,
                style: Theme.of(context)
                    .textTheme
                    .headlineSmall
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Text(detail),
              const SizedBox(height: 8),
              Text(
                extra,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        );
      },
    );
  }

  void _showQuickExpenseSheet(BuildContext context, WidgetRef ref) {
    final TextEditingController titleController = TextEditingController();
    final TextEditingController amountController = TextEditingController();
    BudgetCategory selectedCategory = BudgetCategory.food;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context,
              void Function(void Function()) setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text('Quick add expense',
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 16),
                  TextField(
                      controller: titleController,
                      decoration:
                          const InputDecoration(labelText: 'Expense name')),
                  const SizedBox(height: 12),
                  TextField(
                    controller: amountController,
                    keyboardType: TextInputType.number,
                    decoration:
                        const InputDecoration(labelText: 'Amount in PHP'),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<BudgetCategory>(
                    initialValue: selectedCategory,
                    items: BudgetCategory.values
                        .map((BudgetCategory category) =>
                            DropdownMenuItem<BudgetCategory>(
                                value: category, child: Text(category.label)))
                        .toList(),
                    onChanged: (BudgetCategory? value) {
                      if (value != null) {
                        setModalState(() => selectedCategory = value);
                      }
                    },
                    decoration: const InputDecoration(labelText: 'Category'),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () {
                        ref
                            .read(budgetBuddyControllerProvider.notifier)
                            .addExpense(
                              title: titleController.text.trim().isEmpty
                                  ? 'Quick expense'
                                  : titleController.text.trim(),
                              amount:
                                  double.tryParse(amountController.text) ?? 0,
                              category: selectedCategory,
                            );
                        Navigator.of(context).pop();
                      },
                      child: const Text('Save expense'),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.summary, required this.profile});

  final BudgetSummary summary;
  final UserProfile profile;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      child: Row(
        children: <Widget>[
          CircleAvatar(
            radius: 28,
            backgroundColor:
                Theme.of(context).colorScheme.primary.withValues(alpha: 0.12),
            child: Text(profile.avatarSeed,
                style: const TextStyle(fontWeight: FontWeight.w700)),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text('Hi, ${profile.displayName}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text(
                  'Today you have ${formatPeso(summary.remainingBalance)} left for the day.',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
          const Icon(Icons.bolt_rounded),
        ],
      ),
    );
  }
}

// _SuggestionCard removed — suggestions are now accessed via dedicated screens
