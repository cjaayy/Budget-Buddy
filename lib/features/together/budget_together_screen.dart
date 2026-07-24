import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/budget_models.dart';
import '../../core/state/app_controller.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/budget_cards.dart';
import '../../core/widgets/section_title.dart';

class BudgetTogetherScreen extends ConsumerStatefulWidget {
  const BudgetTogetherScreen({super.key});

  @override
  ConsumerState<BudgetTogetherScreen> createState() =>
      _BudgetTogetherScreenState();
}

class _BudgetTogetherScreenState extends ConsumerState<BudgetTogetherScreen> {
  late final TextEditingController _budgetController;
  bool _seededFromState = false;
  bool _isEditing = false;
  String? _editingSnapshot;

  @override
  void initState() {
    super.initState();
    _budgetController = TextEditingController();
    _budgetController.addListener(_onBudgetChanged);
  }

  @override
  void dispose() {
    _budgetController.removeListener(_onBudgetChanged);
    _budgetController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final BudgetBuddyState state = ref.watch(budgetBuddyControllerProvider);

    ref.listen<BudgetBuddyState>(budgetBuddyControllerProvider,
        (BudgetBuddyState? previous, BudgetBuddyState next) {
      final double nextAmount = next.togetherBudget;
      final double prevAmount = previous?.togetherBudget ?? -1;
      if (nextAmount != prevAmount) {
        final String newText =
            nextAmount > 0 ? nextAmount.toStringAsFixed(0) : '';
        if (_budgetController.text != newText) {
          _budgetController.text = newText;
        }
      }
    });

    if (!_seededFromState && !state.isBootstrapping) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _seedFromState(state);
        }
      });
    }

    final double amount =
        double.tryParse(_budgetController.text.trim()) ?? state.togetherBudget;
    final String displayedBudget = amount > 0 ? formatPeso(amount) : '₱0';
    final bool hasBudget = state.togetherBudget > 0;
    final bool canEdit = _isEditing || !hasBudget;

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
                  label: const Text(
                    'Back to Menu',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor:
                        const Color(0xFF0F766E).withValues(alpha: 0.12),
                    foregroundColor: const Color(0xFF0F766E),
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
              const SectionTitle(
                title: 'Set Budget Together',
                subtitle: 'This budget is only for the Budget Together tab.',
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ListView(
                  padding: EdgeInsets.zero,
                  children: <Widget>[
                    BudgetMetricCard(
                      label: 'Budget Together Budget',
                      value: displayedBudget,
                      subtitle: 'Local to this tab only',
                      icon: Icons.groups_rounded,
                      color: const Color(0xFF0F766E),
                      centerContent: true,
                    ),
                    const SizedBox(height: 16),
                    SectionCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Row(
                            children: <Widget>[
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: <Widget>[
                                    Text(
                                      'Budget Amount',
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium
                                          ?.copyWith(fontWeight: FontWeight.w800),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Set a budget that stays inside the Budget Together tab.',
                                      style: Theme.of(context).textTheme.bodyMedium,
                                    ),
                                  ],
                                ),
                              ),
                              if (hasBudget && !_isEditing)
                                OutlinedButton.icon(
                                  onPressed: () {
                                    setState(() {
                                      _editingSnapshot = _budgetController.text;
                                      _isEditing = true;
                                    });
                                  },
                                  icon: const Icon(Icons.edit_rounded, size: 18),
                                  label: const Text('Edit'),
                                ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _budgetController,
                            readOnly: !canEdit,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: const InputDecoration(
                              prefixText: '₱ ',
                              labelText: 'Enter tab budget',
                              border: OutlineInputBorder(),
                            ),
                            onSubmitted: (_) {
                              if (canEdit && _budgetController.text.trim().isNotEmpty) {
                                _saveBudget();
                              }
                            },
                          ),
                          const SizedBox(height: 12),
                          if (!hasBudget && !_isEditing) ...<Widget>[
                            SizedBox(
                              width: double.infinity,
                              child: FilledButton.icon(
                                onPressed: _budgetController.text.trim().isEmpty
                                    ? null
                                    : _saveBudget,
                                icon: const Icon(Icons.check_circle_rounded),
                                label: const Text('Save Budget'),
                              ),
                            ),
                          ] else if (_isEditing) ...<Widget>[
                            Row(
                              children: <Widget>[
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: () {
                                      FocusScope.of(context).unfocus();
                                      setState(() {
                                        if (_editingSnapshot != null) {
                                          _budgetController.text = _editingSnapshot!;
                                        }
                                        _isEditing = false;
                                      });
                                    },
                                    icon: const Icon(Icons.close_rounded),
                                    label: const Text('Cancel'),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: FilledButton.icon(
                                    onPressed: _budgetController.text.trim().isEmpty
                                        ? null
                                        : _saveBudget,
                                    icon: const Icon(Icons.save_rounded),
                                    label: const Text('Save'),
                                  ),
                                ),
                              ],
                            ),
                          ],
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

  void _onBudgetChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  void _seedFromState(BudgetBuddyState state) {
    if (_seededFromState) {
      return;
    }

    _budgetController.text =
        state.togetherBudget > 0 ? state.togetherBudget.toStringAsFixed(0) : '';

    setState(() {
      _seededFromState = true;
    });
  }

  Future<void> _saveBudget() async {
    final double amount = double.tryParse(_budgetController.text.trim()) ?? 0;

    ref.read(budgetBuddyControllerProvider.notifier).setTogetherBudget(amount);

    await showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          icon: const Icon(Icons.check_circle_rounded),
          title: const Text('Budget Saved'),
          content: const Text(
            'This budget is saved only inside Budget Together.',
          ),
          actions: <Widget>[
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }
}
