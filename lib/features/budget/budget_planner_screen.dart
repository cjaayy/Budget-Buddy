import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/models/budget_models.dart';
import '../../core/state/app_controller.dart';
import '../../core/utils/formatters.dart';

/// Palette defining the 3 primary design colors: Dark Red, Gold, and Dark Green.
class _BudgetPalette {
  const _BudgetPalette(this.isDark);

  final bool isDark;

  // Dark Red: expenses, overspent alert, debt, reset/cancel actions
  Color get darkRed => const Color(0xFF991B1B);
  Color get darkRedBg => const Color(0xFF991B1B).withValues(alpha: isDark ? 0.20 : 0.08);
  Color get darkRedBorder => const Color(0xFF991B1B).withValues(alpha: 0.25);

  // Gold: target budget amounts, currency signs, presets, monthly overview
  Color get gold => const Color(0xFFD97706);
  Color get goldBg => const Color(0xFFD97706).withValues(alpha: isDark ? 0.20 : 0.08);
  Color get goldBorder => const Color(0xFFD97706).withValues(alpha: 0.25);

  // Dark Green: remaining safe balance, locked/active status, save/update actions
  Color get darkGreen => const Color(0xFF0F766E);
  Color get darkGreenBg => const Color(0xFF0F766E).withValues(alpha: isDark ? 0.20 : 0.08);
  Color get darkGreenBorder => const Color(0xFF0F766E).withValues(alpha: 0.25);
}

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
        backgroundColor: const Color(0xFF0F766E),
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
        confirmColor: const Color(0xFF0F766E),
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
        backgroundColor: const Color(0xFF0F766E),
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
            'This will reset today\'s active budget and spending back to ₱0 so you can start a fresh new day.',
        confirmLabel: 'Reset Now',
        confirmColor: Color(0xFF991B1B),
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
        backgroundColor: Color(0xFF991B1B),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _applyPreset(double amount) {
    _dailyController.text = amount.toStringAsFixed(0);
    setState(() {});
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

  @override
  Widget build(BuildContext context) {
    final BudgetBuddyState state = ref.watch(budgetBuddyControllerProvider);
    final BudgetSummary summary = ref.watch(budgetSummaryProvider);
    final devController = ref.read(budgetBuddyControllerProvider.notifier);
    final DateTime currentClock = devController.currentEffectiveTime;
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final _BudgetPalette palette = _BudgetPalette(isDark);

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

    // Listen to external resets (e.g. 12 AM midnight reset) and update the text field
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
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              // 1. Compact Header: Single line title + date + status pill
              _buildHeader(
                context,
                currentClock: currentClock,
                hasBudget: hasBudget,
                isLocked: isLocked,
                palette: palette,
              ),
              const SizedBox(height: 12),

              // 2. Compact Main Content List
              Expanded(
                child: ListView(
                  padding: EdgeInsets.zero,
                  children: <Widget>[
                    // Main Budget Card (Gold, Green, Dark Red)
                    _buildBudgetCard(
                      context,
                      currentBudget: currentBudget,
                      hasBudget: hasBudget,
                      isLocked: isLocked,
                      palette: palette,
                    ),
                    const SizedBox(height: 12),

                    // Spending Progress Card (Only if hasBudget or spending exists)
                    if (hasBudget || currentSpent > 0) ...<Widget>[
                      _buildSpendingCard(
                        context,
                        currentBudget: currentBudget,
                        currentSpent: currentSpent,
                        remaining: remaining,
                        progressValue: progressValue,
                        dailySummary: dailySummary,
                        hasBudget: hasBudget,
                        savingsDebt: state.savingsDebt,
                        palette: palette,
                      ),
                      const SizedBox(height: 12),
                    ],

                    // Compact Month Total Strip
                    _buildMonthTile(
                      context,
                      monthlyLimit: monthlySummary.limit,
                      currentClock: currentClock,
                      palette: palette,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Compact header without redundant subtitles or duplicate pills
  Widget _buildHeader(
    BuildContext context, {
    required DateTime currentClock,
    required bool hasBudget,
    required bool isLocked,
    required _BudgetPalette palette,
  }) {
    final Color statusColor = isLocked
        ? palette.darkGreen
        : (hasBudget ? palette.gold : palette.darkRed);
    final Color statusBg = isLocked
        ? palette.darkGreenBg
        : (hasBudget ? palette.goldBg : palette.darkRedBg);
    final Color statusBorder = isLocked
        ? palette.darkGreenBorder
        : (hasBudget ? palette.goldBorder : palette.darkRedBorder);
    final IconData statusIcon = isLocked
        ? Icons.check_circle_rounded
        : (hasBudget ? Icons.edit_rounded : Icons.radio_button_unchecked_rounded);
    final String statusLabel =
        isLocked ? 'Active' : (hasBudget ? 'Editing' : 'No Budget Set');

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: <Widget>[
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Daily Budget',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
            ),
            const SizedBox(height: 2),
            Text(
              DateFormat('EEEE, MMM d').format(currentClock),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                  ),
            ),
          ],
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: statusBg,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: statusBorder),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(statusIcon, size: 12, color: statusColor),
              const SizedBox(width: 5),
              Text(
                statusLabel,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: statusColor,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Compact Budget Card: Clean Gold Currency Field + MD Solid Buttons (Green, Dark Red)
  Widget _buildBudgetCard(
    BuildContext context, {
    required double currentBudget,
    required bool hasBudget,
    required bool isLocked,
    required _BudgetPalette palette,
  }) {
    final ThemeData theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.cardTheme.color ?? theme.cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: palette.goldBorder),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: palette.gold.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // Top Label Row
          Row(
            children: <Widget>[
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: palette.goldBg,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.account_balance_wallet_rounded,
                  size: 16,
                  color: palette.gold,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Target Allowance',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Currency Input Box (Gold Prefix + Gold Numbers)
          TextField(
            controller: _dailyController,
            focusNode: _focusNode,
            readOnly: isLocked,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
              color: palette.gold,
            ),
            onChanged: (_) => setState(() {}),
            onSubmitted: (_) {
              if (!isLocked) {
                if (hasBudget) {
                  _confirmAndUpdateBudget(currentBudget);
                } else {
                  _saveBudget();
                }
              }
            },
            decoration: InputDecoration(
              isDense: true,
              filled: isLocked,
              fillColor: theme.colorScheme.surfaceContainerHighest
                  .withValues(alpha: 0.35),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              prefixIcon: Container(
                padding: const EdgeInsets.only(left: 14, right: 6),
                alignment: Alignment.centerLeft,
                width: 36,
                child: Text(
                  '₱',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: palette.gold,
                  ),
                ),
              ),
              hintText: '0',
              hintStyle: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w600,
                color: theme.hintColor,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: palette.goldBorder),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: palette.gold, width: 2),
              ),
              suffixIcon: !isLocked && _dailyController.text.isNotEmpty
                  ? IconButton(
                      icon: Icon(Icons.clear_rounded,
                          color: palette.darkRed, size: 20),
                      onPressed: () {
                        _dailyController.clear();
                        setState(() {});
                      },
                    )
                  : null,
            ),
          ),

          // Preset Chips (Only visible when unlocked for editing)
          if (!isLocked) ...<Widget>[
            const SizedBox(height: 10),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _quickPresets.map((double preset) {
                  final bool isSelected = _dailyController.text.trim() ==
                      preset.toStringAsFixed(0);
                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: InkWell(
                      onTap: () => _applyPreset(preset),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: isSelected ? palette.gold : palette.goldBg,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isSelected
                                ? palette.gold
                                : palette.goldBorder,
                          ),
                        ),
                        child: Text(
                          '₱${preset.toStringAsFixed(0)}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: isSelected
                                ? FontWeight.w700
                                : FontWeight.w600,
                            color: isSelected ? Colors.white : palette.gold,
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
          const SizedBox(height: 12),

          // Action Buttons: Solid Green for current/save, Solid Dark Red for reset/cancel
          if (isLocked) ...<Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _unlockForEditing,
                    icon: const Icon(Icons.lock_open_rounded, size: 16),
                    label: const Text('Unlock to Edit'),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(42),
                      backgroundColor: palette.darkGreen,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _confirmAndResetBudget,
                    icon: const Icon(Icons.restart_alt_rounded, size: 16),
                    label: const Text('Reset Budget'),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(42),
                      backgroundColor: palette.darkRed,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ] else if (hasBudget) ...<Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => _cancelEditing(currentBudget),
                    icon: const Icon(Icons.close_rounded, size: 16),
                    label: const Text('Cancel'),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(42),
                      backgroundColor: palette.darkRed,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _dailyController.text.trim().isNotEmpty
                        ? () => _confirmAndUpdateBudget(currentBudget)
                        : null,
                    icon: const Icon(Icons.sync_rounded, size: 16),
                    label: const Text('Update Budget'),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(42),
                      backgroundColor: palette.darkGreen,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ] else ...<Widget>[
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed:
                    _dailyController.text.trim().isNotEmpty ? _saveBudget : null,
                icon: const Icon(Icons.check_circle_rounded, size: 16),
                label: const Text('Save & Lock Today\'s Budget'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(42),
                  backgroundColor: palette.darkGreen,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Compact Spending Card (Progress Bar + 3 Metrics: Gold, Dark Red, Dark Green)
  Widget _buildSpendingCard(
    BuildContext context, {
    required double currentBudget,
    required double currentSpent,
    required double remaining,
    required double progressValue,
    required BudgetPeriodSummary dailySummary,
    required bool hasBudget,
    required double savingsDebt,
    required _BudgetPalette palette,
  }) {
    final ThemeData theme = Theme.of(context);
    final bool isOver = remaining < 0;

    final Color barColor = isOver
        ? palette.darkRed
        : (dailySummary.isWarning ? palette.gold : palette.darkGreen);
    final Color badgeColor = isOver
        ? palette.darkRed
        : (dailySummary.isWarning ? palette.gold : palette.darkGreen);
    final Color badgeBg = isOver
        ? palette.darkRedBg
        : (dailySummary.isWarning ? palette.goldBg : palette.darkGreenBg);
    final Color badgeBorder = isOver
        ? palette.darkRedBorder
        : (dailySummary.isWarning ? palette.goldBorder : palette.darkGreenBorder);

    final String badgeLabel = !hasBudget
        ? 'Unset'
        : isOver
            ? 'Over by ${formatPeso(remaining.abs())}'
            : '${(progressValue * 100).toInt()}% Used';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.cardTheme.color ?? theme.cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // Header Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Icon(Icons.analytics_rounded,
                      size: 16, color: palette.darkGreen),
                  const SizedBox(width: 6),
                  Text(
                    'Daily Spending',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: badgeBg,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: badgeBorder),
                ),
                child: Text(
                  badgeLabel,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: badgeColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Linear progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progressValue,
              minHeight: 7,
              backgroundColor: barColor.withValues(alpha: 0.12),
              valueColor: AlwaysStoppedAnimation<Color>(barColor),
            ),
          ),
          const SizedBox(height: 12),

          // 3 Compact Metric Tiles with Rich Colored Backgrounds & Highly Visible Numbers
          Row(
            children: <Widget>[
              Expanded(
                child: _CompactMetricTile(
                  label: 'Budget',
                  value: formatPeso(currentBudget),
                  bgColor: palette.gold,
                  icon: Icons.account_balance_wallet_rounded,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _CompactMetricTile(
                  label: 'Spent',
                  value: formatPeso(currentSpent),
                  bgColor: palette.darkRed,
                  icon: Icons.shopping_bag_rounded,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _CompactMetricTile(
                  label: isOver ? 'Over' : 'Remaining',
                  value: formatPeso(remaining.abs()),
                  bgColor: isOver ? palette.darkRed : palette.darkGreen,
                  icon: isOver
                      ? Icons.warning_amber_rounded
                      : Icons.savings_rounded,
                ),
              ),
            ],
          ),

          // Warning Notice (Only shown if overspent or warning threshold reached)
          if (hasBudget && (dailySummary.isOverspent || dailySummary.isWarning)) ...<Widget>[
            const SizedBox(height: 8),
            Row(
              children: <Widget>[
                Icon(
                  Icons.info_outline_rounded,
                  size: 14,
                  color: dailySummary.isOverspent
                      ? palette.darkRed
                      : palette.gold,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    dailySummary.warningMessage,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: dailySummary.isOverspent
                          ? palette.darkRed
                          : palette.gold,
                    ),
                  ),
                ),
              ],
            ),
          ],

          // Savings Debt Alert (Dark Red)
          if (savingsDebt > 0) ...<Widget>[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              decoration: BoxDecoration(
                color: palette.darkRedBg,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: palette.darkRedBorder),
              ),
              child: Row(
                children: <Widget>[
                  Icon(Icons.history_rounded,
                      size: 14, color: palette.darkRed),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Debt: ${formatPeso(savingsDebt)} will be settled from surplus.',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: palette.darkRed,
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

  /// Compact Month Summary Strip (Gold Accent)
  Widget _buildMonthTile(
    BuildContext context, {
    required double monthlyLimit,
    required DateTime currentClock,
    required _BudgetPalette palette,
  }) {
    final ThemeData theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: theme.cardTheme.color ?? theme.cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: palette.goldBorder),
      ),
      child: Row(
        children: <Widget>[
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: palette.goldBg,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.savings_rounded, size: 16, color: palette.gold),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Month Total Budget',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                Text(
                  DateFormat('MMMM yyyy').format(currentClock),
                  style: TextStyle(
                    fontSize: 11,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Text(
            formatPeso(monthlyLimit),
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: palette.gold,
            ),
          ),
        ],
      ),
    );
  }
}

/// Compact Metric Tile for Budget, Spent, and Remaining with solid background color and prominent numbers
class _CompactMetricTile extends StatelessWidget {
  const _CompactMetricTile({
    required this.label,
    required this.value,
    required this.bgColor,
    this.textColor = Colors.white,
    this.icon,
  });

  final String label;
  final String value;
  final Color bgColor;
  final Color textColor;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: bgColor.withValues(alpha: 0.32),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Row(
            children: <Widget>[
              if (icon != null) ...<Widget>[
                Icon(
                  icon,
                  size: 12,
                  color: textColor.withValues(alpha: 0.88),
                ),
                const SizedBox(width: 4),
              ],
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.2,
                    color: textColor.withValues(alpha: 0.88),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              maxLines: 1,
              style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 16,
                letterSpacing: -0.3,
                color: textColor,
                shadows: const <Shadow>[
                  Shadow(
                    color: Colors.black26,
                    blurRadius: 2,
                    offset: Offset(0, 1),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A modal confirmation dialog with countdown timer.
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
    final double progress = _secondsRemaining / _totalSeconds;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
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
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
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
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 5,
              backgroundColor:
                  Theme.of(context).colorScheme.surfaceContainerHighest,
              valueColor: AlwaysStoppedAnimation<Color>(widget.confirmColor),
            ),
          ),
          const SizedBox(height: 6),
          if (widget.autoConfirm) ...<Widget>[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Text(
                  'Auto-confirming in $_secondsRemaining s...',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: widget.confirmColor,
                  ),
                ),
                Icon(Icons.timer_outlined, size: 13, color: widget.confirmColor),
              ],
            ),
          ] else ...<Widget>[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Expanded(
                  child: Text(
                    _secondsRemaining > 0
                        ? 'Timer: $_secondsRemaining s (tap "${widget.confirmLabel}" to confirm)'
                        : 'Timer done. Tap "${widget.confirmLabel}" to confirm.',
                    style: TextStyle(
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
        ],
      ),
      actions: <Widget>[
        // Solid Red Cancel Button
        FilledButton(
          onPressed: () {
            _timer?.cancel();
            Navigator.of(context).pop(false);
          },
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF991B1B),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          child: const Text('Cancel'),
        ),
        // Solid Confirm Button
        FilledButton.icon(
          onPressed: () {
            _timer?.cancel();
            Navigator.of(context).pop(true);
          },
          icon: Icon(widget.icon, size: 15),
          label: Text(widget.confirmLabel),
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
