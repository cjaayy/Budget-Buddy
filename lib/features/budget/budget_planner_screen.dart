import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../core/models/budget_models.dart';
import '../../core/state/app_controller.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/budget_cards.dart';

/// Clean Modern Bento Tokens for Today's Budget Planner Screen.
/// Emphasizes Gold (#D97706) as primary focus with Dark Teal (#0F766E) and Dark Red (#991B1B).
class _BudgetTokens {
  const _BudgetTokens(this.isDark);

  final bool isDark;

  // Primary 3-Color Strict Palette
  static const Color budgetGold = Color(0xFFD97706);
  static const Color safeGreen = Color(0xFF0F766E);
  static const Color expenseRed = Color(0xFF991B1B);

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

typedef _BentoTokens = _BudgetTokens;


class BudgetPlannerScreen extends ConsumerStatefulWidget {
  const BudgetPlannerScreen({super.key});

  @override
  ConsumerState<BudgetPlannerScreen> createState() =>
      _BudgetPlannerScreenState();
}

class _BudgetPlannerScreenState extends ConsumerState<BudgetPlannerScreen> {
  late final TextEditingController _dailyController;
  final FocusNode _focusNode = FocusNode();
  final List<double> _quickPresets = const <double>[200, 300, 500, 1000, 1500];
  bool _isUnlockedForEditing = false;

  @override
  void initState() {
    super.initState();
    _dailyController = TextEditingController();
    final BudgetBuddyState state = ref.read(budgetBuddyControllerProvider);
    final double initialDaily = state.settings.dailyLimit ?? 0;
    if (initialDaily > 0) {
      _dailyController.text = initialDaily.toStringAsFixed(0);
    }
  }

  @override
  void dispose() {
    _dailyController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _saveBudget() {
    final String text = _dailyController.text.trim();
    final double? amount = double.tryParse(text);

    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid budget amount greater than ₱0.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    _focusNode.unfocus();
    ref
        .read(budgetBuddyControllerProvider.notifier)
        .recordDailyBudget(amount: amount);

    setState(() {
      _isUnlockedForEditing = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Today\'s budget set to ${formatPeso(amount)}!'),
        backgroundColor: _BudgetTokens.safeGreen,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _confirmAndUpdateBudget(double currentBudget) async {
    final String text = _dailyController.text.trim();
    final double? newAmount = double.tryParse(text);

    if (newAmount == null || newAmount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid budget amount greater than ₱0.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    _focusNode.unfocus();

    final bool? confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext ctx) => _CountdownConfirmationDialog(
        title: 'Confirm Budget Update',
        message:
            'Update today\'s budget from ${formatPeso(currentBudget)} to ${formatPeso(newAmount)}?',
        confirmLabel: 'Update Now',
        confirmColor: _BudgetTokens.safeGreen,
        icon: Icons.sync_rounded,
        autoConfirm: false,
      ),
    );

    if (!mounted || confirmed != true) {
      return;
    }

    ref
        .read(budgetBuddyControllerProvider.notifier)
        .recordDailyBudget(amount: newAmount);

    setState(() {
      _isUnlockedForEditing = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Today\'s budget updated to ${formatPeso(newAmount)}!'),
        backgroundColor: _BudgetTokens.safeGreen,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _confirmAndResetBudget() async {
    _focusNode.unfocus();

    final bool? confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext ctx) => const _CountdownConfirmationDialog(
        title: 'Confirm Budget Reset',
        message:
            'This will reset today\'s active budget and spending back to ₱0 so you can start fresh.',
        confirmLabel: 'Reset Now',
        confirmColor: _BudgetTokens.expenseRed,
        icon: Icons.restart_alt_rounded,
        autoConfirm: false,
      ),
    );

    if (!mounted || confirmed != true) {
      return;
    }

    _dailyController.clear();
    ref.read(budgetBuddyControllerProvider.notifier).clearDailyBudget();

    setState(() {
      _isUnlockedForEditing = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Today\'s budget and spending have been reset to ₱0.'),
        backgroundColor: _BudgetTokens.expenseRed,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _applyPreset(double amount) {
    setState(() {
      _dailyController.text = amount.toStringAsFixed(0);
      _isUnlockedForEditing = true;
    });
    _focusNode.requestFocus();
  }

  void _unlockForEditing() {
    setState(() {
      _isUnlockedForEditing = true;
    });
    _focusNode.requestFocus();
  }

  void _cancelEditing(double currentBudget) {
    _focusNode.unfocus();
    setState(() {
      _isUnlockedForEditing = false;
      _dailyController.text =
          currentBudget > 0 ? currentBudget.toStringAsFixed(0) : '';
    });
  }

  IconData _iconForCategory(BudgetCategory category) {
    return switch (category) {
      BudgetCategory.food => Icons.restaurant_rounded,
      BudgetCategory.transportation => Icons.directions_bus_rounded,
      BudgetCategory.entertainment => Icons.movie_outlined,
      BudgetCategory.shopping => Icons.shopping_bag_rounded,
      BudgetCategory.miscellaneous => Icons.category_rounded,
    };
  }

  double _getCategoryLimit(
    BudgetCategory category,
    BudgetSettings settings,
    double totalBudget,
  ) {
    return switch (category) {
      BudgetCategory.food =>
        settings.foodBudget > 0 ? settings.foodBudget : totalBudget * 0.40,
      BudgetCategory.transportation => settings.transportationBudget > 0
          ? settings.transportationBudget
          : totalBudget * 0.25,
      BudgetCategory.entertainment =>
        settings.leisureBudget > 0 ? settings.leisureBudget : totalBudget * 0.15,
      BudgetCategory.shopping => totalBudget * 0.10,
      BudgetCategory.miscellaneous => totalBudget * 0.10,
    };
  }

  @override
  Widget build(BuildContext context) {
    final BudgetBuddyState state = ref.watch(budgetBuddyControllerProvider);
    final BudgetSummary summary = ref.watch(budgetSummaryProvider);
    final devController = ref.read(budgetBuddyControllerProvider.notifier);
    final DateTime currentClock = devController.currentEffectiveTime;
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final _BudgetTokens tokens = _BudgetTokens(isDark);

    final BudgetPeriodSummary dailySummary =
        summary.periodSummaries[BudgetPeriod.daily] ??
            const BudgetPeriodSummary(
              period: BudgetPeriod.daily,
              limit: 0,
              spent: 0,
            );

    final BudgetPeriodSummary monthlySummary =
        summary.periodSummaries[BudgetPeriod.monthly] ??
            const BudgetPeriodSummary(
              period: BudgetPeriod.monthly,
              limit: 0,
              spent: 0,
            );

    final bool hasBudget = (state.settings.dailyLimit ?? 0) > 0;
    final double currentBudget = state.settings.dailyLimit ?? 0;
    final double currentSpent = state.dailySpent;
    final double remaining = currentBudget - currentSpent;
    final bool isLocked = hasBudget && !_isUnlockedForEditing;
    final bool isOver = remaining < 0;
    final bool isWarning =
        !isOver && hasBudget && currentSpent >= (currentBudget * 0.8);

    // Listen to external resets (e.g. 12 AM midnight reset)
    ref.listen<BudgetBuddyState>(budgetBuddyControllerProvider,
        (BudgetBuddyState? prev, BudgetBuddyState next) {
      final double? nextLimit = next.settings.dailyLimit;
      final double? prevLimit = prev?.settings.dailyLimit;
      if (nextLimit != prevLimit) {
        if (nextLimit == null || nextLimit <= 0) {
          if (_dailyController.text.isNotEmpty) {
            _dailyController.clear();
          }
          setState(() {
            _isUnlockedForEditing = false;
          });
        } else {
          final String newText = nextLimit.toStringAsFixed(0);
          if (_dailyController.text != newText) {
            _dailyController.text = newText;
          }
        }
      }
    });

    final double progressValue = currentBudget > 0
        ? (currentSpent / currentBudget).clamp(0.0, 1.0)
        : 0.0;

    return Scaffold(
      backgroundColor: tokens.scaffoldBg,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          children: <Widget>[
            // 1. Header & Budget Lock Control
            _buildHeader(
              context,
              currentClock: currentClock,
              isLocked: isLocked,
              hasBudget: hasBudget,
              currentBudget: currentBudget,
              tokens: tokens,
            ),
            const SizedBox(height: 14),

            // 2. Hero Budget Card (Target vs. Allocated)
            _buildHeroBudgetCard(
              context,
              currentBudget: currentBudget,
              currentSpent: currentSpent,
              remaining: remaining,
              progressValue: progressValue,
              hasBudget: hasBudget,
              isLocked: isLocked,
              isOver: isOver,
              isWarning: isWarning,
              dailySummary: dailySummary,
              savingsDebt: state.savingsDebt,
              tokens: tokens,
            ),
            const SizedBox(height: 14),

            // 3. Quick-Preset Amount Chips
            _buildPresetChipsSection(
              context,
              isLocked: isLocked,
              tokens: tokens,
            ),
            const SizedBox(height: 14),

            // 4. Action Buttons (Edit, Adjust, Save, Cancel, Reset)
            _buildActionButtons(
              context,
              hasBudget: hasBudget,
              isLocked: isLocked,
              currentBudget: currentBudget,
              tokens: tokens,
            ),
            const SizedBox(height: 14),

            // 5. Category Budget Breakdown (Bento Cards)
            _buildCategoryBreakdownSection(
              context,
              state: state,
              currentBudget: currentBudget,
              currentClock: currentClock,
              tokens: tokens,
            ),
            const SizedBox(height: 14),

            // 6. Compact Month Total Overview Strip
            _buildMonthTile(
              context,
              monthlyLimit: monthlySummary.limit,
              currentClock: currentClock,
              tokens: tokens,
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  /// 1. Header Section with Title, Formatted Date, and Clean Lock Switch Tile
  Widget _buildHeader(
    BuildContext context, {
    required DateTime currentClock,
    required bool isLocked,
    required bool hasBudget,
    required double currentBudget,
    required _BudgetTokens tokens,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        // Title Row
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Today\'s Budget Plan',
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
              text: isLocked
                  ? 'Locked'
                  : (_isUnlockedForEditing ? 'Editing' : 'Setup'),
              color: isLocked ? _BudgetTokens.budgetGold : _BudgetTokens.safeGreen,
              icon: isLocked ? Icons.lock_outline_rounded : Icons.edit_rounded,
              fontSize: 11,
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Budget Lock / Unlock Switch Tile
        if (hasBudget) ...<Widget>[
          BentoCard(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            borderRadius: 16,
            child: Row(
              children: <Widget>[
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: tokens.tint(
                      isLocked ? _BudgetTokens.budgetGold : _BudgetTokens.safeGreen,
                      0.10,
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isLocked ? Icons.lock_rounded : Icons.lock_open_rounded,
                    size: 16,
                    color: isLocked
                        ? _BudgetTokens.budgetGold
                        : _BudgetTokens.safeGreen,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        isLocked ? 'Budget Locked' : 'Editing Mode Active',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: tokens.textPrimary,
                        ),
                      ),
                      Text(
                        isLocked
                            ? 'Protected against accidental changes'
                            : 'Adjust your target allowance below',
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
                  value: isLocked,
                  activeColor: _BudgetTokens.budgetGold,
                  onChanged: (bool value) {
                    if (value) {
                      _cancelEditing(currentBudget);
                    } else {
                      _unlockForEditing();
                    }
                  },
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  /// 2. Hero Budget Card: Target vs. Allocated with Gold Accent & Sub-Metrics
  Widget _buildHeroBudgetCard(
    BuildContext context, {
    required double currentBudget,
    required double currentSpent,
    required double remaining,
    required double progressValue,
    required bool hasBudget,
    required bool isLocked,
    required bool isOver,
    required bool isWarning,
    required BudgetPeriodSummary dailySummary,
    required double savingsDebt,
    required _BudgetTokens tokens,
  }) {
    return BentoCard(
      padding: const EdgeInsets.all(18),
      borderRadius: 24,
      borderColor: isOver
          ? _BudgetTokens.expenseRed.withValues(alpha: 0.40)
          : _BudgetTokens.budgetGold.withValues(alpha: 0.35),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // Top Label Row
          Row(
            children: <Widget>[
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: tokens.tint(_BudgetTokens.budgetGold, 0.10),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.account_balance_wallet_rounded,
                  size: 16,
                  color: _BudgetTokens.budgetGold,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Today\'s Total Target',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: tokens.textSecondary,
                  ),
                ),
              ),
              SoftPill(
                text: !hasBudget
                    ? 'No Budget Set'
                    : (isOver
                        ? 'Over Budget'
                        : (isWarning ? '80% Cap' : 'Active Target')),
                color: !hasBudget
                    ? _BudgetTokens.budgetGold
                    : (isOver
                        ? _BudgetTokens.expenseRed
                        : (isWarning
                            ? _BudgetTokens.budgetGold
                            : _BudgetTokens.safeGreen)),
                icon: isOver
                    ? Icons.warning_amber_rounded
                    : (isWarning
                        ? Icons.info_outline_rounded
                        : Icons.check_circle_outline_rounded),
                fontSize: 11,
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Big Gold Currency Display or Clean Input Field
          if (isLocked) ...<Widget>[
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                formatPeso(currentBudget),
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 34,
                  fontWeight: FontWeight.w900,
                  color: _BudgetTokens.budgetGold,
                  letterSpacing: -1.0,
                ),
              ),
            ),
          ] else ...<Widget>[
            TextField(
              controller: _dailyController,
              focusNode: _focusNode,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              style: GoogleFonts.plusJakartaSans(
                fontSize: 28,
                fontWeight: FontWeight.w900,
                color: _BudgetTokens.budgetGold,
                letterSpacing: -0.5,
              ),
              onChanged: (_) => setState(() {}),
              onSubmitted: (_) {
                if (hasBudget) {
                  _confirmAndUpdateBudget(currentBudget);
                } else {
                  _saveBudget();
                }
              },
              decoration: InputDecoration(
                isDense: true,
                filled: true,
                fillColor: tokens.subCardBg,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                prefixIcon: Padding(
                  padding: const EdgeInsets.only(left: 14, right: 6),
                  child: Text(
                    '₱',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      color: _BudgetTokens.budgetGold,
                    ),
                  ),
                ),
                prefixIconConstraints:
                    const BoxConstraints(minWidth: 36, minHeight: 0),
                hintText: '0',
                hintStyle: GoogleFonts.plusJakartaSans(
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  color: tokens.textMuted,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: tokens.cardBorder, width: 1.0),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(
                    color: _BudgetTokens.budgetGold,
                    width: 2.0,
                  ),
                ),
                suffixIcon: _dailyController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(
                          Icons.clear_rounded,
                          color: _BudgetTokens.expenseRed,
                          size: 20,
                        ),
                        onPressed: () {
                          _dailyController.clear();
                          setState(() {});
                        },
                      )
                    : null,
              ),
            ),
          ],
          const SizedBox(height: 14),

          // Visual Progress Bar
          BentoHealthBar(
            progress: progressValue,
            color: isOver
                ? _BudgetTokens.expenseRed
                : (isWarning
                    ? _BudgetTokens.budgetGold
                    : _BudgetTokens.budgetGold),
            height: 8,
          ),
          const SizedBox(height: 8),

          // Progress Breakdown Sub-Row
          Row(
            children: <Widget>[
              Text(
                '${(progressValue * 100).toInt()}% of daily target reached',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: tokens.textSecondary,
                ),
              ),
              const Spacer(),
              Text(
                '${formatPeso(currentSpent)} / ${formatPeso(currentBudget)}',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: tokens.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Sub-Metric Row: Spent Today & Remaining Safe Side-by-Side
          Row(
            children: <Widget>[
              // Spent Today (Dark Red)
              Expanded(
                child: BentoMetricTile(
                  label: 'Spent Today',
                  value: formatPeso(currentSpent),
                  accentColor: _BudgetTokens.expenseRed,
                  icon: Icons.payments_rounded,
                  subtitle: isOver ? 'Limit exceeded' : 'Logged outlays',
                ),
              ),
              const SizedBox(width: 10),
              // Remaining Safe (Dark Green / Dark Red if over)
              Expanded(
                child: BentoMetricTile(
                  label: isOver ? 'Deficit' : 'Safe Remaining',
                  value: (isOver ? '-' : '') + formatPeso(remaining.abs()),
                  accentColor: isOver
                      ? _BudgetTokens.expenseRed
                      : _BudgetTokens.safeGreen,
                  icon: isOver
                      ? Icons.trending_down_rounded
                      : Icons.savings_rounded,
                  subtitle: isOver ? 'Over by amount' : 'Safe to spend',
                ),
              ),
            ],
          ),

          // Overspent Warning Box
          if (isOver) ...<Widget>[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: tokens.tint(_BudgetTokens.expenseRed, 0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: _BudgetTokens.expenseRed.withValues(alpha: 0.25),
                  width: 1.0,
                ),
              ),
              child: Row(
                children: <Widget>[
                  const Icon(
                    Icons.error_outline_rounded,
                    size: 15,
                    color: _BudgetTokens.expenseRed,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Budget exceeded by ${formatPeso(remaining.abs())}. Slow down on expenses today.',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: _BudgetTokens.expenseRed,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Savings Debt Alert
          if (savingsDebt > 0) ...<Widget>[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: tokens.tint(_BudgetTokens.expenseRed, 0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: _BudgetTokens.expenseRed.withValues(alpha: 0.25),
                  width: 1.0,
                ),
              ),
              child: Row(
                children: <Widget>[
                  const Icon(
                    Icons.history_rounded,
                    size: 15,
                    color: _BudgetTokens.expenseRed,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Running Debt: ${formatPeso(savingsDebt)} will be settled from upcoming surplus.',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: _BudgetTokens.expenseRed,
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

  /// 3. Quick-Preset Amount Chips: Scrollable Row of Capsule Pills
  Widget _buildPresetChipsSection(
    BuildContext context, {
    required bool isLocked,
    required _BudgetTokens tokens,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            const Icon(
              Icons.flash_on_rounded,
              size: 15,
              color: _BudgetTokens.budgetGold,
            ),
            const SizedBox(width: 6),
            Text(
              'Quick Presets',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: tokens.textPrimary,
              ),
            ),
            const Spacer(),
            Text(
              isLocked ? 'Tap to unlock & select' : 'Tap to apply',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: tokens.textSecondary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: _quickPresets.map((double preset) {
              final bool isSelected =
                  _dailyController.text.trim() == preset.toStringAsFixed(0);

              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => _applyPreset(preset),
                    borderRadius: BorderRadius.circular(999),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? _BudgetTokens.budgetGold
                            : tokens.cardBg,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: isSelected
                              ? _BudgetTokens.budgetGold
                              : tokens.cardBorder,
                          width: 1.0,
                        ),
                      ),
                      child: Text(
                        '₱${preset.toStringAsFixed(0)}',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12.5,
                          fontWeight:
                              isSelected ? FontWeight.w800 : FontWeight.w600,
                          color: isSelected
                              ? Colors.white
                              : _BudgetTokens.budgetGold,
                        ),
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

  /// 4. Action Buttons with Solid Gold (Edit) and Solid Dark Green (Save/Confirm)
  Widget _buildActionButtons(
    BuildContext context, {
    required bool hasBudget,
    required bool isLocked,
    required double currentBudget,
    required _BudgetTokens tokens,
  }) {
    if (isLocked) {
      return Row(
        children: <Widget>[
          // Edit Target Button (Solid Gold)
          Expanded(
            child: FilledButton.icon(
              onPressed: _unlockForEditing,
              icon: const Icon(Icons.edit_rounded, size: 16),
              label: const Text('Adjust Target'),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(44),
                backgroundColor: _BudgetTokens.budgetGold,
                foregroundColor: Colors.white,
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
          // Reset Button (Solid Dark Red)
          Expanded(
            child: FilledButton.icon(
              onPressed: _confirmAndResetBudget,
              icon: const Icon(Icons.restart_alt_rounded, size: 16),
              label: const Text('Reset Today'),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(44),
                backgroundColor: _BudgetTokens.expenseRed,
                foregroundColor: Colors.white,
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
      );
    } else if (hasBudget) {
      return Row(
        children: <Widget>[
          // Cancel Button (Solid Dark Red)
          Expanded(
            child: FilledButton.icon(
              onPressed: () => _cancelEditing(currentBudget),
              icon: const Icon(Icons.close_rounded, size: 16),
              label: const Text('Cancel'),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(44),
                backgroundColor: _BudgetTokens.expenseRed,
                foregroundColor: Colors.white,
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
          // Save / Update Button (Solid Dark Green)
          Expanded(
            child: FilledButton.icon(
              onPressed: _dailyController.text.trim().isNotEmpty
                  ? () => _confirmAndUpdateBudget(currentBudget)
                  : null,
              icon: const Icon(Icons.check_circle_rounded, size: 16),
              label: const Text('Save & Lock'),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(44),
                backgroundColor: _BudgetTokens.safeGreen,
                foregroundColor: Colors.white,
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
      );
    } else {
      // First Time Set Target
      return SizedBox(
        width: double.infinity,
        child: FilledButton.icon(
          onPressed:
              _dailyController.text.trim().isNotEmpty ? _saveBudget : null,
          icon: const Icon(Icons.check_circle_rounded, size: 16),
          label: const Text('Save & Lock Today\'s Budget'),
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(46),
            backgroundColor: _BudgetTokens.safeGreen,
            foregroundColor: Colors.white,
            textStyle: GoogleFonts.plusJakartaSans(
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      );
    }
  }

  /// 5. Category Budget Breakdown (Bento Cards with 18px radius)
  Widget _buildCategoryBreakdownSection(
    BuildContext context, {
    required BudgetBuddyState state,
    required double currentBudget,
    required DateTime currentClock,
    required _BudgetTokens tokens,
  }) {
    final List<BudgetCategory> categories = BudgetCategory.values;

    return BentoCard(
      padding: const EdgeInsets.all(18),
      borderRadius: 18,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // Header Row
          Row(
            children: <Widget>[
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: tokens.tint(_BudgetTokens.budgetGold, 0.10),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.pie_chart_rounded,
                  size: 16,
                  color: _BudgetTokens.budgetGold,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Category Budget Allocation',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w800,
                    color: tokens.textPrimary,
                  ),
                ),
              ),
              Text(
                'Today',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: tokens.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Categories Bento Cards
          ...categories.map((BudgetCategory category) {
            final double limit =
                _getCategoryLimit(category, state.settings, currentBudget);

            // Compute today's spending in this category
            double spentToday = 0;
            for (final ExpenseEntry e in state.expenses) {
              if (e.source == 'togetherSpend') continue;
              if (e.dateTime.year == currentClock.year &&
                  e.dateTime.month == currentClock.month &&
                  e.dateTime.day == currentClock.day &&
                  e.category == category) {
                spentToday += e.amount;
              }
            }

            final bool isCategoryOver = limit > 0 && spentToday > limit;
            final double catProgress =
                limit > 0 ? (spentToday / limit).clamp(0.0, 1.0) : 0.0;
            final IconData icon = _iconForCategory(category);

            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: tokens.subCardBg,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: tokens.cardBorder, width: 1.0),
                ),
                child: Column(
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Container(
                          padding: const EdgeInsets.all(7),
                          decoration: BoxDecoration(
                            color: tokens.tint(_BudgetTokens.budgetGold, 0.10),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            icon,
                            size: 14,
                            color: _BudgetTokens.budgetGold,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                category.label,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: tokens.textPrimary,
                                ),
                              ),
                              Text(
                                category.hint,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w500,
                                  color: tokens.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: <Widget>[
                            Text(
                              formatPeso(spentToday),
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: isCategoryOver
                                    ? _BudgetTokens.expenseRed
                                    : tokens.textPrimary,
                              ),
                            ),
                            Text(
                              'cap: ${formatPeso(limit)}',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w600,
                                color: tokens.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    BentoHealthBar(
                      progress: catProgress,
                      color: isCategoryOver
                          ? _BudgetTokens.expenseRed
                          : _BudgetTokens.budgetGold,
                      height: 5,
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  /// 6. Compact Month Summary Strip with Gold Accent
  Widget _buildMonthTile(
    BuildContext context, {
    required double monthlyLimit,
    required DateTime currentClock,
    required _BudgetTokens tokens,
  }) {
    return BentoCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      borderRadius: 16,
      child: Row(
        children: <Widget>[
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: tokens.tint(_BudgetTokens.budgetGold, 0.10),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.calendar_month_rounded,
              size: 16,
              color: _BudgetTokens.budgetGold,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Month Total Budget',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: tokens.textPrimary,
                  ),
                ),
                Text(
                  DateFormat('MMMM yyyy').format(currentClock),
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    color: tokens.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Text(
            formatPeso(monthlyLimit),
            style: GoogleFonts.plusJakartaSans(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: _BudgetTokens.budgetGold,
              letterSpacing: -0.4,
            ),
          ),
        ],
      ),
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
  });

  final String title;
  final String message;
  final String confirmLabel;
  final Color confirmColor;
  final IconData icon;
  final bool autoConfirm;

  @override
  State<_CountdownConfirmationDialog> createState() =>
      _CountdownConfirmationDialogState();
}

class _CountdownConfirmationDialogState
    extends State<_CountdownConfirmationDialog> {
  static const int _totalSeconds = 5;
  int _secondsRemaining = _totalSeconds;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
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
    final double progress = _secondsRemaining / _totalSeconds;

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
      content: Column(
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
              Expanded(
                child: Text(
                  _secondsRemaining > 0
                      ? 'Timer: $_secondsRemaining s'
                      : 'Timer done. Ready to confirm.',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: widget.confirmColor,
                  ),
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
            backgroundColor: _BudgetTokens.expenseRed,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ),
        // Solid Confirm Button
        FilledButton.icon(
          onPressed: () {
            _timer?.cancel();
            Navigator.of(context).pop(true);
          },
          icon: Icon(widget.icon, size: 15),
          label: Text(
            widget.confirmLabel,
            style: GoogleFonts.plusJakartaSans(
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
          style: FilledButton.styleFrom(
            backgroundColor: widget.confirmColor,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ),
      ],
    );
  }
}
