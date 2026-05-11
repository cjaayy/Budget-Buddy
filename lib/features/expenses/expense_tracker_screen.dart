import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/models/budget_models.dart';
import '../../core/state/app_controller.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/budget_cards.dart';
import '../../core/widgets/section_title.dart';

class ExpenseTrackerScreen extends ConsumerStatefulWidget {
  const ExpenseTrackerScreen({super.key});

  @override
  ConsumerState<ExpenseTrackerScreen> createState() =>
      _ExpenseTrackerScreenState();
}

class _ExpenseTrackerScreenState extends ConsumerState<ExpenseTrackerScreen> {
  ExpenseSection _activeSection = ExpenseSection.daily;
  DateTime _selectedDay = DateUtils.dateOnly(DateTime.now());
  DateTime _selectedMonth = DateTime(DateTime.now().year, DateTime.now().month);

  @override
  Widget build(BuildContext context) {
    final BudgetBuddyState state = ref.watch(budgetBuddyControllerProvider);
    final List<ExpenseEntry> expenses = _filteredExpenses(state);
    final List<ExpenseEntry> dailyExpenses =
        _expensesForDay(expenses, _selectedDay);
    final List<ExpenseEntry> monthlyExpenses =
        _expensesForMonth(expenses, _selectedMonth);
    final List<DateTime> monthDays = _availableDays(monthlyExpenses);
    final double dailyTotal = dailyExpenses.fold<double>(
      0,
      (double total, ExpenseEntry expense) => total + expense.amount,
    );
    final double monthlyTotal = monthlyExpenses.fold<double>(
      0,
      (double total, ExpenseEntry expense) => total + expense.amount,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Expenses'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: <Widget>[
            const SectionTitle(
              title: 'Expenses',
              subtitle: 'View and manage your logged expenses.',
            ),
            const SizedBox(height: 12),
            Row(
              children: <Widget>[
                Expanded(
                  child: FilledButton(
                    onPressed: () => setState(() {
                      _activeSection = ExpenseSection.daily;
                    }),
                    style: FilledButton.styleFrom(
                      backgroundColor: _activeSection == ExpenseSection.daily
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context)
                              .colorScheme
                              .surfaceContainerHighest,
                      foregroundColor: _activeSection == ExpenseSection.daily
                          ? Theme.of(context).colorScheme.onPrimary
                          : Theme.of(context).colorScheme.onSurface,
                    ),
                    child: const Text('Daily'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: () => setState(() {
                      _activeSection = ExpenseSection.monthly;
                    }),
                    style: FilledButton.styleFrom(
                      backgroundColor: _activeSection == ExpenseSection.monthly
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context)
                              .colorScheme
                              .surfaceContainerHighest,
                      foregroundColor: _activeSection == ExpenseSection.monthly
                          ? Theme.of(context).colorScheme.onPrimary
                          : Theme.of(context).colorScheme.onSurface,
                    ),
                    child: const Text('Monthly'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_activeSection == ExpenseSection.daily)
              _DailySection(
                dayLabel: _formatDayLabel(_selectedDay),
                dailyExpenses: dailyExpenses,
                dailyTotal: dailyTotal,
                onTapDay: () => _showDayExpensesSheet(
                  context,
                  ref,
                  _selectedDay,
                  expenses,
                ),
                onTapExpense: (ExpenseEntry expense) => _showExpenseDialog(
                  context,
                  ref,
                  existing: expense,
                ),
              )
            else
              _MonthlySection(
                monthLabel: DateFormat('MMMM yyyy').format(_selectedMonth),
                monthDays: monthDays,
                monthlyExpenses: monthlyExpenses,
                monthlyTotal: monthlyTotal,
                onTapDay: _jumpToDailyDay,
              ),
          ],
        ),
      ),
    );
  }

  List<ExpenseEntry> _filteredExpenses(BudgetBuddyState state) {
    final List<ExpenseEntry> filtered =
        state.expenses.where((ExpenseEntry expense) {
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
        expense.dateTime.year,
        expense.dateTime.month,
        expense.dateTime.day,
      ));
    }
    final List<DateTime> sortedDays = days.toList()
      ..sort((DateTime left, DateTime right) => right.compareTo(left));
    return sortedDays;
  }

  List<ExpenseEntry> _expensesForDay(
    List<ExpenseEntry> expenses,
    DateTime day,
  ) {
    return expenses
        .where((ExpenseEntry expense) =>
            DateUtils.isSameDay(expense.dateTime, day))
        .toList();
  }

  List<ExpenseEntry> _expensesForMonth(
    List<ExpenseEntry> expenses,
    DateTime month,
  ) {
    return expenses
        .where(
          (ExpenseEntry expense) =>
              expense.dateTime.year == month.year &&
              expense.dateTime.month == month.month,
        )
        .toList();
  }

  List<ExpenseEntry> _sortExpenses(List<ExpenseEntry> expenses) {
    final List<ExpenseEntry> sorted = List<ExpenseEntry>.from(expenses);
    sorted.sort((ExpenseEntry left, ExpenseEntry right) {
      return right.dateTime.compareTo(left.dateTime);
    });
    return sorted;
  }

  Future<void> _showDayExpensesSheet(
    BuildContext context,
    WidgetRef ref,
    DateTime day,
    List<ExpenseEntry> expenses,
  ) async {
    final List<ExpenseEntry> dayExpenses = _expensesForDay(expenses, day);

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (BuildContext context) {
        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.78,
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    DateFormat('EEEE, MMM d, yyyy').format(day),
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${dayExpenses.length} expense${dayExpenses.length == 1 ? '' : 's'}',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                  const SizedBox(height: 12),
                  if (dayExpenses.isEmpty)
                    const Text('No expenses for this date.')
                  else
                    Expanded(
                      child: ListView.separated(
                        itemCount: dayExpenses.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (BuildContext context, int index) {
                          final ExpenseEntry expense = dayExpenses[index];
                          return Container(
                            decoration: BoxDecoration(
                              color: Theme.of(context)
                                  .colorScheme
                                  .surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: ListTile(
                              onTap: () => _showExpenseDialog(
                                context,
                                ref,
                                existing: expense,
                              ),
                              leading: CircleAvatar(
                                backgroundColor: expense.category.color
                                    .withValues(alpha: 0.14),
                                child: Text(
                                  expense.category.label.substring(0, 1),
                                ),
                              ),
                              title: Text(
                                expense.title,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              subtitle: Text(
                                expense.note.isNotEmpty
                                    ? '${expense.category.label} • ${expense.note}'
                                    : expense.category.label,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              trailing: Text(
                                formatPeso(expense.amount),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
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
  }

  void _jumpToDailyDay(DateTime day) {
    setState(() {
      _selectedDay = DateUtils.dateOnly(day);
      _selectedMonth = DateTime(day.year, day.month);
    });
    setState(() {
      _activeSection = ExpenseSection.daily;
    });
  }

  Future<void> _showExpenseDialog(
    BuildContext context,
    WidgetRef ref, {
    ExpenseEntry? existing,
  }) async {
    final TextEditingController titleController =
        TextEditingController(text: existing?.title ?? '');
    final TextEditingController amountController = TextEditingController(
      text: existing?.amount.toStringAsFixed(0) ?? '',
    );
    final TextEditingController noteController =
        TextEditingController(text: existing?.note ?? '');
    BudgetCategory category = existing?.category ?? BudgetCategory.food;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (BuildContext context) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
          ),
          child: StatefulBuilder(
            builder: (BuildContext context,
                void Function(void Function()) setModalState) {
              final BudgetBuddyState state =
                  ref.read(budgetBuddyControllerProvider);
              final BudgetSummary summary = ref.read(budgetSummaryProvider);
              final double enteredAmount =
                  double.tryParse(amountController.text) ?? 0;
              final double limit = _categoryLimit(category, state.settings);
              final double projectedTotal =
                  _categorySpent(summary, category) + enteredAmount;
              final bool showWarning = limit > 0 && projectedTotal > limit;

              return ListView(
                shrinkWrap: true,
                children: <Widget>[
                  Text(
                    existing == null ? 'Add expense' : 'Edit expense',
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: titleController,
                    decoration: const InputDecoration(labelText: 'Title'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: amountController,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    onChanged: (_) => setModalState(() {}),
                    decoration: const InputDecoration(labelText: 'Amount'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: noteController,
                    maxLines: 2,
                    decoration: const InputDecoration(labelText: 'Note'),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<BudgetCategory>(
                    initialValue: category,
                    items: BudgetCategory.values
                        .map(
                          (BudgetCategory item) =>
                              DropdownMenuItem<BudgetCategory>(
                            value: item,
                            child: Text(item.label),
                          ),
                        )
                        .toList(),
                    onChanged: (BudgetCategory? value) {
                      if (value != null) {
                        setModalState(() {
                          category = value;
                        });
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
                        border: Border.all(color: const Color(0xFFFCA5A5)),
                      ),
                      child: Text(
                        '${category.label} is now ${formatPeso(projectedTotal - limit)} over its limit.',
                        style: const TextStyle(
                          color: Color(0xFF991B1B),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () {
                        final BudgetBuddyController controller =
                            ref.read(budgetBuddyControllerProvider.notifier);
                        final ExpenseEntry entry = ExpenseEntry(
                          id: existing?.id ??
                              DateTime.now().microsecondsSinceEpoch.toString(),
                          title: titleController.text.trim().isEmpty
                              ? 'Expense'
                              : titleController.text.trim(),
                          amount: double.tryParse(amountController.text) ?? 0,
                          category: category,
                          dateTime: existing?.dateTime ?? DateTime.now(),
                          note: noteController.text.trim(),
                        );
                        if (existing == null) {
                          controller.addExpense(
                            title: entry.title,
                            amount: entry.amount,
                            category: entry.category,
                            note: entry.note,
                            dateTime: entry.dateTime,
                          );
                        } else {
                          controller.updateExpense(entry);
                        }
                        Navigator.of(context).pop();
                      },
                      child: Text(
                        existing == null ? 'Save expense' : 'Update expense',
                      ),
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

  String _formatDayLabel(DateTime dateTime) {
    final DateTime now = DateTime.now();
    if (DateUtils.isSameDay(dateTime, now)) {
      return 'Today, ${DateFormat('MMMM d, yyyy').format(dateTime)}';
    }
    return DateFormat('EEEE, MMM d, yyyy').format(dateTime);
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

class _DailySection extends StatelessWidget {
  const _DailySection({
    required this.dayLabel,
    required this.dailyExpenses,
    required this.dailyTotal,
    required this.onTapDay,
    required this.onTapExpense,
  });

  final String dayLabel;
  final List<ExpenseEntry> dailyExpenses;
  final double dailyTotal;
  final VoidCallback onTapDay;
  final ValueChanged<ExpenseEntry> onTapExpense;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'DAILY',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: onTapDay,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Text(
                dayLabel,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                      decoration: TextDecoration.underline,
                    ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${dailyExpenses.length} expense${dailyExpenses.length == 1 ? '' : 's'} today',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 4),
          Text('Total spent: ${formatPeso(dailyTotal)}'),
          const SizedBox(height: 12),
          if (dailyExpenses.isEmpty)
            Text(
              'No expenses for this day.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            )
          else
            ...dailyExpenses.map(
              (ExpenseEntry expense) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 2,
                  ),
                  tileColor:
                      Theme.of(context).colorScheme.surfaceContainerHighest,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  leading: CircleAvatar(
                    backgroundColor:
                        expense.category.color.withValues(alpha: 0.14),
                    child: Text(expense.category.label.substring(0, 1)),
                  ),
                  title: Text(expense.title),
                  subtitle: Text(expense.category.label),
                  trailing: Text(formatPeso(expense.amount)),
                  onTap: () => onTapExpense(expense),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _MonthlySection extends StatelessWidget {
  const _MonthlySection({
    required this.monthLabel,
    required this.monthDays,
    required this.monthlyExpenses,
    required this.monthlyTotal,
    required this.onTapDay,
  });

  final String monthLabel;
  final List<DateTime> monthDays;
  final List<ExpenseEntry> monthlyExpenses;
  final double monthlyTotal;
  final ValueChanged<DateTime> onTapDay;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'MONTHLY',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(
            'Month of $monthLabel',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            '${monthlyExpenses.length} expense${monthlyExpenses.length == 1 ? '' : 's'} in $monthLabel',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 4),
          Text('Total for the month: ${formatPeso(monthlyTotal)}'),
          const SizedBox(height: 12),
          if (monthDays.isEmpty)
            Text(
              'No expenses for this month yet.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            )
          else
            ...monthDays.map(
              (DateTime day) {
                final List<ExpenseEntry> dayExpenses = monthlyExpenses
                    .where((ExpenseEntry expense) =>
                        DateUtils.isSameDay(expense.dateTime, day))
                    .toList();
                final double total = dayExpenses.fold<double>(
                  0,
                  (double value, ExpenseEntry expense) =>
                      value + expense.amount,
                );
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 2,
                    ),
                    tileColor:
                        Theme.of(context).colorScheme.surfaceContainerHighest,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    title: Text(
                      DateFormat('EEEE, MMM d').format(day),
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: Text(
                      '${dayExpenses.length} expense${dayExpenses.length == 1 ? '' : 's'}',
                    ),
                    trailing: Text(formatPeso(total)),
                    onTap: () => onTapDay(day),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}
