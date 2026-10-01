import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../core/models/budget_models.dart';
import '../../core/state/app_controller.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/budget_cards.dart';
import '../budget/budget_planner_screen.dart';
import '../together/budget_together_screen.dart';
import 'package:budgetbuddy/core/utils/alert_dialog.dart';

/// Clean Modern Bento Tokens for Spend Screen.
/// Emphasizes Dark Red (#991B1B) as primary expense accent with Dark Teal (#0F766E) and Gold (#D97706).
class _SpendTokens {
  const _SpendTokens(this.isDark);

  final bool isDark;

  // Primary 3-Color Strict Palette
  static const Color expenseRed = Color(0xFF991B1B);
  static const Color safeGreen = Color(0xFF0F766E);
  static const Color budgetGold = Color(0xFFD97706);

  // Surfaces & Borders
  Color get scaffoldBg =>
      isDark ? const Color(0xFF0B1120) : const Color(0xFFF8FAFC);
  Color get cardBg =>
      isDark ? const Color(0xFF111827) : const Color(0xFFFFFFFF);
  Color get cardBorder =>
      isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0);
  Color get subCardBg =>
      isDark ? const Color(0xFF161F31) : const Color(0xFFF1F5F9);
  Color get keyTileBg =>
      isDark ? const Color(0xFF161F31) : const Color(0xFFFFFFFF);

  // Text
  Color get textPrimary =>
      isDark ? const Color(0xFFF1F5F9) : const Color(0xFF0F172A);
  Color get textSecondary =>
      isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
  Color get textMuted =>
      isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8);

  Color tint(Color color, [double alpha = 0.10]) =>
      color.withValues(alpha: alpha);
}

/// Represents an item in the batch queue ready to be logged
class _PendingSpendItem {
  _PendingSpendItem({
    required this.id,
    required this.title,
    required this.amount,
    required this.category,
    required this.color,
    required this.icon,
    this.note = '',
    this.categoryName = '',
    this.isDebt = false,
  });

  final String id;
  final String title;
  final double amount;
  final BudgetCategory category;
  final Color color;
  final IconData icon;
  final String note;
  final String categoryName;
  final bool isDebt;
}

class _SpendCategoryOption {
  const _SpendCategoryOption({
    required this.title,
    required this.icon,
    required this.budgetCategory,
    required this.color,
  });

  final String title;
  final IconData icon;
  final BudgetCategory budgetCategory;
  final Color color;
}

const List<_SpendCategoryOption> _spendCategories = <_SpendCategoryOption>[
  _SpendCategoryOption(
    title: 'Food & Drinks',
    icon: Icons.restaurant_rounded,
    budgetCategory: BudgetCategory.food,
    color: Color(0xFFD97706), // Gold
  ),
  _SpendCategoryOption(
    title: 'Transport',
    icon: Icons.directions_bus_rounded,
    budgetCategory: BudgetCategory.transportation,
    color: Color(0xFF0F766E), // Dark Green
  ),
  _SpendCategoryOption(
    title: 'Shopping',
    icon: Icons.shopping_bag_rounded,
    budgetCategory: BudgetCategory.shopping,
    color: Color(0xFF991B1B), // Dark Red
  ),
  _SpendCategoryOption(
    title: 'Leisure & Gala',
    icon: Icons.celebration_rounded,
    budgetCategory: BudgetCategory.entertainment,
    color: Color(0xFFD97706), // Gold
  ),
  _SpendCategoryOption(
    title: 'Bills & Utilities',
    icon: Icons.receipt_long_rounded,
    budgetCategory: BudgetCategory.miscellaneous,
    color: Color(0xFF991B1B), // Dark Red
  ),
  _SpendCategoryOption(
    title: 'Health',
    icon: Icons.health_and_safety_rounded,
    budgetCategory: BudgetCategory.miscellaneous,
    color: Color(0xFF0F766E), // Dark Green
  ),
];

class SpendScreen extends ConsumerStatefulWidget {
  const SpendScreen({super.key, this.isTogetherOnly = false});

  final bool isTogetherOnly;

  @override
  ConsumerState<SpendScreen> createState() => _SpendScreenState();
}

class _SpendScreenState extends ConsumerState<SpendScreen> {
  static const String _spendTag = '[SPEND]';
  final List<_PendingSpendItem> _pendingSpends = <_PendingSpendItem>[];

  // Spend Input State
  final TextEditingController _amountController = TextEditingController();
  final FocusNode _amountFocusNode = FocusNode();
  bool _isAddingSpend = false;
  _SpendCategoryOption _selectedCategory = _spendCategories.first;
  bool _isCustomCategory = false;
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();
  final TextEditingController _customCategoryController = TextEditingController();
  final FocusNode _customCategoryFocusNode = FocusNode();
  bool _isQueueExpanded = true;

  @override
  void initState() {
    super.initState();
    _selectedCategory = _spendCategories.first;
  }

  @override
  void dispose() {
    _amountController.dispose();
    _amountFocusNode.dispose();
    _titleController.dispose();
    _noteController.dispose();
    _customCategoryController.dispose();
    _customCategoryFocusNode.dispose();
    super.dispose();
  }

  String get _effectiveCategoryTitle {
    if (_isCustomCategory) {
      final String custom = _customCategoryController.text.trim();
      return custom.isNotEmpty ? custom : 'Custom';
    }
    return _selectedCategory.title;
  }

  Color get _effectiveCategoryColor {
    if (_isCustomCategory) {
      return _SpendTokens.budgetGold;
    }
    return _selectedCategory.color;
  }

  IconData get _effectiveCategoryIcon {
    if (_isCustomCategory) {
      return Icons.edit_note_rounded;
    }
    return _selectedCategory.icon;
  }

  BudgetCategory get _effectiveBudgetCategory {
    if (_isCustomCategory) {
      return BudgetCategory.miscellaneous;
    }
    return _selectedCategory.budgetCategory;
  }

  double get _currentAmount {
    final String clean = _amountController.text.replaceAll(',', '').trim();
    return double.tryParse(clean) ?? 0.0;
  }

  void _onQuickAddAmount(double addAmount) {
    HapticFeedback.lightImpact();
    final double next = _currentAmount + addAmount;
    final String text =
        next % 1 == 0 ? next.toInt().toString() : next.toStringAsFixed(2);
    setState(() {
      _amountController.text = text;
      _amountController.selection =
          TextSelection.fromPosition(TextPosition(offset: text.length));
    });
  }

  void _addToQueue() {
    if (_currentAmount <= 0) {
      showAppAlert(
        context,
        message: 'Please enter an expense amount greater than ₱0.',
        title: 'Notice',
        icon: Icons.info_outline_rounded,
      );
      return;
    }

    _handleSpendAction(
      context,
      amountToSpend: _currentAmount,
      isBatch: true,
      onProceed: ({bool isDebt = false}) => _doAddToQueue(isDebt: isDebt),
    );
  }

  void _doAddToQueue({bool isDebt = false}) {
    HapticFeedback.mediumImpact();
    final double itemAmount = _currentAmount;
    final String enteredTitle = _titleController.text.trim();
    final String categoryTitle = _effectiveCategoryTitle;
    final String title =
        enteredTitle.isNotEmpty ? enteredTitle : categoryTitle;

    final String enteredNote = _noteController.text.trim();
    final String note = isDebt
        ? (enteredNote.isNotEmpty ? '$enteredNote (Charged to Debt)' : 'Charged to Debt')
        : enteredNote;

    setState(() {
      _pendingSpends.add(
        _PendingSpendItem(
          id: '${DateTime.now().microsecondsSinceEpoch}_${_pendingSpends.length}',
          title: title,
          amount: itemAmount,
          category: _effectiveBudgetCategory,
          color: isDebt ? _SpendTokens.expenseRed : _effectiveCategoryColor,
          icon: isDebt ? Icons.receipt_long_rounded : _effectiveCategoryIcon,
          categoryName: categoryTitle,
          isDebt: isDebt,
          note: note,
        ),
      );
      _amountController.clear();
      _titleController.clear();
      _noteController.clear();
      _isQueueExpanded = true;
    });

    showAppAlert(
      context,
      message: isDebt
          ? 'Added "$title" to batch as Debt (${formatPeso(itemAmount)})'
          : 'Added "$title" to batch queue (${formatPeso(itemAmount)})',
      title: isDebt ? 'Added as Debt' : 'Notice',
      icon: isDebt ? Icons.receipt_long_rounded : Icons.info_outline_rounded,
      accentColor: isDebt ? _SpendTokens.expenseRed : _SpendTokens.budgetGold,
    );
  }

  void _removeFromQueue(String id) {
    HapticFeedback.lightImpact();
    setState(() {
      _pendingSpends.removeWhere((item) => item.id == id);
    });
  }

  void _clearQueue() {
    HapticFeedback.mediumImpact();
    setState(() {
      _pendingSpends.clear();
    });
  }

  void _submitSpend(BuildContext context) {
    final double amountToSubmit = _pendingSpends.fold(
          0.0,
          (double sum, _PendingSpendItem item) => sum + item.amount,
        ) +
        (_currentAmount > 0 ? _currentAmount : 0);

    if (amountToSubmit <= 0) {
      showAppAlert(
        context,
        message: 'Enter an amount or add items to queue first.',
        title: 'Notice',
        icon: Icons.info_outline_rounded,
      );
      return;
    }

    _handleSpendAction(
      context,
      amountToSpend: amountToSubmit,
      isBatch: _pendingSpends.isNotEmpty,
      onProceed: ({bool isDebt = false}) =>
          _doSubmitSpend(context, isDebt: isDebt),
    );
  }

  void _doSubmitSpend(BuildContext context, {bool isDebt = false}) {
    final controller = ref.read(budgetBuddyControllerProvider.notifier);
    final DateTime now = controller.now;

    // If there is currently typed amount in the input, auto-include it
    if (_currentAmount > 0) {
      final String enteredTitle = _titleController.text.trim();
      final String categoryTitle = _effectiveCategoryTitle;
      final String title =
          enteredTitle.isNotEmpty ? enteredTitle : categoryTitle;
      final String enteredNote = _noteController.text.trim();
      final String note = isDebt
          ? (enteredNote.isNotEmpty ? '$enteredNote (Charged to Debt)' : 'Charged to Debt')
          : enteredNote;
      _pendingSpends.add(
        _PendingSpendItem(
          id: '${DateTime.now().microsecondsSinceEpoch}_${_pendingSpends.length}',
          title: title,
          amount: _currentAmount,
          category: _effectiveBudgetCategory,
          color: isDebt ? _SpendTokens.expenseRed : _effectiveCategoryColor,
          icon: isDebt ? Icons.receipt_long_rounded : _effectiveCategoryIcon,
          categoryName: categoryTitle,
          isDebt: isDebt,
          note: note,
        ),
      );
      _amountController.clear();
      _titleController.clear();
      _noteController.clear();
    }

    if (_pendingSpends.isEmpty) {
      showAppAlert(
        context,
        message: 'Enter an amount or add items to queue first.',
        title: 'Notice',
        icon: Icons.info_outline_rounded,
      );
      return;
    }

    HapticFeedback.heavyImpact();
    final int count = _pendingSpends.length;
    double total = 0;
    bool hasAnyDebt = isDebt;

    for (final _PendingSpendItem item in _pendingSpends) {
      total += item.amount;
      final bool itemIsDebt = isDebt || item.isDebt;
      if (itemIsDebt) hasAnyDebt = true;

      controller.addExpense(
        title: item.title,
        amount: item.amount,
        category: item.category,
        note: itemIsDebt
            ? (item.note.isNotEmpty ? item.note : 'Charged to Debt')
            : item.note,
        dateTime: now,
        source: widget.isTogetherOnly
            ? 'togetherSpend'
            : (itemIsDebt ? 'debt' : 'manual'),
        spendCategory:
            item.categoryName.isNotEmpty ? item.categoryName : item.title,
      );
    }

    setState(() {
      _pendingSpends.clear();
      _amountController.clear();
      _titleController.clear();
      _noteController.clear();
      _isAddingSpend = false;
    });

    final BudgetSummary summary = widget.isTogetherOnly
        ? ref.read(budgetTogetherSummaryProvider)
        : ref.read(budgetSummaryProvider);
    final BudgetPeriodSummary? daySummary =
        summary.periodSummaries[BudgetPeriod.daily];
    final String suffix = daySummary == null || !daySummary.isActive
        ? ''
        : ' • Left: ${formatPeso(daySummary.remaining)}';

    showAppAlert(
      context,
      message: hasAnyDebt
          ? '$count ${count == 1 ? 'spend' : 'spends'} logged as Debt (${formatPeso(total)})$suffix'
          : '$count ${count == 1 ? 'spend' : 'spends'} logged (${formatPeso(total)})$suffix',
      title: hasAnyDebt ? 'Logged to Debt' : 'Success',
      icon: hasAnyDebt
          ? Icons.receipt_long_rounded
          : Icons.check_circle_outline_rounded,
      accentColor:
          hasAnyDebt ? _SpendTokens.expenseRed : _SpendTokens.safeGreen,
    );
  }

  String _stripSpendTag(String note) {
    return note.replaceAll(_spendTag, '').trim();
  }

  void _handleSpendAction(
    BuildContext context, {
    required double amountToSpend,
    required void Function({bool isDebt}) onProceed,
    bool isBatch = false,
  }) {
    final BudgetBuddyState state = ref.read(budgetBuddyControllerProvider);
    final BudgetSummary summary = widget.isTogetherOnly
        ? ref.read(budgetTogetherSummaryProvider)
        : ref.read(budgetSummaryProvider);
    final BudgetPeriodSummary dailySummary =
        summary.periodSummaries[BudgetPeriod.daily] ??
            const BudgetPeriodSummary(
              period: BudgetPeriod.daily,
              limit: 0,
              spent: 0,
            );

    final double currentBudget = widget.isTogetherOnly
        ? state.togetherBudget
        : (state.settings.dailyLimit ?? 0);
    final double currentSpent = dailySummary.spent;
    final double remaining = currentBudget - currentSpent;

    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final _SpendTokens tokens = _SpendTokens(isDark);

    void navigateToPlanner() {
      if (widget.isTogetherOnly) {
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => const BudgetTogetherScreen(),
          ),
        );
      } else {
        ref.read(homeShellIndexProvider.notifier).state = 1;
        Navigator.of(context).popUntil((Route<dynamic> route) => route.isFirst);
      }
    }

    // Max Budget Reached, Exceeded, or Budget is Zero:
    // Prompt with the selected batch/spend price, Debt, or Add in Budget options.
    if (currentBudget <= 0 || remaining <= 0 || amountToSpend > remaining) {
      showDialog<void>(
        context: context,
        builder: (BuildContext dialogContext) {
          final double overAmount = remaining <= 0
              ? amountToSpend
              : (amountToSpend - remaining);

          return AlertDialog(
            backgroundColor: tokens.cardBg,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
              side: BorderSide(color: tokens.cardBorder, width: 1.0),
            ),
            titlePadding: const EdgeInsets.fromLTRB(18, 18, 18, 6),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
            actionsPadding: const EdgeInsets.fromLTRB(16, 6, 16, 16),
            icon: const Icon(
              Icons.error_outline_rounded,
              color: _SpendTokens.expenseRed,
              size: 40,
            ),
            title: Text(
              currentBudget <= 0
                  ? (widget.isTogetherOnly
                      ? 'Budget Together Required'
                      : 'Today\'s Budget Required')
                  : 'Max Budget Reached',
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.w800,
                fontSize: 16,
                color: tokens.textPrimary,
              ),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  // Prominent Batch / Spend Price Card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: tokens.tint(_SpendTokens.expenseRed, 0.08),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: _SpendTokens.expenseRed.withValues(alpha: 0.25),
                        width: 1.2,
                      ),
                    ),
                    child: Column(
                      children: <Widget>[
                        Text(
                          isBatch ? 'Batch Amount Selected' : 'Spend Amount',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: tokens.textSecondary,
                            letterSpacing: 0.3,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          formatPeso(amountToSpend),
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 30,
                            fontWeight: FontWeight.w900,
                            color: _SpendTokens.expenseRed,
                            letterSpacing: -1.0,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Budget Context Breakdown Box
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: tokens.subCardBg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: tokens.cardBorder, width: 1.0),
                    ),
                    child: Column(
                      children: <Widget>[
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: <Widget>[
                            Text(
                              'Today\'s Budget',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: tokens.textSecondary,
                              ),
                            ),
                            Text(
                              formatPeso(currentBudget),
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: tokens.textPrimary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: <Widget>[
                            Text(
                              'Spent Today',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: tokens.textSecondary,
                              ),
                            ),
                            Text(
                              formatPeso(currentSpent),
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: _SpendTokens.expenseRed,
                              ),
                            ),
                          ],
                        ),
                        if (overAmount > 0) ...<Widget>[
                          const SizedBox(height: 6),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: <Widget>[
                              Text(
                                'Exceeds Safe Limit By',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: _SpendTokens.expenseRed,
                                ),
                              ),
                              Text(
                                formatPeso(overAmount),
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  color: _SpendTokens.expenseRed,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    currentBudget <= 0
                        ? 'No daily budget is set for today. Choose how you want to handle this spend:'
                        : 'Today\'s budget limit reached. Choose how you want to handle this spend:',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w500,
                      color: tokens.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Option 1: Charge to Debt (only visible when a budget is set and reached/exceeded)
                  if (currentBudget > 0) ...<Widget>[
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () {
                          Navigator.of(dialogContext).pop();
                          onProceed(isDebt: true);
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: tokens.tint(_SpendTokens.expenseRed, 0.08),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: _SpendTokens.expenseRed.withValues(alpha: 0.35),
                              width: 1.2,
                            ),
                          ),
                          child: Row(
                            children: <Widget>[
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: const BoxDecoration(
                                  color: _SpendTokens.expenseRed,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.receipt_long_rounded,
                                  size: 18,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: <Widget>[
                                    Text(
                                      'Charge to Debt',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 13.5,
                                        color: _SpendTokens.expenseRed,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Record spend as unpaid debt without deducting from today\'s budget',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w500,
                                        color: tokens.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 4),
                              const Icon(
                                Icons.chevron_right_rounded,
                                size: 18,
                                color: _SpendTokens.expenseRed,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],

                  // Option 2: Add in Budget
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () {
                        Navigator.of(dialogContext).pop();
                        navigateToPlanner();
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: tokens.tint(_SpendTokens.budgetGold, 0.08),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _SpendTokens.budgetGold.withValues(alpha: 0.35),
                            width: 1.2,
                          ),
                        ),
                        child: Row(
                          children: <Widget>[
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: const BoxDecoration(
                                color: _SpendTokens.budgetGold,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.add_circle_outline_rounded,
                                size: 18,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  Text(
                                    'Add in Budget',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 13.5,
                                      color: _SpendTokens.budgetGold,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Go to Budget Planner to increase and reload your daily target',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500,
                                      color: tokens.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Icon(
                              Icons.chevron_right_rounded,
                              size: 18,
                              color: _SpendTokens.budgetGold,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: <Widget>[
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: tokens.textSecondary,
                    side: BorderSide(color: tokens.cardBorder),
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: Text(
                    'Cancel',
                    style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      );
      return;
    }

    // 3. Normal safe spend
    onProceed(isDebt: false);
  }

  @override
  Widget build(BuildContext context) {
    final BudgetBuddyState state = ref.watch(budgetBuddyControllerProvider);
    final BudgetSummary summary = widget.isTogetherOnly
        ? ref.watch(budgetTogetherSummaryProvider)
        : ref.watch(budgetSummaryProvider);
    final DateTime currentClock = state.effectiveDate;

    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final _SpendTokens tokens = _SpendTokens(isDark);

    final BudgetPeriodSummary dailySummary =
        summary.periodSummaries[BudgetPeriod.daily] ??
            const BudgetPeriodSummary(
              period: BudgetPeriod.daily,
              limit: 0,
              spent: 0,
            );

    final double currentBudget = widget.isTogetherOnly
        ? state.togetherBudget
        : (state.settings.dailyLimit ?? 0);
    final double currentSpent = dailySummary.spent;
    final double remaining = currentBudget - currentSpent;
    final bool hasBudget = currentBudget > 0;
    final bool isOver = hasBudget && remaining < 0;
    final bool isBudgetZero = currentBudget <= 0;
    final bool isBudgetReached = isBudgetZero || remaining <= 0;
    final double progressValue = currentBudget > 0
        ? (currentSpent / currentBudget).clamp(0.0, 1.0)
        : 0.0;

    final double totalPendingAmount =
        _pendingSpends.fold(0.0, (sum, item) => sum + item.amount);

    return Scaffold(
      backgroundColor: tokens.scaffoldBg,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: ConstrainedBox(
                constraints:
                    BoxConstraints(minHeight: constraints.maxHeight - 28),
                child: IntrinsicHeight(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      // Back Button if opened from Budget Together
                      if (widget.isTogetherOnly &&
                          Navigator.of(context).canPop()) ...<Widget>[
                        Align(
                          alignment: Alignment.centerLeft,
                          child: FilledButton.icon(
                            onPressed: () => Navigator.of(context).pop(),
                            icon: const Icon(Icons.arrow_back_rounded,
                                size: 15, color: Colors.white),
                            label: const Text('Back to Together'),
                            style: FilledButton.styleFrom(
                              backgroundColor: _SpendTokens.expenseRed,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 6),
                              visualDensity: VisualDensity.compact,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],

                      // 1. Header (Title + Active Budget Context)
                      _buildHeader(
                        context,
                        currentClock: currentClock,
                        remaining: remaining,
                        currentBudget: currentBudget,
                        currentSpent: currentSpent,
                        progressValue: progressValue,
                        isOver: isOver,
                        tokens: tokens,
                      ),
                      if (isBudgetReached) ...<Widget>[
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            color: isBudgetZero
                                ? _SpendTokens.budgetGold
                                : _SpendTokens.expenseRed,
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: <BoxShadow>[
                              BoxShadow(
                                color: (isBudgetZero
                                        ? _SpendTokens.budgetGold
                                        : _SpendTokens.expenseRed)
                                    .withValues(alpha: 0.25),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Row(
                            children: <Widget>[
                              Icon(
                                isBudgetZero
                                    ? Icons.info_outline_rounded
                                    : Icons.error_outline_rounded,
                                size: 18,
                                color: Colors.white,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  isBudgetZero
                                      ? 'Today\'s budget is ₱0. Add budget in plan to spend.'
                                      : 'Max budget reached! You can log as Debt or add in budget.',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                    height: 1.3,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              FilledButton(
                                onPressed: () {
                                  if (widget.isTogetherOnly) {
                                    Navigator.of(context).push(
                                      MaterialPageRoute<void>(
                                        builder: (_) =>
                                            const BudgetTogetherScreen(),
                                      ),
                                    );
                                  } else {
                                    Navigator.of(context).push(
                                      MaterialPageRoute<void>(
                                        builder: (_) =>
                                            const BudgetPlannerScreen(),
                                      ),
                                    );
                                  }
                                },
                                style: FilledButton.styleFrom(
                                  backgroundColor: Colors.white,
                                  foregroundColor: isBudgetZero
                                      ? _SpendTokens.budgetGold
                                      : _SpendTokens.expenseRed,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 7),
                                  minimumSize: Size.zero,
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  elevation: 0,
                                ),
                                child: Text(
                                  'Add in Budget',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 11.5,
                                    color: isBudgetZero
                                        ? _SpendTokens.budgetGold
                                        : _SpendTokens.expenseRed,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      // 2. Add Spend Form OR "+ Add Spend" Button
                      if (!_isAddingSpend) ...<Widget>[
                        const Spacer(),
                        Center(child: _buildAddSpendButton(tokens)),
                        const Spacer(),

                        // If there are pending spends in batch, show batch queue and action button to log
                        if (_pendingSpends.isNotEmpty) ...<Widget>[
                          _buildBatchQueueCard(
                            context,
                            totalPendingAmount: totalPendingAmount,
                            tokens: tokens,
                          ),
                          const SizedBox(height: 12),
                          _buildBatchSummaryActions(
                            context,
                            totalPendingAmount: totalPendingAmount,
                            tokens: tokens,
                          ),
                          const SizedBox(height: 14),
                        ],
                      ] else ...<Widget>[
                        const SizedBox(height: 12),
                        // Horizontal Category Selector Bar
                        _buildCategorySelectorBar(context, tokens),
                        const SizedBox(height: 12),

                        // Spend Input Card (Amount with device keyboard + Title + Add to Batch + Log Spend + Back)
                        _buildSpendInputCard(
                          context,
                          tokens: tokens,
                          totalPendingAmount: totalPendingAmount,
                        ),
                        const SizedBox(height: 10),

                        // Quick Amount Increments (+₱20, +₱50, +₱100, +₱200, +₱500)
                        _buildQuickAmountIncrements(tokens),
                        const SizedBox(height: 14),

                        // Batch Log Queue (if any already added)
                        if (_pendingSpends.isNotEmpty) ...<Widget>[
                          _buildBatchQueueCard(
                            context,
                            totalPendingAmount: totalPendingAmount,
                            tokens: tokens,
                          ),
                          const SizedBox(height: 14),
                        ],
                      ],
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  /// 1. Header with Title and Compact Budget Progress Strip
  Widget _buildHeader(
    BuildContext context, {
    required DateTime currentClock,
    required double remaining,
    required double currentBudget,
    required double currentSpent,
    required double progressValue,
    required bool isOver,
    required _SpendTokens tokens,
  }) {
    final String formattedDate =
        DateFormat('EEEE, MMM d').format(currentClock);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  widget.isTogetherOnly
                      ? 'Quick Spend (Together)'
                      : 'Quick Spend Log',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: tokens.textPrimary,
                    letterSpacing: -0.6,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  formattedDate,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: tokens.textSecondary,
                  ),
                ),
              ],
            ),
            SoftPill(
              text: currentBudget <= 0
                  ? 'No Budget Set'
                  : (remaining <= 0 ? 'Budget Reached' : 'Safe to Spend'),
              color: currentBudget <= 0
                  ? _SpendTokens.budgetGold
                  : (remaining <= 0
                      ? _SpendTokens.expenseRed
                      : _SpendTokens.safeGreen),
              icon: currentBudget <= 0
                  ? Icons.info_outline_rounded
                  : (remaining <= 0
                      ? Icons.block_rounded
                      : Icons.check_circle_outline_rounded),
              fontSize: 11,
            ),
          ],
        ),
        const SizedBox(height: 10),

        // Compact Budget Context Strip
        BentoCard(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          borderRadius: 16,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Text(
                    'Daily Balance Context',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: tokens.textSecondary,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    currentBudget <= 0
                        ? 'Unbudgeted'
                        : (remaining <= 0
                            ? 'Reached (₱0.00 left)'
                            : 'Left: ${formatPeso(remaining)}'),
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: currentBudget <= 0
                          ? _SpendTokens.budgetGold
                          : (remaining <= 0
                              ? _SpendTokens.expenseRed
                              : _SpendTokens.safeGreen),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              BentoHealthBar(
                progress: progressValue,
                color: isOver ? _SpendTokens.expenseRed : _SpendTokens.budgetGold,
                height: 5,
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// 2. Horizontal Category Selector Bar with Alpha-Tinted Icon Badges
  Widget _buildCategorySelectorBar(
    BuildContext context,
    _SpendTokens tokens,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.only(left: 2, bottom: 6),
          child: Text(
            'Category',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: tokens.textSecondary,
            ),
          ),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: <Widget>[
              // Custom category option in the first line
              _buildCustomCategoryOption(tokens),

              ..._spendCategories.map((_SpendCategoryOption category) {
                final bool isSelected =
                    !_isCustomCategory && _selectedCategory.title == category.title;

                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() {
                          _isCustomCategory = false;
                          _customCategoryFocusNode.unfocus();
                          _selectedCategory = category;
                        });
                      },
                      borderRadius: BorderRadius.circular(999),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 7),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? tokens.tint(category.color, 0.14)
                              : tokens.cardBg,
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: isSelected
                                ? category.color
                                : tokens.cardBorder,
                            width: isSelected ? 1.6 : 1.0,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            Container(
                              padding: const EdgeInsets.all(5),
                              decoration: BoxDecoration(
                                color: tokens.tint(category.color, 0.12),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                category.icon,
                                size: 13,
                                color: category.color,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              category.title,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 12,
                                fontWeight: isSelected
                                    ? FontWeight.w800
                                    : FontWeight.w600,
                                color: isSelected
                                    ? tokens.textPrimary
                                    : tokens.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ],
          ),
        ),
      ],
    );
  }

  /// Custom category option in the first line: chip when idle, input with cancel when selected
  Widget _buildCustomCategoryOption(_SpendTokens tokens) {
    if (_isCustomCategory) {
      return Padding(
        padding: const EdgeInsets.only(right: 8),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: tokens.tint(_SpendTokens.budgetGold, 0.12),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: _SpendTokens.budgetGold,
              width: 1.6,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Container(
                padding: const EdgeInsets.all(5),
                decoration: const BoxDecoration(
                  color: _SpendTokens.budgetGold,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.edit_note_rounded,
                  size: 13,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 135,
                child: TextField(
                  controller: _customCategoryController,
                  focusNode: _customCategoryFocusNode,
                  autofocus: true,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: tokens.textPrimary,
                  ),
                  decoration: InputDecoration(
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 2),
                    border: InputBorder.none,
                    hintText: 'Custom category...',
                    hintStyle: GoogleFonts.plusJakartaSans(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w500,
                      color: tokens.textMuted,
                    ),
                  ),
                  onChanged: (String val) {
                    setState(() {});
                  },
                ),
              ),
              const SizedBox(width: 4),
              // Cancel Button
              InkWell(
                onTap: () {
                  HapticFeedback.lightImpact();
                  setState(() {
                    _isCustomCategory = false;
                    _customCategoryController.clear();
                    _customCategoryFocusNode.unfocus();
                  });
                },
                borderRadius: BorderRadius.circular(999),
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: tokens.tint(_SpendTokens.expenseRed, 0.16),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.close_rounded,
                    size: 14,
                    color: _SpendTokens.expenseRed,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Default Unselected Custom Chip in First Position
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            HapticFeedback.selectionClick();
            setState(() {
              _isCustomCategory = true;
            });
            _customCategoryFocusNode.requestFocus();
          },
          borderRadius: BorderRadius.circular(999),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: tokens.cardBg,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: tokens.cardBorder,
                width: 1.0,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color: tokens.tint(_SpendTokens.budgetGold, 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.add_rounded,
                    size: 13,
                    color: _SpendTokens.budgetGold,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'Custom',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: tokens.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// First Button: Prominent "+ Add Spend" Button (Centered)
  Widget _buildAddSpendButton(_SpendTokens tokens) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(
            constraints: const BoxConstraints(maxWidth: 320),
            width: double.infinity,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: _SpendTokens.budgetGold.withValues(alpha: 0.22),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: FilledButton.icon(
              onPressed: () {
                setState(() {
                  _isAddingSpend = true;
                });
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  _amountFocusNode.requestFocus();
                });
              },
              icon: const Icon(Icons.add_circle_outline_rounded,
                  size: 20, color: Colors.white),
              label: Text(
                '+ Add Spend',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  letterSpacing: 0.2,
                ),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: _SpendTokens.budgetGold,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 0,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Record an expense or build a batch spend list',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: tokens.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  /// Batch Summary Actions (Shown below batch queue when not in adding mode)
  Widget _buildBatchSummaryActions(
    BuildContext context, {
    required double totalPendingAmount,
    required _SpendTokens tokens,
  }) {
    return Row(
      children: <Widget>[
        Expanded(
          child: FilledButton.icon(
            onPressed: () => _submitSpend(context),
            icon: const Icon(Icons.check_circle_rounded,
                size: 18, color: Colors.white),
            label: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                'Log Spend (${formatPeso(totalPendingAmount)})',
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                  color: Colors.white,
                ),
              ),
            ),
            style: FilledButton.styleFrom(
              backgroundColor: _SpendTokens.safeGreen,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              elevation: 0,
            ),
          ),
        ),
        const SizedBox(width: 8),
        OutlinedButton(
          onPressed: _clearQueue,
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            foregroundColor: _SpendTokens.expenseRed,
            side: const BorderSide(color: _SpendTokens.expenseRed, width: 1.2),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          child: const Icon(Icons.delete_sweep_rounded,
              size: 20, color: _SpendTokens.expenseRed),
        ),
      ],
    );
  }

  /// 3. Spend Input Card: Device Keyboard for Amount + Title of Spend + Action Buttons
  Widget _buildSpendInputCard(
    BuildContext context, {
    required _SpendTokens tokens,
    required double totalPendingAmount,
  }) {
    return BentoCard(
      padding: const EdgeInsets.all(16),
      borderRadius: 20,
      borderColor: _currentAmount > 0
          ? _SpendTokens.expenseRed.withValues(alpha: 0.35)
          : tokens.cardBorder,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // Top Row: Active Category indicator & Subtitle Description
          Row(
            children: <Widget>[
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: tokens.tint(_effectiveCategoryColor, 0.10),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _effectiveCategoryIcon,
                  size: 14,
                  color: _effectiveCategoryColor,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      _effectiveCategoryTitle,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: tokens.textPrimary,
                      ),
                    ),
                    Text(
                      'Enter amount, title, and description below',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: tokens.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Amount Input with Native Device Keyboard
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: tokens.subCardBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _currentAmount > 0
                    ? _SpendTokens.expenseRed.withValues(alpha: 0.35)
                    : tokens.cardBorder,
                width: 1.2,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: <Widget>[
                Text(
                  '₱',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    color: _SpendTokens.expenseRed,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _amountController,
                    focusNode: _amountFocusNode,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: <TextInputFormatter>[
                      FilteringTextInputFormatter.allow(
                          RegExp(r'^\d*\.?\d{0,2}')),
                    ],
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      color: _SpendTokens.expenseRed,
                      letterSpacing: -0.5,
                    ),
                    decoration: InputDecoration(
                      hintText: '0.00',
                      hintStyle: GoogleFonts.plusJakartaSans(
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        color: _SpendTokens.expenseRed.withValues(alpha: 0.3),
                      ),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                    onChanged: (String val) {
                      setState(() {});
                    },
                  ),
                ),
                if (_amountController.text.isNotEmpty)
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    icon: const Icon(
                      Icons.clear_rounded,
                      size: 20,
                      color: _SpendTokens.expenseRed,
                    ),
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      setState(() {
                        _amountController.clear();
                      });
                    },
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Title / Name of Spend Input Field
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: tokens.subCardBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: tokens.cardBorder, width: 1.0),
            ),
            child: Row(
              children: <Widget>[
                const Icon(
                  Icons.edit_rounded,
                  size: 16,
                  color: _SpendTokens.budgetGold,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _titleController,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: tokens.textPrimary,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Title / Name of spend (e.g. Lunch, Fare)...',
                      hintStyle: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: tokens.textMuted,
                      ),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // Description / Note Input Field
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: tokens.subCardBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: tokens.cardBorder, width: 1.0),
            ),
            child: Row(
              children: <Widget>[
                Icon(
                  Icons.notes_rounded,
                  size: 16,
                  color: tokens.textSecondary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _noteController,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: tokens.textPrimary,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Description (optional note or details)...',
                      hintStyle: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: tokens.textMuted,
                      ),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Action Buttons: Add to Batch & Log Spend placed close to Title / Name of Spend
          _buildActionButtons(
            context,
            totalPendingAmount: totalPendingAmount,
            tokens: tokens,
          ),
        ],
      ),
    );
  }

  /// Quick Amount Increments (+₱20, +₱50, +₱100, +₱200, +₱500)
  Widget _buildQuickAmountIncrements(_SpendTokens tokens) {
    const List<double> increments = <double>[20, 50, 100, 200, 500];

    return Row(
      children: increments.map((double amount) {
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => _onQuickAddAmount(amount),
                borderRadius: BorderRadius.circular(999),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  decoration: BoxDecoration(
                    color: tokens.cardBg,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: tokens.cardBorder, width: 1.0),
                  ),
                  child: Center(
                    child: Text(
                      '+₱${amount.toInt()}',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: _SpendTokens.budgetGold,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  /// 6. Batch Log Queue Card (Expandable list of pending spends)
  Widget _buildBatchQueueCard(
    BuildContext context, {
    required double totalPendingAmount,
    required _SpendTokens tokens,
  }) {
    return BentoCard(
      padding: const EdgeInsets.all(16),
      borderRadius: 18,
      borderColor: _SpendTokens.budgetGold.withValues(alpha: 0.35),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // Header Row
          Row(
            children: <Widget>[
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: tokens.tint(_SpendTokens.budgetGold, 0.10),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.receipt_long_rounded,
                  size: 16,
                  color: _SpendTokens.budgetGold,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Batch Queue (${_pendingSpends.length})',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: tokens.textPrimary,
                  ),
                ),
              ),
              Text(
                formatPeso(totalPendingAmount),
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  color: _SpendTokens.expenseRed,
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                icon: Icon(
                  _isQueueExpanded
                      ? Icons.expand_less_rounded
                      : Icons.expand_more_rounded,
                  color: tokens.textSecondary,
                ),
                onPressed: () {
                  setState(() {
                    _isQueueExpanded = !_isQueueExpanded;
                  });
                },
              ),
            ],
          ),

          // Items List
          if (_isQueueExpanded) ...<Widget>[
            const SizedBox(height: 12),
            ..._pendingSpends.map((_PendingSpendItem item) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: tokens.subCardBg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: tokens.cardBorder, width: 1.0),
                  ),
                  child: Row(
                    children: <Widget>[
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: tokens.tint(item.color, 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(item.icon, size: 14, color: item.color),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              item.title,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: tokens.textPrimary,
                              ),
                            ),
                            Row(
                              children: <Widget>[
                                Flexible(
                                  child: Text(
                                    item.categoryName.isNotEmpty
                                        ? item.categoryName
                                        : item.category.label,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500,
                                      color: tokens.textSecondary,
                                    ),
                                  ),
                                ),
                                if (item.isDebt) ...<Widget>[
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 5, vertical: 1),
                                    decoration: BoxDecoration(
                                      color: tokens.tint(_SpendTokens.expenseRed, 0.14),
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(
                                          color: _SpendTokens.expenseRed
                                              .withValues(alpha: 0.3)),
                                    ),
                                    child: Text(
                                      'Debt',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 9.5,
                                        fontWeight: FontWeight.w800,
                                        color: _SpendTokens.expenseRed,
                                      ),
                                    ),
                                  ),
                                ],
                                if (item.note.isNotEmpty && (!item.isDebt || item.note != 'Charged to Debt')) ...<Widget>[
                                  const SizedBox(width: 6),
                                  Flexible(
                                    child: Text(
                                      '• ${item.note.replaceAll('(Charged to Debt)', '').trim()}',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.w500,
                                        color: tokens.textMuted,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                      Text(
                        formatPeso(item.amount),
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: _SpendTokens.expenseRed,
                        ),
                      ),
                      const SizedBox(width: 8),
                      InkWell(
                        onTap: () => _removeFromQueue(item.id),
                        borderRadius: BorderRadius.circular(6),
                        child: Padding(
                          padding: const EdgeInsets.all(4),
                          child: Icon(
                            Icons.close_rounded,
                            size: 16,
                            color: tokens.textMuted,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ],
        ],
      ),
    );
  }

  /// Action Buttons (Add to Batch & Log Spend & Done to collapse)
  Widget _buildActionButtons(
    BuildContext context, {
    required double totalPendingAmount,
    required _SpendTokens tokens,
  }) {
    final double finalAmountToSubmit =
        totalPendingAmount + (_currentAmount > 0 ? _currentAmount : 0);

    return Column(
      children: <Widget>[
        Row(
          children: <Widget>[
            // Add to Batch Button (Solid Gold #D97706)
            Expanded(
              child: FilledButton.icon(
                onPressed: _addToQueue,
                icon: const Icon(Icons.playlist_add_rounded,
                    size: 16, color: Colors.white),
                label: Text(
                  _pendingSpends.isEmpty
                      ? 'Add to Batch'
                      : 'Add to Batch (${_pendingSpends.length})',
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w800,
                    fontSize: 12.5,
                    color: Colors.white,
                  ),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: _SpendTokens.budgetGold,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 0,
                ),
              ),
            ),
            const SizedBox(width: 8),

            // Log Spend Button (Solid Dark Green #0F766E)
            Expanded(
              child: FilledButton.icon(
                onPressed: () => _submitSpend(context),
                icon: const Icon(Icons.check_circle_rounded,
                    size: 16, color: Colors.white),
                label: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    finalAmountToSubmit > 0
                        ? 'Log Spend (${formatPeso(finalAmountToSubmit)})'
                        : 'Log Spend',
                    style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.w800,
                      fontSize: 12.5,
                      color: Colors.white,
                    ),
                  ),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: _SpendTokens.safeGreen,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 0,
                ),
              ),
            ),

            if (_pendingSpends.isNotEmpty) ...<Widget>[
              const SizedBox(width: 8),
              OutlinedButton(
                onPressed: _clearQueue,
                style: OutlinedButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 13),
                  foregroundColor: _SpendTokens.expenseRed,
                  side: const BorderSide(
                      color: _SpendTokens.expenseRed, width: 1.2),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Icon(Icons.delete_sweep_rounded,
                    size: 18, color: _SpendTokens.expenseRed),
              ),
            ],
          ],
        ),
        const SizedBox(height: 8),

        // Back button to go back to "+ Add Spend" button (Solid Red)
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: () {
              FocusScope.of(context).unfocus();
              setState(() {
                _isAddingSpend = false;
              });
            },
            icon: const Icon(Icons.arrow_back_rounded,
                size: 16, color: Colors.white),
            label: Text(
              _pendingSpends.isNotEmpty
                  ? 'Back (Keep ${_pendingSpends.length} Batch ${_pendingSpends.length == 1 ? 'Item' : 'Items'})'
                  : 'Back',
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.w800,
                fontSize: 12.5,
                color: Colors.white,
              ),
            ),
            style: FilledButton.styleFrom(
              backgroundColor: _SpendTokens.expenseRed,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 0,
            ),
          ),
        ),
      ],
    );
  }
}





