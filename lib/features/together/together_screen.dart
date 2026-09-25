import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/models/budget_models.dart';
import '../../core/state/app_controller.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/budget_cards.dart';
import '../expenses/expense_tracker_screen.dart';
import '../savings/savings_screen.dart';
import '../spend/spend_screen.dart';
import 'budget_together_screen.dart';
import 'package:budgetbuddy/core/utils/alert_dialog.dart';

/// Clean Modern Bento Tokens for Offline Shared Daily Budget ("Budget Together").
/// 100% OFFLINE dedicated parallel workspace.
/// - Target / Planning / Edit: Gold (#D97706)
/// - Safe / Savings / Confirm: Dark Teal Green (#0F766E)
/// - Expenses / Deficit / Delete: Dark Red (#991B1B)
class _TogetherTokens {
  const _TogetherTokens(this.isDark);

  final bool isDark;

  // Primary Strict 3-Color Palette
  static const Color budgetGold = Color(0xFFD97706);
  static const Color safeGreen = Color(0xFF0F766E);
  static const Color spentRed = Color(0xFF991B1B);

  // Surfaces & Borders
  Color get scaffoldBg =>
      isDark ? const Color(0xFF0B1120) : const Color(0xFFF8FAFC);
  Color get cardBg =>
      isDark ? const Color(0xFF111827) : const Color(0xFFFFFFFF);
  Color get cardBorder =>
      isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0);
  Color get subCardBg =>
      isDark ? const Color(0xFF161F31) : const Color(0xFFF1F5F9);

  // Text
  Color get textPrimary =>
      isDark ? const Color(0xFFF1F5F9) : const Color(0xFF0F172A);
  Color get textSecondary =>
      isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
  Color get textMuted =>
      isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8);

  Color tint(Color color, [double alpha = 0.10]) =>
      color.withValues(alpha: alpha);
}

class TogetherScreen extends ConsumerStatefulWidget {
  const TogetherScreen({super.key});

  @override
  ConsumerState<TogetherScreen> createState() => _TogetherScreenState();
}

class _TogetherScreenState extends ConsumerState<TogetherScreen> {
  int? _selectedModuleIndex;

  @override
  Widget build(BuildContext context) {
    final DateTime currentClock =
        ref.read(budgetBuddyControllerProvider.notifier).currentEffectiveTime;
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final _TogetherTokens tokens = _TogetherTokens(isDark);

    return PopScope(
      canPop: _selectedModuleIndex == null,
      onPopInvokedWithResult: (bool didPop, dynamic result) {
        if (!didPop) {
          setState(() => _selectedModuleIndex = null);
        }
      },
      child: Scaffold(
        backgroundColor: tokens.scaffoldBg,
        body: SafeArea(
          bottom: false,
          child: _selectedModuleIndex == null
              ? _buildHubView(currentClock, tokens)
              : _buildModuleContainer(tokens),
        ),
      ),
    );
  }

  /// Hub Menu: Overview Card + Vertical List of 4 Features
  Widget _buildHubView(DateTime currentClock, _TogetherTokens tokens) {
    final BudgetBuddyState state = ref.watch(budgetBuddyControllerProvider);
    final double totalBudget = state.togetherBudget;
    final List<ExpenseEntry> todaySharedExpenses = state.expenses.where((ExpenseEntry e) {
      if (e.source != 'togetherSpend') return false;
      return DateUtils.isSameDay(e.dateTime, currentClock);
    }).toList();

    final double spent = todaySharedExpenses.fold<double>(
        0.0, (double sum, ExpenseEntry e) => sum + e.amount);
    final double remaining = totalBudget - spent;
    final bool hasBudget = totalBudget > 0;
    final bool isOver = remaining < 0;
    final double progressValue = totalBudget > 0
        ? (spent / totalBudget).clamp(0.0, 1.0)
        : 0.0;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: <Widget>[
        // Top Header: Title, Live Date, and Hub Badge
        _buildTopHeader(currentClock, tokens),
        const SizedBox(height: 14),

        // Shared Budget Summary Bento Card
        _buildHubOverviewCard(
          totalBudget: totalBudget,
          spent: spent,
          remaining: remaining,
          progressValue: progressValue,
          hasBudget: hasBudget,
          isOver: isOver,
          tokens: tokens,
        ),
        const SizedBox(height: 20),

        // Section Title: Together Modules
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            Row(
              children: <Widget>[
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: tokens.tint(_TogetherTokens.safeGreen, 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.dashboard_customize_rounded,
                    size: 15,
                    color: _TogetherTokens.safeGreen,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'Together Modules',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: tokens.textPrimary,
                    letterSpacing: -0.4,
                  ),
                ),
              ],
            ),
            SoftPill(
              text: 'Tap to Open',
              color: _TogetherTokens.safeGreen,
              icon: Icons.touch_app_rounded,
              fontSize: 10.5,
            ),
          ],
        ),
        const SizedBox(height: 12),

        // 1. Budget Plan
        _buildHubOptionCard(
          index: 0,
          title: 'Budget Plan',
          subtitle: 'Set daily shared target, toggle lock status & view breakdown',
          icon: Icons.calendar_today_rounded,
          accentColor: _TogetherTokens.budgetGold,
          badgeText: 'Planning',
          tokens: tokens,
        ),

        // 2. Quick Spend
        _buildHubOptionCard(
          index: 1,
          title: 'Quick Spend',
          subtitle: 'Tactile numeric keypad & batch expense logger for shared costs',
          icon: Icons.bolt_rounded,
          accentColor: _TogetherTokens.spentRed,
          badgeText: 'Log Spend',
          tokens: tokens,
        ),

        // 3. Expense History
        _buildHubOptionCard(
          index: 2,
          title: 'Expense History',
          subtitle: 'Review shared transaction logs, filters & detail sheets',
          icon: Icons.receipt_long_rounded,
          accentColor: _TogetherTokens.budgetGold,
          badgeText: 'History',
          tokens: tokens,
        ),

        // 4. Savings & Debt
        _buildHubOptionCard(
          index: 3,
          title: 'Savings & Debt',
          subtitle: 'Manage shared emergency vault, debt tracker & joint goals',
          icon: Icons.savings_rounded,
          accentColor: _TogetherTokens.safeGreen,
          badgeText: 'Vault & Debt',
          tokens: tokens,
        ),
      ],
    );
  }

  /// Top Screen Title Header
  Widget _buildTopHeader(DateTime currentClock, _TogetherTokens tokens) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Budget Together',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: tokens.textPrimary,
                letterSpacing: -0.6,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              DateFormat('EEEE, MMMM d, y').format(currentClock),
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: tokens.textSecondary,
              ),
            ),
          ],
        ),
        SoftPill(
          text: 'Shared Hub',
          color: _TogetherTokens.budgetGold,
          icon: Icons.people_alt_rounded,
          fontSize: 11,
        ),
      ],
    );
  }

  /// Shared Overview Card on the Hub Screen
  Widget _buildHubOverviewCard({
    required double totalBudget,
    required double spent,
    required double remaining,
    required double progressValue,
    required bool hasBudget,
    required bool isOver,
    required _TogetherTokens tokens,
  }) {
    return BentoCard(
      padding: const EdgeInsets.all(18),
      borderRadius: 20,
      borderColor: _TogetherTokens.budgetGold.withValues(alpha: 0.35),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: tokens.tint(_TogetherTokens.budgetGold, 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.groups_rounded,
                      size: 15,
                      color: _TogetherTokens.budgetGold,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    "Today's Shared Overview",
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: tokens.textSecondary,
                    ),
                  ),
                ],
              ),
              SoftPill(
                text: hasBudget ? 'Active Shared' : 'No Limit Set',
                color: hasBudget
                    ? _TogetherTokens.budgetGold
                    : _TogetherTokens.spentRed,
                fontSize: 10.5,
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Total Shared Target Figure
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              formatPeso(totalBudget),
              style: GoogleFonts.plusJakartaSans(
                fontSize: 32,
                fontWeight: FontWeight.w900,
                color: _TogetherTokens.budgetGold,
                letterSpacing: -1.0,
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Sub-metrics Row
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: tokens.subCardBg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: tokens.cardBorder),
            ),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'Spent Today',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: tokens.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        formatPeso(spent),
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: _TogetherTokens.spentRed,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  height: 28,
                  width: 1,
                  color: tokens.cardBorder,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        isOver ? 'Deficit' : 'Safe Remaining',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: tokens.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        (isOver ? '-' : '') + formatPeso(remaining.abs()),
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: isOver
                              ? _TogetherTokens.spentRed
                              : _TogetherTokens.safeGreen,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          BentoHealthBar(
            progress: progressValue,
            color: _TogetherTokens.budgetGold,
            backgroundColor: tokens.subCardBg,
            height: 6,
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Text(
                '${(progressValue * 100).round()}% allowance used',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                  color: tokens.textSecondary,
                ),
              ),
              Text(
                isOver
                    ? 'Exceeded by ${formatPeso(remaining.abs())}'
                    : '${formatPeso(remaining > 0 ? remaining : 0)} safe balance',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  color: isOver
                      ? _TogetherTokens.spentRed
                      : _TogetherTokens.safeGreen,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Hub List Option Card
  Widget _buildHubOptionCard({
    required int index,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color accentColor,
    required String badgeText,
    required _TogetherTokens tokens,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => setState(() => _selectedModuleIndex = index),
          borderRadius: BorderRadius.circular(18),
          child: BentoCard(
            padding: const EdgeInsets.all(16),
            borderRadius: 18,
            child: Row(
              children: <Widget>[
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: tokens.tint(accentColor, 0.14),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: accentColor.withValues(alpha: 0.25),
                      width: 1.0,
                    ),
                  ),
                  child: Icon(
                    icon,
                    size: 22,
                    color: accentColor,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          Text(
                            title,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: tokens.textPrimary,
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(width: 8),
                          SoftPill(
                            text: badgeText,
                            color: accentColor,
                            fontSize: 10,
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w500,
                          color: tokens.textSecondary,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 14,
                  color: tokens.textMuted,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Container for the opened module with top back bar and preserved IndexedStack
  Widget _buildModuleContainer(_TogetherTokens tokens) {
    return Column(
      children: <Widget>[
        // Top Navigation Bar with Back Button
        _buildModuleTopBar(tokens),

        // Preserved IndexedStack
        Expanded(
          child: IndexedStack(
            index: _selectedModuleIndex ?? 0,
            children: <Widget>[
              // View 1: Together Budget Plan
              _TogetherBudgetPlanView(tokens: tokens),
              // View 2: Together Quick Spend Log (Tactile Keypad & Batch Queue)
              const SpendScreen(isTogetherOnly: true),
              // View 3: Together Expense History & Log (Filters & Detail Sheets)
              const ExpenseTrackerScreen(isTogetherOnly: true),
              // View 4: Together Savings & Debt Tracker (Vault, Deficit & Goals)
              const SavingsScreen(isTogetherOnly: true),
            ],
          ),
        ),
      ],
    );
  }

  /// Top Bar with Back Button inside any active module
  Widget _buildModuleTopBar(_TogetherTokens tokens) {
    final String title = switch (_selectedModuleIndex) {
      0 => 'Budget Plan',
      1 => 'Quick Spend',
      2 => 'Expense History',
      3 => 'Savings & Debt',
      _ => 'Budget Together',
    };

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      decoration: BoxDecoration(
        color: tokens.scaffoldBg,
        border: Border(
          bottom: BorderSide(color: tokens.cardBorder, width: 1.0),
        ),
      ),
      child: Row(
        children: <Widget>[
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => setState(() => _selectedModuleIndex = null),
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: tokens.subCardBg,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: tokens.cardBorder),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Icon(
                      Icons.arrow_back_rounded,
                      size: 16,
                      color: tokens.textPrimary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Back to List',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: tokens.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              title,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: tokens.textPrimary,
                letterSpacing: -0.4,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

/// =========================================================================
/// VIEW 1: TOGETHER BUDGET PLAN (Offline Daily Budget Plan View)
/// =========================================================================
class _TogetherBudgetPlanView extends ConsumerStatefulWidget {
  const _TogetherBudgetPlanView({
    required this.tokens,
    super.key,
  });

  final _TogetherTokens tokens;

  @override
  ConsumerState<_TogetherBudgetPlanView> createState() =>
      _TogetherBudgetPlanViewState();
}

class _TogetherBudgetPlanViewState
    extends ConsumerState<_TogetherBudgetPlanView> {
  static const List<double> _quickPresets = <double>[300, 500, 1000, 1500];
  static const String _lockPrefsKey = 'budgetbuddy_together_budget_locked';

  bool _isLocked = false;

  @override
  void initState() {
    super.initState();
    _loadLockState();
  }

  Future<void> _loadLockState() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      setState(() {
        _isLocked = prefs.getBool(_lockPrefsKey) ?? false;
      });
    } catch (_) {}
  }

  Future<void> _setLockState(bool locked) async {
    setState(() {
      _isLocked = locked;
    });
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_lockPrefsKey, locked);
    } catch (_) {}
  }

  IconData _iconForCategory(BudgetCategory category) {
    return switch (category) {
      BudgetCategory.food => Icons.restaurant_rounded,
      BudgetCategory.transportation => Icons.directions_bus_rounded,
      BudgetCategory.entertainment => Icons.celebration_rounded,
      BudgetCategory.shopping => Icons.shopping_bag_rounded,
      BudgetCategory.miscellaneous => Icons.category_rounded,
    };
  }

  String _labelForCategory(BudgetCategory category) {
    return switch (category) {
      BudgetCategory.food => 'Food & Groceries',
      BudgetCategory.transportation => 'Transport & Commute',
      BudgetCategory.entertainment => 'Date & Gala',
      BudgetCategory.shopping => 'Bills & Household',
      BudgetCategory.miscellaneous => 'Miscellaneous',
    };
  }

  @override
  Widget build(BuildContext context) {
    final BudgetBuddyState state = ref.watch(budgetBuddyControllerProvider);
    final DateTime currentClock =
        ref.read(budgetBuddyControllerProvider.notifier).currentEffectiveTime;
    final _TogetherTokens tokens = widget.tokens;

    final double totalBudget = state.togetherBudget;
    final List<ExpenseEntry> todaySharedExpenses = state.expenses.where((ExpenseEntry e) {
      if (e.source != 'togetherSpend') return false;
      return DateUtils.isSameDay(e.dateTime, currentClock);
    }).toList();

    final double spent = todaySharedExpenses.fold<double>(
        0.0, (double sum, ExpenseEntry e) => sum + e.amount);
    final double remaining = totalBudget - spent;
    final bool hasBudget = totalBudget > 0;
    final bool isOver = remaining < 0;
    final double progressValue = totalBudget > 0
        ? (spent / totalBudget).clamp(0.0, 1.0)
        : 0.0;

    // Category breakdown totals
    final Map<BudgetCategory, double> categorySpent = <BudgetCategory, double>{
      for (final BudgetCategory cat in BudgetCategory.values) cat: 0.0,
    };
    for (final ExpenseEntry e in todaySharedExpenses) {
      categorySpent[e.category] = (categorySpent[e.category] ?? 0.0) + e.amount;
    }

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      children: <Widget>[
        // Header Row: Title, Date & Status Pill / Reset Button
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  "Shared Budget Plan",
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: tokens.textPrimary,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  DateFormat('EEEE, MMMM d, y').format(currentClock),
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: tokens.textSecondary,
                  ),
                ),
              ],
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                if (hasBudget || spent > 0) ...<Widget>[
                  IconButton(
                    icon: const Icon(Icons.restart_alt_rounded, size: 20),
                    color: _TogetherTokens.spentRed,
                    tooltip: 'Reset Today',
                    onPressed: () => _confirmResetTodayBudget(context, tokens),
                  ),
                  const SizedBox(width: 4),
                ],
                SoftPill(
                  text: _isLocked ? 'Locked' : (hasBudget ? 'Active' : 'Setup'),
                  color: _isLocked
                      ? _TogetherTokens.budgetGold
                      : (hasBudget
                          ? _TogetherTokens.safeGreen
                          : _TogetherTokens.budgetGold),
                  icon: _isLocked
                      ? Icons.lock_outline_rounded
                      : Icons.edit_rounded,
                  fontSize: 11,
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Header & Lock Switch Tile
        _buildLockSwitchTile(hasBudget: hasBudget, tokens: tokens),
        const SizedBox(height: 14),

        // Unified Bento Card: Today's Shared Target, Presets, and Set Target Button
        _buildHeroBudgetCard(
          totalBudget: totalBudget,
          spent: spent,
          remaining: remaining,
          progressValue: progressValue,
          hasBudget: hasBudget,
          isOver: isOver,
          tokens: tokens,
        ),
        const SizedBox(height: 16),

        // Shared Category Breakdown Section (Informational Only - No Spend Shortcuts)
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            Row(
              children: <Widget>[
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: tokens.tint(_TogetherTokens.budgetGold, 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.pie_chart_outline_rounded,
                    size: 15,
                    color: _TogetherTokens.budgetGold,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'Shared Category Breakdown',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: tokens.textPrimary,
                    letterSpacing: -0.4,
                  ),
                ),
              ],
            ),
            SoftPill(
              text: 'Today',
              color: _TogetherTokens.budgetGold,
              icon: Icons.pie_chart_rounded,
              fontSize: 10.5,
            ),
          ],
        ),
        const SizedBox(height: 10),

        // List of Shared Categories with Spent Amount and Health Bar (Non-interactive)
        ...BudgetCategory.values.map((BudgetCategory category) {
          final double catSpent = categorySpent[category] ?? 0.0;
          final double catShare = spent > 0 ? (catSpent / spent).clamp(0.0, 1.0) : 0.0;

          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: BentoCard(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              borderRadius: 16,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          color: tokens.tint(_TogetherTokens.budgetGold, 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          _iconForCategory(category),
                          size: 16,
                          color: _TogetherTokens.budgetGold,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _labelForCategory(category),
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: tokens.textPrimary,
                          ),
                        ),
                      ),
                      Text(
                        formatPeso(catSpent),
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: catSpent > 0
                              ? _TogetherTokens.spentRed
                              : tokens.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  BentoHealthBar(
                    progress: catShare,
                    color: _TogetherTokens.budgetGold,
                    backgroundColor: tokens.subCardBg,
                    height: 5,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: <Widget>[
                      Text(
                        catSpent > 0
                            ? '${(catShare * 100).round()}% of shared spent'
                            : 'No shared expenses today',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w500,
                          color: tokens.textMuted,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        }),
        const SizedBox(height: 24),
      ],
    );
  }

  /// Lock/Unlock Switch Tile
  Widget _buildLockSwitchTile({
    required bool hasBudget,
    required _TogetherTokens tokens,
  }) {
    return BentoCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      borderRadius: 16,
      child: Row(
        children: <Widget>[
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: tokens.tint(
                _isLocked
                    ? _TogetherTokens.budgetGold
                    : _TogetherTokens.safeGreen,
                0.12,
              ),
              shape: BoxShape.circle,
            ),
            child: Icon(
              _isLocked ? Icons.lock_rounded : Icons.lock_open_rounded,
              size: 16,
              color: _isLocked
                  ? _TogetherTokens.budgetGold
                  : _TogetherTokens.safeGreen,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  _isLocked ? 'Together Daily Plan Locked' : 'Editing Mode Active',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: tokens.textPrimary,
                  ),
                ),
                Text(
                  _isLocked
                      ? 'Protected against accidental changes'
                      : 'Adjust your shared daily target below',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: tokens.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Switch.adaptive(
            value: _isLocked,
            activeColor: _TogetherTokens.budgetGold,
            onChanged: (bool value) {
              _setLockState(value);
              showAppAlert(
                context,
                message: value
                    ? 'Together budget locked against edits.'
                    : 'Together budget unlocked for changes.',
                title: value ? 'Budget Locked' : 'Budget Unlocked',
                icon: value
                    ? Icons.lock_outline_rounded
                    : Icons.lock_open_rounded,
                accentColor: value
                    ? _TogetherTokens.spentRed
                    : _TogetherTokens.safeGreen,
              );
            },
          ),
        ],
      ),
    );
  }

  /// Hero Bento Card: Today's Shared Target
  Widget _buildHeroBudgetCard({
    required double totalBudget,
    required double spent,
    required double remaining,
    required double progressValue,
    required bool hasBudget,
    required bool isOver,
    required _TogetherTokens tokens,
  }) {
    return BentoCard(
      borderRadius: 24,
      padding: const EdgeInsets.all(18),
      borderColor: _TogetherTokens.budgetGold.withValues(alpha: 0.35),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // Header Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: tokens.tint(_TogetherTokens.budgetGold, 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.groups_rounded,
                      size: 15,
                      color: _TogetherTokens.budgetGold,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    "Today's Shared Target",
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: tokens.textSecondary,
                    ),
                  ),
                ],
              ),
              SoftPill(
                text: hasBudget ? 'Active Plan' : 'No Limit Set',
                color: hasBudget
                    ? _TogetherTokens.budgetGold
                    : _TogetherTokens.spentRed,
                fontSize: 10.5,
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Prominent Gold Figure
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              formatPeso(totalBudget),
              style: GoogleFonts.plusJakartaSans(
                fontSize: 34,
                fontWeight: FontWeight.w900,
                color: _TogetherTokens.budgetGold,
                letterSpacing: -1.0,
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Sub-metric Row: Spent Today vs Remaining Safe
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: tokens.subCardBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: tokens.cardBorder),
            ),
            child: Row(
              children: <Widget>[
                // Spent Today (Dark Red)
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          const Icon(
                            Icons.arrow_downward_rounded,
                            size: 13,
                            color: _TogetherTokens.spentRed,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Spent Today',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: tokens.textSecondary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          formatPeso(spent),
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: _TogetherTokens.spentRed,
                            letterSpacing: -0.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  height: 32,
                  width: 1,
                  color: tokens.cardBorder,
                ),
                const SizedBox(width: 14),

                // Remaining Safe (Dark Teal Green)
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          Icon(
                            isOver
                                ? Icons.warning_amber_rounded
                                : Icons.shield_rounded,
                            size: 13,
                            color: isOver
                                ? _TogetherTokens.spentRed
                                : _TogetherTokens.safeGreen,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            isOver ? 'Deficit' : 'Remaining Safe',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: tokens.textSecondary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          (isOver ? '-' : '') + formatPeso(remaining.abs()),
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: isOver
                                ? _TogetherTokens.spentRed
                                : _TogetherTokens.safeGreen,
                            letterSpacing: -0.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Clean Progress Bar in Gold
          BentoHealthBar(
            progress: progressValue,
            color: _TogetherTokens.budgetGold,
            backgroundColor: tokens.subCardBg,
            height: 8,
          ),
          const SizedBox(height: 6),

          // Subtitle
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Text(
                '${(progressValue * 100).round()}% allowance consumed',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: tokens.textSecondary,
                ),
              ),
              Text(
                isOver
                    ? 'Exceeded by ${formatPeso(remaining.abs())}'
                    : '${formatPeso(remaining > 0 ? remaining : 0)} safe balance',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: isOver
                      ? _TogetherTokens.spentRed
                      : _TogetherTokens.safeGreen,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Divider
          Divider(
            height: 1,
            thickness: 1,
            color: tokens.cardBorder,
          ),
          const SizedBox(height: 14),

          // Quick Presets Section inside the card
          _buildQuickPresets(currentBudget: totalBudget, tokens: tokens),
          const SizedBox(height: 14),

          // Set / Adjust Target Button & Reset Today Button
          _buildActionButtons(
            currentBudget: totalBudget,
            spent: spent,
            tokens: tokens,
          ),
        ],
      ),
    );
  }

  /// Quick Presets (₱300, ₱500, ₱1,000, ₱1,500)
  Widget _buildQuickPresets({
    required double currentBudget,
    required _TogetherTokens tokens,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            Text(
              'Quick Daily Presets',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: tokens.textSecondary,
              ),
            ),
            Text(
              _isLocked ? 'Locked (Unlock switch to apply)' : 'Tap to apply',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color:
                    _isLocked ? _TogetherTokens.budgetGold : tokens.textMuted,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: _quickPresets.map((double preset) {
              final bool isSelected = currentBudget == preset;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: InkWell(
                  onTap: () {
                    if (_isLocked) {
                      HapticFeedback.lightImpact();
                      showAppAlert(context, message: 'Together plan is locked. Toggle switch above to unlock and change target.', title: 'Notice', icon: Icons.info_outline_rounded,

                        accentColor: _TogetherTokens.budgetGold,

                      );
                      return;
                    }
                    ref
                        .read(budgetBuddyControllerProvider.notifier)
                        .setTogetherBudget(preset);
                    showAppAlert(context,
                      message: 'Shared target updated to ${formatPeso(preset)}!',
                      title: 'Notice',
                      icon: Icons.info_outline_rounded,
                      accentColor: _TogetherTokens.budgetGold,
                    );
                  },
                  borderRadius: BorderRadius.circular(999),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? _TogetherTokens.budgetGold
                          : tokens.subCardBg,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: isSelected
                            ? _TogetherTokens.budgetGold
                            : tokens.cardBorder,
                      ),
                    ),
                    child: Text(
                      formatPeso(preset),
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        fontWeight:
                            isSelected ? FontWeight.w800 : FontWeight.w600,
                        color: isSelected ? Colors.white : tokens.textSecondary,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  /// Action Buttons (Adjust Target & Reset Today)
  Widget _buildActionButtons({
    required double currentBudget,
    required double spent,
    required _TogetherTokens tokens,
  }) {
    final bool canReset = currentBudget > 0 || spent > 0;
    return Row(
      children: <Widget>[
        // Adjust Target: Solid Gold (#D97706) when unlocked, Tonal Locked when locked
        Expanded(
          child: FilledButton.icon(
            onPressed: () {
              if (_isLocked) {
                HapticFeedback.lightImpact();
                showAppAlert(context, message: 'Together plan is locked. Toggle switch above to unlock and adjust target.', title: 'Notice', icon: Icons.info_outline_rounded,

                  accentColor: _TogetherTokens.budgetGold,

                );
                return;
              }
              _showAdjustTargetSheet(context, currentBudget, tokens);
            },
            icon: Icon(
              _isLocked ? Icons.lock_rounded : Icons.tune_rounded,
              size: 15,
              color: _isLocked ? _TogetherTokens.budgetGold : Colors.white,
            ),
            label: Text(
              _isLocked
                  ? (currentBudget > 0 ? 'Target Locked' : 'Plan Locked')
                  : (currentBudget > 0 ? 'Adjust Target' : 'Set Target'),
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.w700,
                fontSize: 13,
                color: _isLocked ? _TogetherTokens.budgetGold : Colors.white,
              ),
            ),
            style: FilledButton.styleFrom(
              backgroundColor: _isLocked
                  ? tokens.tint(_TogetherTokens.budgetGold, 0.14)
                  : _TogetherTokens.budgetGold,
              foregroundColor:
                  _isLocked ? _TogetherTokens.budgetGold : Colors.white,
              side: _isLocked
                  ? BorderSide(
                      color:
                          _TogetherTokens.budgetGold.withValues(alpha: 0.45),
                      width: 1.0,
                    )
                  : null,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 0,
            ),
          ),
        ),
        if (canReset) ...<Widget>[
          const SizedBox(width: 10),
          // Reset Today Button: Solid Dark Red (#991B1B) when unlocked, Tonal Locked when locked
          Expanded(
            child: FilledButton.icon(
              onPressed: () => _confirmResetTodayBudget(context, tokens),
              icon: Icon(
                _isLocked ? Icons.lock_rounded : Icons.restart_alt_rounded,
                size: 15,
                color: _isLocked ? _TogetherTokens.spentRed : Colors.white,
              ),
              label: Text(
                _isLocked ? 'Reset (Locked)' : 'Reset Today',
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  color: _isLocked ? _TogetherTokens.spentRed : Colors.white,
                ),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: _isLocked
                    ? tokens.tint(_TogetherTokens.spentRed, 0.14)
                    : _TogetherTokens.spentRed,
                foregroundColor:
                    _isLocked ? _TogetherTokens.spentRed : Colors.white,
                side: _isLocked
                    ? BorderSide(
                        color: _TogetherTokens.spentRed.withValues(alpha: 0.45),
                        width: 1.0,
                      )
                    : null,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
            ),
          ),
        ],
      ],
    );
  }


  /// Confirm and reset today's shared budget plan back to ₱0
  void _confirmResetTodayBudget(BuildContext context, _TogetherTokens tokens) {
    if (_isLocked) {
      HapticFeedback.lightImpact();
      showAppAlert(context, message: 'Together plan is locked. Toggle switch above to unlock before resetting.', title: 'Alert', icon: Icons.warning_amber_rounded,

        accentColor: _TogetherTokens.spentRed,

      );
      return;
    }

    showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: tokens.cardBg,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: tokens.cardBorder),
          ),
          icon: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: tokens.tint(_TogetherTokens.spentRed, 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.restart_alt_rounded,
              color: _TogetherTokens.spentRed,
              size: 32,
            ),
          ),
          title: Text(
            "Reset Today's Budget Plan?",
            textAlign: TextAlign.center,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: tokens.textPrimary,
              letterSpacing: -0.4,
            ),
          ),
          content: Text(
            "This will reset today's shared target back to ₱0.00, clear today's shared expenses, and unlock the plan so you can configure a fresh budget.",
            textAlign: TextAlign.center,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13,
              color: tokens.textSecondary,
              height: 1.4,
            ),
          ),
          actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          actions: <Widget>[
            Row(
              children: <Widget>[
                // Cancel
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(dialogContext).pop(),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      side: BorderSide(color: tokens.cardBorder),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      'Cancel',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: tokens.textSecondary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                // Reset Button (Solid Dark Red #991B1B)
                Expanded(
                  child: FilledButton(
                    onPressed: () {
                      Navigator.of(dialogContext).pop();
                      final DateTime currentClock = ref
                          .read(budgetBuddyControllerProvider.notifier)
                          .currentEffectiveTime;
                      final BudgetBuddyState currentState =
                          ref.read(budgetBuddyControllerProvider);
                      final List<ExpenseEntry> todayShared =
                          currentState.expenses.where((ExpenseEntry e) {
                        return e.source == 'togetherSpend' &&
                            DateUtils.isSameDay(e.dateTime, currentClock);
                      }).toList();
                      if (todayShared.isNotEmpty) {
                        ref
                            .read(budgetBuddyControllerProvider.notifier)
                            .deleteExpenses(
                              todayShared.map((ExpenseEntry e) => e.id),
                            );
                      }
                      ref
                          .read(budgetBuddyControllerProvider.notifier)
                          .setTogetherBudget(0.0);
                      _setLockState(false);
                      showAppAlert(context, message: "Today's shared budget plan has been reset to ₱0.00.", title: 'Alert', icon: Icons.warning_amber_rounded,

                        accentColor: _TogetherTokens.spentRed,

                      );
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: _TogetherTokens.spentRed,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      'Reset Plan',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  void _showAdjustTargetSheet(
    BuildContext context,
    double currentBudget,
    _TogetherTokens tokens,
  ) {
    if (_isLocked) {
      HapticFeedback.lightImpact();
      showAppAlert(context, message: 'Together plan is locked. Toggle switch above to unlock and adjust target.', title: 'Notice', icon: Icons.info_outline_rounded,

        accentColor: _TogetherTokens.budgetGold,

      );
      return;
    }

    final TextEditingController ctrl = TextEditingController(
      text: currentBudget > 0 ? currentBudget.toStringAsFixed(0) : '',
    );

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: tokens.cardBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (BuildContext sheetContext) {
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              20,
              12,
              20,
              MediaQuery.of(sheetContext).viewInsets.bottom + 20,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: tokens.cardBorder,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                Text(
                  'Set Together Daily Target',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: tokens.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Enter the shared daily allowance limit for offline together spending.',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    color: tokens.textSecondary,
                  ),
                ),
                const SizedBox(height: 14),

                TextField(
                  controller: ctrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: _TogetherTokens.budgetGold,
                  ),
                  decoration: InputDecoration(
                    labelText: "Today's Together Target",
                    prefixText: '₱ ',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: tokens.cardBorder),
                    ),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 16),

                // Save Target Button (Solid Gold #D97706)
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () {
                      final double? val = double.tryParse(ctrl.text.trim());
                      if (val == null || val <= 0) return;

                      ref
                          .read(budgetBuddyControllerProvider.notifier)
                          .setTogetherBudget(val);
                      _setLockState(true);
                      Navigator.of(sheetContext).pop();
                      showAppAlert(context,
                        message: 'Together target locked at ${formatPeso(val)}!',
                        title: 'Notice',
                        icon: Icons.info_outline_rounded,
                        accentColor: _TogetherTokens.budgetGold,
                      );
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: _TogetherTokens.budgetGold,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      'Lock & Save Target',
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),

                if (currentBudget > 0) ...<Widget>[
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: TextButton.icon(
                      onPressed: () {
                        Navigator.of(sheetContext).pop();
                        _confirmResetTodayBudget(context, tokens);
                      },
                      icon: const Icon(
                        Icons.restart_alt_rounded,
                        size: 15,
                        color: _TogetherTokens.spentRed,
                      ),
                      label: Text(
                        "Reset Today's Budget to ₱0",
                        style: GoogleFonts.plusJakartaSans(
                          color: _TogetherTokens.spentRed,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}





