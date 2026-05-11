import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/budget_models.dart';
import '../../core/state/app_controller.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/budget_cards.dart';
import '../../core/widgets/section_title.dart';

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
                              ? 'Today spent'
                              : 'Month spent',
                          value: formatPeso(spentAdjusted),
                          subtitle: 'Out of ${formatPeso(totalBudget)}',
                          icon: Icons.payments_rounded,
                          color: const Color(0xFF2563EB),
                        ),
                      ],
                    ),
                  ),
                ),
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(20, 28, 20, 0),
                    child: SectionTitle(
                      title: 'Insights',
                      subtitle: 'What the app wants you to know today',
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                    child: SectionCard(
                      child: Column(
                        children: summary.recommendedActions
                            .map(
                              (String tip) => ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: const Icon(Icons.auto_awesome_rounded),
                                title: Text(tip),
                              ),
                            )
                            .toList(),
                      ),
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
                  right: period == DashboardPeriod.monthly ? 0 : 8,
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

  Color _ringColor(double consumedRatio) {
    if (consumedRatio < 0.5) {
      return const Color(0xFF16A34A);
    }
    if (consumedRatio < 0.8) {
      return const Color(0xFFF59E0B);
    }
    return const Color(0xFFDC2626);
  }

  @override
  Widget build(BuildContext context) {
    final double consumedRatio =
        total <= 0 ? 0 : (spent / total).clamp(0.0, 1.0).toDouble();
    final Color ringColor = _ringColor(consumedRatio);

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: <Color>[
            const Color(0xFF059669).withValues(alpha: 0.92),
            const Color(0xFF059669).withValues(alpha: 0.72)
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: <BoxShadow>[
          BoxShadow(
              color: const Color(0xFF059669).withValues(alpha: 0.22),
              blurRadius: 24,
              offset: const Offset(0, 12)),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          mainAxisSize: MainAxisSize.max,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Container(
                  width: 30,
                  height: 30,
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.18),
                      shape: BoxShape.circle),
                  child: const Icon(Icons.trending_down_rounded,
                      size: 18, color: Colors.white),
                ),
                SizedBox(
                  width: 48,
                  height: 48,
                  child: Stack(
                    alignment: Alignment.center,
                    children: <Widget>[
                      CircularProgressIndicator(
                        value: consumedRatio,
                        strokeWidth: 4,
                        backgroundColor: ringColor.withValues(alpha: 0.16),
                        valueColor: AlwaysStoppedAnimation<Color>(ringColor),
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Text(
                            '${(consumedRatio * 100).round()}%',
                            maxLines: 1,
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 10,
                              color: Colors.white,
                              height: 1.0,
                            ),
                          ),
                          const SizedBox(height: 1),
                          Text(
                            'used',
                            maxLines: 1,
                            style: Theme.of(context)
                                .textTheme
                                .labelSmall
                                ?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white.withValues(alpha: 0.8),
                                  height: 1.0,
                                  fontSize: 7,
                                ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 5),
            Text(
              'Remaining Budget',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: Colors.white.withValues(alpha: 0.85), fontSize: 10),
            ),
            const SizedBox(height: 1),
            Text(
              formatPeso(remaining),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
            ),
            const SizedBox(height: 6),
            Text(
              '${formatPeso(spent)} of ${formatPeso(total)}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.white.withValues(alpha: 0.82),
                    fontSize: 10,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
