import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/models/budget_models.dart';
import '../../core/state/app_controller.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/budget_cards.dart';
import '../../core/widgets/section_title.dart';
import '../budget/budget_planner_screen.dart';
import '../together/budget_together_screen.dart';

class ExpenseTrackerScreen extends ConsumerStatefulWidget {
  const ExpenseTrackerScreen({super.key, this.isTogetherOnly = false});

  final bool isTogetherOnly;

  @override
  ConsumerState<ExpenseTrackerScreen> createState() =>
      _ExpenseTrackerScreenState();
}

class _ExpenseTrackerScreenState extends ConsumerState<ExpenseTrackerScreen> {
  ExpenseSection _activeSection = ExpenseSection.daily;

  bool _ensureBudgetSet(BuildContext context) {
    final BudgetBuddyState state = ref.read(budgetBuddyControllerProvider);
    final bool hasBudget = widget.isTogetherOnly
        ? state.togetherBudget > 0
        : state.settings.totalDailyBudget > 0;

    if (!hasBudget) {
      showDialog<void>(
        context: context,
        builder: (BuildContext dialogContext) {
          return AlertDialog(
            icon: const Icon(
              Icons.warning_amber_rounded,
              color: Color(0xFFDC2626),
              size: 44,
            ),
            title: Text(widget.isTogetherOnly
                ? 'Budget Together Required'
                : 'Daily Budget Required'),
            content: Text(
              widget.isTogetherOnly
                  ? 'You cannot log expenses until you set a Budget Together amount. Please set a budget first.'
                  : 'You cannot log expenses until you set a daily budget. Please set a budget first.',
              textAlign: TextAlign.center,
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF991B1B),
                ),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () {
                  Navigator.of(dialogContext).pop();
                  if (widget.isTogetherOnly) {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const BudgetTogetherScreen(),
                      ),
                    );
                  } else {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const BudgetPlannerScreen(),
                      ),
                    );
                  }
                },
                child: const Text('Set Budget'),
              ),
            ],
          );
        },
      );
      return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final BudgetBuddyState state = ref.watch(budgetBuddyControllerProvider);
    final List<ExpenseEntry> expenses = _filteredExpenses(state);
    final DateTime today =
        ref.watch(budgetBuddyControllerProvider.notifier).now;
    final List<DateTime> availableMonths =
        _availableMonths(state, expenses, today);
    final List<ExpenseEntry> todayExpenses =
        _sortExpenses(_expensesForDay(expenses, today));

    final DateTime todayDay = DateTime(today.year, today.month, today.day);
    final Set<DateTime> pastDaysSet = <DateTime>{};
    for (final DailyRecord record in state.dailyRecords) {
      final DateTime rDate =
          DateTime(record.date.year, record.date.month, record.date.day);
      if (rDate.isBefore(todayDay)) {
        pastDaysSet.add(rDate);
      }
    }
    for (final ExpenseEntry expense in expenses) {
      final DateTime eDate = DateTime(expense.dateTime.year,
          expense.dateTime.month, expense.dateTime.day);
      if (eDate.isBefore(todayDay)) {
        pastDaysSet.add(eDate);
      }
    }
    final List<DateTime> pastDays = pastDaysSet.toList()
      ..sort((DateTime left, DateTime right) => right.compareTo(left));

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              if (Navigator.of(context).canPop()) ...<Widget>[
                FilledButton.tonalIcon(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.arrow_back_rounded, size: 18),
                  label: Text(
                    widget.isTogetherOnly
                        ? 'Back to Budget Together Menu'
                        : 'Back to Menu',
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 13),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: widget.isTogetherOnly
                        ? const Color(0xFF0F766E).withValues(alpha: 0.12)
                        : Theme.of(context)
                            .colorScheme
                            .primary
                            .withValues(alpha: 0.12),
                    foregroundColor: widget.isTogetherOnly
                        ? const Color(0xFF0F766E)
                        : Theme.of(context).colorScheme.primary,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    visualDensity: VisualDensity.compact,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              SectionTitle(
                title: widget.isTogetherOnly
                    ? 'Budget Together Expenses'
                    : 'Expenses',
                subtitle: widget.isTogetherOnly
                    ? 'View and manage expenses logged for Budget Together.'
                    : 'View and manage your logged expenses.',
              ),
              const SizedBox(height: 12),
              Expanded(
                child: ListView(
                  padding: EdgeInsets.zero,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: FilledButton(
                            onPressed: () => setState(
                                () => _activeSection = ExpenseSection.daily),
                            style: FilledButton.styleFrom(
                              backgroundColor:
                                  _activeSection == ExpenseSection.daily
                                      ? Theme.of(context).colorScheme.primary
                                      : Theme.of(context)
                                          .colorScheme
                                          .surfaceContainerHighest,
                              foregroundColor:
                                  _activeSection == ExpenseSection.daily
                                      ? Theme.of(context).colorScheme.onPrimary
                                      : Theme.of(context).colorScheme.onSurface,
                            ),
                            child: const Text('Daily'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton(
                            onPressed: () => setState(
                                () => _activeSection = ExpenseSection.monthly),
                            style: FilledButton.styleFrom(
                              backgroundColor:
                                  _activeSection == ExpenseSection.monthly
                                      ? Theme.of(context).colorScheme.primary
                                      : Theme.of(context)
                                          .colorScheme
                                          .surfaceContainerHighest,
                              foregroundColor:
                                  _activeSection == ExpenseSection.monthly
                                      ? Theme.of(context).colorScheme.onPrimary
                                      : Theme.of(context).colorScheme.onSurface,
                            ),
                            child: const Text('Monthly'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (_activeSection == ExpenseSection.daily) ...<Widget>[
                      _DailySection(
                        dayLabel: _formatDayLabel(today),
                        expenses: todayExpenses,
                        isTogetherOnly: widget.isTogetherOnly,
                        onTapDay: (DateTime day) => _showDayExpensesSheet(
                            ref, day, expenses,
                            showBackButton: true),
                        onTapExpense: (ExpenseEntry e) async =>
                            await _showExpenseActions(ref, e),
                        onEditExpense: (ExpenseEntry e) async {
                          if (!mounted) return;
                          await _showExpenseDialog(ref, existing: e);
                        },
                        onDeleteExpense: (ExpenseEntry e) async {
                          if (!mounted) return;
                          final BuildContext localContext = context;
                          final bool shouldDelete =
                              await _confirmDeleteExpense(localContext);
                          if (!mounted || !shouldDelete) {
                            return;
                          }
                          ref
                              .read(budgetBuddyControllerProvider.notifier)
                              .deleteExpense(e.id);
                        },
                        onViewExpense: (ExpenseEntry e) async {
                          if (!mounted) return;
                          await _showExpenseDetails(ref, e);
                        },
                      ),
                      if (pastDays.isNotEmpty) ...<Widget>[
                        const SizedBox(height: 14),
                        SectionCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                'DAILY HISTORY',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(fontWeight: FontWeight.w800),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Tap a date to view its expense breakdown',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurfaceVariant,
                                    ),
                              ),
                              const SizedBox(height: 12),
                              ...pastDays.map((DateTime day) {
                                final List<ExpenseEntry> dayExpenses =
                                    _expensesForDay(expenses, day);
                                final double dayTotal = dayExpenses.fold<double>(
                                    0,
                                    (double sum, ExpenseEntry e) =>
                                        sum + e.amount);
                                final bool isZero = dayExpenses.isEmpty;
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: ListTile(
                                    contentPadding:
                                        const EdgeInsets.symmetric(
                                            horizontal: 12, vertical: 4),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                      side: BorderSide(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .outlineVariant,
                                      ),
                                    ),
                                    leading: Icon(
                                      isZero
                                          ? Icons.calendar_today_rounded
                                          : Icons.receipt_long_outlined,
                                      color: isZero
                                          ? const Color(0xFFD97706)
                                          : Theme.of(context)
                                              .colorScheme
                                              .primary,
                                    ),
                                    title: Text(
                                      _formatDayLabel(day),
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w700),
                                    ),
                                    subtitle: Text(
                                      isZero
                                          ? 'No budget and expenses today'
                                          : '${dayExpenses.length} expense${dayExpenses.length == 1 ? '' : 's'}',
                                    ),
                                    trailing: Text(
                                      isZero ? '₱0' : formatPeso(dayTotal),
                                      style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                        color: isZero
                                            ? const Color(0xFFD97706)
                                            : null,
                                      ),
                                    ),
                                    onTap: () => _showDayExpensesSheet(
                                      ref,
                                      day,
                                      expenses,
                                      showBackButton: true,
                                    ),
                                  ),
                                );
                              }),
                            ],
                          ),
                        ),
                      ],
                    ] else
                      _MonthlySection(
                        availableMonths: availableMonths,
                        expenses: expenses,
                        isTogetherOnly: widget.isTogetherOnly,
                        onTapMonth: (DateTime month) =>
                            _showMonthDatesSheet(ref, month, expenses),
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

  List<ExpenseEntry> _filteredExpenses(BudgetBuddyState state) {
    final List<ExpenseEntry> filtered =
        state.expenses.where((ExpenseEntry expense) {
      if (widget.isTogetherOnly) {
        if (expense.source != 'togetherSpend') {
          return false;
        }
      } else {
        if (expense.source == 'togetherSpend') {
          return false;
        }
      }
      if (state.currentExpenseFilter != null &&
          expense.category != state.currentExpenseFilter) {
        return false;
      }
      return true;
    }).toList();
    return _sortExpenses(filtered);
  }

  List<DateTime> _availableDays(List<ExpenseEntry> expenses) {
    final Set<DateTime> days = <DateTime>{};
    for (final ExpenseEntry expense in expenses) {
      days.add(DateTime(
          expense.dateTime.year, expense.dateTime.month, expense.dateTime.day));
    }
    final List<DateTime> sortedDays = days.toList()
      ..sort((DateTime left, DateTime right) => right.compareTo(left));
    return sortedDays;
  }

  List<DateTime> _availableMonths(
      BudgetBuddyState state, List<ExpenseEntry> expenses, DateTime today) {
    final Set<DateTime> months = <DateTime>{};
    months.add(DateTime(today.year, today.month));
    for (final ExpenseEntry expense in expenses) {
      months.add(DateTime(expense.dateTime.year, expense.dateTime.month));
    }
    for (final DailyRecord record in state.dailyRecords) {
      months.add(DateTime(record.date.year, record.date.month));
    }
    final List<DateTime> sortedMonths = months.toList()
      ..sort((DateTime left, DateTime right) => right.compareTo(left));
    return sortedMonths;
  }

  List<ExpenseEntry> _expensesForDay(
      List<ExpenseEntry> expenses, DateTime day) {
    return expenses
        .where((ExpenseEntry expense) =>
            DateUtils.isSameDay(expense.dateTime, day))
        .toList();
  }

  List<ExpenseEntry> _expensesForMonth(
      List<ExpenseEntry> expenses, DateTime month) {
    return expenses
        .where((ExpenseEntry expense) =>
            expense.dateTime.year == month.year &&
            expense.dateTime.month == month.month)
        .toList();
  }

  List<ExpenseEntry> _sortExpenses(List<ExpenseEntry> expenses) {
    final List<ExpenseEntry> sorted = List<ExpenseEntry>.from(expenses);
    sorted.sort((ExpenseEntry left, ExpenseEntry right) =>
        right.dateTime.compareTo(left.dateTime));
    return sorted;
  }

  Future<void> _showMonthDatesSheet(
      WidgetRef ref, DateTime month, List<ExpenseEntry> expenses) async {
    final BuildContext localContext = context;
    final BudgetBuddyState state = ref.read(budgetBuddyControllerProvider);
    final DateTime currentNow =
        ref.read(budgetBuddyControllerProvider.notifier).now;
    final List<ExpenseEntry> monthExpenses = _expensesForMonth(expenses, month);

    final Set<DateTime> daysSet = <DateTime>{};
    for (final ExpenseEntry expense in monthExpenses) {
      daysSet.add(DateTime(expense.dateTime.year, expense.dateTime.month, expense.dateTime.day));
    }
    for (final DailyRecord record in state.dailyRecords) {
      if (record.date.year == month.year && record.date.month == month.month) {
        daysSet.add(DateTime(record.date.year, record.date.month, record.date.day));
      }
    }
    if (currentNow.year == month.year && currentNow.month == month.month) {
      daysSet.add(DateTime(currentNow.year, currentNow.month, currentNow.day));
    }
    final List<DateTime> monthDays = daysSet.toList()..sort((a, b) => b.compareTo(a));

    await showModalBottomSheet<void>(
      context: localContext,
      isScrollControlled: true,
      showDragHandle: false,
      enableDrag: false,
      isDismissible: false,
      builder: (BuildContext sheetContext) {
        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(
                maxHeight: MediaQuery.of(sheetContext).size.height * 0.78),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      TextButton.icon(
                        onPressed: () => Navigator.of(sheetContext).pop(),
                        icon: const Icon(Icons.arrow_back_rounded),
                        label: const Text('Back'),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          DateFormat('MMMM yyyy').format(month),
                          style: Theme.of(sheetContext)
                              .textTheme
                              .titleLarge
                              ?.copyWith(fontWeight: FontWeight.w700),
                          textAlign: TextAlign.right,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                      '${monthExpenses.length} expense${monthExpenses.length == 1 ? '' : 's'} in this month',
                      style: Theme.of(sheetContext)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(
                              color: Theme.of(sheetContext)
                                  .colorScheme
                                  .onSurfaceVariant)),
                  const SizedBox(height: 12),
                  if (monthDays.isEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Theme.of(sheetContext)
                            .colorScheme
                            .surfaceContainerLow,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: const Color(0xFFD97706).withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        children: <Widget>[
                          const Icon(
                            Icons.calendar_today_rounded,
                            color: Color(0xFFD97706),
                            size: 20,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'No budget and expenses this month',
                              style: Theme.of(sheetContext)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(
                                    color: const Color(0xFFD97706),
                                    fontWeight: FontWeight.w600,
                                  ),
                            ),
                          ),
                          const Text(
                            '₱0',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: Color(0xFFD97706),
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    Expanded(
                      child: ListView.separated(
                        itemCount: monthDays.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (BuildContext context, int index) {
                          final DateTime day = monthDays[index];
                          final List<ExpenseEntry> dayExpenses = monthExpenses
                              .where((ExpenseEntry expense) =>
                                  DateUtils.isSameDay(expense.dateTime, day))
                              .toList();
                          final double dayTotal = dayExpenses.fold<double>(
                              0,
                              (double total, ExpenseEntry expense) =>
                                  total + expense.amount);
                          final bool isZero = dayExpenses.isEmpty;

                          return ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                                side: BorderSide(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .outlineVariant)),
                            leading: Icon(
                              isZero
                                  ? Icons.calendar_today_rounded
                                  : Icons.calendar_today_outlined,
                              color: isZero ? const Color(0xFFD97706) : null,
                            ),
                            title: Text(_formatDayLabel(day),
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700)),
                            subtitle: Text(
                              isZero
                                  ? 'No budget and expenses today'
                                  : '${dayExpenses.length} expense${dayExpenses.length == 1 ? '' : 's'}',
                            ),
                            trailing: Text(
                              isZero ? '₱0' : formatPeso(dayTotal),
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: isZero ? const Color(0xFFD97706) : null,
                              ),
                            ),
                            onTap: () async => await _showDayExpensesSheet(
                                ref, day, expenses,
                                showBackButton: true),
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _showDayExpensesSheet(
      WidgetRef ref, DateTime day, List<ExpenseEntry> expenses,
      {bool showBackButton = false}) async {
    final BuildContext localContext = context;
    final List<ExpenseEntry> dayExpenses = _expensesForDay(expenses, day);
    final ExpenseEntry? editExpense = await showModalBottomSheet<ExpenseEntry>(
      context: localContext,
      isScrollControlled: true,
      showDragHandle: !showBackButton,
      enableDrag: !showBackButton,
      isDismissible: !showBackButton,
      builder: (BuildContext sheetContext) {
        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(
                maxHeight: MediaQuery.of(sheetContext).size.height * 0.78),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      if (showBackButton)
                        TextButton.icon(
                            onPressed: () => Navigator.of(sheetContext).pop(),
                            icon: const Icon(Icons.arrow_back_rounded),
                            style: TextButton.styleFrom(
                              foregroundColor: const Color(0xFF991B1B),
                            ),
                            label: const Text('Back')),
                      Expanded(
                        child: Text(DateFormat('EEEE, MMM d, yyyy').format(day),
                            style: Theme.of(sheetContext)
                                .textTheme
                                .titleLarge
                                ?.copyWith(fontWeight: FontWeight.w700),
                            textAlign: showBackButton
                                ? TextAlign.right
                                : TextAlign.left),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                      '${dayExpenses.length} expense${dayExpenses.length == 1 ? '' : 's'}',
                      style: Theme.of(sheetContext)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(
                              color: Theme.of(sheetContext)
                                  .colorScheme
                                  .onSurfaceVariant)),
                  const SizedBox(height: 12),
                  if (dayExpenses.isEmpty)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 32),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            const Icon(
                              Icons.calendar_today_rounded,
                              size: 44,
                              color: Color(0xFFD97706),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'No budget and expenses today',
                              style: Theme.of(sheetContext)
                                  .textTheme
                                  .titleSmall
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '₱0 spent • ₱0 balance',
                              style: Theme.of(sheetContext)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                    color: Theme.of(sheetContext)
                                        .colorScheme
                                        .onSurfaceVariant,
                                  ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    Expanded(
                      child: ListView.separated(
                        itemCount: dayExpenses.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (BuildContext context, int index) {
                          final ExpenseEntry expense = dayExpenses[index];
                          return Container(
                            decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .outlineVariant)),
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  Row(
                                    children: <Widget>[
                                      CircleAvatar(
                                          backgroundColor: Theme.of(context)
                                              .colorScheme
                                              .surfaceContainerLow,
                                          child: Icon(
                                            _expenseIconForExpense(expense),
                                            color: expense.category.color,
                                            size: 18,
                                          )),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: <Widget>[
                                            Text(expense.title,
                                                style: const TextStyle(
                                                    fontWeight:
                                                        FontWeight.w700)),
                                            const SizedBox(height: 2),
                                            Text(
                                                expense.note.isNotEmpty
                                                    ? '${expense.category.label} • ${expense.note}'
                                                    : expense.category.label,
                                                maxLines: 2,
                                                overflow:
                                                    TextOverflow.ellipsis),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(formatPeso(expense.amount),
                                          style: const TextStyle(
                                              fontWeight: FontWeight.w700)),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Row(
                                    children: <Widget>[
                                      Expanded(
                                        child: OutlinedButton(
                                          style: OutlinedButton.styleFrom(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 8, vertical: 12),
                                          ),
                                          onPressed: () =>
                                              Navigator.of(sheetContext)
                                                  .pop(expense),
                                          child:
                                              const Text('Edit', maxLines: 1),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: OutlinedButton(
                                          style: OutlinedButton.styleFrom(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 8, vertical: 12),
                                          ),
                                          onPressed: () async {
                                            final BuildContext localContext =
                                                context;
                                            final bool shouldDelete =
                                                await _confirmDeleteExpense(
                                                    localContext);
                                            if (!mounted ||
                                                !sheetContext.mounted ||
                                                !shouldDelete) {
                                              return;
                                            }
                                            ref
                                                .read(
                                                    budgetBuddyControllerProvider
                                                        .notifier)
                                                .deleteExpense(expense.id);
                                            Navigator.of(sheetContext).pop();
                                          },
                                          child:
                                              const Text('Delete', maxLines: 1),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: OutlinedButton(
                                          style: OutlinedButton.styleFrom(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 8, vertical: 12),
                                          ),
                                          onPressed: () async {
                                            if (!mounted) return;
                                            await _showExpenseDetails(
                                                ref, expense);
                                          },
                                          child: const Text('Details',
                                              maxLines: 1),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );

    if (editExpense != null) {
      if (!mounted) return;
      await _showExpenseDialog(ref, existing: editExpense);
    }
  }

  Future<void> _showExpenseActions(WidgetRef ref, ExpenseEntry expense) async {
    final BuildContext localContext = context;
    final String? action = await showModalBottomSheet<String>(
      context: localContext,
      isScrollControlled: true,
      builder: (BuildContext sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                ListTile(
                    leading: const Icon(Icons.edit_outlined),
                    title: const Text('Edit'),
                    onTap: () => Navigator.of(sheetContext).pop('edit')),
                ListTile(
                    leading: const Icon(Icons.delete_outline_rounded),
                    title: const Text('Delete'),
                    onTap: () => Navigator.of(sheetContext).pop('delete')),
                ListTile(
                    leading: const Icon(Icons.info_outline),
                    title: const Text('View Details'),
                    onTap: () => Navigator.of(sheetContext).pop('view')),
                const SizedBox(height: 8),
                TextButton(
                    onPressed: () => Navigator.of(sheetContext).pop(),
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFF991B1B),
                    ),
                    child: const Text('Cancel')),
              ],
            ),
          ),
        );
      },
    );

    if (action == 'edit') {
      if (!mounted) return;
      await _showExpenseDialog(ref, existing: expense);
    } else if (action == 'delete') {
      final BuildContext dialogContext = context;
      if (!dialogContext.mounted) return;
      final bool shouldDelete = await _confirmDeleteExpense(dialogContext);
      if (!dialogContext.mounted || !shouldDelete) return;
      ref
          .read(budgetBuddyControllerProvider.notifier)
          .deleteExpense(expense.id);
    } else if (action == 'view') {
      if (!mounted) return;
      await _showExpenseDetails(ref, expense);
    }
  }

  Future<void> _showExpenseDialog(WidgetRef ref,
      {ExpenseEntry? existing}) async {
    if (existing == null && !_ensureBudgetSet(context)) return;

    final TextEditingController titleController =
        TextEditingController(text: existing?.title ?? '');
    final TextEditingController amountController =
        TextEditingController(text: existing?.amount.toStringAsFixed(0) ?? '');
    final TextEditingController noteController =
        TextEditingController(text: existing?.note ?? '');
    BudgetCategory category = existing?.category ?? BudgetCategory.food;

    final BuildContext localContext = context;
    await showModalBottomSheet<void>(
      context: localContext,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: false,
      enableDrag: false,
      isDismissible: false,
      builder: (BuildContext sheetContext) {
        return Padding(
          padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 20,
              bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 20),
          child: StatefulBuilder(
            builder: (BuildContext context,
                void Function(void Function()) setModalState) {
              final BudgetBuddyState state =
                  ref.read(budgetBuddyControllerProvider);
              final BudgetSummary summary = widget.isTogetherOnly
                  ? ref.read(budgetTogetherSummaryProvider)
                  : ref.read(budgetSummaryProvider);
              final double enteredAmount =
                  double.tryParse(amountController.text) ?? 0;
              final double limit = _categoryLimit(category, state.settings);
              final double projectedTotal =
                  _categorySpent(summary, category) + enteredAmount;
              final bool showWarning = limit > 0 && projectedTotal > limit;

              return ListView(
                shrinkWrap: true,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      TextButton.icon(
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(Icons.arrow_back_rounded),
                          label: const Text('Back')),
                      const SizedBox(width: 8),
                      Expanded(
                          child: Text(
                              existing == null
                                  ? (widget.isTogetherOnly
                                      ? 'Add Together Expense'
                                      : 'Add Expense')
                                  : 'Edit Expense',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleLarge
                                  ?.copyWith(fontWeight: FontWeight.w700),
                              textAlign: TextAlign.right)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                      controller: titleController,
                      decoration: const InputDecoration(labelText: 'Title')),
                  const SizedBox(height: 12),
                  TextField(
                      controller: amountController,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      onChanged: (_) => setModalState(() {}),
                      decoration: const InputDecoration(labelText: 'Amount')),
                  const SizedBox(height: 12),
                  TextField(
                      controller: noteController,
                      maxLines: 2,
                      decoration: const InputDecoration(labelText: 'Note')),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<BudgetCategory>(
                    initialValue: category,
                    items: BudgetCategory.values
                        .map((BudgetCategory item) =>
                            DropdownMenuItem<BudgetCategory>(
                                value: item, child: Text(item.label)))
                        .toList(),
                    onChanged: (BudgetCategory? value) {
                      if (value != null) {
                        setModalState(() => category = value);
                      }
                    },
                    decoration: const InputDecoration(labelText: 'Category'),
                  ),
                  if (showWarning) ...<Widget>[
                    const SizedBox(height: 10),
                    Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                            color: const Color(0xFFFEE2E2),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFFFCA5A5))),
                        child: Text(
                            '${category.label} is now ${formatPeso(projectedTotal - limit)} over its limit.',
                            style: const TextStyle(
                                color: Color(0xFF991B1B),
                                fontWeight: FontWeight.w600))),
                  ],
                  const SizedBox(height: 20),
                  SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                          onPressed: () {
                            final BudgetBuddyController controller = ref
                                .read(budgetBuddyControllerProvider.notifier);
                            final String source = existing != null &&
                                    existing.source.isNotEmpty
                                ? existing.source
                                : (widget.isTogetherOnly
                                    ? 'togetherSpend'
                                    : 'manual');
                            final ExpenseEntry entry = ExpenseEntry(
                              id: existing?.id ??
                                  DateTime.now()
                                      .microsecondsSinceEpoch
                                      .toString(),
                              title: titleController.text.trim().isEmpty
                                  ? 'Expense'
                                  : titleController.text.trim(),
                              amount:
                                  double.tryParse(amountController.text) ?? 0,
                              category: category,
                              dateTime: existing?.dateTime ?? controller.now,
                              note: noteController.text.trim(),
                              source: source,
                            );
                            if (existing == null) {
                              controller.addExpense(
                                title: entry.title,
                                amount: entry.amount,
                                category: entry.category,
                                note: entry.note,
                                dateTime: entry.dateTime,
                                source: entry.source,
                              );
                            } else {
                              controller.updateExpense(entry);
                            }
                            Navigator.of(context).pop();
                          },
                          child: Text(existing == null
                              ? 'Save Expense'
                              : 'Update Expense'))),
                ],
              );
            },
          ),
        );
      },
    );
  }

  Future<void> _showExpenseDetails(WidgetRef ref, ExpenseEntry expense) async {
    final BuildContext localContext = context;

    await showModalBottomSheet<void>(
      context: localContext,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: false,
      enableDrag: false,
      isDismissible: false,
      builder: (BuildContext sheetContext) {
        return SingleChildScrollView(
          padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 12,
              bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(expense.title,
                  softWrap: true,
                  style: Theme.of(sheetContext)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              Text(formatPeso(expense.amount),
                  softWrap: true,
                  style: Theme.of(sheetContext)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Text('Category: ${expense.category.label}', softWrap: true),
              const SizedBox(height: 6),
              Text(
                  'Date: ${DateFormat('MMMM d, yyyy h:mm a').format(expense.dateTime)}',
                  softWrap: true),
              const SizedBox(height: 8),
              if (expense.note.isNotEmpty)
                Text('Note: ${expense.note}', softWrap: true),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.of(sheetContext).pop(),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF991B1B),
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Close'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<bool> _confirmDeleteExpense(BuildContext context) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Delete expense?'),
          content: const Text('This expense will be removed permanently.'),
          actions: <Widget>[
            TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF991B1B),
                ),
                child: const Text('Cancel')),
            FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: const Text('Delete')),
          ],
        );
      },
    );
    return confirmed ?? false;
  }

  double _categoryLimit(BudgetCategory category, BudgetSettings settings) {
    return switch (category) {
      BudgetCategory.food => settings.foodBudget,
      BudgetCategory.transportation => settings.transportationBudget,
      BudgetCategory.entertainment => settings.leisureBudget,
      BudgetCategory.shopping => 0,
      BudgetCategory.miscellaneous => 0,
    };
  }

  double _categorySpent(BudgetSummary summary, BudgetCategory category) {
    return summary.categoryTotals[category.label] ?? 0;
  }
}

enum ExpenseSection { daily, monthly }

String _formatDayLabel(DateTime dateTime) {
  final DateTime now = DateTime.now();
  if (DateUtils.isSameDay(dateTime, now)) {
    return 'Today, ${DateFormat('MMMM d, yyyy').format(dateTime)}';
  }
  return DateFormat('EEEE, MMM d, yyyy').format(dateTime);
}

IconData _expenseIconForExpense(ExpenseEntry expense) {
  final String selectedCategory = expense.spendCategory.trim().toLowerCase();
  if (selectedCategory.isNotEmpty) {
    return switch (selectedCategory) {
      'food & drinks' => Icons.restaurant_rounded,
      'transport' => Icons.directions_bus_rounded,
      'shopping' => Icons.shopping_bag_rounded,
      'leisure & gala' => Icons.celebration_rounded,
      'health' => Icons.health_and_safety_rounded,
      'bills & utilities' => Icons.receipt_long_rounded,
      'custom' => Icons.edit_rounded,
      _ => _expenseCategoryIcon(expense.category),
    };
  }

  final String normalizedTitle = expense.title.trim().toLowerCase();
  return switch (normalizedTitle) {
    'food & drinks' => Icons.restaurant_rounded,
    'transport' => Icons.directions_bus_rounded,
    'shopping' => Icons.shopping_bag_rounded,
    'leisure & gala' => Icons.celebration_rounded,
    'health' => Icons.health_and_safety_rounded,
    'bills & utilities' => Icons.receipt_long_rounded,
    'custom' => Icons.edit_rounded,
    _ => _expenseCategoryIcon(expense.category),
  };
}

IconData _expenseCategoryIcon(BudgetCategory category) {
  return switch (category) {
    BudgetCategory.food => Icons.restaurant_rounded,
    BudgetCategory.transportation => Icons.directions_bus_rounded,
    BudgetCategory.entertainment => Icons.celebration_rounded,
    BudgetCategory.shopping => Icons.shopping_bag_rounded,
    BudgetCategory.miscellaneous => Icons.edit_rounded,
  };
}

class _DailySection extends StatelessWidget {
  const _DailySection({
    required this.dayLabel,
    required this.expenses,
    required this.onTapDay,
    this.isTogetherOnly = false,
    this.onTapExpense,
    this.onEditExpense,
    this.onDeleteExpense,
    this.onViewExpense,
  });

  final String dayLabel;
  final List<ExpenseEntry> expenses;
  final bool isTogetherOnly;
  final ValueChanged<DateTime> onTapDay;
  final ValueChanged<ExpenseEntry>? onTapExpense;
  final Future<void> Function(ExpenseEntry)? onEditExpense;
  final Future<void> Function(ExpenseEntry)? onDeleteExpense;
  final Future<void> Function(ExpenseEntry)? onViewExpense;

  @override
  Widget build(BuildContext context) {
    final double total = expenses.fold<double>(
        0, (double value, ExpenseEntry expense) => value + expense.amount);
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('DAILY',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Text(dayLabel,
              style: Theme.of(context)
                  .textTheme
                  .bodyLarge
                  ?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Text(
              '${expenses.length} expense${expenses.length == 1 ? '' : 's'} • ${formatPeso(total)} today',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant)),
          const SizedBox(height: 12),
          if (expenses.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isTogetherOnly
                      ? Theme.of(context).colorScheme.outlineVariant
                      : const Color(0xFFD97706).withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: <Widget>[
                  Icon(
                    isTogetherOnly
                        ? Icons.group_outlined
                        : Icons.calendar_today_rounded,
                    color: isTogetherOnly
                        ? Theme.of(context).colorScheme.onSurfaceVariant
                        : const Color(0xFFD97706),
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      isTogetherOnly
                          ? 'No Budget Together expenses yet for today.'
                          : 'No budget and expenses today',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: isTogetherOnly
                                ? Theme.of(context).colorScheme.onSurfaceVariant
                                : const Color(0xFFD97706),
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ),
                  if (!isTogetherOnly)
                    const Text(
                      '₱0',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: Color(0xFFD97706),
                      ),
                    ),
                ],
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: expenses.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (BuildContext context, int index) {
                final ExpenseEntry expense = expenses[index];
                return InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => onTapExpense != null
                      ? onTapExpense!(expense)
                      : onTapDay(DateTime.now()),
                  child: Container(
                    decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                            color: Theme.of(context)
                                .colorScheme
                                .outlineVariant)),
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Row(
                          children: <Widget>[
                            CircleAvatar(
                                backgroundColor: Theme.of(context)
                                    .colorScheme
                                    .surfaceContainerLow,
                                child: Icon(
                                  _expenseIconForExpense(expense),
                                  color: expense.category.color,
                                  size: 18,
                                )),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  Text(expense.title,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w700)),
                                  const SizedBox(height: 2),
                                  Text(
                                      expense.note.isNotEmpty
                                          ? '${expense.category.label} • ${expense.note}'
                                          : expense.category.label,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(formatPeso(expense.amount),
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700)),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: <Widget>[
                            Expanded(
                              child: OutlinedButton(
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 12),
                                ),
                                onPressed: () {
                                  if (onEditExpense != null) {
                                    onEditExpense!(expense);
                                  }
                                },
                                child: const Text('Edit', maxLines: 1),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: OutlinedButton(
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 12),
                                ),
                                onPressed: () async {
                                  if (onDeleteExpense != null) {
                                    await onDeleteExpense!(expense);
                                  }
                                },
                                child: const Text('Delete', maxLines: 1),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: OutlinedButton(
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 12),
                                ),
                                onPressed: () async {
                                  if (onViewExpense != null) {
                                    await onViewExpense!(expense);
                                  }
                                },
                                child: const Text('Details', maxLines: 1),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}

class _MonthlySection extends StatelessWidget {
  const _MonthlySection(
      {required this.availableMonths,
      required this.expenses,
      required this.onTapMonth,
      this.isTogetherOnly = false});

  final List<DateTime> availableMonths;
  final List<ExpenseEntry> expenses;
  final ValueChanged<DateTime> onTapMonth;
  final bool isTogetherOnly;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('MONTHLY',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Text('Tap a month to open its daily dates',
              style: Theme.of(context)
                  .textTheme
                  .bodyLarge
                  ?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          if (availableMonths.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: const Color(0xFFD97706).withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: <Widget>[
                  const Icon(
                    Icons.calendar_today_rounded,
                    color: Color(0xFFD97706),
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      isTogetherOnly
                          ? 'No Budget Together expenses yet.'
                          : 'No budget and expenses this month',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: const Color(0xFFD97706),
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ),
                  const Text(
                    '₱0',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: Color(0xFFD97706),
                    ),
                  ),
                ],
              ),
            )
          else
            ...availableMonths.map((DateTime month) {
              final List<ExpenseEntry> monthExpenses = expenses
                  .where((ExpenseEntry expense) =>
                      expense.dateTime.year == month.year &&
                      expense.dateTime.month == month.month)
                  .toList();
              final double total = monthExpenses.fold<double>(
                  0,
                  (double value, ExpenseEntry expense) =>
                      value + expense.amount);
              final bool isZero = monthExpenses.isEmpty;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(
                          color: isZero
                              ? const Color(0xFFD97706).withValues(alpha: 0.3)
                              : Theme.of(context)
                                  .colorScheme
                                  .outlineVariant)),
                  leading: Icon(
                    isZero
                        ? Icons.calendar_today_rounded
                        : Icons.date_range_outlined,
                    color: isZero
                        ? const Color(0xFFD97706)
                        : Theme.of(context).colorScheme.primary,
                  ),
                  title: Text(DateFormat('MMMM yyyy').format(month),
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Text(
                      isZero
                          ? 'No budget and expenses this month • Tap for daily dates'
                          : '${monthExpenses.length} expense${monthExpenses.length == 1 ? '' : 's'} • Tap for daily dates'),
                  trailing: Text(
                    isZero ? '₱0' : formatPeso(total),
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: isZero ? const Color(0xFFD97706) : null,
                    ),
                  ),
                  onTap: () => onTapMonth(month),
                ),
              );
            }),
        ],
      ),
    );
  }
}
