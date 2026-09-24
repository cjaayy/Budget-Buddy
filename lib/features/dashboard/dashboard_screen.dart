import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

import '../../core/models/budget_models.dart';
import '../../core/state/app_controller.dart';
import '../../core/utils/formatters.dart';

/// Palette defining the unified 3 primary design colors: Dark Red, Gold, and Dark Green.
class _DashboardPalette {
  const _DashboardPalette(this.isDark);

  final bool isDark;

  // Dark Red: expenses, overspent alert, deficit
  Color get darkRed => const Color(0xFF991B1B);
  Color get darkRedBg =>
      const Color(0xFF991B1B).withValues(alpha: isDark ? 0.20 : 0.08);
  Color get darkRedBorder => const Color(0xFF991B1B).withValues(alpha: 0.25);

  // Gold: target budget amounts, presets, warnings, monthly overview
  Color get gold => const Color(0xFFD97706);
  Color get goldBg =>
      const Color(0xFFD97706).withValues(alpha: isDark ? 0.20 : 0.08);
  Color get goldBorder => const Color(0xFFD97706).withValues(alpha: 0.25);

  // Dark Green: remaining safe balance, positive progress, submit actions
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

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({
    super.key,
    this.onGetStarted,
    this.onOpenSpend,
    this.onOpenExpenses,
    this.onOpenSavings,
  });

  final VoidCallback? onGetStarted;
  final VoidCallback? onOpenSpend;
  final VoidCallback? onOpenExpenses;
  final VoidCallback? onOpenSavings;

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  DashboardPeriod _selectedPeriod = DashboardPeriod.daily;

  @override
  void initState() {
    super.initState();
    final DashboardPeriod savedPeriod =
        ref.read(budgetBuddyControllerProvider).dashboardPeriod;
    _selectedPeriod = savedPeriod == DashboardPeriod.weekly
        ? DashboardPeriod.daily
        : savedPeriod;
  }

  BudgetPeriod _budgetPeriodFor(DashboardPeriod period) {
    return switch (period) {
      DashboardPeriod.daily => BudgetPeriod.daily,
      DashboardPeriod.weekly => BudgetPeriod.daily,
      DashboardPeriod.monthly => BudgetPeriod.monthly,
    };
  }

  void _handleHorizontalDragEnd(DragEndDetails details) {
    final double velocity = details.primaryVelocity ?? 0;
    if (velocity.abs() < 250) {
      return;
    }

    final DashboardPeriod nextPeriod = _selectedPeriod == DashboardPeriod.daily
        ? DashboardPeriod.monthly
        : DashboardPeriod.daily;

    setState(() => _selectedPeriod = nextPeriod);
    ref
        .read(budgetBuddyControllerProvider.notifier)
        .setDashboardPeriod(nextPeriod);
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

  @override
  Widget build(BuildContext context) {
    final BudgetBuddyState state = ref.watch(budgetBuddyControllerProvider);
    final BudgetSummary summary = ref.watch(budgetSummaryProvider);
    final DateTime currentClock =
        ref.read(budgetBuddyControllerProvider.notifier).currentEffectiveTime;
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final _DashboardPalette palette = _DashboardPalette(isDark);

    final bool isDaily = _selectedPeriod == DashboardPeriod.daily;
    final BudgetPeriodSummary activeSummary =
        summary.periodSummaries[_budgetPeriodFor(_selectedPeriod)] ??
            BudgetPeriodSummary(
              period: _budgetPeriodFor(_selectedPeriod),
              limit: 0,
              spent: 0,
            );

    final bool hasConfiguredBudget = state.settings.hasConfiguredBudget;
    final bool hasExpenses =
        state.expenses.any((ExpenseEntry e) => e.source != 'togetherSpend');

    final double totalBudget = isDaily
        ? (state.settings.dailyLimit ?? activeSummary.limit)
        : (state.settings.monthlyLimit ?? activeSummary.limit);
    final double spentAdjusted = activeSummary.spent;
    final double remainingAdjusted = totalBudget - spentAdjusted;
    final bool hasBudget = totalBudget > 0;
    final bool isOver = remainingAdjusted < 0;
    final bool isWarning =
        !isOver && hasBudget && spentAdjusted >= (totalBudget * 0.8);
    final double progressValue = totalBudget > 0
        ? (spentAdjusted / totalBudget).clamp(0.0, 1.0)
        : 0.0;

    final DateTime now = currentClock;
    final List<ExpenseEntry> periodExpenses =
        state.expenses.where((ExpenseEntry e) {
      if (e.source == 'togetherSpend') return false;
      if (isDaily) {
        return e.dateTime.year == now.year &&
            e.dateTime.month == now.month &&
            e.dateTime.day == now.day;
      } else {
        return e.dateTime.year == now.year && e.dateTime.month == now.month;
      }
    }).toList();

    return Scaffold(
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onHorizontalDragEnd: _handleHorizontalDragEnd,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                // 1. Compact Header (Clean Greeting + Date)
                _buildHeader(
                  context,
                  displayName: state.profile.displayName,
                  currentClock: currentClock,
                ),
                const SizedBox(height: 12),

                // 2. Main Content
                Expanded(
                  child: ListView(
                    padding: EdgeInsets.zero,
                    children: <Widget>[
                      // Savings / Spending Overview Card (with 3 Solid Metric Tiles)
                      _buildOverviewCard(
                        context,
                        isDaily: isDaily,
                        totalBudget: totalBudget,
                        spent: spentAdjusted,
                        remaining: remainingAdjusted,
                        isOver: isOver,
                        palette: palette,
                      ),
                      const SizedBox(height: 12),

                      // Sleek Daily / Monthly Toggle
                      _buildPeriodToggle(context, palette),
                      const SizedBox(height: 12),

                      if (!hasConfiguredBudget || !hasExpenses) ...<Widget>[
                        _buildEmptyState(
                          context,
                          hasConfiguredBudget: hasConfiguredBudget,
                          palette: palette,
                        ),
                      ] else ...<Widget>[
                        // Enlarged Spending Breakdown Card
                        _buildSpendingBreakdownCard(
                          context,
                          isDaily: isDaily,
                          spent: spentAdjusted,
                          remaining: remainingAdjusted,
                          totalBudget: totalBudget,
                          periodExpenses: periodExpenses,
                          palette: palette,
                        ),
                        const SizedBox(height: 12),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Compact Header without redundant status badge
  Widget _buildHeader(
    BuildContext context, {
    required String displayName,
    required DateTime currentClock,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          displayName.trim().isNotEmpty ? 'Hi, $displayName' : 'Home',
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

  /// Clean Overview Card with the 3 Solid Metric Tiles (no duplicate progress bar/pill)
  Widget _buildOverviewCard(
    BuildContext context, {
    required bool isDaily,
    required double totalBudget,
    required double spent,
    required double remaining,
    required bool isOver,
    required _DashboardPalette palette,
  }) {
    final ThemeData theme = Theme.of(context);
    final bool isWarning =
        !isOver && totalBudget > 0 && spent >= (totalBudget * 0.8);

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
              Icon(
                Icons.analytics_rounded,
                size: 16,
                color: palette.darkGreen,
              ),
              const SizedBox(width: 6),
              Text(
                isDaily ? 'Daily Overview' : 'Monthly Overview',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: theme.colorScheme.onSurface,
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
                      label: isDaily ? 'Daily Budget' : 'Month Budget',
                      value: formatPeso(totalBudget),
                      bgColor: palette.gold,
                      icon: Icons.account_balance_wallet_rounded,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _CompactMetricTile(
                      label: isDaily ? 'Daily Spent' : 'Month Spent',
                      value: formatPeso(spent),
                      bgColor: isOver
                          ? palette.darkRed
                          : (isWarning ? palette.gold : palette.darkGreen),
                      icon: Icons.payments_rounded,
                    ),
                  ),
                ],
              ),

              // Over-budget alert
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
                          'Over-budget warning: Exceeded budget by ${formatPeso(remaining.abs())}.',
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

  /// Segmented Daily / Monthly toggle matching app style
  Widget _buildPeriodToggle(BuildContext context, _DashboardPalette palette) {
    final ThemeData theme = Theme.of(context);
    final bool isDaily = _selectedPeriod == DashboardPeriod.daily;

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
                if (!isDaily) {
                  setState(() => _selectedPeriod = DashboardPeriod.daily);
                  ref
                      .read(budgetBuddyControllerProvider.notifier)
                      .setDashboardPeriod(DashboardPeriod.daily);
                }
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 9),
                decoration: BoxDecoration(
                  color: isDaily ? palette.darkGreen : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: isDaily
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
                      color: isDaily
                          ? Colors.white
                          : theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Daily',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight:
                            isDaily ? FontWeight.w700 : FontWeight.w600,
                        color: isDaily
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
                if (isDaily) {
                  setState(() => _selectedPeriod = DashboardPeriod.monthly);
                  ref
                      .read(budgetBuddyControllerProvider.notifier)
                      .setDashboardPeriod(DashboardPeriod.monthly);
                }
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 9),
                decoration: BoxDecoration(
                  color: !isDaily ? palette.darkGreen : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: !isDaily
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
                      color: !isDaily
                          ? Colors.white
                          : theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Monthly',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight:
                            !isDaily ? FontWeight.w700 : FontWeight.w600,
                        color: !isDaily
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

  /// Enlarged Spending Breakdown Card (Clean, Non-Duplicate)
  Widget _buildSpendingBreakdownCard(
    BuildContext context, {
    required bool isDaily,
    required double spent,
    required double remaining,
    required double totalBudget,
    required List<ExpenseEntry> periodExpenses,
    required _DashboardPalette palette,
  }) {
    final ThemeData theme = Theme.of(context);
    final double safeSpent = spent < 0 ? 0 : spent;
    final double safeRemaining = remaining < 0 ? 0 : remaining;
    final bool hasAnyValue = safeSpent > 0 || safeRemaining > 0;
    final double chartSpent = hasAnyValue ? safeSpent : 0.0001;
    final double chartRemaining = hasAnyValue ? safeRemaining : 1.0;
    final double spentRatio =
        totalBudget <= 0 ? 0 : (safeSpent / totalBudget).clamp(0.0, 1.0);
    final bool isOver = remaining < 0;
    final bool isWarning =
        !isOver && totalBudget > 0 && safeSpent >= (totalBudget * 0.8);

    // Aggregate category totals for this period
    final Map<BudgetCategory, double> categoryTotals =
        <BudgetCategory, double>{};
    for (final ExpenseEntry e in periodExpenses) {
      categoryTotals[e.category] =
          (categoryTotals[e.category] ?? 0.0) + e.amount;
    }
    final List<MapEntry<BudgetCategory, double>> sortedCategories =
        categoryTotals.entries.toList()
          ..sort((MapEntry<BudgetCategory, double> a,
                  MapEntry<BudgetCategory, double> b) =>
              b.value.compareTo(a.value));

    return Container(
      padding: const EdgeInsets.all(16),
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
              Icon(Icons.pie_chart_rounded, size: 18, color: palette.gold),
              const SizedBox(width: 8),
              Text(
                'Spending Breakdown',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Enlarged Donut Pie Chart Centerpiece
          Center(
            child: SizedBox(
              width: 190,
              height: 190,
              child: Stack(
                alignment: Alignment.center,
                children: <Widget>[
                  PieChart(
                    PieChartData(
                      centerSpaceRadius: 58,
                      sectionsSpace: 3,
                      startDegreeOffset: -90,
                      sections: <PieChartSectionData>[
                        PieChartSectionData(
                          value: chartSpent,
                          color: palette.darkRed,
                          radius: 28,
                          title: '',
                        ),
                        PieChartSectionData(
                          value: chartRemaining,
                          color: palette.darkGreen,
                          radius: 28,
                          title: '',
                        ),
                      ],
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text(
                        '${(spentRatio * 100).toInt()}%',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          color: isOver
                              ? palette.darkRed
                              : (isWarning
                                  ? palette.gold
                                  : palette.darkGreen),
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        isOver ? 'OVER' : 'USED',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.8,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Categories Breakdown Section
          if (sortedCategories.isNotEmpty) ...<Widget>[
            const SizedBox(height: 18),
            Row(
              children: <Widget>[
                Icon(Icons.category_rounded, size: 15, color: palette.gold),
                const SizedBox(width: 6),
                Text(
                  'Spending by Category',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                const Spacer(),
                Text(
                  '${sortedCategories.length} ${sortedCategories.length == 1 ? 'category' : 'categories'}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ...sortedCategories.map(
              (MapEntry<BudgetCategory, double> entry) {
                final double catSpent = entry.value;
                final double catRatio = safeSpent > 0
                    ? (catSpent / safeSpent).clamp(0.0, 1.0)
                    : 0.0;
                final IconData icon = _iconForCategory(entry.key);

                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest
                          .withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: theme.colorScheme.outlineVariant
                            .withValues(alpha: 0.25),
                      ),
                    ),
                    child: Column(
                      children: <Widget>[
                        Row(
                          children: <Widget>[
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: palette.goldBg,
                                shape: BoxShape.circle,
                                border: Border.all(color: palette.goldBorder),
                              ),
                              child: Icon(icon, color: palette.gold, size: 14),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                entry.key.label,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                            Text(
                              formatPeso(catSpent),
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 13,
                                color: palette.darkRed,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: catRatio,
                            minHeight: 5,
                            backgroundColor:
                                palette.gold.withValues(alpha: 0.12),
                            valueColor:
                                AlwaysStoppedAnimation<Color>(palette.gold),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ],
      ),
    );
  }

  /// Modern Empty State matching App Theme
  Widget _buildEmptyState(
    BuildContext context, {
    required bool hasConfiguredBudget,
    required _DashboardPalette palette,
  }) {
    final ThemeData theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.cardTheme.color ?? theme.cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        children: <Widget>[
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color:
                  (hasConfiguredBudget ? palette.darkGreenBg : palette.goldBg),
              shape: BoxShape.circle,
              border: Border.all(
                color: (hasConfiguredBudget
                    ? palette.darkGreenBorder
                    : palette.goldBorder),
              ),
            ),
            child: Icon(
              hasConfiguredBudget
                  ? Icons.receipt_long_rounded
                  : Icons.savings_rounded,
              size: 28,
              color: hasConfiguredBudget ? palette.darkGreen : palette.gold,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            hasConfiguredBudget
                ? 'No Expenses Logged Yet'
                : 'No Active Budget Set',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            hasConfiguredBudget
                ? 'Your budget is ready. Tap Log Spend to start tracking your daily expenses.'
                : 'Set a daily or monthly budget to start tracking your allowance, spending, and savings.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: hasConfiguredBudget
                ? widget.onOpenSpend
                : widget.onGetStarted,
            icon: Icon(
              hasConfiguredBudget
                  ? Icons.add_shopping_cart_rounded
                  : Icons.account_balance_wallet_rounded,
              size: 16,
              color: Colors.white,
            ),
            label: Text(
              hasConfiguredBudget ? 'Log First Spend' : 'Set Budget Now',
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 13,
                color: Colors.white,
              ),
            ),
            style: FilledButton.styleFrom(
              backgroundColor:
                  hasConfiguredBudget ? palette.darkGreen : palette.gold,
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(42),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
