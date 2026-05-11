import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
  _ReportsTab _reportsTab = _ReportsTab.daily;

  @override
  Widget build(BuildContext context) {
    final BudgetBuddyState state = ref.watch(budgetBuddyControllerProvider);
    final BudgetSummary summary = ref.watch(budgetSummaryProvider);

    final double savingsTarget = state.settings.savingsTargetAmount;
    final DateTime? savingsTargetDate = state.settings.savingsTargetDate;
    final double targetProgress = savingsTarget <= 0
        ? 0
        : (summary.savings / savingsTarget).clamp(0, 1.0).toDouble();
    final int daysRemaining = savingsTargetDate == null
        ? 0
        : savingsTargetDate.difference(DateTime.now()).inDays;
    final double dailySaveTarget =
        savingsTargetDate == null || daysRemaining <= 0
            ? 0
            : savingsTarget / daysRemaining;

    return Scaffold(
      appBar: AppBar(title: const Text('Analytics')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: <Widget>[
            const SectionTitle(
              title: 'Analytics',
              subtitle: 'Savings target and period reports.',
            ),
            const SizedBox(height: 12),
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
                    Text('Current progress: ${formatPeso(summary.savings)}'),
                    const SizedBox(height: 4),
                    Text('Daily save target: ${formatPeso(dailySaveTarget)}'),
                  ],
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => _editSavingsTarget(context, state),
                      icon: const Icon(Icons.edit_rounded),
                      label: const Text('Set target'),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _reportsSection(state),
          ],
        ),
      ),
    );
  }

  void _editSavingsTarget(BuildContext context, BudgetBuddyState state) {
    final TextEditingController amountController = TextEditingController(
      text: state.settings.savingsTargetAmount > 0
          ? state.settings.savingsTargetAmount.toStringAsFixed(0)
          : '',
    );
    DateTime selectedDate = state.settings.savingsTargetDate ??
        DateTime.now().add(const Duration(days: 30));

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
          0, (double sum, ExpenseEntry expense) => sum + expense.amount);

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
          0, (double sum, ExpenseEntry expense) => sum + expense.amount);

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
          0, (double sum, ExpenseEntry expense) => sum + expense.amount);
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
      final String biggestCategory = monthExpenses.isEmpty
          ? 'None'
          : categoryTotals.entries
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
      BudgetBuddyState state, DateTime monthStart, DateTime monthEnd) {
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

  DateTime _startOfDay(DateTime value) =>
      DateTime(value.year, value.month, value.day);

  bool _sameDay(DateTime left, DateTime right) {
    return left.year == right.year &&
        left.month == right.month &&
        left.day == right.day;
  }

  String _trendLabel(DateTime dateTime) {
    if (DateUtils.isSameDay(dateTime, DateTime.now())) {
      return 'Today';
    }
    if (DateUtils.isSameDay(
        dateTime, DateTime.now().subtract(const Duration(days: 1)))) {
      return 'Yesterday';
    }
    return formatDayLabel(dateTime);
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
