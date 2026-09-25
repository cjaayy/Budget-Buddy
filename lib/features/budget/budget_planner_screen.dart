import 'dart:async';

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
import '../savings/savings_screen.dart';

/// Clean Modern Bento Tokens for Today's Budget Planner Screen.
/// Emphasizes Gold (#D97706) as primary focus with Dark Teal (#0F766E) and Dark Red (#991B1B).
class _BudgetTokens {
  const _BudgetTokens(this.isDark);

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

typedef _BentoTokens = _BudgetTokens;


class BudgetPlannerScreen extends ConsumerStatefulWidget {
  const BudgetPlannerScreen({super.key});

  @override
  ConsumerState<BudgetPlannerScreen> createState() =>
      _BudgetPlannerScreenState();
}

class _BudgetPlannerScreenState extends ConsumerState<BudgetPlannerScreen> {
  late final TextEditingController _dailyController;
  final FocusNode _focusNode = FocusNode();
  bool _isInputActive = false;
  bool _isAddMode = false;
  double? _lastAddBase;
  double? _lastAddAmount;
  DateTime? _lastAddDate; // tracks which calendar day the last add was done

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
    if (!_isInputActive) return;
    HapticFeedback.lightImpact();
    setState(() {
      final bool isAllSelected = _dailyController.selection.start == 0 &&
          _dailyController.selection.end == _dailyController.text.length &&
          _dailyController.text.isNotEmpty;

      double nextAmount;
      if (isAllSelected) {
        nextAmount = amount;
      } else {
        final double currentVal =
            double.tryParse(_dailyController.text.trim()) ?? 0.0;
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

  void _startAddBudget(double currentBudget) {
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
    final double currentBudget = state.settings.dailyLimit ?? 0;
    final double target = _isAddMode ? (currentBudget + entered) : entered;

    _focusNode.unfocus();

    if (_isAddMode) {
      _confirmAndSaveAddBudget(
        currentBudget: currentBudget,
        addedAmount: entered,
        targetAmount: target,
      );
    } else {
      _handleBudgetSubmissionWithDebtCheck(
        targetAmount: target,
        previousBudget: currentBudget > 0 ? currentBudget : null,
        isUpdate: currentBudget > 0,
      );
    }
  }

  Future<void> _confirmAndSaveAddBudget({
    required double currentBudget,
    required double addedAmount,
    required double targetAmount,
  }) async {
    // Add Budget never touches savings debt — debt stays separate.
    // Skip confirmation dialog when setting from zero (first-time budget set).
    if (currentBudget > 0) {
      final bool? confirmed = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext ctx) => _CountdownConfirmationDialog(
          title: 'Confirm Add Budget',
          message: 'Add ${formatPeso(addedAmount)} to today\'s budget of ${formatPeso(currentBudget)} for a new total of ${formatPeso(targetAmount)}?',
          confirmLabel: 'Save & Add',
          confirmColor: _BudgetTokens.safeGreen,
          icon: Icons.add_circle_outline_rounded,
          autoConfirm: false,
          totalSeconds: 3,
        ),
      );
      if (!mounted || confirmed != true) return;
    }
    if (!mounted) return;

    if (currentBudget > 0) {
      ref
          .read(budgetBuddyControllerProvider.notifier)
          .addDailyBudget(addedAmount: addedAmount);
    } else {
      ref
          .read(budgetBuddyControllerProvider.notifier)
          .recordDailyBudget(amount: targetAmount);
    }

    setState(() {
      _isInputActive = false;
      _isAddMode = false;
      _dailyController.clear();
      if (currentBudget > 0) {
        _lastAddBase = currentBudget;
        _lastAddAmount = addedAmount;
        _lastAddDate = ref.read(budgetBuddyControllerProvider.notifier).now;
      } else {
        _lastAddBase = null;
        _lastAddAmount = null;
        _lastAddDate = null;
      }
    });

    showAppAlert(
      context,
      message: 'Today\'s budget increased to ${formatPeso(targetAmount)}!',
      title: 'Success',
      icon: Icons.check_circle_outline_rounded,
      accentColor: _BudgetTokens.safeGreen,
    );
  }

  Future<void> _handleBudgetSubmissionWithDebtCheck({
    required double targetAmount,
    double? previousBudget,
    required bool isUpdate,
  }) async {
    // Debt is NEVER touched here — it can only be paid from the Savings screen.
    // Always show countdown confirmation then save budget.
    if (isUpdate && previousBudget != null) {
      final bool? confirmed = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext ctx) => _CountdownConfirmationDialog(
          title: 'Confirm Budget Update',
          message:
              'Update today\'s budget from ${formatPeso(previousBudget)} to ${formatPeso(targetAmount)}?',
          confirmLabel: 'Update Now',
          confirmColor: _BudgetTokens.safeGreen,
          icon: Icons.sync_rounded,
          autoConfirm: false,
          totalSeconds: 3,
        ),
      );
      if (!mounted || confirmed != true) return;
    } else if (!isUpdate) {
      final bool? confirmed = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext ctx) => _CountdownConfirmationDialog(
          title: 'Set Today\'s Budget',
          message: 'Set today\'s budget to ${formatPeso(targetAmount)}?',
          confirmLabel: 'Set Budget',
          confirmColor: _BudgetTokens.safeGreen,
          icon: Icons.check_circle_outline_rounded,
          autoConfirm: false,
          totalSeconds: 3,
        ),
      );
      if (!mounted || confirmed != true) return;
    }

    ref
        .read(budgetBuddyControllerProvider.notifier)
        .recordDailyBudget(amount: targetAmount);

    setState(() {
      _isInputActive = false;
      _isAddMode = false;
      _dailyController.clear();
      _lastAddBase = null;
      _lastAddAmount = null;
    });

    showAppAlert(
      context,
      message: isUpdate
          ? 'Today\'s budget updated to ${formatPeso(targetAmount)}!'
          : 'Today\'s budget set to ${formatPeso(targetAmount)}!',
      title: 'Success',
      icon: Icons.check_circle_outline_rounded,
      accentColor: _BudgetTokens.safeGreen,
    );
  }

  Future<bool?> _showNewBudgetDebtChoiceDialog({
    required double proposedBudget,
    required double debtAmount,
    required bool isUpdate,
  }) async {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final _BudgetTokens tokens = _BudgetTokens(isDark);

    double payAmount = debtAmount <= proposedBudget
        ? (debtAmount <= proposedBudget * 0.5
            ? debtAmount
            : (proposedBudget * 0.3).roundToDouble())
        : (proposedBudget * 0.5).roundToDouble();
    if (payAmount <= 0 && debtAmount > 0) {
      payAmount = (debtAmount <= proposedBudget ? debtAmount : proposedBudget);
    }

    final TextEditingController payCtrl = TextEditingController(
      text: payAmount.toStringAsFixed(0),
    );
    bool payDebtSelected = true;

    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: tokens.cardBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (BuildContext sheetContext) {
        return StatefulBuilder(
          builder: (BuildContext ctx, StateSetter setSheetState) {
            final double? enteredPay = double.tryParse(payCtrl.text.trim());
            final double currentPay =
                payDebtSelected ? (enteredPay ?? 0.0) : 0.0;
            final double netBudget =
                (proposedBudget - currentPay).clamp(0.0, double.infinity);
            final double remainingDebt =
                (debtAmount - currentPay).clamp(0.0, double.infinity);

            return SafeArea(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  20,
                  12,
                  20,
                  MediaQuery.of(sheetContext).viewInsets.bottom + 20,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Center(
                      child: Container(
                        width: 36,
                        height: 4,
                        decoration: BoxDecoration(
                          color: tokens.cardBorder,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Title Header
                    Row(
                      children: <Widget>[
                        Container(
                          padding: const EdgeInsets.all(7),
                          decoration: BoxDecoration(
                            color: tokens.tint(_BudgetTokens.budgetGold, 0.12),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.account_balance_wallet_rounded,
                            size: 18,
                            color: _BudgetTokens.budgetGold,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                'Running Deficit Choice',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: tokens.textPrimary,
                                ),
                              ),
                              Text(
                                'Outstanding deficit: ${formatPeso(debtAmount)}',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w500,
                                  color: _BudgetTokens.expenseRed,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded, size: 20),
                          onPressed: () =>
                              Navigator.of(sheetContext).pop(false),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Bento Overview: Proposed Budget & Running Deficit
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: tokens.subCardBg,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: tokens.cardBorder),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: <Widget>[
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                'New Target Budget',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: tokens.textSecondary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                formatPeso(proposedBudget),
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: _BudgetTokens.budgetGold,
                                ),
                              ),
                            ],
                          ),
                          Container(
                            height: 24,
                            width: 1,
                            color: tokens.cardBorder,
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: <Widget>[
                              Text(
                                'Running Deficit',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: tokens.textSecondary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                formatPeso(debtAmount),
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: _BudgetTokens.expenseRed,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    Text(
                      'Choose how to apply your budget:',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: tokens.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Choice 1: Pay Debt from New Budget
                    InkWell(
                      onTap: () =>
                          setSheetState(() => payDebtSelected = true),
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: payDebtSelected
                              ? tokens.tint(_BudgetTokens.budgetGold, 0.08)
                              : tokens.subCardBg,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: payDebtSelected
                                ? _BudgetTokens.budgetGold
                                : tokens.cardBorder,
                            width: payDebtSelected ? 1.5 : 1.0,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Row(
                              children: <Widget>[
                                Icon(
                                  payDebtSelected
                                      ? Icons.radio_button_checked_rounded
                                      : Icons.radio_button_off_rounded,
                                  size: 16,
                                  color: payDebtSelected
                                      ? _BudgetTokens.budgetGold
                                      : tokens.textMuted,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Deduct & Pay Debt from New Budget',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: tokens.textPrimary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            if (payDebtSelected) ...<Widget>[
                              const SizedBox(height: 10),
                              Text(
                                'Amount to pay towards debt:',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: tokens.textSecondary,
                                ),
                              ),
                              const SizedBox(height: 6),
                              TextField(
                                controller: payCtrl,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                        decimal: true),
                                onChanged: (_) => setSheetState(() {}),
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  color: _BudgetTokens.expenseRed,
                                ),
                                decoration: InputDecoration(
                                  prefixText: '₱ ',
                                  isDense: true,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide:
                                        BorderSide(color: tokens.cardBorder),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              // Quick Pills
                              Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                children: <Widget>[
                                  ...<double>[50, 100, 200]
                                      .where((double v) =>
                                          v <= proposedBudget &&
                                          v <= debtAmount)
                                      .map((double val) {
                                    return InkWell(
                                      onTap: () {
                                        payCtrl.text =
                                            val.toStringAsFixed(0);
                                        setSheetState(() {});
                                      },
                                      borderRadius:
                                          BorderRadius.circular(999),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: tokens.subCardBg,
                                          borderRadius:
                                              BorderRadius.circular(999),
                                          border: Border.all(
                                              color: tokens.cardBorder),
                                        ),
                                        child: Text(
                                          '₱${val.toStringAsFixed(0)}',
                                          style: GoogleFonts.plusJakartaSans(
                                            fontSize: 10.5,
                                            fontWeight: FontWeight.w700,
                                            color: _BudgetTokens.budgetGold,
                                          ),
                                        ),
                                      ),
                                    );
                                  }),
                                  InkWell(
                                    onTap: () {
                                      final double fullPay =
                                          debtAmount <= proposedBudget
                                              ? debtAmount
                                              : proposedBudget;
                                      payCtrl.text =
                                          fullPay.toStringAsFixed(0);
                                      setSheetState(() {});
                                    },
                                    borderRadius:
                                        BorderRadius.circular(999),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: tokens.tint(
                                            _BudgetTokens.expenseRed, 0.1),
                                        borderRadius:
                                            BorderRadius.circular(999),
                                        border: Border.all(
                                            color: _BudgetTokens.expenseRed),
                                      ),
                                      child: Text(
                                        'Full (${formatPeso(debtAmount <= proposedBudget ? debtAmount : proposedBudget)})',
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.w700,
                                          color: _BudgetTokens.expenseRed,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Choice 2: Keep Full Budget
                    InkWell(
                      onTap: () =>
                          setSheetState(() => payDebtSelected = false),
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: !payDebtSelected
                              ? tokens.tint(_BudgetTokens.safeGreen, 0.08)
                              : tokens.subCardBg,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: !payDebtSelected
                                ? _BudgetTokens.safeGreen
                                : tokens.cardBorder,
                            width: !payDebtSelected ? 1.5 : 1.0,
                          ),
                        ),
                        child: Row(
                          children: <Widget>[
                            Icon(
                              !payDebtSelected
                                  ? Icons.radio_button_checked_rounded
                                  : Icons.radio_button_off_rounded,
                              size: 16,
                              color: !payDebtSelected
                                  ? _BudgetTokens.safeGreen
                                  : tokens.textMuted,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: <Widget>[
                                  Text(
                                    'Keep Full Budget (${formatPeso(proposedBudget)})',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: tokens.textPrimary,
                                    ),
                                  ),
                                  Text(
                                    'Do not deduct for debt today; settle deficit from future surplus',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 11,
                                      color: tokens.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Live Summary Box
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: tokens.subCardBg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: tokens.cardBorder),
                      ),
                      child: Column(
                        children: <Widget>[
                          Row(
                            mainAxisAlignment:
                                MainAxisAlignment.spaceBetween,
                            children: <Widget>[
                              Text(
                                'Today\'s Spend Allowance:',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: tokens.textSecondary,
                                ),
                              ),
                              Text(
                                formatPeso(netBudget),
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                  color: _BudgetTokens.safeGreen,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            mainAxisAlignment:
                                MainAxisAlignment.spaceBetween,
                            children: <Widget>[
                              Text(
                                'Remaining Deficit:',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: tokens.textSecondary,
                                ),
                              ),
                              Text(
                                formatPeso(remainingDebt),
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                  color: remainingDebt > 0
                                      ? _BudgetTokens.expenseRed
                                      : _BudgetTokens.safeGreen,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Confirm Action Button
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: () {
                          if (payDebtSelected) {
                            if (currentPay <= 0) {
                              showAppAlert(context, message: 'Please enter an amount to pay towards debt, or choose "Keep Full Budget".', title: 'Notice', icon: Icons.info_outline_rounded,

                              );
                              return;
                            }
                            if (currentPay > proposedBudget) {
                              showAppAlert(context,
                                message: 'Debt payment exceeds proposed budget (${formatPeso(proposedBudget)})!',
                                title: 'Alert',
                                icon: Icons.warning_amber_rounded,
                                accentColor: _BudgetTokens.expenseRed,
                              );
                              return;
                            }

                            // 1. Pay savings debt
                            ref
                                .read(
                                    budgetBuddyControllerProvider.notifier)
                                .paySavingsDebt(
                                  amount: currentPay,
                                  deductFromBudget: false,
                                  description:
                                      'Deficit payment allocated from new budget set',
                                );

                            // 2. Set net daily budget
                            ref
                                .read(
                                    budgetBuddyControllerProvider.notifier)
                                .recordDailyBudget(amount: netBudget);

                            setState(() {
                              _isInputActive = false;
                              _isAddMode = false;
                              _dailyController.clear();
                            });

                            Navigator.of(sheetContext).pop(true);

                            showAppAlert(context,
                              message: 'Set today\'s budget to ${formatPeso(netBudget)} and paid ${formatPeso(currentPay)} towards debt! Remaining debt: ${formatPeso(remainingDebt)}.',
                              title: 'Success',
                              icon: Icons.check_circle_outline_rounded,
                              accentColor: _BudgetTokens.safeGreen,
                            );
                          } else {
                            // Keep full budget
                            ref
                                .read(
                                    budgetBuddyControllerProvider.notifier)
                                .recordDailyBudget(amount: proposedBudget);

                            setState(() {
                              _isInputActive = false;
                              _isAddMode = false;
                              _dailyController.clear();
                            });

                            Navigator.of(sheetContext).pop(true);

                            showAppAlert(context,
                              message: 'Today\'s budget set to ${formatPeso(proposedBudget)}! Deficit of ${formatPeso(debtAmount)} remains for future surplus.',
                              title: 'Success',
                              icon: Icons.check_circle_outline_rounded,
                              accentColor: _BudgetTokens.safeGreen,
                            );
                          }
                        },
                        icon: const Icon(Icons.check_circle_rounded,
                            size: 16, color: Colors.white),
                        label: Text(
                          payDebtSelected
                              ? 'Confirm & Pay ${formatPeso(currentPay)} to Debt'
                              : 'Set Full Budget (${formatPeso(proposedBudget)})',
                          style: GoogleFonts.plusJakartaSans(
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                            color: Colors.white,
                          ),
                        ),
                        style: FilledButton.styleFrom(
                          backgroundColor: payDebtSelected
                              ? _BudgetTokens.budgetGold
                              : _BudgetTokens.safeGreen,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showDirectPayDebtSheet(
    BuildContext context, {
    required double savingsDebt,
    required double currentBudget,
    required _BudgetTokens tokens,
  }) {
    final BudgetBuddyState state = ref.read(budgetBuddyControllerProvider);
    final double vaultSavings = state.totalSavings;
    final double currentSpent = state.dailySpent;
    final double remainingBudget =
        (currentBudget - currentSpent).clamp(0.0, double.infinity);
    final bool isOverBudget = currentBudget <= 0 ||
        currentSpent >= currentBudget ||
        (currentBudget - currentSpent) <= 0;
    final bool canPayFromBudget = !isOverBudget && remainingBudget > 0;
    final TextEditingController payCtrl =
        TextEditingController(text: savingsDebt.toStringAsFixed(0));
    int paymentSource = canPayFromBudget
        ? 0
        : (vaultSavings > 0 ? 1 : 2); // 0: From Today's Budget, 1: From Savings Vault, 2: Direct

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: tokens.cardBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (BuildContext sheetCtx) {
        return StatefulBuilder(
          builder: (BuildContext ctx, StateSetter setModalState) {
            final double? enteredVal = double.tryParse(payCtrl.text.trim());
            final double currentAmount = enteredVal ?? 0.0;

            return SafeArea(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  20,
                  12,
                  20,
                  MediaQuery.of(sheetCtx).viewInsets.bottom + 20,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Center(
                      child: Container(
                        width: 36,
                        height: 4,
                        decoration: BoxDecoration(
                          color: tokens.cardBorder,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: <Widget>[
                        Text(
                          'Pay Running Deficit',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: tokens.textPrimary,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded, size: 20),
                          onPressed: () => Navigator.of(sheetCtx).pop(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // Metrics Strip
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: tokens.subCardBg,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: tokens.cardBorder),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: <Widget>[
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                'Running Deficit',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: tokens.textSecondary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                formatPeso(savingsDebt),
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  color: _BudgetTokens.expenseRed,
                                ),
                              ),
                            ],
                          ),
                          Container(
                            height: 24,
                            width: 1,
                            color: tokens.cardBorder,
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: <Widget>[
                              Text(
                                'Today\'s Allowance',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: tokens.textSecondary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                formatPeso(remainingBudget),
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  color: canPayFromBudget
                                      ? _BudgetTokens.budgetGold
                                      : _BudgetTokens.expenseRed,
                                ),
                              ),
                            ],
                          ),
                          Container(
                            height: 24,
                            width: 1,
                            color: tokens.cardBorder,
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: <Widget>[
                              Text(
                                'Vault Savings',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: tokens.textSecondary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                formatPeso(vaultSavings),
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  color: _BudgetTokens.safeGreen,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    Text(
                      'Choose Payment Source:',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: tokens.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Option 0: Today's Budget
                    InkWell(
                      onTap: canPayFromBudget
                          ? () => setModalState(() => paymentSource = 0)
                          : () {
                              showAppAlert(
                                context,
                                message:
                                    'You are overbudget today! Cannot pay debt from today\'s budget allowance.',
                                title: 'Overbudget',
                                icon: Icons.warning_amber_rounded,
                                accentColor: _BudgetTokens.expenseRed,
                              );
                            },
                      borderRadius: BorderRadius.circular(12),
                      child: Opacity(
                        opacity: canPayFromBudget ? 1.0 : 0.45,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: paymentSource == 0 && canPayFromBudget
                                ? tokens.tint(_BudgetTokens.budgetGold, 0.1)
                                : tokens.subCardBg,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: paymentSource == 0 && canPayFromBudget
                                  ? _BudgetTokens.budgetGold
                                  : tokens.cardBorder,
                              width: paymentSource == 0 && canPayFromBudget
                                  ? 1.5
                                  : 1.0,
                            ),
                          ),
                          child: Row(
                            children: <Widget>[
                              Icon(
                                paymentSource == 0 && canPayFromBudget
                                    ? Icons.radio_button_checked_rounded
                                    : Icons.radio_button_off_rounded,
                                size: 16,
                                color: paymentSource == 0 && canPayFromBudget
                                    ? _BudgetTokens.budgetGold
                                    : tokens.textMuted,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: <Widget>[
                                    Row(
                                      children: <Widget>[
                                        Text(
                                          'Pay from Today\'s Budget Allowance',
                                          style: GoogleFonts.plusJakartaSans(
                                            fontSize: 12.5,
                                            fontWeight: FontWeight.w700,
                                            color: canPayFromBudget
                                                ? tokens.textPrimary
                                                : tokens.textMuted,
                                          ),
                                        ),
                                        if (!canPayFromBudget) ...<Widget>[
                                          const SizedBox(width: 6),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: _BudgetTokens.expenseRed
                                                  .withValues(alpha: 0.15),
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                            ),
                                            child: Text(
                                              'Overbudget',
                                              style: GoogleFonts.plusJakartaSans(
                                                fontSize: 9.5,
                                                fontWeight: FontWeight.w700,
                                                color: _BudgetTokens.expenseRed,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                    Text(
                                      canPayFromBudget
                                          ? 'Deducts from today\'s remaining allowance (${formatPeso(remainingBudget)} available)'
                                          : 'Unavailable — You have no budget left today (Overbudget)',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 11,
                                        color: canPayFromBudget
                                            ? tokens.textSecondary
                                            : _BudgetTokens.expenseRed,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),

                    // Option 1: Savings Vault
                    InkWell(
                      onTap: () => setModalState(() => paymentSource = 1),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: paymentSource == 1
                              ? tokens.tint(_BudgetTokens.safeGreen, 0.1)
                              : tokens.subCardBg,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: paymentSource == 1
                                ? _BudgetTokens.safeGreen
                                : tokens.cardBorder,
                            width: paymentSource == 1 ? 1.5 : 1.0,
                          ),
                        ),
                        child: Row(
                          children: <Widget>[
                            Icon(
                              paymentSource == 1
                                  ? Icons.radio_button_checked_rounded
                                  : Icons.radio_button_off_rounded,
                              size: 16,
                              color: paymentSource == 1
                                  ? _BudgetTokens.safeGreen
                                  : tokens.textMuted,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  Text(
                                    'Pay from Savings Vault',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w700,
                                      color: tokens.textPrimary,
                                    ),
                                  ),
                                  Text(
                                    'Deducts from vault savings (${formatPeso(vaultSavings)} available)',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 11,
                                      color: tokens.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),

                    // Option 2: Direct Payment
                    InkWell(
                      onTap: () => setModalState(() => paymentSource = 2),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: paymentSource == 2
                              ? tokens.tint(_BudgetTokens.expenseRed, 0.1)
                              : tokens.subCardBg,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: paymentSource == 2
                                ? _BudgetTokens.expenseRed
                                : tokens.cardBorder,
                            width: paymentSource == 2 ? 1.5 : 1.0,
                          ),
                        ),
                        child: Row(
                          children: <Widget>[
                            Icon(
                              paymentSource == 2
                                  ? Icons.radio_button_checked_rounded
                                  : Icons.radio_button_off_rounded,
                              size: 16,
                              color: paymentSource == 2
                                  ? _BudgetTokens.expenseRed
                                  : tokens.textMuted,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  Text(
                                    'Direct / External Payment',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w700,
                                      color: tokens.textPrimary,
                                    ),
                                  ),
                                  Text(
                                    'Pay without touching today\'s budget or savings vault',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 11,
                                      color: tokens.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    Text(
                      'Payment Amount:',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: tokens.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: payCtrl,
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true),
                      onChanged: (_) => setModalState(() {}),
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: _BudgetTokens.expenseRed,
                      ),
                      decoration: InputDecoration(
                        prefixText: '₱ ',
                        isDense: true,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: tokens.cardBorder),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Quick Pills
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: <Widget>[
                        ...<double>[50, 100, 200].map((double val) {
                          return InkWell(
                            onTap: () {
                              payCtrl.text = val.toStringAsFixed(0);
                              setModalState(() {});
                            },
                            borderRadius: BorderRadius.circular(999),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 9, vertical: 4),
                              decoration: BoxDecoration(
                                color: tokens.subCardBg,
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(color: tokens.cardBorder),
                              ),
                              child: Text(
                                '₱${val.toStringAsFixed(0)}',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: _BudgetTokens.expenseRed,
                                ),
                              ),
                            ),
                          );
                        }),
                        InkWell(
                          onTap: () {
                            payCtrl.text = savingsDebt.toStringAsFixed(0);
                            setModalState(() {});
                          },
                          borderRadius: BorderRadius.circular(999),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 9, vertical: 4),
                            decoration: BoxDecoration(
                              color: tokens.tint(
                                  _BudgetTokens.expenseRed, 0.12),
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(
                                  color: _BudgetTokens.expenseRed),
                            ),
                            child: Text(
                              'Full (${formatPeso(savingsDebt)})',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: _BudgetTokens.expenseRed,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Confirm Payment Button
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: () {
                          if (currentAmount <= 0) {
                            showAppAlert(context, message: 'Please enter a valid amount to pay.', title: 'Notice', icon: Icons.info_outline_rounded,

                            );
                            return;
                          }

                          if (paymentSource == 0) {
                            if (!canPayFromBudget || remainingBudget <= 0) {
                              showAppAlert(
                                context,
                                message:
                                    'You are overbudget today! Cannot pay debt from today\'s budget allowance.',
                                title: 'Overbudget',
                                icon: Icons.warning_amber_rounded,
                                accentColor: _BudgetTokens.expenseRed,
                              );
                              return;
                            }
                            if (remainingBudget < currentAmount) {
                              showAppAlert(
                                context,
                                message:
                                    'Payment (${formatPeso(currentAmount)}) exceeds today\'s remaining budget allowance (${formatPeso(remainingBudget)})!',
                                title: 'Alert',
                                icon: Icons.warning_amber_rounded,
                                accentColor: _BudgetTokens.expenseRed,
                              );
                              return;
                            }
                            ref
                                .read(budgetBuddyControllerProvider.notifier)
                                .paySavingsDebt(
                                  amount: currentAmount,
                                  deductFromBudget: true,
                                  description:
                                      'Deficit payment from today\'s budget allowance',
                                );
                          } else if (paymentSource == 1) {
                            if (vaultSavings < currentAmount) {
                              showAppAlert(context,
                                message: 'Payment exceeds vault savings (${formatPeso(vaultSavings)})!',
                                title: 'Alert',
                                icon: Icons.warning_amber_rounded,
                                accentColor: _BudgetTokens.expenseRed,
                              );
                              return;
                            }
                            ref
                                .read(budgetBuddyControllerProvider.notifier)
                                .paySavingsDebt(
                                  amount: currentAmount,
                                  deductFromBudget: false,
                                  description:
                                      'Deficit payment from settled savings vault',
                                );
                            ref
                                .read(budgetBuddyControllerProvider.notifier)
                                .setTotalSavings((vaultSavings - currentAmount)
                                    .clamp(0.0, double.infinity));
                          } else {
                            ref
                                .read(budgetBuddyControllerProvider.notifier)
                                .paySavingsDebt(
                                  amount: currentAmount,
                                  deductFromBudget: false,
                                  description:
                                      'Direct deficit payment (cash / external)',
                                );
                          }

                          final double remainingDebt =
                              (savingsDebt - currentAmount)
                                  .clamp(0.0, double.infinity);
                          Navigator.of(sheetCtx).pop();

                          showAppAlert(context,
                            message: 'Paid ${formatPeso(currentAmount)} towards debt! Remaining debt: ${formatPeso(remainingDebt)}.',
                            title: 'Success',
                            icon: Icons.check_circle_outline_rounded,
                            accentColor: _BudgetTokens.safeGreen,
                          );
                        },
                        icon: const Icon(Icons.check_circle_rounded,
                            size: 16, color: Colors.white),
                        label: Text(
                          'Confirm Payment (${formatPeso(currentAmount)})',
                          style: GoogleFonts.plusJakartaSans(
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                            color: Colors.white,
                          ),
                        ),
                        style: FilledButton.styleFrom(
                          backgroundColor: _BudgetTokens.expenseRed,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _confirmAndResetBudget() async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext ctx) => const _CountdownConfirmationDialog(
        title: 'Reset Today\'s Budget Plan?',
        message:
            'This will reset today\'s budget target back to ₱0.00 and clear today\'s expenses so you can start fresh.',
        confirmLabel: 'Reset Plan',
        confirmColor: _BudgetTokens.expenseRed,
        icon: Icons.restart_alt_rounded,
        autoConfirm: false,
        totalSeconds: 3,
      ),
    );

    if (!mounted || confirmed != true) {
      return;
    }

    final BudgetBuddyState currentState =
        ref.read(budgetBuddyControllerProvider);
    final DateTime currentClock = currentState.effectiveDate;
    final List<ExpenseEntry> todayExpenses =
        currentState.expenses.where((ExpenseEntry e) {
      return e.source != 'togetherSpend' &&
          DateUtils.isSameDay(e.dateTime, currentClock);
    }).toList();
    if (todayExpenses.isNotEmpty) {
      ref
          .read(budgetBuddyControllerProvider.notifier)
          .deleteExpenses(todayExpenses.map((ExpenseEntry e) => e.id));
    }
    ref.read(budgetBuddyControllerProvider.notifier).clearDailyBudget();

    setState(() {
      _isInputActive = false;
      _isAddMode = false;
      _dailyController.clear();
    });

    showAppAlert(
      context,
      message: 'Today\'s budget plan and expenses have been reset to ₱0.00.',
      title: 'Alert',
      icon: Icons.warning_amber_rounded,
      accentColor: _BudgetTokens.expenseRed,
    );
  }

  @override
  Widget build(BuildContext context) {
    final BudgetBuddyState state = ref.watch(budgetBuddyControllerProvider);
    final BudgetSummary summary = ref.watch(budgetSummaryProvider);
    final DateTime currentClock = state.effectiveDate;
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final _BudgetTokens tokens = _BudgetTokens(isDark);

    final BudgetPeriodSummary monthlySummary =
        summary.periodSummaries[BudgetPeriod.monthly] ??
            const BudgetPeriodSummary(
              period: BudgetPeriod.monthly,
              limit: 0,
              spent: 0,
            );

    final bool hasBudget = (state.settings.dailyLimit ?? 0) > 0;
    final double currentBudget = state.settings.dailyLimit ?? 0;
    final double currentSpent = state.dailySpent;
    final double remaining = currentBudget - currentSpent;
    final bool isOver = hasBudget && remaining < 0;
    final bool isWarning =
        !isOver && hasBudget && currentSpent >= (currentBudget * 0.8);

    final DateTime todayStart =
        DateTime(currentClock.year, currentClock.month, currentClock.day);
    final double grossDailySpent = state.expenses
        .where((ExpenseEntry e) =>
            e.source != 'togetherSpend' &&
            !e.dateTime.isBefore(todayStart) &&
            !e.dateTime.isAfter(currentClock))
        .fold(0.0, (double sum, ExpenseEntry e) => sum + e.amount);

    final double addBase = state.lastAddBase ?? _lastAddBase ?? 0.0;
    final double addAmount = state.lastAddAmount ?? _lastAddAmount ?? 0.0;
    final DateTime? addDate = state.lastAddDate ?? _lastAddDate;
    final bool hasAddToday = addBase > 0 &&
        addAmount > 0 &&
        addDate != null &&
        DateUtils.isSameDay(addDate, currentClock);

    final double overbudgetDebt = hasAddToday
        ? ((state.lastAddDebtAbsorbed ?? 0.0) +
            (currentBudget > 0 && grossDailySpent > currentBudget
                ? (grossDailySpent - currentBudget)
                : 0.0))
        : (currentBudget > 0
            ? (grossDailySpent - currentBudget).clamp(0.0, double.infinity)
            : grossDailySpent);

    final double effectiveDebt = (state.savingsDebt > 0 && overbudgetDebt == 0)
        ? state.savingsDebt
        : (state.savingsDebt + overbudgetDebt);

    // Listen to external resets (e.g. 12 AM midnight reset, +1 day, Reset All)
    ref.listen<BudgetBuddyState>(budgetBuddyControllerProvider,
        (BudgetBuddyState? prev, BudgetBuddyState next) {
      final double? nextLimit = next.settings.dailyLimit;
      final double? prevLimit = prev?.settings.dailyLimit;
      // Detect day change: dailyPeriodStart moved to a new day
      final DateTime? prevDay = prev?.dailyPeriodStart;
      final DateTime? nextDay = next.dailyPeriodStart;
      final bool dayChanged = prevDay != null &&
          nextDay != null &&
          (prevDay.year != nextDay.year ||
              prevDay.month != nextDay.month ||
              prevDay.day != nextDay.day);
      if (nextLimit != prevLimit) {
        if (nextLimit == null || nextLimit <= 0) {
          setState(() {
            _isInputActive = false;
            _isAddMode = false;
            _dailyController.clear();
            _lastAddBase = null;
            _lastAddAmount = null;
            _lastAddDate = null;
          });
        }
      } else if (dayChanged) {
        // Day rolled over — clear the add card
        setState(() {
          _lastAddBase = null;
          _lastAddAmount = null;
          _lastAddDate = null;
        });
      }
    });

    final double progressValue = currentBudget > 0
        ? (currentSpent / currentBudget).clamp(0.0, 1.0)
        : 0.0;

    return Scaffold(
      backgroundColor: tokens.scaffoldBg,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          children: <Widget>[
            // 1. Header (Title + Date)
            _buildHeader(
              context,
              currentClock: currentClock,
              hasBudget: hasBudget,
              tokens: tokens,
            ),
            const SizedBox(height: 12),

            // 2. Hero Budget Card (Remaining displayed when idle, text input when active)
            _buildHeroBudgetCard(
              context,
              currentBudget: currentBudget,
              currentSpent: currentSpent,
              remaining: remaining,
              progressValue: progressValue,
              hasBudget: hasBudget,
              isOver: isOver,
              isWarning: isWarning,
              savingsDebt: effectiveDebt,
              tokens: tokens,
            ),
            const SizedBox(height: 12),

            // 3. Standalone Over Budget Debt Card (shown separately when debt exists)
            if (effectiveDebt > 0) ...<Widget>[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: tokens.tint(_BudgetTokens.expenseRed, 0.07),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: _BudgetTokens.expenseRed.withValues(alpha: 0.30),
                    width: 1.2,
                  ),
                ),
                child: Row(
                  children: <Widget>[
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: _BudgetTokens.expenseRed.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.account_balance_wallet_rounded, size: 18, color: _BudgetTokens.expenseRed),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            'Over Budget Debt',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: _BudgetTokens.expenseRed,
                              letterSpacing: 0.3,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            formatPeso(effectiveDebt),
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              color: _BudgetTokens.expenseRed,
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Debt is separate from your daily budget and can only be paid in Savings.',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                              color: tokens.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => const SavingsScreen(),
                          ),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                        decoration: BoxDecoration(
                          color: _BudgetTokens.expenseRed,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            const Icon(Icons.savings_rounded, size: 14, color: Colors.white),
                            const SizedBox(height: 2),
                            Text(
                              'Pay in Savings',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
            ],

            // 3b. Today's Budget Added Card (only shows for today's add, clears at midnight)
            if (hasAddToday) ...<Widget>[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: tokens.tint(_BudgetTokens.safeGreen, 0.07),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: _BudgetTokens.safeGreen.withValues(alpha: 0.28),
                    width: 1.2,
                  ),
                ),
                child: Row(
                  children: <Widget>[
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: _BudgetTokens.safeGreen.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.add_circle_rounded, size: 18, color: _BudgetTokens.safeGreen),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            'Budget Added Today',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: _BudgetTokens.safeGreen,
                              letterSpacing: 0.3,
                            ),
                          ),
                          const SizedBox(height: 3),
                          RichText(
                            text: TextSpan(
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.2,
                              ),
                              children: <InlineSpan>[
                                TextSpan(
                                  text: formatPeso(addBase),
                                  style: TextStyle(color: tokens.textSecondary),
                                ),
                                TextSpan(
                                  text: '  +  ',
                                  style: TextStyle(color: tokens.textMuted),
                                ),
                                TextSpan(
                                  text: formatPeso(addAmount),
                                  style: const TextStyle(color: _BudgetTokens.safeGreen),
                                ),
                                TextSpan(
                                  text: '  =  ',
                                  style: TextStyle(color: tokens.textMuted),
                                ),
                                TextSpan(
                                  text: formatPeso(addBase + addAmount),
                                  style: const TextStyle(color: _BudgetTokens.safeGreen),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Today\'s budget was increased. Debt is NOT affected.',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                              color: tokens.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
            ],

            // 4. Action Buttons (Cancel / Save when input is active; Add, Edit, Reset when idle)
            _buildActionButtons(
              context,
              currentBudget: currentBudget,
              hasBudget: hasBudget,
              tokens: tokens,
            ),
            const SizedBox(height: 14),

            // 4. Compact Month Total Overview Strip
            _buildMonthTile(
              context,
              monthlyLimit: monthlySummary.limit,
              currentClock: currentClock,
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
    required _BudgetTokens tokens,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Today\'s Budget Plan',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: tokens.textPrimary,
                letterSpacing: -0.6,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              DateFormat('EEEE, MMMM d, y').format(currentClock),
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: tokens.textSecondary,
              ),
            ),
          ],
        ),
        SoftPill(
          text: hasBudget ? 'Active Target' : 'Setup',
          color: hasBudget ? _BudgetTokens.budgetGold : _BudgetTokens.safeGreen,
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
    required double savingsDebt,
    required _BudgetTokens tokens,
  }) {
    final bool isTyping = _isInputActive;

    return BentoCard(
      padding: const EdgeInsets.all(16),
      borderRadius: 20,
      borderColor: isOver
          ? _BudgetTokens.expenseRed.withValues(alpha: 0.35)
          : (isTyping
              ? _BudgetTokens.budgetGold.withValues(alpha: 0.45)
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
                  color: tokens.tint(_BudgetTokens.budgetGold, 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.account_balance_wallet_rounded,
                  size: 15,
                  color: _BudgetTokens.budgetGold,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  isTyping
                      ? (_isAddMode ? 'Add to Today\'s Budget' : 'Edit Target Budget')
                      : 'Today\'s Budget',
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
                            : (isWarning ? '80% Cap' : 'Active Target'))),
                color: isTyping
                    ? _BudgetTokens.budgetGold
                    : (!hasBudget
                        ? _BudgetTokens.budgetGold
                        : (isOver
                            ? _BudgetTokens.expenseRed
                            : (isWarning
                                ? _BudgetTokens.budgetGold
                                : _BudgetTokens.safeGreen))),
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

          // Main Hero Amount Display: Shows Remaining when idle, or TextField equation when active
          if (isTyping)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                // Equation label inline when in add mode
                if (_isAddMode && currentBudget > 0) ...<Widget>[
                  RichText(
                    text: TextSpan(
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.2,
                      ),
                      children: <InlineSpan>[
                        TextSpan(
                          text: '${currentBudget == currentBudget.roundToDouble() ? currentBudget.toStringAsFixed(0) : currentBudget.toStringAsFixed(2)}',
                          style: TextStyle(color: tokens.textSecondary),
                        ),
                        TextSpan(
                          text: '  +  ',
                          style: TextStyle(color: tokens.textMuted),
                        ),
                        TextSpan(
                          text: _dailyController.text.isEmpty ? '0' : _dailyController.text,
                          style: const TextStyle(color: _BudgetTokens.budgetGold),
                        ),
                        TextSpan(
                          text: '  =  ',
                          style: TextStyle(color: tokens.textMuted),
                        ),
                        TextSpan(
                          text: '${(currentBudget + (double.tryParse(_dailyController.text.trim()) ?? 0.0)).toStringAsFixed(0)}',
                          style: const TextStyle(color: _BudgetTokens.safeGreen),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                ],
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
                          color: _BudgetTokens.budgetGold,
                          letterSpacing: -0.8,
                        ),
                        decoration: InputDecoration(
                          prefixText: '₱ ',
                          prefixStyle: GoogleFonts.plusJakartaSans(
                            fontSize: 34,
                            fontWeight: FontWeight.w900,
                            color: tokens.textSecondary,
                            letterSpacing: -0.8,
                          ),
                          hintText: '0',
                          hintStyle: GoogleFonts.plusJakartaSans(
                            fontSize: 34,
                            fontWeight: FontWeight.w900,
                            color: _BudgetTokens.budgetGold.withValues(alpha: 0.35),
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
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            _dailyController.clear();
                          });
                          _focusNode.requestFocus();
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: _BudgetTokens.expenseRed.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: _BudgetTokens.expenseRed.withValues(alpha: 0.35),
                              width: 1.0,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              const Icon(Icons.close_rounded, size: 13, color: _BudgetTokens.expenseRed),
                              const SizedBox(width: 3),
                              Text(
                                'Clear',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: _BudgetTokens.expenseRed,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            )
          else
            InkWell(
              onTap: () {
                setState(() {
                  _lastAddBase = null;
                  _lastAddAmount = null;
                });
                _startEditBudget(currentBudget);
              },
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
                              ? _BudgetTokens.budgetGold
                              : (isOver
                                  ? _BudgetTokens.expenseRed
                                  : _BudgetTokens.safeGreen),
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
          // (inline add pill removed — standalone card below hero card shows this info)
          const SizedBox(height: 2),

          // Context Subtitle below amount
          Text(
            isTyping
                ? (_isAddMode
                    ? (currentBudget > 0
                        ? 'Adding ₱${(double.tryParse(_dailyController.text.trim()) ?? 0.0).toStringAsFixed(0)} to today\'s budget of ${formatPeso(currentBudget)} (Total: ${formatPeso(currentBudget + (double.tryParse(_dailyController.text.trim()) ?? 0.0))})'
                        : 'Enter initial daily budget for today')
                    : 'Enter new target daily budget for today')
                : (!hasBudget
                    ? 'No daily budget set. Tap "Add Budget" below.'
                    : (isOver
                        ? 'Budget exceeded by ${formatPeso(remaining.abs())}'
                        : (savingsDebt > 0
                            ? 'Can spend overbudget: ${formatPeso(remaining)}'
                            : 'Safe remaining balance to spend today'))),
            style: GoogleFonts.plusJakartaSans(
              fontSize: 11.5,
              fontWeight: FontWeight.w500,
              color: isOver ? _BudgetTokens.expenseRed : tokens.textSecondary,
            ),
          ),

          // Quick Amount Increments (Only shown when user taps Add Budget or Edit Budget)
          if (isTyping) ...<Widget>[
            const SizedBox(height: 10),
            _buildQuickAmountIncrements(tokens),
          ],
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
                          'Daily Target',
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
                            color: _BudgetTokens.budgetGold,
                          ),
                        ),
                      ],
                    ),
                    Container(height: 20, width: 1, color: tokens.cardBorder),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: <Widget>[
                        Text(
                          'Spent Today',
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
                            color: _BudgetTokens.expenseRed,
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
                              ? ((remaining < 0 ? '-' : '') + formatPeso(remaining.abs()))
                              : '₱0.00',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: !hasBudget
                                ? _BudgetTokens.budgetGold
                                : (isOver
                                    ? _BudgetTokens.expenseRed
                                    : _BudgetTokens.safeGreen),
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
                      ? _BudgetTokens.expenseRed
                      : (isWarning
                          ? _BudgetTokens.budgetGold
                          : _BudgetTokens.budgetGold),
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
                color: tokens.tint(_BudgetTokens.expenseRed, 0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: _BudgetTokens.expenseRed.withValues(alpha: 0.25),
                  width: 1.0,
                ),
              ),
              child: Row(
                children: <Widget>[
                  const Icon(
                    Icons.error_outline_rounded,
                    size: 15,
                    color: _BudgetTokens.expenseRed,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Budget exceeded by ${formatPeso(remaining.abs())}. Slow down on expenses today.',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: _BudgetTokens.expenseRed,
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
    required _BudgetTokens tokens,
  }) {
    if (_isInputActive) {
      final double entered = double.tryParse(_dailyController.text.trim()) ?? 0.0;
      final bool showEquation = _isAddMode && currentBudget > 0;
      return Column(
        children: <Widget>[
          if (showEquation) ...<Widget>[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: tokens.tint(_BudgetTokens.safeGreen, 0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _BudgetTokens.safeGreen.withValues(alpha: 0.3), width: 1.0),
              ),
              child: Text(
                '${currentBudget == currentBudget.roundToDouble() ? currentBudget.toStringAsFixed(0) : currentBudget.toStringAsFixed(2)} + ${entered == entered.roundToDouble() ? entered.toStringAsFixed(0) : entered.toStringAsFixed(2)} = ${(currentBudget + entered) == (currentBudget + entered).roundToDouble() ? (currentBudget + entered).toStringAsFixed(0) : (currentBudget + entered).toStringAsFixed(2)}',
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: _BudgetTokens.safeGreen,
                  letterSpacing: -0.3,
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
          Row(
            children: <Widget>[
              // Cancel Button (Solid Dark Red #991B1B)
              Expanded(
                child: FilledButton.icon(
                  onPressed: _cancelInput,
                  icon: const Icon(Icons.close_rounded, size: 16, color: Colors.white),
                  label: const Text('Cancel'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(46),
                    backgroundColor: _BudgetTokens.expenseRed,
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
                    backgroundColor: _BudgetTokens.safeGreen,
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
          ),
        ],
      );
    }

    return Row(
      children: <Widget>[
        // Add Budget Button (Solid Dark Green #0F766E)
        Expanded(
          child: FilledButton.icon(
            onPressed: () => _startAddBudget(currentBudget),
            icon: const Icon(Icons.add_rounded, size: 16, color: Colors.white),
            label: const Text('Add Budget'),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(44),
              backgroundColor: _BudgetTokens.safeGreen,
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
              backgroundColor: _BudgetTokens.budgetGold,
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
            onPressed: _confirmAndResetBudget,
            icon: const Icon(Icons.restart_alt_rounded, size: 15, color: Colors.white),
            label: const Text('Reset'),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(44),
              backgroundColor: _BudgetTokens.expenseRed,
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
  Widget _buildQuickAmountIncrements(_BudgetTokens tokens) {
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
                        color: _BudgetTokens.budgetGold,
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

  /// 6. Compact Month Summary Strip with Gold Accent
  Widget _buildMonthTile(
    BuildContext context, {
    required double monthlyLimit,
    required DateTime currentClock,
    required _BudgetTokens tokens,
  }) {
    return BentoCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      borderRadius: 16,
      child: Row(
        children: <Widget>[
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: tokens.tint(_BudgetTokens.budgetGold, 0.10),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.calendar_month_rounded,
              size: 16,
              color: _BudgetTokens.budgetGold,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Month Total Budget',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: tokens.textPrimary,
                  ),
                ),
                Text(
                  DateFormat('MMMM yyyy').format(currentClock),
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    color: tokens.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Text(
            formatPeso(monthlyLimit),
            style: GoogleFonts.plusJakartaSans(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: _BudgetTokens.budgetGold,
              letterSpacing: -0.4,
            ),
          ),
        ],
      ),
    );
  }
}

/// A clean modal confirmation dialog with countdown timer and GoogleFonts.plusJakartaSans
class _CountdownConfirmationDialog extends StatefulWidget {
  const _CountdownConfirmationDialog({
    required this.title,
    required this.message,
    required this.confirmLabel,
    required this.confirmColor,
    required this.icon,
    this.autoConfirm = false,
    this.totalSeconds = 3,
  });

  final String title;
  final String message;
  final String confirmLabel;
  final Color confirmColor;
  final IconData icon;
  final bool autoConfirm;
  final int totalSeconds;

  @override
  State<_CountdownConfirmationDialog> createState() =>
      _CountdownConfirmationDialogState();
}

class _CountdownConfirmationDialogState
    extends State<_CountdownConfirmationDialog> {
  late int _secondsRemaining;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _secondsRemaining = widget.totalSeconds;
    _startCountdown();
  }

  void _startCountdown() {
    _timer = Timer.periodic(const Duration(seconds: 1), (Timer timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_secondsRemaining <= 1) {
        timer.cancel();
        setState(() {
          _secondsRemaining = 0;
        });
        if (widget.autoConfirm) {
          Navigator.of(context).pop(true);
        }
      } else {
        setState(() {
          _secondsRemaining--;
        });
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color cardBg =
        isDark ? const Color(0xFF111827) : const Color(0xFFFFFFFF);
    final Color cardBorder =
        isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0);
    final Color textPrimary =
        isDark ? const Color(0xFFF1F5F9) : const Color(0xFF0F172A);
    final Color textSecondary =
        isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final double progress = widget.totalSeconds > 0
        ? (_secondsRemaining / widget.totalSeconds)
        : 0.0;

    return AlertDialog(
      backgroundColor: cardBg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: cardBorder, width: 1.0),
      ),
      titlePadding: const EdgeInsets.fromLTRB(18, 18, 18, 6),
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
      actionsPadding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
      title: Row(
        children: <Widget>[
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: widget.confirmColor.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(widget.icon, color: widget.confirmColor, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              widget.title,
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.w800,
                fontSize: 16,
                color: textPrimary,
              ),
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 320,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              widget.message,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: textSecondary,
              ),
            ),
            const SizedBox(height: 12),
            BentoHealthBar(
              progress: progress,
              color: widget.confirmColor,
              height: 5,
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Text(
                  _secondsRemaining > 0
                      ? 'Timer: $_secondsRemaining s'
                      : 'Timer done. Ready to confirm.',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: widget.confirmColor,
                  ),
                ),
                Icon(
                  _secondsRemaining > 0
                      ? Icons.timer_outlined
                      : Icons.touch_app_rounded,
                  size: 13,
                  color: widget.confirmColor,
                ),
              ],
            ),
          ],
        ),
      ),
      actions: <Widget>[
        // Solid Red Cancel Button
        FilledButton.icon(
          onPressed: () {
            _timer?.cancel();
            Navigator.of(context).pop(false);
          },
          icon: const Icon(Icons.close_rounded, size: 14, color: Colors.white),
          label: Text(
            'Cancel',
            style: GoogleFonts.plusJakartaSans(
              fontWeight: FontWeight.w700,
              color: Colors.white,
              fontSize: 12,
            ),
          ),
          style: FilledButton.styleFrom(
            backgroundColor: _BudgetTokens.expenseRed,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ),
        // Solid Confirm Button (Disabled until timer is done)
        FilledButton.icon(
          onPressed: _secondsRemaining > 0
              ? null
              : () {
                  _timer?.cancel();
                  Navigator.of(context).pop(true);
                },
          icon: Icon(widget.icon, size: 15),
          label: Text(
            _secondsRemaining > 0
                ? '${widget.confirmLabel} ($_secondsRemaining s)'
                : widget.confirmLabel,
            style: GoogleFonts.plusJakartaSans(
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
          style: FilledButton.styleFrom(
            backgroundColor: widget.confirmColor,
            foregroundColor: Colors.white,
            disabledBackgroundColor:
                widget.confirmColor.withValues(alpha: 0.38),
            disabledForegroundColor: Colors.white.withValues(alpha: 0.7),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ),
      ],
    );
  }
}





