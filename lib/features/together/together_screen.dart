import 'dart:async';
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
              _TogetherBudgetPlanView(
                tokens: tokens,
                onOpenSavings: () => setState(() => _selectedModuleIndex = 3),
              ),
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

    final Color moduleColor = switch (_selectedModuleIndex) {
      0 => _TogetherTokens.budgetGold,
      1 => _TogetherTokens.budgetGold,
      2 => _TogetherTokens.spentRed,
      3 => _TogetherTokens.safeGreen,
      _ => _TogetherTokens.budgetGold,
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
                  color: moduleColor,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: moduleColor.withValues(alpha: 0.35),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    const Icon(
                      Icons.arrow_back_rounded,
                      size: 16,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Back to List',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
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
    this.onOpenSavings,
    super.key,
  });

  final _TogetherTokens tokens;
  final VoidCallback? onOpenSavings;

  @override
  ConsumerState<_TogetherBudgetPlanView> createState() =>
      _TogetherBudgetPlanViewState();
}

class _TogetherBudgetPlanViewState
    extends ConsumerState<_TogetherBudgetPlanView> {
  late final TextEditingController _dailyController;
  final FocusNode _focusNode = FocusNode();
  bool _isInputActive = false;
  bool _isAddMode = false;
  double? _lastAddBase;
  double? _lastAddAmount;
  DateTime? _lastAddDate;

  @override
  void initState() {
    super.initState();
    _dailyController = TextEditingController();
  }

  @override
  void dispose() {
    _dailyController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onQuickAddAmount(double amount) {
    if (!_isInputActive) return;
    HapticFeedback.lightImpact();
    setState(() {
      final bool isAllSelected = _dailyController.selection.start == 0 &&
          _dailyController.selection.end == _dailyController.text.length &&
          _dailyController.text.isNotEmpty;

      double nextAmount;
      if (isAllSelected) {
        nextAmount = amount;
      } else {
        final double currentVal =
            double.tryParse(_dailyController.text.trim()) ?? 0.0;
        nextAmount = currentVal + amount;
      }
      _dailyController.text = nextAmount == nextAmount.roundToDouble()
          ? nextAmount.toStringAsFixed(0)
          : nextAmount.toStringAsFixed(2);
      _dailyController.selection = TextSelection.collapsed(
        offset: _dailyController.text.length,
      );
    });
    _focusNode.requestFocus();
  }

  void _startAddBudget() {
    HapticFeedback.lightImpact();
    setState(() {
      _isInputActive = true;
      _isAddMode = true;
      _dailyController.clear();
    });
    _focusNode.requestFocus();
  }

  void _startEditBudget(double currentBudget) {
    HapticFeedback.lightImpact();
    setState(() {
      _isInputActive = true;
      _isAddMode = false;
      _dailyController.text =
          currentBudget > 0 ? currentBudget.toStringAsFixed(0) : '';
      _dailyController.selection = TextSelection(
        baseOffset: 0,
        extentOffset: _dailyController.text.length,
      );
    });
    _focusNode.requestFocus();
  }

  void _cancelInput() {
    HapticFeedback.lightImpact();
    _focusNode.unfocus();
    setState(() {
      _isInputActive = false;
      _isAddMode = false;
      _dailyController.clear();
    });
  }

  Future<void> _saveBudget() async {
    final String text = _dailyController.text.trim();
    final double? entered = double.tryParse(text);
    if (entered == null || entered <= 0) {
      showAppAlert(
        context,
        message: 'Please enter a valid budget amount greater than ₱0.',
        title: 'Notice',
        icon: Icons.info_outline_rounded,
      );
      return;
    }

    final BudgetBuddyState state = ref.read(budgetBuddyControllerProvider);
    final double currentBudget = state.togetherBudget;
    final double target = _isAddMode ? (currentBudget + entered) : entered;
    final bool wasAddMode = _isAddMode;

    if (wasAddMode) {
      if (currentBudget > 0) {
        final bool? confirmed = await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (BuildContext ctx) => _CountdownConfirmationDialog(
            title: 'Confirm Add Budget',
            message:
                'Add ${formatPeso(entered)} to today\'s shared budget of ${formatPeso(currentBudget)} for a new total of ${formatPeso(target)}?',
            confirmLabel: 'Save & Add',
            confirmColor: _TogetherTokens.safeGreen,
            icon: Icons.add_circle_outline_rounded,
            autoConfirm: false,
            totalSeconds: 3,
          ),
        );
        if (!mounted || confirmed != true) return;
      }
      if (!mounted) return;

      if (currentBudget > 0) {
        ref
            .read(budgetBuddyControllerProvider.notifier)
            .addTogetherDailyBudget(addedAmount: entered);
      } else {
        ref
            .read(budgetBuddyControllerProvider.notifier)
            .setTogetherBudget(target);
      }
    } else {
      if (currentBudget > 0) {
        final bool? confirmed = await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (BuildContext ctx) => _CountdownConfirmationDialog(
            title: 'Confirm Budget Update',
            message:
                'Update today\'s shared budget from ${formatPeso(currentBudget)} to ${formatPeso(target)}?',
            confirmLabel: 'Update Now',
            confirmColor: _TogetherTokens.safeGreen,
            icon: Icons.sync_rounded,
            autoConfirm: false,
            totalSeconds: 3,
          ),
        );
        if (!mounted || confirmed != true) return;
      }
      if (!mounted) return;

      ref
          .read(budgetBuddyControllerProvider.notifier)
          .setTogetherBudget(target);
    }

    _focusNode.unfocus();

    setState(() {
      _isInputActive = false;
      _isAddMode = false;
      _dailyController.clear();
      if (wasAddMode && currentBudget > 0) {
        final BudgetBuddyState currentState =
            ref.read(budgetBuddyControllerProvider);
        _lastAddBase = currentState.togetherLastAddBase ?? currentBudget;
        _lastAddAmount =
            (currentState.togetherLastAddAmount ?? 0.0) + entered;
        _lastAddDate = ref.read(budgetBuddyControllerProvider.notifier).now;
      } else {
        _lastAddBase = null;
        _lastAddAmount = null;
        _lastAddDate = null;
      }
    });

    showAppAlert(
      context,
      message: wasAddMode
          ? 'Shared budget increased to ${formatPeso(target)}!'
          : 'Shared budget set to ${formatPeso(target)}!',
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
                        _isInputActive = false;
                        _isAddMode = false;
                        _dailyController.clear();
                        _lastAddBase = null;
                        _lastAddAmount = null;
                        _lastAddDate = null;
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

    final double addBase = state.togetherLastAddBase ?? _lastAddBase ?? 0.0;
    final double addAmount =
        state.togetherLastAddAmount ?? _lastAddAmount ?? 0.0;
    final DateTime? addDate = state.togetherLastAddDate ?? _lastAddDate;
    final bool hasAddToday = (state.togetherLastAddDebtAbsorbed != null &&
            state.togetherLastAddDebtAbsorbed! > 0) ||
        (addBase > 0 &&
            addAmount > 0 &&
            addDate != null &&
            DateUtils.isSameDay(addDate, currentClock));

    final double todayPaidDebt = state.vaultLog
        .where((VaultLogEntry log) =>
            log.type == VaultLogType.payDebt &&
            (log.isTogether == true ||
                log.description.toLowerCase().contains('together')) &&
            log.description.toLowerCase().contains('deficit payment') &&
            DateUtils.isSameDay(log.dateTime, currentClock))
        .fold(0.0, (double sum, VaultLogEntry log) => sum + log.amount);

    final double rawOverbudgetDebt = hasAddToday
        ? ((state.togetherLastAddDebtAbsorbed ?? 0.0) +
            (totalBudget > 0 && spent > totalBudget
                ? (spent - totalBudget)
                : 0.0))
        : (totalBudget > 0
            ? (spent - totalBudget).clamp(0.0, double.infinity)
            : spent);

    final double overbudgetDebt =
        (rawOverbudgetDebt - todayPaidDebt).clamp(0.0, double.infinity);

    final double effectiveDebt = overbudgetDebt;

    // Listen to external resets
    ref.listen<BudgetBuddyState>(budgetBuddyControllerProvider,
        (BudgetBuddyState? prev, BudgetBuddyState next) {
      if (next.togetherBudget != prev?.togetherBudget) {
        if (next.togetherBudget <= 0) {
          if (_dailyController.text.isNotEmpty || _isInputActive) {
            setState(() {
              _isInputActive = false;
              _isAddMode = false;
              _dailyController.clear();
            });
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

        // 2. Hero Budget Card (Remaining displayed when idle, text input when active)
        _buildHeroBudgetCard(
          totalBudget: totalBudget,
          spent: spent,
          remaining: remaining,
          progressValue: progressValue,
          hasBudget: hasBudget,
          isOver: isOver,
          isWarning: isWarning,
          savingsDebt: effectiveDebt,
          tokens: tokens,
        ),
        const SizedBox(height: 12),

        // 2b. Standalone Over Budget Debt Card (shown separately when debt exists)
        if (effectiveDebt > 0) ...<Widget>[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: tokens.tint(_TogetherTokens.spentRed, 0.07),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _TogetherTokens.spentRed.withValues(alpha: 0.30),
                width: 1.2,
              ),
            ),
            child: Row(
              children: <Widget>[
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _TogetherTokens.spentRed.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.account_balance_wallet_rounded,
                      size: 18, color: _TogetherTokens.spentRed),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'Over Budget Debt',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: _TogetherTokens.spentRed,
                          letterSpacing: 0.3,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        formatPeso(effectiveDebt),
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: _TogetherTokens.spentRed,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Debt is separate from your shared budget and can only be paid in Savings.',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                          color: tokens.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () {
                    widget.onOpenSavings?.call();
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 7),
                    decoration: BoxDecoration(
                      color: _TogetherTokens.spentRed,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        const Icon(Icons.savings_rounded,
                            size: 14, color: Colors.white),
                        const SizedBox(height: 2),
                        Text(
                          'Pay in Savings',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
        ],

        // 2c. Today's Budget Added Card (only shows for today's add, clears at midnight)
        if (hasAddToday &&
            (addBase > 0 ||
                (state.togetherLastAddDebtAbsorbed ?? 0) > 0)) ...<Widget>[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: tokens.tint(_TogetherTokens.safeGreen, 0.07),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _TogetherTokens.safeGreen.withValues(alpha: 0.28),
                width: 1.2,
              ),
            ),
            child: Row(
              children: <Widget>[
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _TogetherTokens.safeGreen.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.add_circle_rounded,
                      size: 18, color: _TogetherTokens.safeGreen),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'Budget Added Today',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: _TogetherTokens.safeGreen,
                          letterSpacing: 0.3,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${formatPeso(addBase)} + ${formatPeso(addAmount)} = ${formatPeso(addBase + addAmount)}',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: tokens.textPrimary,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Added ${formatPeso(addAmount)} to shared daily budget.',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 10.5,
                          color: tokens.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
        ],

        // 3. Action Buttons (Cancel / Save when input is active; Add, Edit, Reset when idle)
        _buildActionButtons(
          totalBudget: totalBudget,
          hasBudget: hasBudget,
          tokens: tokens,
        ),
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
    required double savingsDebt,
    required _TogetherTokens tokens,
  }) {
    final bool isTyping = _isInputActive;

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
                  isTyping
                      ? (_isAddMode
                          ? 'Add to Shared Budget'
                          : 'Edit Target Shared Budget')
                      : 'Today\'s Shared Budget',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: tokens.textPrimary,
                  ),
                ),
              ),
              SoftPill(
                text: isTyping
                    ? (_isAddMode ? 'Adding' : 'Editing')
                    : (!hasBudget
                        ? 'No Plan Set'
                        : (isOver
                            ? 'Over Budget'
                            : (isWarning ? '80% Cap' : 'Active Plan'))),
                color: isTyping
                    ? _TogetherTokens.budgetGold
                    : (!hasBudget
                        ? _TogetherTokens.budgetGold
                        : (isOver
                            ? _TogetherTokens.spentRed
                            : (isWarning
                                ? _TogetherTokens.budgetGold
                                : _TogetherTokens.safeGreen))),
                icon: isTyping
                    ? Icons.edit_rounded
                    : (!hasBudget
                        ? Icons.info_outline_rounded
                        : (isOver
                            ? Icons.warning_amber_rounded
                            : (isWarning
                                ? Icons.info_outline_rounded
                                : Icons.check_circle_outline_rounded))),
                fontSize: 11,
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Main Hero Amount Display: Shows Remaining when idle, or TextField when active
          if (isTyping)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                if (_isAddMode && totalBudget > 0) ...<Widget>[
                  RichText(
                    text: TextSpan(
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.2,
                      ),
                      children: <InlineSpan>[
                        TextSpan(
                          text: '${totalBudget == totalBudget.roundToDouble() ? totalBudget.toStringAsFixed(0) : totalBudget.toStringAsFixed(2)}',
                          style: TextStyle(color: tokens.textSecondary),
                        ),
                        TextSpan(text: '  +  ', style: TextStyle(color: tokens.textMuted)),
                        TextSpan(
                          text: _dailyController.text.isEmpty ? '0' : _dailyController.text,
                          style: const TextStyle(color: _TogetherTokens.budgetGold),
                        ),
                        TextSpan(text: '  =  ', style: TextStyle(color: tokens.textMuted)),
                        TextSpan(
                          text: '${(totalBudget + (double.tryParse(_dailyController.text.trim()) ?? 0.0)).toStringAsFixed(0)}',
                          style: const TextStyle(color: _TogetherTokens.safeGreen),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                ],
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: <Widget>[
                    Expanded(
                      child: TextField(
                        controller: _dailyController,
                        focusNode: _focusNode,
                        keyboardType:
                            const TextInputType.numberWithOptions(decimal: true),
                        inputFormatters: <TextInputFormatter>[
                          FilteringTextInputFormatter.allow(
                              RegExp(r'^\d*\.?\d{0,2}')),
                        ],
                        autofocus: true,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 34,
                          fontWeight: FontWeight.w900,
                          color: _TogetherTokens.budgetGold,
                          letterSpacing: -0.8,
                        ),
                        decoration: InputDecoration(
                          prefixText: '₱ ',
                          prefixStyle: GoogleFonts.plusJakartaSans(
                            fontSize: 34,
                            fontWeight: FontWeight.w900,
                            color: tokens.textSecondary,
                            letterSpacing: -0.8,
                          ),
                          hintText: '0',
                          hintStyle: GoogleFonts.plusJakartaSans(
                            fontSize: 34,
                            fontWeight: FontWeight.w900,
                            color: _TogetherTokens.budgetGold.withValues(alpha: 0.35),
                            letterSpacing: -0.8,
                          ),
                          isDense: true,
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.zero,
                        ),
                        onChanged: (_) => setState(() {}),
                        onSubmitted: (_) => _saveBudget(),
                      ),
                    ),
                    if (_dailyController.text.isNotEmpty)
                      GestureDetector(
                        onTap: () {
                          setState(() { _dailyController.clear(); });
                          _focusNode.requestFocus();
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: _TogetherTokens.spentRed.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: _TogetherTokens.spentRed.withValues(alpha: 0.35), width: 1.0),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              const Icon(Icons.close_rounded, size: 13, color: _TogetherTokens.spentRed),
                              const SizedBox(width: 3),
                              Text('Clear', style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.w700, color: _TogetherTokens.spentRed)),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            )
          else
            InkWell(
              onTap: () {
                setState(() {
                  _lastAddBase = null;
                  _lastAddAmount = null;
                });
                _startEditBudget(totalBudget);
              },
              borderRadius: BorderRadius.circular(12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: <Widget>[
                  Expanded(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        hasBudget
                            ? ((remaining < 0 ? '-' : '') +
                                formatPeso(remaining.abs()))
                            : '₱0.00',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 36,
                          fontWeight: FontWeight.w900,
                          color: !hasBudget
                              ? _TogetherTokens.budgetGold
                              : (isOver
                                  ? _TogetherTokens.spentRed
                                  : _TogetherTokens.safeGreen),
                          letterSpacing: -1.0,
                        ),
                      ),
                    ),
                  ),
                  Icon(
                    Icons.edit_rounded,
                    size: 18,
                    color: tokens.textMuted.withValues(alpha: 0.6),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 2),

          // Context Subtitle below amount
          Text(
            isTyping
                ? (_isAddMode
                    ? (totalBudget > 0
                        ? 'Adding ₱${(double.tryParse(_dailyController.text.trim()) ?? 0.0).toStringAsFixed(0)} to shared budget of ${formatPeso(totalBudget)} (Total: ${formatPeso(totalBudget + (double.tryParse(_dailyController.text.trim()) ?? 0.0))})'
                        : 'Enter amount for shared budget')
                    : 'Enter new target shared budget for today')
                : (!hasBudget
                    ? 'No shared budget set yet. Tap "Add Budget" below.'
                    : (isOver
                        ? 'Budget exceeded by ${formatPeso(remaining.abs())}'
                        : (savingsDebt > 0
                            ? 'Can spend overbudget: ${formatPeso(remaining)}'
                            : 'Safe remaining balance for shared spending'))),
            style: GoogleFonts.plusJakartaSans(
              fontSize: 11.5,
              fontWeight: FontWeight.w500,
              color:
                  isOver ? _TogetherTokens.spentRed : tokens.textSecondary,
            ),
          ),

          // Quick Amount Increments (Only shown when user taps Add Budget or Edit Budget)
          if (isTyping) ...<Widget>[
            const SizedBox(height: 10),
            _buildQuickAmountIncrements(tokens),
          ],
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

  /// 3. Action Buttons: Cancel & Save when typing; Add Budget, Edit Budget, Reset when idle
  Widget _buildActionButtons({
    required double totalBudget,
    required bool hasBudget,
    required _TogetherTokens tokens,
  }) {
    if (_isInputActive) {
      final double entered = double.tryParse(_dailyController.text.trim()) ?? 0.0;
      final bool showEquation = _isAddMode && totalBudget > 0;
      return Column(
        children: <Widget>[
          if (showEquation) ...<Widget>[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: tokens.tint(_TogetherTokens.safeGreen, 0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _TogetherTokens.safeGreen.withValues(alpha: 0.3), width: 1.0),
              ),
              child: Text(
                '${totalBudget == totalBudget.roundToDouble() ? totalBudget.toStringAsFixed(0) : totalBudget.toStringAsFixed(2)} + ${entered == entered.roundToDouble() ? entered.toStringAsFixed(0) : entered.toStringAsFixed(2)} = ${(totalBudget + entered) == (totalBudget + entered).roundToDouble() ? (totalBudget + entered).toStringAsFixed(0) : (totalBudget + entered).toStringAsFixed(2)}',
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: _TogetherTokens.safeGreen,
                  letterSpacing: -0.3,
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
          Row(
            children: <Widget>[
              // Cancel Button (Solid Dark Red #991B1B)
              Expanded(
                child: FilledButton.icon(
                  onPressed: _cancelInput,
                  icon: const Icon(Icons.close_rounded, size: 16, color: Colors.white),
                  label: const Text('Cancel'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(46),
                    backgroundColor: _TogetherTokens.spentRed,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    textStyle: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              // Save Button (Solid Dark Green #0F766E)
              Expanded(
                child: FilledButton.icon(
                  onPressed: _saveBudget,
                  icon: const Icon(Icons.check_rounded, size: 16, color: Colors.white),
                  label: Text(_isAddMode ? 'Save & Add' : 'Save Budget'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(46),
                    backgroundColor: _TogetherTokens.safeGreen,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    textStyle: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      );
    }

    return Row(
      children: <Widget>[
        // Add Budget Button (Solid Dark Green #0F766E)
        Expanded(
          child: FilledButton.icon(
            onPressed: _startAddBudget,
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
            onPressed: () => _startEditBudget(totalBudget),
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
}

/// A clean modal confirmation dialog with countdown timer and GoogleFonts.plusJakartaSans
class _CountdownConfirmationDialog extends StatefulWidget {
  const _CountdownConfirmationDialog({
    required this.title,
    required this.message,
    required this.confirmLabel,
    required this.confirmColor,
    required this.icon,
    this.autoConfirm = false,
    this.totalSeconds = 3,
  });

  final String title;
  final String message;
  final String confirmLabel;
  final Color confirmColor;
  final IconData icon;
  final bool autoConfirm;
  final int totalSeconds;

  @override
  State<_CountdownConfirmationDialog> createState() =>
      _CountdownConfirmationDialogState();
}

class _CountdownConfirmationDialogState
    extends State<_CountdownConfirmationDialog> {
  late int _secondsRemaining;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _secondsRemaining = widget.totalSeconds;
    _startCountdown();
  }

  void _startCountdown() {
    _timer = Timer.periodic(const Duration(seconds: 1), (Timer timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_secondsRemaining <= 1) {
        timer.cancel();
        setState(() {
          _secondsRemaining = 0;
        });
        if (widget.autoConfirm) {
          Navigator.of(context).pop(true);
        }
      } else {
        setState(() {
          _secondsRemaining--;
        });
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color cardBg =
        isDark ? const Color(0xFF111827) : const Color(0xFFFFFFFF);
    final Color cardBorder =
        isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0);
    final Color textPrimary =
        isDark ? const Color(0xFFF1F5F9) : const Color(0xFF0F172A);
    final Color textSecondary =
        isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final double progress = widget.totalSeconds > 0
        ? (_secondsRemaining / widget.totalSeconds)
        : 0.0;

    return AlertDialog(
      backgroundColor: cardBg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: cardBorder, width: 1.0),
      ),
      titlePadding: const EdgeInsets.fromLTRB(18, 18, 18, 6),
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
      actionsPadding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
      title: Row(
        children: <Widget>[
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: widget.confirmColor.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(widget.icon, color: widget.confirmColor, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              widget.title,
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.w800,
                fontSize: 16,
                color: textPrimary,
              ),
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 320,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              widget.message,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: textSecondary,
              ),
            ),
            const SizedBox(height: 12),
            BentoHealthBar(
              progress: progress,
              color: widget.confirmColor,
              height: 5,
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Text(
                  _secondsRemaining > 0
                      ? 'Timer: $_secondsRemaining s'
                      : 'Timer done. Ready to confirm.',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: widget.confirmColor,
                  ),
                ),
                Icon(
                  _secondsRemaining > 0
                      ? Icons.timer_outlined
                      : Icons.touch_app_rounded,
                  size: 13,
                  color: widget.confirmColor,
                ),
              ],
            ),
          ],
        ),
      ),
      actions: <Widget>[
        // Solid Red Cancel Button
        FilledButton.icon(
          onPressed: () {
            _timer?.cancel();
            Navigator.of(context).pop(false);
          },
          icon: const Icon(Icons.close_rounded, size: 14, color: Colors.white),
          label: Text(
            'Cancel',
            style: GoogleFonts.plusJakartaSans(
              fontWeight: FontWeight.w700,
              color: Colors.white,
              fontSize: 12,
            ),
          ),
          style: FilledButton.styleFrom(
            backgroundColor: _TogetherTokens.spentRed,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ),
        // Countdown Action Button
        FilledButton.icon(
          onPressed: _secondsRemaining == 0
              ? () {
                  _timer?.cancel();
                  Navigator.of(context).pop(true);
                }
              : null,
          icon: Icon(
            _secondsRemaining == 0
                ? Icons.check_circle_rounded
                : Icons.hourglass_top_rounded,
            size: 14,
            color: Colors.white,
          ),
          label: Text(
            _secondsRemaining > 0
                ? 'Wait (${_secondsRemaining}s)'
                : widget.confirmLabel,
            style: GoogleFonts.plusJakartaSans(
              fontWeight: FontWeight.w800,
              color: Colors.white,
              fontSize: 12,
            ),
          ),
          style: FilledButton.styleFrom(
            backgroundColor: widget.confirmColor,
            disabledBackgroundColor:
                widget.confirmColor.withValues(alpha: 0.45),
            foregroundColor: Colors.white,
            disabledForegroundColor: Colors.white.withValues(alpha: 0.7),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ),
      ],
    );
  }
}





