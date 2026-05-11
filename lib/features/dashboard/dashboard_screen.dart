import 'package:fl_chart/fl_chart.dart';
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
    _selectedPeriod = ref.read(budgetBuddyControllerProvider).dashboardPeriod;
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
    final double savingsAdjusted = selectedSummary.saved;
    final List<ExpenseEntry> recentExpenses = state.expenses.take(5).toList();

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
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: _BudgetHeroCard(
                      summary: summary,
                      period: _selectedPeriod,
                      periodBudget: totalBudget,
                      periodSpent: spentAdjusted,
                      periodRemaining: remainingAdjusted,
                      periodSavings: savingsAdjusted,
                      expiryBanner: _buildBudgetExpiryBanner(state.settings),
                      onTap: () => _showMetricDetails(
                        context,
                        title: 'Remaining budget',
                        value: formatPeso(remainingAdjusted),
                        detail:
                            'This ring shows how much of your ${_selectedPeriod.label.toLowerCase()} budget has already been used.',
                        extra:
                            'Your selected period is ${_selectedPeriod.label.toLowerCase()} and the card scales the daily budget to match it.',
                      ),
                    ),
                  ),
                ),
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
                        BudgetMetricCard(
                          label: 'Today spent',
                          value: formatPeso(spentAdjusted),
                          subtitle: 'Out of ${formatPeso(totalBudget)}',
                          icon: Icons.payments_rounded,
                          color: const Color(0xFF2563EB),
                          onTap: () => _showMetricDetails(
                            context,
                            title: 'Today spent',
                            value: formatPeso(spentAdjusted),
                            detail:
                                'This is the current period total for your selected budget period.',
                            extra:
                                'Use the period selector to compare daily, weekly, and monthly views without auto-scaling.',
                          ),
                        ),
                        BudgetMetricCard(
                          label: 'Savings',
                          value: formatPeso(savingsAdjusted),
                          subtitle:
                              'Goal ${formatPeso(state.settings.savingsGoal)}',
                          icon: Icons.lock_rounded,
                          color: const Color(0xFFF97316),
                          onTap: () => _showMetricDetails(
                            context,
                            title: 'Savings',
                            value: formatPeso(savingsAdjusted),
                            detail:
                                'This shows how much of your selected period budget remains after spending.',
                            extra:
                                'Goal: ${formatPeso(state.settings.savingsGoal)}',
                          ),
                        ),
                        BudgetMetricCard(
                          label: 'Top category',
                          value: summary.biggestExpenseCategory,
                          subtitle: summary.overspendingCategories.isEmpty
                              ? 'Healthy pace'
                              : 'Watch overspending',
                          icon: Icons.pie_chart_rounded,
                          color: const Color(0xFF7C3AED),
                          onTap: () => _showMetricDetails(
                            context,
                            title: 'Top category',
                            value: summary.biggestExpenseCategory,
                            detail: summary.overspendingCategories.isEmpty
                                ? 'This is your highest-spending category right now.'
                                : 'This category is spending the most and needs attention.',
                            extra: summary.overspendingCategories.isEmpty
                                ? 'No overspending categories detected.'
                                : 'Watch: ${summary.overspendingCategories.join(', ')}',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: SectionCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          const SectionTitle(
                            title: 'Spending breakdown',
                            subtitle: 'Real-time category totals and trend',
                          ),
                          SizedBox(
                            height: 220,
                            child: PieChart(
                              PieChartData(
                                sectionsSpace: 3,
                                centerSpaceRadius: 44,
                                sections: summary.categoryTotals.entries
                                    .map((MapEntry<String, double> entry) {
                                  final BudgetCategory category =
                                      BudgetCategoryX.fromString(
                                          entry.key.toLowerCase());
                                  final double total = summary.totalSpent == 0
                                      ? 1
                                      : summary.totalSpent;
                                  return PieChartSectionData(
                                    value: entry.value,
                                    title: entry.value <= 0
                                        ? ''
                                        : '${(entry.value / total * 100).toStringAsFixed(0)}%',
                                    color: category.color,
                                    radius: 64,
                                    titleStyle: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                        fontSize: 12),
                                  );
                                }).toList(),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: BudgetCategory.values
                                .map((BudgetCategory category) => SoftPill(
                                    text: category.label,
                                    color: category.color,
                                    icon: Icons.circle))
                                .toList(),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20),
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
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        const SectionTitle(
                          title: 'Recent transactions',
                          subtitle: 'Last 5 expenses you logged',
                        ),
                        const SizedBox(height: 12),
                        SectionCard(
                          child: Column(
                            children: recentExpenses
                                .map(
                                  (ExpenseEntry expense) => Padding(
                                    padding: const EdgeInsets.only(bottom: 12),
                                    child: ListTile(
                                      contentPadding: EdgeInsets.zero,
                                      leading: CircleAvatar(
                                        backgroundColor: expense.category.color
                                            .withValues(alpha: 0.14),
                                        child: Icon(
                                          _categoryIcon(expense.category),
                                          color: expense.category.color,
                                        ),
                                      ),
                                      title: Text(
                                        expense.title,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      subtitle: Text(
                                        '${expense.category.label} • ${formatShortDate(expense.dateTime)}',
                                      ),
                                      trailing: Text(
                                        formatPeso(expense.amount),
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                  ),
                                )
                                .toList(),
                          ),
                        ),
                      ],
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
      DashboardPeriod.weekly => BudgetPeriod.weekly,
      DashboardPeriod.monthly => BudgetPeriod.monthly,
    };
  }

  void _handleHorizontalDragEnd(DragEndDetails details) {
    final double velocity = details.primaryVelocity ?? 0;
    if (velocity.abs() < 250) {
      return;
    }

    const List<DashboardPeriod> periods = DashboardPeriod.values;
    final int currentIndex = periods.indexOf(_selectedPeriod);
    final int nextIndex = velocity < 0
        ? (currentIndex + 1) % periods.length
        : (currentIndex - 1 + periods.length) % periods.length;

    if (nextIndex != currentIndex) {
      setState(() => _selectedPeriod = periods[nextIndex]);
    }
  }

  String _budgetCountdownText(BudgetSettings settings) {
    final DateTime? createdAt = settings.budgetCreatedAt;
    if (createdAt == null) {
      return 'Budget reset timing will appear after you save a budget.';
    }

    final Duration cycle = switch (settings.budgetExpiryPeriod) {
      BudgetExpiryPeriod.daily => const Duration(days: 1),
      BudgetExpiryPeriod.weekly => const Duration(days: 7),
      BudgetExpiryPeriod.monthly => const Duration(days: 30),
    };
    final Duration remaining = createdAt.add(cycle).difference(DateTime.now());

    if (remaining.isNegative) {
      return 'Budget reset window reached. Save a new budget to start the next cycle.';
    }

    if (remaining.inDays >= 1) {
      return 'Budget resets in ${remaining.inDays} day${remaining.inDays == 1 ? '' : 's'}';
    }

    if (remaining.inHours >= 1) {
      return 'Budget resets in ${remaining.inHours} hour${remaining.inHours == 1 ? '' : 's'}';
    }

    final int minutes = remaining.inMinutes.clamp(1, 59);
    return 'Budget resets in $minutes minute${minutes == 1 ? '' : 's'}';
  }

  Widget? _buildBudgetExpiryBanner(BudgetSettings settings) {
    if (!settings.hasConfiguredBudget || settings.budgetCreatedAt == null) {
      return null;
    }

    return _BudgetCountdownBanner(message: _budgetCountdownText(settings));
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

  void _showMetricDetails(
    BuildContext context, {
    required String title,
    required String value,
    required String detail,
    required String extra,
  }) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (BuildContext context) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                title,
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              Text(
                value,
                style: Theme.of(context)
                    .textTheme
                    .headlineSmall
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Text(detail),
              const SizedBox(height: 8),
              Text(
                extra,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        );
      },
    );
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

class _BudgetHeroCard extends StatelessWidget {
  const _BudgetHeroCard({
    required this.summary,
    required this.period,
    required this.periodBudget,
    required this.periodSpent,
    required this.periodRemaining,
    required this.periodSavings,
    required this.expiryBanner,
    required this.onTap,
  });

  final BudgetSummary summary;
  final DashboardPeriod period;
  final double periodBudget;
  final double periodSpent;
  final double periodRemaining;
  final double periodSavings;
  final Widget? expiryBanner;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final double consumedRatio = periodBudget <= 0
        ? 0
        : (periodSpent / periodBudget).clamp(0.0, 1.0).toDouble();
    final Color ringColor = _ringColor(consumedRatio);
    final String statusLabel = consumedRatio < 0.5
        ? 'On track'
        : consumedRatio < 0.8
            ? 'Watch pace'
            : 'Near limit';

    return SectionCard(
      padding: const EdgeInsets.all(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: <Widget>[
                SizedBox(
                  width: 96,
                  height: 96,
                  child: Stack(
                    alignment: Alignment.center,
                    children: <Widget>[
                      CircularProgressIndicator(
                        value: consumedRatio,
                        strokeWidth: 7,
                        backgroundColor: ringColor.withValues(alpha: 0.16),
                        valueColor: AlwaysStoppedAnimation<Color>(ringColor),
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Text(
                            '${(consumedRatio * 100).round()}%',
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 18,
                            ),
                          ),
                          Text(
                            'used',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'Remaining budget',
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        formatPeso(periodRemaining),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context)
                            .textTheme
                            .headlineMedium
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${period.label} view • ${formatPeso(periodSpent)} spent of ${formatPeso(periodBudget)}',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: <Widget>[
                          _BudgetStatusChip(
                            label: statusLabel,
                            color: ringColor,
                          ),
                          _BudgetStatusChip(
                            label: 'Savings ${formatPeso(periodSavings)}',
                            color: const Color(0xFF0F766E),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            if (expiryBanner != null) expiryBanner!,
          ],
        ),
      ),
    );
  }

  Color _ringColor(double consumedRatio) {
    if (consumedRatio < 0.5) {
      return const Color(0xFF16A34A);
    }
    if (consumedRatio < 0.8) {
      return const Color(0xFFF59E0B);
    }
    return const Color(0xFFDC2626);
  }
}

class _BudgetStatusChip extends StatelessWidget {
  const _BudgetStatusChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _BudgetCountdownBanner extends StatelessWidget {
  const _BudgetCountdownBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.14),
        ),
      ),
      child: Row(
        children: <Widget>[
          Icon(
            Icons.schedule_rounded,
            size: 18,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
        ],
      ),
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
