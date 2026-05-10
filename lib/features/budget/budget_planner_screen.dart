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
  ConsumerState<BudgetPlannerScreen> createState() =>
      _BudgetPlannerScreenState();
}

class _BudgetPlannerScreenState extends ConsumerState<BudgetPlannerScreen> {
  late final TextEditingController _quickBudgetController;
  BudgetExpiryPeriod _expiryPeriod = BudgetExpiryPeriod.daily;

  @override
  void initState() {
    super.initState();
    _quickBudgetController = TextEditingController();
  }

  @override
  void dispose() {
    _quickBudgetController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: <Widget>[
            const SectionTitle(
              title: 'Budget planner',
              subtitle: 'Set your budget and choose when it expires.',
            ),
            const SizedBox(height: 16),
            SectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Text(
                    'Quick Budget',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _quickBudgetController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Budget amount',
                      prefixText: '₱ ',
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Budget expires after:',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: Center(
                      child: SegmentedButton<BudgetExpiryPeriod>(
                        segments: const <ButtonSegment<BudgetExpiryPeriod>>[
                          ButtonSegment<BudgetExpiryPeriod>(
                            value: BudgetExpiryPeriod.daily,
                            label: Text(
                              '1 Day',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          ButtonSegment<BudgetExpiryPeriod>(
                            value: BudgetExpiryPeriod.weekly,
                            label: Text(
                              '1 Week',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          ButtonSegment<BudgetExpiryPeriod>(
                            value: BudgetExpiryPeriod.monthly,
                            label: Text(
                              '1 Month',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                        selected: <BudgetExpiryPeriod>{_expiryPeriod},
                        onSelectionChanged:
                            (Set<BudgetExpiryPeriod> newSelection) {
                          setState(() {
                            _expiryPeriod = newSelection.first;
                          });
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _applyQuickBudget,
                      child: const Text('Apply Budget'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _applyQuickBudget() {
    final double amount = double.tryParse(_quickBudgetController.text) ?? 0;
    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid budget amount')),
      );
      return;
    }

    final BudgetSettings currentSettings =
        ref.read(budgetBuddyControllerProvider).settings;
    final BudgetSettings visibleSettings = currentSettings.hasConfiguredBudget
        ? currentSettings
        : BudgetSettings.defaults();

    ref.read(budgetBuddyControllerProvider.notifier).updateBudget(
          BudgetSettings(
            totalDailyBudget: amount,
            foodBudget: visibleSettings.foodBudget,
            transportationBudget: visibleSettings.transportationBudget,
            leisureBudget: visibleSettings.leisureBudget,
            savingsGoal: visibleSettings.savingsGoal,
            budgetExpiryPeriod: _expiryPeriod,
            budgetCreatedAt: DateTime.now(),
          ),
        );

    _quickBudgetController.clear();
    final String expiryLabel = switch (_expiryPeriod) {
      BudgetExpiryPeriod.daily => '1 day',
      BudgetExpiryPeriod.weekly => '1 week',
      BudgetExpiryPeriod.monthly => '1 month',
    };
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Budget set to ${formatPeso(amount)}, expires in $expiryLabel',
        ),
      ),
    );
  }
}
