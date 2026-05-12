import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';

import '../../core/models/budget_models.dart';
import '../../core/state/app_controller.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/budget_cards.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key, this.onGetStarted, this.onOpenSpend});

  final VoidCallback? onGetStarted;
  final VoidCallback? onOpenSpend;

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

  @override
  Widget build(BuildContext context) {
    final BudgetBuddyState state = ref.watch(budgetBuddyControllerProvider);
    final BudgetSummary summary = ref.watch(budgetSummaryProvider);
    final BudgetPeriodSummary selectedSummary =
        summary.periodSummaries[_budgetPeriodFor(_selectedPeriod)] ??
            BudgetPeriodSummary(
              period: _budgetPeriodFor(_selectedPeriod),
              limit: 0,
              spent: 0,
            );
    final bool hasConfiguredBudget = state.settings.hasConfiguredBudget;
    final bool hasExpenses = state.expenses.isNotEmpty;
    final double totalBudget = selectedSummary.limit;
    final double spentAdjusted = selectedSummary.spent;
    final double remainingAdjusted = selectedSummary.remaining;

    return Scaffold(
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onHorizontalDragEnd: _handleHorizontalDragEnd,
        child: SafeArea(
          child: CustomScrollView(
            slivers: <Widget>[
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                  child: _Header(summary: summary, profile: state.profile),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  child: _PeriodPills(
                    selectedPeriod: _selectedPeriod,
                    onChanged: (DashboardPeriod value) {
                      setState(() => _selectedPeriod = value);
                      ref
                          .read(budgetBuddyControllerProvider.notifier)
                          .setDashboardPeriod(value);
                    },
                  ),
                ),
              ),
              if (!hasConfiguredBudget || !hasExpenses)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                    child: _DashboardEmptyState(
                      title: hasConfiguredBudget
                          ? 'No expenses logged yet.'
                          : 'Set a budget to get started.',
                      body: hasConfiguredBudget
                          ? 'Log your first expense and the dashboard will start showing your ring, insights, and recent transactions.'
                          : 'Add a budget so the dashboard can track your ring, countdown banner, and spending breakdown.',
                      buttonLabel:
                          hasConfiguredBudget ? 'Go to Spend' : 'Go to Budget',
                      icon: hasConfiguredBudget
                          ? Icons.receipt_long_rounded
                          : Icons.savings_rounded,
                      onPressed: hasConfiguredBudget
                          ? widget.onOpenSpend
                          : widget.onGetStarted,
                    ),
                  ),
                )
              else ...<Widget>[
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                  sliver: SliverGrid(
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      mainAxisExtent: 148,
                    ),
                    delegate: SliverChildListDelegate(
                      <Widget>[
                        _RemainingBudgetRingCard(
                          remaining: remainingAdjusted,
                          total: totalBudget,
                          spent: spentAdjusted,
                        ),
                        BudgetMetricCard(
                          label: _selectedPeriod == DashboardPeriod.daily
                              ? 'Daily Spent'
                              : 'Monthly Spent',
                          value: formatPeso(spentAdjusted),
                          subtitle: 'Out of ${formatPeso(totalBudget)}',
                          icon: Icons.payments_rounded,
                          color: const Color(0xFF2563EB),
                        ),
                      ],
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                    child: _BudgetPieOverviewCard(
                      spent: spentAdjusted,
                      remaining: remainingAdjusted,
                      total: totalBudget,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
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

    const List<DashboardPeriod> periods = <DashboardPeriod>[
      DashboardPeriod.daily,
      DashboardPeriod.monthly,
    ];
    final int currentIndex = periods.indexOf(_selectedPeriod);
    final int nextIndex = velocity < 0
        ? (currentIndex + 1) % periods.length
        : (currentIndex - 1 + periods.length) % periods.length;

    if (nextIndex != currentIndex) {
      setState(() => _selectedPeriod = periods[nextIndex]);
    }
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.summary, required this.profile});

  final BudgetSummary summary;
  final UserProfile profile;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      child: Row(
        children: <Widget>[
          CircleAvatar(
            radius: 28,
            backgroundColor:
                Theme.of(context).colorScheme.primary.withValues(alpha: 0.12),
            child: Text(profile.avatarSeed,
                style: const TextStyle(fontWeight: FontWeight.w700)),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text('Hi, ${profile.displayName}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text(
                  'Today you have ${formatPeso(summary.remainingBalance)} left for the day.',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
          const Icon(Icons.bolt_rounded),
        ],
      ),
    );
  }
}

class _PeriodPills extends StatelessWidget {
  const _PeriodPills({
    required this.selectedPeriod,
    required this.onChanged,
  });

  final DashboardPeriod selectedPeriod;
  final ValueChanged<DashboardPeriod> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: const <DashboardPeriod>[
        DashboardPeriod.daily,
        DashboardPeriod.monthly,
      ]
          .map(
            (DashboardPeriod period) => Expanded(
              child: Padding(
                padding: EdgeInsets.only(
                  left: period == DashboardPeriod.monthly ? 6 : 0,
                  right: period == DashboardPeriod.daily ? 6 : 0,
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
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Text(
                          period.label,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: period == selectedPeriod
                                ? Colors.white
                                : Theme.of(context).colorScheme.onSurface,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          height: 3,
                          width: period == selectedPeriod ? 28 : 12,
                          decoration: BoxDecoration(
                            color: period == selectedPeriod
                                ? Colors.white
                                : Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant
                                    .withValues(alpha: 0.35),
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                      ],
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

class _DashboardEmptyState extends StatelessWidget {
  const _DashboardEmptyState({
    required this.title,
    required this.body,
    required this.buttonLabel,
    required this.icon,
    required this.onPressed,
  });

  final String title;
  final String body;
  final String buttonLabel;
  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: <Widget>[
          Container(
            width: 84,
            height: 84,
            decoration: BoxDecoration(
              color:
                  Theme.of(context).colorScheme.primary.withValues(alpha: 0.10),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              size: 40,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(height: 18),
          Text(
            title,
            textAlign: TextAlign.center,
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          Text(
            body,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: onPressed,
              child: Text(buttonLabel),
            ),
          ),
        ],
      ),
    );
  }
}

class _RemainingBudgetRingCard extends StatelessWidget {
  const _RemainingBudgetRingCard({
    required this.remaining,
    required this.total,
    required this.spent,
  });

  final double remaining;
  final double total;
  final double spent;

  @override
  Widget build(BuildContext context) {
    return BudgetMetricCard(
      label: 'Remaining Budget',
      value: formatPeso(remaining),
      subtitle: '${formatPeso(spent)} of ${formatPeso(total)}',
      icon: Icons.trending_down_rounded,
      color: const Color(0xFF059669),
    );
  }
}

class _BudgetPieOverviewCard extends StatelessWidget {
  const _BudgetPieOverviewCard({
    required this.spent,
    required this.remaining,
    required this.total,
  });

  final double spent;
  final double remaining;
  final double total;

  @override
  Widget build(BuildContext context) {
    final double safeSpent = spent < 0 ? 0 : spent;
    final double safeRemaining = remaining < 0 ? 0 : remaining;
    final bool hasAnyValue = safeSpent > 0 || safeRemaining > 0;
    final double chartSpent = hasAnyValue ? safeSpent : 1;
    final double chartRemaining = hasAnyValue ? safeRemaining : 0;
    final double spentRatio =
        total <= 0 ? 0 : (safeSpent / total).clamp(0.0, 1.0).toDouble();

    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Spending Split',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            'Current ${total > 0 ? '${(spentRatio * 100).round()}% used' : 'period has no budget set'}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 156,
            child: Row(
              children: <Widget>[
                SizedBox(
                  width: 150,
                  child: PieChart(
                    PieChartData(
                      centerSpaceRadius: 34,
                      sectionsSpace: 3,
                      startDegreeOffset: -90,
                      sections: <PieChartSectionData>[
                        PieChartSectionData(
                          value: chartSpent,
                          color: const Color(0xFFEF4444),
                          radius: 30,
                          title: hasAnyValue
                              ? '${(spentRatio * 100).round()}%'
                              : '',
                          titleStyle: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 11,
                          ),
                        ),
                        PieChartSectionData(
                          value: chartRemaining,
                          color: const Color(0xFF10B981),
                          radius: 30,
                          title: hasAnyValue
                              ? '${(100 - (spentRatio * 100)).round()}%'
                              : '',
                          titleStyle: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      _PieLegendItem(
                        color: const Color(0xFFEF4444),
                        label: 'Spent',
                        value: formatPeso(safeSpent),
                      ),
                      const SizedBox(height: 10),
                      _PieLegendItem(
                        color: const Color(0xFF10B981),
                        label: 'Remaining',
                        value: formatPeso(safeRemaining),
                      ),
                      const SizedBox(height: 10),
                      _PieLegendItem(
                        color: Theme.of(context).colorScheme.primary,
                        label: 'Budget',
                        value: formatPeso(total),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PieLegendItem extends StatelessWidget {
  const _PieLegendItem({
    required this.color,
    required this.label,
    required this.value,
  });

  final Color color;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(99),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          value,
          style: Theme.of(context)
              .textTheme
              .bodyMedium
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}
