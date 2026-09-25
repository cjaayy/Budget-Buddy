import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../core/models/budget_models.dart';
import '../../core/state/app_controller.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/budget_cards.dart';
import 'package:budgetbuddy/core/utils/alert_dialog.dart';

/// Clean Modern Bento Tokens for Budget Together Screen matching Today's Budget Planner.
class _TogetherBudgetTokens {
  const _TogetherBudgetTokens(this.isDark);

  final bool isDark;

  // Primary 3-Color Strict Palette
  static const Color budgetGold = Color(0xFFD97706);
  static const Color safeGreen = Color(0xFF0F766E);
  static const Color expenseRed = Color(0xFF991B1B);

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
      isDark ? const Color(0xFF161F31) : const Color(0xFFF1F5F9);

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

class BudgetTogetherScreen extends ConsumerStatefulWidget {
  const BudgetTogetherScreen({super.key});

  @override
  ConsumerState<BudgetTogetherScreen> createState() =>
      _BudgetTogetherScreenState();
}

class _BudgetTogetherScreenState extends ConsumerState<BudgetTogetherScreen> {
  late final TextEditingController _dailyController;
  final FocusNode _focusNode = FocusNode();
  bool _isInputActive = false;
  bool _isAddMode = false;

  @override
  void initState() {
    super.initState();
    _dailyController = TextEditingController();
  }

  @override
  void dispose() {
    _dailyController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onQuickAddAmount(double amount) {
    HapticFeedback.lightImpact();
    setState(() {
      _isInputActive = true;
      final bool isAllSelected = _dailyController.selection.start == 0 &&
          _dailyController.selection.end == _dailyController.text.length &&
          _dailyController.text.isNotEmpty;

      double nextAmount;
      if (isAllSelected) {
        nextAmount = amount;
      } else {
        final double currentVal =
            double.tryParse(_dailyController.text.replaceAll('+', '').trim()) ??
                0.0;
        nextAmount = currentVal + amount;
      }
      _dailyController.text = nextAmount == nextAmount.roundToDouble()
          ? nextAmount.toStringAsFixed(0)
          : nextAmount.toStringAsFixed(2);
      _dailyController.selection = TextSelection.collapsed(
        offset: _dailyController.text.length,
      );
    });
    _focusNode.requestFocus();
  }

  void _startAddBudget() {
    HapticFeedback.lightImpact();
    setState(() {
      _isInputActive = true;
      _isAddMode = true;
      _dailyController.clear();
    });
    _focusNode.requestFocus();
  }

  void _startEditBudget(double currentBudget) {
    HapticFeedback.lightImpact();
    setState(() {
      _isInputActive = true;
      _isAddMode = false;
      _dailyController.text =
          currentBudget > 0 ? currentBudget.toStringAsFixed(0) : '';
      _dailyController.selection = TextSelection(
        baseOffset: 0,
        extentOffset: _dailyController.text.length,
      );
    });
    _focusNode.requestFocus();
  }

  void _cancelInput() {
    HapticFeedback.lightImpact();
    _focusNode.unfocus();
    setState(() {
      _isInputActive = false;
      _isAddMode = false;
      _dailyController.clear();
    });
  }

  void _saveBudget() {
    final String text = _dailyController.text.trim();
    final double? entered = double.tryParse(text);
    if (entered == null || entered <= 0) {
      showAppAlert(
        context,
        message: 'Please enter a valid budget amount greater than ₱0.',
        title: 'Notice',
        icon: Icons.info_outline_rounded,
      );
      return;
    }

    final BudgetBuddyState state = ref.read(budgetBuddyControllerProvider);
    final double currentBudget = state.togetherBudget;
    final double target = _isAddMode ? (currentBudget + entered) : entered;

    _focusNode.unfocus();
    ref
        .read(budgetBuddyControllerProvider.notifier)
        .setTogetherBudget(target);

    setState(() {
      _isInputActive = false;
      _isAddMode = false;
      _dailyController.clear();
    });

    showAppAlert(
      context,
      message: _isAddMode
          ? 'Budget Together increased to ${formatPeso(target)}!'
          : 'Budget Together set to ${formatPeso(target)}!',
      title: 'Success',
      icon: Icons.check_circle_outline_rounded,
      accentColor: _TogetherBudgetTokens.safeGreen,
    );
  }

  Future<void> _resetBudget() async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          icon: const Icon(Icons.restart_alt_rounded,
              color: _TogetherBudgetTokens.expenseRed, size: 36),
          title: const Text('Reset Tab Budget',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
          content: const Text(
            'This will clear the Budget Together tab budget back to ₱0.',
            textAlign: TextAlign.center,
          ),
          actions: <Widget>[
            FilledButton.icon(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              icon: const Icon(Icons.close_rounded, size: 14),
              label: const Text('Cancel'),
              style: FilledButton.styleFrom(
                backgroundColor: Colors.grey.shade600,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            FilledButton.icon(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              icon: const Icon(Icons.delete_outline_rounded, size: 14),
              label: const Text('Reset'),
              style: FilledButton.styleFrom(
                backgroundColor: _TogetherBudgetTokens.expenseRed,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ],
        );
      },
    );

    if (!mounted || confirmed != true) return;

    setState(() {
      _isInputActive = false;
      _isAddMode = false;
      _dailyController.clear();
    });
    ref.read(budgetBuddyControllerProvider.notifier).setTogetherBudget(0);

    showAppAlert(
      context,
      message: 'Budget Together has been reset to ₱0.',
      title: 'Alert',
      icon: Icons.warning_amber_rounded,
      accentColor: _TogetherBudgetTokens.expenseRed,
    );
  }

  @override
  Widget build(BuildContext context) {
    final BudgetBuddyState state = ref.watch(budgetBuddyControllerProvider);
    final DateTime currentClock = state.effectiveDate;
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final _TogetherBudgetTokens tokens = _TogetherBudgetTokens(isDark);

    final double currentBudget = state.togetherBudget;
    final double currentSpent = state.expenses
        .where((ExpenseEntry e) =>
            e.source == 'togetherSpend' &&
            DateUtils.isSameDay(e.dateTime, currentClock))
        .fold<double>(0.0, (double sum, ExpenseEntry e) => sum + e.amount);
    final double remaining = currentBudget - currentSpent;
    final bool hasBudget = currentBudget > 0;
    final bool isOver = hasBudget && remaining < 0;
    final bool isWarning =
        !isOver && hasBudget && currentSpent >= (currentBudget * 0.8);
    final double progressValue = currentBudget > 0
        ? (currentSpent / currentBudget).clamp(0.0, 1.0)
        : 0.0;

    // Listen to external changes
    ref.listen<BudgetBuddyState>(budgetBuddyControllerProvider,
        (BudgetBuddyState? prev, BudgetBuddyState next) {
      if (next.togetherBudget != prev?.togetherBudget) {
        if (next.togetherBudget <= 0) {
          if (_dailyController.text.isNotEmpty || _isInputActive) {
            setState(() {
              _isInputActive = false;
              _isAddMode = false;
              _dailyController.clear();
            });
          }
        }
      }
    });

    return Scaffold(
      backgroundColor: tokens.scaffoldBg,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          children: <Widget>[
            // Back Button (When opened from Together Hub)
            if (Navigator.of(context).canPop()) ...<Widget>[
              Align(
                alignment: Alignment.centerLeft,
                child: FilledButton.icon(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.arrow_back_rounded,
                      size: 15, color: Colors.white),
                  label: const Text('Back'),
                  style: FilledButton.styleFrom(
                    backgroundColor: _TogetherBudgetTokens.safeGreen,
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

            // 1. Header (Title + Date + Pill)
            _buildHeader(
              context,
              currentClock: currentClock,
              hasBudget: hasBudget,
              tokens: tokens,
            ),
            const SizedBox(height: 12),

            // 2. Hero Budget Card (Remaining as hero display, no duplicate cards)
            _buildHeroBudgetCard(
              context,
              currentBudget: currentBudget,
              currentSpent: currentSpent,
              remaining: remaining,
              progressValue: progressValue,
              hasBudget: hasBudget,
              isOver: isOver,
              isWarning: isWarning,
              tokens: tokens,
            ),
            const SizedBox(height: 12),

            // 3. Action Buttons (Cancel / Save when typing; Add, Edit, Reset when idle)
            _buildActionButtons(
              context,
              currentBudget: currentBudget,
              hasBudget: hasBudget,
              tokens: tokens,
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  /// 1. Header Section with Title, Formatted Date, and Clean Setup/Target Pill
  Widget _buildHeader(
    BuildContext context, {
    required DateTime currentClock,
    required bool hasBudget,
    required _TogetherBudgetTokens tokens,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Set Budget Together',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: tokens.textPrimary,
                letterSpacing: -0.6,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              DateFormat('EEEE, MMM d').format(currentClock),
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: tokens.textSecondary,
              ),
            ),
          ],
        ),
        SoftPill(
          text: hasBudget ? 'Active Tab' : 'Setup',
          color: hasBudget
              ? _TogetherBudgetTokens.budgetGold
              : _TogetherBudgetTokens.safeGreen,
          icon: hasBudget ? Icons.lock_outline_rounded : Icons.edit_rounded,
          fontSize: 11,
        ),
      ],
    );
  }

  /// 2. Hero Budget Card: Shows Safe Remaining when idle, typed input when active, with no duplicate cards
  Widget _buildHeroBudgetCard(
    BuildContext context, {
    required double currentBudget,
    required double currentSpent,
    required double remaining,
    required double progressValue,
    required bool hasBudget,
    required bool isOver,
    required bool isWarning,
    required _TogetherBudgetTokens tokens,
  }) {
    final bool isTyping = _isInputActive;

    return BentoCard(
      padding: const EdgeInsets.all(16),
      borderRadius: 20,
      borderColor: isOver
          ? _TogetherBudgetTokens.expenseRed.withValues(alpha: 0.35)
          : (isTyping
              ? _TogetherBudgetTokens.budgetGold.withValues(alpha: 0.45)
              : tokens.cardBorder),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // Top Row: Category / Target Header & Status Pill
          Row(
            children: <Widget>[
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: tokens.tint(_TogetherBudgetTokens.budgetGold, 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.group_rounded,
                  size: 15,
                  color: _TogetherBudgetTokens.budgetGold,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  isTyping
                      ? (_isAddMode
                          ? 'Add to Budget Together'
                          : 'Edit Budget Together Target')
                      : 'Budget Together Tab',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: tokens.textPrimary,
                  ),
                ),
              ),
              SoftPill(
                text: isTyping
                    ? (_isAddMode ? 'Adding' : 'Editing')
                    : (!hasBudget
                        ? 'No Budget Set'
                        : (isOver
                            ? 'Over Budget'
                            : (isWarning ? '80% Cap' : 'Active Tab'))),
                color: isTyping
                    ? _TogetherBudgetTokens.budgetGold
                    : (!hasBudget
                        ? _TogetherBudgetTokens.budgetGold
                        : (isOver
                            ? _TogetherBudgetTokens.expenseRed
                            : (isWarning
                                ? _TogetherBudgetTokens.budgetGold
                                : _TogetherBudgetTokens.safeGreen))),
                icon: isTyping
                    ? Icons.edit_rounded
                    : (!hasBudget
                        ? Icons.info_outline_rounded
                        : (isOver
                            ? Icons.warning_amber_rounded
                            : (isWarning
                                ? Icons.info_outline_rounded
                                : Icons.check_circle_outline_rounded))),
                fontSize: 11,
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Main Hero Amount Display: Shows Remaining when idle, or TextField when active
          if (isTyping)
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: <Widget>[
                Expanded(
                  child: TextField(
                    controller: _dailyController,
                    focusNode: _focusNode,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: <TextInputFormatter>[
                      FilteringTextInputFormatter.allow(
                          RegExp(r'^\d*\.?\d{0,2}')),
                    ],
                    autofocus: true,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 34,
                      fontWeight: FontWeight.w900,
                      color: _TogetherBudgetTokens.budgetGold,
                      letterSpacing: -0.8,
                    ),
                    decoration: InputDecoration(
                      prefixText: '₱ ',
                      prefixStyle: GoogleFonts.plusJakartaSans(
                        fontSize: 34,
                        fontWeight: FontWeight.w900,
                        color: _TogetherBudgetTokens.budgetGold,
                        letterSpacing: -0.8,
                      ),
                      hintText: '0.00',
                      hintStyle: GoogleFonts.plusJakartaSans(
                        fontSize: 34,
                        fontWeight: FontWeight.w900,
                        color: _TogetherBudgetTokens.budgetGold
                            .withValues(alpha: 0.35),
                        letterSpacing: -0.8,
                      ),
                      isDense: true,
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                    ),
                    onChanged: (_) => setState(() {}),
                    onSubmitted: (_) => _saveBudget(),
                  ),
                ),
                if (_dailyController.text.isNotEmpty)
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    icon: const Icon(
                      Icons.clear_rounded,
                      size: 20,
                      color: _TogetherBudgetTokens.expenseRed,
                    ),
                    onPressed: () {
                      setState(() {
                        _dailyController.clear();
                      });
                    },
                  ),
              ],
            )
          else
            InkWell(
              onTap: () => _startEditBudget(currentBudget),
              borderRadius: BorderRadius.circular(12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: <Widget>[
                  Expanded(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        hasBudget
                            ? ((remaining < 0 ? '-' : '') +
                                formatPeso(remaining.abs()))
                            : '₱0.00',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 36,
                          fontWeight: FontWeight.w900,
                          color: !hasBudget
                              ? _TogetherBudgetTokens.budgetGold
                              : (isOver
                                  ? _TogetherBudgetTokens.expenseRed
                                  : _TogetherBudgetTokens.safeGreen),
                          letterSpacing: -1.0,
                        ),
                      ),
                    ),
                  ),
                  Icon(
                    Icons.edit_rounded,
                    size: 18,
                    color: tokens.textMuted.withValues(alpha: 0.6),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 2),

          // Context Subtitle below amount
          Text(
            isTyping
                ? (_isAddMode
                    ? 'Enter amount to add to group tab budget'
                    : 'Enter new target group tab budget')
                : (!hasBudget
                    ? 'No tab budget set yet. Tap "Add Budget" below.'
                    : (isOver
                        ? 'Tab budget exceeded by ${formatPeso(remaining.abs())}'
                        : 'Safe remaining balance for group spending')),
            style: GoogleFonts.plusJakartaSans(
              fontSize: 11.5,
              fontWeight: FontWeight.w500,
              color: isOver
                  ? _TogetherBudgetTokens.expenseRed
                  : tokens.textSecondary,
            ),
          ),
          const SizedBox(height: 10),

          // Quick Amount Increments (Preset Numbers close to Budget Input)
          _buildQuickAmountIncrements(tokens),
          const SizedBox(height: 12),

          // Compact Budget Breakdown Strip (Target, Spent, Remaining Context)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          'Tab Target',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600,
                            color: tokens.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 1),
                        Text(
                          formatPeso(currentBudget),
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: _TogetherBudgetTokens.budgetGold,
                          ),
                        ),
                      ],
                    ),
                    Container(height: 20, width: 1, color: tokens.cardBorder),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: <Widget>[
                        Text(
                          'Tab Spent',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600,
                            color: tokens.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 1),
                        Text(
                          formatPeso(currentSpent),
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: _TogetherBudgetTokens.expenseRed,
                          ),
                        ),
                      ],
                    ),
                    Container(height: 20, width: 1, color: tokens.cardBorder),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: <Widget>[
                        Text(
                          'Remaining',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600,
                            color: tokens.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 1),
                        Text(
                          hasBudget
                              ? ((remaining < 0 ? '-' : '') +
                                  formatPeso(remaining.abs()))
                              : '₱0.00',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: !hasBudget
                                ? _TogetherBudgetTokens.budgetGold
                                : (isOver
                                    ? _TogetherBudgetTokens.expenseRed
                                    : _TogetherBudgetTokens.safeGreen),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                BentoHealthBar(
                  progress: progressValue,
                  color: isOver
                      ? _TogetherBudgetTokens.expenseRed
                      : (isWarning
                          ? _TogetherBudgetTokens.budgetGold
                          : _TogetherBudgetTokens.safeGreen),
                  height: 5,
                ),
              ],
            ),
          ),

          // Overspent Warning Box
          if (isOver) ...<Widget>[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: tokens.tint(_TogetherBudgetTokens.expenseRed, 0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: _TogetherBudgetTokens.expenseRed.withValues(alpha: 0.25),
                  width: 1.0,
                ),
              ),
              child: Row(
                children: <Widget>[
                  const Icon(
                    Icons.error_outline_rounded,
                    size: 15,
                    color: _TogetherBudgetTokens.expenseRed,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Tab budget exceeded by ${formatPeso(remaining.abs())}.',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: _TogetherBudgetTokens.expenseRed,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// 3. Action Buttons: Cancel & Save when typing; Add Budget, Edit Budget, Reset when idle
  Widget _buildActionButtons(
    BuildContext context, {
    required double currentBudget,
    required bool hasBudget,
    required _TogetherBudgetTokens tokens,
  }) {
    if (_isInputActive) {
      return Row(
        children: <Widget>[
          // Cancel Button (Solid Dark Red #991B1B)
          Expanded(
            child: FilledButton.icon(
              onPressed: _cancelInput,
              icon: const Icon(Icons.close_rounded, size: 16, color: Colors.white),
              label: const Text('Cancel'),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(46),
                backgroundColor: _TogetherBudgetTokens.expenseRed,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 4),
                textStyle: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          // Save Button (Solid Dark Green #0F766E)
          Expanded(
            child: FilledButton.icon(
              onPressed: _saveBudget,
              icon: const Icon(Icons.check_rounded, size: 16, color: Colors.white),
              label: Text(_isAddMode ? 'Save & Add' : 'Save Budget'),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(46),
                backgroundColor: _TogetherBudgetTokens.safeGreen,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 4),
                textStyle: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      );
    }

    return Row(
      children: <Widget>[
        // Add Budget Button (Solid Dark Green #0F766E)
        Expanded(
          child: FilledButton.icon(
            onPressed: _startAddBudget,
            icon: const Icon(Icons.add_rounded, size: 16, color: Colors.white),
            label: const Text('Add Budget'),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(44),
              backgroundColor: _TogetherBudgetTokens.safeGreen,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 4),
              textStyle: GoogleFonts.plusJakartaSans(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        // Edit Budget Button (Solid Gold #D97706)
        Expanded(
          child: FilledButton.icon(
            onPressed: () => _startEditBudget(currentBudget),
            icon: const Icon(Icons.edit_rounded, size: 15, color: Colors.white),
            label: const Text('Edit Budget'),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(44),
              backgroundColor: _TogetherBudgetTokens.budgetGold,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 4),
              textStyle: GoogleFonts.plusJakartaSans(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        // Reset Button (Solid Dark Red #991B1B)
        Expanded(
          child: FilledButton.icon(
            onPressed: _resetBudget,
            icon: const Icon(Icons.restart_alt_rounded,
                size: 15, color: Colors.white),
            label: const Text('Reset'),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(44),
              backgroundColor: _TogetherBudgetTokens.expenseRed,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 4),
              textStyle: GoogleFonts.plusJakartaSans(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// 4. Quick Amount Increments (+₱100, +₱200, +₱300, +₱500, +₱1,000)
  Widget _buildQuickAmountIncrements(_TogetherBudgetTokens tokens) {
    const List<double> increments = <double>[100, 200, 300, 500, 1000];

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
                  padding: const EdgeInsets.symmetric(vertical: 7),
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
                        color: _TogetherBudgetTokens.budgetGold,
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
}
