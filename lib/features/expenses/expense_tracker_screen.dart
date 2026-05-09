import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/budget_models.dart';
import '../../core/state/app_controller.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/budget_cards.dart';
import '../../core/widgets/section_title.dart';

class ExpenseTrackerScreen extends ConsumerWidget {
  const ExpenseTrackerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final BudgetBuddyState state = ref.watch(budgetBuddyControllerProvider);
    final BudgetSummary summary = ref.watch(budgetSummaryProvider);
    final List<ExpenseEntry> expenses = state.currentExpenseFilter == null
        ? state.expenses
        : state.expenses.where((ExpenseEntry expense) => expense.category == state.currentExpenseFilter).toList();

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showExpenseDialog(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Add expense'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: <Widget>[
            SectionTitle(title: 'Expense tracker', subtitle: 'Edit, filter, and delete your daily logs.'),
            const SizedBox(height: 12),
            Row(
              children: <Widget>[
                ChoiceChip(
                  selected: state.currentExpenseFilter == null,
                  label: const Text('All'),
                  onSelected: (_) => ref.read(budgetBuddyControllerProvider.notifier).setExpenseFilter(null),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: BudgetCategory.values
                          .map(
                            (BudgetCategory category) => Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: ChoiceChip(
                                selected: state.currentExpenseFilter == category,
                                label: Text(category.label),
                                onSelected: (_) => ref.read(budgetBuddyControllerProvider.notifier).setExpenseFilter(category),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            GridView.count(
              crossAxisCount: MediaQuery.of(context).size.width > 500 ? 2 : 1,
              shrinkWrap: true,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: MediaQuery.of(context).size.width > 500 ? 1.7 : 2.2,
              physics: const NeverScrollableScrollPhysics(),
              children: <Widget>[
                BudgetMetricCard(
                  label: 'Expense count',
                  value: '${expenses.length}',
                  subtitle: 'Current filter',
                  icon: Icons.receipt_long_rounded,
                  color: const Color(0xFF2563EB),
                ),
                BudgetMetricCard(
                  label: 'Spent total',
                  value: formatPeso(expenses.fold(0, (double total, ExpenseEntry expense) => total + expense.amount)),
                  subtitle: 'Today',
                  icon: Icons.payments_rounded,
                  color: const Color(0xFFF97316),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text('Today\'s summary', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 12),
                  Text('Remaining balance: ${formatPeso(summary.remainingBalance)}'),
                  Text('Savings: ${formatPeso(summary.savings)}'),
                ],
              ),
            ),
            const SizedBox(height: 16),
            ...expenses.map(
              (ExpenseEntry expense) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Dismissible(
                  key: ValueKey<String>(expense.id),
                  background: Container(
                    decoration: BoxDecoration(color: Colors.red.shade400, borderRadius: BorderRadius.circular(24)),
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 20),
                    child: const Icon(Icons.delete, color: Colors.white),
                  ),
                  direction: DismissDirection.endToStart,
                  onDismissed: (_) => ref.read(budgetBuddyControllerProvider.notifier).deleteExpense(expense.id),
                  child: SectionCard(
                      child: ListTile(
                      onTap: () => _showExpenseDialog(context, ref, existing: expense),
                      leading: CircleAvatar(backgroundColor: expense.category.color.withOpacity(0.14), child: Text(expense.category.label.substring(0, 1))),
                      title: Text(expense.title, style: const TextStyle(fontWeight: FontWeight.w700)),
                      subtitle: Text('${expense.category.label} • ${formatShortDate(expense.dateTime)}'),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: <Widget>[
                          Text(formatPeso(expense.amount), style: const TextStyle(fontWeight: FontWeight.w700)),
                          const SizedBox(height: 2),
                          IconButton(
                            onPressed: () => ref.read(budgetBuddyControllerProvider.notifier).deleteExpense(expense.id),
                            icon: const Icon(Icons.delete_outline_rounded),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showExpenseDialog(BuildContext context, WidgetRef ref, {ExpenseEntry? existing}) {
    final TextEditingController titleController = TextEditingController(text: existing?.title ?? '');
    final TextEditingController amountController = TextEditingController(text: existing?.amount.toStringAsFixed(0) ?? '');
    final TextEditingController noteController = TextEditingController(text: existing?.note ?? '');
    BudgetCategory category = existing?.category ?? BudgetCategory.food;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext context) {
        return Padding(
          padding: EdgeInsets.only(left: 20, right: 20, top: 20, bottom: MediaQuery.of(context).viewInsets.bottom + 20),
          child: StatefulBuilder(
            builder: (BuildContext context, void Function(void Function()) setModalState) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(existing == null ? 'Add expense' : 'Edit expense', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 12),
                  TextField(controller: titleController, decoration: const InputDecoration(labelText: 'Title')),
                  const SizedBox(height: 12),
                  TextField(controller: amountController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Amount')),
                  const SizedBox(height: 12),
                  TextField(controller: noteController, decoration: const InputDecoration(labelText: 'Note')),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<BudgetCategory>(
                    value: category,
                    items: BudgetCategory.values.map((BudgetCategory item) => DropdownMenuItem<BudgetCategory>(value: item, child: Text(item.label))).toList(),
                    onChanged: (BudgetCategory? value) {
                      if (value != null) setModalState(() => category = value);
                    },
                    decoration: const InputDecoration(labelText: 'Category'),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () {
                        final BudgetBuddyController controller = ref.read(budgetBuddyControllerProvider.notifier);
                        final ExpenseEntry entry = ExpenseEntry(
                          id: existing?.id ?? DateTime.now().microsecondsSinceEpoch.toString(),
                          title: titleController.text.trim().isEmpty ? 'Expense' : titleController.text.trim(),
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
                      child: Text(existing == null ? 'Save expense' : 'Update expense'),
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
}