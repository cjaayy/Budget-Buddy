import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../budget/budget_planner_screen.dart';
import '../dashboard/dashboard_screen.dart';
import '../expenses/expense_tracker_screen.dart';
import '../profile/profile_settings_screen.dart';
import '../savings/savings_screen.dart';
import '../spend/spend_screen.dart';
import '../../core/models/budget_models.dart';
import '../../core/state/app_controller.dart';
import '../../core/services/update_service.dart';
import '../../core/widgets/budget_ai_assistant.dart';

/// Clean Modern Bento Tokens for Home Shell Navigation.
class _NavTokens {
  const _NavTokens(this.isDark);

  final bool isDark;

  static const Color activeGreen = Color(0xFF0F766E);
  static const Color centerGold = Color(0xFFD97706);
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
    DashboardScreen(
      onGetStarted: () =>
          ref.read(homeShellIndexProvider.notifier).state = 1,
      onOpenSpend: () =>
          ref.read(homeShellIndexProvider.notifier).state = 2,
      onOpenExpenses: () =>
          ref.read(homeShellIndexProvider.notifier).state = 3,
      onOpenSavings: () {
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => const SavingsScreen(),
          ),
        );
      },
      onOpenProfile: () =>
          ref.read(homeShellIndexProvider.notifier).state = 4,
    ),
    const BudgetPlannerScreen(),
    const SpendScreen(),
    const ExpenseTrackerScreen(),
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
          if (kDebugMode)
            const Positioned.fill(
              child: BudgetAiAssistant(),
            ),
        ],
      ),
      bottomNavigationBar: _buildBottomNav(
        context: context,
        selectedIndex: activeIndex,
        budgetExpired: budgetExpired,
        tokens: tokens,
      ),
    );
  }

  Widget _buildBottomNav({
    required BuildContext context,
    required int selectedIndex,
    required bool budgetExpired,
    required _NavTokens tokens,
  }) {
    final double bottomPadding = MediaQuery.of(context).padding.bottom;

    return Container(
      decoration: BoxDecoration(
        color: tokens.navBarBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        border: Border(
          top: BorderSide(
            color: tokens.borderColor,
            width: 1.2,
          ),
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: tokens.isDark ? 0.35 : 0.04),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.only(
            left: 6,
            right: 6,
            top: 6,
            bottom: bottomPadding > 0 ? 4 : 8,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: <Widget>[
              // Tab 1: Home
              _buildStandardNavItem(
                index: 0,
                selectedIndex: selectedIndex,
                label: 'Home',
                unselectedIcon: Icons.home_outlined,
                selectedIcon: Icons.home_rounded,
                tokens: tokens,
              ),

              // Tab 2: Budget
              _buildStandardNavItem(
                index: 1,
                selectedIndex: selectedIndex,
                label: 'Budget',
                unselectedIcon: Icons.account_balance_wallet_outlined,
                selectedIcon: Icons.account_balance_wallet_rounded,
                hasBadge: budgetExpired,
                tokens: tokens,
              ),

              // Tab 3: Quick Log (Prominent Center Button)
              _buildCenterQuickLogItem(
                selectedIndex: selectedIndex,
                tokens: tokens,
              ),

              // Tab 4: Expenses
              _buildStandardNavItem(
                index: 3,
                selectedIndex: selectedIndex,
                label: 'Expenses',
                unselectedIcon: Icons.receipt_long_outlined,
                selectedIcon: Icons.receipt_long_rounded,
                tokens: tokens,
              ),

              // Tab 5: Settings / Hub
              _buildStandardNavItem(
                index: 4,
                selectedIndex: selectedIndex,
                label: 'Settings',
                unselectedIcon: Icons.settings_outlined,
                selectedIcon: Icons.settings_rounded,
                tokens: tokens,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStandardNavItem({
    required int index,
    required int selectedIndex,
    required String label,
    required IconData unselectedIcon,
    required IconData selectedIcon,
    required _NavTokens tokens,
    bool hasBadge = false,
  }) {
    final bool isSelected = selectedIndex == index;

    return Expanded(
      child: InkWell(
        onTap: () => ref.read(homeShellIndexProvider.notifier).state = index,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              // Active Tab Indicator Pill
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: isSelected
                      ? _NavTokens.activeGreen.withValues(alpha: 0.14)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Badge(
                  isLabelVisible: hasBadge,
                  backgroundColor: _NavTokens.alertRed,
                  smallSize: 8,
                  child: Icon(
                    isSelected ? selectedIcon : unselectedIcon,
                    size: 22,
                    color: isSelected
                        ? _NavTokens.activeGreen
                        : tokens.inactiveIcon,
                  ),
                ),
              ),
              const SizedBox(height: 2),
              // Only Show Selected Label Behavior
              if (isSelected)
                Text(
                  label,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: _NavTokens.activeGreen,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                )
              else
                const SizedBox(height: 13),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCenterQuickLogItem({
    required int selectedIndex,
    required _NavTokens tokens,
  }) {
    final bool isSelected = selectedIndex == 2;

    return Expanded(
      child: InkWell(
        onTap: () => ref.read(homeShellIndexProvider.notifier).state = 2,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              // Prominent raised / distinctly styled center action button
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: isSelected
                      ? _NavTokens.activeGreen
                      : _NavTokens.centerGold,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: (isSelected
                              ? _NavTokens.activeGreen
                              : _NavTokens.centerGold)
                          .withValues(alpha: 0.35),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                alignment: Alignment.center,
                child: const Icon(
                  Icons.add_rounded,
                  color: Colors.white,
                  size: 26,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Quick Log',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 10,
                  fontWeight:
                      isSelected ? FontWeight.w800 : FontWeight.w700,
                  color: isSelected
                      ? _NavTokens.activeGreen
                      : tokens.inactiveIcon,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
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
