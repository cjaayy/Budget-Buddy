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

/// Clean Modern Bento Tokens for Savings & Debt Tracker Screen.
/// Primary Accent: Dark Teal Green (#0F766E) - Savings & Growth
/// Target & Goal Accent: Gold (#D97706) - Target goals, milestone badges
/// Deficit & Debt Accent: Dark Red (#991B1B) - Deficits, debt rollovers, withdrawals
class _SavingsTokens {
  const _SavingsTokens(this.isDark);

  final bool isDark;

  // Primary Accent (Savings & Growth)
  static const Color savingsGreen = Color(0xFF0F766E);

  // Target & Goal Accent
  static const Color targetGold = Color(0xFFD97706);

  // Deficit & Debt Accent
  static const Color deficitRed = Color(0xFF991B1B);

  // Surfaces & Borders
  Color get scaffoldBg =>
      isDark ? const Color(0xFF0B1120) : const Color(0xFFF8FAFC);
  Color get cardBg =>
      isDark ? const Color(0xFF111827) : const Color(0xFFFFFFFF);
  Color get cardBorder =>
      isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0);
  Color get subCardBg =>
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



enum SavingsSection { daily, monthly, logs }

class SavingsScreen extends ConsumerStatefulWidget {
  const SavingsScreen({super.key, this.isTogetherOnly = false});

  final bool isTogetherOnly;

  @override
  ConsumerState<SavingsScreen> createState() => _SavingsScreenState();
}

class _SavingsScreenState extends ConsumerState<SavingsScreen> {
  SavingsSection _activeSection = SavingsSection.daily;

  @override
  Widget build(BuildContext context) {
    final BudgetBuddyState state = ref.watch(budgetBuddyControllerProvider);
    final DateTime currentClock =
        ref.watch(budgetBuddyControllerProvider.notifier).now;
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final _SavingsTokens tokens = _SavingsTokens(isDark);

    final List<DailyRecord> records = _getRecords(state, currentClock);
    final List<DateTime> availableMonths = _availableMonths(records);

    final DailyRecord? todayRecord = records.cast<DailyRecord?>().firstWhere(
      (DailyRecord? r) =>
          r != null && DateUtils.isSameDay(r.date, currentClock),
      orElse: () => null,
    );
    final double todaySaved = (todayRecord != null &&
            todayRecord.budget > 0 &&
            todayRecord.remainingBalance > 0)
        ? todayRecord.remainingBalance
        : 0.0;

    final double dailyRemainingSavings = records
        .where((DailyRecord r) => r.budget > 0 && r.remainingBalance > 0)
        .fold(0.0, (double sum, DailyRecord r) => sum + r.remainingBalance);

    final double pastDailySavings = records
        .where((DailyRecord r) =>
            !DateUtils.isSameDay(r.date, currentClock) &&
            r.budget > 0 &&
            r.remainingBalance > 0)
        .fold(0.0, (double sum, DailyRecord r) => sum + r.remainingBalance);

    final double effectiveBaseSavings = state.totalSavings > pastDailySavings
        ? state.totalSavings
        : pastDailySavings;

    final double savingsAmount = widget.isTogetherOnly
        ? dailyRemainingSavings
        : (effectiveBaseSavings + todaySaved);

    final double dailyDeficits = records.fold(0.0, (double sum, DailyRecord r) {
      if (r.budget > 0 && r.remainingBalance < 0) {
        return sum + r.remainingBalance.abs();
      } else if (r.budget <= 0 && r.totalSpent > 0) {
        return sum + r.totalSpent;
      }
      return sum;
    });

    final double pastDeficits = records
        .where((DailyRecord r) => !DateUtils.isSameDay(r.date, currentClock))
        .fold(0.0, (double sum, DailyRecord r) {
      if (r.budget > 0 && r.remainingBalance < 0) {
        return sum + r.remainingBalance.abs();
      } else if (r.budget <= 0 && r.totalSpent > 0) {
        return sum + r.totalSpent;
      }
      return sum;
    });

    final double todayDeficit = (todayRecord != null &&
            ((todayRecord.budget > 0 && todayRecord.remainingBalance < 0) ||
                (todayRecord.budget <= 0 && todayRecord.totalSpent > 0)))
        ? (todayRecord.remainingBalance < 0
            ? todayRecord.remainingBalance.abs()
            : todayRecord.totalSpent)
        : 0.0;

    final double effectiveBaseDebt = state.savingsDebt > pastDeficits
        ? state.savingsDebt
        : pastDeficits;

    final double debtAmount = widget.isTogetherOnly
        ? dailyDeficits
        : (effectiveBaseDebt + todayDeficit);

    final double togetherSpent = widget.isTogetherOnly
        ? state.expenses
            .where((ExpenseEntry e) => e.source == 'togetherSpend')
            .fold(0.0, (double sum, ExpenseEntry e) => sum + e.amount)
        : 0.0;

    return Scaffold(
      backgroundColor: tokens.scaffoldBg,
      body: SafeArea(
        child: CustomScrollView(
          slivers: <Widget>[
            // 1. Header & Back button
            SliverToBoxAdapter(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    if (widget.isTogetherOnly && Navigator.of(context).canPop()) ...<Widget>[
                      Align(
                        alignment: Alignment.centerLeft,
                        child: FilledButton.icon(
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(Icons.arrow_back_rounded,
                              size: 15, color: Colors.white),
                          label: const Text('Back'),
                          style: FilledButton.styleFrom(
                            backgroundColor: _SavingsTokens.savingsGreen,
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

                    _buildHeader(context, currentClock, tokens),
                    const SizedBox(height: 14),

                    // 2. Dual Hero Bento Overview Grid
                    _buildDualHeroBentoGrid(
                      context,
                      state: state,
                      togetherSpent: togetherSpent,
                      records: records,
                      currentClock: currentClock,
                      tokens: tokens,
                    ),
                    const SizedBox(height: 14),

                    // 4. Quick Action Buttons
                    _buildQuickActionButtons(
                      context,
                      state: state,
                      tokens: tokens,
                      settledVaultSavings: state.totalSavings,
                      savingsAmount: savingsAmount,
                      debtAmount: debtAmount,
                    ),
                    const SizedBox(height: 20),

                    const SizedBox(height: 6),
                  ],
                ),
              ),
            ),

            // 5. Daily & Monthly Historical Archive Section
            SliverToBoxAdapter(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: <Widget>[
                        Row(
                          children: <Widget>[
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: tokens.tint(_SavingsTokens.targetGold, 0.12),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.history_rounded,
                                size: 16,
                                color: _SavingsTokens.targetGold,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _activeSection == SavingsSection.logs
                                  ? 'Vault Activity & Logs'
                                  : 'Historical Balance Logs',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: tokens.textPrimary,
                                letterSpacing: -0.4,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Daily / Monthly / Vault Logs Toggle
                    _buildSectionToggle(
                      context,
                      tokens,
                      logCount: state.vaultLog.length,
                    ),
                    const SizedBox(height: 12),

                    // History Bento Card with Records & Vault Logs
                    // History Bento Card with Records & Vault Logs
                    Builder(
                      builder: (BuildContext _) {
                        // Only settled (past) records appear in history.
                        final List<DailyRecord> pastRecords = records
                            .where((DailyRecord r) =>
                                !DateUtils.isSameDay(r.date, currentClock))
                            .toList();
                        final List<DateTime> pastMonths = _availableMonths(pastRecords);
                        return _buildHistoryCard(
                          context,
                          records: pastRecords,
                          availableMonths: pastMonths,
                          currentClock: currentClock,
                          tokens: tokens,
                          vaultLogs: state.vaultLog,
                        );
                      },
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 1. Header with Title and Active Status Subtitle
  Widget _buildHeader(
    BuildContext context,
    DateTime currentClock,
    _SavingsTokens tokens,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: <Widget>[
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              widget.isTogetherOnly
                  ? 'Together Savings & Debt'
                  : 'Savings & Debt Tracker',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: tokens.textPrimary,
                letterSpacing: -0.6,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'Track your vault & manage deficits',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: tokens.textSecondary,
              ),
            ),
          ],
        ),
        SoftPill(
          text: DateFormat('MMM d').format(currentClock),
          color: _SavingsTokens.savingsGreen,
          icon: Icons.calendar_today_rounded,
          fontSize: 11,
        ),
      ],
    );
  }

  /// 2. Dual Hero Bento Overview Grid
  Widget _buildDualHeroBentoGrid(
    BuildContext context, {
    required BudgetBuddyState state,
    required double togetherSpent,
    required List<DailyRecord> records,
    required DateTime currentClock,
    required _SavingsTokens tokens,
  }) {
    // 1. Calculate accumulated daily savings across all days where budget had remaining balance
    final double dailyRemainingSavings = records
        .where((DailyRecord r) => r.budget > 0 && r.remainingBalance > 0)
        .fold(0.0, (double sum, DailyRecord r) => sum + r.remainingBalance);

    // 2. Identify today's specific savings from today's budget
    final DailyRecord? todayRecord = records.cast<DailyRecord?>().firstWhere(
      (DailyRecord? r) =>
          r != null && DateUtils.isSameDay(r.date, currentClock),
      orElse: () => null,
    );
    final double todaySaved = (todayRecord != null &&
            todayRecord.budget > 0 &&
            todayRecord.remainingBalance > 0)
        ? todayRecord.remainingBalance
        : 0.0;

    // 3. Accumulated deficit from days where spending exceeded budget
    final double dailyDeficits = records.fold(0.0, (double sum, DailyRecord r) {
      if (r.budget > 0 && r.remainingBalance < 0) {
        return sum + r.remainingBalance.abs();
      } else if (r.budget <= 0 && r.totalSpent > 0) {
        return sum + r.totalSpent;
      }
      return sum;
    });

    final double pastDailySavings = records
        .where((DailyRecord r) =>
            !DateUtils.isSameDay(r.date, currentClock) &&
            r.budget > 0 &&
            r.remainingBalance > 0)
        .fold(0.0, (double sum, DailyRecord r) => sum + r.remainingBalance);

    final double effectiveBaseSavings = state.totalSavings > pastDailySavings
        ? state.totalSavings
        : pastDailySavings;

    final double settledVaultSavings = state.totalSavings;

    final double savingsAmount = widget.isTogetherOnly
        ? dailyRemainingSavings
        : (effectiveBaseSavings + todaySaved);

    final double pastDeficits = records
        .where((DailyRecord r) => !DateUtils.isSameDay(r.date, currentClock))
        .fold(0.0, (double sum, DailyRecord r) {
      if (r.budget > 0 && r.remainingBalance < 0) {
        return sum + r.remainingBalance.abs();
      } else if (r.budget <= 0 && r.totalSpent > 0) {
        return sum + r.totalSpent;
      }
      return sum;
    });

    final double todayDeficit = (todayRecord != null &&
            ((todayRecord.budget > 0 && todayRecord.remainingBalance < 0) ||
                (todayRecord.budget <= 0 && todayRecord.totalSpent > 0)))
        ? (todayRecord.remainingBalance < 0
            ? todayRecord.remainingBalance.abs()
            : todayRecord.totalSpent)
        : 0.0;

    final double effectiveBaseDebt = state.savingsDebt > pastDeficits
        ? state.savingsDebt
        : pastDeficits;

    final double debtAmount = widget.isTogetherOnly
        ? dailyDeficits
        : (effectiveBaseDebt + todayDeficit);

    final bool hasDebt = debtAmount > 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            // Hero Bento 1: Total Savings Vault (Dark Green #0F766E)
            Expanded(
              child: BentoCard(
                borderRadius: 24,
                padding: const EdgeInsets.all(16),
                borderColor: _SavingsTokens.savingsGreen.withValues(alpha: 0.35),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: <Widget>[
                        Container(
                          padding: const EdgeInsets.all(7),
                          decoration: BoxDecoration(
                            color: tokens.tint(_SavingsTokens.savingsGreen, 0.12),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.savings_rounded,
                            size: 16,
                            color: _SavingsTokens.savingsGreen,
                          ),
                        ),
                        // Quick Deposit trigger
                        InkWell(
                          onTap: () =>
                              _showQuickDepositSheet(context, tokens: tokens),
                          borderRadius: BorderRadius.circular(999),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: _SavingsTokens.savingsGreen,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: <Widget>[
                                const Icon(Icons.add_rounded,
                                    size: 12, color: Colors.white),
                                const SizedBox(width: 3),
                                Text(
                                  'Deposit',
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
                    const SizedBox(height: 10),
                    Text(
                      widget.isTogetherOnly
                          ? 'Together Savings Vault'
                          : 'Total Savings Vault',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: tokens.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 3),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        widget.isTogetherOnly
                            ? formatPeso(savingsAmount)
                            : formatPeso(settledVaultSavings),
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: _SavingsTokens.savingsGreen,
                          letterSpacing: -0.6,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    if (!widget.isTogetherOnly && todaySaved > 0) ...<Widget>[
                      Row(
                        children: <Widget>[
                          const Icon(Icons.lock_clock_rounded,
                              size: 11,
                              color: _SavingsTokens.targetGold),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              '+${formatPeso(todaySaved)} pending (unlocks midnight)',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: _SavingsTokens.targetGold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ] else ...<Widget>[
                      Text(
                        'Settled vault • withdrawable now',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                          color: tokens.textMuted,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),

            // Hero Bento 2: Running Deficit / Debt Tracker (Dark Red #991B1B)
            Expanded(
              child: BentoCard(
                borderRadius: 24,
                padding: const EdgeInsets.all(16),
                onTap: hasDebt
                    ? () => _showWithdrawOrCoverDeficitSheet(
                          context,
                          state: state,
                          tokens: tokens,
                          settledVaultSavings: settledVaultSavings,
                          debtAmount: debtAmount,
                          initialTab: 1,
                        )
                    : null,
                borderColor: hasDebt
                    ? _SavingsTokens.deficitRed.withValues(alpha: 0.35)
                    : _SavingsTokens.savingsGreen.withValues(alpha: 0.25),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: <Widget>[
                        Container(
                          padding: const EdgeInsets.all(7),
                          decoration: BoxDecoration(
                            color: tokens.tint(
                              hasDebt
                                  ? _SavingsTokens.deficitRed
                                  : _SavingsTokens.savingsGreen,
                              0.12,
                            ),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            hasDebt
                                ? Icons.warning_amber_rounded
                                : Icons.check_circle_rounded,
                            size: 16,
                            color: hasDebt
                                ? _SavingsTokens.deficitRed
                                : _SavingsTokens.savingsGreen,
                          ),
                        ),
                        if (hasDebt)
                          InkWell(
                            onTap: () => _showWithdrawOrCoverDeficitSheet(
                              context,
                              state: state,
                              tokens: tokens,
                              settledVaultSavings: settledVaultSavings,
                              debtAmount: debtAmount,
                              initialTab: 1,
                            ),
                            borderRadius: BorderRadius.circular(999),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: _SavingsTokens.deficitRed,
                                borderRadius: BorderRadius.circular(999),
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
                          )
                        else
                          SoftPill(
                            text: 'Clean Record',
                            color: _SavingsTokens.savingsGreen,
                            fontSize: 10,
                          ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      widget.isTogetherOnly
                          ? 'Together Deficit'
                          : 'Running Deficit',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: tokens.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 3),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        hasDebt ? formatPeso(debtAmount) : '₱0.00',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: hasDebt
                              ? _SavingsTokens.deficitRed
                              : _SavingsTokens.savingsGreen,
                          letterSpacing: -0.6,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      hasDebt
                          ? 'Over-budget deficit to recover'
                          : 'No outstanding debt',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w500,
                        color: tokens.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        // Daily Savings Rollover Banner
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: tokens.subCardBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: tokens.cardBorder),
          ),
          child: Row(
            children: <Widget>[
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: tokens.tint(_SavingsTokens.savingsGreen, 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.auto_graph_rounded,
                  size: 16,
                  color: _SavingsTokens.savingsGreen,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      todaySaved > 0
                          ? "Today's Budget Saved: +${formatPeso(todaySaved)}"
                          : "Daily Budget Savings Active",
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: tokens.textPrimary,
                      ),
                    ),
                    Text(
                      todaySaved > 0
                          ? "Added to your savings vault from today's unspent budget allowance."
                          : "Remaining allowance from every day automatically accumulates into your savings.",
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
        ),
      ],
    );
  }

  /// 4. Quick Action Buttons: Deposit / Withdraw / Pay Debt
  Widget _buildQuickActionButtons(
    BuildContext context, {
    required BudgetBuddyState state,
    required _SavingsTokens tokens,
    double? settledVaultSavings,
    double? savingsAmount,
    double? debtAmount,
  }) {
    final double effectiveDebt = debtAmount ?? state.savingsDebt;
    final double effectiveSettled = settledVaultSavings ?? state.totalSavings;
    final bool hasDebt = effectiveDebt > 0;

    return Row(
      children: <Widget>[
        // Deposit (Solid Dark Green #0F766E)
        Expanded(
          child: FilledButton.icon(
            onPressed: () => _showQuickDepositSheet(context, tokens: tokens),
            icon: const Icon(Icons.savings_rounded, size: 15, color: Colors.white),
            label: Text(
              'Deposit',
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.w700,
                fontSize: 12,
                color: Colors.white,
              ),
            ),
            style: FilledButton.styleFrom(
              backgroundColor: _SavingsTokens.savingsGreen,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 0,
            ),
          ),
        ),
        const SizedBox(width: 8),

        // Withdraw (Solid Gold #D97706)
        Expanded(
          child: FilledButton.icon(
            onPressed: () => _showWithdrawOrCoverDeficitSheet(
              context,
              state: state,
              tokens: tokens,
              settledVaultSavings: effectiveSettled,
              debtAmount: effectiveDebt,
              initialTab: 0,
            ),
            icon: const Icon(Icons.outbond_rounded, size: 15, color: Colors.white),
            label: Text(
              'Withdraw',
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.w700,
                fontSize: 12,
                color: Colors.white,
              ),
            ),
            style: FilledButton.styleFrom(
              backgroundColor: _SavingsTokens.targetGold,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 0,
            ),
          ),
        ),

        if (hasDebt) ...<Widget>[
          const SizedBox(width: 8),
          // Pay Debt (Solid Dark Red #991B1B)
          Expanded(
            child: FilledButton.icon(
              onPressed: () => _showWithdrawOrCoverDeficitSheet(
                context,
                state: state,
                tokens: tokens,
                settledVaultSavings: effectiveSettled,
                debtAmount: effectiveDebt,
                initialTab: 1,
              ),
              icon: const Icon(Icons.payment_rounded, size: 15, color: Colors.white),
              label: Text(
                'Pay Debt',
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                  color: Colors.white,
                ),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: _SavingsTokens.deficitRed,
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
      ],
    );
  }




  /// Deposit Dialog
  Future<void> _showDepositDialog(
    BuildContext context, {
    required _SavingsTokens tokens,
  }) async {
    final TextEditingController amountCtrl = TextEditingController();

    await showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (BuildContext ctx, StateSetter setModalState) {
            return AlertDialog(
              backgroundColor: tokens.cardBg,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(color: tokens.cardBorder, width: 1.0),
              ),
              title: Row(
                children: <Widget>[
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: tokens.tint(_SavingsTokens.savingsGreen, 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.savings_rounded,
                      color: _SavingsTokens.savingsGreen,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Log Savings Deposit',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: tokens.textPrimary,
                    ),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Deposit Amount',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: tokens.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: amountCtrl,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: _SavingsTokens.savingsGreen,
                      ),
                      decoration: InputDecoration(
                        prefixText: '₱ ',
                        hintText: '0.00',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: tokens.cardBorder),
                        ),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Quick Increment Pills
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: <double>[100, 500, 1000, 2000].map((double val) {
                        return InkWell(
                          onTap: () {
                            amountCtrl.text = val.toStringAsFixed(0);
                            setModalState(() {});
                          },
                          borderRadius: BorderRadius.circular(999),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: tokens.subCardBg,
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(color: tokens.cardBorder),
                            ),
                            child: Text(
                              '+${formatPeso(val)}',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: _SavingsTokens.savingsGreen,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: Text(
                    'Cancel',
                    style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.w700,
                      color: tokens.textSecondary,
                    ),
                  ),
                ),
                // Confirm Deposit Button (Solid Dark Green #0F766E)
                FilledButton.icon(
                  onPressed: () async {
                    final double? amount =
                        double.tryParse(amountCtrl.text.trim());
                    if (amount == null || amount <= 0) return;

                    // Synchronize with global vault
                    final double currentVault = ref
                        .read(budgetBuddyControllerProvider)
                        .totalSavings;
                    ref
                        .read(budgetBuddyControllerProvider.notifier)
                        .setTotalSavings(
                          currentVault + amount,
                          logDescription: 'Manual deposit to vault',
                        );

                    if (dialogContext.mounted) {
                      Navigator.of(dialogContext).pop();
                    }
                    if (context.mounted) {
                      showAppAlert(context,
                        message: 'Successfully deposited ${formatPeso(amount)}!',
                        title: 'Success',
                        icon: Icons.check_circle_outline_rounded,
                        accentColor: _SavingsTokens.savingsGreen,
                      );
                    }
                  },
                  icon: const Icon(Icons.check_rounded,
                      size: 15, color: Colors.white),
                  label: Text(
                    'Confirm Deposit',
                    style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                    ),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: _SavingsTokens.savingsGreen,
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
      },
    );
  }

  void _showQuickDepositSheet(
    BuildContext context, {
    required _SavingsTokens tokens,
  }) {
    _showDepositDialog(context, tokens: tokens);
  }

  /// Withdraw / Cover Deficit & Pay Debt Modal Bottom Sheet
  void _showWithdrawOrCoverDeficitSheet(
    BuildContext context, {
    required BudgetBuddyState state,
    required _SavingsTokens tokens,
    double? settledVaultSavings,
    double? debtAmount,
    int initialTab = 0,
  }) {
    final double effectiveDebt = debtAmount ?? state.savingsDebt;
    // Only the settled vault (past committed days) is withdrawable — today's pending locks until midnight
    final double effectiveSavings = settledVaultSavings ?? state.totalSavings;
    final double currentTodayBudget = widget.isTogetherOnly
        ? state.togetherBudget
        : (state.settings.dailyLimit ?? 0.0);
    final bool hasDeficit = effectiveDebt > 0;

    int activeTab = (hasDeficit && initialTab == 1) ? 1 : initialTab;
    final TextEditingController withdrawCtrl = TextEditingController();
    final TextEditingController payDebtCtrl = TextEditingController(
        text: effectiveDebt > 0 ? effectiveDebt.toStringAsFixed(0) : '');
    bool addToTodayBudget = false;
    int withdrawSource = 0; // 0: Add to Today's Budget, 1: Cash Out / External
    int debtPaymentSource =
        0; // 0: From Today's Budget, 1: From Savings Vault, 2: Direct Payment

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: tokens.cardBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (BuildContext sheetContext) {
        return StatefulBuilder(
          builder: (BuildContext ctx, StateSetter setModalState) {
            final double? withdrawVal =
                double.tryParse(withdrawCtrl.text.trim());
            final double currentWithdrawAmount = withdrawVal ?? 0.0;
            final double? payDebtVal = double.tryParse(payDebtCtrl.text.trim());
            final double currentPayDebtAmount = payDebtVal ?? 0.0;

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

                    // Header Row with Title and Close Button
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: <Widget>[
                        Text(
                          'Vault & Deficit Manager',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: tokens.textPrimary,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded, size: 20),
                          onPressed: () => Navigator.of(sheetContext).pop(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // Segmented Tab Switcher (Withdraw vs Pay Deficit)
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: tokens.subCardBg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: tokens.cardBorder),
                      ),
                      child: Row(
                        children: <Widget>[
                          // Tab 0: Withdraw
                          Expanded(
                            child: InkWell(
                              onTap: () => setModalState(() => activeTab = 0),
                              borderRadius: BorderRadius.circular(9),
                              child: Container(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 8),
                                decoration: BoxDecoration(
                                  color: activeTab == 0
                                      ? _SavingsTokens.savingsGreen
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(9),
                                ),
                                alignment: Alignment.center,
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: <Widget>[
                                    Icon(
                                      Icons.outbond_rounded,
                                      size: 14,
                                      color: activeTab == 0
                                          ? Colors.white
                                          : tokens.textSecondary,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Withdraw',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: activeTab == 0
                                            ? Colors.white
                                            : tokens.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),

                          // Tab 1: Pay Deficit / Debt
                          Expanded(
                            child: InkWell(
                              onTap: () => setModalState(() => activeTab = 1),
                              borderRadius: BorderRadius.circular(9),
                              child: Container(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 8),
                                decoration: BoxDecoration(
                                  color: activeTab == 1
                                      ? _SavingsTokens.deficitRed
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(9),
                                ),
                                alignment: Alignment.center,
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: <Widget>[
                                    Icon(
                                      Icons.payment_rounded,
                                      size: 14,
                                      color: activeTab == 1
                                          ? Colors.white
                                          : (hasDeficit
                                              ? _SavingsTokens.deficitRed
                                              : tokens.textSecondary),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      hasDeficit
                                          ? 'Pay Debt (${formatPeso(effectiveDebt)})'
                                          : 'Pay Deficit',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: activeTab == 1
                                            ? Colors.white
                                            : (hasDeficit
                                                ? _SavingsTokens.deficitRed
                                                : tokens.textSecondary),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    if (activeTab == 0) ...<Widget>[
                      // TAB 0: WITHDRAW FROM SAVINGS
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
                                  'Settled Vault',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: tokens.textSecondary,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  formatPeso(effectiveSavings),
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                    color: _SavingsTokens.savingsGreen,
                                  ),
                                ),
                                const SizedBox(height: 1),
                                Row(
                                  children: <Widget>[
                                    const Icon(Icons.lock_clock_rounded,
                                        size: 10,
                                        color: _SavingsTokens.targetGold),
                                    const SizedBox(width: 3),
                                    Text(
                                      'Today pending until midnight',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 9.5,
                                        fontWeight: FontWeight.w600,
                                        color: _SavingsTokens.targetGold,
                                      ),
                                    ),
                                  ],
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
                                  'Today\'s Budget',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: tokens.textSecondary,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  formatPeso(currentTodayBudget),
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                    color: _SavingsTokens.targetGold,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),

                      Text(
                        'Choose Withdraw Destination',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: tokens.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Option 0: Add to Today's Budget
                      InkWell(
                        onTap: () => setModalState(() => withdrawSource = 0),
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: withdrawSource == 0
                                ? tokens.tint(_SavingsTokens.targetGold, 0.1)
                                : tokens.subCardBg,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: withdrawSource == 0
                                  ? _SavingsTokens.targetGold
                                  : tokens.cardBorder,
                              width: withdrawSource == 0 ? 1.5 : 1.0,
                            ),
                          ),
                          child: Row(
                            children: <Widget>[
                              Icon(
                                withdrawSource == 0
                                    ? Icons.radio_button_checked_rounded
                                    : Icons.radio_button_off_rounded,
                                size: 16,
                                color: withdrawSource == 0
                                    ? _SavingsTokens.targetGold
                                    : tokens.textMuted,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: <Widget>[
                                    Text(
                                      'Add to Today\'s Budget',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w700,
                                        color: tokens.textPrimary,
                                      ),
                                    ),
                                    Text(
                                      'Transfer into today\'s allowance (${formatPeso(currentTodayBudget)} current)',
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

                      // Option 1: Cash Out / External
                      InkWell(
                        onTap: () => setModalState(() => withdrawSource = 1),
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: withdrawSource == 1
                                ? tokens.tint(_SavingsTokens.savingsGreen, 0.1)
                                : tokens.subCardBg,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: withdrawSource == 1
                                  ? _SavingsTokens.savingsGreen
                                  : tokens.cardBorder,
                              width: withdrawSource == 1 ? 1.5 : 1.0,
                            ),
                          ),
                          child: Row(
                            children: <Widget>[
                              Icon(
                                withdrawSource == 1
                                    ? Icons.radio_button_checked_rounded
                                    : Icons.radio_button_off_rounded,
                                size: 16,
                                color: withdrawSource == 1
                                    ? _SavingsTokens.savingsGreen
                                    : tokens.textMuted,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: <Widget>[
                                    Text(
                                      'Cash Out / External',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w700,
                                        color: tokens.textPrimary,
                                      ),
                                    ),
                                    Text(
                                      'Remove from vault without adding to today\'s budget',
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
                      const SizedBox(height: 12),

                      Text(
                        'Withdraw Amount',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: tokens.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: withdrawCtrl,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        onChanged: (_) => setModalState(() {}),
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: withdrawSource == 0
                              ? _SavingsTokens.targetGold
                              : _SavingsTokens.savingsGreen,
                        ),
                        decoration: InputDecoration(
                          prefixText: '₱ ',
                          hintText: '0.00',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: tokens.cardBorder),
                          ),
                          isDense: true,
                        ),
                      ),
                      const SizedBox(height: 10),

                      // Quick Pills for Withdraw
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: <Widget>[
                          ...<double>[100, 200, 500, 1000].map((double val) {
                            return InkWell(
                              onTap: () {
                                withdrawCtrl.text = val.toStringAsFixed(0);
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
                                  '+${formatPeso(val)}',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: _SavingsTokens.savingsGreen,
                                  ),
                                ),
                              ),
                            );
                          }),
                          if (effectiveSavings > 0)
                            InkWell(
                              onTap: () {
                                withdrawCtrl.text =
                                    effectiveSavings.toStringAsFixed(0);
                                setModalState(() {});
                              },
                              borderRadius: BorderRadius.circular(999),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 9, vertical: 4),
                                decoration: BoxDecoration(
                                  color: tokens.tint(
                                      _SavingsTokens.savingsGreen, 0.12),
                                  borderRadius: BorderRadius.circular(999),
                                  border: Border.all(
                                      color: _SavingsTokens.savingsGreen),
                                ),
                                child: Text(
                                  'Max (${formatPeso(effectiveSavings)})',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: _SavingsTokens.savingsGreen,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Confirm Withdrawal Button
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: () {
                            if (effectiveSavings <= 0) {
                              showAppAlert(sheetContext, message: 'Your vault has no settled savings to withdraw!', title: 'Alert', icon: Icons.warning_amber_rounded,

                                accentColor: _SavingsTokens.deficitRed,

                              );
                              return;
                            }
                            if (currentWithdrawAmount <= 0) {
                              showAppAlert(sheetContext, message: 'Please enter a valid amount to withdraw.', title: 'Notice', icon: Icons.info_outline_rounded,

                              );
                              return;
                            }
                            if (currentWithdrawAmount > effectiveSavings) {
                              showAppAlert(sheetContext, message: 'Withdrawal amount exceeds your settled vault savings!', title: 'Alert', icon: Icons.warning_amber_rounded,

                                accentColor: _SavingsTokens.deficitRed,

                              );
                              return;
                            }

                            final bool addToBudget = withdrawSource == 0;
                            ref
                                .read(budgetBuddyControllerProvider.notifier)
                                .withdrawFromSavings(
                                  amount: currentWithdrawAmount,
                                  addToDailyBudget: addToBudget,
                                  isTogether: widget.isTogetherOnly,
                                );
                            Navigator.of(sheetContext).pop();

                            showAppAlert(
                              context,
                              message: addToBudget
                                  ? 'Withdrew ${formatPeso(currentWithdrawAmount)} → added to today\'s budget! (New: ${formatPeso(currentTodayBudget + currentWithdrawAmount)})'
                                  : 'Withdrew ${formatPeso(currentWithdrawAmount)} from vault (cash out).',
                              title: 'Notice',
                              icon: Icons.info_outline_rounded,
                              accentColor: addToBudget
                                  ? _SavingsTokens.savingsGreen
                                  : _SavingsTokens.targetGold,
                            );
                          },
                          icon: Icon(
                            withdrawSource == 0
                                ? Icons.add_circle_outline_rounded
                                : Icons.outbond_rounded,
                            size: 16,
                            color: Colors.white,
                          ),
                          label: Text(
                            withdrawSource == 0
                                ? 'Withdraw & Add to Today\'s Budget'
                                : 'Cash Out from Vault',
                            style: GoogleFonts.plusJakartaSans(
                              fontWeight: FontWeight.w800,
                              fontSize: 13,
                              color: Colors.white,
                            ),
                          ),
                          style: FilledButton.styleFrom(
                            backgroundColor: withdrawSource == 0
                                ? _SavingsTokens.targetGold
                                : _SavingsTokens.savingsGreen,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 13),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ] else ...<Widget>[
                      // TAB 1: PAY RUNNING DEFICIT / DEBT
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: tokens.subCardBg,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: hasDeficit
                                ? _SavingsTokens.deficitRed
                                    .withValues(alpha: 0.3)
                                : tokens.cardBorder,
                          ),
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
                                  formatPeso(effectiveDebt),
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                    color: hasDeficit
                                        ? _SavingsTokens.deficitRed
                                        : _SavingsTokens.savingsGreen,
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
                                  'Today\'s Budget',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: tokens.textSecondary,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  formatPeso(currentTodayBudget),
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                    color: _SavingsTokens.targetGold,
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
                                  formatPeso(effectiveSavings),
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                    color: _SavingsTokens.savingsGreen,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),

                      if (!hasDeficit) ...<Widget>[
                        // No deficit - show cleared notice
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: _SavingsTokens.savingsGreen
                                .withValues(alpha: 0.10),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: _SavingsTokens.savingsGreen
                                  .withValues(alpha: 0.35),
                            ),
                          ),
                          child: Row(
                            children: <Widget>[
                              Container(
                                padding: const EdgeInsets.all(7),
                                decoration: BoxDecoration(
                                  color: _SavingsTokens.savingsGreen
                                      .withValues(alpha: 0.15),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.check_circle_rounded,
                                  size: 18,
                                  color: _SavingsTokens.savingsGreen,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: <Widget>[
                                    Text(
                                      'No Running Deficit!',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: _SavingsTokens.savingsGreen,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Your budget is on track — there\'s nothing to pay here.',
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
                        ),
                      ] else ...<Widget>[
                        Text(
                          'Choose Payment Source for Debt',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: tokens.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 8),

                        // Option 0: Pay from Today's Budget
                        InkWell(
                        onTap: () => setModalState(() => debtPaymentSource = 0),
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: debtPaymentSource == 0
                                ? tokens.tint(_SavingsTokens.targetGold, 0.1)
                                : tokens.subCardBg,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: debtPaymentSource == 0
                                  ? _SavingsTokens.targetGold
                                  : tokens.cardBorder,
                              width: debtPaymentSource == 0 ? 1.5 : 1.0,
                            ),
                          ),
                          child: Row(
                            children: <Widget>[
                              Icon(
                                debtPaymentSource == 0
                                    ? Icons.radio_button_checked_rounded
                                    : Icons.radio_button_off_rounded,
                                size: 16,
                                color: debtPaymentSource == 0
                                    ? _SavingsTokens.targetGold
                                    : tokens.textMuted,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: <Widget>[
                                    Text(
                                      'Pay from Today\'s Budget Allowance',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w700,
                                        color: tokens.textPrimary,
                                      ),
                                    ),
                                    Text(
                                      'Deducts from today\'s budget (${formatPeso(currentTodayBudget)} available)',
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

                      // Option 1: Pay from Savings Vault
                      InkWell(
                        onTap: () => setModalState(() => debtPaymentSource = 1),
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: debtPaymentSource == 1
                                ? tokens.tint(_SavingsTokens.savingsGreen, 0.1)
                                : tokens.subCardBg,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: debtPaymentSource == 1
                                  ? _SavingsTokens.savingsGreen
                                  : tokens.cardBorder,
                              width: debtPaymentSource == 1 ? 1.5 : 1.0,
                            ),
                          ),
                          child: Row(
                            children: <Widget>[
                              Icon(
                                debtPaymentSource == 1
                                    ? Icons.radio_button_checked_rounded
                                    : Icons.radio_button_off_rounded,
                                size: 16,
                                color: debtPaymentSource == 1
                                    ? _SavingsTokens.savingsGreen
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
                                      'Deducts from accumulated savings (${formatPeso(effectiveSavings)} available)',
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

                      // Option 2: Direct / External Payment
                      InkWell(
                        onTap: () => setModalState(() => debtPaymentSource = 2),
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: debtPaymentSource == 2
                                ? tokens.tint(_SavingsTokens.deficitRed, 0.1)
                                : tokens.subCardBg,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: debtPaymentSource == 2
                                  ? _SavingsTokens.deficitRed
                                  : tokens.cardBorder,
                              width: debtPaymentSource == 2 ? 1.5 : 1.0,
                            ),
                          ),
                          child: Row(
                            children: <Widget>[
                              Icon(
                                debtPaymentSource == 2
                                    ? Icons.radio_button_checked_rounded
                                    : Icons.radio_button_off_rounded,
                                size: 16,
                                color: debtPaymentSource == 2
                                    ? _SavingsTokens.deficitRed
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
                                      'Pay down debt without touching today\'s budget or savings vault',
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
                      const SizedBox(height: 12),

                      Text(
                        'Payment Amount to Debt',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: tokens.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: payDebtCtrl,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        onChanged: (_) => setModalState(() {}),
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: _SavingsTokens.deficitRed,
                        ),
                        decoration: InputDecoration(
                          prefixText: '₱ ',
                          hintText: '0.00',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: tokens.cardBorder),
                          ),
                          isDense: true,
                        ),
                      ),
                      const SizedBox(height: 10),

                      // Quick Pills for Debt Payment
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: <Widget>[
                          ...<double>[50, 100, 200, 500].map((double val) {
                            return InkWell(
                              onTap: () {
                                payDebtCtrl.text = val.toStringAsFixed(0);
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
                                    color: _SavingsTokens.deficitRed,
                                  ),
                                ),
                              ),
                            );
                          }),
                          if (effectiveDebt > 0)
                            InkWell(
                              onTap: () {
                                payDebtCtrl.text =
                                    effectiveDebt.toStringAsFixed(0);
                                setModalState(() {});
                              },
                              borderRadius: BorderRadius.circular(999),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 9, vertical: 4),
                                decoration: BoxDecoration(
                                  color: tokens.tint(
                                      _SavingsTokens.deficitRed, 0.12),
                                  borderRadius: BorderRadius.circular(999),
                                  border: Border.all(
                                      color: _SavingsTokens.deficitRed),
                                ),
                                child: Text(
                                  'Full Deficit (${formatPeso(effectiveDebt)})',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: _SavingsTokens.deficitRed,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                      ],
                      const SizedBox(height: 16),

                      // Confirm Debt Payment Button — only show when there is a deficit
                      if (hasDeficit)
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: () {
                            if (effectiveDebt <= 0) {
                              showAppAlert(sheetContext, message: 'You have no running deficit to pay!', title: 'Alert', icon: Icons.warning_amber_rounded,

                                accentColor: _SavingsTokens.deficitRed,

                              );
                              return;
                            }
                            if (currentPayDebtAmount <= 0) {
                              showAppAlert(sheetContext, message: 'Please enter an amount to pay towards debt.', title: 'Notice', icon: Icons.info_outline_rounded,

                              );
                              return;
                            }
                            if (currentPayDebtAmount > effectiveDebt) {
                              showAppAlert(sheetContext,
                                message: 'Payment (${formatPeso(currentPayDebtAmount)}) exceeds the total deficit (${formatPeso(effectiveDebt)})!',
                                title: 'Alert',
                                icon: Icons.warning_amber_rounded,
                                accentColor: _SavingsTokens.deficitRed,
                              );
                              return;
                            }

                            if (debtPaymentSource == 0) {
                              // From Today's Budget
                              if (currentTodayBudget < currentPayDebtAmount) {
                                showAppAlert(sheetContext,
                                  message: 'Payment exceeds today\'s budget (${formatPeso(currentTodayBudget)})!',
                                  title: 'Alert',
                                  icon: Icons.warning_amber_rounded,
                                  accentColor: _SavingsTokens.deficitRed,
                                );
                                return;
                              }
                              ref
                                  .read(budgetBuddyControllerProvider.notifier)
                                  .paySavingsDebt(
                                    amount: currentPayDebtAmount,
                                    deductFromBudget: true,
                                    description:
                                        'Deficit paid using today\'s budget allowance',
                                  );
                              if (widget.isTogetherOnly) {
                                final double newTogether = (currentTodayBudget -
                                        currentPayDebtAmount)
                                    .clamp(0.0, double.infinity);
                                ref
                                    .read(
                                        budgetBuddyControllerProvider.notifier)
                                    .setTogetherBudget(newTogether);
                              }
                            } else if (debtPaymentSource == 1) {
                              // From Savings Vault
                              if (effectiveSavings < currentPayDebtAmount) {
                                showAppAlert(sheetContext,
                                  message: 'Payment exceeds vault savings (${formatPeso(effectiveSavings)})!',
                                  title: 'Alert',
                                  icon: Icons.warning_amber_rounded,
                                  accentColor: _SavingsTokens.deficitRed,
                                );
                                return;
                              }
                              ref
                                  .read(budgetBuddyControllerProvider.notifier)
                                  .paySavingsDebt(
                                    amount: currentPayDebtAmount,
                                    deductFromBudget: false,
                                    description:
                                        'Deficit paid using settled savings vault',
                                  );
                              ref
                                  .read(budgetBuddyControllerProvider.notifier)
                                  .setTotalSavings((effectiveSavings -
                                          currentPayDebtAmount)
                                      .clamp(0.0, double.infinity));
                            } else {
                              // Direct payment
                              ref
                                  .read(budgetBuddyControllerProvider.notifier)
                                  .paySavingsDebt(
                                    amount: currentPayDebtAmount,
                                    deductFromBudget: false,
                                    description:
                                        'Direct deficit payment (cash / external)',
                                  );
                            }

                            final double remainingDebt =
                                (effectiveDebt - currentPayDebtAmount)
                                    .clamp(0.0, double.infinity);
                            Navigator.of(sheetContext).pop();

                            showAppAlert(context,
                              message: 'Paid ${formatPeso(currentPayDebtAmount)} towards debt! Remaining deficit: ${formatPeso(remainingDebt)}.',
                              title: 'Success',
                              icon: Icons.check_circle_outline_rounded,
                              accentColor: _SavingsTokens.savingsGreen,
                            );
                          },
                          icon: const Icon(Icons.check_circle_rounded,
                              size: 16, color: Colors.white),
                          label: Text(
                            'Confirm Payment to Debt (${formatPeso(currentPayDebtAmount)})',
                            style: GoogleFonts.plusJakartaSans(
                              fontWeight: FontWeight.w800,
                              fontSize: 13,
                              color: Colors.white,
                            ),
                          ),
                          style: FilledButton.styleFrom(
                            backgroundColor: _SavingsTokens.deficitRed,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 13),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }


  Widget _buildDetailRow({
    required String label,
    required String value,
    Color? valueColor,
    required _SavingsTokens tokens,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: <Widget>[
        Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: tokens.textSecondary,
          ),
        ),
        Text(
          value,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: valueColor ?? tokens.textPrimary,
          ),
        ),
      ],
    );
  }

  /// Segmented Daily / Monthly / Vault Logs toggle
  Widget _buildSectionToggle(
    BuildContext context,
    _SavingsTokens tokens, {
    int logCount = 0,
  }) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: tokens.subCardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: tokens.cardBorder, width: 1.0),
      ),
      child: Row(
        children: <Widget>[
          // 1. Daily Records
          Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () {
                if (_activeSection != SavingsSection.daily) {
                  setState(() => _activeSection = SavingsSection.daily);
                }
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: _activeSection == SavingsSection.daily
                      ? _SavingsTokens.savingsGreen
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    Icon(
                      Icons.calendar_today_rounded,
                      size: 12,
                      color: _activeSection == SavingsSection.daily
                          ? Colors.white
                          : tokens.textSecondary,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      'Daily',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11.5,
                        fontWeight: _activeSection == SavingsSection.daily
                            ? FontWeight.w800
                            : FontWeight.w600,
                        color: _activeSection == SavingsSection.daily
                            ? Colors.white
                            : tokens.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 4),

          // 2. Monthly Records
          Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () {
                if (_activeSection != SavingsSection.monthly) {
                  setState(() => _activeSection = SavingsSection.monthly);
                }
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: _activeSection == SavingsSection.monthly
                      ? _SavingsTokens.savingsGreen
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    Icon(
                      Icons.calendar_month_rounded,
                      size: 12,
                      color: _activeSection == SavingsSection.monthly
                          ? Colors.white
                          : tokens.textSecondary,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      'Monthly',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11.5,
                        fontWeight: _activeSection == SavingsSection.monthly
                            ? FontWeight.w800
                            : FontWeight.w600,
                        color: _activeSection == SavingsSection.monthly
                            ? Colors.white
                            : tokens.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 4),

          // 3. Vault Logs / Activity
          Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () {
                if (_activeSection != SavingsSection.logs) {
                  setState(() => _activeSection = SavingsSection.logs);
                }
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: _activeSection == SavingsSection.logs
                      ? _SavingsTokens.savingsGreen
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    Icon(
                      Icons.receipt_long_rounded,
                      size: 12,
                      color: _activeSection == SavingsSection.logs
                          ? Colors.white
                          : tokens.textSecondary,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      'Vault Logs',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11.5,
                        fontWeight: _activeSection == SavingsSection.logs
                            ? FontWeight.w800
                            : FontWeight.w600,
                        color: _activeSection == SavingsSection.logs
                            ? Colors.white
                            : tokens.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// History Bento Card containing the list of daily or monthly savings records or vault logs
  Widget _buildHistoryCard(
    BuildContext context, {
    required List<DailyRecord> records,
    required List<DateTime> availableMonths,
    required DateTime currentClock,
    required _SavingsTokens tokens,
    required List<VaultLogEntry> vaultLogs,
  }) {
    return BentoCard(
      padding: const EdgeInsets.all(14),
      borderRadius: 20,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (_activeSection == SavingsSection.logs)
            _buildVaultLogsView(context, vaultLogs: vaultLogs, tokens: tokens)
          else if (records.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text(
                  widget.isTogetherOnly
                      ? 'No Budget Together savings records yet.'
                      : 'No savings records yet. Set a budget to start tracking your savings history.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    color: tokens.textSecondary,
                  ),
                ),
              ),
            )
          else if (_activeSection == SavingsSection.daily)
            ...records.map(
              (DailyRecord record) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _buildSavingsDateTile(
                    context,
                    record: record,
                    currentClock: currentClock,
                    tokens: tokens,
                    onTap: () => _showSavingsDaySheet(
                      context,
                      record,
                      tokens,
                      currentClock: currentClock,
                    ),
                  ),
                );
              },
            )
          else
            ...availableMonths.map(
              (DateTime month) {
                final List<DailyRecord> monthRecords =
                    _recordsForMonth(records, month);
                final double monthSavings = monthRecords.fold<double>(
                  0,
                  (double total, DailyRecord record) => total + record.savings,
                );
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _buildSavingsMonthTile(
                    context,
                    month: month,
                    savings: monthSavings,
                    recordCount: monthRecords.length,
                    tokens: tokens,
                    onTap: () => _showSavingsMonthSheet(
                      context,
                      month,
                      monthRecords,
                      currentClock,
                      tokens,
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  /// Vault Transaction Logs View
  Widget _buildVaultLogsView(
    BuildContext context, {
    required List<VaultLogEntry> vaultLogs,
    required _SavingsTokens tokens,
  }) {
    if (vaultLogs.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: tokens.tint(_SavingsTokens.targetGold, 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.receipt_long_rounded,
                  size: 28,
                  color: _SavingsTokens.targetGold,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'No Vault Activity Yet',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: tokens.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Transactions such as vault deposits, withdrawals, auto-saved budget surplus, and deficit payments will appear here.',
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w500,
                  color: tokens.textSecondary,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.only(bottom: 10, left: 2, right: 2),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Text(
                'All Transactions',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: tokens.textSecondary,
                ),
              ),
              SoftPill(
                text:
                    '${vaultLogs.length} ${vaultLogs.length == 1 ? 'entry' : 'entries'}',
                color: _SavingsTokens.savingsGreen,
                fontSize: 10,
              ),
            ],
          ),
        ),
        ...vaultLogs.map(
          (VaultLogEntry entry) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _buildVaultLogTile(
              context,
              entry: entry,
              tokens: tokens,
              onTap: () => _showVaultLogDetailSheet(
                context,
                entry: entry,
                tokens: tokens,
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Individual Vault Log Tile with rich Bento styling
  Widget _buildVaultLogTile(
    BuildContext context, {
    required VaultLogEntry entry,
    required _SavingsTokens tokens,
    required VoidCallback onTap,
  }) {
    final bool isAutoSave = entry.type == VaultLogType.autoSave;
    final bool isDeposit = entry.type == VaultLogType.deposit;
    final bool isWithdraw = entry.type == VaultLogType.withdraw;
    final bool isToBudget = entry.description.toLowerCase().contains('budget');

    final Color accentColor = isAutoSave || isDeposit
        ? _SavingsTokens.savingsGreen
        : (isWithdraw
            ? (isToBudget ? _SavingsTokens.targetGold : _SavingsTokens.deficitRed)
            : _SavingsTokens.targetGold);

    final IconData icon = isAutoSave
        ? Icons.auto_awesome_rounded
        : (isDeposit
            ? Icons.add_circle_outline_rounded
            : (isWithdraw
                ? (isToBudget
                    ? Icons.swap_horiz_rounded
                    : Icons.arrow_upward_rounded)
                : Icons.shield_rounded));

    final String typeTitle = isAutoSave
        ? 'Surplus Auto-Saved'
        : (isDeposit
            ? 'Vault Deposit'
            : (isWithdraw
                ? (isToBudget ? 'Withdrawal → Budget' : 'Cash Out (Vault)')
                : 'Deficit Paid'));

    final String tagLabel = isAutoSave
        ? 'AUTO-SAVE'
        : (isDeposit
            ? 'DEPOSIT'
            : (isWithdraw
                ? (isToBudget ? 'TO BUDGET' : 'CASH OUT')
                : 'DEFICIT PAID'));

    final String amountPrefix = (isAutoSave || isDeposit) ? '+' : '-';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: tokens.subCardBg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: tokens.cardBorder.withValues(alpha: 0.7),
              width: 1.0,
            ),
          ),
          child: Row(
            children: <Widget>[
              // Type Icon
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: tokens.tint(accentColor, 0.14),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 18, color: accentColor),
              ),
              const SizedBox(width: 10),

              // Title, description & date
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      typeTitle,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: tokens.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      entry.description,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: tokens.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      DateFormat('MMM d, y • h:mm a').format(entry.dateTime),
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w600,
                        color: tokens.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),

              // Amount & Tag
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: <Widget>[
                  Text(
                    '$amountPrefix${formatPeso(entry.amount)}',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: accentColor,
                    ),
                  ),
                  const SizedBox(height: 3),
                  SoftPill(
                    text: tagLabel,
                    color: accentColor,
                    fontSize: 8.5,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Detail Modal Sheet for a Vault Log entry
  void _showVaultLogDetailSheet(
    BuildContext context, {
    required VaultLogEntry entry,
    required _SavingsTokens tokens,
  }) {
    final bool isAutoSave = entry.type == VaultLogType.autoSave;
    final bool isDeposit = entry.type == VaultLogType.deposit;
    final bool isWithdraw = entry.type == VaultLogType.withdraw;
    final bool isToBudget = entry.description.toLowerCase().contains('budget');

    final Color accentColor = isAutoSave || isDeposit
        ? _SavingsTokens.savingsGreen
        : (isWithdraw
            ? (isToBudget ? _SavingsTokens.targetGold : _SavingsTokens.deficitRed)
            : _SavingsTokens.targetGold);

    final String typeTitle = isAutoSave
        ? 'Surplus Auto-Saved'
        : (isDeposit
            ? 'Vault Deposit'
            : (isWithdraw
                ? (isToBudget
                    ? 'Withdrawal → Today\'s Budget'
                    : 'Cash Out from Vault')
                : 'Deficit Payment'));

    final String amountPrefix = (isAutoSave || isDeposit) ? '+' : '-';

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (BuildContext sheetCtx) {
        return Container(
          decoration: BoxDecoration(
            color: tokens.cardBg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border.all(color: tokens.cardBorder),
          ),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              // Handle
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
              const SizedBox(height: 16),

              // Title and badge
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  Text(
                    'Transaction Details',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: tokens.textPrimary,
                    ),
                  ),
                  SoftPill(
                    text: entry.type.name.toUpperCase(),
                    color: accentColor,
                    fontSize: 10,
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Amount Card
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
                decoration: BoxDecoration(
                  color: tokens.tint(accentColor, 0.10),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: accentColor.withValues(alpha: 0.3)),
                ),
                child: Column(
                  children: <Widget>[
                    Text(
                      '$amountPrefix${formatPeso(entry.amount)}',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        color: accentColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      typeTitle,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: tokens.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Meta Details
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: tokens.subCardBg,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: tokens.cardBorder),
                ),
                child: Column(
                  children: <Widget>[
                    _buildDetailRow(
                      tokens: tokens,
                      label: 'Action',
                      value: typeTitle,
                      valueColor: accentColor,
                    ),
                    Divider(color: tokens.cardBorder, height: 16),
                    _buildDetailRow(
                      tokens: tokens,
                      label: 'Description',
                      value: entry.description,
                    ),
                    Divider(color: tokens.cardBorder, height: 16),
                    _buildDetailRow(
                      tokens: tokens,
                      label: 'Date & Time',
                      value: DateFormat('MMMM d, y • h:mm:ss a')
                          .format(entry.dateTime),
                    ),
                    if (entry.id.isNotEmpty) ...<Widget>[
                      Divider(color: tokens.cardBorder, height: 16),
                      _buildDetailRow(
                        tokens: tokens,
                        label: 'Reference ID',
                        value: entry.id.length > 12
                            ? entry.id.substring(0, 12).toUpperCase()
                            : entry.id.toUpperCase(),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 18),

              // Close Button (Solid Dark Green #0F766E)
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.of(sheetCtx).pop(),
                  style: FilledButton.styleFrom(
                    backgroundColor: _SavingsTokens.savingsGreen,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: Text(
                    'Close',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSavingsDateTile(
    BuildContext context, {
    required DailyRecord record,
    required VoidCallback onTap,
    required _SavingsTokens tokens,
    DateTime? currentClock,
  }) {
    final bool isZeroActivity = record.isZeroActivity;
    final bool isOverspent = record.savings < 0;
    final bool isToday = currentClock != null &&
        DateUtils.isSameDay(record.date, currentClock);

    final Color accent = isZeroActivity
        ? _SavingsTokens.targetGold
        : (isOverspent ? _SavingsTokens.deficitRed : _SavingsTokens.savingsGreen);

    final IconData icon = isZeroActivity
        ? Icons.calendar_today_rounded
        : (isOverspent
            ? Icons.trending_down_rounded
            : Icons.trending_up_rounded);

    final String statusText;
    if (isZeroActivity) {
      statusText = 'No budget configured';
    } else if (isOverspent) {
      statusText = 'Over budget by ${formatPeso(record.savings.abs())}';
    } else if (record.savings > 0) {
      statusText = isToday
          ? 'Saved ${formatPeso(record.savings)} for today\'s budget'
          : 'Saved ${formatPeso(record.savings)} from daily budget';
    } else {
      statusText = 'Spent all ${formatPeso(record.budget)} (Exact)';
    }

    final String badgeText = isZeroActivity
        ? '₱0'
        : (isOverspent
            ? '-${formatPeso(record.savings.abs())}'
            : '+${formatPeso(record.savings)}');

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: tokens.subCardBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: tokens.cardBorder),
        ),
        child: Row(
          children: <Widget>[
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: tokens.tint(accent, 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: accent, size: 16),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    _formatDayLabel(record.date, currentClock),
                    style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: tokens.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    statusText,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      color: tokens.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: tokens.tint(accent, 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                badgeText,
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                  color: accent,
                ),
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.chevron_right_rounded,
              size: 18,
              color: tokens.textMuted,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSavingsMonthTile(
    BuildContext context, {
    required DateTime month,
    required double savings,
    required int recordCount,
    required _SavingsTokens tokens,
    required VoidCallback onTap,
  }) {
    final bool isOverspent = savings < 0;
    final Color accent =
        isOverspent ? _SavingsTokens.deficitRed : _SavingsTokens.savingsGreen;

    final String badgeText = isOverspent
        ? '-${formatPeso(savings.abs())}'
        : '+${formatPeso(savings)}';

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: tokens.subCardBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: tokens.cardBorder),
        ),
        child: Row(
          children: <Widget>[
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: tokens.tint(accent, 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isOverspent ? Icons.calendar_month : Icons.savings_rounded,
                color: accent,
                size: 16,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    DateFormat('MMMM yyyy').format(month),
                    style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: tokens.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$recordCount day${recordCount == 1 ? '' : 's'} tracked',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      color: tokens.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: tokens.tint(accent, 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                badgeText,
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                  color: accent,
                ),
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.chevron_right_rounded,
              size: 18,
              color: tokens.textMuted,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showSavingsDaySheet(
    BuildContext context,
    DailyRecord record,
    _SavingsTokens tokens, {
    DateTime? currentClock,
  }) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: tokens.cardBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (BuildContext sheetContext) {
        final bool isToday = currentClock != null &&
            DateUtils.isSameDay(record.date, currentClock);
        final bool isZeroActivity = record.isZeroActivity;
        final bool isOverspent = record.savings < 0;

        final Color accent = isZeroActivity
            ? _SavingsTokens.targetGold
            : (isOverspent
                ? _SavingsTokens.deficitRed
                : _SavingsTokens.savingsGreen);

        final List<MapEntry<String, double>> categories = record
            .categoryTotals.entries
            .where((MapEntry<String, double> entry) => entry.value > 0)
            .toList()
          ..sort((MapEntry<String, double> a, MapEntry<String, double> b) =>
              b.value.compareTo(a.value));

        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(sheetContext).size.height * 0.78,
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
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
                      FilledButton.icon(
                        onPressed: () => Navigator.of(sheetContext).pop(),
                        icon: const Icon(Icons.arrow_back_rounded,
                            size: 15, color: Colors.white),
                        label: const Text('Back'),
                        style: FilledButton.styleFrom(
                          backgroundColor: _SavingsTokens.savingsGreen,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          visualDensity: VisualDensity.compact,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                      Text(
                        isToday
                            ? 'Today, ${DateFormat('MMM d, yyyy').format(record.date)}'
                            : DateFormat('EEEE, MMM d, yyyy').format(record.date),
                        style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                          color: tokens.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Highlight Card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: tokens.subCardBg,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: tokens.cardBorder),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: <Widget>[
                            Text(
                              isZeroActivity
                                  ? 'Zero Activity'
                                  : (isOverspent
                                      ? 'Overspent'
                                      : (isToday
                                          ? "Saved Today's Budget"
                                          : 'Saved Daily Budget')),
                              style: GoogleFonts.plusJakartaSans(
                                color: accent,
                                fontWeight: FontWeight.w800,
                                fontSize: 12,
                              ),
                            ),
                            Icon(
                              isZeroActivity
                                  ? Icons.horizontal_rule_rounded
                                  : (isOverspent
                                      ? Icons.trending_down_rounded
                                      : Icons.trending_up_rounded),
                              color: accent,
                              size: 16,
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          isZeroActivity
                              ? '₱0.00'
                              : formatPeso(record.savings.abs()),
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            color: accent,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          isZeroActivity
                              ? 'Budget ₱0 • Spent ₱0 • ₱0 balance'
                              : (record.budget > 0
                                  ? (record.savings > 0
                                      ? (isToday
                                          ? 'Spent ${formatPeso(record.totalSpent)} • Left ${formatPeso(record.remainingBalance)} added to today\'s savings'
                                          : 'Spent ${formatPeso(record.totalSpent)} • Left ${formatPeso(record.remainingBalance)} added to savings vault')
                                      : (record.savings < 0
                                          ? 'Spent ${formatPeso(record.totalSpent)} • Over by ${formatPeso(record.savings.abs())}'
                                          : 'Spent ${formatPeso(record.totalSpent)} of ${formatPeso(record.budget)} (Exact)'))
                                  : 'Spent ${formatPeso(record.totalSpent)} • No budget configured'),
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            color: tokens.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  Text(
                    'Category Breakdown',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: tokens.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),

                  if (categories.isEmpty || isZeroActivity)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: Center(
                        child: Text(
                          'No expenses logged for this day.',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            color: tokens.textSecondary,
                          ),
                        ),
                      ),
                    )
                  else
                    Expanded(
                      child: ListView.separated(
                        itemCount: categories.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (BuildContext ctx, int index) {
                          final MapEntry<String, double> entry =
                              categories[index];
                          return Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 10),
                            decoration: BoxDecoration(
                              color: tokens.subCardBg,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: tokens.cardBorder),
                            ),
                            child: Row(
                              children: <Widget>[
                                Expanded(
                                  child: Text(
                                    entry.key,
                                    style: GoogleFonts.plusJakartaSans(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13,
                                      color: tokens.textPrimary,
                                    ),
                                  ),
                                ),
                                Text(
                                  formatPeso(entry.value),
                                  style: GoogleFonts.plusJakartaSans(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 12,
                                    color: _SavingsTokens.deficitRed,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _showSavingsMonthSheet(
    BuildContext context,
    DateTime month,
    List<DailyRecord> records,
    DateTime currentClock,
    _SavingsTokens tokens,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: tokens.cardBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (BuildContext sheetContext) {
        final double monthSavings = records.fold<double>(
          0,
          (double total, DailyRecord record) => total + record.savings,
        );
        final bool isOverspent = monthSavings < 0;
        final Color accent = isOverspent
            ? _SavingsTokens.deficitRed
            : _SavingsTokens.savingsGreen;

        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(sheetContext).size.height * 0.78,
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
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
                      FilledButton.icon(
                        onPressed: () => Navigator.of(sheetContext).pop(),
                        icon: const Icon(Icons.arrow_back_rounded,
                            size: 15, color: Colors.white),
                        label: const Text('Back'),
                        style: FilledButton.styleFrom(
                          backgroundColor: _SavingsTokens.savingsGreen,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          visualDensity: VisualDensity.compact,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                      Text(
                        DateFormat('MMMM yyyy').format(month),
                        style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                          color: tokens.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: tokens.subCardBg,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: tokens.cardBorder),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          isOverspent ? 'Month Overspent' : 'Month Net Saved',
                          style: GoogleFonts.plusJakartaSans(
                            color: accent,
                            fontWeight: FontWeight.w800,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          (isOverspent ? '-' : '+') +
                              formatPeso(monthSavings.abs()),
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            color: accent,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${records.length} day${records.length == 1 ? '' : 's'} tracked in this period',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            color: tokens.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  Text(
                    'Days in this Month',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: tokens.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),

                  Expanded(
                    child: ListView.separated(
                      itemCount: records.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (BuildContext ctx, int index) {
                        final DailyRecord record = records[index];
                        return _buildSavingsDateTile(
                          sheetContext,
                          record: record,
                          currentClock: currentClock,
                          tokens: tokens,
                          onTap: () => _showSavingsDaySheet(
                            sheetContext,
                            record,
                            tokens,
                            currentClock: currentClock,
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  List<DailyRecord> _getRecords(
    BudgetBuddyState state,
    DateTime currentClock,
  ) {
    if (!widget.isTogetherOnly) {
      final DateTime today =
          DateTime(currentClock.year, currentClock.month, currentClock.day);

      final BudgetEntry? entry =
          state.budgetEntries.cast<BudgetEntry?>().firstWhere(
                (BudgetEntry? e) =>
                    e != null && DateUtils.isSameDay(e.date, today),
                orElse: () => null,
              );

      // Only use dailyLimit as the budget if the user explicitly set a BudgetEntry
      // for today. If they haven't set a budget today, treat budget as 0 so no
      // fake "pending savings" appears.
      final double todayBudget = entry?.amount ?? 0.0;

      final List<ExpenseEntry> todayExpenses = state.expenses
          .where((ExpenseEntry e) =>
              e.source != 'togetherSpend' &&
              DateUtils.isSameDay(e.dateTime, today))
          .toList();

      final double todaySpent = todayExpenses.fold(
          0.0, (double sum, ExpenseEntry e) => sum + e.amount);

      final double remainingBalance = todayBudget > 0
          ? (todayBudget - todaySpent)
          : (todaySpent > 0 ? -todaySpent : 0.0);

      final double savings = todayBudget > 0
          ? (todayBudget - todaySpent)
          : (todaySpent > 0 ? -todaySpent : 0.0);

      final Map<String, double> todayCategoryTotals = <String, double>{
        for (final BudgetCategory category in BudgetCategory.values)
          category.label: 0.0,
      };
      for (final ExpenseEntry expense in todayExpenses) {
        todayCategoryTotals[expense.category.label] =
            (todayCategoryTotals[expense.category.label] ?? 0.0) +
                expense.amount;
      }

      final String biggestCategory = todayExpenses.isEmpty
          ? BudgetCategory.miscellaneous.label
          : todayExpenses
              .reduce((ExpenseEntry a, ExpenseEntry b) =>
                  a.amount >= b.amount ? a : b)
              .category
              .label;

      final DailyRecord liveTodayRecord = DailyRecord(
        date: today,
        budget: todayBudget,
        totalSpent: todaySpent,
        remainingBalance: remainingBalance,
        savings: savings,
        biggestExpenseCategory: biggestCategory,
        categoryTotals: todayCategoryTotals,
      );

      final List<DailyRecord> result = <DailyRecord>[];
      bool todayFound = false;

      for (final DailyRecord rec in state.dailyRecords) {
        if (DateUtils.isSameDay(rec.date, today)) {
          result.add(liveTodayRecord);
          todayFound = true;
        } else {
          result.add(rec);
        }
      }

      if (!todayFound) {
        result.add(liveTodayRecord);
      }

      return _sortedRecords(result);
    }

    final double togetherBudget = state.togetherBudget;
    final List<ExpenseEntry> togetherExpenses = state.expenses
        .where((ExpenseEntry e) => e.source == 'togetherSpend')
        .toList();

    if (togetherBudget <= 0 && togetherExpenses.isEmpty) {
      return <DailyRecord>[];
    }

    final Set<DateTime> dates = <DateTime>{};
    final DateTime today =
        DateTime(currentClock.year, currentClock.month, currentClock.day);
    dates.add(today);

    for (final ExpenseEntry expense in togetherExpenses) {
      dates.add(DateTime(
          expense.dateTime.year, expense.dateTime.month, expense.dateTime.day));
    }

    final List<DailyRecord> records = <DailyRecord>[];
    for (final DateTime date in dates) {
      final List<ExpenseEntry> dayExpenses = togetherExpenses
          .where((ExpenseEntry e) => DateUtils.isSameDay(e.dateTime, date))
          .toList();
      final double totalSpent =
          dayExpenses.fold(0, (double sum, ExpenseEntry e) => sum + e.amount);
      final double dayBudget = togetherBudget;
      final double savings =
          dayBudget > 0 ? dayBudget - totalSpent : -totalSpent;

      final Map<String, double> categoryTotals = <String, double>{
        for (final BudgetCategory category in BudgetCategory.values)
          category.label: 0,
      };
      for (final ExpenseEntry e in dayExpenses) {
        categoryTotals[e.category.label] =
            (categoryTotals[e.category.label] ?? 0) + e.amount;
      }

      records.add(
        DailyRecord(
          date: date,
          budget: dayBudget,
          totalSpent: totalSpent,
          remainingBalance: savings,
          savings: savings,
          biggestExpenseCategory: dayExpenses.isEmpty
              ? BudgetCategory.miscellaneous.label
              : dayExpenses
                  .reduce((a, b) => a.amount >= b.amount ? a : b)
                  .category
                  .label,
          categoryTotals: categoryTotals,
        ),
      );
    }

    return _sortedRecords(records);
  }

  List<DailyRecord> _sortedRecords(List<DailyRecord> records) {
    final List<DailyRecord> sorted = List<DailyRecord>.from(records);
    sorted.sort((DailyRecord left, DailyRecord right) {
      return right.date.compareTo(left.date);
    });
    return sorted;
  }

  List<DateTime> _availableMonths(List<DailyRecord> records) {
    final Set<DateTime> months = <DateTime>{};
    for (final DailyRecord record in records) {
      months.add(DateTime(record.date.year, record.date.month));
    }
    final List<DateTime> sortedMonths = months.toList()
      ..sort((DateTime left, DateTime right) => right.compareTo(left));
    return sortedMonths;
  }

  List<DailyRecord> _recordsForMonth(
    List<DailyRecord> records,
    DateTime month,
  ) {
    return records
        .where((DailyRecord record) =>
            record.date.year == month.year && record.date.month == month.month)
        .toList();
  }
}

String _formatDayLabel(DateTime dateTime, [DateTime? currentClock]) {
  final DateTime now = currentClock ?? DateTime.now();
  if (DateUtils.isSameDay(dateTime, now)) {
    return 'Today, ${DateFormat('MMMM d, yyyy').format(dateTime)}';
  }
  return DateFormat('EEEE, MMM d, yyyy').format(dateTime);
}






