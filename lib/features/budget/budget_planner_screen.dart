import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/budget_models.dart';
import '../../core/state/app_controller.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/budget_cards.dart';
import '../../core/widgets/section_title.dart';

class BudgetPlannerScreen extends ConsumerStatefulWidget {
  const BudgetPlannerScreen({super.key});

  @override
  ConsumerState<BudgetPlannerScreen> createState() =>
      _BudgetPlannerScreenState();
}

class _BudgetPlannerScreenState extends ConsumerState<BudgetPlannerScreen> {
  late final TextEditingController _dailyController;
  late final TextEditingController _weeklyController;
  late final TextEditingController _monthlyController;
  bool _seededFromState = false;

  @override
  void initState() {
    super.initState();
    _dailyController = TextEditingController();
    _weeklyController = TextEditingController();
    _monthlyController = TextEditingController();
  }

  @override
  void dispose() {
    _dailyController.dispose();
    _weeklyController.dispose();
    _monthlyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final BudgetBuddyState state = ref.watch(budgetBuddyControllerProvider);
    final BudgetSummary summary = ref.watch(budgetSummaryProvider);

    if (!_seededFromState && !state.isBootstrapping) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _seedFromState(state);
        }
      });
    }

    final int activeLimitCount = state.settings.activeLimitCount;
    final Map<BudgetPeriod, BudgetPeriodSummary> periodSummaries =
        summary.periodSummaries;

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: <Widget>[
            const SectionTitle(
              title: 'Budget planner',
              subtitle:
                  'Set daily, weekly, and monthly limits. Any expense counts toward every active period.',
            ),
            const SizedBox(height: 16),
            BudgetMetricCard(
              label: 'Limits set',
              value: '$activeLimitCount / 3',
              subtitle: activeLimitCount == 0
                  ? 'Enable one or more limits to start tracking'
                  : activeLimitCount == 3
                      ? 'All periods active'
                      : '${3 - activeLimitCount} optional period${3 - activeLimitCount == 1 ? '' : 's'} still open',
              icon: Icons.layers_rounded,
              color: activeLimitCount == 0
                  ? const Color(0xFF64748B)
                  : const Color(0xFF0F766E),
            ),
            const SizedBox(height: 16),
            _LimitEditorCard(
              title: 'Max per day',
              helper: 'Resets every midnight',
              controller: _dailyController,
              icon: Icons.calendar_today_rounded,
              periodSummary: periodSummaries[BudgetPeriod.daily],
            ),
            const SizedBox(height: 12),
            _LimitEditorCard(
              title: 'Max per week',
              helper: 'Resets every Monday',
              controller: _weeklyController,
              icon: Icons.date_range_rounded,
              periodSummary: periodSummaries[BudgetPeriod.weekly],
            ),
            const SizedBox(height: 12),
            _LimitEditorCard(
              title: 'Max per month',
              helper: 'Resets on the 1st of the month',
              controller: _monthlyController,
              icon: Icons.calendar_month_rounded,
              periodSummary: periodSummaries[BudgetPeriod.monthly],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => _saveLimits(state),
                icon: const Icon(Icons.save_rounded),
                label: const Text('Save limits'),
              ),
            ),
            const SizedBox(height: 16),
            SectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Rules & behaviors',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 12),
                  const _RuleTile(
                    icon: Icons.warning_amber_rounded,
                    color: Color(0xFFF59E0B),
                    title: 'Warning thresholds',
                    body:
                        'Amber at 80%. Red at 100%. The app will surface messages like “You\'re ₱120 from your daily limit.”',
                  ),
                  const SizedBox(height: 12),
                  const _RuleTile(
                    icon: Icons.block_rounded,
                    color: Color(0xFFDC2626),
                    title: 'Overspend indicator, not a blocker',
                    body:
                        'You can still log expenses over the limit. They are marked Overspent and carried into the report as over-limit spend.',
                  ),
                  const SizedBox(height: 12),
                  const _RuleTile(
                    icon: Icons.restart_alt_rounded,
                    color: Color(0xFF2563EB),
                    title: 'Auto-reset per period',
                    body:
                        'Daily resets at midnight, weekly resets Monday 12:00 AM, and monthly resets on the 1st. Saved balances carry forward in the report.',
                  ),
                  const SizedBox(height: 12),
                  const _RuleTile(
                    icon: Icons.toggle_on_rounded,
                    color: Color(0xFF7C3AED),
                    title: 'Independent limits',
                    body:
                        'Set only one or two limits if you want. Blank fields stay inactive and do not block the other periods.',
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
                    'Live period status',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'The app deducts every new expense from whichever periods are active.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 12),
                  ...BudgetPeriod.values.map((BudgetPeriod period) {
                    final BudgetPeriodSummary? periodSummary =
                        periodSummaries[period];
                    if (periodSummary == null || !periodSummary.isActive) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _InactivePeriodRow(period: period),
                      );
                    }

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _ActivePeriodRow(summary: periodSummary),
                    );
                  }),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _seedFromState(BudgetBuddyState state) {
    if (_seededFromState) {
      return;
    }

    _dailyController.text = state.settings.totalDailyBudget > 0
        ? state.settings.totalDailyBudget.toStringAsFixed(0)
        : '';
    _weeklyController.text = (state.settings.weeklyBudget ?? 0) > 0
        ? state.settings.weeklyBudget!.toStringAsFixed(0)
        : '';
    _monthlyController.text = (state.settings.monthlyBudget ?? 0) > 0
        ? state.settings.monthlyBudget!.toStringAsFixed(0)
        : '';

    setState(() {
      _seededFromState = true;
    });
  }

  void _saveLimits(BudgetBuddyState state) {
    final double dailyLimit = double.tryParse(_dailyController.text) ?? 0;
    final double weeklyLimit = double.tryParse(_weeklyController.text) ?? 0;
    final double monthlyLimit = double.tryParse(_monthlyController.text) ?? 0;
    final bool hasActiveLimit =
        dailyLimit > 0 || weeklyLimit > 0 || monthlyLimit > 0;

    ref.read(budgetBuddyControllerProvider.notifier).updateBudget(
          state.settings.copyWith(
            totalDailyBudget: dailyLimit,
            weeklyBudget: weeklyLimit > 0 ? weeklyLimit : 0,
            monthlyBudget: monthlyLimit > 0 ? monthlyLimit : 0,
            budgetCreatedAt: hasActiveLimit ? DateTime.now() : null,
          ),
        );

    setState(() {
      _seededFromState = true;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          hasActiveLimit
              ? 'Budget limits saved. All active periods now track together.'
              : 'All limits cleared. Add at least one limit to start tracking.',
        ),
      ),
    );
  }
}

class _LimitEditorCard extends StatelessWidget {
  const _LimitEditorCard({
    required this.title,
    required this.helper,
    required this.controller,
    required this.icon,
    required this.periodSummary,
  });

  final String title;
  final String helper;
  final TextEditingController controller;
  final IconData icon;
  final BudgetPeriodSummary? periodSummary;

  @override
  Widget build(BuildContext context) {
    final BudgetPeriodSummary? summary = periodSummary;
    final Color statusColor = summary == null
        ? const Color(0xFF64748B)
        : summary.isOverspent
            ? const Color(0xFFDC2626)
            : summary.isWarning
                ? const Color(0xFFF59E0B)
                : const Color(0xFF16A34A);

    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: statusColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      title,
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 2),
                    Text(helper),
                  ],
                ),
              ),
              if (summary != null)
                SoftPill(
                  text: summary.statusLabel,
                  color: statusColor,
                ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: title,
              prefixText: '₱ ',
              hintText: 'Leave blank to disable',
              helperText: summary == null
                  ? 'Inactive until you add a value.'
                  : summary.warningMessage,
            ),
          ),
          if (summary != null) ...<Widget>[
            const SizedBox(height: 10),
            LinearProgressIndicator(
              value: summary.limit <= 0
                  ? 0
                  : (summary.spent / summary.limit).clamp(0.0, 1.0),
              minHeight: 10,
              backgroundColor: statusColor.withValues(alpha: 0.14),
              valueColor: AlwaysStoppedAnimation<Color>(statusColor),
            ),
            const SizedBox(height: 8),
            Text(
              '${formatPeso(summary.spent)} spent • ${formatPeso(summary.remaining.abs())} ${summary.isOverspent ? 'over' : 'left'} • ${summary.resetLabel}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ],
      ),
    );
  }
}

class _ActivePeriodRow extends StatelessWidget {
  const _ActivePeriodRow({required this.summary});

  final BudgetPeriodSummary summary;

  @override
  Widget build(BuildContext context) {
    final Color color = summary.isOverspent
        ? const Color(0xFFDC2626)
        : summary.isWarning
            ? const Color(0xFFF59E0B)
            : const Color(0xFF16A34A);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Row(
        children: <Widget>[
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(
              summary.isOverspent
                  ? Icons.warning_rounded
                  : summary.isWarning
                      ? Icons.info_rounded
                      : Icons.check_circle_rounded,
              color: color,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  '${summary.period.label} limit',
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 2),
                Text(summary.warningMessage),
                const SizedBox(height: 4),
                Text(
                  '${formatPeso(summary.spent)} spent of ${formatPeso(summary.limit)} • ${summary.resetLabel}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          SoftPill(
            text: summary.statusLabel,
            color: color,
          ),
        ],
      ),
    );
  }
}

class _InactivePeriodRow extends StatelessWidget {
  const _InactivePeriodRow({required this.period});

  final BudgetPeriod period;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context)
            .colorScheme
            .surfaceContainerHighest
            .withValues(alpha: 0.28),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: <Widget>[
          const Icon(Icons.radio_button_unchecked_rounded,
              color: Color(0xFF64748B)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  '${period.label} limit is inactive',
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 2),
                Text(period.resetLabel),
              ],
            ),
          ),
          const SoftPill(
            text: 'Disabled',
            color: Color(0xFF64748B),
          ),
        ],
      ),
    );
  }
}

class _RuleTile extends StatelessWidget {
  const _RuleTile({
    required this.icon,
    required this.color,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                title,
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 2),
              Text(body),
            ],
          ),
        ),
      ],
    );
  }
}
