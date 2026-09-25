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
  String _rawInput = '';

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
        if (_rawInput == '0') {
          _rawInput = '';
        }
      }
    });
  }

  void _onClear() {
    HapticFeedback.mediumImpact();
    setState(() {
      _rawInput = '';
    });
  }

  void _onQuickAddAmount(double amount) {
    HapticFeedback.lightImpact();
    setState(() {
      final double nextAmount = _currentAmount + amount;
      if (nextAmount == nextAmount.roundToDouble()) {
        _rawInput = nextAmount.toStringAsFixed(0);
      } else {
        _rawInput = nextAmount.toStringAsFixed(2);
      }
    });
  }

  void _addBudget() {
    final double amount = _currentAmount;
    if (amount <= 0) {
      showAppAlert(
        context,
        message:
            'Please enter an amount on the keypad greater than ₱0 to add to today\'s budget.',
        title: 'Notice',
        icon: Icons.info_outline_rounded,
      );
      return;
    }

    final BudgetBuddyState state = ref.read(budgetBuddyControllerProvider);
    final double currentBudget = state.settings.dailyLimit ?? 0;
    final double newTotal = currentBudget + amount;

    _handleBudgetSubmissionWithDebtCheck(
      targetAmount: newTotal,
      previousBudget: currentBudget > 0 ? currentBudget : null,
      isUpdate: currentBudget > 0,
    );

    setState(() {
      _rawInput = '';
    });
  }

  void _editBudget() {
    final double amount = _currentAmount;
    if (amount <= 0) {
      showAppAlert(
        context,
        message:
            'Please enter a valid budget amount on the keypad greater than ₱0.',
        title: 'Notice',
        icon: Icons.info_outline_rounded,
      );
      return;
    }

    final BudgetBuddyState state = ref.read(budgetBuddyControllerProvider);
    final double currentBudget = state.settings.dailyLimit ?? 0;

    _handleBudgetSubmissionWithDebtCheck(
      targetAmount: amount,
      previousBudget: currentBudget > 0 ? currentBudget : null,
      isUpdate: currentBudget > 0,
    );

    setState(() {
      _rawInput = '';
    });
  }

  Future<void> _handleBudgetSubmissionWithDebtCheck({
    required double targetAmount,
    double? previousBudget,
    required bool isUpdate,
  }) async {
    final BudgetBuddyState state = ref.read(budgetBuddyControllerProvider);
    final double debt = state.savingsDebt;

    if (debt > 0) {
      final bool? proceed = await _showNewBudgetDebtChoiceDialog(
        proposedBudget: targetAmount,
        debtAmount: debt,
        isUpdate: isUpdate,
      );
      if (proceed != true) return;
    } else {
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
          ),
        );

        if (!mounted || confirmed != true) {
          return;
        }
      }

      ref
          .read(budgetBuddyControllerProvider.notifier)
          .recordDailyBudget(amount: targetAmount);

      setState(() {
        _rawInput = '';
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
                              _rawInput = '';
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
                              _rawInput = '';
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
        title: 'Confirm Budget Reset',
        message:
            'This will reset today\'s active budget and spending back to ₱0 so you can start fresh.',
        confirmLabel: 'Reset Now',
        confirmColor: _BudgetTokens.expenseRed,
        icon: Icons.restart_alt_rounded,
        autoConfirm: false,
      ),
    );

    if (!mounted || confirmed != true) {
      return;
    }

    setState(() {
      _rawInput = '';
    });
    ref.read(budgetBuddyControllerProvider.notifier).clearDailyBudget();

    showAppAlert(
      context,
      message: 'Today\'s budget and spending have been reset to ₱0.',
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

    // Listen to external resets (e.g. 12 AM midnight reset)
    ref.listen<BudgetBuddyState>(budgetBuddyControllerProvider,
        (BudgetBuddyState? prev, BudgetBuddyState next) {
      final double? nextLimit = next.settings.dailyLimit;
      final double? prevLimit = prev?.settings.dailyLimit;
      if (nextLimit != prevLimit) {
        if (nextLimit == null || nextLimit <= 0) {
          if (_rawInput.isNotEmpty) {
            setState(() {
              _rawInput = '';
            });
          }
        }
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

            // 2. Hero Budget Card (Remaining displayed in hero display; no duplicate cards)
            _buildHeroBudgetCard(
              context,
              currentBudget: currentBudget,
              currentSpent: currentSpent,
              remaining: remaining,
              progressValue: progressValue,
              hasBudget: hasBudget,
              isOver: isOver,
              isWarning: isWarning,
              savingsDebt: state.savingsDebt,
              tokens: tokens,
            ),
            const SizedBox(height: 12),

            // 3. Action Buttons (Add Budget, Edit Budget, Reset)
            _buildActionButtons(
              context,
              tokens: tokens,
            ),
            const SizedBox(height: 10),

            // 4. Quick Amount Increments (+₱100, +₱200, +₱300, +₱500, +₱1,000)
            _buildQuickAmountIncrements(tokens),
            const SizedBox(height: 12),

            // 5. Numeric Keypad (Flat Bento Keypad Tiles)
            _buildNumericKeypad(context, tokens),
            const SizedBox(height: 14),

            // 6. Compact Month Total Overview Strip
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
    final bool isTyping = _rawInput.isNotEmpty;

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
                  isTyping ? 'Budget Input' : 'Today\'s Budget',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: tokens.textPrimary,
                  ),
                ),
              ),
              SoftPill(
                text: !hasBudget
                    ? 'No Budget Set'
                    : (isOver
                        ? 'Over Budget'
                        : (isWarning ? '80% Cap' : 'Active Target')),
                color: !hasBudget
                    ? _BudgetTokens.budgetGold
                    : (isOver
                        ? _BudgetTokens.expenseRed
                        : (isWarning
                            ? _BudgetTokens.budgetGold
                            : _BudgetTokens.safeGreen)),
                icon: !hasBudget
                    ? Icons.info_outline_rounded
                    : (isOver
                        ? Icons.warning_amber_rounded
                        : (isWarning
                            ? Icons.info_outline_rounded
                            : Icons.check_circle_outline_rounded)),
                fontSize: 11,
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Main Hero Amount Display: Shows Remaining (or 0) when idle, or typed input when typing
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    isTyping
                        ? '₱${_displayAmount()}'
                        : (hasBudget
                            ? ((remaining < 0 ? '-' : '') + formatPeso(remaining.abs()))
                            : '₱0.00'),
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 36,
                      fontWeight: FontWeight.w900,
                      color: isTyping
                          ? _BudgetTokens.budgetGold
                          : (!hasBudget
                              ? _BudgetTokens.budgetGold
                              : (isOver
                                  ? _BudgetTokens.expenseRed
                                  : _BudgetTokens.safeGreen)),
                      letterSpacing: -1.0,
                    ),
                  ),
                ),
              ),
              if (isTyping)
                IconButton(
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  icon: const Icon(
                    Icons.backspace_outlined,
                    size: 20,
                    color: _BudgetTokens.expenseRed,
                  ),
                  onPressed: _onBackspace,
                ),
            ],
          ),
          const SizedBox(height: 2),

          // Context Subtitle below amount
          Text(
            isTyping
                ? 'Tap "Add Budget" to increase or "Edit Budget" to set new target'
                : (!hasBudget
                    ? 'No daily budget set. Enter amount on keypad below.'
                    : (isOver
                        ? 'Budget exceeded by ${formatPeso(remaining.abs())}'
                        : 'Safe remaining balance to spend today')),
            style: GoogleFonts.plusJakartaSans(
              fontSize: 11.5,
              fontWeight: FontWeight.w500,
              color: isOver ? _BudgetTokens.expenseRed : tokens.textSecondary,
            ),
          ),
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

          // Savings Debt Alert
          if (savingsDebt > 0) ...<Widget>[
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
                    Icons.history_rounded,
                    size: 15,
                    color: _BudgetTokens.expenseRed,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Running Debt: ${formatPeso(savingsDebt)} will be settled from upcoming surplus.',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: _BudgetTokens.expenseRed,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: () => _showDirectPayDebtSheet(
                      context,
                      savingsDebt: savingsDebt,
                      currentBudget: currentBudget,
                      tokens: tokens,
                    ),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: _BudgetTokens.expenseRed,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          const Icon(Icons.payment_rounded,
                              size: 11, color: Colors.white),
                          const SizedBox(width: 3),
                          Text(
                            'Pay Debt',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
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
          ],
        ],
      ),
    );
  }

  /// 3. Action Buttons with Solid Dark Green (Add), Solid Gold (Edit), and Solid Dark Red (Reset)
  Widget _buildActionButtons(
    BuildContext context, {
    required _BudgetTokens tokens,
  }) {
    return Row(
      children: <Widget>[
        // Add Budget Button (Solid Dark Green #0F766E)
        Expanded(
          child: FilledButton.icon(
            onPressed: _addBudget,
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
            onPressed: _editBudget,
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

  /// 5. Custom Flat Numeric Keypad (Tactile Bento Keypad Tiles)
  Widget _buildNumericKeypad(BuildContext context, _BudgetTokens tokens) {
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

        // Row 5: Clear and Backspace
        Row(
          children: <Widget>[
            // Clear Key (C)
            Expanded(
              child: _buildActionKeyTile(
                label: 'C',
                color: _BudgetTokens.expenseRed,
                onTap: _onClear,
                tokens: tokens,
              ),
            ),
            const SizedBox(width: 8),
            // Backspace Key
            Expanded(
              child: _buildActionKeyTile(
                icon: Icons.backspace_outlined,
                color: tokens.textSecondary,
                onTap: _onBackspace,
                tokens: tokens,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildKeyTile(String value, _BudgetTokens tokens) {
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
    required _BudgetTokens tokens,
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
  });

  final String title;
  final String message;
  final String confirmLabel;
  final Color confirmColor;
  final IconData icon;
  final bool autoConfirm;

  @override
  State<_CountdownConfirmationDialog> createState() =>
      _CountdownConfirmationDialogState();
}

class _CountdownConfirmationDialogState
    extends State<_CountdownConfirmationDialog> {
  static const int _totalSeconds = 5;
  int _secondsRemaining = _totalSeconds;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
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
    final double progress = _secondsRemaining / _totalSeconds;

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
      content: Column(
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
              Expanded(
                child: Text(
                  _secondsRemaining > 0
                      ? 'Timer: $_secondsRemaining s'
                      : 'Timer done. Ready to confirm.',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: widget.confirmColor,
                  ),
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
        // Solid Confirm Button
        FilledButton.icon(
          onPressed: () {
            _timer?.cancel();
            Navigator.of(context).pop(true);
          },
          icon: Icon(widget.icon, size: 15),
          label: Text(
            widget.confirmLabel,
            style: GoogleFonts.plusJakartaSans(
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
          style: FilledButton.styleFrom(
            backgroundColor: widget.confirmColor,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ),
      ],
    );
  }
}





