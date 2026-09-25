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
  Color get keyTileBg =>
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
        ref.watch(budgetBuddyControllerProvider).effectiveDate;
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
    final bool isOver = hasBudget && remaining < 0;
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
                        !hasBudget
                            ? 'Remaining'
                            : (isOver ? 'Deficit' : 'Safe Remaining'),
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: tokens.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        !hasBudget
                            ? formatPeso(0)
                            : ((isOver ? '-' : '') + formatPeso(remaining.abs())),
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: !hasBudget
                              ? _TogetherTokens.budgetGold
                              : (isOver
                                  ? _TogetherTokens.spentRed
                                  : _TogetherTokens.safeGreen),
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
                !hasBudget
                    ? 'No limit set'
                    : (isOver
                        ? 'Exceeded by ${formatPeso(remaining.abs())}'
                        : '${formatPeso(remaining > 0 ? remaining : 0)} safe balance'),
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  color: !hasBudget
                      ? _TogetherTokens.budgetGold
                      : (isOver
                          ? _TogetherTokens.spentRed
                          : _TogetherTokens.safeGreen),
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
  String _rawInput = '';

  double get _currentAmount => double.tryParse(_rawInput) ?? 0.0;

  String _displayAmount() {
    if (_rawInput.isEmpty) return '0.00';
    if (_rawInput.contains('.')) {
      final List<String> parts = _rawInput.split('.');
      final double whole = double.tryParse(parts[0]) ?? 0;
      final String wholeFormatted = NumberFormat('#,##0').format(whole);
      return '$wholeFormatted.${parts[1]}';
    } else {
      final double whole = double.tryParse(_rawInput) ?? 0;
      return NumberFormat('#,##0').format(whole);
    }
  }

  void _onKeypadTap(String value) {
    HapticFeedback.lightImpact();
    setState(() {
      if (value == '.') {
        if (_rawInput.isEmpty) {
          _rawInput = '0.';
        } else if (!_rawInput.contains('.')) {
          _rawInput += '.';
        }
      } else if (value == '00') {
        if (_rawInput.isEmpty || _rawInput == '0') {
          return;
        }
        if (_rawInput.contains('.')) {
          final List<String> parts = _rawInput.split('.');
          if (parts[1].isEmpty) {
            _rawInput += '00';
          } else if (parts[1].length == 1) {
            _rawInput += '0';
          }
        } else {
          if (_rawInput.length <= 8) {
            _rawInput += '00';
          }
        }
      } else {
        if (_rawInput == '0') {
          _rawInput = value;
        } else if (_rawInput.contains('.')) {
          final List<String> parts = _rawInput.split('.');
          if (parts[1].length < 2) {
            _rawInput += value;
          }
        } else {
          if (_rawInput.length < 9) {
            _rawInput += value;
          }
        }
      }
    });
  }

  void _onBackspace() {
    HapticFeedback.lightImpact();
    setState(() {
      if (_rawInput.isNotEmpty) {
        _rawInput = _rawInput.substring(0, _rawInput.length - 1);
        if (_rawInput == '0') {
          _rawInput = '';
        }
      }
    });
  }

  void _onClear() {
    HapticFeedback.mediumImpact();
    setState(() {
      _rawInput = '';
    });
  }

  void _onQuickAddAmount(double amount) {
    HapticFeedback.lightImpact();
    setState(() {
      final double nextAmount = _currentAmount + amount;
      if (nextAmount == nextAmount.roundToDouble()) {
        _rawInput = nextAmount.toStringAsFixed(0);
      } else {
        _rawInput = nextAmount.toStringAsFixed(2);
      }
    });
  }

  void _addBudget() {
    final double amount = _currentAmount;
    if (amount <= 0) {
      showAppAlert(
        context,
        message:
            'Please enter an amount on the keypad greater than ₱0 to add to Shared Budget.',
        title: 'Notice',
        icon: Icons.info_outline_rounded,
      );
      return;
    }

    final BudgetBuddyState state = ref.read(budgetBuddyControllerProvider);
    final double currentBudget = state.togetherBudget;
    final double newTotal = currentBudget + amount;

    ref
        .read(budgetBuddyControllerProvider.notifier)
        .setTogetherBudget(newTotal);

    setState(() {
      _rawInput = '';
    });

    showAppAlert(
      context,
      message: 'Shared budget increased to ${formatPeso(newTotal)}!',
      title: 'Success',
      icon: Icons.check_circle_outline_rounded,
      accentColor: _TogetherTokens.safeGreen,
    );
  }

  void _editBudget() {
    final double amount = _currentAmount;
    if (amount <= 0) {
      showAppAlert(
        context,
        message:
            'Please enter a valid budget amount on the keypad greater than ₱0.',
        title: 'Notice',
        icon: Icons.info_outline_rounded,
      );
      return;
    }

    ref.read(budgetBuddyControllerProvider.notifier).setTogetherBudget(amount);

    setState(() {
      _rawInput = '';
    });

    showAppAlert(
      context,
      message: 'Shared budget set to ${formatPeso(amount)}!',
      title: 'Success',
      icon: Icons.check_circle_outline_rounded,
      accentColor: _TogetherTokens.safeGreen,
    );
  }

  void _confirmResetTodayBudget(
      BuildContext context, _TogetherTokens tokens) {
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
            "Reset Shared Budget Plan?",
            textAlign: TextAlign.center,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: tokens.textPrimary,
              letterSpacing: -0.4,
            ),
          ),
          content: Text(
            "This will reset today's shared target back to ₱0.00 and clear today's shared expenses so you can start fresh.",
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
                      final BudgetBuddyState currentState =
                          ref.read(budgetBuddyControllerProvider);
                      final DateTime currentClock =
                          currentState.effectiveDate;
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
                      setState(() {
                        _rawInput = '';
                      });
                      showAppAlert(
                        context,
                        message:
                            "Today's shared budget plan has been reset to ₱0.00.",
                        title: 'Alert',
                        icon: Icons.warning_amber_rounded,
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

  @override
  Widget build(BuildContext context) {
    final BudgetBuddyState state = ref.watch(budgetBuddyControllerProvider);
    final DateTime currentClock = state.effectiveDate;
    final _TogetherTokens tokens = widget.tokens;

    final double totalBudget = state.togetherBudget;
    final List<ExpenseEntry> todaySharedExpenses =
        state.expenses.where((ExpenseEntry e) {
      if (e.source != 'togetherSpend') return false;
      return DateUtils.isSameDay(e.dateTime, currentClock);
    }).toList();

    final double spent = todaySharedExpenses.fold<double>(
        0.0, (double sum, ExpenseEntry e) => sum + e.amount);
    final double remaining = totalBudget - spent;
    final bool hasBudget = totalBudget > 0;
    final bool isOver = hasBudget && remaining < 0;
    final bool isWarning =
        !isOver && hasBudget && spent >= (totalBudget * 0.8);
    final double progressValue = totalBudget > 0
        ? (spent / totalBudget).clamp(0.0, 1.0)
        : 0.0;

    // Listen to external resets
    ref.listen<BudgetBuddyState>(budgetBuddyControllerProvider,
        (BudgetBuddyState? prev, BudgetBuddyState next) {
      if (next.togetherBudget != prev?.togetherBudget) {
        if (next.togetherBudget <= 0) {
          if (_rawInput.isNotEmpty) {
            setState(() => _rawInput = '');
          }
        }
      }
    });

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      children: <Widget>[
        // 1. Header Row: Title, Date & Status Pill
        _buildHeader(
          currentClock: currentClock,
          hasBudget: hasBudget,
          tokens: tokens,
        ),
        const SizedBox(height: 12),

        // 2. Hero Budget Card (Remaining displayed in hero display; no duplicate cards)
        _buildHeroBudgetCard(
          totalBudget: totalBudget,
          spent: spent,
          remaining: remaining,
          progressValue: progressValue,
          hasBudget: hasBudget,
          isOver: isOver,
          isWarning: isWarning,
          tokens: tokens,
        ),
        const SizedBox(height: 12),

        // 3. Action Buttons (Add Budget, Edit Budget, Reset)
        _buildActionButtons(
          tokens: tokens,
        ),
        const SizedBox(height: 10),

        // 4. Quick Amount Increments (+₱100, +₱200, +₱300, +₱500, +₱1,000)
        _buildQuickAmountIncrements(tokens),
        const SizedBox(height: 12),

        // 5. Numeric Keypad (Tactile Bento Keypad Tiles)
        _buildNumericKeypad(context, tokens),
        const SizedBox(height: 24),
      ],
    );
  }

  /// 1. Header Section with Title, Formatted Date, and Clean Setup/Plan Pill
  Widget _buildHeader({
    required DateTime currentClock,
    required bool hasBudget,
    required _TogetherTokens tokens,
  }) {
    return Row(
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
        SoftPill(
          text: hasBudget ? 'Active Plan' : 'Setup',
          color: hasBudget
              ? _TogetherTokens.budgetGold
              : _TogetherTokens.safeGreen,
          icon: hasBudget ? Icons.lock_outline_rounded : Icons.edit_rounded,
          fontSize: 11,
        ),
      ],
    );
  }

  /// 2. Hero Budget Card: Shows Safe Remaining when idle, typed input when active, with no duplicate cards
  Widget _buildHeroBudgetCard({
    required double totalBudget,
    required double spent,
    required double remaining,
    required double progressValue,
    required bool hasBudget,
    required bool isOver,
    required bool isWarning,
    required _TogetherTokens tokens,
  }) {
    final bool isTyping = _rawInput.isNotEmpty;

    return BentoCard(
      padding: const EdgeInsets.all(16),
      borderRadius: 20,
      borderColor: isOver
          ? _TogetherTokens.spentRed.withValues(alpha: 0.35)
          : (isTyping
              ? _TogetherTokens.budgetGold.withValues(alpha: 0.45)
              : tokens.cardBorder),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // Top Row: Category / Target Header & Status Pill
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
              Expanded(
                child: Text(
                  isTyping ? 'Shared Budget Input' : 'Today\'s Shared Budget',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: tokens.textPrimary,
                  ),
                ),
              ),
              SoftPill(
                text: !hasBudget
                    ? 'No Plan Set'
                    : (isOver
                        ? 'Over Budget'
                        : (isWarning ? '80% Cap' : 'Active Plan')),
                color: !hasBudget
                    ? _TogetherTokens.budgetGold
                    : (isOver
                        ? _TogetherTokens.spentRed
                        : (isWarning
                            ? _TogetherTokens.budgetGold
                            : _TogetherTokens.safeGreen)),
                icon: !hasBudget
                    ? Icons.info_outline_rounded
                    : (isOver
                        ? Icons.warning_amber_rounded
                        : (isWarning
                            ? Icons.info_outline_rounded
                            : Icons.check_circle_outline_rounded)),
                fontSize: 11,
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Main Hero Amount Display: Shows Remaining (or 0) when idle, or typed input when typing
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    isTyping
                        ? '₱${_displayAmount()}'
                        : (hasBudget
                            ? ((remaining < 0 ? '-' : '') +
                                formatPeso(remaining.abs()))
                            : '₱0.00'),
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 36,
                      fontWeight: FontWeight.w900,
                      color: isTyping
                          ? _TogetherTokens.budgetGold
                          : (!hasBudget
                              ? _TogetherTokens.budgetGold
                              : (isOver
                                  ? _TogetherTokens.spentRed
                                  : _TogetherTokens.safeGreen)),
                      letterSpacing: -1.0,
                    ),
                  ),
                ),
              ),
              if (isTyping)
                IconButton(
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  icon: const Icon(
                    Icons.backspace_outlined,
                    size: 20,
                    color: _TogetherTokens.spentRed,
                  ),
                  onPressed: _onBackspace,
                ),
            ],
          ),
          const SizedBox(height: 2),

          // Context Subtitle below amount
          Text(
            isTyping
                ? 'Tap "Add Budget" to increase or "Edit Budget" to set new target'
                : (!hasBudget
                    ? 'No shared budget set yet. Enter amount on keypad below.'
                    : (isOver
                        ? 'Budget exceeded by ${formatPeso(remaining.abs())}'
                        : 'Safe remaining balance for shared spending')),
            style: GoogleFonts.plusJakartaSans(
              fontSize: 11.5,
              fontWeight: FontWeight.w500,
              color:
                  isOver ? _TogetherTokens.spentRed : tokens.textSecondary,
            ),
          ),
          const SizedBox(height: 12),

          // Compact Budget Breakdown Strip (Target, Spent, Remaining Context)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: tokens.subCardBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: tokens.cardBorder, width: 1.0),
            ),
            child: Column(
              children: <Widget>[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: <Widget>[
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          'Daily Target',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600,
                            color: tokens.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 1),
                        Text(
                          formatPeso(totalBudget),
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: _TogetherTokens.budgetGold,
                          ),
                        ),
                      ],
                    ),
                    Container(height: 20, width: 1, color: tokens.cardBorder),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: <Widget>[
                        Text(
                          'Spent Today',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600,
                            color: tokens.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 1),
                        Text(
                          formatPeso(spent),
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: _TogetherTokens.spentRed,
                          ),
                        ),
                      ],
                    ),
                    Container(height: 20, width: 1, color: tokens.cardBorder),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: <Widget>[
                        Text(
                          'Remaining',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600,
                            color: tokens.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 1),
                        Text(
                          hasBudget
                              ? ((remaining < 0 ? '-' : '') +
                                  formatPeso(remaining.abs()))
                              : '₱0.00',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: !hasBudget
                                ? _TogetherTokens.budgetGold
                                : (isOver
                                    ? _TogetherTokens.spentRed
                                    : _TogetherTokens.safeGreen),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                BentoHealthBar(
                  progress: progressValue,
                  color: isOver
                      ? _TogetherTokens.spentRed
                      : (isWarning
                          ? _TogetherTokens.budgetGold
                          : _TogetherTokens.budgetGold),
                  height: 5,
                ),
              ],
            ),
          ),

          // Overspent Warning Box
          if (isOver) ...<Widget>[
            const SizedBox(height: 10),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: tokens.tint(_TogetherTokens.spentRed, 0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: _TogetherTokens.spentRed.withValues(alpha: 0.25),
                  width: 1.0,
                ),
              ),
              child: Row(
                children: <Widget>[
                  const Icon(
                    Icons.error_outline_rounded,
                    size: 15,
                    color: _TogetherTokens.spentRed,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Budget exceeded by ${formatPeso(remaining.abs())}. Slow down on shared expenses today.',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: _TogetherTokens.spentRed,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// 3. Action Buttons with Solid Dark Green (Add), Solid Gold (Edit), and Solid Dark Red (Reset)
  Widget _buildActionButtons({
    required _TogetherTokens tokens,
  }) {
    return Row(
      children: <Widget>[
        // Add Budget Button (Solid Dark Green #0F766E)
        Expanded(
          child: FilledButton.icon(
            onPressed: _addBudget,
            icon: const Icon(Icons.add_rounded, size: 16, color: Colors.white),
            label: const Text('Add Budget'),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(44),
              backgroundColor: _TogetherTokens.safeGreen,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 4),
              textStyle: GoogleFonts.plusJakartaSans(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        // Edit Budget Button (Solid Gold #D97706)
        Expanded(
          child: FilledButton.icon(
            onPressed: _editBudget,
            icon: const Icon(Icons.edit_rounded, size: 15, color: Colors.white),
            label: const Text('Edit Budget'),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(44),
              backgroundColor: _TogetherTokens.budgetGold,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 4),
              textStyle: GoogleFonts.plusJakartaSans(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        // Reset Button (Solid Dark Red #991B1B)
        Expanded(
          child: FilledButton.icon(
            onPressed: () => _confirmResetTodayBudget(context, tokens),
            icon: const Icon(Icons.restart_alt_rounded,
                size: 15, color: Colors.white),
            label: const Text('Reset'),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(44),
              backgroundColor: _TogetherTokens.spentRed,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 4),
              textStyle: GoogleFonts.plusJakartaSans(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// 4. Quick Amount Increments (+₱100, +₱200, +₱300, +₱500, +₱1,000)
  Widget _buildQuickAmountIncrements(_TogetherTokens tokens) {
    const List<double> increments = <double>[100, 200, 300, 500, 1000];

    return Row(
      children: increments.map((double amount) {
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => _onQuickAddAmount(amount),
                borderRadius: BorderRadius.circular(999),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 7),
                  decoration: BoxDecoration(
                    color: tokens.cardBg,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: tokens.cardBorder, width: 1.0),
                  ),
                  child: Center(
                    child: Text(
                      '+₱${amount.toInt()}',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: _TogetherTokens.budgetGold,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  /// 5. Custom Flat Numeric Keypad (Tactile Bento Keypad Tiles)
  Widget _buildNumericKeypad(
      BuildContext context, _TogetherTokens tokens) {
    return Column(
      children: <Widget>[
        // Row 1: 1, 2, 3
        Row(
          children: <Widget>[
            _buildKeyTile('1', tokens),
            const SizedBox(width: 8),
            _buildKeyTile('2', tokens),
            const SizedBox(width: 8),
            _buildKeyTile('3', tokens),
          ],
        ),
        const SizedBox(height: 8),

        // Row 2: 4, 5, 6
        Row(
          children: <Widget>[
            _buildKeyTile('4', tokens),
            const SizedBox(width: 8),
            _buildKeyTile('5', tokens),
            const SizedBox(width: 8),
            _buildKeyTile('6', tokens),
          ],
        ),
        const SizedBox(height: 8),

        // Row 3: 7, 8, 9
        Row(
          children: <Widget>[
            _buildKeyTile('7', tokens),
            const SizedBox(width: 8),
            _buildKeyTile('8', tokens),
            const SizedBox(width: 8),
            _buildKeyTile('9', tokens),
          ],
        ),
        const SizedBox(height: 8),

        // Row 4: . , 0 , 00
        Row(
          children: <Widget>[
            _buildKeyTile('.', tokens),
            const SizedBox(width: 8),
            _buildKeyTile('0', tokens),
            const SizedBox(width: 8),
            _buildKeyTile('00', tokens),
          ],
        ),
        const SizedBox(height: 8),

        // Row 5: Clear and Backspace
        Row(
          children: <Widget>[
            // Clear Key (C)
            Expanded(
              child: _buildActionKeyTile(
                label: 'C',
                color: _TogetherTokens.spentRed,
                onTap: _onClear,
                tokens: tokens,
              ),
            ),
            const SizedBox(width: 8),
            // Backspace Key
            Expanded(
              child: _buildActionKeyTile(
                icon: Icons.backspace_outlined,
                color: tokens.textSecondary,
                onTap: _onBackspace,
                tokens: tokens,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildKeyTile(String value, _TogetherTokens tokens) {
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _onKeypadTap(value),
          borderRadius: BorderRadius.circular(16),
          child: Container(
            height: 52,
            decoration: BoxDecoration(
              color: tokens.keyTileBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: tokens.cardBorder, width: 1.0),
            ),
            child: Center(
              child: Text(
                value,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: tokens.textPrimary,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionKeyTile({
    String? label,
    IconData? icon,
    required Color color,
    required VoidCallback onTap,
    required _TogetherTokens tokens,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          height: 52,
          decoration: BoxDecoration(
            color: tokens.cardBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: tokens.cardBorder, width: 1.0),
          ),
          child: Center(
            child: icon != null
                ? Icon(icon, size: 20, color: color)
                : Text(
                    label ?? '',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: color,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}





