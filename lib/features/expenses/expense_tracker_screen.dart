import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/models/budget_models.dart';
import '../../core/state/app_controller.dart';
import '../../core/utils/formatters.dart';
import '../budget/budget_planner_screen.dart';
import '../together/budget_together_screen.dart';

/// Palette matching Daily Budget, Spend, and Savings screens:
/// Dark Red (#991B1B), Gold (#D97706), Dark Green (#0F766E)
class _ExpensePalette {
  const _ExpensePalette(this.isDark);

  final bool isDark;

  // Dark Red: expenses, overspent alert, delete/cancel actions
  Color get darkRed => const Color(0xFF991B1B);
  Color get darkRedBg =>
      const Color(0xFF991B1B).withValues(alpha: isDark ? 0.20 : 0.08);
  Color get darkRedBorder => const Color(0xFF991B1B).withValues(alpha: 0.25);

  // Gold: target budget amounts, zero-activity badges, history counts, monthly overview
  Color get gold => const Color(0xFFD97706);
  Color get goldBg =>
      const Color(0xFFD97706).withValues(alpha: isDark ? 0.20 : 0.08);
  Color get goldBorder => const Color(0xFFD97706).withValues(alpha: 0.25);

  // Dark Green: remaining safe balance, on-track status, save/update actions
  Color get darkGreen => const Color(0xFF0F766E);
  Color get darkGreenBg =>
      const Color(0xFF0F766E).withValues(alpha: isDark ? 0.20 : 0.08);
  Color get darkGreenBorder => const Color(0xFF0F766E).withValues(alpha: 0.25);
}

/// Compact Metric Tile for Budget, Spent, and Remaining matching other screens
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
                fontWeight: FontWeight.w900,
                fontSize: 16,
                letterSpacing: -0.3,
                color: Colors.white,
                shadows: <Shadow>[
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

class ExpenseTrackerScreen extends ConsumerStatefulWidget {
  const ExpenseTrackerScreen({super.key, this.isTogetherOnly = false});

  final bool isTogetherOnly;

  @override
  ConsumerState<ExpenseTrackerScreen> createState() =>
      _ExpenseTrackerScreenState();
}

class _ExpenseTrackerScreenState extends ConsumerState<ExpenseTrackerScreen> {
  ExpenseSection _activeSection = ExpenseSection.daily;

  bool _ensureBudgetSet(BuildContext context, _ExpensePalette palette) {
    final BudgetBuddyState state = ref.read(budgetBuddyControllerProvider);
    final bool hasBudget = widget.isTogetherOnly
        ? state.togetherBudget > 0
        : state.settings.totalDailyBudget > 0;

    if (!hasBudget) {
      showDialog<void>(
        context: context,
        builder: (BuildContext dialogContext) {
          return AlertDialog(
            icon: Icon(
              Icons.warning_amber_rounded,
              color: palette.darkRed,
              size: 44,
            ),
            title: Text(widget.isTogetherOnly
                ? 'Budget Together Required'
                : 'Daily Budget Required'),
            content: Text(
              widget.isTogetherOnly
                  ? 'You cannot log expenses until you set a Budget Together amount. Please set a budget first.'
                  : 'You cannot log expenses until you set a daily budget. Please set a budget first.',
              textAlign: TextAlign.center,
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                style: TextButton.styleFrom(
                  foregroundColor: palette.darkRed,
                ),
                child: const Text('Cancel'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: palette.darkGreen,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: () {
                  Navigator.of(dialogContext).pop();
                  if (widget.isTogetherOnly) {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const BudgetTogetherScreen(),
                      ),
                    );
                  } else {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const BudgetPlannerScreen(),
                      ),
                    );
                  }
                },
                child: const Text('Set Budget'),
              ),
            ],
          );
        },
      );
      return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final BudgetBuddyState state = ref.watch(budgetBuddyControllerProvider);
    final List<ExpenseEntry> expenses = _filteredExpenses(state);
    final DateTime today =
        ref.watch(budgetBuddyControllerProvider.notifier).now;
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final _ExpensePalette palette = _ExpensePalette(isDark);

    final List<DateTime> availableMonths =
        _availableMonths(state, expenses, today);
    final List<ExpenseEntry> todayExpenses =
        _sortExpenses(_expensesForDay(expenses, today));

    final DateTime todayDay = DateTime(today.year, today.month, today.day);
    final Set<DateTime> pastDaysSet = <DateTime>{};
    for (final DailyRecord record in state.dailyRecords) {
      final DateTime rDate =
          DateTime(record.date.year, record.date.month, record.date.day);
      if (rDate.isBefore(todayDay)) {
        pastDaysSet.add(rDate);
      }
    }
    for (final ExpenseEntry expense in expenses) {
      final DateTime eDate = DateTime(
          expense.dateTime.year, expense.dateTime.month, expense.dateTime.day);
      if (eDate.isBefore(todayDay)) {
        pastDaysSet.add(eDate);
      }
    }
    final List<DateTime> pastDays = pastDaysSet.toList()
      ..sort((DateTime left, DateTime right) => right.compareTo(left));

    // Daily Metrics
    final double currentBudget = widget.isTogetherOnly
        ? state.togetherBudget
        : (state.settings.dailyLimit ?? 0);
    final double todayTotal = todayExpenses.fold<double>(
        0, (double sum, ExpenseEntry e) => sum + e.amount);
    final double dailyRemaining = currentBudget - todayTotal;
    final bool isDailyOver = dailyRemaining < 0;

    // Monthly Metrics
    final DateTime monthStart = DateTime(today.year, today.month);
    final DateTime nextMonthStart = DateTime(today.year, today.month + 1);
    final List<ExpenseEntry> currentMonthExpenses =
        _expensesForMonth(expenses, today);
    final double monthTotal = currentMonthExpenses.fold<double>(
        0, (double sum, ExpenseEntry e) => sum + e.amount);
    final double trackedMonthlyBudget = widget.isTogetherOnly
        ? state.togetherBudget
        : state.budgetEntries
            .where((BudgetEntry entry) =>
                !entry.date.isBefore(monthStart) &&
                entry.date.isBefore(nextMonthStart))
            .fold(
                0.0, (double total, BudgetEntry entry) => total + entry.amount);
    final double monthlyBudget = trackedMonthlyBudget > 0
        ? trackedMonthlyBudget
        : ((state.settings.monthlyBudget ?? 0) > 0
            ? (state.settings.monthlyBudget ?? 0)
            : (currentBudget * 30));
    final double monthlyRemaining = monthlyBudget - monthTotal;
    final bool isMonthlyOver = monthlyRemaining < 0;

    final bool hasBudget = widget.isTogetherOnly
        ? state.togetherBudget > 0
        : state.settings.totalDailyBudget > 0;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              // Back Button (If pushed from another screen)
              if (Navigator.of(context).canPop()) ...<Widget>[
                FilledButton.tonalIcon(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.arrow_back_rounded, size: 16),
                  label: Text(
                    widget.isTogetherOnly ? 'Back to Budget Together' : 'Back',
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 12),
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

              // 1. Compact Header matching Daily Budget, Spend, and Savings
              _buildHeader(
                context,
                currentClock: today,
                hasBudget: hasBudget,
                isOver: _activeSection == ExpenseSection.daily
                    ? isDailyOver
                    : isMonthlyOver,
                palette: palette,
              ),
              const SizedBox(height: 12),

              // 2. Main Content
              Expanded(
                child: ListView(
                  padding: EdgeInsets.zero,
                  children: <Widget>[
                    // Overview Card (with 3 Solid Metric Tiles: Gold, Dark Red, Dark Green)
                    _buildOverviewCard(
                      context,
                      currentBudget: currentBudget,
                      todayTotal: todayTotal,
                      dailyRemaining: dailyRemaining,
                      isDailyOver: isDailyOver,
                      monthlyBudget: monthlyBudget,
                      monthTotal: monthTotal,
                      monthlyRemaining: monthlyRemaining,
                      isMonthlyOver: isMonthlyOver,
                      hasBudget: hasBudget,
                      palette: palette,
                    ),
                    const SizedBox(height: 12),

                    // Sleek Daily / Monthly Toggle
                    _buildSectionToggle(context, palette),
                    const SizedBox(height: 12),

                    // Active Section Content
                    if (_activeSection == ExpenseSection.daily) ...<Widget>[
                      // Today's Expenses Card
                      _buildTodayExpensesCard(
                        context,
                        todayExpenses: todayExpenses,
                        palette: palette,
                      ),
                      const SizedBox(height: 12),

                      // Daily History Card
                      _buildDailyHistoryCard(
                        context,
                        pastDays: pastDays,
                        expenses: expenses,
                        palette: palette,
                      ),
                    ] else ...<Widget>[
                      // Monthly Records Card
                      _buildMonthlyRecordsCard(
                        context,
                        availableMonths: availableMonths,
                        expenses: expenses,
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

  /// Compact header without redundant subtitles or duplicate pills
  Widget _buildHeader(
    BuildContext context, {
    required DateTime currentClock,
    required bool hasBudget,
    required bool isOver,
    required _ExpensePalette palette,
  }) {
    final Color statusColor = !hasBudget
        ? palette.darkRed
        : (isOver ? palette.darkRed : palette.darkGreen);
    final Color statusBg = !hasBudget
        ? palette.darkRedBg
        : (isOver ? palette.darkRedBg : palette.darkGreenBg);
    final Color statusBorder = !hasBudget
        ? palette.darkRedBorder
        : (isOver ? palette.darkRedBorder : palette.darkGreenBorder);
    final IconData statusIcon = !hasBudget
        ? Icons.warning_amber_rounded
        : (isOver ? Icons.trending_down_rounded : Icons.check_circle_rounded);
    final String statusLabel =
        !hasBudget ? 'No Budget Set' : (isOver ? 'Over Budget' : 'On Track');

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: <Widget>[
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              widget.isTogetherOnly ? 'Together Expenses' : 'Expenses',
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

  /// Compact Overview Card with the 3 Solid Metric Tiles (Gold, Dark Red, Dark Green)
  Widget _buildOverviewCard(
    BuildContext context, {
    required double currentBudget,
    required double todayTotal,
    required double dailyRemaining,
    required bool isDailyOver,
    required double monthlyBudget,
    required double monthTotal,
    required double monthlyRemaining,
    required bool isMonthlyOver,
    required bool hasBudget,
    required _ExpensePalette palette,
  }) {
    final ThemeData theme = Theme.of(context);
    final bool isDaily = _activeSection == ExpenseSection.daily;

    final double activeBudget = isDaily ? currentBudget : monthlyBudget;
    final double activeSpent = isDaily ? todayTotal : monthTotal;
    final double activeRemaining = isDaily ? dailyRemaining : monthlyRemaining;
    final bool isOver = isDaily ? isDailyOver : isMonthlyOver;

    final double progressValue =
        activeBudget > 0 ? (activeSpent / activeBudget).clamp(0.0, 1.0) : 0.0;

    final Color barColor = isOver ? palette.darkRed : palette.darkGreen;
    final Color badgeColor = isOver ? palette.darkRed : palette.darkGreen;
    final Color badgeBg = isOver ? palette.darkRedBg : palette.darkGreenBg;
    final Color badgeBorder =
        isOver ? palette.darkRedBorder : palette.darkGreenBorder;

    final String badgeLabel = !hasBudget
        ? 'Unset'
        : isOver
            ? 'Over by ${formatPeso(activeRemaining.abs())}'
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
                  Icon(
                    Icons.analytics_rounded,
                    size: 16,
                    color: palette.darkGreen,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    isDaily
                        ? 'Daily Expense Overview'
                        : 'Monthly Expense Overview',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
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

          // Linear Progress Bar
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

          // 3 Compact Metric Tiles: Budget (Gold), Spent (Dark Red), Remaining (Green/Red)
          Row(
            children: <Widget>[
              Expanded(
                child: _CompactMetricTile(
                  label: isDaily ? 'Budget' : 'Month Budget',
                  value: formatPeso(activeBudget),
                  bgColor: palette.gold,
                  icon: Icons.account_balance_wallet_rounded,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _CompactMetricTile(
                  label: isDaily ? 'Spent' : 'Month Spent',
                  value: formatPeso(activeSpent),
                  bgColor: palette.darkRed,
                  icon: Icons.shopping_bag_rounded,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _CompactMetricTile(
                  label: isOver ? 'Over' : 'Remaining',
                  value: formatPeso(activeRemaining.abs()),
                  bgColor: isOver ? palette.darkRed : palette.darkGreen,
                  icon: isOver
                      ? Icons.warning_amber_rounded
                      : Icons.savings_rounded,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Sleek segmented Daily / Monthly toggle matching app style
  Widget _buildSectionToggle(BuildContext context, _ExpensePalette palette) {
    final ThemeData theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () {
                if (_activeSection != ExpenseSection.daily) {
                  setState(() => _activeSection = ExpenseSection.daily);
                }
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 9),
                decoration: BoxDecoration(
                  color: _activeSection == ExpenseSection.daily
                      ? palette.darkGreen
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: _activeSection == ExpenseSection.daily
                      ? <BoxShadow>[
                          BoxShadow(
                            color: palette.darkGreen.withValues(alpha: 0.35),
                            blurRadius: 4,
                            offset: const Offset(0, 1),
                          ),
                        ]
                      : null,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    Icon(
                      Icons.calendar_today_rounded,
                      size: 14,
                      color: _activeSection == ExpenseSection.daily
                          ? Colors.white
                          : theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Daily',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: _activeSection == ExpenseSection.daily
                            ? FontWeight.w700
                            : FontWeight.w600,
                        color: _activeSection == ExpenseSection.daily
                            ? Colors.white
                            : theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () {
                if (_activeSection != ExpenseSection.monthly) {
                  setState(() => _activeSection = ExpenseSection.monthly);
                }
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 9),
                decoration: BoxDecoration(
                  color: _activeSection == ExpenseSection.monthly
                      ? palette.darkGreen
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: _activeSection == ExpenseSection.monthly
                      ? <BoxShadow>[
                          BoxShadow(
                            color: palette.darkGreen.withValues(alpha: 0.35),
                            blurRadius: 4,
                            offset: const Offset(0, 1),
                          ),
                        ]
                      : null,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    Icon(
                      Icons.calendar_month_rounded,
                      size: 14,
                      color: _activeSection == ExpenseSection.monthly
                          ? Colors.white
                          : theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Monthly',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: _activeSection == ExpenseSection.monthly
                            ? FontWeight.w700
                            : FontWeight.w600,
                        color: _activeSection == ExpenseSection.monthly
                            ? Colors.white
                            : theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Today's Expenses card in Daily view
  Widget _buildTodayExpensesCard(
    BuildContext context, {
    required List<ExpenseEntry> todayExpenses,
    required _ExpensePalette palette,
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
          // Header Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Icon(Icons.today_rounded, size: 16, color: palette.darkGreen),
                  const SizedBox(width: 6),
                  Text(
                    'Today\'s Expenses',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
              Row(
                children: <Widget>[
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: palette.goldBg,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: palette.goldBorder),
                    ),
                    child: Text(
                      '${todayExpenses.length} logged',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: palette.gold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () => _showExpenseDialog(ref),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: palette.darkGreenBg,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: palette.darkGreenBorder),
                      ),
                      child: Row(
                        children: <Widget>[
                          Icon(Icons.add_rounded,
                              size: 14, color: palette.darkGreen),
                          const SizedBox(width: 2),
                          Text(
                            'Add',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: palette.darkGreen,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),

          if (todayExpenses.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: palette.goldBg,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: palette.goldBorder),
              ),
              child: Row(
                children: <Widget>[
                  Icon(
                    widget.isTogetherOnly
                        ? Icons.group_outlined
                        : Icons.calendar_today_rounded,
                    color: palette.gold,
                    size: 18,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      widget.isTogetherOnly
                          ? 'No Budget Together expenses logged today.'
                          : 'No expenses logged for today yet.',
                      style: TextStyle(
                        color: palette.gold,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Text(
                    '₱0',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                      color: palette.gold,
                    ),
                  ),
                ],
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: todayExpenses.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (BuildContext context, int index) {
                final ExpenseEntry expense = todayExpenses[index];
                return _buildExpenseTile(
                  context,
                  expense: expense,
                  palette: palette,
                  onEdit: () => _showExpenseDialog(ref, existing: expense),
                  onDelete: () async {
                    final bool shouldDelete =
                        await _confirmDeleteExpense(context, palette);
                    if (!mounted || !shouldDelete) return;
                    ref
                        .read(budgetBuddyControllerProvider.notifier)
                        .deleteExpense(expense.id);
                  },
                  onDetails: () => _showExpenseDetails(ref, expense, palette),
                );
              },
            ),
        ],
      ),
    );
  }

  /// Daily History card containing past days in Daily view
  Widget _buildDailyHistoryCard(
    BuildContext context, {
    required List<DateTime> pastDays,
    required List<ExpenseEntry> expenses,
    required _ExpensePalette palette,
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Icon(Icons.history_rounded, size: 16, color: palette.gold),
                  const SizedBox(width: 6),
                  Text(
                    'Daily History',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: palette.goldBg,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: palette.goldBorder),
                ),
                child: Text(
                  '${pastDays.length} past days',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: palette.gold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (pastDays.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: Text(
                  'No past expense history yet.',
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            )
          else
            ...pastDays.map((DateTime day) {
              final List<ExpenseEntry> dayExpenses =
                  _expensesForDay(expenses, day);
              final double dayTotal = dayExpenses.fold<double>(
                  0, (double sum, ExpenseEntry e) => sum + e.amount);
              final bool isZero = dayExpenses.isEmpty;

              final Color accent = isZero ? palette.gold : palette.darkRed;
              final Color accentBg =
                  isZero ? palette.goldBg : palette.darkRedBg;
              final Color accentBorder =
                  isZero ? palette.goldBorder : palette.darkRedBorder;

              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () => _showDayExpensesSheet(
                    ref,
                    day,
                    expenses,
                    palette,
                    showBackButton: true,
                  ),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest
                          .withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: theme.colorScheme.outlineVariant
                            .withValues(alpha: 0.25),
                      ),
                    ),
                    child: Row(
                      children: <Widget>[
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: accentBg,
                            shape: BoxShape.circle,
                            border: Border.all(color: accentBorder),
                          ),
                          child: Icon(
                            isZero
                                ? Icons.calendar_today_rounded
                                : Icons.receipt_long_rounded,
                            color: accent,
                            size: 16,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                _formatDayLabel(day),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                isZero
                                    ? 'No budget and expenses'
                                    : '${dayExpenses.length} expense${dayExpenses.length == 1 ? '' : 's'}',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: accentBg,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: accentBorder),
                          ),
                          child: Text(
                            isZero ? '₱0' : formatPeso(dayTotal),
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 12,
                              color: accent,
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          Icons.chevron_right_rounded,
                          size: 18,
                          color: theme.colorScheme.onSurfaceVariant
                              .withValues(alpha: 0.5),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }

  /// Monthly Records card in Monthly view
  Widget _buildMonthlyRecordsCard(
    BuildContext context, {
    required List<DateTime> availableMonths,
    required List<ExpenseEntry> expenses,
    required _ExpensePalette palette,
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Icon(Icons.calendar_month_rounded,
                      size: 16, color: palette.gold),
                  const SizedBox(width: 6),
                  Text(
                    'Monthly Records',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: palette.goldBg,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: palette.goldBorder),
                ),
                child: Text(
                  '${availableMonths.length} months',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: palette.gold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (availableMonths.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text(
                  widget.isTogetherOnly
                      ? 'No Budget Together expenses recorded yet.'
                      : 'No monthly expense records yet.',
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            )
          else
            ...availableMonths.map((DateTime month) {
              final List<ExpenseEntry> monthExpenses = expenses
                  .where((ExpenseEntry expense) =>
                      expense.dateTime.year == month.year &&
                      expense.dateTime.month == month.month)
                  .toList();
              final double total = monthExpenses.fold<double>(
                  0,
                  (double value, ExpenseEntry expense) =>
                      value + expense.amount);
              final bool isZero = monthExpenses.isEmpty;

              final Color accent = isZero ? palette.gold : palette.darkRed;
              final Color accentBg =
                  isZero ? palette.goldBg : palette.darkRedBg;
              final Color accentBorder =
                  isZero ? palette.goldBorder : palette.darkRedBorder;

              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () =>
                      _showMonthDatesSheet(ref, month, expenses, palette),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest
                          .withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: theme.colorScheme.outlineVariant
                            .withValues(alpha: 0.25),
                      ),
                    ),
                    child: Row(
                      children: <Widget>[
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: accentBg,
                            shape: BoxShape.circle,
                            border: Border.all(color: accentBorder),
                          ),
                          child: Icon(
                            isZero
                                ? Icons.calendar_today_rounded
                                : Icons.date_range_rounded,
                            color: accent,
                            size: 16,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                DateFormat('MMMM yyyy').format(month),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                isZero
                                    ? 'No expenses this month'
                                    : '${monthExpenses.length} expense${monthExpenses.length == 1 ? '' : 's'} tracked',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: accentBg,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: accentBorder),
                          ),
                          child: Text(
                            isZero ? '₱0' : formatPeso(total),
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 12,
                              color: accent,
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          Icons.chevron_right_rounded,
                          size: 18,
                          color: theme.colorScheme.onSurfaceVariant
                              .withValues(alpha: 0.5),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }

  /// Modern expense item tile with compact Edit, Delete, Details actions
  Widget _buildExpenseTile(
    BuildContext context, {
    required ExpenseEntry expense,
    required _ExpensePalette palette,
    required VoidCallback onEdit,
    required VoidCallback onDelete,
    required VoidCallback onDetails,
  }) {
    final ThemeData theme = Theme.of(context);
    final String displayNote = _cleanNote(expense.note);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color:
            theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.25),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: expense.category.color.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _expenseIconForExpense(expense),
                  color: expense.category.color,
                  size: 16,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      expense.title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      displayNote.isNotEmpty
                          ? '${expense.category.label} • $displayNote'
                          : expense.category.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: palette.darkRedBg,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: palette.darkRedBorder),
                ),
                child: Text(
                  formatPeso(expense.amount),
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                    color: palette.darkRed,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Action Buttons: Edit, Delete, Details
          Row(
            children: <Widget>[
              Expanded(
                child: FilledButton.tonal(
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    visualDensity: VisualDensity.compact,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: onEdit,
                  child: const Text('Edit',
                      style:
                          TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: FilledButton.tonal(
                  style: FilledButton.styleFrom(
                    backgroundColor: palette.darkRedBg,
                    foregroundColor: palette.darkRed,
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    visualDensity: VisualDensity.compact,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: onDelete,
                  child: const Text('Delete',
                      style:
                          TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: FilledButton.tonal(
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    visualDensity: VisualDensity.compact,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: onDetails,
                  child: const Text('Details',
                      style:
                          TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  List<ExpenseEntry> _filteredExpenses(BudgetBuddyState state) {
    final List<ExpenseEntry> filtered =
        state.expenses.where((ExpenseEntry expense) {
      if (widget.isTogetherOnly) {
        if (expense.source != 'togetherSpend') {
          return false;
        }
      } else {
        if (expense.source == 'togetherSpend') {
          return false;
        }
      }
      if (state.currentExpenseFilter != null &&
          expense.category != state.currentExpenseFilter) {
        return false;
      }
      return true;
    }).toList();
    return _sortExpenses(filtered);
  }

  List<DateTime> _availableMonths(
      BudgetBuddyState state, List<ExpenseEntry> expenses, DateTime today) {
    final Set<DateTime> months = <DateTime>{};
    months.add(DateTime(today.year, today.month));
    for (final ExpenseEntry expense in expenses) {
      months.add(DateTime(expense.dateTime.year, expense.dateTime.month));
    }
    for (final DailyRecord record in state.dailyRecords) {
      months.add(DateTime(record.date.year, record.date.month));
    }
    final List<DateTime> sortedMonths = months.toList()
      ..sort((DateTime left, DateTime right) => right.compareTo(left));
    return sortedMonths;
  }

  List<ExpenseEntry> _expensesForDay(
      List<ExpenseEntry> expenses, DateTime day) {
    return expenses
        .where((ExpenseEntry expense) =>
            DateUtils.isSameDay(expense.dateTime, day))
        .toList();
  }

  List<ExpenseEntry> _expensesForMonth(
      List<ExpenseEntry> expenses, DateTime month) {
    return expenses
        .where((ExpenseEntry expense) =>
            expense.dateTime.year == month.year &&
            expense.dateTime.month == month.month)
        .toList();
  }

  List<ExpenseEntry> _sortExpenses(List<ExpenseEntry> expenses) {
    final List<ExpenseEntry> sorted = List<ExpenseEntry>.from(expenses);
    sorted.sort((ExpenseEntry left, ExpenseEntry right) =>
        right.dateTime.compareTo(left.dateTime));
    return sorted;
  }

  Future<void> _showMonthDatesSheet(
    WidgetRef ref,
    DateTime month,
    List<ExpenseEntry> expenses,
    _ExpensePalette palette,
  ) async {
    final BuildContext localContext = context;
    final BudgetBuddyState state = ref.read(budgetBuddyControllerProvider);
    final List<ExpenseEntry> monthExpenses = _expensesForMonth(expenses, month);

    final DateTime monthStart = DateTime(month.year, month.month);
    final DateTime nextMonthStart = DateTime(month.year, month.month + 1);
    final List<DateTime> monthDays = <DateTime>[];
    for (DateTime day = nextMonthStart.subtract(const Duration(days: 1));
        !day.isBefore(monthStart);
        day = day.subtract(const Duration(days: 1))) {
      monthDays.add(day);
    }
    final double totalMonthlyBudget = widget.isTogetherOnly
        ? state.togetherBudget
        : state.budgetEntries
            .where((BudgetEntry entry) =>
                !entry.date.isBefore(monthStart) &&
                entry.date.isBefore(nextMonthStart))
            .fold(0, (double total, BudgetEntry entry) => total + entry.amount);
    final double totalMonthlyExpenses = monthExpenses.fold(
        0, (double total, ExpenseEntry expense) => total + expense.amount);
    final bool isSaved = totalMonthlyBudget >= totalMonthlyExpenses;

    await showModalBottomSheet<void>(
      context: localContext,
      isScrollControlled: true,
      showDragHandle: false,
      enableDrag: false,
      isDismissible: false,
      backgroundColor: Colors.transparent,
      builder: (BuildContext sheetContext) {
        final ThemeData theme = Theme.of(sheetContext);

        return Container(
          decoration: BoxDecoration(
            color: theme.scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SafeArea(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(sheetContext).size.height * 0.78,
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    // Header Row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: <Widget>[
                        FilledButton.tonalIcon(
                          onPressed: () => Navigator.of(sheetContext).pop(),
                          icon: const Icon(Icons.arrow_back_rounded, size: 16),
                          label: const Text(
                            'Back',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                          style: FilledButton.styleFrom(
                            backgroundColor: palette.darkGreenBg,
                            foregroundColor: palette.darkGreen,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            visualDensity: VisualDensity.compact,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                        Text(
                          DateFormat('MMMM yyyy').format(month),
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Month Summary Card
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color:
                            isSaved ? palette.darkGreenBg : palette.darkRedBg,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isSaved
                              ? palette.darkGreenBorder
                              : palette.darkRedBorder,
                        ),
                      ),
                      child: Column(
                        children: <Widget>[
                          Row(
                            children: <Widget>[
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: <Widget>[
                                    Text(
                                      'MONTH BUDGET',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w800,
                                        color: palette.gold,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      formatPeso(totalMonthlyBudget),
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w900,
                                        color: theme.colorScheme.onSurface,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: <Widget>[
                                    Text(
                                      'EXPENSES',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w800,
                                        color: palette.darkRed,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      formatPeso(totalMonthlyExpenses),
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w900,
                                        color: palette.darkRed,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: isSaved
                                    ? palette.darkGreen
                                    : palette.darkRed,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                isSaved ? 'SAVED' : 'OVER BUDGET',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.4,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Days List Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: <Widget>[
                        Row(
                          children: <Widget>[
                            Icon(Icons.calendar_today_rounded,
                                size: 14, color: palette.gold),
                            const SizedBox(width: 6),
                            Text(
                              'Days in this Month',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: theme.colorScheme.onSurface,
                              ),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: palette.goldBg,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: palette.goldBorder),
                          ),
                          child: Text(
                            '${monthDays.length} days',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: palette.gold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // Days List
                    Expanded(
                      child: ListView.separated(
                        itemCount: monthDays.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (BuildContext ctx, int index) {
                          final DateTime day = monthDays[index];
                          final List<ExpenseEntry> dayExpenses = monthExpenses
                              .where((ExpenseEntry expense) =>
                                  DateUtils.isSameDay(expense.dateTime, day))
                              .toList();
                          final double dayTotal = dayExpenses.fold<double>(
                              0,
                              (double total, ExpenseEntry expense) =>
                                  total + expense.amount);
                          final bool isZero = dayExpenses.isEmpty;

                          final Color accent =
                              isZero ? palette.gold : palette.darkRed;
                          final Color accentBg =
                              isZero ? palette.goldBg : palette.darkRedBg;
                          final Color accentBorder = isZero
                              ? palette.goldBorder
                              : palette.darkRedBorder;

                          return InkWell(
                            borderRadius: BorderRadius.circular(14),
                            onTap: () async => await _showDayExpensesSheet(
                              ref,
                              day,
                              expenses,
                              palette,
                              showBackButton: true,
                            ),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 10),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.surfaceContainerHighest
                                    .withValues(alpha: 0.35),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: theme.colorScheme.outlineVariant
                                      .withValues(alpha: 0.25),
                                ),
                              ),
                              child: Row(
                                children: <Widget>[
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: accentBg,
                                      shape: BoxShape.circle,
                                      border: Border.all(color: accentBorder),
                                    ),
                                    child: Icon(
                                      isZero
                                          ? Icons.calendar_today_rounded
                                          : Icons.receipt_long_rounded,
                                      color: accent,
                                      size: 16,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: <Widget>[
                                        Text(
                                          _formatDayLabel(day),
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 13,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          isZero
                                              ? 'No activity'
                                              : '${dayExpenses.length} expense${dayExpenses.length == 1 ? '' : 's'}',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: theme
                                                .colorScheme.onSurfaceVariant,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: accentBg,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: accentBorder),
                                    ),
                                    child: Text(
                                      isZero ? '₱0' : formatPeso(dayTotal),
                                      style: TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 12,
                                        color: accent,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Icon(
                                    Icons.chevron_right_rounded,
                                    size: 18,
                                    color: theme.colorScheme.onSurfaceVariant
                                        .withValues(alpha: 0.5),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _showDayExpensesSheet(
    WidgetRef ref,
    DateTime day,
    List<ExpenseEntry> expenses,
    _ExpensePalette palette, {
    bool showBackButton = false,
  }) async {
    final BuildContext localContext = context;
    final List<ExpenseEntry> dayExpenses = _expensesForDay(expenses, day);
    final double dayTotal = dayExpenses.fold<double>(
        0, (double sum, ExpenseEntry e) => sum + e.amount);

    final ExpenseEntry? editExpense = await showModalBottomSheet<ExpenseEntry>(
      context: localContext,
      isScrollControlled: true,
      showDragHandle: false,
      enableDrag: false,
      isDismissible: false,
      backgroundColor: Colors.transparent,
      builder: (BuildContext sheetContext) {
        final ThemeData theme = Theme.of(sheetContext);

        return Container(
          decoration: BoxDecoration(
            color: theme.scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SafeArea(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(sheetContext).size.height * 0.78,
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    // Header Row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: <Widget>[
                        FilledButton.tonalIcon(
                          onPressed: () => Navigator.of(sheetContext).pop(),
                          icon: const Icon(Icons.arrow_back_rounded, size: 16),
                          label: const Text(
                            'Back',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                          style: FilledButton.styleFrom(
                            backgroundColor: palette.darkGreenBg,
                            foregroundColor: palette.darkGreen,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            visualDensity: VisualDensity.compact,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                        Text(
                          DateFormat('EEEE, MMM d, yyyy').format(day),
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Day Total Spent Card
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: palette.darkRedBg,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: palette.darkRedBorder),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: <Widget>[
                              Text(
                                'Total Spent on this Day',
                                style: TextStyle(
                                  color: palette.darkRed,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 12,
                                ),
                              ),
                              Icon(
                                Icons.receipt_long_rounded,
                                color: palette.darkRed,
                                size: 16,
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            formatPeso(dayTotal),
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              color: palette.darkRed,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${dayExpenses.length} expense${dayExpenses.length == 1 ? '' : 's'} logged',
                            style: TextStyle(
                              fontSize: 12,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Expenses List
                    if (dayExpenses.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 32),
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              Icon(
                                Icons.calendar_today_rounded,
                                size: 36,
                                color: palette.gold,
                              ),
                              const SizedBox(height: 10),
                              Text(
                                'No expenses logged for this day',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: theme.colorScheme.onSurface,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '₱0 spent',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      Expanded(
                        child: ListView.separated(
                          itemCount: dayExpenses.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 8),
                          itemBuilder: (BuildContext context, int index) {
                            final ExpenseEntry expense = dayExpenses[index];
                            return _buildExpenseTile(
                              context,
                              expense: expense,
                              palette: palette,
                              onEdit: () =>
                                  Navigator.of(sheetContext).pop(expense),
                              onDelete: () async {
                                final bool shouldDelete =
                                    await _confirmDeleteExpense(
                                        context, palette);
                                if (!mounted ||
                                    !sheetContext.mounted ||
                                    !shouldDelete) {
                                  return;
                                }
                                ref
                                    .read(
                                        budgetBuddyControllerProvider.notifier)
                                    .deleteExpense(expense.id);
                                Navigator.of(sheetContext).pop();
                              },
                              onDetails: () async {
                                await _showExpenseDetails(
                                    ref, expense, palette);
                              },
                            );
                          },
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );

    if (editExpense != null) {
      if (!mounted) return;
      await _showExpenseDialog(ref, existing: editExpense);
    }
  }

  Future<void> _showExpenseDialog(
    WidgetRef ref, {
    ExpenseEntry? existing,
  }) async {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final _ExpensePalette palette = _ExpensePalette(isDark);

    if (existing == null && !_ensureBudgetSet(context, palette)) return;

    final TextEditingController titleController =
        TextEditingController(text: existing?.title ?? '');
    final TextEditingController amountController =
        TextEditingController(text: existing?.amount.toStringAsFixed(0) ?? '');
    final TextEditingController noteController =
        TextEditingController(text: _cleanNote(existing?.note ?? ''));
    BudgetCategory category = existing?.category ?? BudgetCategory.food;

    final BuildContext localContext = context;
    await showModalBottomSheet<void>(
      context: localContext,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: false,
      enableDrag: false,
      isDismissible: false,
      backgroundColor: Colors.transparent,
      builder: (BuildContext sheetContext) {
        final ThemeData theme = Theme.of(sheetContext);

        return Container(
          decoration: BoxDecoration(
            color: theme.scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Padding(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 14,
              bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 16,
            ),
            child: StatefulBuilder(
              builder: (BuildContext context,
                  void Function(void Function()) setModalState) {
                final BudgetBuddyState state =
                    ref.read(budgetBuddyControllerProvider);
                final BudgetSummary summary = widget.isTogetherOnly
                    ? ref.read(budgetTogetherSummaryProvider)
                    : ref.read(budgetSummaryProvider);
                final double enteredAmount =
                    double.tryParse(amountController.text) ?? 0;
                final double limit = _categoryLimit(category, state.settings);
                final double projectedTotal =
                    _categorySpent(summary, category) + enteredAmount;
                final bool showWarning = limit > 0 && projectedTotal > limit;

                return ListView(
                  shrinkWrap: true,
                  children: <Widget>[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: <Widget>[
                        FilledButton.tonalIcon(
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(Icons.arrow_back_rounded, size: 16),
                          label: const Text(
                            'Back',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                          style: FilledButton.styleFrom(
                            backgroundColor: palette.darkGreenBg,
                            foregroundColor: palette.darkGreen,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            visualDensity: VisualDensity.compact,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                        Text(
                          existing == null
                              ? (widget.isTogetherOnly
                                  ? 'Add Together Expense'
                                  : 'Add Expense')
                              : 'Edit Expense',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: titleController,
                      decoration: InputDecoration(
                        labelText: 'Title',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: amountController,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      onChanged: (_) => setModalState(() {}),
                      decoration: InputDecoration(
                        labelText: 'Amount (₱)',
                        prefixText: '₱ ',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: noteController,
                      maxLines: 2,
                      decoration: InputDecoration(
                        labelText: 'Note (Optional)',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<BudgetCategory>(
                      initialValue: category,
                      decoration: InputDecoration(
                        labelText: 'Category',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      items: BudgetCategory.values
                          .map((BudgetCategory item) =>
                              DropdownMenuItem<BudgetCategory>(
                                value: item,
                                child: Row(
                                  children: <Widget>[
                                    Icon(_expenseCategoryIcon(item),
                                        size: 16, color: item.color),
                                    const SizedBox(width: 8),
                                    Text(item.label),
                                  ],
                                ),
                              ))
                          .toList(),
                      onChanged: (BudgetCategory? value) {
                        if (value != null) {
                          setModalState(() => category = value);
                        }
                      },
                    ),
                    if (showWarning) ...<Widget>[
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: palette.darkRedBg,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: palette.darkRedBorder),
                        ),
                        child: Row(
                          children: <Widget>[
                            Icon(Icons.warning_amber_rounded,
                                size: 16, color: palette.darkRed),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '${category.label} will be ${formatPeso(projectedTotal - limit)} over its limit.',
                                style: TextStyle(
                                  color: palette.darkRed,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(44),
                          backgroundColor: palette.darkGreen,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: () {
                          final BudgetBuddyController controller =
                              ref.read(budgetBuddyControllerProvider.notifier);
                          final String source =
                              existing != null && existing.source.isNotEmpty
                                  ? existing.source
                                  : (widget.isTogetherOnly
                                      ? 'togetherSpend'
                                      : 'manual');
                          final ExpenseEntry entry = ExpenseEntry(
                            id: existing?.id ??
                                DateTime.now()
                                    .microsecondsSinceEpoch
                                    .toString(),
                            title: titleController.text.trim().isEmpty
                                ? 'Expense'
                                : titleController.text.trim(),
                            amount: double.tryParse(amountController.text) ?? 0,
                            category: category,
                            dateTime: existing?.dateTime ?? controller.now,
                            note: noteController.text.trim(),
                            source: source,
                          );
                          if (existing == null) {
                            controller.addExpense(
                              title: entry.title,
                              amount: entry.amount,
                              category: entry.category,
                              note: entry.note,
                              dateTime: entry.dateTime,
                              source: entry.source,
                            );
                          } else {
                            controller.updateExpense(entry);
                          }
                          Navigator.of(context).pop();
                        },
                        child: Text(
                          existing == null ? 'Save Expense' : 'Update Expense',
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }

  Future<void> _showExpenseDetails(
    WidgetRef ref,
    ExpenseEntry expense,
    _ExpensePalette palette,
  ) async {
    final BuildContext localContext = context;

    await showModalBottomSheet<void>(
      context: localContext,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: false,
      enableDrag: false,
      isDismissible: false,
      backgroundColor: Colors.transparent,
      builder: (BuildContext sheetContext) {
        final ThemeData theme = Theme.of(sheetContext);
        final String displayNote = _cleanNote(expense.note);

        return Container(
          decoration: BoxDecoration(
            color: theme.scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SingleChildScrollView(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 16,
              bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 20,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: <Widget>[
                    Text(
                      'Expense Details',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.of(sheetContext).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: palette.darkRedBg,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: palette.darkRedBorder),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        expense.title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        formatPeso(expense.amount),
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: palette.darkRed,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  'Category: ${expense.category.label}',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 6),
                Text(
                  'Date: ${DateFormat('MMMM d, yyyy h:mm a').format(expense.dateTime)}',
                  style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                ),
                if (displayNote.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 8),
                  Text(
                    'Note: $displayNote',
                    style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                  ),
                ],
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => Navigator.of(sheetContext).pop(),
                    style: FilledButton.styleFrom(
                      backgroundColor: palette.darkGreen,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Close'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<bool> _confirmDeleteExpense(
    BuildContext context,
    _ExpensePalette palette,
  ) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Delete expense?'),
          content: const Text('This expense will be removed permanently.'),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              style: TextButton.styleFrom(
                foregroundColor: palette.darkRed,
              ),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              style: FilledButton.styleFrom(
                backgroundColor: palette.darkRed,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
    return confirmed ?? false;
  }

  double _categoryLimit(BudgetCategory category, BudgetSettings settings) {
    return switch (category) {
      BudgetCategory.food => settings.foodBudget,
      BudgetCategory.transportation => settings.transportationBudget,
      BudgetCategory.entertainment => settings.leisureBudget,
      BudgetCategory.shopping => 0,
      BudgetCategory.miscellaneous => 0,
    };
  }

  double _categorySpent(BudgetSummary summary, BudgetCategory category) {
    return summary.categoryTotals[category.label] ?? 0;
  }
}

enum ExpenseSection { daily, monthly }

String _cleanNote(String note) {
  final String trimmed = note.trim();
  if (trimmed.startsWith('[SPEND]')) {
    return trimmed.substring('[SPEND]'.length).trim();
  }
  return trimmed;
}

String _formatDayLabel(DateTime dateTime) {
  final DateTime now = DateTime.now();
  if (DateUtils.isSameDay(dateTime, now)) {
    return 'Today, ${DateFormat('MMMM d, yyyy').format(dateTime)}';
  }
  return DateFormat('EEEE, MMM d, yyyy').format(dateTime);
}

IconData _expenseIconForExpense(ExpenseEntry expense) {
  final String selectedCategory = expense.spendCategory.trim().toLowerCase();
  if (selectedCategory.isNotEmpty) {
    return switch (selectedCategory) {
      'food & drinks' => Icons.restaurant_rounded,
      'transport' => Icons.directions_bus_rounded,
      'shopping' => Icons.shopping_bag_rounded,
      'leisure & gala' => Icons.celebration_rounded,
      'health' => Icons.health_and_safety_rounded,
      'bills & utilities' => Icons.receipt_long_rounded,
      'custom' => Icons.edit_rounded,
      _ => _expenseCategoryIcon(expense.category),
    };
  }

  final String normalizedTitle = expense.title.trim().toLowerCase();
  return switch (normalizedTitle) {
    'food & drinks' => Icons.restaurant_rounded,
    'transport' => Icons.directions_bus_rounded,
    'shopping' => Icons.shopping_bag_rounded,
    'leisure & gala' => Icons.celebration_rounded,
    'health' => Icons.health_and_safety_rounded,
    'bills & utilities' => Icons.receipt_long_rounded,
    'custom' => Icons.edit_rounded,
    _ => _expenseCategoryIcon(expense.category),
  };
}

IconData _expenseCategoryIcon(BudgetCategory category) {
  return switch (category) {
    BudgetCategory.food => Icons.restaurant_rounded,
    BudgetCategory.transportation => Icons.directions_bus_rounded,
    BudgetCategory.entertainment => Icons.celebration_rounded,
    BudgetCategory.shopping => Icons.shopping_bag_rounded,
    BudgetCategory.miscellaneous => Icons.edit_rounded,
  };
}
