import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

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

/// Clean Modern Bento Tokens for Home Navigation Shell.
class _NavTokens {
  const _NavTokens(this.isDark);

  final bool isDark;

  static const Color activeGreen = Color(0xFF0F766E);
  static const Color spendGold = Color(0xFFD97706);
  static const Color alertRed = Color(0xFF991B1B);

  Color get scaffoldBg =>
      isDark ? const Color(0xFF0B1120) : const Color(0xFFF8FAFC);
  Color get navBarBg =>
      isDark ? const Color(0xFF111827) : const Color(0xFFFFFFFF);
  Color get borderColor =>
      isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0);
  Color get inactiveIcon =>
      isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
}

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
    // 0: Home (Dashboard)
    DashboardScreen(
      onGetStarted: () =>
          ref.read(homeShellIndexProvider.notifier).state = 1,
      onOpenSpend: () =>
          ref.read(homeShellIndexProvider.notifier).state = 2,
      onOpenExpenses: () =>
          ref.read(homeShellIndexProvider.notifier).state = 3,
      onOpenSavings: () =>
          ref.read(homeShellIndexProvider.notifier).state = 4,
      onOpenProfile: () =>
          ref.read(homeShellIndexProvider.notifier).state = 6,
    ),
    // 1: Budget Planner
    const BudgetPlannerScreen(),
    // 2: Quick Spend
    const SpendScreen(),
    // 3: Expenses
    const ExpenseTrackerScreen(),
    // 4: Savings (Vault & Debt)
    const SavingsScreen(),
    // 5: Together (Shared Couple Budget)
    const TogetherScreen(),
    // 6: Settings (Preferences & Data)
    const ProfileSettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final int rawIndex = ref.watch(homeShellIndexProvider);
    final int activeIndex = rawIndex.clamp(0, _pages.length - 1);
    final BudgetBuddyState state = ref.watch(budgetBuddyControllerProvider);
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final _NavTokens tokens = _NavTokens(isDark);
    final bool budgetExpired =
        _isBudgetExpired(state.settings, state.effectiveDate);

    return Scaffold(
      backgroundColor: tokens.scaffoldBg,
      body: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          IndexedStack(
            index: activeIndex,
            children: _pages,
          ),
          const Positioned.fill(
            child: BudgetAiAssistant(),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: tokens.navBarBg,
          border: Border(
            top: BorderSide(
              color: tokens.borderColor,
              width: 1.2,
            ),
          ),
        ),
        child: NavigationBarTheme(
          data: NavigationBarThemeData(
            backgroundColor: tokens.navBarBg,
            indicatorColor: activeIndex == 2
                ? _NavTokens.spendGold.withValues(alpha: 0.16)
                : _NavTokens.activeGreen.withValues(alpha: 0.14),
            indicatorShape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(999),
            ),
            labelTextStyle: WidgetStateProperty.resolveWith<TextStyle?>(
              (Set<WidgetState> states) {
                if (states.contains(WidgetState.selected)) {
                  return GoogleFonts.plusJakartaSans(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: activeIndex == 2
                        ? _NavTokens.spendGold
                        : _NavTokens.activeGreen,
                  );
                }
                return GoogleFonts.plusJakartaSans(
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  color: tokens.inactiveIcon,
                );
              },
            ),
            iconTheme: WidgetStateProperty.resolveWith<IconThemeData?>(
              (Set<WidgetState> states) {
                if (states.contains(WidgetState.selected)) {
                  return IconThemeData(
                    size: 21,
                    color: activeIndex == 2
                        ? _NavTokens.spendGold
                        : _NavTokens.activeGreen,
                  );
                }
                return IconThemeData(
                  size: 20,
                  color: tokens.inactiveIcon,
                );
              },
            ),
          ),
          child: NavigationBar(
            height: 64,
            elevation: 0,
            backgroundColor: tokens.navBarBg,
            labelBehavior: NavigationDestinationLabelBehavior.onlyShowSelected,
            selectedIndex: activeIndex,
            onDestinationSelected: (int value) {
              ref.read(homeShellIndexProvider.notifier).state = value;
            },
            destinations: <NavigationDestination>[
              // 1. Home
              const NavigationDestination(
                icon: Icon(Icons.home_outlined),
                selectedIcon: Icon(Icons.home_rounded),
                label: 'Home',
              ),
              // 2. Budget
              NavigationDestination(
                icon: Badge(
                  isLabelVisible: budgetExpired,
                  backgroundColor: _NavTokens.alertRed,
                  smallSize: 7,
                  child: const Icon(Icons.account_balance_wallet_outlined),
                ),
                selectedIcon: Badge(
                  isLabelVisible: budgetExpired,
                  backgroundColor: _NavTokens.alertRed,
                  smallSize: 7,
                  child: const Icon(Icons.account_balance_wallet_rounded),
                ),
                label: 'Budget',
              ),
              // 3. Spend (Quick Logger)
              const NavigationDestination(
                icon: Icon(
                  Icons.add_circle_outline_rounded,
                  color: _NavTokens.spendGold,
                ),
                selectedIcon: Icon(
                  Icons.add_circle_rounded,
                  color: _NavTokens.spendGold,
                ),
                label: 'Spend',
              ),
              // 4. Expenses
              const NavigationDestination(
                icon: Icon(Icons.receipt_long_outlined),
                selectedIcon: Icon(Icons.receipt_long_rounded),
                label: 'Expenses',
              ),
              // 5. Savings
              const NavigationDestination(
                icon: Icon(Icons.savings_outlined),
                selectedIcon: Icon(Icons.savings_rounded),
                label: 'Savings',
              ),
              // 6. Together
              const NavigationDestination(
                icon: Icon(Icons.groups_outlined),
                selectedIcon: Icon(Icons.groups_rounded),
                label: 'Together',
              ),
              // 7. Settings
              const NavigationDestination(
                icon: Icon(Icons.settings_outlined),
                selectedIcon: Icon(Icons.settings_rounded),
                label: 'Settings',
              ),
            ],
          ),
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
