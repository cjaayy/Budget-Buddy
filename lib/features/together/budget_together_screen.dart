import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/models/budget_models.dart';
import '../../core/state/app_controller.dart';
import '../../core/utils/formatters.dart';

/// Palette defining the 3 primary design colors matching Daily Budget: Dark Red, Gold, and Dark Green.
class _TogetherBudgetPalette {
  const _TogetherBudgetPalette(this.isDark);

  final bool isDark;

  // Dark Red: expenses, overspent alert, debt, reset/cancel actions
  Color get darkRed => const Color(0xFF991B1B);
  Color get darkRedBg =>
      const Color(0xFF991B1B).withValues(alpha: isDark ? 0.20 : 0.08);
  Color get darkRedBorder => const Color(0xFF991B1B).withValues(alpha: 0.25);

  // Gold: target budget amounts, currency signs, presets, monthly overview
  Color get gold => const Color(0xFFD97706);
  Color get goldBg =>
      const Color(0xFFD97706).withValues(alpha: isDark ? 0.20 : 0.08);
  Color get goldBorder => const Color(0xFFD97706).withValues(alpha: 0.25);

  // Dark Green: remaining safe balance, locked/active status, save/update actions
  Color get darkGreen => const Color(0xFF0F766E);
  Color get darkGreenBg =>
      const Color(0xFF0F766E).withValues(alpha: isDark ? 0.20 : 0.08);
  Color get darkGreenBorder => const Color(0xFF0F766E).withValues(alpha: 0.25);
}

/// Compact Metric Tile matching Daily Budget, Spend, and Savings screens
class _CompactMetricTile extends StatelessWidget {
  const _CompactMetricTile({
    required this.label,
    required this.value,
    required this.bgColor,
    this.icon,
  });

  final String label;
  final String value;
  final Color bgColor;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
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
                  color: Colors.white.withValues(alpha: 0.88),
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
                    color: Colors.white.withValues(alpha: 0.88),
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
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w900,
                color: Colors.white,
                letterSpacing: -0.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class BudgetTogetherScreen extends ConsumerStatefulWidget {
  const BudgetTogetherScreen({super.key});

  @override
  ConsumerState<BudgetTogetherScreen> createState() =>
      _BudgetTogetherScreenState();
}

class _BudgetTogetherScreenState extends ConsumerState<BudgetTogetherScreen> {
  late final TextEditingController _budgetController;
  final FocusNode _focusNode = FocusNode();
  final List<double> _quickPresets = const <double>[200, 300, 500, 1000, 1500];
  bool _isUnlockedForEditing = false;

  @override
  void initState() {
    super.initState();
    _budgetController = TextEditingController();
    final BudgetBuddyState state = ref.read(budgetBuddyControllerProvider);
    final double initialBudget = state.togetherBudget;
    if (initialBudget > 0) {
      _budgetController.text = initialBudget.toStringAsFixed(0);
    }
  }

  @override
  void dispose() {
    _budgetController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _saveBudget() {
    final String text = _budgetController.text.trim();
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
    ref.read(budgetBuddyControllerProvider.notifier).setTogetherBudget(amount);

    setState(() {
      _isUnlockedForEditing = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Budget Together set to ${formatPeso(amount)}!'),
        backgroundColor: const Color(0xFF0F766E),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _resetBudget() {
    _focusNode.unfocus();
    showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          icon: const Icon(Icons.restart_alt_rounded,
              color: Color(0xFF991B1B), size: 36),
          title: const Text('Reset Tab Budget',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
          content: const Text(
            'This will clear the Budget Together tab budget back to ₱0.',
            textAlign: TextAlign.center,
          ),
          actions: <Widget>[
            FilledButton.icon(
              onPressed: () => Navigator.of(dialogContext).pop(),
              icon: const Icon(Icons.close_rounded, size: 14),
              label: const Text('Cancel'),
              style: FilledButton.styleFrom(
                backgroundColor: Colors.grey.shade600,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            FilledButton.icon(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                _budgetController.clear();
                ref
                    .read(budgetBuddyControllerProvider.notifier)
                    .setTogetherBudget(0);
                setState(() {
                  _isUnlockedForEditing = false;
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Budget Together has been reset to ₱0.'),
                    backgroundColor: Color(0xFF991B1B),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
              icon: const Icon(Icons.delete_outline_rounded, size: 14),
              label: const Text('Reset'),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF991B1B),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _applyPreset(double amount) {
    _budgetController.text = amount.toStringAsFixed(0);
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
      _budgetController.text =
          currentBudget > 0 ? currentBudget.toStringAsFixed(0) : '';
    });
  }

  @override
  Widget build(BuildContext context) {
    final BudgetBuddyState state = ref.watch(budgetBuddyControllerProvider);
    final DateTime currentClock =
        ref.read(budgetBuddyControllerProvider.notifier).currentEffectiveTime;
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final _TogetherBudgetPalette palette = _TogetherBudgetPalette(isDark);

    final double currentBudget = state.togetherBudget;
    final double currentSpent = state.expenses
        .where((ExpenseEntry e) => e.source == 'togetherSpend')
        .fold<double>(0.0, (double sum, ExpenseEntry e) => sum + e.amount);
    final double remaining = currentBudget - currentSpent;
    final bool hasBudget = currentBudget > 0;
    final bool isLocked = hasBudget && !_isUnlockedForEditing;
    final bool isOver = remaining < 0;
    final bool isWarning =
        !isOver && hasBudget && currentSpent >= (currentBudget * 0.8);
    final double progressValue = currentBudget > 0
        ? (currentSpent / currentBudget).clamp(0.0, 1.0)
        : 0.0;

    // Listen to external changes
    ref.listen<BudgetBuddyState>(budgetBuddyControllerProvider,
        (BudgetBuddyState? prev, BudgetBuddyState next) {
      if (next.togetherBudget != prev?.togetherBudget) {
        if (next.togetherBudget <= 0) {
          if (_budgetController.text.isNotEmpty) {
            _budgetController.clear();
          }
          setState(() => _isUnlockedForEditing = false);
        } else {
          final String newText = next.togetherBudget.toStringAsFixed(0);
          if (_budgetController.text != newText) {
            _budgetController.text = newText;
          }
        }
      }
    });

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              // Back Button (If pushed on top of another screen)
              if (Navigator.of(context).canPop()) ...<Widget>[
                FilledButton.tonalIcon(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.arrow_back_rounded, size: 16),
                  label: const Text(
                    'Back to Menu',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: palette.darkGreenBg,
                    foregroundColor: palette.darkGreen,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    visualDensity: VisualDensity.compact,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
              ],

              // 1. Compact Header
              _buildHeader(
                context,
                currentClock: currentClock,
              ),
              const SizedBox(height: 12),

              // 2. Main Content
              Expanded(
                child: ListView(
                  padding: EdgeInsets.zero,
                  children: <Widget>[
                    // Main Budget Together Planner Card
                    _buildBudgetCard(
                      context,
                      currentBudget: currentBudget,
                      hasBudget: hasBudget,
                      isLocked: isLocked,
                      palette: palette,
                    ),
                    const SizedBox(height: 12),

                    // Spending Progress Card (Visible if budget set or spending exists)
                    if (hasBudget || currentSpent > 0) ...<Widget>[
                      _buildSpendingCard(
                        context,
                        currentBudget: currentBudget,
                        currentSpent: currentSpent,
                        remaining: remaining,
                        progressValue: progressValue,
                        hasBudget: hasBudget,
                        isOver: isOver,
                        isWarning: isWarning,
                        palette: palette,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Compact Header matching Daily Budget & Spend screens
  Widget _buildHeader(
    BuildContext context, {
    required DateTime currentClock,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'Set Budget Together',
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
    );
  }

  /// Main Budget Card with Input, Presets, and Solid Action Buttons
  Widget _buildBudgetCard(
    BuildContext context, {
    required double currentBudget,
    required bool hasBudget,
    required bool isLocked,
    required _TogetherBudgetPalette palette,
  }) {
    final ThemeData theme = Theme.of(context);

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
                'Target Tab Budget',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const Spacer(),
              if (hasBudget)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: isLocked ? palette.darkGreen : palette.gold,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    isLocked ? 'Active' : 'Editing',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),

          // Budget Input TextField
          TextField(
            controller: _budgetController,
            focusNode: _focusNode,
            readOnly: isLocked,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w900,
              color: palette.gold,
              letterSpacing: -0.5,
            ),
            decoration: InputDecoration(
              isDense: true,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              prefixIcon: Container(
                padding: const EdgeInsets.only(left: 12, right: 6),
                alignment: Alignment.centerLeft,
                width: 32,
                child: Text(
                  '₱',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: palette.gold,
                  ),
                ),
              ),
              hintText: '0',
              hintStyle: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w900,
                color: palette.gold.withValues(alpha: 0.35),
              ),
              filled: true,
              fillColor: isLocked
                  ? theme.colorScheme.surfaceContainerHighest
                      .withValues(alpha: 0.3)
                  : theme.colorScheme.surface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color:
                      theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: palette.gold, width: 2),
              ),
            ),
          ),

          // Quick Presets Row (When unlocked)
          if (!isLocked) ...<Widget>[
            const SizedBox(height: 10),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _quickPresets.map((double preset) {
                  final bool isSelected = _budgetController.text.trim() ==
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
                          color: isSelected ? palette.darkGreen : palette.gold,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            if (isSelected) ...<Widget>[
                              const Icon(Icons.check_rounded,
                                  size: 13, color: Colors.white),
                              const SizedBox(width: 3),
                            ],
                            Text(
                              '₱${preset.toStringAsFixed(0)}',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
          const SizedBox(height: 14),

          // Action Buttons: Edit, Reset, Save, Cancel (Following Solid Action Button Rules)
          if (isLocked) ...<Widget>[
            Row(
              children: <Widget>[
                // Edit Button (Solid Gold)
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _unlockForEditing,
                    icon: const Icon(Icons.edit_rounded, size: 16),
                    label: const Text('Edit Budget'),
                    style: FilledButton.styleFrom(
                      backgroundColor: palette.gold,
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(42),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Reset Button (Solid Dark Red)
                FilledButton.icon(
                  onPressed: _resetBudget,
                  icon: const Icon(Icons.restart_alt_rounded, size: 16),
                  label: const Text('Reset'),
                  style: FilledButton.styleFrom(
                    backgroundColor: palette.darkRed,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(90, 42),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ],
            ),
          ] else ...<Widget>[
            Row(
              children: <Widget>[
                if (hasBudget) ...<Widget>[
                  // Cancel Button (Solid Dark Red)
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () => _cancelEditing(currentBudget),
                      icon: const Icon(Icons.close_rounded, size: 16),
                      label: const Text('Cancel'),
                      style: FilledButton.styleFrom(
                        backgroundColor: palette.darkRed,
                        foregroundColor: Colors.white,
                        minimumSize: const Size.fromHeight(42),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                // Save / Update Button (Solid Dark Green)
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _saveBudget,
                    icon: const Icon(Icons.check_circle_rounded, size: 16),
                    label:
                        Text(hasBudget ? 'Update Budget' : 'Save Tab Budget'),
                    style: FilledButton.styleFrom(
                      backgroundColor: palette.darkGreen,
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(42),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  /// Compact Spending Progress Card with 3 Metric Tiles
  Widget _buildSpendingCard(
    BuildContext context, {
    required double currentBudget,
    required double currentSpent,
    required double remaining,
    required double progressValue,
    required bool hasBudget,
    required bool isOver,
    required bool isWarning,
    required _TogetherBudgetPalette palette,
  }) {
    final ThemeData theme = Theme.of(context);
    final Color barColor = isOver
        ? palette.darkRed
        : (isWarning ? palette.gold : palette.darkGreen);
    return Container(
      clipBehavior: Clip.antiAlias,
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
            children: <Widget>[
              Icon(Icons.analytics_rounded,
                  size: 16, color: palette.darkGreen),
              const SizedBox(width: 6),
              Text(
                'Tab Spending Progress',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ],
          ),
              const SizedBox(height: 10),

              // Progress Bar
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: progressValue,
                  minHeight: 7,
                  backgroundColor: barColor.withValues(alpha: 0.12),
                  valueColor: AlwaysStoppedAnimation<Color>(barColor),
                ),
              ),
              const SizedBox(height: 8),

              // Progress caption
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  Text(
                    hasBudget
                        ? '${formatPeso(currentSpent)} spent of ${formatPeso(currentBudget)}'
                        : 'No tab budget set',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  Text(
                    isOver
                        ? 'Over limit'
                        : '${formatPeso(remaining > 0 ? remaining : 0)} left',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: isOver ? palette.darkRed : palette.darkGreen,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // 3 Compact Metric Tiles: Remaining, Budget, Spent
              Row(
                children: <Widget>[
                  Expanded(
                    child: _CompactMetricTile(
                      label: 'Remaining',
                      value: (isOver ? '-' : '') + formatPeso(remaining.abs()),
                      bgColor: isOver ? palette.darkRed : palette.darkGreen,
                      icon: isOver
                          ? Icons.trending_down_rounded
                          : Icons.savings_rounded,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _CompactMetricTile(
                      label: 'Tab Budget',
                      value: formatPeso(currentBudget),
                      bgColor: palette.gold,
                      icon: Icons.account_balance_wallet_rounded,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _CompactMetricTile(
                      label: 'Tab Spent',
                      value: formatPeso(currentSpent),
                      bgColor: isOver
                          ? palette.darkRed
                          : (isWarning ? palette.gold : palette.darkGreen),
                      icon: Icons.payments_rounded,
                    ),
                  ),
                ],
              ),

              // Over-budget alert banner
              if (isOver) ...<Widget>[
                const SizedBox(height: 10),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: palette.darkRedBg,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: palette.darkRedBorder),
                  ),
                  child: Row(
                    children: <Widget>[
                      Icon(Icons.info_outline_rounded,
                          size: 14, color: palette.darkRed),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Over-budget warning: Tab spending exceeded budget by ${formatPeso(remaining.abs())}.',
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
}
