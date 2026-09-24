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
      const Color(0xFF991B1B).withValues(alpha: isDark ? 0.22 : 0.12);
  Color get darkRedBorder => const Color(0xFF991B1B).withValues(alpha: 0.30);

  // Gold: target budget amounts, zero-activity badges, history counts, monthly overview
  Color get gold => const Color(0xFFD97706);
  Color get goldBg =>
      const Color(0xFFD97706).withValues(alpha: isDark ? 0.22 : 0.12);
  Color get goldBorder => const Color(0xFFD97706).withValues(alpha: 0.30);

  // Dark Green: remaining safe balance, on-track status, save/update actions
  Color get darkGreen => const Color(0xFF0F766E);
  Color get darkGreenBg =>
      const Color(0xFF0F766E).withValues(alpha: isDark ? 0.22 : 0.12);
  Color get darkGreenBorder => const Color(0xFF0F766E).withValues(alpha: 0.30);
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
              FilledButton.icon(
                onPressed: () => Navigator.of(dialogContext).pop(),
                icon: const Icon(Icons.arrow_back_rounded,
                    size: 14, color: Colors.white),
                label: const Text('Back',
                    style: TextStyle(
                        fontWeight: FontWeight.w700, color: Colors.white)),
                style: FilledButton.styleFrom(
                  backgroundColor: palette.darkRed,
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
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
    const Color statusColor = Colors.white;
    final Color statusBg = !hasBudget
        ? palette.darkRed
        : (isOver ? palette.darkRed : palette.darkGreen);
    final Color statusBorder = !hasBudget
        ? palette.darkRed
        : (isOver ? palette.darkRed : palette.darkGreen);
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
                style: const TextStyle(
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
    const Color badgeColor = Colors.white;
    final Color badgeBg = isOver ? palette.darkRed : palette.darkGreen;
    final Color badgeBorder = isOver ? palette.darkRed : palette.darkGreen;

    final String badgeLabel = !hasBudget
        ? 'Unset'
        : isOver
            ? 'Over by ${formatPeso(activeRemaining.abs())}'
            : '${(progressValue * 100).toInt()}% Used';

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
      child: Stack(
        children: <Widget>[
          Column(
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
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: badgeBg,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: badgeBorder),
                    ),
                    child: Text(
                      badgeLabel,
                      style: const TextStyle(
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
    final Color iconColor = _expenseColorForExpense(expense);
    final IconData iconData = _expenseIconForExpense(expense);
    final String title = _displayTitle(expense);
    final String subtitle = _expenseSubtitleText(expense, displayNote);

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
                  color: iconColor.withValues(alpha: 0.14),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  iconData,
                  color: iconColor,
                  size: 16,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
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

          // Action Buttons: Edit (Full Gold), Delete (Full Dark Red), Details (Full Dark Green)
          Row(
            children: <Widget>[
              Expanded(
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: palette.gold,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    visualDensity: VisualDensity.compact,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: onEdit,
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      Icon(Icons.edit_rounded, size: 13, color: Colors.white),
                      SizedBox(width: 4),
                      Text('Edit',
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Colors.white)),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: palette.darkRed,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    visualDensity: VisualDensity.compact,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: onDelete,
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      Icon(Icons.delete_outline_rounded,
                          size: 13, color: Colors.white),
                      SizedBox(width: 4),
                      Text('Delete',
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Colors.white)),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: palette.darkGreen,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    visualDensity: VisualDensity.compact,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: onDetails,
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      Icon(Icons.info_outline_rounded,
                          size: 13, color: Colors.white),
                      SizedBox(width: 4),
                      Text('Details',
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Colors.white)),
                    ],
                  ),
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
    final List<ExpenseEntry> dayExpenses = expenses
        .where((ExpenseEntry expense) =>
            DateUtils.isSameDay(expense.dateTime, day))
        .toList();
    final Set<String> seenIds = <String>{};
    return dayExpenses.where((ExpenseEntry e) => seenIds.add(e.id)).toList();
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
                        FilledButton.icon(
                          onPressed: () => Navigator.of(sheetContext).pop(),
                          icon: const Icon(Icons.arrow_back_rounded,
                              size: 16, color: Colors.white),
                          label: const Text(
                            'Back',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                              color: Colors.white,
                            ),
                          ),
                          style: FilledButton.styleFrom(
                            backgroundColor: palette.darkGreen,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 8),
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
                        FilledButton.icon(
                          onPressed: () => Navigator.of(sheetContext).pop(),
                          icon: const Icon(Icons.arrow_back_rounded,
                              size: 16, color: Colors.white),
                          label: const Text(
                            'Back',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                              color: Colors.white,
                            ),
                          ),
                          style: FilledButton.styleFrom(
                            backgroundColor: palette.darkGreen,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 8),
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
                        FilledButton.icon(
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(Icons.arrow_back_rounded,
                              size: 16, color: Colors.white),
                          label: const Text(
                            'Back',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                              color: Colors.white,
                            ),
                          ),
                          style: FilledButton.styleFrom(
                            backgroundColor: palette.darkGreen,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 8),
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
                                        size: 16,
                                        color: _spendCategoryColorForCategory(
                                            item)),
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
    final BudgetBuddyState state = ref.read(budgetBuddyControllerProvider);
    final double dailyBudget = widget.isTogetherOnly
        ? state.togetherBudget
        : state.settings.totalDailyBudget;
    final double? percentOfDaily =
        dailyBudget > 0 ? (expense.amount / dailyBudget) * 100 : null;
    final double categoryLimit =
        _categoryLimit(expense.category, state.settings);

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
        final String sourceLabel = _sourceLabel(expense.source);
        final IconData sourceIcon = _sourceIcon(expense.source);
        final Color iconColor = _expenseColorForExpense(expense);
        final IconData iconData = _expenseIconForExpense(expense);
        final String title = _displayTitle(expense);

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
                // Header Row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: <Widget>[
                    FilledButton.icon(
                      onPressed: () => Navigator.of(sheetContext).pop(),
                      icon: const Icon(Icons.arrow_back_rounded,
                          size: 16, color: Colors.white),
                      label: const Text(
                        'Back',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                          color: Colors.white,
                        ),
                      ),
                      style: FilledButton.styleFrom(
                        backgroundColor: palette.darkGreen,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
                        visualDensity: VisualDensity.compact,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    Text(
                      'Expense Details',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Hero Card: Title, Amount, Badges
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: palette.darkRedBg,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: palette.darkRedBorder),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: iconColor.withValues(alpha: 0.16),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              iconData,
                              color: iconColor,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(
                                  title,
                                  style: const TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 4,
                                  children: <Widget>[
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 7, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: palette.goldBg,
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(
                                            color: palette.goldBorder),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: <Widget>[
                                          Icon(sourceIcon,
                                              size: 11, color: palette.gold),
                                          const SizedBox(width: 4),
                                          Text(
                                            sourceLabel,
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w700,
                                              color: palette.gold,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (!_isCategoryDuplicate(
                                        expense.title,
                                        expense.category,
                                        expense.spendCategory))
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 7, vertical: 2),
                                        decoration: BoxDecoration(
                                          color:
                                              iconColor.withValues(alpha: 0.14),
                                          borderRadius:
                                              BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          expense.category.label,
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w700,
                                            color: iconColor,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const Divider(height: 1),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: <Widget>[
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                'Amount Spent',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                formatPeso(expense.amount),
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: -0.5,
                                  color: palette.darkRed,
                                ),
                              ),
                            ],
                          ),
                          if (percentOfDaily != null)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: palette.darkRedBg,
                                borderRadius: BorderRadius.circular(8),
                                border:
                                    Border.all(color: palette.darkRedBorder),
                              ),
                              child: Text(
                                '${percentOfDaily.toStringAsFixed(1)}% of daily',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: palette.darkRed,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // Organized Details Card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: theme.cardTheme.color ?? theme.cardColor,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: theme.colorScheme.outlineVariant
                          .withValues(alpha: 0.3),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          Icon(Icons.format_list_bulleted_rounded,
                              size: 15, color: palette.gold),
                          const SizedBox(width: 6),
                          Text(
                            'Transaction Information',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Divider(height: 1),
                      _buildDetailRow(
                        theme: theme,
                        icon: Icons.calendar_today_rounded,
                        iconColor: palette.gold,
                        label: 'Date',
                        value: DateFormat('EEEE, MMM d, yyyy')
                            .format(expense.dateTime),
                      ),
                      const Divider(height: 1),
                      _buildDetailRow(
                        theme: theme,
                        icon: Icons.access_time_rounded,
                        iconColor: palette.gold,
                        label: 'Time',
                        value: DateFormat('h:mm a').format(expense.dateTime),
                      ),
                      const Divider(height: 1),
                      _buildDetailRow(
                        theme: theme,
                        icon: iconData,
                        iconColor: iconColor,
                        label: 'Category',
                        value: expense.category.label,
                        valueColor: iconColor,
                      ),
                      if (expense.spendCategory.trim().isNotEmpty) ...<Widget>[
                        const Divider(height: 1),
                        _buildDetailRow(
                          theme: theme,
                          icon: _expenseIconForExpense(expense),
                          iconColor: palette.darkGreen,
                          label: 'Spend Tag',
                          value: expense.spendCategory.trim(),
                        ),
                      ],
                      if (categoryLimit > 0) ...<Widget>[
                        const Divider(height: 1),
                        _buildDetailRow(
                          theme: theme,
                          icon: Icons.pie_chart_outline_rounded,
                          iconColor: palette.gold,
                          label: 'Category Budget',
                          value: formatPeso(categoryLimit),
                        ),
                      ],
                      const Divider(height: 1),
                      _buildDetailRow(
                        theme: theme,
                        icon: sourceIcon,
                        iconColor: palette.darkGreen,
                        label: 'Logged Via',
                        value: sourceLabel,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // Note / Remarks Card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: theme.cardTheme.color ?? theme.cardColor,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: theme.colorScheme.outlineVariant
                          .withValues(alpha: 0.3),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          Icon(Icons.notes_rounded,
                              size: 15, color: palette.gold),
                          const SizedBox(width: 6),
                          Text(
                            'Remarks / Note',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        displayNote.isNotEmpty
                            ? displayNote
                            : 'No remarks added for this expense.',
                        style: TextStyle(
                          fontSize: 12,
                          fontStyle: displayNote.isEmpty
                              ? FontStyle.italic
                              : FontStyle.normal,
                          color: displayNote.isNotEmpty
                              ? theme.colorScheme.onSurface
                              : theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),

                // Bottom Action Buttons: Edit, Delete, Done
                Row(
                  children: <Widget>[
                    Expanded(
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: palette.gold,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        onPressed: () {
                          Navigator.of(sheetContext).pop();
                          _showExpenseDialog(ref, existing: expense);
                        },
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: <Widget>[
                            Icon(Icons.edit_rounded,
                                size: 14, color: Colors.white),
                            SizedBox(width: 4),
                            Text('Edit',
                                style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: palette.darkRed,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        onPressed: () async {
                          Navigator.of(sheetContext).pop();
                          final bool shouldDelete =
                              await _confirmDeleteExpense(context, palette);
                          if (!mounted || !shouldDelete) return;
                          ref
                              .read(budgetBuddyControllerProvider.notifier)
                              .deleteExpense(expense.id);
                        },
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: <Widget>[
                            Icon(Icons.delete_outline_rounded,
                                size: 14, color: Colors.white),
                            SizedBox(width: 4),
                            Text('Delete',
                                style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDetailRow({
    required ThemeData theme,
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
    Color? valueColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: <Widget>[
          Container(
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 13, color: iconColor),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: valueColor ?? theme.colorScheme.onSurface,
            ),
          ),
        ],
      ),
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
            FilledButton.icon(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              icon: const Icon(Icons.arrow_back_rounded,
                  size: 14, color: Colors.white),
              label: const Text('Back',
                  style: TextStyle(
                      fontWeight: FontWeight.w700, color: Colors.white)),
              style: FilledButton.styleFrom(
                backgroundColor: palette.darkGreen,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            FilledButton.icon(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              icon: const Icon(Icons.delete_outline_rounded,
                  size: 14, color: Colors.white),
              label: const Text('Delete',
                  style: TextStyle(
                      fontWeight: FontWeight.w700, color: Colors.white)),
              style: FilledButton.styleFrom(
                backgroundColor: palette.darkRed,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
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
  final String key =
      (expense.spendCategory.isNotEmpty ? expense.spendCategory : expense.title)
          .trim()
          .toLowerCase();

  if (key.contains('transport')) {
    return Icons.directions_bus_rounded;
  }
  if (key.contains('food') || key.contains('drink')) {
    return Icons.restaurant_rounded;
  }
  if (key.contains('shop')) {
    return Icons.shopping_bag_rounded;
  }
  if (key.contains('leisure') ||
      key.contains('gala') ||
      key.contains('entertain')) {
    return Icons.celebration_rounded;
  }
  if (key.contains('health') || key.contains('medic')) {
    return Icons.health_and_safety_rounded;
  }
  if (key.contains('bill') || key.contains('utilit')) {
    return Icons.receipt_long_rounded;
  }
  if (key.contains('custom')) {
    return Icons.edit_rounded;
  }

  return _expenseCategoryIcon(expense.category);
}

Color _expenseColorForExpense(ExpenseEntry expense) {
  final String key =
      (expense.spendCategory.isNotEmpty ? expense.spendCategory : expense.title)
          .trim()
          .toLowerCase();

  if (key.contains('transport')) {
    return const Color(0xFF0F766E); // Dark Green (Spend screen Transport)
  }
  if (key.contains('food') || key.contains('drink')) {
    return const Color(0xFFD97706); // Gold (Spend screen Food & Drinks)
  }
  if (key.contains('shop')) {
    return const Color(0xFF991B1B); // Dark Red (Spend screen Shopping)
  }
  if (key.contains('leisure') ||
      key.contains('gala') ||
      key.contains('entertain')) {
    return const Color(0xFFD97706); // Gold (Spend screen Leisure & Gala)
  }
  if (key.contains('health') || key.contains('medic')) {
    return const Color(0xFF0F766E); // Dark Green (Spend screen Health)
  }
  if (key.contains('bill') || key.contains('utilit')) {
    return const Color(0xFF991B1B); // Dark Red (Spend screen Bills & Utilities)
  }
  if (key.contains('custom')) {
    return const Color(0xFF0F766E); // Dark Green
  }

  return _spendCategoryColorForCategory(expense.category);
}

Color _spendCategoryColorForCategory(BudgetCategory category) {
  return switch (category) {
    BudgetCategory.food => const Color(0xFFD97706),
    BudgetCategory.transportation => const Color(0xFF0F766E),
    BudgetCategory.shopping => const Color(0xFF991B1B),
    BudgetCategory.entertainment => const Color(0xFFD97706),
    BudgetCategory.miscellaneous => const Color(0xFF0F766E),
  };
}

IconData _expenseCategoryIcon(BudgetCategory category) {
  return switch (category) {
    BudgetCategory.food => Icons.restaurant_rounded,
    BudgetCategory.transportation => Icons.directions_bus_rounded,
    BudgetCategory.entertainment => Icons.celebration_rounded,
    BudgetCategory.shopping => Icons.shopping_bag_rounded,
    BudgetCategory.miscellaneous => Icons.receipt_long_rounded,
  };
}

String _displayTitle(ExpenseEntry expense) {
  final String trimmed = expense.title.trim();
  if (trimmed.toLowerCase() == 'transportation') {
    return 'Transport';
  }
  return trimmed.isEmpty ? 'Expense' : trimmed;
}

bool _isCategoryDuplicate(
  String title,
  BudgetCategory category,
  String spendCategory,
) {
  final String t = title.trim().toLowerCase();
  final String c = category.label.trim().toLowerCase();
  final String sc = spendCategory.trim().toLowerCase();

  // Specifically transport / transportation
  if ((t.contains('transport') || sc.contains('transport')) &&
      c.contains('transport')) {
    return true;
  }
  // Food / food & drinks
  if ((t.contains('food') || sc.contains('food')) && c.contains('food')) {
    return true;
  }
  // Shopping
  if (t == 'shopping' || (c == 'shopping' && (t == c || sc == 'shopping'))) {
    return true;
  }
  // Entertainment / Leisure
  if ((t.contains('leisure') ||
          t.contains('gala') ||
          t.contains('entertain') ||
          sc.contains('leisure') ||
          sc.contains('gala') ||
          sc.contains('entertain')) &&
      c.contains('entertain')) {
    return true;
  }
  // Health
  if ((t.contains('health') || sc.contains('health')) &&
      (c.contains('misc') || c.contains('health'))) {
    return true;
  }
  // Bills & Utilities
  if ((t.contains('bill') || sc.contains('bill')) &&
      (c.contains('misc') || c.contains('bill'))) {
    return true;
  }
  // Exact or containment match
  if (t == c || sc == c) {
    return true;
  }
  if (t.length <= 15 && (t.contains(c) || c.contains(t))) {
    return true;
  }
  return false;
}

String _expenseSubtitleText(ExpenseEntry expense, String displayNote) {
  final bool isDuplicate = _isCategoryDuplicate(
    expense.title,
    expense.category,
    expense.spendCategory,
  );

  String cleanNote = displayNote.trim();
  if (cleanNote.toLowerCase() == 'transport' ||
      cleanNote.toLowerCase() == 'transportation' ||
      cleanNote.toLowerCase() == expense.title.trim().toLowerCase()) {
    cleanNote = '';
  }

  final String timeStr = DateFormat('h:mm a').format(expense.dateTime);

  if (isDuplicate) {
    if (cleanNote.isNotEmpty) {
      return cleanNote;
    }
    return timeStr;
  } else {
    if (cleanNote.isNotEmpty) {
      return '${expense.category.label} • $cleanNote';
    }
    return '${expense.category.label} • $timeStr';
  }
}

String _sourceLabel(String source) {
  return switch (source) {
    'togetherSpend' => 'Budget Together',
    'quick_spend' || 'spend_screen' || 'spend' => 'Quick Spend',
    'meal' => 'Meal Plan',
    'manual' => 'Manual Log',
    _ => source.isEmpty ? 'Manual Log' : source,
  };
}

IconData _sourceIcon(String source) {
  return switch (source) {
    'togetherSpend' => Icons.group_rounded,
    'quick_spend' || 'spend_screen' || 'spend' => Icons.bolt_rounded,
    'meal' => Icons.restaurant_rounded,
    _ => Icons.edit_note_rounded,
  };
}
