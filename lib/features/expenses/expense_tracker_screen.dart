import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  static const String _swipeHintSeenKey = 'expense_swipe_hint_seen';

  final Set<String> _selectedExpenseIds = <String>{};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showSwipeHintIfNeeded();
    });
  }

  @override
  Widget build(BuildContext context) {
    final BudgetBuddyState state = ref.watch(budgetBuddyControllerProvider);
    final BudgetSummary summary = ref.watch(budgetSummaryProvider);
    final List<ExpenseEntry> visibleExpenses = _filteredExpenses(state);
    final List<_ExpenseGroup> groups = _groupExpenses(visibleExpenses);
    final bool hasSelection = _selectedExpenseIds.isNotEmpty;
    final double budgetProgress = summary.totalBudget <= 0
        ? 0
        : (summary.totalSpent / summary.totalBudget).clamp(0, 1).toDouble();
    final Color progressColor = summary.remainingBalance < 0
        ? const Color(0xFFDC2626)
        : Theme.of(context).colorScheme.primary;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _selectedExpenseIds.isEmpty
              ? ''
              : '${_selectedExpenseIds.length} selected',
        ),
        actions: <Widget>[
          if (hasSelection)
            IconButton(
              onPressed: () => _confirmDeleteSelected(context, ref),
              tooltip: 'Delete selected',
              icon: const Icon(Icons.delete_outline_rounded),
            ),
          if (hasSelection)
            IconButton(
              onPressed: _clearSelection,
              tooltip: 'Clear selection',
              icon: const Icon(Icons.close_rounded),
            ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          children: <Widget>[
            const SectionTitle(
              title: 'Expense tracker',
              subtitle: 'View all logged expenses and their categories.',
            ),
            SectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Today\'s summary',
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Remaining balance: ${formatPeso(summary.remainingBalance)}',
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Spent today: ${formatPeso(summary.totalSpent)} of ${formatPeso(summary.totalBudget)}',
                  ),
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      minHeight: 8,
                      value: budgetProgress,
                      backgroundColor: progressColor.withValues(alpha: 0.12),
                      valueColor: AlwaysStoppedAnimation<Color>(progressColor),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text('Savings: ${formatPeso(summary.savings)}'),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              visibleExpenses.isEmpty
                  ? 'No expenses yet. Use Spend to add expenses.'
                  : '${visibleExpenses.length} expense${visibleExpenses.length == 1 ? '' : 's'} total',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 16),
            if (groups.isEmpty)
              SectionCard(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      const Text(
                        'No expenses yet',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Use Spend to add new expenses.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                            ),
                      ),
                    ],
                  ),
                ),
              )
            else
              ...groups.expand(
                (_ExpenseGroup group) => <Widget>[
                  Padding(
                    padding: const EdgeInsets.only(top: 6, bottom: 10),
                    child: Row(
                      children: <Widget>[
                        Text(
                          _groupLabel(group.date),
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(width: 10),
                        SoftPill(
                          text: '${group.expenses.length}',
                          color: Theme.of(context).colorScheme.primary,
                          icon: Icons.receipt_long_rounded,
                        ),
                      ],
                    ),
                  ),
                  ...group.expenses.map(
                    (ExpenseEntry expense) => _buildExpenseTile(
                      context,
                      ref,
                      expense,
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  List<ExpenseEntry> _filteredExpenses(BudgetBuddyState state) {
    return state.expenses.where((ExpenseEntry expense) {
      if (state.currentExpenseFilter != null &&
          expense.category != state.currentExpenseFilter) {
        return false;
      }
      return true;
    }).toList();
  }

  List<_ExpenseGroup> _groupExpenses(List<ExpenseEntry> expenses) {
    if (expenses.isEmpty) {
      return <_ExpenseGroup>[];
    }

    final List<ExpenseEntry> sortedExpenses = _sortExpenses(expenses);
    final Map<DateTime, List<ExpenseEntry>> groups =
        <DateTime, List<ExpenseEntry>>{};
    for (final ExpenseEntry expense in sortedExpenses) {
      final DateTime dayKey = DateTime(
        expense.dateTime.year,
        expense.dateTime.month,
        expense.dateTime.day,
      );
      groups.putIfAbsent(dayKey, () => <ExpenseEntry>[]).add(expense);
    }

    final List<DateTime> sortedKeys = groups.keys.toList()
      ..sort((DateTime left, DateTime right) => right.compareTo(left));

    return sortedKeys
        .map(
          (DateTime key) => _ExpenseGroup(
            date: key,
            expenses: _sortExpenses(groups[key] ?? <ExpenseEntry>[]),
          ),
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

  Widget _buildExpenseTile(
      BuildContext context, WidgetRef ref, ExpenseEntry expense) {
    final bool selected = _selectedExpenseIds.contains(expense.id);
    final bool selectionMode = _selectedExpenseIds.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Dismissible(
        key: ValueKey<String>(expense.id),
        direction:
            selectionMode ? DismissDirection.none : DismissDirection.endToStart,
        background: Container(
          decoration: BoxDecoration(
            color: Colors.red.shade400,
            borderRadius: BorderRadius.circular(24),
          ),
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 20),
          child: const Icon(Icons.delete, color: Colors.white),
        ),
        onDismissed: (_) => _deleteExpenseWithUndo(context, ref, expense),
        child: SectionCard(
          padding: EdgeInsets.zero,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border(
                left: BorderSide(color: expense.category.color, width: 5),
              ),
              color: selected
                  ? expense.category.color.withValues(alpha: 0.08)
                  : Colors.transparent,
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 10,
              ),
              onTap: () {
                if (selectionMode) {
                  _toggleExpenseSelection(expense.id);
                  return;
                }
                _showExpenseDialog(context, ref, existing: expense);
              },
              onLongPress: () => _toggleExpenseSelection(expense.id),
              leading: selectionMode
                  ? Checkbox(
                      value: selected,
                      onChanged: (_) => _toggleExpenseSelection(expense.id),
                    )
                  : CircleAvatar(
                      backgroundColor:
                          expense.category.color.withValues(alpha: 0.14),
                      child: Text(expense.category.label.substring(0, 1)),
                    ),
              title: Text(
                expense.title,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      '${expense.category.label} • ${_groupLabel(expense.dateTime)}',
                    ),
                    if (expense.note.isNotEmpty) ...<Widget>[
                      const SizedBox(height: 4),
                      Text(
                        expense.note,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                            ),
                      ),
                    ],
                  ],
                ),
              ),
              trailing: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    formatPeso(expense.amount),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 6),
                  IconButton(
                    onPressed: () =>
                        _deleteExpenseWithUndo(context, ref, expense),
                    icon: const Icon(Icons.delete_outline_rounded),
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints:
                        const BoxConstraints.tightFor(width: 36, height: 36),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _toggleExpenseSelection(String expenseId) {
    setState(() {
      if (_selectedExpenseIds.contains(expenseId)) {
        _selectedExpenseIds.remove(expenseId);
      } else {
        _selectedExpenseIds.add(expenseId);
      }
    });
  }

  void _clearSelection() {
    setState(() {
      _selectedExpenseIds.clear();
    });
  }

  void _selectAllVisible(List<ExpenseEntry> visibleExpenses) {
    setState(() {
      _selectedExpenseIds
        ..clear()
        ..addAll(visibleExpenses.map((ExpenseEntry expense) => expense.id));
    });
  }

  Future<void> _confirmDeleteSelected(
      BuildContext context, WidgetRef ref) async {
    if (_selectedExpenseIds.isEmpty) {
      return;
    }
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final bool? shouldDelete = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete selected expenses?'),
          content: Text(
            'This will permanently delete ${_selectedExpenseIds.length} expense${_selectedExpenseIds.length == 1 ? '' : 's'}.',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (!mounted || shouldDelete != true) {
      return;
    }

    ref
        .read(budgetBuddyControllerProvider.notifier)
        .deleteExpenses(_selectedExpenseIds);
    _clearSelection();
    messenger.showSnackBar(
      const SnackBar(content: Text('Selected expenses deleted.')),
    );
  }

  void _deleteExpenseWithUndo(
      BuildContext context, WidgetRef ref, ExpenseEntry expense) {
    ref.read(budgetBuddyControllerProvider.notifier).deleteExpense(expense.id);
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text('${expense.title} deleted'),
          action: SnackBarAction(
            label: 'Undo',
            onPressed: () => ref
                .read(budgetBuddyControllerProvider.notifier)
                .restoreExpense(expense),
          ),
        ),
      );
  }

  Future<void> _showSwipeHintIfNeeded() async {
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    if (!mounted || prefs.getBool(_swipeHintSeenKey) == true) {
      return;
    }
    await prefs.setBool(_swipeHintSeenKey, true);
    if (!mounted) {
      return;
    }
    messenger.showSnackBar(
      const SnackBar(
        content: Text('Swipe left on any expense to delete it.'),
        duration: Duration(seconds: 4),
      ),
    );
  }

  String _groupLabel(DateTime dateTime) {
    final DateTime now = DateTime.now();
    if (DateUtils.isSameDay(dateTime, now)) {
      return 'Today';
    }
    if (DateUtils.isSameDay(dateTime, now.subtract(const Duration(days: 1)))) {
      return 'Yesterday';
    }
    if (dateTime.year == now.year) {
      return DateFormat('MMM d').format(dateTime);
    }
    return formatShortDate(dateTime);
  }

  void _showExpenseDialog(BuildContext context, WidgetRef ref,
      {ExpenseEntry? existing}) {
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

class _ExpenseGroup {
  const _ExpenseGroup({required this.date, required this.expenses});

  final DateTime date;
  final List<ExpenseEntry> expenses;
}
