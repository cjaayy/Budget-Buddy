import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../budget/budget_planner_screen.dart';
import '../dashboard/dashboard_screen.dart';
import '../expenses/expense_tracker_screen.dart';
import '../profile/profile_settings_screen.dart';
import '../savings/savings_screen.dart';
import '../spend/spend_screen.dart';
import '../together/together_screen.dart';
import '../../core/models/budget_models.dart';
import '../../core/state/app_controller.dart';
import '../../core/services/update_service.dart';
import '../../core/widgets/budget_ai_assistant.dart';

class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key});

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        UpdateService.instance.checkOnLaunch(context);
      }
    });
  }

  late final List<Widget> _pages = <Widget>[
    DashboardScreen(
      onGetStarted: () =>
          ref.read(homeShellIndexProvider.notifier).state = 1,
      onOpenSpend: () =>
          ref.read(homeShellIndexProvider.notifier).state = 2,
      onOpenExpenses: () =>
          ref.read(homeShellIndexProvider.notifier).state = 3,
      onOpenSavings: () =>
          ref.read(homeShellIndexProvider.notifier).state = 4,
    ),
    const BudgetPlannerScreen(),
    const SpendScreen(),
    const ExpenseTrackerScreen(),
    const SavingsScreen(),
    const TogetherScreen(),
    const ProfileSettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final int index = ref.watch(homeShellIndexProvider);
    final BudgetBuddyState state = ref.watch(budgetBuddyControllerProvider);
    final bool budgetExpired =
        _isBudgetExpired(state.settings, state.effectiveDate);

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          IndexedStack(index: index, children: _pages),
          if (kDebugMode)
            const Positioned.fill(
              child: BudgetAiAssistant(),
            ),
        ],
      ),
      bottomNavigationBar: NavigationBarTheme(
        data: NavigationBarThemeData(
          indicatorColor: Theme.of(context).colorScheme.primaryContainer,
          labelTextStyle: WidgetStateProperty.resolveWith<TextStyle?>(
              (Set<WidgetState> states) {
            return const TextStyle(fontSize: 11, height: 1.0);
          }),
        ),
        child: NavigationBar(
          labelBehavior: NavigationDestinationLabelBehavior.onlyShowSelected,
          selectedIndex: index,
          onDestinationSelected: (int value) =>
              ref.read(homeShellIndexProvider.notifier).state = value,
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
              icon: Icon(Icons.shopping_bag_outlined),
              selectedIcon: Icon(Icons.shopping_bag_rounded),
              label: 'Spend',
            ),
            const NavigationDestination(
              icon: Icon(Icons.receipt_long_outlined),
              selectedIcon: Icon(Icons.receipt_long_rounded),
              label: 'Expenses',
            ),
            const NavigationDestination(
              icon: Icon(Icons.savings_outlined),
              selectedIcon: Icon(Icons.savings_rounded),
              label: 'Savings',
            ),
            const NavigationDestination(
              icon: Icon(Icons.groups_outlined),
              selectedIcon: Icon(Icons.groups_rounded),
              label: 'Together',
            ),
            const NavigationDestination(
              icon: Icon(Icons.settings_outlined),
              selectedIcon: Icon(Icons.settings_rounded),
              label: 'Settings',
            ),
          ],
        ),
      ),
    );
  }

  bool _isBudgetExpired(BudgetSettings settings, DateTime now) {
    final DateTime? createdAt = settings.budgetCreatedAt;
    if (!settings.hasConfiguredBudget || createdAt == null) {
      return false;
    }

    final Duration cycle = switch (settings.budgetExpiryPeriod) {
      BudgetExpiryPeriod.daily => const Duration(days: 1),
      BudgetExpiryPeriod.weekly => const Duration(days: 7),
      BudgetExpiryPeriod.monthly => const Duration(days: 30),
    };
    return !createdAt.add(cycle).isAfter(now);
  }
}
