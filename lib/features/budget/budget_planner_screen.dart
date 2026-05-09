import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/budget_models.dart';
import '../../core/state/app_controller.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/budget_cards.dart';
import '../../core/widgets/section_title.dart';

class BudgetPlannerScreen extends ConsumerStatefulWidget {
  const BudgetPlannerScreen({super.key});

  @override
  ConsumerState<BudgetPlannerScreen> createState() => _BudgetPlannerScreenState();
}

class _BudgetPlannerScreenState extends ConsumerState<BudgetPlannerScreen> {
  late final TextEditingController _totalController;
  late final TextEditingController _foodController;
  late final TextEditingController _transportController;
  late final TextEditingController _leisureController;
  late final TextEditingController _savingsController;

  @override
  void initState() {
    super.initState();
    final BudgetSettings settings = ref.read(budgetBuddyControllerProvider).settings;
    _totalController = TextEditingController(text: settings.totalDailyBudget.toStringAsFixed(0));
    _foodController = TextEditingController(text: settings.foodBudget.toStringAsFixed(0));
    _transportController = TextEditingController(text: settings.transportationBudget.toStringAsFixed(0));
    _leisureController = TextEditingController(text: settings.leisureBudget.toStringAsFixed(0));
    _savingsController = TextEditingController(text: settings.savingsGoal.toStringAsFixed(0));
  }

  @override
  void dispose() {
    _totalController.dispose();
    _foodController.dispose();
    _transportController.dispose();
    _leisureController.dispose();
    _savingsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final BudgetBuddyState state = ref.watch(budgetBuddyControllerProvider);
    final BudgetSummary summary = ref.watch(budgetSummaryProvider);

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: <Widget>[
            SectionTitle(
              title: 'Daily budget planner',
              subtitle: 'Keep your food, fare, and gala money in balance.',
              actionText: 'Save',
              onAction: _saveBudget,
            ),
            const SizedBox(height: 12),
            SectionCard(
              child: Column(
                children: <Widget>[
                  _BudgetTextField(controller: _totalController, label: 'Total daily budget'),
                  const SizedBox(height: 12),
                  _BudgetTextField(controller: _foodController, label: 'Food budget'),
                  const SizedBox(height: 12),
                  _BudgetTextField(controller: _transportController, label: 'Transportation budget'),
                  const SizedBox(height: 12),
                  _BudgetTextField(controller: _leisureController, label: 'Leisure / stroll budget'),
                  const SizedBox(height: 12),
                  _BudgetTextField(controller: _savingsController, label: 'Savings goal'),
                ],
              ),
            ),
            const SizedBox(height: 18),
            GridView.count(
              crossAxisCount: MediaQuery.of(context).size.width > 500 ? 2 : 1,
              physics: const NeverScrollableScrollPhysics(),
              shrinkWrap: true,
              childAspectRatio: MediaQuery.of(context).size.width > 500 ? 1.65 : 2.2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              children: <Widget>[
                BudgetMetricCard(
                  label: 'Remaining',
                  value: formatPeso(summary.remainingBalance),
                  subtitle: 'After today\'s spending',
                  icon: Icons.savings_rounded,
                  color: const Color(0xFF0F766E),
                ),
                BudgetMetricCard(
                  label: 'Overspending',
                  value: summary.overspendingCategories.isEmpty ? 'None' : summary.overspendingCategories.join(', '),
                  subtitle: 'Budget check',
                  icon: Icons.warning_rounded,
                  color: summary.overspendingCategories.isEmpty ? const Color(0xFF2563EB) : const Color(0xFFEF4444),
                ),
              ],
            ),
            const SizedBox(height: 18),
            SectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: BudgetCategory.values.map((BudgetCategory category) {
                  final double limit = _limitFor(state.settings, category);
                  final double spent = summary.categoryTotals[category.label] ?? 0;
                  final double progress = limit == 0 ? 0 : (spent / limit).clamp(0, 1.4).toDouble();
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Row(
                          children: <Widget>[
                            Expanded(child: Text(category.label, style: const TextStyle(fontWeight: FontWeight.w700))),
                            Text('${formatPeso(spent)} / ${formatPeso(limit)}'),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(999),
                          child: LinearProgressIndicator(
                            minHeight: 10,
                            value: progress.clamp(0, 1).toDouble(),
                            color: category.color,
                            backgroundColor: category.color.withOpacity(0.10),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  double _limitFor(BudgetSettings settings, BudgetCategory category) {
    return switch (category) {
      BudgetCategory.food => settings.foodBudget,
      BudgetCategory.transportation => settings.transportationBudget,
      BudgetCategory.entertainment => settings.leisureBudget,
      BudgetCategory.shopping => settings.totalDailyBudget * 0.15,
      BudgetCategory.miscellaneous => settings.totalDailyBudget * 0.10,
    };
  }

  void _saveBudget() {
    ref.read(budgetBuddyControllerProvider.notifier).updateBudget(
          BudgetSettings(
            totalDailyBudget: double.tryParse(_totalController.text) ?? 0,
            foodBudget: double.tryParse(_foodController.text) ?? 0,
            transportationBudget: double.tryParse(_transportController.text) ?? 0,
            leisureBudget: double.tryParse(_leisureController.text) ?? 0,
            savingsGoal: double.tryParse(_savingsController.text) ?? 0,
          ),
        );
  }
}

class _BudgetTextField extends StatelessWidget {
  const _BudgetTextField({required this.controller, required this.label});

  final TextEditingController controller;
  final String label;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(labelText: label, prefixText: '₱ '),
    );
  }
}