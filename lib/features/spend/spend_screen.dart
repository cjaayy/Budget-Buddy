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
  });

  final String id;
  final String title;
  final double amount;
  final BudgetCategory category;
  final Color color;
  final IconData icon;
  final String note;
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

  // Numeric Keypad & Input State
  String _rawInput = '';
  _SpendCategoryOption _selectedCategory = _spendCategories.first;
  final TextEditingController _noteController = TextEditingController();
  bool _isQueueExpanded = true;

  @override
  void initState() {
    super.initState();
    _selectedCategory = _spendCategories.first;
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  double get _currentAmount => double.tryParse(_rawInput) ?? 0.0;

  String _displayAmount() {
    if (_rawInput.isEmpty) return '0.00';
    if (_rawInput.contains('.')) {
      final List<String> parts = _rawInput.split('.');
      final double whole = double.tryParse(parts[0]) ?? 0;
      final String wholeFormatted = NumberFormat('#,##0').format(whole);
      return '$wholeFormatted.${parts[1]}';
    } else {
      final double whole = double.tryParse(_rawInput) ?? 0;
      return NumberFormat('#,##0').format(whole);
    }
  }

  void _onKeypadTap(String value) {
    HapticFeedback.lightImpact();
    setState(() {
      if (value == '.') {
        if (_rawInput.isEmpty) {
          _rawInput = '0.';
        } else if (!_rawInput.contains('.')) {
          _rawInput += '.';
        }
      } else if (value == '00') {
        if (_rawInput.isEmpty || _rawInput == '0') {
          return;
        }
        if (_rawInput.contains('.')) {
          final List<String> parts = _rawInput.split('.');
          if (parts[1].isEmpty) {
            _rawInput += '00';
          } else if (parts[1].length == 1) {
            _rawInput += '0';
          }
        } else {
          if (_rawInput.length <= 8) {
            _rawInput += '00';
          }
        }
      } else {
        // Digits 0-9
        if (_rawInput == '0') {
          _rawInput = value;
        } else if (_rawInput.contains('.')) {
          final List<String> parts = _rawInput.split('.');
          if (parts[1].length < 2) {
            _rawInput += value;
          }
        } else {
          if (_rawInput.length < 9) {
            _rawInput += value;
          }
        }
      }
    });
  }

  void _onBackspace() {
    HapticFeedback.lightImpact();
    setState(() {
      if (_rawInput.isNotEmpty) {
        _rawInput = _rawInput.substring(0, _rawInput.length - 1);
      }
    });
  }

  void _onClear() {
    HapticFeedback.mediumImpact();
    setState(() {
      _rawInput = '';
      _noteController.clear();
    });
  }

  void _onQuickAddAmount(double addAmount) {
    HapticFeedback.lightImpact();
    setState(() {
      final double next = _currentAmount + addAmount;
      _rawInput =
          next % 1 == 0 ? next.toInt().toString() : next.toStringAsFixed(2);
    });
  }

  void _addToQueue() {
    if (!_ensureBudgetSet(context)) return;

    if (_currentAmount <= 0) {
      showAppAlert(context, message: 'Please enter an expense amount greater than ₱0.', title: 'Notice', icon: Icons.info_outline_rounded,

      );
      return;
    }

    HapticFeedback.mediumImpact();
    final String title = _selectedCategory.title;
    final String note = _noteController.text.trim();

    setState(() {
      _pendingSpends.add(
        _PendingSpendItem(
          id: '${DateTime.now().microsecondsSinceEpoch}_${_pendingSpends.length}',
          title: title,
          amount: _currentAmount,
          category: _selectedCategory.budgetCategory,
          color: _selectedCategory.color,
          icon: _selectedCategory.icon,
          note: note,
        ),
      );
      _rawInput = '';
      _noteController.clear();
      _isQueueExpanded = true;
    });

    showAppAlert(context,
      message: 'Added to batch queue (${formatPeso(_currentAmount)})',
      title: 'Notice',
      icon: Icons.info_outline_rounded,
      accentColor: _SpendTokens.budgetGold,
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
    if (!_ensureBudgetSet(context)) return;

    final controller = ref.read(budgetBuddyControllerProvider.notifier);
    final DateTime now = controller.now;

    // If there is currently typed amount in the input, auto-include it
    if (_currentAmount > 0) {
      _pendingSpends.add(
        _PendingSpendItem(
          id: '${DateTime.now().microsecondsSinceEpoch}_${_pendingSpends.length}',
          title: _selectedCategory.title,
          amount: _currentAmount,
          category: _selectedCategory.budgetCategory,
          color: _selectedCategory.color,
          icon: _selectedCategory.icon,
          note: _noteController.text.trim(),
        ),
      );
      _rawInput = '';
      _noteController.clear();
    }

    if (_pendingSpends.isEmpty) {
      showAppAlert(context, message: 'Enter an amount or add items to queue first.', title: 'Notice', icon: Icons.info_outline_rounded,

      );
      return;
    }

    HapticFeedback.heavyImpact();
    final int count = _pendingSpends.length;
    double total = 0;

    for (final _PendingSpendItem item in _pendingSpends) {
      total += item.amount;
      controller.addExpense(
        title: item.title,
        amount: item.amount,
        category: item.category,
        note: _stripSpendTag(item.note),
        dateTime: now,
        source: widget.isTogetherOnly ? 'togetherSpend' : 'manual',
        spendCategory: item.title,
      );
    }

    setState(() {
      _pendingSpends.clear();
    });

    final BudgetSummary summary = widget.isTogetherOnly
        ? ref.read(budgetTogetherSummaryProvider)
        : ref.read(budgetSummaryProvider);
    final BudgetPeriodSummary? daySummary =
        summary.periodSummaries[BudgetPeriod.daily];
    final String suffix = daySummary == null || !daySummary.isActive
        ? ''
        : ' • Left: ${formatPeso(daySummary.remaining)}';

    showAppAlert(context,
      message: '$count ${count == 1 ? 'spend' : 'spends'} logged (${formatPeso(total)})$suffix',
      title: 'Success',
      icon: Icons.check_circle_outline_rounded,
      accentColor: _SpendTokens.safeGreen,
    );
  }

  String _stripSpendTag(String note) {
    return note.replaceAll(_spendTag, '').trim();
  }

  bool _ensureBudgetSet(BuildContext context) {
    final BudgetBuddyState state = ref.read(budgetBuddyControllerProvider);
    final bool hasBudget = widget.isTogetherOnly
        ? state.togetherBudget > 0
        : state.settings.totalDailyBudget > 0;

    if (!hasBudget) {
      showDialog<void>(
        context: context,
        builder: (BuildContext dialogContext) {
          final bool isDark = Theme.of(context).brightness == Brightness.dark;
          final _SpendTokens tokens = _SpendTokens(isDark);

          return AlertDialog(
            backgroundColor: tokens.cardBg,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
              side: BorderSide(color: tokens.cardBorder, width: 1.0),
            ),
            titlePadding: const EdgeInsets.fromLTRB(18, 18, 18, 6),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
            actionsPadding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
            icon: const Icon(
              Icons.warning_amber_rounded,
              color: _SpendTokens.expenseRed,
              size: 40,
            ),
            title: Text(
              widget.isTogetherOnly
                  ? 'Budget Together Required'
                  : 'Today\'s Budget Required',
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.w800,
                fontSize: 16,
                color: tokens.textPrimary,
              ),
            ),
            content: Text(
              widget.isTogetherOnly
                  ? 'You cannot log expenses until you set a Budget Together amount. Please set a budget first.'
                  : 'You cannot log expenses until you set today\'s budget. Please set a budget first.',
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: tokens.textSecondary,
              ),
            ),
            actions: <Widget>[
              FilledButton.icon(
                onPressed: () => Navigator.of(dialogContext).pop(),
                icon: const Icon(Icons.arrow_back_rounded,
                    size: 14, color: Colors.white),
                label: Text(
                  'Back',
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    fontSize: 12,
                  ),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: _SpendTokens.expenseRed,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
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
                style: FilledButton.styleFrom(
                  backgroundColor: _SpendTokens.safeGreen,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: Text(
                  'Set Budget',
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
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
    final BudgetSummary summary = widget.isTogetherOnly
        ? ref.watch(budgetTogetherSummaryProvider)
        : ref.watch(budgetSummaryProvider);
    final DateTime currentClock =
        ref.read(budgetBuddyControllerProvider.notifier).currentEffectiveTime;

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
    final bool isOver = remaining < 0;
    final double progressValue = currentBudget > 0
        ? (currentSpent / currentBudget).clamp(0.0, 1.0)
        : 0.0;

    final double totalPendingAmount =
        _pendingSpends.fold(0.0, (sum, item) => sum + item.amount);

    return Scaffold(
      backgroundColor: tokens.scaffoldBg,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          children: <Widget>[
            // Back Button if opened from Budget Together
            if (widget.isTogetherOnly && Navigator.of(context).canPop()) ...<Widget>[
              Align(
                alignment: Alignment.centerLeft,
                child: FilledButton.icon(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.arrow_back_rounded,
                      size: 15, color: Colors.white),
                  label: const Text('Back'),
                  style: FilledButton.styleFrom(
                    backgroundColor: _SpendTokens.safeGreen,
                    foregroundColor: Colors.white,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
            const SizedBox(height: 12),

            // 2. Horizontal Category Selector Bar
            _buildCategorySelectorBar(context, tokens),
            const SizedBox(height: 12),

            // 3. Hero Amount Input Card (Large ₱0.00 in Dark Red + Backspace + Note)
            _buildHeroAmountCard(context, tokens),
            const SizedBox(height: 10),

            // 4. Quick Amount Increments (+₱20, +₱50, +₱100, +₱500)
            _buildQuickAmountIncrements(tokens),
            const SizedBox(height: 12),

            // 5. Custom Flat Numeric Keypad (4x3 + Action Row)
            _buildNumericKeypad(context, tokens),
            const SizedBox(height: 12),

            // 6. Batch Log Queue (Expandable Card)
            if (_pendingSpends.isNotEmpty) ...<Widget>[
              _buildBatchQueueCard(
                context,
                totalPendingAmount: totalPendingAmount,
                tokens: tokens,
              ),
              const SizedBox(height: 14),
            ],

            // 7. Bottom Main Action Buttons (Confirm / Submit & Clear)
            _buildBottomActionButtons(
              context,
              totalPendingAmount: totalPendingAmount,
              tokens: tokens,
            ),
            const SizedBox(height: 20),
          ],
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
              text: isOver ? 'Budget Over' : 'Safe to Spend',
              color: isOver ? _SpendTokens.expenseRed : _SpendTokens.safeGreen,
              icon: isOver
                  ? Icons.warning_amber_rounded
                  : Icons.check_circle_outline_rounded,
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
                    'Left: ${(isOver ? "-" : "") + formatPeso(remaining.abs())}',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: isOver
                          ? _SpendTokens.expenseRed
                          : _SpendTokens.safeGreen,
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
            children: _spendCategories.map((_SpendCategoryOption category) {
              final bool isSelected =
                  _selectedCategory.title == category.title;

              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() {
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
            }).toList(),
          ),
        ),
      ],
    );
  }

  /// 3. Hero Amount Input Card: Large Bold ₱0.00 Display in Dark Red + Backspace + Note
  Widget _buildHeroAmountCard(BuildContext context, _SpendTokens tokens) {
    return BentoCard(
      padding: const EdgeInsets.all(16),
      borderRadius: 20,
      borderColor: _currentAmount > 0
          ? _SpendTokens.expenseRed.withValues(alpha: 0.35)
          : tokens.cardBorder,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // Top Row: Active Category indicator & Backspace icon
          Row(
            children: <Widget>[
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: tokens.tint(_selectedCategory.color, 0.10),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _selectedCategory.icon,
                  size: 14,
                  color: _selectedCategory.color,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _selectedCategory.title,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: tokens.textPrimary,
                  ),
                ),
              ),
              // Integrated Backspace Button
              if (_rawInput.isNotEmpty)
                IconButton(
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  icon: const Icon(
                    Icons.backspace_outlined,
                    size: 20,
                    color: _SpendTokens.expenseRed,
                  ),
                  onPressed: _onBackspace,
                ),
            ],
          ),
          const SizedBox(height: 10),

          // Large Bold Financial Amount in Dark Red (#991B1B)
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              '₱${_displayAmount()}',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 36,
                fontWeight: FontWeight.w900,
                color: _SpendTokens.expenseRed,
                letterSpacing: -1.0,
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Description / Quick Note Input Field
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
                  Icons.edit_note_rounded,
                  size: 18,
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
                      hintText: 'Add note (e.g. Lunch with team, fare)...',
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
        ],
      ),
    );
  }

  /// 4. Quick Amount Increments (+₱20, +₱50, +₱100, +₱500)
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

  /// 5. Custom Flat Numeric Keypad (Tactile Bento Keypad Tiles)
  Widget _buildNumericKeypad(BuildContext context, _SpendTokens tokens) {
    return Column(
      children: <Widget>[
        // Row 1: 1, 2, 3
        Row(
          children: <Widget>[
            _buildKeyTile('1', tokens),
            const SizedBox(width: 8),
            _buildKeyTile('2', tokens),
            const SizedBox(width: 8),
            _buildKeyTile('3', tokens),
          ],
        ),
        const SizedBox(height: 8),

        // Row 2: 4, 5, 6
        Row(
          children: <Widget>[
            _buildKeyTile('4', tokens),
            const SizedBox(width: 8),
            _buildKeyTile('5', tokens),
            const SizedBox(width: 8),
            _buildKeyTile('6', tokens),
          ],
        ),
        const SizedBox(height: 8),

        // Row 3: 7, 8, 9
        Row(
          children: <Widget>[
            _buildKeyTile('7', tokens),
            const SizedBox(width: 8),
            _buildKeyTile('8', tokens),
            const SizedBox(width: 8),
            _buildKeyTile('9', tokens),
          ],
        ),
        const SizedBox(height: 8),

        // Row 4: . , 0 , 00
        Row(
          children: <Widget>[
            _buildKeyTile('.', tokens),
            const SizedBox(width: 8),
            _buildKeyTile('0', tokens),
            const SizedBox(width: 8),
            _buildKeyTile('00', tokens),
          ],
        ),
        const SizedBox(height: 8),

        // Row 5: Clear, Backspace, and + Add to Queue
        Row(
          children: <Widget>[
            // Clear Key (C)
            Expanded(
              flex: 1,
              child: _buildActionKeyTile(
                label: 'C',
                color: _SpendTokens.expenseRed,
                onTap: _onClear,
                tokens: tokens,
              ),
            ),
            const SizedBox(width: 8),
            // Backspace Key
            Expanded(
              flex: 1,
              child: _buildActionKeyTile(
                icon: Icons.backspace_outlined,
                color: tokens.textSecondary,
                onTap: _onBackspace,
                tokens: tokens,
              ),
            ),
            const SizedBox(width: 8),
            // + Add to Queue Button
            Expanded(
              flex: 2,
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: _addToQueue,
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    height: 52,
                    decoration: BoxDecoration(
                      color: tokens.tint(_SpendTokens.budgetGold, 0.12),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: _SpendTokens.budgetGold.withValues(alpha: 0.35),
                        width: 1.2,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        const Icon(
                          Icons.playlist_add_rounded,
                          size: 18,
                          color: _SpendTokens.budgetGold,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '+ Add to Batch',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: _SpendTokens.budgetGold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildKeyTile(String value, _SpendTokens tokens) {
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _onKeypadTap(value),
          borderRadius: BorderRadius.circular(16),
          child: Container(
            height: 52,
            decoration: BoxDecoration(
              color: tokens.keyTileBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: tokens.cardBorder, width: 1.0),
            ),
            child: Center(
              child: Text(
                value,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: tokens.textPrimary,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionKeyTile({
    String? label,
    IconData? icon,
    required Color color,
    required VoidCallback onTap,
    required _SpendTokens tokens,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          height: 52,
          decoration: BoxDecoration(
            color: tokens.cardBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: tokens.cardBorder, width: 1.0),
          ),
          child: Center(
            child: icon != null
                ? Icon(icon, size: 20, color: color)
                : Text(
                    label ?? '',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: color,
                    ),
                  ),
          ),
        ),
      ),
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
                            if (item.note.isNotEmpty)
                              Text(
                                item.note,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                  color: tokens.textSecondary,
                                ),
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

  /// 7. Bottom Main Action Buttons (Confirm / Submit Spend & Clear)
  Widget _buildBottomActionButtons(
    BuildContext context, {
    required double totalPendingAmount,
    required _SpendTokens tokens,
  }) {
    final double finalAmountToSubmit =
        totalPendingAmount + (_currentAmount > 0 ? _currentAmount : 0);

    return Row(
      children: <Widget>[
        // Clear Batch / Reset Button
        if (_pendingSpends.isNotEmpty) ...<Widget>[
          OutlinedButton(
            onPressed: _clearQueue,
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(90, 48),
              foregroundColor: _SpendTokens.expenseRed,
              side: const BorderSide(color: _SpendTokens.expenseRed, width: 1.2),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: Text(
              'Clear All',
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.w700,
                fontSize: 13,
                color: _SpendTokens.expenseRed,
              ),
            ),
          ),
          const SizedBox(width: 10),
        ],

        // Confirm / Submit Spend Button (Solid Dark Green #0F766E)
        Expanded(
          child: FilledButton.icon(
            onPressed: () => _submitSpend(context),
            icon: const Icon(Icons.check_circle_rounded, size: 18),
            label: Text(
              finalAmountToSubmit > 0
                  ? 'Log Spend (${formatPeso(finalAmountToSubmit)})'
                  : 'Log Spend',
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.w800,
                fontSize: 14,
                color: Colors.white,
              ),
            ),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
              backgroundColor: _SpendTokens.safeGreen,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ),
      ],
    );
  }
}





