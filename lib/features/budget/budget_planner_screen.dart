import 'dart:async';

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
  late final TextEditingController _dailyController;
  final FocusNode _focusNode = FocusNode();
  final List<double> _quickPresets = const <double>[200, 300, 500, 1000, 1500];
  bool _isUnlockedForEditing = false;

  @override
  void initState() {
    super.initState();
    _dailyController = TextEditingController();
    final BudgetBuddyState state = ref.read(budgetBuddyControllerProvider);
    final double initialDaily = state.settings.dailyLimit ?? 0;
    if (initialDaily > 0) {
      _dailyController.text = initialDaily.toStringAsFixed(0);
    }
  }

  @override
  void dispose() {
    _dailyController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _saveBudget() {
    final String text = _dailyController.text.trim();
    final double? amount = double.tryParse(text);

    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid budget amount greater than ₱0.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    _focusNode.unfocus();
    ref
        .read(budgetBuddyControllerProvider.notifier)
        .recordDailyBudget(amount: amount);

    setState(() {
      _isUnlockedForEditing = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Today\'s budget set to ${formatPeso(amount)}! Input locked.'),
        backgroundColor: const Color(0xFF0F766E),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _confirmAndUpdateBudget(double currentBudget) async {
    final String text = _dailyController.text.trim();
    final double? newAmount = double.tryParse(text);

    if (newAmount == null || newAmount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid budget amount greater than ₱0.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    _focusNode.unfocus();

    final bool? confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext ctx) => _CountdownConfirmationDialog(
        title: 'Confirm Budget Update',
        message:
            'Update today\'s budget from ${formatPeso(currentBudget)} to ${formatPeso(newAmount)}?',
        confirmLabel: 'Update Now',
        confirmColor: const Color(0xFF0F766E),
        icon: Icons.sync_rounded,
      ),
    );

    if (!mounted || confirmed != true) {
      return;
    }

    ref
        .read(budgetBuddyControllerProvider.notifier)
        .recordDailyBudget(amount: newAmount);

    setState(() {
      _isUnlockedForEditing = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Today\'s budget updated to ${formatPeso(newAmount)}! Input locked.',
        ),
        backgroundColor: const Color(0xFF0F766E),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _confirmAndResetBudget() async {
    _focusNode.unfocus();

    final bool? confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext ctx) => const _CountdownConfirmationDialog(
        title: 'Confirm Budget Reset',
        message:
            'This will reset today\'s active budget and spending back to ₱0 so you can start a fresh new day.',
        confirmLabel: 'Reset Now',
        confirmColor: Color(0xFFDC2626),
        icon: Icons.restart_alt_rounded,
      ),
    );

    if (!mounted || confirmed != true) {
      return;
    }

    _dailyController.clear();
    ref.read(budgetBuddyControllerProvider.notifier).clearDailyBudget();

    setState(() {
      _isUnlockedForEditing = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Today\'s budget and spending have been reset to ₱0.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _applyPreset(double amount) {
    _dailyController.text = amount.toStringAsFixed(0);
    setState(() {});
  }

  void _unlockForEditing() {
    setState(() {
      _isUnlockedForEditing = true;
    });
    _focusNode.requestFocus();
  }

  void _cancelEditing(double currentBudget) {
    _focusNode.unfocus();
    setState(() {
      _isUnlockedForEditing = false;
      _dailyController.text =
          currentBudget > 0 ? currentBudget.toStringAsFixed(0) : '';
    });
  }

  @override
  Widget build(BuildContext context) {
    final BudgetBuddyState state = ref.watch(budgetBuddyControllerProvider);
    final BudgetSummary summary = ref.watch(budgetSummaryProvider);
    final devController = ref.read(budgetBuddyControllerProvider.notifier);
    final DateTime currentClock = devController.currentEffectiveTime;

    final BudgetPeriodSummary dailySummary =
        summary.periodSummaries[BudgetPeriod.daily] ??
            const BudgetPeriodSummary(
              period: BudgetPeriod.daily,
              limit: 0,
              spent: 0,
            );

    final BudgetPeriodSummary monthlySummary =
        summary.periodSummaries[BudgetPeriod.monthly] ??
            const BudgetPeriodSummary(
              period: BudgetPeriod.monthly,
              limit: 0,
              spent: 0,
            );

    final bool hasBudget = (state.settings.dailyLimit ?? 0) > 0;
    final double currentBudget = state.settings.dailyLimit ?? 0;
    final double currentSpent = state.dailySpent;
    final double remaining = currentBudget - currentSpent;

    final bool isLocked = hasBudget && !_isUnlockedForEditing;

    // Listen to external resets (e.g. 12 AM midnight reset) and update the text field
    ref.listen<BudgetBuddyState>(budgetBuddyControllerProvider,
        (BudgetBuddyState? prev, BudgetBuddyState next) {
      final double? nextLimit = next.settings.dailyLimit;
      final double? prevLimit = prev?.settings.dailyLimit;
      if (nextLimit != prevLimit) {
        if (nextLimit == null || nextLimit <= 0) {
          if (_dailyController.text.isNotEmpty) {
            _dailyController.clear();
          }
          setState(() {
            _isUnlockedForEditing = false;
          });
        } else {
          final String newText = nextLimit.toStringAsFixed(0);
          if (_dailyController.text != newText) {
            _dailyController.text = newText;
          }
        }
      }
    });

    final Color statusColor = dailySummary.isOverspent
        ? const Color(0xFFDC2626)
        : dailySummary.isWarning
            ? const Color(0xFFF59E0B)
            : const Color(0xFF0F766E);

    final double progressValue = currentBudget > 0
        ? (currentSpent / currentBudget).clamp(0.0, 1.0)
        : 0.0;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const SectionTitle(
                title: 'Daily Budget',
                subtitle:
                    'Set your spending limit and track your daily allowance.',
              ),
              const SizedBox(height: 8),
              // Clean Date & Status Pill
              Row(
                children: <Widget>[
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: Theme.of(context)
                          .colorScheme
                          .surfaceContainerHighest
                          .withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Icon(
                          Icons.today_rounded,
                          size: 14,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Today • ${DateFormat('EEE, MMM d').format(currentClock)}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: hasBudget
                          ? (isLocked
                              ? const Color(0xFF0F766E).withValues(alpha: 0.12)
                              : Colors.amber.withValues(alpha: 0.15))
                          : Colors.grey.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Icon(
                          isLocked
                              ? Icons.lock_rounded
                              : hasBudget
                                  ? Icons.lock_open_rounded
                                  : Icons.radio_button_unchecked_rounded,
                          size: 13,
                          color: hasBudget
                              ? (isLocked
                                  ? const Color(0xFF0F766E)
                                  : Colors.amber.shade800)
                              : Colors.grey.shade600,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          isLocked
                              ? 'Locked'
                              : hasBudget
                                  ? 'Editing'
                                  : 'No Budget Set',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: hasBudget
                                ? (isLocked
                                    ? const Color(0xFF0F766E)
                                    : Colors.amber.shade800)
                                : Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ListView(
                  padding: EdgeInsets.zero,
                  children: <Widget>[
                    // 1. Redesigned Clean Budget Set / Lock Card
                    SectionCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Row(
                            children: <Widget>[
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: (isLocked
                                          ? const Color(0xFF0F766E)
                                          : Colors.amber.shade800)
                                      .withValues(alpha: 0.12),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  isLocked
                                      ? Icons.lock_rounded
                                      : Icons.account_balance_wallet_rounded,
                                  color: isLocked
                                      ? const Color(0xFF0F766E)
                                      : Colors.amber.shade800,
                                  size: 22,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: <Widget>[
                                    Text(
                                      isLocked
                                          ? 'Daily Budget (Locked)'
                                          : hasBudget
                                              ? 'Edit Today\'s Budget'
                                              : 'Set Today\'s Budget',
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium
                                          ?.copyWith(
                                              fontWeight: FontWeight.w800),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      isLocked
                                          ? 'Your active budget is locked. Unlock to change amount.'
                                          : 'Enter your target allowance for today',
                                      style:
                                          Theme.of(context).textTheme.bodySmall,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          // Big Currency Input Box (locked when isLocked == true)
                          TextField(
                            controller: _dailyController,
                            focusNode: _focusNode,
                            readOnly: isLocked,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            style: TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5,
                              color: isLocked
                                  ? Theme.of(context).colorScheme.onSurface
                                  : const Color(0xFF0F766E),
                            ),
                            onChanged: (_) => setState(() {}),
                            onSubmitted: (_) {
                              if (!isLocked) {
                                if (hasBudget) {
                                  _confirmAndUpdateBudget(currentBudget);
                                } else {
                                  _saveBudget();
                                }
                              }
                            },
                            decoration: InputDecoration(
                              filled: isLocked,
                              fillColor: Theme.of(context)
                                  .colorScheme
                                  .surfaceContainerHighest
                                  .withValues(alpha: 0.4),
                              prefixIcon: Container(
                                padding: const EdgeInsets.only(
                                  left: 16,
                                  right: 8,
                                ),
                                alignment: Alignment.centerLeft,
                                width: 44,
                                child: Text(
                                  '₱',
                                  style: TextStyle(
                                    fontSize: 26,
                                    fontWeight: FontWeight.w800,
                                    color: isLocked
                                        ? Theme.of(context)
                                            .colorScheme
                                            .onSurfaceVariant
                                        : const Color(0xFF0F766E),
                                  ),
                                ),
                              ),
                              hintText: '0',
                              hintStyle: TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.w600,
                                color: Theme.of(context).hintColor,
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 16,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              suffixIcon: isLocked
                                  ? const Padding(
                                      padding: EdgeInsets.only(right: 14),
                                      child: Icon(Icons.lock_outline_rounded,
                                          size: 20),
                                    )
                                  : (_dailyController.text.isNotEmpty
                                      ? IconButton(
                                          icon: const Icon(Icons.clear_rounded),
                                          onPressed: () {
                                            _dailyController.clear();
                                            setState(() {});
                                          },
                                        )
                                      : null),
                            ),
                          ),
                          // Quick Preset Chips (Only visible when unlocked for editing)
                          if (!isLocked) ...<Widget>[
                            const SizedBox(height: 12),
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: _quickPresets.map((double preset) {
                                  final bool isSelected =
                                      _dailyController.text.trim() ==
                                          preset.toStringAsFixed(0);
                                  return Padding(
                                    padding: const EdgeInsets.only(right: 8),
                                    child: FilterChip(
                                      selected: isSelected,
                                      label:
                                          Text('₱${preset.toStringAsFixed(0)}'),
                                      onSelected: (_) => _applyPreset(preset),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      selectedColor: const Color(0xFF0F766E)
                                          .withValues(alpha: 0.2),
                                      showCheckmark: false,
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),
                          ],
                          const SizedBox(height: 16),

                          // Action Buttons
                          if (isLocked) ...<Widget>[
                            // Locked State: Show Unlock button and Reset button
                            Row(
                              children: <Widget>[
                                Expanded(
                                  child: FilledButton.tonalIcon(
                                    onPressed: _unlockForEditing,
                                    icon: const Icon(Icons.lock_open_rounded,
                                        size: 18),
                                    label: const Text('Unlock to Edit'),
                                    style: FilledButton.styleFrom(
                                      minimumSize: const Size.fromHeight(48),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: _confirmAndResetBudget,
                                    icon: const Icon(Icons.refresh_rounded,
                                        size: 18, color: Color(0xFFDC2626)),
                                    label: const Text(
                                      'Reset Budget',
                                      style: TextStyle(color: Color(0xFFDC2626)),
                                    ),
                                    style: OutlinedButton.styleFrom(
                                      minimumSize: const Size.fromHeight(48),
                                      side: BorderSide(
                                        color: const Color(0xFFDC2626)
                                            .withValues(alpha: 0.5),
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ] else if (hasBudget) ...<Widget>[
                            // Unlocked Editing State: Show Update (with 5s timer confirmation) and Cancel
                            Row(
                              children: <Widget>[
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: () =>
                                        _cancelEditing(currentBudget),
                                    icon: const Icon(Icons.close_rounded,
                                        size: 18),
                                    label: const Text('Cancel'),
                                    style: OutlinedButton.styleFrom(
                                      minimumSize: const Size.fromHeight(48),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: FilledButton.icon(
                                    onPressed: _dailyController.text
                                            .trim()
                                            .isNotEmpty
                                        ? () => _confirmAndUpdateBudget(
                                            currentBudget)
                                        : null,
                                    icon: const Icon(Icons.sync_rounded,
                                        size: 18),
                                    label: const Text('Update Budget'),
                                    style: FilledButton.styleFrom(
                                      minimumSize: const Size.fromHeight(48),
                                      backgroundColor: const Color(0xFF0F766E),
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ] else ...<Widget>[
                            // First-time set state: Save button (locks immediately upon save)
                            SizedBox(
                              width: double.infinity,
                              child: FilledButton.icon(
                                onPressed:
                                    _dailyController.text.trim().isNotEmpty
                                        ? _saveBudget
                                        : null,
                                icon: const Icon(Icons.check_circle_rounded,
                                    size: 18),
                                label: const Text('Save & Lock Today\'s Budget'),
                                style: FilledButton.styleFrom(
                                  minimumSize: const Size.fromHeight(48),
                                  backgroundColor: const Color(0xFF0F766E),
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // 2. Today's Live Status & Spending Tracker Card
                    if (hasBudget || currentSpent > 0) ...<Widget>[
                      SectionCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: <Widget>[
                                Text(
                                  'Today\'s Progress',
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium
                                      ?.copyWith(fontWeight: FontWeight.w800),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: statusColor.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    hasBudget
                                        ? '${(progressValue * 100).toStringAsFixed(0)}% Used'
                                        : 'Budget Unset',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: statusColor,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            // Progress bar
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: LinearProgressIndicator(
                                value: progressValue,
                                minHeight: 10,
                                backgroundColor:
                                    statusColor.withValues(alpha: 0.14),
                                valueColor: AlwaysStoppedAnimation<Color>(
                                    statusColor),
                              ),
                            ),
                            const SizedBox(height: 14),
                            // 3 Clean Metric Columns
                            Row(
                              children: <Widget>[
                                Expanded(
                                  child: _StatMetricBox(
                                    label: 'Budget',
                                    value: formatPeso(currentBudget),
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurface,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: _StatMetricBox(
                                    label: 'Spent',
                                    value: formatPeso(currentSpent),
                                    color: currentSpent > 0
                                        ? const Color(0xFFDC2626)
                                        : Theme.of(context)
                                            .colorScheme
                                            .onSurface,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: _StatMetricBox(
                                    label: remaining < 0 ? 'Over' : 'Remaining',
                                    value: formatPeso(remaining.abs()),
                                    color: remaining < 0
                                        ? const Color(0xFFDC2626)
                                        : const Color(0xFF16A34A),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Text(
                              hasBudget
                                  ? dailySummary.warningMessage
                                  : 'Budget is not set. Expenses will count as untracked.',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                    ],

                    // 3. Month Summary Card
                    BudgetMetricCard(
                      label: 'This Month\'s Total Budget',
                      value: formatPeso(monthlySummary.limit),
                      subtitle:
                          'Sum of daily budgets recorded in ${DateFormat('MMMM yyyy').format(currentClock)}',
                      icon: Icons.calendar_month_rounded,
                      color: const Color(0xFF0F766E),
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
}

class _StatMetricBox extends StatelessWidget {
  const _StatMetricBox({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: Theme.of(context)
            .colorScheme
            .surfaceContainerHighest
            .withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 14,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

/// A modal confirmation dialog featuring a 5-second countdown timer.
/// The user can confirm immediately, cancel immediately, or wait 5s for auto-confirmation.
class _CountdownConfirmationDialog extends StatefulWidget {
  const _CountdownConfirmationDialog({
    required this.title,
    required this.message,
    required this.confirmLabel,
    required this.confirmColor,
    required this.icon,
  });

  final String title;
  final String message;
  final String confirmLabel;
  final Color confirmColor;
  final IconData icon;

  @override
  State<_CountdownConfirmationDialog> createState() =>
      _CountdownConfirmationDialogState();
}

class _CountdownConfirmationDialogState
    extends State<_CountdownConfirmationDialog> {
  static const int _totalSeconds = 5;
  int _secondsRemaining = _totalSeconds;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startCountdown();
  }

  void _startCountdown() {
    _timer = Timer.periodic(const Duration(seconds: 1), (Timer timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_secondsRemaining <= 1) {
        timer.cancel();
        Navigator.of(context).pop(true);
      } else {
        setState(() {
          _secondsRemaining--;
        });
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final double progress = _secondsRemaining / _totalSeconds;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      actionsPadding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      title: Row(
        children: <Widget>[
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: widget.confirmColor.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(widget.icon, color: widget.confirmColor, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              widget.title,
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            widget.message,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          // 5-second countdown progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              backgroundColor:
                  Theme.of(context).colorScheme.surfaceContainerHighest,
              valueColor: AlwaysStoppedAnimation<Color>(widget.confirmColor),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Text(
                'Auto-confirming in $_secondsRemaining s...',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: widget.confirmColor,
                ),
              ),
              Icon(Icons.timer_outlined, size: 14, color: widget.confirmColor),
            ],
          ),
        ],
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () {
            _timer?.cancel();
            Navigator.of(context).pop(false);
          },
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          onPressed: () {
            _timer?.cancel();
            Navigator.of(context).pop(true);
          },
          icon: Icon(widget.icon, size: 16),
          label: Text(widget.confirmLabel),
          style: FilledButton.styleFrom(
            backgroundColor: widget.confirmColor,
            foregroundColor: Colors.white,
          ),
        ),
      ],
    );
  }
}
