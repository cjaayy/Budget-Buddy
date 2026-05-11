import 'dart:io';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/models/budget_models.dart';
import '../../core/state/app_controller.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/budget_cards.dart';
import '../../core/widgets/section_title.dart';

class AnalyticsScreen extends ConsumerStatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  ConsumerState<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends ConsumerState<AnalyticsScreen> {
  bool _comparePreviousPeriod = false;
  BudgetCategory? _selectedCategory;
  _ReportsTab _reportsTab = _ReportsTab.daily;

  @override
  Widget build(BuildContext context) {
    final BudgetBuddyState state = ref.watch(budgetBuddyControllerProvider);
    final BudgetSummary summary = ref.watch(budgetSummaryProvider);
    final DashboardPeriod period = state.dashboardPeriod;
    final _PeriodAnalysis analysis = _buildAnalysis(state, period);
    final _PeriodAnalysis previousAnalysis =
        _buildPreviousAnalysis(state, period);
    final bool isFirstOfMonth = DateTime.now().day == 1;
    final double savingsTarget = state.settings.savingsTargetAmount;
    final DateTime? savingsTargetDate = state.settings.savingsTargetDate;
    final double targetProgress = savingsTarget <= 0
        ? 0
        : (analysis.savings / savingsTarget).clamp(0, 1.0).toDouble();
    final int daysRemaining = savingsTargetDate == null
        ? 0
        : savingsTargetDate.difference(DateTime.now()).inDays;
    final double dailySaveTarget =
        savingsTargetDate == null || daysRemaining <= 0
            ? 0
            : savingsTarget / daysRemaining;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Analytics'),
        actions: <Widget>[
          IconButton(
            tooltip: 'Export CSV',
            onPressed: () => _exportCsv(context, state, analysis),
            icon: const Icon(Icons.table_view_rounded),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: <Widget>[
            const SectionTitle(
              title: 'Analytics',
              subtitle: 'Track spending, savings, and trends by period.',
            ),
            const SizedBox(height: 12),
            _periodScorecard(summary),
            const SizedBox(height: 16),
            SectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Period',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 12),
                  _PeriodTabs(
                    selectedPeriod: period,
                    onChanged: (DashboardPeriod value) {
                      ref
                          .read(budgetBuddyControllerProvider.notifier)
                          .setDashboardPeriod(value);
                    },
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    value: _comparePreviousPeriod,
                    onChanged: (bool value) {
                      setState(() {
                        _comparePreviousPeriod = value;
                      });
                    },
                    title: const Text('Compare previous period'),
                    subtitle: const Text(
                      'Overlay last period with a lighter trend line.',
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            GridView.count(
              crossAxisCount: MediaQuery.of(context).size.width > 500 ? 2 : 1,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio:
                  MediaQuery.of(context).size.width > 500 ? 1.7 : 2.2,
              children: <Widget>[
                BudgetMetricCard(
                  label: 'Spent in period',
                  value: formatPeso(analysis.totalSpent),
                  subtitle: '${period.label} view',
                  icon: Icons.payments_rounded,
                  color: const Color(0xFF2563EB),
                ),
                BudgetMetricCard(
                  label: 'Savings',
                  value: formatPeso(analysis.savings),
                  subtitle: savingsTarget > 0
                      ? '${(targetProgress * 100).round()}% of goal'
                      : 'No goal set',
                  icon: Icons.savings_rounded,
                  color: const Color(0xFF0F766E),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Today\'s summary',
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 12),
                  _SummaryRow(
                    icon: Icons.payments_rounded,
                    label: 'Spent',
                    value: formatPeso(analysis.totalSpent),
                  ),
                  _SummaryRow(
                    icon: Icons.savings_rounded,
                    label: 'Saved',
                    value: formatPeso(analysis.savings),
                  ),
                  _SummaryRow(
                    icon: Icons.category_rounded,
                    label: 'Biggest category',
                    value: analysis.biggestCategory,
                  ),
                  if (analysis.overspendingCategories.isNotEmpty)
                    _SummaryRow(
                      icon: Icons.warning_rounded,
                      label: 'Alerts',
                      value: analysis.overspendingCategories.join(', '),
                      valueColor: Theme.of(context).colorScheme.error,
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Savings goal tracker',
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 12),
                  if (savingsTarget <= 0)
                    Text(
                      'Set a target amount and due date to track your savings goal.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    )
                  else ...<Widget>[
                    Text('Target: ${formatPeso(savingsTarget)}'),
                    const SizedBox(height: 4),
                    Text(
                      savingsTargetDate == null
                          ? 'No target date set.'
                          : 'Due ${formatShortDate(savingsTargetDate)}${daysRemaining >= 0 ? ' • $daysRemaining day${daysRemaining == 1 ? '' : 's'} left' : ' • overdue'}',
                    ),
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: LinearProgressIndicator(
                        minHeight: 8,
                        value: targetProgress,
                        backgroundColor: Theme.of(context)
                            .colorScheme
                            .primary
                            .withValues(alpha: 0.12),
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text('Current progress: ${formatPeso(analysis.savings)}'),
                    const SizedBox(height: 4),
                    Text('Daily save target: ${formatPeso(dailySaveTarget)}'),
                  ],
                  const SizedBox(height: 12),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _editSavingsTarget(context, state),
                          icon: const Icon(Icons.edit_rounded),
                          label: const Text('Set target'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Spending trend',
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 260,
                    child: BarChart(
                      BarChartData(
                        gridData: const FlGridData(show: false),
                        alignment: BarChartAlignment.spaceAround,
                        maxY: analysis.maxYAxis,
                        titlesData: FlTitlesData(
                          leftTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 42,
                              getTitlesWidget: (double value, TitleMeta meta) {
                                if (value == 0 || value == analysis.maxYAxis) {
                                  return const SizedBox.shrink();
                                }
                                return Padding(
                                  padding: const EdgeInsets.only(right: 4),
                                  child: Text(
                                    formatPeso(value),
                                    style: const TextStyle(fontSize: 9),
                                  ),
                                );
                              },
                            ),
                          ),
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 36,
                              getTitlesWidget: (double value, TitleMeta meta) {
                                final int index = value.toInt();
                                if (index < 0 ||
                                    index >= analysis.days.length) {
                                  return const SizedBox.shrink();
                                }
                                return Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Text(
                                    _trendLabel(analysis.days[index]),
                                    style: const TextStyle(fontSize: 10),
                                  ),
                                );
                              },
                            ),
                          ),
                          topTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                          rightTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                        ),
                        borderData: FlBorderData(show: false),
                        extraLinesData: ExtraLinesData(
                          horizontalLines: <HorizontalLine>[
                            HorizontalLine(
                              y: state.settings.totalDailyBudget,
                              dashArray: <int>[6, 4],
                              color: const Color(0xFFDC2626),
                              strokeWidth: 1.5,
                              label: HorizontalLineLabel(
                                show: true,
                                alignment: Alignment.topRight,
                                style: const TextStyle(
                                  color: Color(0xFFDC2626),
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                ),
                                labelResolver: (HorizontalLine line) =>
                                    'Daily budget',
                              ),
                            ),
                          ],
                        ),
                        barTouchData: BarTouchData(
                          enabled: true,
                          touchTooltipData: BarTouchTooltipData(
                            getTooltipItem: (group, groupIndex, rod, rodIndex) {
                              final DateTime day =
                                  analysis.days[group.x.toInt()];
                              final bool isCompareRod =
                                  _comparePreviousPeriod && rodIndex == 1;
                              return BarTooltipItem(
                                '${_trendLabel(day)}\n${isCompareRod ? 'Previous' : 'Current'}: ${formatPeso(rod.toY)}',
                                TextStyle(
                                  color: isCompareRod
                                      ? Theme.of(context)
                                          .colorScheme
                                          .onSurfaceVariant
                                      : Theme.of(context).colorScheme.onSurface,
                                  fontWeight: FontWeight.w600,
                                ),
                              );
                            },
                          ),
                          touchCallback:
                              (FlTouchEvent event, BarTouchResponse? response) {
                            if (event is! FlTapUpEvent ||
                                response?.spot == null) {
                              return;
                            }
                            final int index =
                                response!.spot!.touchedBarGroupIndex;
                            if (index < 0 || index >= analysis.days.length) {
                              return;
                            }
                            _showDayExpenses(
                                context, state, analysis.days[index]);
                          },
                        ),
                        barGroups: _buildBarGroups(
                          analysis,
                          previousAnalysis,
                          compare: _comparePreviousPeriod,
                          context: context,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: <Widget>[
                      const SoftPill(
                        text: 'Budget line',
                        color: Color(0xFFDC2626),
                        icon: Icons.horizontal_rule_rounded,
                      ),
                      const SoftPill(
                        text: 'Red bars exceed budget',
                        color: Color(0xFFDC2626),
                        icon: Icons.warning_rounded,
                      ),
                      if (_comparePreviousPeriod)
                        const SoftPill(
                          text: 'Previous period overlay',
                          color: Color(0xFF64748B),
                          icon: Icons.compare_arrows_rounded,
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Category mix',
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 240,
                    child: PieChart(
                      PieChartData(
                        centerSpaceRadius: 54,
                        sectionsSpace: 2,
                        pieTouchData: PieTouchData(
                          touchCallback:
                              (FlTouchEvent event, PieTouchResponse? response) {
                            if (event is! FlTapUpEvent ||
                                response?.touchedSection == null) {
                              return;
                            }
                            final int index =
                                response!.touchedSection!.touchedSectionIndex;
                            final List<_CategorySlice> slices =
                                _categorySlices(analysis);
                            if (index < 0 || index >= slices.length) {
                              return;
                            }
                            _showCategoryDetails(context, state, analysis,
                                slices[index].category);
                          },
                        ),
                        sections: _categorySlices(analysis)
                            .map(((_CategorySlice slice) {
                          final bool selected =
                              _selectedCategory == slice.category;
                          return PieChartSectionData(
                            value: slice.value,
                            title: slice.value <= 0
                                ? ''
                                : '${slice.percent.toStringAsFixed(0)}%',
                            radius: selected ? 74 : 64,
                            color: slice.category.color,
                            titleStyle: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 11,
                            ),
                          );
                        })).toList(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _categorySlices(analysis)
                        .map(
                          (_CategorySlice slice) => SoftPill(
                            text:
                                '${slice.category.label} • ${formatPeso(slice.value)}',
                            color: slice.category.color,
                            icon: Icons.circle,
                          ),
                        )
                        .toList(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _reportsSection(state),
            const SizedBox(height: 16),
            if (isFirstOfMonth)
              SectionCard(
                child: _monthlyRecapCard(
                  recap: _buildLastMonthRecap(state),
                  onExportCsv: () => _exportCsv(context, state, analysis),
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _formatMonthYear(DateTime dateTime) {
    final String month = switch (dateTime.month) {
      1 => 'January',
      2 => 'February',
      3 => 'March',
      4 => 'April',
      5 => 'May',
      6 => 'June',
      7 => 'July',
      8 => 'August',
      9 => 'September',
      10 => 'October',
      11 => 'November',
      _ => 'December',
    };
    return '$month ${dateTime.year}';
  }

  void _editSavingsTarget(BuildContext context, BudgetBuddyState state) {
    final TextEditingController amountController = TextEditingController(
      text: state.settings.savingsTargetAmount > 0
          ? state.settings.savingsTargetAmount.toStringAsFixed(0)
          : '',
    );
    DateTime selectedDate = state.settings.savingsTargetDate ??
        DateTime.now().add(
          const Duration(days: 30),
        );

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (BuildContext context) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 8,
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
          ),
          child: StatefulBuilder(
            builder: (BuildContext context,
                void Function(void Function()) setModalState) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Set savings target',
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: amountController,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration:
                        const InputDecoration(labelText: 'Target amount'),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () async {
                      final DateTime? picked = await showDatePicker(
                        context: context,
                        firstDate: DateTime.now(),
                        lastDate:
                            DateTime.now().add(const Duration(days: 365 * 3)),
                        initialDate: selectedDate,
                      );
                      if (picked == null) {
                        return;
                      }
                      setModalState(() {
                        selectedDate = picked;
                      });
                    },
                    icon: const Icon(Icons.event_rounded),
                    label: Text('Due ${formatShortDate(selectedDate)}'),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () {
                        final double amount =
                            double.tryParse(amountController.text) ?? 0;
                        ref
                            .read(budgetBuddyControllerProvider.notifier)
                            .updateSavingsTarget(
                              amount: amount,
                              targetDate: selectedDate,
                            );
                        Navigator.of(context).pop();
                      },
                      child: const Text('Save target'),
                    ),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  void _showDayExpenses(
    BuildContext context,
    BudgetBuddyState state,
    DateTime day,
  ) {
    final List<ExpenseEntry> dayExpenses = state.expenses
        .where((ExpenseEntry expense) => _sameDay(expense.dateTime, day))
        .toList();
    final double total = dayExpenses.fold(
      0,
      (double sum, ExpenseEntry expense) => sum + expense.amount,
    );

    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (BuildContext context) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                _trendLabel(day),
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              Text('Total spent: ${formatPeso(total)}'),
              const SizedBox(height: 12),
              ...dayExpenses.map(
                (ExpenseEntry expense) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    backgroundColor:
                        expense.category.color.withValues(alpha: 0.14),
                    child: Icon(
                      _categoryIcon(expense.category),
                      color: expense.category.color,
                    ),
                  ),
                  title: Text(expense.title),
                  subtitle: Text(expense.category.label),
                  trailing: Text(formatPeso(expense.amount)),
                ),
              ),
              if (dayExpenses.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text('No expenses logged on this day.'),
                ),
            ],
          ),
        );
      },
    );
  }

  void _showCategoryDetails(
    BuildContext context,
    BudgetBuddyState state,
    _PeriodAnalysis analysis,
    BudgetCategory category,
  ) {
    setState(() {
      _selectedCategory = category;
    });
    final List<ExpenseEntry> categoryExpenses = analysis.expenses
        .where((ExpenseEntry expense) => expense.category == category)
        .toList();
    final double total = categoryExpenses.fold(
      0,
      (double sum, ExpenseEntry expense) => sum + expense.amount,
    );

    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (BuildContext context) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                category.label,
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              Text('Total in period: ${formatPeso(total)}'),
              const SizedBox(height: 12),
              ...categoryExpenses.map(
                (ExpenseEntry expense) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    backgroundColor: category.color.withValues(alpha: 0.14),
                    child: Icon(_categoryIcon(category), color: category.color),
                  ),
                  title: Text(expense.title),
                  subtitle: Text(formatShortDate(expense.dateTime)),
                  trailing: Text(formatPeso(expense.amount)),
                ),
              ),
              if (categoryExpenses.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text('No expenses found for this category.'),
                ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _exportCategoryCsv(
                      context, state, category, categoryExpenses),
                  icon: const Icon(Icons.table_view_rounded),
                  label: const Text('Export this category CSV'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _exportCsv(
    BuildContext context,
    BudgetBuddyState state,
    _PeriodAnalysis analysis,
  ) async {
    final StringBuffer buffer = StringBuffer()
      ..writeln('Date,Title,Category,Amount,Note,Source');
    for (final ExpenseEntry expense in analysis.expenses) {
      buffer.writeln(
        '${formatShortDate(expense.dateTime)},${_csvEscape(expense.title)},${expense.category.label},${expense.amount.toStringAsFixed(2)},${_csvEscape(expense.note)},${expense.source}',
      );
    }

    final Directory directory = await getTemporaryDirectory();
    final File file = File(
      '${directory.path}${Platform.pathSeparator}BudgetBuddy_${state.dashboardPeriod.name}_analytics.csv',
    );
    await file.writeAsString(buffer.toString());
    await Share.shareXFiles(<XFile>[XFile(file.path)],
        text: 'BudgetBuddy analytics CSV');
  }

  Future<void> _exportCategoryCsv(
    BuildContext context,
    BudgetBuddyState state,
    BudgetCategory category,
    List<ExpenseEntry> expenses,
  ) async {
    final StringBuffer buffer = StringBuffer()
      ..writeln('Date,Title,Category,Amount,Note,Source');
    for (final ExpenseEntry expense in expenses) {
      buffer.writeln(
        '${formatShortDate(expense.dateTime)},${_csvEscape(expense.title)},${expense.category.label},${expense.amount.toStringAsFixed(2)},${_csvEscape(expense.note)},${expense.source}',
      );
    }

    final Directory directory = await getTemporaryDirectory();
    final File file = File(
      '${directory.path}${Platform.pathSeparator}${category.name}_analytics.csv',
    );
    await file.writeAsString(buffer.toString());
    await Share.shareXFiles(<XFile>[XFile(file.path)],
        text: '${category.label} analytics CSV');
  }

  String _csvEscape(String value) {
    final String safe = value.replaceAll('"', '""');
    return '"$safe"';
  }

  Widget _monthlyRecapCard({
    required _MonthlyRecap recap,
    required VoidCallback onExportCsv,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'Last month summary',
          style: Theme.of(context)
              .textTheme
              .titleLarge
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 12),
        _SummaryRow(
          icon: Icons.payments_rounded,
          label: 'Total spent',
          value: formatPeso(recap.totalSpent),
        ),
        _SummaryRow(
          icon: Icons.savings_rounded,
          label: 'Total saved',
          value: formatPeso(recap.totalSaved),
        ),
        _SummaryRow(
          icon: Icons.local_fire_department_rounded,
          label: 'Longest budget streak',
          value: '${recap.longestStreak} days',
        ),
        _SummaryRow(
          icon: Icons.category_rounded,
          label: 'Biggest category',
          value: recap.biggestCategory,
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: onExportCsv,
            icon: const Icon(Icons.table_view_rounded),
            label: const Text('Export current period CSV'),
          ),
        ),
      ],
    );
  }

  IconData _categoryIcon(BudgetCategory category) {
    return switch (category) {
      BudgetCategory.food => Icons.restaurant_rounded,
      BudgetCategory.transportation => Icons.directions_transit_rounded,
      BudgetCategory.entertainment => Icons.movie_rounded,
      BudgetCategory.shopping => Icons.shopping_bag_rounded,
      BudgetCategory.miscellaneous => Icons.category_rounded,
    };
  }

  List<_CategorySlice> _categorySlices(_PeriodAnalysis analysis) {
    return analysis.categoryTotals.entries
        .where((MapEntry<BudgetCategory, double> entry) => entry.value > 0)
        .map((MapEntry<BudgetCategory, double> entry) {
      final double total = analysis.totalSpent <= 0 ? 1 : analysis.totalSpent;
      return _CategorySlice(
        category: entry.key,
        value: entry.value,
        percent: (entry.value / total) * 100,
      );
    }).toList()
      ..sort((left, right) => right.value.compareTo(left.value));
  }

  List<BarChartGroupData> _buildBarGroups(
    _PeriodAnalysis current,
    _PeriodAnalysis previous, {
    required bool compare,
    required BuildContext context,
  }) {
    final List<BarChartGroupData> groups = <BarChartGroupData>[];
    for (int index = 0; index < current.days.length; index++) {
      final double currentValue = current.dailyTotals[index];
      final double previousValue = compare ? previous.dailyTotals[index] : 0;
      final bool overBudget = currentValue > current.dailyBudgetLimit;
      final List<BarChartRodData> rods = <BarChartRodData>[
        BarChartRodData(
          toY: currentValue,
          color: overBudget
              ? const Color(0xFFDC2626)
              : Theme.of(context).colorScheme.primary,
          width: compare ? 10 : 18,
          borderRadius: BorderRadius.circular(6),
        ),
      ];
      if (compare) {
        rods.add(
          BarChartRodData(
            toY: previousValue,
            color: Theme.of(context)
                .colorScheme
                .onSurfaceVariant
                .withValues(alpha: 0.32),
            width: 10,
            borderRadius: BorderRadius.circular(6),
          ),
        );
      }
      groups.add(
        BarChartGroupData(
          x: index,
          barRods: rods,
          barsSpace: 4,
        ),
      );
    }
    return groups;
  }

  _PeriodAnalysis _buildAnalysis(
      BudgetBuddyState state, DashboardPeriod period) {
    final DateTime end = _startOfDay(DateTime.now());
    final int spanDays = _periodDays(period);
    final DateTime start = end.subtract(Duration(days: spanDays - 1));
    final List<DateTime> days = List<DateTime>.generate(
      spanDays,
      (int index) => start.add(Duration(days: index)),
    );
    return _buildAnalysisForRange(state, days);
  }

  _PeriodAnalysis _buildPreviousAnalysis(
      BudgetBuddyState state, DashboardPeriod period) {
    final DateTime end = _startOfDay(DateTime.now())
        .subtract(Duration(days: _periodDays(period)));
    final int spanDays = _periodDays(period);
    final DateTime start = end.subtract(Duration(days: spanDays - 1));
    final List<DateTime> days = List<DateTime>.generate(
      spanDays,
      (int index) => start.add(Duration(days: index)),
    );
    return _buildAnalysisForRange(state, days);
  }

  _PeriodAnalysis _buildAnalysisForRange(
      BudgetBuddyState state, List<DateTime> days) {
    final List<ExpenseEntry> expenses = state.expenses
        .where((ExpenseEntry expense) =>
            days.any((DateTime day) => _sameDay(expense.dateTime, day)))
        .toList();

    final Map<DateTime, double> dailyTotals = <DateTime, double>{
      for (final DateTime day in days) day: 0,
    };
    final Map<BudgetCategory, double> categoryTotals = <BudgetCategory, double>{
      for (final BudgetCategory category in BudgetCategory.values) category: 0,
    };

    for (final ExpenseEntry expense in expenses) {
      final DateTime key = _startOfDay(expense.dateTime);
      dailyTotals[key] = (dailyTotals[key] ?? 0) + expense.amount;
      categoryTotals[expense.category] =
          (categoryTotals[expense.category] ?? 0) + expense.amount;
    }

    final double multiplier = _periodMultiplier(state.dashboardPeriod);
    final double periodBudget = state.settings.totalDailyBudget * multiplier;
    final double totalSpent = expenses.fold(
        0, (double sum, ExpenseEntry expense) => sum + expense.amount);
    final double savings =
        (periodBudget - totalSpent).clamp(-999999, 999999).toDouble();
    final List<String> overspendingCategories =
        _overspendingCategories(state, categoryTotals, multiplier);
    final String biggestCategory = categoryTotals.entries.isEmpty
        ? 'None'
        : categoryTotals.entries
            .reduce((MapEntry<BudgetCategory, double> left,
                    MapEntry<BudgetCategory, double> right) =>
                left.value >= right.value ? left : right)
            .key
            .label;

    return _PeriodAnalysis(
      days: days,
      expenses: expenses,
      dailyTotals: days.map((DateTime day) => dailyTotals[day] ?? 0).toList(),
      categoryTotals: categoryTotals,
      totalSpent: totalSpent,
      savings: savings,
      totalBudget: periodBudget,
      biggestCategory: biggestCategory,
      overspendingCategories: overspendingCategories,
      dailyBudgetLimit: state.settings.totalDailyBudget,
      maxYAxis: _maxYAxis(dailyTotals.values, state.settings.totalDailyBudget),
    );
  }

  List<String> _overspendingCategories(
    BudgetBuddyState state,
    Map<BudgetCategory, double> categoryTotals,
    double multiplier,
  ) {
    final List<String> alerts = <String>[];
    for (final BudgetCategory category in BudgetCategory.values) {
      final double limit = switch (category) {
            BudgetCategory.food => state.settings.foodBudget,
            BudgetCategory.transportation =>
              state.settings.transportationBudget,
            BudgetCategory.entertainment => state.settings.leisureBudget,
            BudgetCategory.shopping => 0,
            BudgetCategory.miscellaneous => 0,
          } *
          multiplier;
      if (limit > 0 && (categoryTotals[category] ?? 0) > limit) {
        alerts.add(category.label);
      }
    }
    return alerts;
  }

  int _periodDays(DashboardPeriod period) {
    return switch (period) {
      DashboardPeriod.daily => 1,
      DashboardPeriod.weekly => 7,
      DashboardPeriod.monthly => 30,
    };
  }

  double _periodMultiplier(DashboardPeriod period) {
    return switch (period) {
      DashboardPeriod.daily => 1,
      DashboardPeriod.weekly => 7,
      DashboardPeriod.monthly => 30,
    };
  }

  double _maxYAxis(Iterable<double> values, double lineValue) {
    final double maxValue =
        values.fold(0, (double max, double value) => value > max ? value : max);
    final double top = maxValue > lineValue ? maxValue : lineValue;
    if (top <= 0) {
      return 100;
    }
    return (top * 1.2).ceilToDouble();
  }

  DateTime _startOfDay(DateTime value) =>
      DateTime(value.year, value.month, value.day);

  bool _sameDay(DateTime left, DateTime right) {
    return left.year == right.year &&
        left.month == right.month &&
        left.day == right.day;
  }

  String _trendLabelShort(DateTime dateTime) {
    if (DateUtils.isSameDay(dateTime, DateTime.now())) {
      return 'Today';
    }
    if (DateUtils.isSameDay(
        dateTime, DateTime.now().subtract(const Duration(days: 1)))) {
      return 'Yesterday';
    }
    return formatDayLabel(dateTime);
  }

  String _trendLabel(DateTime dateTime) => _trendLabelShort(dateTime);

  _MonthlyRecap _buildLastMonthRecap(BudgetBuddyState state) {
    final DateTime now = DateTime.now();
    final DateTime firstOfThisMonth = DateTime(now.year, now.month, 1);
    final DateTime firstOfLastMonth =
        DateTime(firstOfThisMonth.year, firstOfThisMonth.month - 1, 1);
    final List<ExpenseEntry> lastMonthExpenses = state.expenses
        .where((ExpenseEntry expense) =>
            expense.dateTime
                .isAfter(firstOfLastMonth.subtract(const Duration(days: 1))) &&
            expense.dateTime.isBefore(firstOfThisMonth))
        .toList();
    final double totalSpent = lastMonthExpenses.fold(
        0, (double sum, ExpenseEntry expense) => sum + expense.amount);
    final Map<BudgetCategory, double> totals = <BudgetCategory, double>{
      for (final BudgetCategory category in BudgetCategory.values) category: 0,
    };
    for (final ExpenseEntry expense in lastMonthExpenses) {
      totals[expense.category] =
          (totals[expense.category] ?? 0) + expense.amount;
    }
    final String biggestCategory = totals.entries.isEmpty
        ? 'None'
        : totals.entries
            .reduce((left, right) => left.value >= right.value ? left : right)
            .key
            .label;

    final Map<DateTime, int> streakCounts = <DateTime, int>{};
    for (final DailyRecord record in state.dailyRecords) {
      final DateTime day = _startOfDay(record.date);
      if (day.isBefore(firstOfThisMonth) &&
          day.isAfter(firstOfLastMonth.subtract(const Duration(days: 1)))) {
        streakCounts[day] =
            record.totalSpent <= state.settings.totalDailyBudget ? 1 : 0;
      }
    }
    int longestStreak = 0;
    int currentStreak = 0;
    final List<DateTime> sortedDays = streakCounts.keys.toList()..sort();
    for (final DateTime day in sortedDays) {
      if (streakCounts[day] == 1) {
        currentStreak += 1;
        if (currentStreak > longestStreak) {
          longestStreak = currentStreak;
        }
      } else {
        currentStreak = 0;
      }
    }

    return _MonthlyRecap(
      totalSpent: totalSpent,
      totalSaved: (state.settings.totalDailyBudget * 30 - totalSpent)
          .clamp(-999999, 999999)
          .toDouble(),
      longestStreak: longestStreak,
      biggestCategory: biggestCategory,
    );
  }

  Widget _periodScorecard(BudgetSummary summary) {
    final _PeriodStatusCard dayCard = _statusCardFor(
      'This day',
      summary.periodSummaries[BudgetPeriod.daily],
    );
    final _PeriodStatusCard weekCard = _statusCardFor(
      'This week',
      summary.periodSummaries[BudgetPeriod.weekly],
    );
    final _PeriodStatusCard monthCard = _statusCardFor(
      'This month',
      summary.periodSummaries[BudgetPeriod.monthly],
    );

    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Period scorecard',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              final bool compact = constraints.maxWidth < 520;
              if (compact) {
                return Column(
                  children: <Widget>[
                    _PeriodStatusTile(card: dayCard),
                    const SizedBox(height: 8),
                    _PeriodStatusTile(card: weekCard),
                    const SizedBox(height: 8),
                    _PeriodStatusTile(card: monthCard),
                  ],
                );
              }

              return Row(
                children: <Widget>[
                  Expanded(child: _PeriodStatusTile(card: dayCard)),
                  const SizedBox(width: 8),
                  Expanded(child: _PeriodStatusTile(card: weekCard)),
                  const SizedBox(width: 8),
                  Expanded(child: _PeriodStatusTile(card: monthCard)),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _reportsSection(BudgetBuddyState state) {
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Reports',
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            'Daily, weekly, and monthly saved vs overspent history.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 12),
          Row(
            children: _ReportsTab.values
                .map(
                  (_ReportsTab tab) => Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(
                        right: tab == _ReportsTab.values.last ? 0 : 8,
                      ),
                      child: ChoiceChip(
                        selected: _reportsTab == tab,
                        label: Text(tab.label),
                        onSelected: (_) {
                          setState(() => _reportsTab = tab);
                        },
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 12),
          if (_reportsTab == _ReportsTab.daily) ..._buildDailyReportRows(state),
          if (_reportsTab == _ReportsTab.weekly)
            ..._buildWeeklyReportRows(state),
          if (_reportsTab == _ReportsTab.monthly)
            ..._buildMonthlyReportRows(state),
        ],
      ),
    );
  }

  List<Widget> _buildDailyReportRows(BudgetBuddyState state) {
    final DateTime today = _startOfDay(DateTime.now());
    final double dailyLimit = state.settings.totalDailyBudget;
    final List<Widget> rows = <Widget>[];

    for (int i = 6; i >= 0; i--) {
      final DateTime day = today.subtract(Duration(days: i));
      final List<ExpenseEntry> dayExpenses = state.expenses
          .where((ExpenseEntry expense) => _sameDay(expense.dateTime, day))
          .toList();
      final double spent = dayExpenses.fold(
        0,
        (double sum, ExpenseEntry expense) => sum + expense.amount,
      );

      final _ReportStatus status = _statusFrom(spent, dailyLimit);
      final double ratio =
          dailyLimit <= 0 ? 0 : (spent / dailyLimit).clamp(0, 1);

      rows.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      _trendLabel(day),
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  Text(
                    formatPeso(spent),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(width: 8),
                  _reportBadge(status),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: ratio,
                  minHeight: 9,
                  backgroundColor: status.color.withValues(alpha: 0.12),
                  valueColor: AlwaysStoppedAnimation<Color>(status.color),
                ),
              ),
              const SizedBox(height: 4),
              Text(status.detail),
            ],
          ),
        ),
      );
    }

    return rows;
  }

  List<Widget> _buildWeeklyReportRows(BudgetBuddyState state) {
    final DateTime today = _startOfDay(DateTime.now());
    final DateTime currentWeekStart =
        today.subtract(Duration(days: today.weekday - DateTime.monday));
    final double weeklyLimit = state.settings.weeklyBudget ?? 0;
    final List<Widget> rows = <Widget>[];

    for (int weekOffset = 0; weekOffset < 4; weekOffset++) {
      final DateTime weekStart =
          currentWeekStart.subtract(Duration(days: weekOffset * 7));
      final DateTime weekEnd = weekStart.add(const Duration(days: 6));

      final List<ExpenseEntry> weekExpenses =
          state.expenses.where((ExpenseEntry expense) {
        final DateTime day = _startOfDay(expense.dateTime);
        return !day.isBefore(weekStart) && !day.isAfter(weekEnd);
      }).toList();

      final double spent = weekExpenses.fold(
        0,
        (double sum, ExpenseEntry expense) => sum + expense.amount,
      );

      final _ReportStatus status = _statusFrom(spent, weeklyLimit);

      rows.add(
        ExpansionTile(
          tilePadding: EdgeInsets.zero,
          title: Text(
            '${formatShortDate(weekStart)} - ${formatShortDate(weekEnd)}',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          subtitle: Text(
            'Spent ${formatPeso(spent)} of ${weeklyLimit > 0 ? formatPeso(weeklyLimit) : 'No weekly limit'}',
          ),
          trailing: _reportBadge(status),
          children: List<Widget>.generate(7, (int dayIndex) {
            final DateTime day = weekStart.add(Duration(days: dayIndex));
            final double daySpent = weekExpenses
                .where(
                    (ExpenseEntry expense) => _sameDay(expense.dateTime, day))
                .fold(0,
                    (double sum, ExpenseEntry expense) => sum + expense.amount);
            return ListTile(
              dense: true,
              title: Text(_trendLabel(day)),
              trailing: Text(formatPeso(daySpent)),
            );
          }),
        ),
      );
    }

    return rows;
  }

  List<Widget> _buildMonthlyReportRows(BudgetBuddyState state) {
    final DateTime now = DateTime.now();
    final double monthlyLimit = state.settings.monthlyBudget ?? 0;
    final List<Widget> rows = <Widget>[];

    for (int monthOffset = 0; monthOffset < 4; monthOffset++) {
      final DateTime monthStart =
          DateTime(now.year, now.month - monthOffset, 1);
      final DateTime nextMonth =
          DateTime(monthStart.year, monthStart.month + 1, 1);
      final DateTime monthEnd = nextMonth.subtract(const Duration(days: 1));

      final List<ExpenseEntry> monthExpenses =
          state.expenses.where((ExpenseEntry expense) {
        final DateTime day = _startOfDay(expense.dateTime);
        return !day.isBefore(monthStart) && day.isBefore(nextMonth);
      }).toList();

      final double spent = monthExpenses.fold(
        0,
        (double sum, ExpenseEntry expense) => sum + expense.amount,
      );
      final _ReportStatus status = _statusFrom(spent, monthlyLimit);

      final Map<BudgetCategory, double> categoryTotals =
          <BudgetCategory, double>{
        for (final BudgetCategory category in BudgetCategory.values)
          category: 0,
      };
      for (final ExpenseEntry expense in monthExpenses) {
        categoryTotals[expense.category] =
            (categoryTotals[expense.category] ?? 0) + expense.amount;
      }
      final String biggestCategory = categoryTotals.entries
          .reduce((a, b) => a.value >= b.value ? a : b)
          .key
          .label;

      final int savingsStreak =
          _monthSavingsStreak(state, monthStart, monthEnd);

      rows.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: status.color.withValues(alpha: 0.08),
              border: Border.all(color: status.color.withValues(alpha: 0.2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        _formatMonthYear(monthStart),
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                    _reportBadge(status),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Spent ${formatPeso(spent)} of ${monthlyLimit > 0 ? formatPeso(monthlyLimit) : 'No monthly limit'}',
                ),
                Text(status.detail),
                Text('Biggest category: $biggestCategory'),
                Text(
                    'Savings streak: $savingsStreak day${savingsStreak == 1 ? '' : 's'}'),
              ],
            ),
          ),
        ),
      );
    }

    return rows;
  }

  int _monthSavingsStreak(
    BudgetBuddyState state,
    DateTime monthStart,
    DateTime monthEnd,
  ) {
    if (state.settings.totalDailyBudget <= 0) {
      return 0;
    }

    final Map<DateTime, double> dayTotals = <DateTime, double>{};
    for (final ExpenseEntry expense in state.expenses) {
      final DateTime day = _startOfDay(expense.dateTime);
      if (day.isBefore(monthStart) || day.isAfter(monthEnd)) {
        continue;
      }
      dayTotals[day] = (dayTotals[day] ?? 0) + expense.amount;
    }

    int streak = 0;
    for (DateTime day = monthStart;
        !day.isAfter(monthEnd);
        day = day.add(const Duration(days: 1))) {
      final double spent = dayTotals[day] ?? 0;
      if (spent <= state.settings.totalDailyBudget) {
        streak += 1;
      }
    }
    return streak;
  }

  _ReportStatus _statusFrom(double spent, double limit) {
    if (limit <= 0) {
      return const _ReportStatus(
        label: 'On track',
        detail: 'No limit set for this period.',
        color: Color(0xFF64748B),
      );
    }

    if (spent > limit) {
      final double over = spent - limit;
      return _ReportStatus(
        label: 'Over',
        detail: 'Over ${formatPeso(over)}',
        color: const Color(0xFFDC2626),
      );
    }

    if (spent >= limit * 0.8) {
      return const _ReportStatus(
        label: 'On track',
        detail: 'Near limit',
        color: Color(0xFFF59E0B),
      );
    }

    return _ReportStatus(
      label: 'Saved',
      detail: 'Saved ${formatPeso(limit - spent)}',
      color: const Color(0xFF16A34A),
    );
  }

  Widget _reportBadge(_ReportStatus status) {
    return SoftPill(text: status.label, color: status.color);
  }

  _PeriodStatusCard _statusCardFor(String label, BudgetPeriodSummary? summary) {
    if (summary == null || !summary.isActive) {
      return _PeriodStatusCard(
        label: label,
        title: 'On track',
        amountText: 'No limit',
        color: const Color(0xFF64748B),
      );
    }

    if (summary.isOverspent) {
      return _PeriodStatusCard(
        label: label,
        title: 'Over',
        amountText: formatPeso(summary.overspentAmount),
        color: const Color(0xFFDC2626),
      );
    }

    if (summary.isWarning) {
      return _PeriodStatusCard(
        label: label,
        title: 'On track',
        amountText: formatPeso(summary.remaining),
        color: const Color(0xFFF59E0B),
      );
    }

    return _PeriodStatusCard(
      label: label,
      title: 'Saved',
      amountText: formatPeso(summary.saved),
      color: const Color(0xFF16A34A),
    );
  }
}

enum _ReportsTab { daily, weekly, monthly }

extension _ReportsTabX on _ReportsTab {
  String get label => switch (this) {
        _ReportsTab.daily => 'Daily',
        _ReportsTab.weekly => 'Weekly',
        _ReportsTab.monthly => 'Monthly',
      };
}

class _ReportStatus {
  const _ReportStatus({
    required this.label,
    required this.detail,
    required this.color,
  });

  final String label;
  final String detail;
  final Color color;
}

class _PeriodStatusCard {
  const _PeriodStatusCard({
    required this.label,
    required this.title,
    required this.amountText,
    required this.color,
  });

  final String label;
  final String title;
  final String amountText;
  final Color color;
}

class _PeriodStatusTile extends StatelessWidget {
  const _PeriodStatusTile({required this.card});

  final _PeriodStatusCard card;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: card.color.withValues(alpha: 0.10),
        border: Border.all(color: card.color.withValues(alpha: 0.24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            card.label,
            style: Theme.of(context)
                .textTheme
                .labelLarge
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            card.title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: card.color,
                ),
          ),
          const SizedBox(height: 2),
          Text(
            card.amountText,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: card.color,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ],
      ),
    );
  }
}

class _PeriodTabs extends StatelessWidget {
  const _PeriodTabs({required this.selectedPeriod, required this.onChanged});

  final DashboardPeriod selectedPeriod;
  final ValueChanged<DashboardPeriod> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: DashboardPeriod.values
          .map(
            (DashboardPeriod period) => Expanded(
              child: Padding(
                padding: EdgeInsets.only(
                  right: period == DashboardPeriod.values.last ? 0 : 8,
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(999),
                  onTap: () => onChanged(period),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: period == selectedPeriod
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context)
                              .colorScheme
                              .surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: period == selectedPeriod
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context)
                                .colorScheme
                                .outlineVariant
                                .withValues(alpha: 0.4),
                      ),
                    ),
                    child: Text(
                      period.label,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: period == selectedPeriod
                            ? Colors.white
                            : Theme.of(context).colorScheme.onSurface,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          )
          .toList(),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: <Widget>[
          CircleAvatar(
            radius: 16,
            backgroundColor:
                Theme.of(context).colorScheme.primary.withValues(alpha: 0.12),
            child: Icon(icon, size: 16),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Text(
            value,
            textAlign: TextAlign.end,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }
}

class _MonthlyRecap {
  const _MonthlyRecap({
    required this.totalSpent,
    required this.totalSaved,
    required this.longestStreak,
    required this.biggestCategory,
  });

  final double totalSpent;
  final double totalSaved;
  final int longestStreak;
  final String biggestCategory;
}

class _CategorySlice {
  const _CategorySlice({
    required this.category,
    required this.value,
    required this.percent,
  });

  final BudgetCategory category;
  final double value;
  final double percent;
}

class _PeriodAnalysis {
  const _PeriodAnalysis({
    required this.days,
    required this.expenses,
    required this.dailyTotals,
    required this.categoryTotals,
    required this.totalSpent,
    required this.savings,
    required this.totalBudget,
    required this.biggestCategory,
    required this.overspendingCategories,
    required this.dailyBudgetLimit,
    required this.maxYAxis,
  });

  final List<DateTime> days;
  final List<ExpenseEntry> expenses;
  final List<double> dailyTotals;
  final Map<BudgetCategory, double> categoryTotals;
  final double totalSpent;
  final double savings;
  final double totalBudget;
  final String biggestCategory;
  final List<String> overspendingCategories;
  final double dailyBudgetLimit;
  final double maxYAxis;
}
