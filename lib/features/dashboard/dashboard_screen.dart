import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../core/models/budget_models.dart';
import '../../core/state/app_controller.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/budget_cards.dart';

/// Clean Modern Bento Tokens for Home / Dashboard screen.
/// Implements high contrast, crisp typography, and solid flat cards (no glassmorphism/blur).
class _BentoTokens {
  const _BentoTokens(this.isDark);

  final bool isDark;

  // Primary 3-Color Strict Palette
  static const Color safeGreen = Color(0xFF0F766E);
  static const Color budgetGold = Color(0xFFD97706);
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
  Color get toggleBg =>
      isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9);

  // Text
  Color get textPrimary =>
      isDark ? const Color(0xFFF1F5F9) : const Color(0xFF0F172A);
  Color get textSecondary =>
      isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
  Color get textMuted =>
      isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8);

  // Tint helper
  Color tint(Color color, [double alpha = 0.10]) =>
      color.withValues(alpha: alpha);
}

class _ChartPoint {
  const _ChartPoint({
    required this.index,
    required this.value,
    required this.label,
    required this.fullDate,
  });

  final double index;
  final double value;
  final String label;
  final String fullDate;
}

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({
    super.key,
    this.onGetStarted,
    this.onOpenSpend,
    this.onOpenExpenses,
    this.onOpenSavings,
    this.onOpenProfile,
  });

  final VoidCallback? onGetStarted;
  final VoidCallback? onOpenSpend;
  final VoidCallback? onOpenExpenses;
  final VoidCallback? onOpenSavings;
  final VoidCallback? onOpenProfile;

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  DashboardPeriod _selectedPeriod = DashboardPeriod.daily;

  @override
  void initState() {
    super.initState();
    final DashboardPeriod savedPeriod =
        ref.read(budgetBuddyControllerProvider).dashboardPeriod;
    _selectedPeriod = savedPeriod == DashboardPeriod.weekly
        ? DashboardPeriod.daily
        : savedPeriod;
  }

  BudgetPeriod _budgetPeriodFor(DashboardPeriod period) {
    return switch (period) {
      DashboardPeriod.daily => BudgetPeriod.daily,
      DashboardPeriod.weekly => BudgetPeriod.daily,
      DashboardPeriod.monthly => BudgetPeriod.monthly,
    };
  }

  void _handleHorizontalDragEnd(DragEndDetails details) {
    final double velocity = details.primaryVelocity ?? 0;
    if (velocity.abs() < 250) {
      return;
    }

    final DashboardPeriod nextPeriod = _selectedPeriod == DashboardPeriod.daily
        ? DashboardPeriod.monthly
        : DashboardPeriod.daily;

    setState(() => _selectedPeriod = nextPeriod);
    ref
        .read(budgetBuddyControllerProvider.notifier)
        .setDashboardPeriod(nextPeriod);
  }

  IconData _iconForCategory(BudgetCategory category) {
    return switch (category) {
      BudgetCategory.food => Icons.restaurant_rounded,
      BudgetCategory.transportation => Icons.directions_bus_rounded,
      BudgetCategory.entertainment => Icons.movie_outlined,
      BudgetCategory.shopping => Icons.shopping_bag_rounded,
      BudgetCategory.miscellaneous => Icons.category_rounded,
    };
  }

  String _getGreeting(int hour) {
    if (hour >= 5 && hour < 12) {
      return 'Good morning';
    } else if (hour >= 12 && hour < 17) {
      return 'Good afternoon';
    } else if (hour >= 17 && hour < 22) {
      return 'Good evening';
    }
    return 'Welcome back';
  }

  String _getInitials(String displayName) {
    final String trimmed = displayName.trim();
    if (trimmed.isEmpty) return 'BB';
    final List<String> parts = trimmed.split(RegExp(r'\s+'));
    if (parts.length == 1) {
      return parts[0].substring(0, parts[0].length >= 2 ? 2 : 1).toUpperCase();
    }
    return (parts[0][0] + parts[1][0]).toUpperCase();
  }

  String _compactAmount(double value) {
    if (value >= 1000000) {
      return '₱${(value / 1000000).toStringAsFixed(1)}M';
    } else if (value >= 1000) {
      return '₱${(value / 1000).toStringAsFixed(value % 1000 == 0 ? 0 : 1)}k';
    }
    return '₱${value.toInt()}';
  }

  List<_ChartPoint> _buildDailyTrendPoints(
    List<ExpenseEntry> expenses,
    DateTime currentClock,
  ) {
    final List<_ChartPoint> points = <_ChartPoint>[];
    for (int i = 6; i >= 0; i--) {
      final DateTime day = DateTime(
        currentClock.year,
        currentClock.month,
        currentClock.day,
      ).subtract(Duration(days: i));

      double daySpent = 0;
      for (final ExpenseEntry e in expenses) {
        if (e.source == 'togetherSpend') continue;
        if (e.dateTime.year == day.year &&
            e.dateTime.month == day.month &&
            e.dateTime.day == day.day) {
          daySpent += e.amount;
        }
      }

      final String label = i == 0 ? 'Today' : DateFormat('E').format(day);
      points.add(_ChartPoint(
        index: (6 - i).toDouble(),
        value: daySpent,
        label: label,
        fullDate: DateFormat('MMM d').format(day),
      ));
    }
    return points;
  }

  List<_ChartPoint> _buildMonthlyTrendPoints(
    List<ExpenseEntry> expenses,
    DateTime currentClock,
  ) {
    final List<_ChartPoint> points = <_ChartPoint>[];
    for (int i = 5; i >= 0; i--) {
      final int yearOffset = (currentClock.month - i - 1) ~/ 12;
      final int month = ((currentClock.month - i - 1) % 12) + 1;
      final int year = currentClock.year + yearOffset;

      double monthSpent = 0;
      for (final ExpenseEntry e in expenses) {
        if (e.source == 'togetherSpend') continue;
        if (e.dateTime.year == year && e.dateTime.month == month) {
          monthSpent += e.amount;
        }
      }

      final DateTime monthDate = DateTime(year, month, 1);
      final String label =
          i == 0 ? 'This Mo' : DateFormat('MMM').format(monthDate);
      points.add(_ChartPoint(
        index: (5 - i).toDouble(),
        value: monthSpent,
        label: label,
        fullDate: DateFormat('MMMM yyyy').format(monthDate),
      ));
    }
    return points;
  }

  @override
  Widget build(BuildContext context) {
    final BudgetBuddyState state = ref.watch(budgetBuddyControllerProvider);
    final BudgetSummary summary = ref.watch(budgetSummaryProvider);
    final DateTime currentClock = state.effectiveDate;
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final _BentoTokens tokens = _BentoTokens(isDark);

    final bool isDaily = _selectedPeriod == DashboardPeriod.daily;
    final BudgetPeriodSummary activeSummary =
        summary.periodSummaries[_budgetPeriodFor(_selectedPeriod)] ??
            BudgetPeriodSummary(
              period: _budgetPeriodFor(_selectedPeriod),
              limit: 0,
              spent: 0,
            );

    final bool hasConfiguredBudget = state.settings.hasConfiguredBudget;
    final bool hasExpenses =
        state.expenses.any((ExpenseEntry e) => e.source != 'togetherSpend');

    final double totalBudget = isDaily
        ? (state.settings.dailyLimit ?? activeSummary.limit)
        : (state.settings.monthlyLimit ?? activeSummary.limit);
    final double spentAdjusted = activeSummary.spent;
    final double remainingAdjusted = totalBudget - spentAdjusted;
    final bool hasBudget = totalBudget > 0;
    final bool isOver = hasBudget && remainingAdjusted < 0;
    final bool isWarning =
        !isOver && hasBudget && spentAdjusted >= (totalBudget * 0.8);
    final double progressValue = totalBudget > 0
        ? (spentAdjusted / totalBudget).clamp(0.0, 1.0)
        : 0.0;

    final DateTime now = currentClock;
    final List<ExpenseEntry> periodExpenses =
        state.expenses.where((ExpenseEntry e) {
      if (e.source == 'togetherSpend') return false;
      if (isDaily) {
        return e.dateTime.year == now.year &&
            e.dateTime.month == now.month &&
            e.dateTime.day == now.day;
      } else {
        return e.dateTime.year == now.year && e.dateTime.month == now.month;
      }
    }).toList();

    return Scaffold(
      backgroundColor: tokens.scaffoldBg,
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onHorizontalDragEnd: _handleHorizontalDragEnd,
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            children: <Widget>[
              // 1. Header Section (Clean Greeting + Date + Avatar)
              _buildHeader(
                context,
                displayName: state.profile.displayName,
                currentClock: currentClock,
                tokens: tokens,
              ),
              const SizedBox(height: 14),

              // 2. Animated Timeframe Toggle (Solid Slider Effect)
              _buildTimeframeToggle(context, tokens),
              const SizedBox(height: 14),

              // 3. Top Metrics Bento Grid
              _buildMetricsBentoGrid(
                context,
                isDaily: isDaily,
                totalBudget: totalBudget,
                spent: spentAdjusted,
                remaining: remainingAdjusted,
                progressValue: progressValue,
                isOver: isOver,
                isWarning: isWarning,
                periodExpenseCount: periodExpenses.length,
                tokens: tokens,
              ),
              const SizedBox(height: 14),

              // Empty State (if no budget or no expenses)
              if (!hasConfiguredBudget || !hasExpenses) ...<Widget>[
                _buildEmptyState(
                  context,
                  hasConfiguredBudget: hasConfiguredBudget,
                  tokens: tokens,
                ),
                const SizedBox(height: 14),
              ],

              // 4. Analytics & Chart Bento Card
              if (hasConfiguredBudget && hasExpenses) ...<Widget>[
                _buildAnalyticsBentoCard(
                  context,
                  isDaily: isDaily,
                  allExpenses: state.expenses,
                  periodExpenses: periodExpenses,
                  currentClock: currentClock,
                  totalBudget: totalBudget,
                  spentAdjusted: spentAdjusted,
                  tokens: tokens,
                ),
                const SizedBox(height: 14),
              ],

              // 5. Recent Activity / Expense Preview
              _buildRecentActivityBentoCard(
                context,
                periodExpenses: periodExpenses,
                tokens: tokens,
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  /// 1. Clean Header Section with High-Contrast Typography & Profile Button
  Widget _buildHeader(
    BuildContext context, {
    required String displayName,
    required DateTime currentClock,
    required _BentoTokens tokens,
  }) {
    final String greeting = _getGreeting(currentClock.hour);
    final String name = displayName.trim().isNotEmpty
        ? displayName.trim().split(' ').first
        : 'Buddy';
    final String formattedDate =
        DateFormat('EEEE, MMM d, y').format(currentClock);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                '$greeting, $name',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
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
        ),
        const SizedBox(width: 12),
        // Clean Profile Avatar Button
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              if (widget.onOpenProfile != null) {
                widget.onOpenProfile!();
              } else {
                _showProfileSheet(context, displayName, tokens);
              }
            },
            borderRadius: BorderRadius.circular(14),
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: tokens.cardBg,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: tokens.cardBorder, width: 1.0),
              ),
              child: Center(
                child: Text(
                  _getInitials(displayName),
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: _BentoTokens.safeGreen,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _showProfileSheet(
    BuildContext context,
    String displayName,
    _BentoTokens tokens,
  ) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: tokens.cardBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: tokens.cardBorder,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 16),
                CircleAvatar(
                  radius: 28,
                  backgroundColor: tokens.tint(_BentoTokens.safeGreen, 0.12),
                  child: Text(
                    _getInitials(displayName),
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: _BentoTokens.safeGreen,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  displayName.trim().isNotEmpty ? displayName : 'Budget Buddy',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: tokens.textPrimary,
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () {
                          Navigator.of(sheetContext).pop();
                          widget.onOpenSavings?.call();
                        },
                        icon: const Icon(Icons.savings_rounded, size: 16),
                        label: const Text('Savings'),
                        style: FilledButton.styleFrom(
                          backgroundColor: _BentoTokens.safeGreen,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () {
                          Navigator.of(sheetContext).pop();
                          widget.onOpenExpenses?.call();
                        },
                        icon: const Icon(Icons.receipt_long_rounded, size: 16),
                        label: const Text('Expenses'),
                        style: FilledButton.styleFrom(
                          backgroundColor: _BentoTokens.expenseRed,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// 2. Clean Timeframe Pill Toggle (Solid Slider Effect, No Glassmorphism)
  Widget _buildTimeframeToggle(BuildContext context, _BentoTokens tokens) {
    final bool isDaily = _selectedPeriod == DashboardPeriod.daily;

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: tokens.toggleBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: tokens.cardBorder, width: 1.0),
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: GestureDetector(
              onTap: () {
                if (!isDaily) {
                  setState(() => _selectedPeriod = DashboardPeriod.daily);
                  ref
                      .read(budgetBuddyControllerProvider.notifier)
                      .setDashboardPeriod(DashboardPeriod.daily);
                }
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: isDaily ? _BentoTokens.safeGreen : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    Icon(
                      Icons.calendar_today_rounded,
                      size: 14,
                      color: isDaily ? Colors.white : tokens.textSecondary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Today',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        fontWeight: isDaily ? FontWeight.w700 : FontWeight.w600,
                        color: isDaily ? Colors.white : tokens.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: GestureDetector(
              onTap: () {
                if (isDaily) {
                  setState(() => _selectedPeriod = DashboardPeriod.monthly);
                  ref
                      .read(budgetBuddyControllerProvider.notifier)
                      .setDashboardPeriod(DashboardPeriod.monthly);
                }
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: !isDaily ? _BentoTokens.safeGreen : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    Icon(
                      Icons.calendar_month_rounded,
                      size: 14,
                      color: !isDaily ? Colors.white : tokens.textSecondary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Monthly',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        fontWeight:
                            !isDaily ? FontWeight.w700 : FontWeight.w600,
                        color: !isDaily ? Colors.white : tokens.textSecondary,
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

  /// 3. Top Metrics Bento Grid:
  /// - Hero Card: Safe Remaining Balance with Health Bar & Status Pill
  /// - Side/Sub Cards: 2 Equal-Width Bento Tiles (Budget Target & Total Spent)
  Widget _buildMetricsBentoGrid(
    BuildContext context, {
    required bool isDaily,
    required double totalBudget,
    required double spent,
    required double remaining,
    required double progressValue,
    required bool isOver,
    required bool isWarning,
    required int periodExpenseCount,
    required _BentoTokens tokens,
  }) {
    final bool hasBudget = totalBudget > 0;
    final Color heroAccent = !hasBudget
        ? _BentoTokens.budgetGold
        : (isOver ? _BentoTokens.expenseRed : _BentoTokens.safeGreen);

    return Column(
      children: <Widget>[
        // Hero Bento Card: Remaining Safe Balance
        BentoCard(
          padding: const EdgeInsets.all(18),
          borderRadius: 20,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              // Top Row: Icon + Label + Status Pill
              Row(
                children: <Widget>[
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: tokens.tint(heroAccent, 0.10),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      !hasBudget
                          ? Icons.savings_rounded
                          : (isOver
                              ? Icons.trending_down_rounded
                              : Icons.savings_rounded),
                      size: 16,
                      color: heroAccent,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      isDaily
                          ? 'Remaining Safe Balance'
                          : 'Monthly Safe Balance',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: tokens.textSecondary,
                      ),
                    ),
                  ),
                  SoftPill(
                    text: !hasBudget
                        ? 'No Budget Set'
                        : (isOver
                            ? 'Over Budget'
                            : (isWarning ? '80% Warning' : 'Safe to Spend')),
                    color: !hasBudget
                        ? _BentoTokens.budgetGold
                        : (isOver
                            ? _BentoTokens.expenseRed
                            : (isWarning
                                ? _BentoTokens.budgetGold
                                : _BentoTokens.safeGreen)),
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
              const SizedBox(height: 12),

              // Large Financial Value Display
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  !hasBudget
                      ? formatPeso(0)
                      : ((isOver ? '-' : '') + formatPeso(remaining.abs())),
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                    color: heroAccent,
                    letterSpacing: -1.0,
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // Visual Health Progress Bar
              BentoHealthBar(
                progress: progressValue,
                color: isOver
                    ? _BentoTokens.expenseRed
                    : (isWarning
                        ? _BentoTokens.budgetGold
                        : _BentoTokens.safeGreen),
                height: 8,
              ),
              const SizedBox(height: 8),

              // Progress Breakdown Sub-Row
              Row(
                children: <Widget>[
                  Text(
                    '${(progressValue * 100).toInt()}% budget spent',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: tokens.textSecondary,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${formatPeso(spent)} of ${formatPeso(totalBudget)}',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: tokens.textPrimary,
                    ),
                  ),
                ],
              ),

              // Over-Budget Alert Banner
              if (isOver) ...<Widget>[
                const SizedBox(height: 12),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: tokens.tint(_BentoTokens.expenseRed, 0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: _BentoTokens.expenseRed.withValues(alpha: 0.25),
                      width: 1.0,
                    ),
                  ),
                  child: Row(
                    children: <Widget>[
                      const Icon(
                        Icons.error_outline_rounded,
                        size: 15,
                        color: _BentoTokens.expenseRed,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Exceeded ${isDaily ? "today's" : "monthly"} budget limit by ${formatPeso(remaining.abs())}.',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: _BentoTokens.expenseRed,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Side/Sub Bento Cards: Total Target & Total Spent side-by-side
        Row(
          children: <Widget>[
            // Card 1: Total Budget Target (Gold)
            Expanded(
              child: BentoMetricTile(
                label: isDaily ? 'Target Budget' : 'Month Target',
                value: formatPeso(totalBudget),
                accentColor: _BentoTokens.budgetGold,
                icon: Icons.account_balance_wallet_rounded,
                subtitle: 'Allocated limit',
                onTap: widget.onGetStarted,
              ),
            ),
            const SizedBox(width: 12),
            // Card 2: Total Spent (Dark Red)
            Expanded(
              child: BentoMetricTile(
                label: isDaily ? 'Today\'s Spent' : 'Month Spent',
                value: formatPeso(spent),
                accentColor: _BentoTokens.expenseRed,
                icon: Icons.payments_rounded,
                subtitle:
                    '$periodExpenseCount ${periodExpenseCount == 1 ? "expense" : "expenses"}',
                onTap: widget.onOpenExpenses,
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// 4. Analytics & Chart Bento Card with Minimalist LineChart + Flat Gradient Fill
  Widget _buildAnalyticsBentoCard(
    BuildContext context, {
    required bool isDaily,
    required List<ExpenseEntry> allExpenses,
    required List<ExpenseEntry> periodExpenses,
    required DateTime currentClock,
    required double totalBudget,
    required double spentAdjusted,
    required _BentoTokens tokens,
  }) {
    final List<_ChartPoint> points = isDaily
        ? _buildDailyTrendPoints(allExpenses, currentClock)
        : _buildMonthlyTrendPoints(allExpenses, currentClock);

    double maxSpent = 0;
    for (final _ChartPoint pt in points) {
      if (pt.value > maxSpent) maxSpent = pt.value;
    }
    if (totalBudget > maxSpent) maxSpent = totalBudget;
    final double maxY = maxSpent <= 0 ? 500.0 : maxSpent * 1.15;

    // Group categories for category breakdown
    final Map<BudgetCategory, double> categoryTotals =
        <BudgetCategory, double>{};
    for (final ExpenseEntry e in periodExpenses) {
      categoryTotals[e.category] =
          (categoryTotals[e.category] ?? 0.0) + e.amount;
    }
    final List<MapEntry<BudgetCategory, double>> sortedCategories =
        categoryTotals.entries.toList()
          ..sort((MapEntry<BudgetCategory, double> a,
                  MapEntry<BudgetCategory, double> b) =>
              b.value.compareTo(a.value));

    final double safeSpent = spentAdjusted < 0 ? 0 : spentAdjusted;

    return BentoCard(
      padding: const EdgeInsets.all(18),
      borderRadius: 20,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // Header Row
          Row(
            children: <Widget>[
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: tokens.tint(_BentoTokens.safeGreen, 0.10),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.insights_rounded,
                  size: 16,
                  color: _BentoTokens.safeGreen,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Spending Analytics',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: tokens.textPrimary,
                  ),
                ),
              ),
              Text(
                isDaily ? 'Last 7 Days' : 'Last 6 Months',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: tokens.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Minimalist Line Chart
          SizedBox(
            height: 170,
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: (maxY / 3).clamp(1.0, double.infinity),
                  getDrawingHorizontalLine: (double value) => FlLine(
                    color: tokens.cardBorder.withValues(alpha: 0.6),
                    strokeWidth: 1.0,
                  ),
                ),
                titlesData: FlTitlesData(
                  show: true,
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 44,
                      interval: (maxY / 2).clamp(1.0, double.infinity),
                      getTitlesWidget: (double value, TitleMeta meta) {
                        if (value == meta.max || value == meta.min) {
                          return const SizedBox.shrink();
                        }
                        return Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: Text(
                            _compactAmount(value),
                            textAlign: TextAlign.right,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: tokens.textMuted,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 26,
                      interval: 1,
                      getTitlesWidget: (double value, TitleMeta meta) {
                        final int idx = value.toInt();
                        if (idx < 0 || idx >= points.length) {
                          return const SizedBox.shrink();
                        }
                        final bool isLast = idx == points.length - 1;
                        return Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            points[idx].label,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 10.5,
                              fontWeight:
                                  isLast ? FontWeight.w800 : FontWeight.w600,
                              color: isLast
                                  ? _BentoTokens.safeGreen
                                  : tokens.textSecondary,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                minX: 0,
                maxX: (points.length - 1).toDouble(),
                minY: 0,
                maxY: maxY,
                lineTouchData: LineTouchData(
                  handleBuiltInTouches: true,
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipColor: (LineBarSpot touchedSpot) => tokens.isDark
                        ? const Color(0xFF1E293B)
                        : const Color(0xFF0F172A),
                    tooltipBorder:
                        BorderSide(color: tokens.cardBorder, width: 1.0),
                    tooltipRoundedRadius: 8,
                    tooltipPadding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 6),
                    getTooltipItems: (List<LineBarSpot> touchedSpots) {
                      return touchedSpots.map((LineBarSpot barSpot) {
                        final int idx = barSpot.x.toInt();
                        final String dateStr = idx >= 0 && idx < points.length
                            ? points[idx].fullDate
                            : '';
                        return LineTooltipItem(
                          '$dateStr\n${formatPeso(barSpot.y)}',
                          GoogleFonts.plusJakartaSans(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        );
                      }).toList();
                    },
                  ),
                ),
                lineBarsData: <LineChartBarData>[
                  LineChartBarData(
                    spots: points
                        .map((_ChartPoint p) => FlSpot(p.index, p.value))
                        .toList(),
                    isCurved: true,
                    curveSmoothness: 0.30,
                    color: _BentoTokens.safeGreen,
                    barWidth: 3.0,
                    isStrokeCapRound: true,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (FlSpot spot, double xPercentage,
                          LineChartBarData bar, int index) {
                        final bool isLast = index == points.length - 1;
                        return FlDotCirclePainter(
                          radius: isLast ? 4.5 : 3.0,
                          color:
                              isLast ? _BentoTokens.safeGreen : tokens.cardBg,
                          strokeWidth: 2.0,
                          strokeColor: _BentoTokens.safeGreen,
                        );
                      },
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: <Color>[
                          _BentoTokens.safeGreen.withValues(alpha: 0.20),
                          _BentoTokens.safeGreen.withValues(alpha: 0.0),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Categories Breakdown Section (if expenses present)
          if (sortedCategories.isNotEmpty) ...<Widget>[
            const SizedBox(height: 18),
            Divider(color: tokens.cardBorder, height: 1),
            const SizedBox(height: 14),
            Row(
              children: <Widget>[
                Text(
                  'Top Categories',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: tokens.textPrimary,
                  ),
                ),
                const Spacer(),
                Text(
                  '${sortedCategories.length} categories',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: tokens.textSecondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ...sortedCategories.take(4).map(
              (MapEntry<BudgetCategory, double> entry) {
                final double catSpent = entry.value;
                final double catRatio = safeSpent > 0
                    ? (catSpent / safeSpent).clamp(0.0, 1.0)
                    : 0.0;
                final IconData icon = _iconForCategory(entry.key);

                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: tokens.subCardBg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: tokens.cardBorder, width: 1.0),
                    ),
                    child: Column(
                      children: <Widget>[
                        Row(
                          children: <Widget>[
                            Container(
                              padding: const EdgeInsets.all(5),
                              decoration: BoxDecoration(
                                color: tokens.tint(_BentoTokens.budgetGold, 0.10),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                icon,
                                color: _BentoTokens.budgetGold,
                                size: 13,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                entry.key.label,
                                style: GoogleFonts.plusJakartaSans(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12.5,
                                  color: tokens.textPrimary,
                                ),
                              ),
                            ),
                            Text(
                              formatPeso(catSpent),
                              style: GoogleFonts.plusJakartaSans(
                                fontWeight: FontWeight.w800,
                                fontSize: 13,
                                color: _BentoTokens.expenseRed,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        BentoHealthBar(
                          progress: catRatio,
                          color: _BentoTokens.budgetGold,
                          height: 4.5,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ],
      ),
    );
  }

  /// 5. Recent Activity / Expense Preview with Alpha-Tinted Category Icons & Bold Indicators
  Widget _buildRecentActivityBentoCard(
    BuildContext context, {
    required List<ExpenseEntry> periodExpenses,
    required _BentoTokens tokens,
  }) {
    final List<ExpenseEntry> recentItems = List<ExpenseEntry>.from(periodExpenses)
      ..sort((ExpenseEntry a, ExpenseEntry b) => b.dateTime.compareTo(a.dateTime));
    final List<ExpenseEntry> displayList = recentItems.take(4).toList();

    return BentoCard(
      padding: const EdgeInsets.all(18),
      borderRadius: 20,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // Header Row
          Row(
            children: <Widget>[
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: tokens.tint(_BentoTokens.budgetGold, 0.10),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.history_rounded,
                  size: 16,
                  color: _BentoTokens.budgetGold,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Recent Activity',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: tokens.textPrimary,
                  ),
                ),
              ),
              if (displayList.isNotEmpty)
                TextButton(
                  onPressed: widget.onOpenExpenses,
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    foregroundColor: _BentoTokens.safeGreen,
                  ),
                  child: Text(
                    'View all',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: _BentoTokens.safeGreen,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),

          if (displayList.isEmpty) ...<Widget>[
            Container(
              padding: const EdgeInsets.symmetric(vertical: 20),
              alignment: Alignment.center,
              child: Column(
                children: <Widget>[
                  Icon(
                    Icons.receipt_long_outlined,
                    size: 28,
                    color: tokens.textMuted,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'No expenses recorded yet',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: tokens.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: widget.onOpenSpend,
                    icon: const Icon(Icons.add, size: 15),
                    label: const Text('Log First Expense'),
                    style: TextButton.styleFrom(
                      foregroundColor: _BentoTokens.safeGreen,
                      textStyle: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ] else ...<Widget>[
            ...displayList.map((ExpenseEntry expense) {
              final IconData icon = _iconForCategory(expense.category);
              final String timeStr =
                  DateFormat('MMM d, h:mm a').format(expense.dateTime);

              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: widget.onOpenExpenses,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: tokens.subCardBg,
                        borderRadius: BorderRadius.circular(12),
                        border:
                            Border.all(color: tokens.cardBorder, width: 1.0),
                      ),
                      child: Row(
                        children: <Widget>[
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: tokens.tint(_BentoTokens.expenseRed, 0.10),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              icon,
                              size: 16,
                              color: _BentoTokens.expenseRed,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(
                                  expense.title.trim().isNotEmpty
                                      ? expense.title
                                      : expense.category.label,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: tokens.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  timeStr,
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                    color: tokens.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '- ${formatPeso(expense.amount)}',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: _BentoTokens.expenseRed,
                              letterSpacing: -0.3,
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
        ],
      ),
    );
  }

  /// Modern Flat Bento Empty State
  Widget _buildEmptyState(
    BuildContext context, {
    required bool hasConfiguredBudget,
    required _BentoTokens tokens,
  }) {
    final Color accentColor =
        hasConfiguredBudget ? _BentoTokens.safeGreen : _BentoTokens.budgetGold;

    return BentoCard(
      padding: const EdgeInsets.all(20),
      borderRadius: 20,
      child: Column(
        children: <Widget>[
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: tokens.tint(accentColor, 0.10),
              shape: BoxShape.circle,
              border: Border.all(
                color: accentColor.withValues(alpha: 0.25),
                width: 1.0,
              ),
            ),
            child: Icon(
              hasConfiguredBudget
                  ? Icons.receipt_long_rounded
                  : Icons.account_balance_wallet_rounded,
              size: 26,
              color: accentColor,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            hasConfiguredBudget
                ? 'No Expenses Logged Yet'
                : 'No Active Budget Set',
            textAlign: TextAlign.center,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: tokens.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            hasConfiguredBudget
                ? 'Your budget is ready. Tap Log Spend to start tracking your daily expenses.'
                : 'Set a daily or monthly budget to start tracking your allowance, spending, and savings.',
            textAlign: TextAlign.center,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: tokens.textSecondary,
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: hasConfiguredBudget
                ? widget.onOpenSpend
                : widget.onGetStarted,
            icon: Icon(
              hasConfiguredBudget
                  ? Icons.add_shopping_cart_rounded
                  : Icons.account_balance_wallet_rounded,
              size: 16,
              color: Colors.white,
            ),
            label: Text(
              hasConfiguredBudget ? 'Log First Spend' : 'Set Budget Now',
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.w700,
                fontSize: 13,
                color: Colors.white,
              ),
            ),
            style: FilledButton.styleFrom(
              backgroundColor: accentColor,
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(42),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
