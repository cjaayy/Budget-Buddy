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

class SpendScreen extends ConsumerStatefulWidget {
  const SpendScreen({super.key, this.isTogetherOnly = false});

  final bool isTogetherOnly;

  @override
  ConsumerState<SpendScreen> createState() => _SpendScreenState();
}

class _SpendScreenState extends ConsumerState<SpendScreen> {
  static const String _spendTag = '[SPEND]';

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
    final BudgetSummary summary = widget.isTogetherOnly
        ? ref.watch(budgetTogetherSummaryProvider)
        : ref.watch(budgetSummaryProvider);
    final DateTime currentClock =
        ref.read(budgetBuddyControllerProvider.notifier).currentEffectiveTime;
    final Color spendColor = widget.isTogetherOnly
        ? const Color(0xFF0F766E)
        : const Color(0xFFDC2626);

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
                title:
                    widget.isTogetherOnly ? 'Spend (Budget Together)' : 'Spend',
                subtitle: widget.isTogetherOnly
                    ? 'Plan and log spending inside Budget Together. Deducted from your tab budget.'
                    : 'Plan and log spending in one place. Every entry is deducted from active day and month limits.',
              ),
              const SizedBox(height: 12),
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
                        Icon(Icons.today_rounded, size: 14, color: spendColor),
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
                ],
              ),
              const SizedBox(height: 16),
              _BalanceSummary(summary: summary),
              const SizedBox(height: 16),
              Expanded(
                child: ListView(
                  padding: EdgeInsets.zero,
                  children: <Widget>[
                    SectionCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Row(
                            children: <Widget>[
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: spendColor.withValues(alpha: 0.12),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.receipt_long_rounded,
                                  color: spendColor,
                                  size: 22,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: <Widget>[
                                    Text(
                                      'Quick Spend Categories',
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium
                                          ?.copyWith(
                                              fontWeight: FontWeight.w800),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                        'Choose a category or add a custom expense.',
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          const SizedBox(height: 2),
                          GridView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              crossAxisSpacing: 10,
                              mainAxisSpacing: 10,
                              childAspectRatio: 1.65,
                            ),
                            itemCount: _spendCategories.length,
                            itemBuilder: (BuildContext context, int index) {
                              final _SpendCategoryOption option =
                                  _spendCategories[index];
                              return _CategoryGridTile(
                                option: option,
                                onTap: () =>
                                    _showQuickCategorySheet(context, option),
                              );
                            },
                          ),
                          const SizedBox(height: 12),
                          Center(
                            child: SizedBox(
                              width: 120,
                              child: _CategoryGridTile(
                                option: _customSpendCategory,
                                onTap: () => _showCustomSpendSheet(context),
                              ),
                            ),
                          ),
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

  void _showQuickCategorySheet(
      BuildContext context, _SpendCategoryOption option) {
    if (!_ensureBudgetSet(context)) return;

    final TextEditingController amountController =
        TextEditingController(text: '');
    final TextEditingController noteController = TextEditingController();

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: false,
      builder: (BuildContext context) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 12,
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              TextButton.icon(
                onPressed: () => Navigator.of(context).pop(),
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  foregroundColor:
                      Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                icon: const Icon(Icons.arrow_back_rounded),
                label: const Text('Back'),
              ),
              const SizedBox(height: 8),
              Row(
                children: <Widget>[
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: option.color.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(option.icon, color: option.color),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          option.title,
                          style: Theme.of(context)
                              .textTheme
                              .titleLarge
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        Text(option.subtitle),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: amountController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Amount',
                  prefixText: '₱ ',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: noteController,
                decoration: const InputDecoration(labelText: 'Note'),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () {
                    final double amount =
                        double.tryParse(amountController.text) ?? 0;
                    if (amount <= 0) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Enter a valid amount greater than 0.'),
                        ),
                      );
                      return;
                    }
                    _logSpend(
                      context,
                      title: option.title,
                      amount: amount,
                      category: option.budgetCategory,
                      note: noteController.text.trim(),
                    );
                  },
                  child: const Text('Log Spend'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showCustomSpendSheet(BuildContext context, {ExpenseEntry? existing}) {
    if (existing == null && !_ensureBudgetSet(context)) return;

    final TextEditingController nameController =
        TextEditingController(text: existing?.title ?? '');
    final TextEditingController amountController = TextEditingController(
      text: existing != null ? existing.amount.toStringAsFixed(0) : '',
    );
    final TextEditingController noteController =
        TextEditingController(text: _stripSpendTag(existing?.note ?? ''));
    final BudgetCategory selectedCategory =
        existing?.category ?? BudgetCategory.miscellaneous;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: false,
      builder: (BuildContext context) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 12,
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
          ),
          child: StatefulBuilder(
            builder: (BuildContext context,
                void Function(void Function()) setModalState) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  TextButton.icon(
                    onPressed: () => Navigator.of(context).pop(),
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      foregroundColor:
                          Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    icon: const Icon(Icons.arrow_back_rounded),
                    label: const Text('Back'),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    existing == null ? 'Add Spend' : 'Edit Spend',
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(labelText: 'Name'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: amountController,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Amount',
                      prefixText: '₱ ',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: noteController,
                    decoration: const InputDecoration(labelText: 'Note'),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: <Widget>[
                      if (existing != null)
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () {
                              ref
                                  .read(budgetBuddyControllerProvider.notifier)
                                  .deleteExpense(existing.id);
                              Navigator.of(context).pop();
                            },
                            icon: const Icon(Icons.delete_outline_rounded),
                            label: const Text('Delete'),
                          ),
                        ),
                      if (existing != null) const SizedBox(width: 8),
                      Expanded(
                        child: FilledButton(
                          onPressed: () {
                            final double amount =
                                double.tryParse(amountController.text) ?? 0;
                            final String title = nameController.text.trim();
                            if (amount <= 0 || title.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                      'Enter a name and an amount greater than 0.'),
                                ),
                              );
                              return;
                            }

                            if (existing == null) {
                              _logSpend(
                                context,
                                title: title,
                                amount: amount,
                                category: selectedCategory,
                                note: noteController.text.trim(),
                              );
                              return;
                            }

                            ref
                                .read(budgetBuddyControllerProvider.notifier)
                                .updateExpense(
                                  existing.copyWith(
                                    title: title,
                                    amount: amount,
                                    category: selectedCategory,
                                    note: _withSpendTag(
                                        noteController.text.trim()),
                                  ),
                                );
                            Navigator.of(context).pop();
                          },
                          child: Text(existing == null ? 'Log Spend' : 'Save'),
                        ),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  void _logSpend(
    BuildContext context, {
    required String title,
    required double amount,
    required BudgetCategory category,
    required String note,
  }) {
    ref.read(budgetBuddyControllerProvider.notifier).addExpense(
          title: title,
          amount: amount,
          category: category,
          note: _withSpendTag(note),
          dateTime: ref.read(budgetBuddyControllerProvider.notifier).now,
          source: widget.isTogetherOnly ? 'togetherSpend' : 'manual',
          spendCategory: title,
        );

    Navigator.of(context).pop();
    final BudgetSummary summary = widget.isTogetherOnly
        ? ref.read(budgetTogetherSummaryProvider)
        : ref.read(budgetSummaryProvider);
    final BudgetPeriodSummary? daySummary =
        summary.periodSummaries[BudgetPeriod.daily];
    final String suffix = daySummary == null || !daySummary.isActive
        ? ''
        : ' Day Left: ${formatPeso(daySummary.remaining)}';

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$title logged.$suffix')),
    );
  }

  bool _isSpendTagged(String note) {
    return note.startsWith(_spendTag);
  }

  String _withSpendTag(String note) {
    final String trimmed = note.trim();
    if (trimmed.isEmpty) {
      return _spendTag;
    }
    return '$_spendTag $trimmed';
  }

  String _stripSpendTag(String note) {
    if (!_isSpendTagged(note)) {
      return note.trim();
    }
    final String stripped = note.replaceFirst(_spendTag, '').trim();
    return stripped;
  }
}

class _BalanceSummary extends StatelessWidget {
  const _BalanceSummary({required this.summary});

  final BudgetSummary summary;

  @override
  Widget build(BuildContext context) {
    final BudgetPeriodSummary? day =
        summary.periodSummaries[BudgetPeriod.daily];
    final BudgetPeriodSummary? month =
        summary.periodSummaries[BudgetPeriod.monthly];

    return Row(
      children: <Widget>[
        Expanded(child: _BalanceCard(label: 'Day', period: day)),
        const SizedBox(width: 10),
        Expanded(child: _BalanceCard(label: 'Month', period: month)),
      ],
    );
  }
}

class _BalanceCard extends StatelessWidget {
  const _BalanceCard({required this.label, required this.period});

  final String label;
  final BudgetPeriodSummary? period;

  @override
  Widget build(BuildContext context) {
    final bool active = period != null && period!.isActive;
    final bool isOver = active && period!.isOverspent;
    final Color color = !active
        ? const Color(0xFF64748B)
        : isOver
            ? const Color(0xFFDC2626)
            : period!.isWarning
                ? const Color(0xFFF59E0B)
                : const Color(0xFF0F766E);
    final String value = !active
        ? 'Not set'
        : isOver
            ? formatPeso(period!.overspentAmount)
            : formatPeso(period!.remaining);
    final String caption = !active
        ? 'Set a budget first'
        : isOver
            ? 'Over'
            : 'Left';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(
                label == 'Day' ? Icons.today_rounded : Icons.date_range_rounded,
                size: 17,
                color: color,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: color,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            caption,
            style: TextStyle(
              color: color.withValues(alpha: 0.85),
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryGridTile extends StatelessWidget {
  const _CategoryGridTile({required this.option, required this.onTap});

  final _SpendCategoryOption option;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: Theme.of(context).colorScheme.outlineVariant,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: <Widget>[
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceContainerLow,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      option.icon,
                      color: option.color,
                      size: 18,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    option.title,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context)
                        .textTheme
                        .titleSmall
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SpendCategoryOption {
  const _SpendCategoryOption({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.budgetCategory,
    required this.color,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final BudgetCategory budgetCategory;
  final Color color;
}

const List<_SpendCategoryOption> _spendCategories = <_SpendCategoryOption>[
  _SpendCategoryOption(
    title: 'Food & Drinks',
    subtitle: 'Meals, Snacks, Coffee',
    icon: Icons.restaurant_rounded,
    budgetCategory: BudgetCategory.food,
    color: Color(0xFFDC2626),
  ),
  _SpendCategoryOption(
    title: 'Transport',
    subtitle: 'Jeep, Tricycle, Grab',
    icon: Icons.directions_bus_rounded,
    budgetCategory: BudgetCategory.transportation,
    color: Color(0xFFDC2626),
  ),
  _SpendCategoryOption(
    title: 'Shopping',
    subtitle: 'Clothes, Personal',
    icon: Icons.shopping_bag_rounded,
    budgetCategory: BudgetCategory.shopping,
    color: Color(0xFFDC2626),
  ),
  _SpendCategoryOption(
    title: 'Leisure & Gala',
    subtitle: 'Outings, Activities',
    icon: Icons.celebration_rounded,
    budgetCategory: BudgetCategory.entertainment,
    color: Color(0xFFDC2626),
  ),
  _SpendCategoryOption(
    title: 'Health',
    subtitle: 'Meds, Checkup',
    icon: Icons.health_and_safety_rounded,
    budgetCategory: BudgetCategory.miscellaneous,
    color: Color(0xFFDC2626),
  ),
  _SpendCategoryOption(
    title: 'Bills & Utilities',
    subtitle: 'Load, Electric, Wifi',
    icon: Icons.receipt_long_rounded,
    budgetCategory: BudgetCategory.miscellaneous,
    color: Color(0xFFDC2626),
  ),
];

const _SpendCategoryOption _customSpendCategory = _SpendCategoryOption(
  title: 'Custom',
  subtitle: 'Any Other Spend',
  icon: Icons.edit_rounded,
  budgetCategory: BudgetCategory.miscellaneous,
  color: Color(0xFFDC2626),
);
