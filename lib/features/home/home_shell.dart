import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../analytics/analytics_screen.dart';
import '../budget/budget_planner_screen.dart';
import '../dashboard/dashboard_screen.dart';
import '../expenses/expense_tracker_screen.dart';
import '../gala/gala_planner_screen.dart';
import '../meals/meal_suggestions_screen.dart';
import '../profile/profile_settings_screen.dart';
import '../../core/models/budget_models.dart';
import '../../core/state/app_controller.dart';
import '../../core/widgets/section_title.dart';

class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key});

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> {
  int _index = 0;

  late final List<Widget> _pages = <Widget>[
    DashboardScreen(onGetStarted: () => setState(() => _index = 1)),
    const BudgetPlannerScreen(),
    const MealSuggestionsScreen(),
    const GalaPlannerScreen(),
    const ExpenseTrackerScreen(),
    const _MoreScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final BudgetBuddyState state = ref.watch(budgetBuddyControllerProvider);
    final BudgetSummary summary = ref.watch(budgetSummaryProvider);
    final bool budgetExpired = _isBudgetExpired(state.settings);
    final bool billsNeedReview = summary.overspendingCategories.isNotEmpty;

    return Scaffold(
      body: IndexedStack(index: _index, children: _pages),
      floatingActionButton: Semantics(
        button: true,
        label: 'Quick add expense',
        child: FloatingActionButton.extended(
          onPressed: () => _showQuickExpenseSheet(context),
          icon: const Icon(Icons.add_rounded),
          label: const Text('Quick add'),
        ),
      ),
      bottomNavigationBar: NavigationBar(
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        selectedIndex: _index,
        onDestinationSelected: (int value) => setState(() => _index = value),
        destinations: <NavigationDestination>[
          const NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Badge(
              isLabelVisible: budgetExpired,
              backgroundColor: const Color(0xFFDC2626),
              child: const Icon(Icons.account_balance_wallet_outlined),
            ),
            selectedIcon: Badge(
              isLabelVisible: budgetExpired,
              backgroundColor: const Color(0xFFDC2626),
              child: const Icon(Icons.account_balance_wallet_rounded),
            ),
            label: 'Budget',
          ),
          const NavigationDestination(
            icon: Icon(Icons.restaurant_outlined),
            selectedIcon: Icon(Icons.restaurant_rounded),
            label: 'Meals',
          ),
          const NavigationDestination(
            icon: Icon(Icons.explore_outlined),
            selectedIcon: Icon(Icons.explore_rounded),
            label: 'Trips',
          ),
          NavigationDestination(
            icon: Badge(
              isLabelVisible: billsNeedReview,
              backgroundColor: const Color(0xFFF97316),
              child: const Icon(Icons.receipt_long_outlined),
            ),
            selectedIcon: Badge(
              isLabelVisible: billsNeedReview,
              backgroundColor: const Color(0xFFF97316),
              child: const Icon(Icons.receipt_long_rounded),
            ),
            label: 'Bills',
          ),
          const NavigationDestination(
            icon: Icon(Icons.more_horiz_outlined),
            selectedIcon: Icon(Icons.more_horiz_rounded),
            label: 'More',
          ),
        ],
      ),
    );
  }

  bool _isBudgetExpired(BudgetSettings settings) {
    final DateTime? createdAt = settings.budgetCreatedAt;
    if (!settings.hasConfiguredBudget || createdAt == null) {
      return false;
    }

    final Duration cycle = switch (settings.budgetExpiryPeriod) {
      BudgetExpiryPeriod.daily => const Duration(days: 1),
      BudgetExpiryPeriod.weekly => const Duration(days: 7),
      BudgetExpiryPeriod.monthly => const Duration(days: 30),
    };
    return !createdAt.add(cycle).isAfter(DateTime.now());
  }

  void _showQuickExpenseSheet(BuildContext context) {
    final TextEditingController titleController = TextEditingController();
    final TextEditingController amountController = TextEditingController();
    final TextEditingController noteController = TextEditingController();
    BudgetCategory selectedCategory =
        ref.read(budgetBuddyControllerProvider).lastExpenseCategory ??
            BudgetCategory.food;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (BuildContext context) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 12,
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
          ),
          child: StatefulBuilder(
            builder: (BuildContext context,
                void Function(void Function()) setModalState) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Quick add expense',
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: titleController,
                    decoration:
                        const InputDecoration(labelText: 'Expense name'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: amountController,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration:
                        const InputDecoration(labelText: 'Amount in PHP'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: noteController,
                    decoration: const InputDecoration(labelText: 'Note'),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<BudgetCategory>(
                    initialValue: selectedCategory,
                    items: BudgetCategory.values
                        .map(
                          (BudgetCategory category) =>
                              DropdownMenuItem<BudgetCategory>(
                            value: category,
                            child: Text(category.label),
                          ),
                        )
                        .toList(),
                    onChanged: (BudgetCategory? value) {
                      if (value == null) {
                        return;
                      }
                      setModalState(() => selectedCategory = value);
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
                              note: noteController.text.trim(),
                            );
                        Navigator.of(context).pop();
                      },
                      child: const Text('Save expense'),
                    ),
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

class _MoreScreen extends StatelessWidget {
  const _MoreScreen();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: <Widget>[
          const SectionTitle(
            title: 'More',
            subtitle: 'Extra tools and account options.',
          ),
          const SizedBox(height: 16),
          Card(
            child: ListTile(
              leading: const Icon(Icons.analytics_rounded),
              title: const Text('Stats'),
              subtitle: const Text('Open analytics and trends'),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const AnalyticsScreen(),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              leading: const Icon(Icons.settings_rounded),
              title: const Text('Profile'),
              subtitle: const Text('Preferences, exports, and reset options'),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const ProfileSettingsScreen(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
