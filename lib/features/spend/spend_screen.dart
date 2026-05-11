import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/budget_models.dart';
import '../../core/state/app_controller.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/budget_cards.dart';
import '../../core/widgets/section_title.dart';

class SpendScreen extends ConsumerStatefulWidget {
  const SpendScreen({super.key});

  @override
  ConsumerState<SpendScreen> createState() => _SpendScreenState();
}

class _SpendScreenState extends ConsumerState<SpendScreen> {
  static const String _spendTag = '[SPEND]';

  @override
  Widget build(BuildContext context) {
    final BudgetSummary summary = ref.watch(budgetSummaryProvider);

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: <Widget>[
            const SectionTitle(
              title: 'Spend',
              subtitle:
                  'Plan and log spending in one place. Every entry is deducted from active day and month limits.',
            ),
            const SizedBox(height: 12),
            _RemainingPills(summary: summary),
            const SizedBox(height: 16),
            SectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Quick spend categories',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Tap a category to log amount and note.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 12),
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
                        onTap: () => _showQuickCategorySheet(context, option),
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
    );
  }

  void _showQuickCategorySheet(
      BuildContext context, _SpendCategoryOption option) {
    final TextEditingController amountController =
        TextEditingController(text: option.defaultAmount.toStringAsFixed(0));
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
                  child: const Text('Log spend'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showCustomSpendSheet(BuildContext context, {ExpenseEntry? existing}) {
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
                    existing == null ? 'Add spend' : 'Edit spend',
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
                          child: Text(existing == null ? 'Log spend' : 'Save'),
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
          dateTime: DateTime.now(),
        );

    Navigator.of(context).pop();
    final BudgetSummary summary = ref.read(budgetSummaryProvider);
    final BudgetPeriodSummary? daySummary =
        summary.periodSummaries[BudgetPeriod.daily];
    final String suffix = daySummary == null || !daySummary.isActive
        ? ''
        : ' Day left: ${formatPeso(daySummary.remaining)}';

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
      return note.trim().isEmpty ? 'No note' : note.trim();
    }
    final String stripped = note.replaceFirst(_spendTag, '').trim();
    return stripped.isEmpty ? 'No note' : stripped;
  }
}

class _RemainingPills extends StatelessWidget {
  const _RemainingPills({required this.summary});

  final BudgetSummary summary;

  @override
  Widget build(BuildContext context) {
    final BudgetPeriodSummary? day =
        summary.periodSummaries[BudgetPeriod.daily];
    final BudgetPeriodSummary? month =
        summary.periodSummaries[BudgetPeriod.monthly];

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: <Widget>[
        _pill('Day', day),
        _pill('Month', month),
      ],
    );
  }

  Widget _pill(String label, BudgetPeriodSummary? period) {
    final bool active = period != null && period.isActive;
    final Color color = !active
        ? const Color(0xFF64748B)
        : period.isOverspent
            ? const Color(0xFFDC2626)
            : period.isWarning
                ? const Color(0xFFF59E0B)
                : const Color(0xFF0F766E);

    final String text = !active
        ? '$label not set'
        : period.isOverspent
            ? '$label ${formatPeso(period.overspentAmount)} over'
            : '$label ${formatPeso(period.remaining)} left';

    return SoftPill(text: text, color: color);
  }
}

class _CategoryGridTile extends StatelessWidget {
  const _CategoryGridTile({required this.option, required this.onTap});

  final _SpendCategoryOption option;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: option.color.withValues(alpha: 0.10),
      borderRadius: BorderRadius.circular(16),
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
                      color: option.color.withValues(alpha: 0.12),
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
    required this.defaultAmount,
    required this.color,
    this.isCustom = false,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final BudgetCategory budgetCategory;
  final double defaultAmount;
  final Color color;
  final bool isCustom;
}

const List<_SpendCategoryOption> _spendCategories = <_SpendCategoryOption>[
  _SpendCategoryOption(
    title: 'Food & drinks',
    subtitle: 'Meals, snacks, coffee',
    icon: Icons.restaurant_rounded,
    budgetCategory: BudgetCategory.food,
    defaultAmount: 120,
    color: Color(0xFF0F766E),
  ),
  _SpendCategoryOption(
    title: 'Transport',
    subtitle: 'Jeep, tricycle, Grab',
    icon: Icons.directions_bus_rounded,
    budgetCategory: BudgetCategory.transportation,
    defaultAmount: 70,
    color: Color(0xFF2563EB),
  ),
  _SpendCategoryOption(
    title: 'Shopping',
    subtitle: 'Clothes, personal',
    icon: Icons.shopping_bag_rounded,
    budgetCategory: BudgetCategory.shopping,
    defaultAmount: 220,
    color: Color(0xFF7C3AED),
  ),
  _SpendCategoryOption(
    title: 'Leisure & gala',
    subtitle: 'Outings, activities',
    icon: Icons.celebration_rounded,
    budgetCategory: BudgetCategory.entertainment,
    defaultAmount: 280,
    color: Color(0xFFF97316),
  ),
  _SpendCategoryOption(
    title: 'Health',
    subtitle: 'Meds, checkup',
    icon: Icons.health_and_safety_rounded,
    budgetCategory: BudgetCategory.miscellaneous,
    defaultAmount: 180,
    color: Color(0xFFDC2626),
  ),
  _SpendCategoryOption(
    title: 'Bills & utilities',
    subtitle: 'Load, electric, wifi',
    icon: Icons.receipt_long_rounded,
    budgetCategory: BudgetCategory.miscellaneous,
    defaultAmount: 350,
    color: Color(0xFF475569),
  ),
];

const _SpendCategoryOption _customSpendCategory = _SpendCategoryOption(
  title: 'Custom',
  subtitle: 'Any other spend',
  icon: Icons.edit_rounded,
  budgetCategory: BudgetCategory.miscellaneous,
  defaultAmount: 0,
  color: Color(0xFF8B5CF6),
  isCustom: true,
);
