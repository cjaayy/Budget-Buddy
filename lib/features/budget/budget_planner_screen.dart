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
  late final TextEditingController _monthlyController;
  FocusNode? _dailyFocusNode;
  FocusNode? _monthlyFocusNode;
  bool _seededFromState = false;

  @override
  void initState() {
    super.initState();
    _dailyController = TextEditingController();
    _monthlyController = TextEditingController();
  }

  @override
  void dispose() {
    _dailyController.dispose();
    _monthlyController.dispose();
    _dailyFocusNode?.dispose();
    _monthlyFocusNode?.dispose();
    super.dispose();
  }

  FocusNode get _dailyFocusNodeOrCreate => _dailyFocusNode ??= FocusNode();

  FocusNode get _monthlyFocusNodeOrCreate => _monthlyFocusNode ??= FocusNode();

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
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const SectionTitle(
                title: 'Budget planner',
                subtitle:
                    'Set daily and monthly limits. Any expense counts toward every active period.',
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ListView(
                  padding: EdgeInsets.zero,
                  children: <Widget>[
                    BudgetMetricCard(
                      label: 'Limits set',
                      value: '$activeLimitCount / 2',
                      subtitle: activeLimitCount == 0
                          ? 'Enable one or more limits to start tracking'
                          : activeLimitCount == 2
                              ? 'All periods active'
                              : '${2 - activeLimitCount} optional period${2 - activeLimitCount == 1 ? '' : 's'} still open',
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
                      focusNode: _dailyFocusNodeOrCreate,
                      icon: Icons.calendar_today_rounded,
                      periodSummary: periodSummaries[BudgetPeriod.daily],
                      onEdit: () => _startEditingLimit(
                        _dailyFocusNodeOrCreate,
                        _dailyController,
                      ),
                      onSave: () => _saveLimit(
                        state,
                        period: BudgetPeriod.daily,
                        controller: _dailyController,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _LimitEditorCard(
                      title: 'Max per month',
                      helper: 'Resets on the 1st of the month',
                      controller: _monthlyController,
                      focusNode: _monthlyFocusNodeOrCreate,
                      icon: Icons.calendar_month_rounded,
                      periodSummary: periodSummaries[BudgetPeriod.monthly],
                      onEdit: () => _startEditingLimit(
                        _monthlyFocusNodeOrCreate,
                        _monthlyController,
                      ),
                      onSave: () => _saveLimit(
                        state,
                        period: BudgetPeriod.monthly,
                        controller: _monthlyController,
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
                          ...<BudgetPeriod>[
                            BudgetPeriod.daily,
                            BudgetPeriod.monthly
                          ].map((BudgetPeriod period) {
                            final BudgetPeriodSummary? periodSummary =
                                periodSummaries[period];
                            if (periodSummary == null ||
                                !periodSummary.isActive) {
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
            ],
          ),
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
    _monthlyController.text = (state.settings.monthlyBudget ?? 0) > 0
        ? state.settings.monthlyBudget!.toStringAsFixed(0)
        : '';

    setState(() {
      _seededFromState = true;
    });
  }

  void _startEditingLimit(
      FocusNode focusNode, TextEditingController controller) {
    FocusScope.of(context).requestFocus(focusNode);
    controller.selection = TextSelection(
      baseOffset: 0,
      extentOffset: controller.text.length,
    );
  }

  Future<void> _saveLimit(
    BudgetBuddyState state, {
    required BudgetPeriod period,
    required TextEditingController controller,
  }) {
    final double limit = double.tryParse(controller.text.trim()) ?? 0;
    final BudgetSettings updatedSettings = switch (period) {
      BudgetPeriod.daily => state.settings.copyWith(
          dailyLimit: limit > 0 ? limit : null,
        ),
      BudgetPeriod.monthly => state.settings.copyWith(
          monthlyLimit: limit > 0 ? limit : null,
        ),
      BudgetPeriod.weekly => state.settings,
    };

    ref
        .read(budgetBuddyControllerProvider.notifier)
        .updateBudget(updatedSettings);

    return _showSavedModal(period);
  }

  Future<void> _showSavedModal(BudgetPeriod period) {
    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          icon: const Icon(Icons.check_circle_rounded),
          title: const Text('Limit saved'),
          content: Text('${period.label} limit saved successfully.'),
          actions: <Widget>[
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }
}

class _LimitEditorCard extends StatefulWidget {
  const _LimitEditorCard({
    required this.title,
    required this.helper,
    required this.controller,
    required this.focusNode,
    required this.icon,
    required this.periodSummary,
    required this.onEdit,
    required this.onSave,
  });

  final String title;
  final String helper;
  final TextEditingController controller;
  final FocusNode focusNode;
  final IconData icon;
  final BudgetPeriodSummary? periodSummary;
  final VoidCallback onEdit;
  final VoidCallback onSave;

  @override
  State<_LimitEditorCard> createState() => _LimitEditorCardState();
}

class _LimitEditorCardState extends State<_LimitEditorCard> {
  bool _isEditing = false;
  String? _editingSnapshot;

  @override
  Widget build(BuildContext context) {
    final BudgetPeriodSummary? summary = widget.periodSummary;
    final Color statusColor = summary == null
        ? const Color(0xFF64748B)
        : summary.isOverspent
            ? const Color(0xFFDC2626)
            : summary.isWarning
                ? const Color(0xFFF59E0B)
                : const Color(0xFF16A34A);
    final bool hasBudget = summary?.isActive ?? false;
    final bool hasChanges = _isEditing &&
        widget.controller.text.trim().isNotEmpty &&
        widget.controller.text != (_editingSnapshot ?? '');

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
                child: Icon(widget.icon, color: statusColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      widget.title,
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 2),
                    Text(widget.helper),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: widget.controller,
            focusNode: widget.focusNode,
            readOnly: !_isEditing,
            keyboardType: TextInputType.number,
            onChanged: (_) {
              if (mounted) {
                setState(() {});
              }
            },
            decoration: InputDecoration(
              labelText: widget.title,
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
          const SizedBox(height: 12),
          if (!_isEditing) ...<Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _beginEditing,
                    icon: const Icon(Icons.edit_rounded),
                    label: Text(hasBudget ? 'Edit' : 'Set it'),
                  ),
                ),
              ],
            ),
          ] else ...<Widget>[
            const SizedBox(height: 10),
            Row(
              children: <Widget>[
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _cancelEdit,
                    icon: const Icon(Icons.close_rounded),
                    label: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: hasChanges ? _confirmSave : null,
                    icon: const Icon(Icons.save_rounded),
                    label: const Text('Save'),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  void _beginEditing() {
    if (!_isEditing) {
      _editingSnapshot = widget.controller.text;
    }

    setState(() {
      _isEditing = true;
    });

    widget.onEdit();
  }

  void _cancelEdit() {
    if (_editingSnapshot != null) {
      widget.controller.text = _editingSnapshot!;
    }

    FocusScope.of(context).unfocus();

    setState(() {
      _isEditing = false;
    });
  }

  Future<void> _confirmSave() async {
    final bool? shouldSave = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Save changes?'),
          content: const Text('Do you want to save this budget limit now?'),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    if (!mounted || shouldSave != true) {
      return;
    }

    if (mounted) {
      setState(() {
        _isEditing = false;
        _editingSnapshot = widget.controller.text;
      });
    }

    widget.onSave();
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
