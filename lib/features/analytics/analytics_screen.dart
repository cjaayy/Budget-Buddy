import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/budget_models.dart';
import '../../core/state/app_controller.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/budget_cards.dart';
import '../../core/widgets/section_title.dart';

class AnalyticsScreen extends ConsumerWidget {
  const AnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final BudgetSummary summary = ref.watch(budgetSummaryProvider);
    final List<DailyRecord> records =
        ref.watch(budgetBuddyControllerProvider).dailyRecords;

    final List<FlSpot> spendingSpots = <FlSpot>[
      for (int i = 0; i < records.length; i++)
        FlSpot(i.toDouble(), records[i].totalSpent),
    ];

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: <Widget>[
            const SectionTitle(
                title: 'Analytics',
                subtitle: 'Track daily spending, savings, and trends.'),
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
                  label: 'Total spent',
                  value: formatPeso(summary.totalSpent),
                  subtitle: 'Today',
                  icon: Icons.payments_rounded,
                  color: const Color(0xFF2563EB),
                ),
                BudgetMetricCard(
                  label: 'Savings achieved',
                  value: formatPeso(summary.savings),
                  subtitle: 'Current day',
                  icon: Icons.lock_rounded,
                  color: const Color(0xFF0F766E),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text('Spending trend',
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 240,
                    child: LineChart(
                      LineChartData(
                        gridData: const FlGridData(show: false),
                        titlesData: FlTitlesData(
                          leftTitles: const AxisTitles(
                              sideTitles: SideTitles(
                                  showTitles: true, reservedSize: 40)),
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              getTitlesWidget: (double value, TitleMeta meta) {
                                final int index = value.toInt();
                                if (index < 0 || index >= records.length) {
                                  return const SizedBox.shrink();
                                }
                                return Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Text(
                                      formatDayLabel(records[index].date),
                                      style: const TextStyle(fontSize: 10)),
                                );
                              },
                              reservedSize: 26,
                            ),
                          ),
                          topTitles: const AxisTitles(
                              sideTitles: SideTitles(showTitles: false)),
                          rightTitles: const AxisTitles(
                              sideTitles: SideTitles(showTitles: false)),
                        ),
                        borderData: FlBorderData(show: false),
                        lineBarsData: <LineChartBarData>[
                          LineChartBarData(
                            spots: spendingSpots,
                            isCurved: true,
                            color: Theme.of(context).colorScheme.primary,
                            barWidth: 4,
                            dotData: const FlDotData(show: false),
                            belowBarData: BarAreaData(
                                show: true,
                                color: Theme.of(context)
                                    .colorScheme
                                    .primary
                                    .withValues(alpha: 0.12)),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text('Category mix',
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 220,
                    child: PieChart(
                      PieChartData(
                        centerSpaceRadius: 44,
                        sectionsSpace: 2,
                        sections: summary.categoryTotals.entries
                            .map((MapEntry<String, double> entry) {
                          final BudgetCategory category =
                              BudgetCategoryX.fromString(
                                  entry.key.toLowerCase());
                          return PieChartSectionData(
                            value: entry.value,
                            title:
                                entry.value > 0 ? formatPeso(entry.value) : '',
                            radius: 64,
                            color: category.color,
                            titleStyle: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 11),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text('End-of-day summary',
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 12),
                  Text(
                      'You spent ${formatPeso(summary.totalSpent)} out of ${formatPeso(summary.totalBudget)} today.'),
                  Text('You saved ${formatPeso(summary.savings)} today.'),
                  Text(
                      'Biggest expense category: ${summary.biggestExpenseCategory}'),
                  if (summary.overspendingCategories.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        'Overspending alerts: ${summary.overspendingCategories.join(', ')}',
                        style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                            fontWeight: FontWeight.w600),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
