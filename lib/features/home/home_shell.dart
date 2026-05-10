import 'package:flutter/material.dart';

import '../analytics/analytics_screen.dart';
import '../budget/budget_planner_screen.dart';
import '../dashboard/dashboard_screen.dart';
import '../expenses/expense_tracker_screen.dart';
import '../gala/gala_planner_screen.dart';
import '../meals/meal_suggestions_screen.dart';
import '../profile/profile_settings_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  late final List<Widget> _pages = <Widget>[
    DashboardScreen(onGetStarted: () => setState(() => _index = 1)),
    const BudgetPlannerScreen(),
    const MealSuggestionsScreen(),
    const GalaPlannerScreen(),
    const ExpenseTrackerScreen(),
    const AnalyticsScreen(),
    const ProfileSettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _index, children: _pages),
      bottomNavigationBar: NavigationBar(
        labelBehavior: NavigationDestinationLabelBehavior.onlyShowSelected,
        selectedIndex: _index,
        onDestinationSelected: (int value) => setState(() => _index = value),
        destinations: const <NavigationDestination>[
          NavigationDestination(
              icon: Icon(Icons.dashboard_rounded), label: 'Home'),
          NavigationDestination(
              icon: Icon(Icons.account_balance_wallet_rounded),
              label: 'Budget'),
          NavigationDestination(
              icon: Icon(Icons.restaurant_rounded), label: 'Meals'),
          NavigationDestination(
              icon: Icon(Icons.explore_rounded), label: 'Trips'),
          NavigationDestination(
              icon: Icon(Icons.receipt_long_rounded), label: 'Bills'),
          NavigationDestination(
              icon: Icon(Icons.analytics_rounded), label: 'Stats'),
          NavigationDestination(
              icon: Icon(Icons.settings_rounded), label: 'Profile'),
        ],
      ),
    );
  }
}
