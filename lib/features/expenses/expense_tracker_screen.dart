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
  DateTime _selectedMonth = DateTime(DateTime.now().year, DateTime.now().month);

  @override
  Widget build(BuildContext context) {
    final BudgetBuddyState state = ref.watch(budgetBuddyControllerProvider);
    final List<ExpenseEntry> expenses = _filteredExpenses(state);
    final List<DateTime> availableMonths = _availableMonths(expenses);
    final List<ExpenseEntry> dailyExpenses =
        _expensesForMonth(expenses, _selectedMonth);
    final List<DateTime> availableDays = _availableDays(dailyExpenses);

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const SectionTitle(
                title: 'Expenses',
                subtitle: 'View and manage your logged expenses.',
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
                            onPressed: () => setState(() {
                              _activeSection = ExpenseSection.daily;
                            }),
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
                            onPressed: () => setState(() {
                              _activeSection = ExpenseSection.monthly;
                            }),
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
                    if (_activeSection == ExpenseSection.daily)
                      _DailySection(
                        monthLabel: _monthLabel(_selectedMonth),
                        availableDays: availableDays,
                        expenses: dailyExpenses,
                        onTapDay: (DateTime day) => _showDayExpensesSheet(
                          context,
                          ref,
                          day,
                          dailyExpenses,
                          showBackButton: true,
                        ),
                      )
                    else
                      _MonthlySection(
                        availableMonths: availableMonths,
                        expenses: expenses,
                        onTapMonth: (DateTime month) {
                          setState(() {
                            _selectedMonth = DateTime(month.year, month.month);
                          });
                          _showMonthDatesSheet(context, ref, month, expenses);
                        },
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

  List<DateTime> _availableMonths(List<ExpenseEntry> expenses) {
    final Set<DateTime> months = <DateTime>{};
    for (final ExpenseEntry expense in expenses) {
      months.add(DateTime(expense.dateTime.year, expense.dateTime.month));
    }
    final List<DateTime> sortedMonths = months.toList()
      ..sort((DateTime left, DateTime right) => right.compareTo(left));
    return sortedMonths;
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

  Future<void> _showMonthDatesSheet(
    BuildContext context,
    WidgetRef ref,
    DateTime month,
    List<ExpenseEntry> expenses,
  ) async {
    final List<ExpenseEntry> monthExpenses = _expensesForMonth(expenses, month);
    final List<DateTime> monthDays = _availableDays(monthExpenses);

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: false,
      enableDrag: false,
      isDismissible: false,
      builder: (BuildContext sheetContext) {
        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(sheetContext).size.height * 0.78,
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      TextButton.icon(
                        onPressed: () {
                          Navigator.of(sheetContext).pop();
                        },
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
                    style:
                        Theme.of(sheetContext).textTheme.bodyMedium?.copyWith(
                              color: Theme.of(sheetContext)
                                  .colorScheme
                                  .onSurfaceVariant,
                            ),
                  ),
                  const SizedBox(height: 12),
                  if (monthDays.isEmpty)
                    const Text('No expenses for this month.')
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
                                total + expense.amount,
                          );

                          return ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            tileColor: Theme.of(context)
                                .colorScheme
                                .surfaceContainerHighest,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            leading: const Icon(Icons.calendar_today_outlined),
                            title: Text(
                              _formatDayLabel(day),
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            subtitle: Text(
                              '${dayExpenses.length} expense${dayExpenses.length == 1 ? '' : 's'}',
                            ),
                            trailing: Text(formatPeso(dayTotal)),
                            onTap: () async {
                              await _showDayExpensesSheet(
                                context,
                                ref,
                                day,
                                monthExpenses,
                                showBackButton: true,
                              );
                            },
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
    BuildContext context,
    WidgetRef ref,
    DateTime day,
    List<ExpenseEntry> expenses, {
    bool showBackButton = false,
  }) async {
    final List<ExpenseEntry> dayExpenses = _expensesForDay(expenses, day);
    final ExpenseEntry? editExpense = await showModalBottomSheet<ExpenseEntry>(
      context: context,
      isScrollControlled: true,
      showDragHandle: !showBackButton,
      enableDrag: !showBackButton,
      isDismissible: !showBackButton,
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
                  Row(
                    children: <Widget>[
                      if (showBackButton)
                        TextButton.icon(
                          onPressed: () {
                            Navigator.of(context).pop();
                          },
                          icon: const Icon(Icons.arrow_back_rounded),
                          label: const Text('Back'),
                        ),
                      Expanded(
                        child: Text(
                          DateFormat('EEEE, MMM d, yyyy').format(day),
                          style: Theme.of(context)
                              .textTheme
                              .titleLarge
                              ?.copyWith(fontWeight: FontWeight.w700),
                          textAlign:
                              showBackButton ? TextAlign.right : TextAlign.left,
                        ),
                      ),
                    ],
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
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  Row(
                                    children: <Widget>[
                                      CircleAvatar(
                                        backgroundColor: expense.category.color
                                            .withValues(alpha: 0.14),
                                        child: Text(
                                          expense.category.label
                                              .substring(0, 1),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: <Widget>[
                                            Text(
                                              expense.title,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              expense.note.isNotEmpty
                                                  ? '${expense.category.label} • ${expense.note}'
                                                  : expense.category.label,
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        formatPeso(expense.amount),
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Row(
                                    children: <Widget>[
                                      Expanded(
                                        child: OutlinedButton.icon(
                                          onPressed: () {
                                            Navigator.of(context).pop(expense);
                                          },
                                          icon: const Icon(
                                            Icons.edit_outlined,
                                          ),
                                          label: const Text('Edit'),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: OutlinedButton.icon(
                                          onPressed: () async {
                                            final bool shouldDelete =
                                                await _confirmDeleteExpense(
                                              context,
                                            );
                                            if (!context.mounted ||
                                                !shouldDelete) {
                                              return;
                                            }
                                            ref
                                                .read(
                                                  budgetBuddyControllerProvider
                                                      .notifier,
                                                )
                                                .deleteExpense(expense.id);
                                            Navigator.of(context).pop();
                                          },
                                          icon: const Icon(
                                            Icons.delete_outline_rounded,
                                          ),
                                          label: const Text('Delete'),
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
      if (!context.mounted) {
        return;
      }
      _showExpenseDialog(
        context,
        ref,
        existing: editExpense,
      );
    }
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
      showDragHandle: false,
      enableDrag: false,
      isDismissible: false,
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
                  Row(
                    children: <Widget>[
                      TextButton.icon(
                        onPressed: () {
                          Navigator.of(context).pop();
                        },
                        icon: const Icon(Icons.arrow_back_rounded),
                        label: const Text('Back'),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          existing == null ? 'Add Expense' : 'Edit Expense',
                          style: Theme.of(context)
                              .textTheme
                              .titleLarge
                              ?.copyWith(fontWeight: FontWeight.w700),
                          textAlign: TextAlign.right,
                        ),
                      ),
                    ],
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
                        existing == null ? 'Save Expense' : 'Update Expense',
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
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Delete'),
            ),
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

String _monthLabel(DateTime month) {
  return DateFormat('MMMM yyyy').format(month);
}

class _DailySection extends StatelessWidget {
  const _DailySection({
    required this.monthLabel,
    required this.availableDays,
    required this.expenses,
    required this.onTapDay,
  });

  final String monthLabel;
  final List<DateTime> availableDays;
  final List<ExpenseEntry> expenses;
  final ValueChanged<DateTime> onTapDay;

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
          Text(
            monthLabel,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 8),
          if (availableDays.isEmpty)
            Text(
              'No expenses yet.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            )
          else
            ...availableDays.map(
              (DateTime day) {
                final List<ExpenseEntry> dayExpenses = expenses
                    .where((ExpenseEntry expense) =>
                        DateUtils.isSameDay(expense.dateTime, day))
                    .toList();

                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    tileColor:
                        Theme.of(context).colorScheme.surfaceContainerHighest,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    leading: const Icon(Icons.calendar_today_outlined),
                    title: Text(
                      _formatDayLabel(day),
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: Text(
                      '${dayExpenses.length} expense${dayExpenses.length == 1 ? '' : 's'} • Tap for details',
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded),
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

class _MonthlySection extends StatelessWidget {
  const _MonthlySection({
    required this.availableMonths,
    required this.expenses,
    required this.onTapMonth,
  });

  final List<DateTime> availableMonths;
  final List<ExpenseEntry> expenses;
  final ValueChanged<DateTime> onTapMonth;

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
            'Tap a month to open its daily dates',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 8),
          if (availableMonths.isEmpty)
            Text(
              'No expenses yet.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            )
          else
            ...availableMonths.map(
              (DateTime month) {
                final List<ExpenseEntry> monthExpenses = expenses
                    .where((ExpenseEntry expense) =>
                        expense.dateTime.year == month.year &&
                        expense.dateTime.month == month.month)
                    .toList();
                final double total = monthExpenses.fold<double>(
                  0,
                  (double value, ExpenseEntry expense) =>
                      value + expense.amount,
                );
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    tileColor:
                        Theme.of(context).colorScheme.surfaceContainerHighest,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    leading: const Icon(Icons.date_range_outlined),
                    title: Text(
                      DateFormat('MMMM yyyy').format(month),
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: Text(
                      '${monthExpenses.length} expense${monthExpenses.length == 1 ? '' : 's'} • Tap for daily dates',
                    ),
                    trailing: Text(formatPeso(total)),
                    onTap: () => onTapMonth(month),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}
