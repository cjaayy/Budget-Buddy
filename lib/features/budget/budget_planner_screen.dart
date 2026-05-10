import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

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
  late final TextEditingController _budgetController;
  late final TextEditingController _foodLimitController;
  late final TextEditingController _transportLimitController;
  late final TextEditingController _leisureLimitController;
  late final TextEditingController _savingsGoalController;

  BudgetExpiryPeriod _expiryPeriod = BudgetExpiryPeriod.daily;
  bool _autoRenewBudget = false;
  bool _seededFromState = false;

  @override
  void initState() {
    super.initState();
    _budgetController = TextEditingController();
    _foodLimitController = TextEditingController();
    _transportLimitController = TextEditingController();
    _leisureLimitController = TextEditingController();
    _savingsGoalController = TextEditingController();
  }

  @override
  void dispose() {
    _budgetController.dispose();
    _foodLimitController.dispose();
    _transportLimitController.dispose();
    _leisureLimitController.dispose();
    _savingsGoalController.dispose();
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

    final double currentBudget = state.settings.hasConfiguredBudget
        ? state.settings.totalDailyBudget
        : double.tryParse(_budgetController.text) ?? 0;
    final double gaugeProgress = currentBudget <= 0
        ? 0
        : (summary.totalSpent / currentBudget).clamp(0.0, 1.0).toDouble();
    final Color gaugeColor = gaugeProgress < 0.5
        ? const Color(0xFF16A34A)
        : gaugeProgress < 0.8
            ? const Color(0xFFF59E0B)
            : const Color(0xFFDC2626);
    final BudgetSuggestion? suggestion = _buildSuggestion(state);

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: <Widget>[
            const SectionTitle(
              title: 'Budget planner',
              subtitle: 'Set your budget, limits, and reset timing.',
            ),
            const SizedBox(height: 16),
            if (suggestion != null) ...<Widget>[
              SectionCard(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: Theme.of(context)
                            .colorScheme
                            .primary
                            .withValues(alpha: 0.10),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.auto_graph_rounded,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            suggestion.title,
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 4),
                          Text(suggestion.body),
                          const SizedBox(height: 10),
                          FilledButton.tonalIcon(
                            onPressed: () {
                              _budgetController.text =
                                  suggestion.amount.toStringAsFixed(0);
                              if (_expiryPeriod != suggestion.period) {
                                setState(
                                    () => _expiryPeriod = suggestion.period);
                              }
                            },
                            icon: const Icon(Icons.check_rounded),
                            label: const Text('Use suggestion'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
            SectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Text(
                    'Quick Budget',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _budgetController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Budget amount',
                      prefixText: '₱ ',
                    ),
                  ),
                  const SizedBox(height: 14),
                  _buildLiveGauge(context, gaugeProgress, gaugeColor),
                  const SizedBox(height: 16),
                  const Text(
                    'Budget expires after:',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: BudgetExpiryPeriod.values
                        .map(
                          (BudgetExpiryPeriod period) => Expanded(
                            child: Padding(
                              padding: EdgeInsets.only(
                                right: period == BudgetExpiryPeriod.monthly
                                    ? 0
                                    : 8,
                              ),
                              child: _ExpiryTile(
                                selected: _expiryPeriod == period,
                                title: _expiryTitle(period),
                                subtitle: _expiryResetLabel(period),
                                onTap: () {
                                  setState(() => _expiryPeriod = period);
                                },
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                  const SizedBox(height: 14),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: _autoRenewBudget,
                    onChanged: (bool value) {
                      setState(() => _autoRenewBudget = value);
                    },
                    title: const Text('Auto-renew when expired'),
                    subtitle: const Text(
                      'Keep the same budget active when the reset date passes.',
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () => _applyQuickBudget(summary),
                      child: const Text('Apply Budget'),
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
                  Text(
                    'Per-category sub-limits',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Set slices of the total budget so alerts can warn you earlier.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 12),
                  _BudgetLimitField(
                    label: 'Food limit',
                    hint: 'For meals and snacks',
                    controller: _foodLimitController,
                    icon: Icons.restaurant_rounded,
                  ),
                  const SizedBox(height: 10),
                  _BudgetLimitField(
                    label: 'Transport limit',
                    hint: 'For jeep, bus, ride-hailing',
                    controller: _transportLimitController,
                    icon: Icons.directions_transit_rounded,
                  ),
                  const SizedBox(height: 10),
                  _BudgetLimitField(
                    label: 'Leisure limit',
                    hint: 'For trips, entertainment, extras',
                    controller: _leisureLimitController,
                    icon: Icons.movie_rounded,
                  ),
                  const SizedBox(height: 10),
                  _BudgetLimitField(
                    label: 'Savings goal',
                    hint: 'What you want to keep aside',
                    controller: _savingsGoalController,
                    icon: Icons.lock_rounded,
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
                    'Budget history',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Recent daily results from the app so you can compare what you planned vs what you used.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 12),
                  if (state.dailyRecords.isEmpty)
                    const Text(
                        'No history yet. Save a budget and come back later.')
                  else
                    ...state.dailyRecords.reversed.take(6).map(
                          (DailyRecord record) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: CircleAvatar(
                                backgroundColor: record.remainingBalance >= 0
                                    ? const Color(0xFF0F766E)
                                        .withValues(alpha: 0.12)
                                    : const Color(0xFFDC2626)
                                        .withValues(alpha: 0.12),
                                child: Icon(
                                  record.remainingBalance >= 0
                                      ? Icons.check_circle_rounded
                                      : Icons.warning_rounded,
                                  color: record.remainingBalance >= 0
                                      ? const Color(0xFF0F766E)
                                      : const Color(0xFFDC2626),
                                ),
                              ),
                              title: Text(
                                formatShortDate(record.date),
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700),
                              ),
                              subtitle: Text(
                                'Set ${formatPeso(record.totalSpent + record.remainingBalance)} • spent ${formatPeso(record.totalSpent)} • ${record.remainingBalance >= 0 ? 'under budget' : 'over budget'}',
                              ),
                              trailing: Text(
                                formatPeso(record.remainingBalance),
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: record.remainingBalance >= 0
                                      ? const Color(0xFF0F766E)
                                      : const Color(0xFFDC2626),
                                ),
                              ),
                            ),
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

  void _seedFromState(BudgetBuddyState state) {
    if (_seededFromState) {
      return;
    }

    _budgetController.text = state.settings.totalDailyBudget > 0
        ? state.settings.totalDailyBudget.toStringAsFixed(0)
        : '';
    _foodLimitController.text = state.settings.foodBudget > 0
        ? state.settings.foodBudget.toStringAsFixed(0)
        : '';
    _transportLimitController.text = state.settings.transportationBudget > 0
        ? state.settings.transportationBudget.toStringAsFixed(0)
        : '';
    _leisureLimitController.text = state.settings.leisureBudget > 0
        ? state.settings.leisureBudget.toStringAsFixed(0)
        : '';
    _savingsGoalController.text = state.settings.savingsGoal > 0
        ? state.settings.savingsGoal.toStringAsFixed(0)
        : '';
    setState(() {
      _expiryPeriod = state.settings.budgetExpiryPeriod;
      _autoRenewBudget = state.settings.autoRenewBudget;
      _seededFromState = true;
    });
  }

  Widget _buildLiveGauge(
    BuildContext context,
    double gaugeProgress,
    Color gaugeColor,
  ) {
    final BudgetBuddyState state = ref.watch(budgetBuddyControllerProvider);
    final BudgetSummary summary = ref.watch(budgetSummaryProvider);

    if (!state.settings.hasConfiguredBudget) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Theme.of(context)
              .colorScheme
              .surfaceContainerHighest
              .withValues(alpha: 0.35),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          'Set a budget to unlock the live spend gauge.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: gaugeProgress,
            minHeight: 12,
            backgroundColor: gaugeColor.withValues(alpha: 0.14),
            valueColor: AlwaysStoppedAnimation<Color>(gaugeColor),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Spent ${formatPeso(summary.totalSpent)} of ${formatPeso(state.settings.totalDailyBudget)}',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ],
    );
  }

  Future<void> _applyQuickBudget(BudgetSummary summary) async {
    final double amount = double.tryParse(_budgetController.text) ?? 0;
    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid budget amount')),
      );
      return;
    }

    if (summary.totalSpent > amount) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("You've already exceeded this budget today."),
        ),
      );
      return;
    }

    final BudgetBuddyState currentState =
        ref.read(budgetBuddyControllerProvider);
    final BudgetSettings currentSettings = currentState.settings;

    if (_hasActiveBudget(currentSettings)) {
      final bool replace = await _confirmOverwriteBudget(currentSettings);
      if (!replace) {
        return;
      }
      if (!mounted) return;
    }

    final BudgetSettings visibleSettings = currentSettings.hasConfiguredBudget
        ? currentSettings
        : BudgetSettings.defaults();
    final double foodBudget = double.tryParse(_foodLimitController.text) ??
        visibleSettings.foodBudget;
    final double transportationBudget =
        double.tryParse(_transportLimitController.text) ??
            visibleSettings.transportationBudget;
    final double leisureBudget =
        double.tryParse(_leisureLimitController.text) ??
            visibleSettings.leisureBudget;
    final double savingsGoal = double.tryParse(_savingsGoalController.text) ??
        visibleSettings.savingsGoal;

    ref.read(budgetBuddyControllerProvider.notifier).updateBudget(
          BudgetSettings(
            totalDailyBudget: amount,
            foodBudget: foodBudget,
            transportationBudget: transportationBudget,
            leisureBudget: leisureBudget,
            savingsGoal: savingsGoal,
            autoRenewBudget: _autoRenewBudget,
            budgetExpiryPeriod: _expiryPeriod,
            budgetCreatedAt: DateTime.now(),
          ),
        );

    if (!mounted) return;
    setState(() {
      _budgetController.text = amount.toStringAsFixed(0);
      _foodLimitController.text =
          foodBudget > 0 ? foodBudget.toStringAsFixed(0) : '';
      _transportLimitController.text = transportationBudget > 0
          ? transportationBudget.toStringAsFixed(0)
          : '';
      _leisureLimitController.text =
          leisureBudget > 0 ? leisureBudget.toStringAsFixed(0) : '';
      _savingsGoalController.text =
          savingsGoal > 0 ? savingsGoal.toStringAsFixed(0) : '';
      _seededFromState = true;
    });

    final String resetLabel = _expiryResetLabel(_expiryPeriod);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Budget set to ${formatPeso(amount)}. $resetLabel',
        ),
      ),
    );
  }

  Future<bool> _confirmOverwriteBudget(BudgetSettings currentSettings) async {
    final Duration remaining = _remainingUntilReset(currentSettings);
    final String remainingText = remaining.inDays >= 1
        ? '${remaining.inDays} day${remaining.inDays == 1 ? '' : 's'} remaining'
        : remaining.inHours >= 1
            ? '${remaining.inHours} hour${remaining.inHours == 1 ? '' : 's'} remaining'
            : '${remaining.inMinutes.clamp(1, 59)} minute${remaining.inMinutes.clamp(1, 59) == 1 ? '' : 's'} remaining';

    final bool? result = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Replace current budget with $remainingText?'),
          content: Text(
            'This will overwrite your active ${_expiryTitle(currentSettings.budgetExpiryPeriod).toLowerCase()} budget of ${formatPeso(currentSettings.totalDailyBudget)}.',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Replace'),
            ),
          ],
        );
      },
    );

    return result ?? false;
  }

  bool _hasActiveBudget(BudgetSettings settings) {
    return settings.hasConfiguredBudget &&
        !_remainingUntilReset(settings).isNegative;
  }

  Duration _remainingUntilReset(BudgetSettings settings) {
    final DateTime? createdAt = settings.budgetCreatedAt;
    if (createdAt == null) {
      return Duration.zero;
    }

    final Duration cycle = switch (settings.budgetExpiryPeriod) {
      BudgetExpiryPeriod.daily => const Duration(days: 1),
      BudgetExpiryPeriod.weekly => const Duration(days: 7),
      BudgetExpiryPeriod.monthly => const Duration(days: 30),
    };

    return createdAt.add(cycle).difference(DateTime.now());
  }

  BudgetSuggestion? _buildSuggestion(BudgetBuddyState state) {
    final List<DailyRecord> recentRecords =
        state.dailyRecords.reversed.take(7).toList();
    if (recentRecords.length < 3) {
      return null;
    }

    final double totalSpent = recentRecords.fold(
      0,
      (double sum, DailyRecord record) => sum + record.totalSpent,
    );
    if (totalSpent <= 0) {
      return null;
    }

    final double averageDaily = totalSpent / recentRecords.length;
    final double suggestedAmount =
        averageDaily * _expiryMultiplier(_expiryPeriod);
    final String amountLabel = formatPeso(averageDaily);
    final String suggestedLabel = formatPeso(suggestedAmount);

    return BudgetSuggestion(
      title: 'Suggested budget from your history',
      body:
          'Based on your last ${recentRecords.length} days, you average $amountLabel/day. Suggested budget: $suggestedLabel/${_expiryShortLabel(_expiryPeriod)}.',
      amount: suggestedAmount,
      period: _expiryPeriod,
    );
  }

  double _expiryMultiplier(BudgetExpiryPeriod period) {
    return switch (period) {
      BudgetExpiryPeriod.daily => 1.0,
      BudgetExpiryPeriod.weekly => 7.0,
      BudgetExpiryPeriod.monthly => 30.0,
    };
  }

  String _expiryShortLabel(BudgetExpiryPeriod period) {
    return switch (period) {
      BudgetExpiryPeriod.daily => 'day',
      BudgetExpiryPeriod.weekly => 'week',
      BudgetExpiryPeriod.monthly => 'month',
    };
  }

  String _expiryTitle(BudgetExpiryPeriod period) {
    return switch (period) {
      BudgetExpiryPeriod.daily => '1 Day',
      BudgetExpiryPeriod.weekly => '1 Week',
      BudgetExpiryPeriod.monthly => '1 Month',
    };
  }

  String _expiryResetLabel(BudgetExpiryPeriod period) {
    final Duration cycle = switch (period) {
      BudgetExpiryPeriod.daily => const Duration(days: 1),
      BudgetExpiryPeriod.weekly => const Duration(days: 7),
      BudgetExpiryPeriod.monthly => const Duration(days: 30),
    };
    final DateTime resetDate = DateTime.now().add(cycle);
    return 'resets ${DateFormat('MMM d').format(resetDate)}';
  }
}

class _ExpiryTile extends StatelessWidget {
  const _ExpiryTile({
    required this.selected,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final bool selected;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            color: selected
                ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.10)
                : Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: selected
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context)
                      .colorScheme
                      .outlineVariant
                      .withValues(alpha: 0.35),
            ),
          ),
          child: Column(
            children: <Widget>[
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: selected
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BudgetLimitField extends StatelessWidget {
  const _BudgetLimitField({
    required this.label,
    required this.hint,
    required this.controller,
    required this.icon,
  });

  final String label;
  final String hint;
  final TextEditingController controller;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon),
        prefixText: '₱ ',
      ),
    );
  }
}

class BudgetSuggestion {
  const BudgetSuggestion({
    required this.title,
    required this.body,
    required this.amount,
    required this.period,
  });

  final String title;
  final String body;
  final double amount;
  final BudgetExpiryPeriod period;
}
