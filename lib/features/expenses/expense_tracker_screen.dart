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

/// Clean Modern Bento Tokens for Expense Tracker Screen.
/// Emphasizes Dark Red (#991B1B) as primary expense accent with Dark Teal (#0F766E) and Gold (#D97706).
class _ExpensesTokens {
  const _ExpensesTokens(this.isDark);

  final bool isDark;

  // Primary Accent (Expenses)
  static const Color expenseRed = Color(0xFF991B1B);

  // Secondary Accents
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

enum _ExpenseViewMode {
  daily,
  monthly,
}

class ExpenseTrackerScreen extends ConsumerStatefulWidget {
  const ExpenseTrackerScreen({super.key, this.isTogetherOnly = false});

  final bool isTogetherOnly;

  @override
  ConsumerState<ExpenseTrackerScreen> createState() =>
      _ExpenseTrackerScreenState();
}

class _ExpenseTrackerScreenState extends ConsumerState<ExpenseTrackerScreen> {
  final TextEditingController _searchController = TextEditingController();
  BudgetCategory? _selectedCategory;
  _ExpenseViewMode _viewMode = _ExpenseViewMode.daily;
  DateTime? _selectedMonth;
  DateTime? _selectedDay;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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

  String _cleanNote(String note) {
    return note.replaceAll('[SPEND]', '').trim();
  }

  List<ExpenseEntry> _filterExpenses(
    List<ExpenseEntry> allExpenses,
    DateTime currentClock, {
    bool forceTodayOnly = false,
  }) {
    final String query = _searchController.text.trim().toLowerCase();

    return allExpenses.where((ExpenseEntry expense) {
      // Scope check
      if (widget.isTogetherOnly) {
        if (expense.source != 'togetherSpend') return false;
      } else {
        if (expense.source == 'togetherSpend') return false;
      }

      // Category filter
      if (_selectedCategory != null &&
          expense.category != _selectedCategory) {
        return false;
      }

      // Daily view: enforce today only
      if (forceTodayOnly) {
        final DateTime today =
            DateTime(currentClock.year, currentClock.month, currentClock.day);
        final DateTime eDay = DateTime(
            expense.dateTime.year, expense.dateTime.month, expense.dateTime.day);
        if (eDay != today) return false;
      }

      // Text query filter
      if (query.isNotEmpty) {
        final String title = expense.title.toLowerCase();
        final String note = expense.note.toLowerCase();
        final String cat = expense.category.label.toLowerCase();
        final String amountStr = expense.amount.toStringAsFixed(0);
        if (!title.contains(query) &&
            !note.contains(query) &&
            !cat.contains(query) &&
            !amountStr.contains(query)) {
          return false;
        }
      }

      return true;
    }).toList()
      ..sort((ExpenseEntry a, ExpenseEntry b) =>
          b.dateTime.compareTo(a.dateTime));
  }

  bool _isSameDayDate(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  double _getBudgetForDay(
    DateTime day,
    BudgetBuddyState state,
    DateTime currentClock,
  ) {
    final DateTime dayStart = DateTime(day.year, day.month, day.day);
    final BudgetEntry? entry =
        state.budgetEntries.cast<BudgetEntry?>().firstWhere(
              (BudgetEntry? e) => e != null && _isSameDayDate(e.date, dayStart),
              orElse: () => null,
            );
    if (entry != null) {
      return entry.amount;
    }
    final DailyRecord? record =
        state.dailyRecords.cast<DailyRecord?>().firstWhere(
              (DailyRecord? r) => r != null && _isSameDayDate(r.date, dayStart),
              orElse: () => null,
            );
    if (record != null && record.budget > 0) {
      return record.budget;
    }
    if (state.settings.hasConfiguredBudget) {
      return state.settings.dailyLimit ?? 0.0;
    }
    return 0.0;
  }

  Map<DateTime, Map<DateTime, List<ExpenseEntry>>> _groupExpensesByMonthAndDay(
    List<ExpenseEntry> list, {
    required BudgetBuddyState state,
    required DateTime currentClock,
    bool includeAllRecordedDays = true,
  }) {
    final Map<DateTime, Map<DateTime, List<ExpenseEntry>>> grouped =
        <DateTime, Map<DateTime, List<ExpenseEntry>>>{};

    if (includeAllRecordedDays) {
      final Set<DateTime> knownDates = <DateTime>{};
      for (final DailyRecord r in state.dailyRecords) {
        knownDates.add(DateTime(r.date.year, r.date.month, r.date.day));
      }
      for (final ExpenseEntry e in state.expenses) {
        if (widget.isTogetherOnly
            ? e.source == 'togetherSpend'
            : e.source != 'togetherSpend') {
          knownDates
              .add(DateTime(e.dateTime.year, e.dateTime.month, e.dateTime.day));
        }
      }
      for (final BudgetEntry b in state.budgetEntries) {
        knownDates.add(DateTime(b.date.year, b.date.month, b.date.day));
      }
      if (state.settings.budgetCreatedAt != null) {
        final DateTime bCreated = state.settings.budgetCreatedAt!;
        knownDates.add(DateTime(bCreated.year, bCreated.month, bCreated.day));
      }
      final DateTime today =
          DateTime(currentClock.year, currentClock.month, currentClock.day);
      knownDates.add(today);

      for (final DateTime day in knownDates) {
        final DateTime monthKey = DateTime(day.year, day.month);
        final DateTime dayKey = DateTime(day.year, day.month, day.day);
        grouped
            .putIfAbsent(monthKey, () => <DateTime, List<ExpenseEntry>>{})
            .putIfAbsent(dayKey, () => <ExpenseEntry>[]);
      }
    }

    for (final ExpenseEntry item in list) {
      final DateTime monthKey =
          DateTime(item.dateTime.year, item.dateTime.month);
      final DateTime dayKey =
          DateTime(item.dateTime.year, item.dateTime.month, item.dateTime.day);

      grouped
          .putIfAbsent(monthKey, () => <DateTime, List<ExpenseEntry>>{})
          .putIfAbsent(dayKey, () => <ExpenseEntry>[])
          .add(item);
    }

    return grouped;
  }

  @override
  Widget build(BuildContext context) {
    final BudgetBuddyState state = ref.watch(budgetBuddyControllerProvider);
    final DateTime currentClock = state.effectiveDate;
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final _ExpensesTokens tokens = _ExpensesTokens(isDark);

    final bool isDaily = _viewMode == _ExpenseViewMode.daily;
    final bool isFiltering =
        _searchController.text.trim().isNotEmpty || _selectedCategory != null;

    final List<ExpenseEntry> displayExpenses = _filterExpenses(
      state.expenses,
      currentClock,
      forceTodayOnly: isDaily,
    );

    final Map<DateTime, Map<DateTime, List<ExpenseEntry>>> monthDayGroups =
        _groupExpensesByMonthAndDay(
      displayExpenses,
      state: state,
      currentClock: currentClock,
      includeAllRecordedDays: !isFiltering,
    );
    final List<DateTime> sortedMonths = monthDayGroups.keys.toList()
      ..sort((DateTime a, DateTime b) => b.compareTo(a));

    // Reconcile selection state if filtered or deleted
    if (_selectedMonth != null && !monthDayGroups.containsKey(_selectedMonth)) {
      _selectedMonth = null;
      _selectedDay = null;
    } else if (_selectedMonth != null && _selectedDay != null) {
      final Map<DateTime, List<ExpenseEntry>>? daysMap =
          monthDayGroups[_selectedMonth];
      if (daysMap == null || !daysMap.containsKey(_selectedDay)) {
        _selectedDay = null;
      }
    }

    final double todayBudget =
        _getBudgetForDay(currentClock, state, currentClock);

    // Determine summary card amounts and labels based on view mode and active selection
    final double summaryTotalAmount;
    final int summaryCount;
    final String summaryLabel;
    final String summaryPillText;

    if (isDaily) {
      summaryTotalAmount = displayExpenses.fold<double>(
          0.0, (double sum, ExpenseEntry e) => sum + e.amount);
      summaryCount = displayExpenses.length;
      summaryLabel = "Today's Total Outlays";
      if (displayExpenses.isEmpty) {
        summaryPillText = todayBudget > 0
            ? 'Full ${formatPeso(todayBudget)} unspent'
            : '0 expenses today';
      } else {
        summaryPillText =
            '$summaryCount ${summaryCount == 1 ? "expense today" : "expenses today"}';
      }
    } else if (_selectedMonth != null && _selectedDay != null) {
      final List<ExpenseEntry> dayItems =
          monthDayGroups[_selectedMonth]?[_selectedDay] ?? <ExpenseEntry>[];
      final double dayBudget =
          _getBudgetForDay(_selectedDay!, state, currentClock);
      summaryTotalAmount = dayItems.fold<double>(
          0.0, (double sum, ExpenseEntry e) => sum + e.amount);
      summaryCount = dayItems.length;
      summaryLabel =
          'Spent on ${DateFormat("MMMM d, yyyy").format(_selectedDay!)}';
      if (dayItems.isEmpty) {
        summaryPillText = dayBudget > 0
            ? 'Full ${formatPeso(dayBudget)} unspent'
            : '0 expenses';
      } else {
        summaryPillText =
            '$summaryCount ${summaryCount == 1 ? "expense" : "expenses"}';
      }
    } else if (_selectedMonth != null) {
      final Map<DateTime, List<ExpenseEntry>> daysMap =
          monthDayGroups[_selectedMonth] ?? <DateTime, List<ExpenseEntry>>{};
      summaryTotalAmount = daysMap.values.fold<double>(
        0.0,
        (double sum, List<ExpenseEntry> list) =>
            sum +
            list.fold<double>(0.0, (double s, ExpenseEntry e) => s + e.amount),
      );
      summaryCount = daysMap.values.fold<int>(
        0,
        (int count, List<ExpenseEntry> list) => count + list.length,
      );
      summaryLabel =
          'Total Spent in ${DateFormat("MMMM yyyy").format(_selectedMonth!)}';
      summaryPillText =
          '$summaryCount ${summaryCount == 1 ? "expense" : "expenses"}';
    } else {
      summaryTotalAmount = displayExpenses.fold<double>(
          0.0, (double sum, ExpenseEntry e) => sum + e.amount);
      summaryCount = displayExpenses.length;
      summaryLabel = 'Monthly Log Outlays';
      summaryPillText =
          '$summaryCount ${summaryCount == 1 ? "expense" : "expenses"}';
    }

    return Scaffold(
      backgroundColor: tokens.scaffoldBg,
      body: SafeArea(
        child: CustomScrollView(
          slivers: <Widget>[
            // 1. Header, Segmented Toggle, Search, Filter & Summary Card
            SliverToBoxAdapter(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    // Back button if in together mode
                    if (widget.isTogetherOnly &&
                        Navigator.of(context).canPop()) ...<Widget>[
                      Align(
                        alignment: Alignment.centerLeft,
                        child: FilledButton.icon(
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(Icons.arrow_back_rounded,
                              size: 15, color: Colors.white),
                          label: const Text('Back'),
                          style: FilledButton.styleFrom(
                            backgroundColor: _ExpensesTokens.safeGreen,
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
                    const SizedBox(height: 12),

                    // Daily vs Monthly Segmented View Toggle
                    _buildViewModeToggle(tokens),
                    const SizedBox(height: 12),

                    // Search Input Field
                    _buildSearchBar(tokens),
                    const SizedBox(height: 12),

                    // Category Filter Chips
                    _buildCategoryFilterRow(tokens),
                    const SizedBox(height: 12),

                    // Filtered Total Summary Bento Card
                    _buildFilteredSummaryCard(
                      totalAmount: summaryTotalAmount,
                      count: summaryCount,
                      tokens: tokens,
                      customLabel: summaryLabel,
                      customPillText: summaryPillText,
                    ),
                  ],
                ),
              ),
            ),

            // 2. Content Slivers based on view mode and selection
            if (isDaily) ...<Widget>[
              if (displayExpenses.isEmpty)
                if (isFiltering)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: _buildEmptyDailyState(tokens),
                    ),
                  )
                else
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                      child: _buildTodayLogCard(
                        dayBudget: todayBudget,
                        currentClock: currentClock,
                        tokens: tokens,
                      ),
                    ),
                  )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (BuildContext context, int index) {
                        final ExpenseEntry expense = displayExpenses[index];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: _buildTransactionTile(
                            context,
                            expense: expense,
                            tokens: tokens,
                          ),
                        );
                      },
                      childCount: displayExpenses.length,
                    ),
                  ),
                ),
            ] else if (_selectedMonth == null) ...<Widget>[
              // Monthly View - Tier 1: Months List
              if (sortedMonths.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: _buildEmptyState(tokens),
                  ),
                )
              else ...<Widget>[
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                    child: Row(
                      children: <Widget>[
                        Text(
                          'Available Months',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: tokens.textSecondary,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          'Tap a month to view days',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: tokens.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (BuildContext context, int index) {
                        final DateTime month = sortedMonths[index];
                        final Map<DateTime, List<ExpenseEntry>> daysMap =
                            monthDayGroups[month] ??
                                <DateTime, List<ExpenseEntry>>{};
                        return _buildMonthCard(
                          context: context,
                          month: month,
                          daysMap: daysMap,
                          tokens: tokens,
                          onTap: () {
                            setState(() {
                              _selectedMonth = month;
                              _selectedDay = null;
                            });
                          },
                        );
                      },
                      childCount: sortedMonths.length,
                    ),
                  ),
                ),
              ],
            ] else if (_selectedDay == null) ...<Widget>[
              // Monthly View - Tier 2: Days in Selected Month
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: Row(
                    children: <Widget>[
                      FilledButton.icon(
                        onPressed: () {
                          setState(() {
                            _selectedMonth = null;
                            _selectedDay = null;
                          });
                        },
                        icon: const Icon(Icons.arrow_back_rounded,
                            size: 15, color: Colors.white),
                        label: const Text('All Months'),
                        style: FilledButton.styleFrom(
                          backgroundColor: _ExpensesTokens.safeGreen,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 8),
                          visualDensity: VisualDensity.compact,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              DateFormat('MMMM yyyy').format(_selectedMonth!),
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: tokens.textPrimary,
                              ),
                            ),
                            Text(
                              'Select a day to view spending',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 11.5,
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
              ),
              Builder(
                builder: (BuildContext context) {
                  final Map<DateTime, List<ExpenseEntry>> daysMap =
                      monthDayGroups[_selectedMonth] ??
                          <DateTime, List<ExpenseEntry>>{};
                  final List<DateTime> sortedDays = daysMap.keys.toList()
                    ..sort((DateTime a, DateTime b) => b.compareTo(a));

                  if (sortedDays.isEmpty) {
                    return SliverFillRemaining(
                      hasScrollBody: false,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: _buildEmptyState(tokens),
                      ),
                    );
                  }

                  return SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (BuildContext context, int index) {
                          final DateTime day = sortedDays[index];
                          final List<ExpenseEntry> dayItems =
                              daysMap[day] ?? <ExpenseEntry>[];
                          final double dayBudget =
                              _getBudgetForDay(day, state, currentClock);
                          return _buildDayCard(
                            context: context,
                            day: day,
                            dayItems: dayItems,
                            dayBudget: dayBudget,
                            currentClock: currentClock,
                            tokens: tokens,
                            onTap: () {
                              setState(() {
                                _selectedDay = day;
                              });
                            },
                          );
                        },
                        childCount: sortedDays.length,
                      ),
                    ),
                  );
                },
              ),
            ] else ...<Widget>[
              // Monthly View - Tier 3: Day Spent & Transactions
              Builder(
                builder: (BuildContext context) {
                  final Map<DateTime, List<ExpenseEntry>> daysMap =
                      monthDayGroups[_selectedMonth] ??
                          <DateTime, List<ExpenseEntry>>{};
                  final List<DateTime> sortedDays = daysMap.keys.toList()
                    ..sort((DateTime a, DateTime b) => b.compareTo(a));
                  final List<ExpenseEntry> dayItems =
                      daysMap[_selectedDay] ?? <ExpenseEntry>[];

                  return SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Row(
                            children: <Widget>[
                              FilledButton.icon(
                                onPressed: () {
                                  setState(() {
                                    _selectedDay = null;
                                  });
                                },
                                icon: const Icon(Icons.arrow_back_rounded,
                                    size: 15, color: Colors.white),
                                label: Text(
                                    'Days in ${DateFormat('MMMM').format(_selectedMonth!)}'),
                                style: FilledButton.styleFrom(
                                  backgroundColor: _ExpensesTokens.safeGreen,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 14, vertical: 8),
                                  visualDensity: VisualDensity.compact,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                              ),
                              const Spacer(),
                              TextButton(
                                onPressed: () {
                                  setState(() {
                                    _selectedMonth = null;
                                    _selectedDay = null;
                                  });
                                },
                                style: TextButton.styleFrom(
                                  foregroundColor: _ExpensesTokens.safeGreen,
                                  visualDensity: VisualDensity.compact,
                                ),
                                child: const Text(
                                  'All Months',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          // Horizontal quick day selector
                          _buildDayChipsRow(
                            sortedDays: sortedDays,
                            selectedDay: _selectedDay!,
                            currentClock: currentClock,
                            tokens: tokens,
                            onSelect: (DateTime d) {
                              setState(() {
                                _selectedDay = d;
                              });
                            },
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: <Widget>[
                              Icon(
                                Icons.receipt_long_rounded,
                                size: 16,
                                color: _ExpensesTokens.expenseRed,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Spent on ${DateFormat('EEEE, MMMM d').format(_selectedDay!)}',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                  color: tokens.textPrimary,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
              Builder(
                builder: (BuildContext context) {
                  final List<ExpenseEntry> dayItems =
                      monthDayGroups[_selectedMonth]?[_selectedDay] ??
                          <ExpenseEntry>[];
                  final double dayBudget =
                      _getBudgetForDay(_selectedDay!, state, currentClock);

                  if (dayItems.isEmpty) {
                    if (isFiltering) {
                      return SliverFillRemaining(
                        hasScrollBody: false,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: _buildEmptyState(tokens),
                        ),
                      );
                    }
                    return SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                        child: _buildEmptyDayLogCard(
                          day: _selectedDay!,
                          dayBudget: dayBudget,
                          tokens: tokens,
                        ),
                      ),
                    );
                  }

                  return SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (BuildContext context, int index) {
                          final ExpenseEntry expense = dayItems[index];
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: _buildTransactionTile(
                              context,
                              expense: expense,
                              tokens: tokens,
                            ),
                          );
                        },
                        childCount: dayItems.length,
                      ),
                    ),
                  );
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// 1. Screen Title Header
  Widget _buildHeader(
    BuildContext context,
    DateTime currentClock,
    _ExpensesTokens tokens,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: <Widget>[
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              widget.isTogetherOnly
                  ? 'Together Expense Log'
                  : 'Expense History & Log',
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
          text: widget.isTogetherOnly ? 'Together' : 'Personal',
          color: widget.isTogetherOnly
              ? _ExpensesTokens.budgetGold
              : _ExpensesTokens.safeGreen,
          icon: widget.isTogetherOnly
              ? Icons.groups_rounded
              : Icons.person_rounded,
          fontSize: 11,
        ),
      ],
    );
  }

  /// View Mode Toggle: Today's Expense vs Monthly Expense
  Widget _buildViewModeToggle(_ExpensesTokens tokens) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: tokens.subCardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: tokens.cardBorder, width: 1.0),
      ),
      child: Row(
        children: <Widget>[
          // 1. Today's Expense
          Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () {
                if (_viewMode != _ExpenseViewMode.daily) {
                  setState(() => _viewMode = _ExpenseViewMode.daily);
                }
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(vertical: 9),
                decoration: BoxDecoration(
                  color: _viewMode == _ExpenseViewMode.daily
                      ? _ExpensesTokens.safeGreen
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    Icon(
                      Icons.today_rounded,
                      size: 14,
                      color: _viewMode == _ExpenseViewMode.daily
                          ? Colors.white
                          : tokens.textSecondary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      "Today's Expense",
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        fontWeight: _viewMode == _ExpenseViewMode.daily
                            ? FontWeight.w800
                            : FontWeight.w600,
                        color: _viewMode == _ExpenseViewMode.daily
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

          // 2. Monthly Expense
          Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () {
                setState(() {
                  if (_viewMode == _ExpenseViewMode.monthly) {
                    _selectedMonth = null;
                    _selectedDay = null;
                  } else {
                    _viewMode = _ExpenseViewMode.monthly;
                  }
                });
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(vertical: 9),
                decoration: BoxDecoration(
                  color: _viewMode == _ExpenseViewMode.monthly
                      ? _ExpensesTokens.safeGreen
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    Icon(
                      Icons.calendar_month_rounded,
                      size: 14,
                      color: _viewMode == _ExpenseViewMode.monthly
                          ? Colors.white
                          : tokens.textSecondary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Monthly Expense',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        fontWeight: _viewMode == _ExpenseViewMode.monthly
                            ? FontWeight.w800
                            : FontWeight.w600,
                        color: _viewMode == _ExpenseViewMode.monthly
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

  /// Search Bar with Instant Clear Button
  Widget _buildSearchBar(_ExpensesTokens tokens) {
    return Container(
      decoration: BoxDecoration(
        color: tokens.cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: tokens.cardBorder, width: 1.0),
      ),
      child: TextField(
        controller: _searchController,
        onChanged: (_) => setState(() {}),
        style: GoogleFonts.plusJakartaSans(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: tokens.textPrimary,
        ),
        decoration: InputDecoration(
          isDense: true,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          border: InputBorder.none,
          hintText: _viewMode == _ExpenseViewMode.daily
              ? "Search today's expenses..."
              : 'Search expenses by name, category, or note...',
          hintStyle: GoogleFonts.plusJakartaSans(
            fontSize: 12.5,
            fontWeight: FontWeight.w500,
            color: tokens.textMuted,
          ),
          prefixIcon: Icon(
            Icons.search_rounded,
            color: tokens.textSecondary,
            size: 19,
          ),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear_rounded, size: 18),
                  color: tokens.textSecondary,
                  onPressed: () {
                    _searchController.clear();
                    setState(() {});
                  },
                )
              : null,
        ),
      ),
    );
  }

  /// Category Filter Row
  Widget _buildCategoryFilterRow(_ExpensesTokens tokens) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: <Widget>[
          // 'All' Chip
          _buildCategoryChip(
            label: 'All Categories',
            isSelected: _selectedCategory == null,
            icon: Icons.all_inclusive_rounded,
            onTap: () => setState(() => _selectedCategory = null),
            tokens: tokens,
          ),
          ...BudgetCategory.values.map((BudgetCategory category) {
            return _buildCategoryChip(
              label: category.label,
              isSelected: _selectedCategory == category,
              icon: _iconForCategory(category),
              onTap: () => setState(() => _selectedCategory = category),
              tokens: tokens,
            );
          }),
        ],
      ),
    );
  }

  Widget _buildCategoryChip({
    required String label,
    required bool isSelected,
    required IconData icon,
    required VoidCallback onTap,
    required _ExpensesTokens tokens,
  }) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(999),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: isSelected
                  ? _ExpensesTokens.safeGreen
                  : tokens.cardBg,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: isSelected
                    ? _ExpensesTokens.safeGreen
                    : tokens.cardBorder,
                width: 1.0,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(
                  icon,
                  size: 13,
                  color: isSelected ? Colors.white : tokens.textSecondary,
                ),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11.5,
                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                    color: isSelected ? Colors.white : tokens.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Summary Bento Card
  Widget _buildFilteredSummaryCard({
    required double totalAmount,
    required int count,
    required _ExpensesTokens tokens,
    String? customLabel,
    String? customPillText,
  }) {
    final String label = customLabel ??
        (_viewMode == _ExpenseViewMode.daily
            ? "Today's Total Outlays"
            : 'Monthly Log Outlays');
    final String pillText = customPillText ??
        (_viewMode == _ExpenseViewMode.daily
            ? '$count ${count == 1 ? "expense today" : "expenses today"}'
            : '$count ${count == 1 ? "expense" : "expenses"}');

    return BentoCard(
      padding: const EdgeInsets.all(16),
      borderRadius: 20,
      borderColor: _ExpensesTokens.expenseRed.withValues(alpha: 0.30),
      child: Row(
        children: <Widget>[
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: tokens.tint(_ExpensesTokens.expenseRed, 0.10),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.receipt_long_rounded,
              size: 20,
              color: _ExpensesTokens.expenseRed,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  label,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: tokens.textSecondary,
                  ),
                ),
                const SizedBox(height: 2),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    formatPeso(totalAmount),
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      color: _ExpensesTokens.expenseRed,
                      letterSpacing: -0.8,
                    ),
                  ),
                ),
              ],
            ),
          ),
          SoftPill(
            text: pillText,
            color: _ExpensesTokens.budgetGold,
            fontSize: 11,
          ),
        ],
      ),
    );
  }

  /// Month Card (Tier 1: List of months)
  Widget _buildMonthCard({
    required BuildContext context,
    required DateTime month,
    required Map<DateTime, List<ExpenseEntry>> daysMap,
    required _ExpensesTokens tokens,
    required VoidCallback onTap,
  }) {
    final List<DateTime> sortedDays = daysMap.keys.toList()
      ..sort((DateTime a, DateTime b) => b.compareTo(a));

    final double monthTotal = daysMap.values.fold<double>(
      0.0,
      (double sum, List<ExpenseEntry> list) =>
          sum +
          list.fold<double>(0.0, (double s, ExpenseEntry e) => s + e.amount),
    );

    final int totalMonthItems = daysMap.values.fold<int>(
      0,
      (int count, List<ExpenseEntry> list) => count + list.length,
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: tokens.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: tokens.cardBorder, width: 1.0),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: <Widget>[
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: tokens.tint(_ExpensesTokens.budgetGold, 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.calendar_month_rounded,
                    size: 20,
                    color: _ExpensesTokens.budgetGold,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        DateFormat('MMMM yyyy').format(month),
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 15.5,
                          fontWeight: FontWeight.w800,
                          color: tokens.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${sortedDays.length} ${sortedDays.length == 1 ? "day recorded" : "days recorded"} • $totalMonthItems ${totalMonthItems == 1 ? "expense" : "expenses"}',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: tokens.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: <Widget>[
                    Text(
                      monthTotal > 0 ? '- ${formatPeso(monthTotal)}' : '₱0.00',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        color: monthTotal > 0
                            ? _ExpensesTokens.expenseRed
                            : tokens.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Text(
                          'View Days',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: _ExpensesTokens.safeGreen,
                          ),
                        ),
                        const SizedBox(width: 3),
                        const Icon(
                          Icons.arrow_forward_ios_rounded,
                          size: 10,
                          color: _ExpensesTokens.safeGreen,
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Day Card (Tier 2: List of days in the selected month)
  Widget _buildDayCard({
    required BuildContext context,
    required DateTime day,
    required List<ExpenseEntry> dayItems,
    required double dayBudget,
    required DateTime currentClock,
    required _ExpensesTokens tokens,
    required VoidCallback onTap,
  }) {
    final double dayTotal = dayItems.fold<double>(
        0.0, (double sum, ExpenseEntry e) => sum + e.amount);

    final DateTime today =
        DateTime(currentClock.year, currentClock.month, currentClock.day);
    final DateTime yesterday = today.subtract(const Duration(days: 1));
    final bool isToday = DateUtils.isSameDay(day, today);
    final bool isYesterday = DateUtils.isSameDay(day, yesterday);

    final String dayLabel = isToday
        ? 'Today, ${DateFormat('MMMM d').format(day)}'
        : (isYesterday
            ? 'Yesterday, ${DateFormat('MMMM d').format(day)}'
            : DateFormat('EEEE, MMMM d').format(day));

    final String subtitleText;
    final String amountText;
    final Color amountColor;
    final String actionText;

    if (dayItems.isNotEmpty) {
      subtitleText =
          '${dayItems.length} ${dayItems.length == 1 ? "expense" : "expenses"} logged${dayBudget > 0 ? " • Budget " + formatPeso(dayBudget) : ""}';
      amountText = '- ${formatPeso(dayTotal)}';
      amountColor = _ExpensesTokens.expenseRed;
      actionText = 'View Spent';
    } else if (dayBudget > 0) {
      subtitleText = 'Full budget unspent (${formatPeso(dayBudget)} saved)';
      amountText = '₱0.00';
      amountColor = _ExpensesTokens.safeGreen;
      actionText = 'View Day';
    } else {
      subtitleText = 'No budget configured • ₱0.00 spent';
      amountText = '₱0.00';
      amountColor = tokens.textSecondary;
      actionText = 'View Day';
    }

    final IconData dayIcon = dayItems.isNotEmpty
        ? (isToday ? Icons.today_rounded : Icons.receipt_long_rounded)
        : (dayBudget > 0
            ? Icons.savings_rounded
            : Icons.event_available_rounded);

    final Color iconColor = dayItems.isNotEmpty
        ? (isToday ? _ExpensesTokens.safeGreen : _ExpensesTokens.budgetGold)
        : (dayBudget > 0 ? _ExpensesTokens.safeGreen : tokens.textSecondary);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: tokens.cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isToday
              ? _ExpensesTokens.safeGreen.withValues(alpha: 0.40)
              : tokens.cardBorder,
          width: 1.0,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: <Widget>[
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: tokens.tint(iconColor, 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    dayIcon,
                    size: 16,
                    color: iconColor,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        dayLabel,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: tokens.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitleText,
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
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: <Widget>[
                    Text(
                      amountText,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        color: amountColor,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Text(
                          actionText,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            color: _ExpensesTokens.safeGreen,
                          ),
                        ),
                        const SizedBox(width: 3),
                        const Icon(
                          Icons.arrow_forward_ios_rounded,
                          size: 9,
                          color: _ExpensesTokens.safeGreen,
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Horizontal Quick Day Switcher (Tier 3)
  Widget _buildDayChipsRow({
    required List<DateTime> sortedDays,
    required DateTime selectedDay,
    required DateTime currentClock,
    required _ExpensesTokens tokens,
    required ValueChanged<DateTime> onSelect,
  }) {
    if (sortedDays.length <= 1) return const SizedBox.shrink();

    final DateTime today =
        DateTime(currentClock.year, currentClock.month, currentClock.day);

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: sortedDays.map((DateTime d) {
          final bool isSelected = DateUtils.isSameDay(d, selectedDay);
          final bool isToday = DateUtils.isSameDay(d, today);
          final String chipLabel = isToday
              ? 'Today (${DateFormat('d').format(d)})'
              : DateFormat('MMM d').format(d);

          return Padding(
            padding: const EdgeInsets.only(right: 6),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => onSelect(d),
                borderRadius: BorderRadius.circular(20),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? _ExpensesTokens.safeGreen
                        : tokens.subCardBg,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isSelected
                          ? _ExpensesTokens.safeGreen
                          : tokens.cardBorder,
                      width: 1.0,
                    ),
                  ),
                  child: Text(
                    chipLabel,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11.5,
                      fontWeight:
                          isSelected ? FontWeight.w800 : FontWeight.w600,
                      color: isSelected ? Colors.white : tokens.textPrimary,
                    ),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  /// Card shown in Today's Expense when 0 expenses have been logged today
  Widget _buildTodayLogCard({
    required double dayBudget,
    required DateTime currentClock,
    required _ExpensesTokens tokens,
  }) {
    final bool hasBudget = dayBudget > 0;
    return BentoCard(
      padding: const EdgeInsets.all(18),
      borderRadius: 18,
      borderColor: hasBudget
          ? _ExpensesTokens.safeGreen.withValues(alpha: 0.35)
          : tokens.cardBorder,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: tokens.tint(
                    hasBudget
                        ? _ExpensesTokens.safeGreen
                        : _ExpensesTokens.budgetGold,
                    0.12,
                  ),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  hasBudget ? Icons.savings_rounded : Icons.today_rounded,
                  size: 20,
                  color: hasBudget
                      ? _ExpensesTokens.safeGreen
                      : _ExpensesTokens.budgetGold,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      hasBudget
                          ? "Today's Log: Full Budget Unspent"
                          : "Today's Log: No Expenses Yet",
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: tokens.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      hasBudget
                          ? '₱0.00 spent out of ${formatPeso(dayBudget)} budget'
                          : '₱0.00 spent • No daily budget configured',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: tokens.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              SoftPill(
                text: hasBudget ? 'Full Saved' : '0 Spent',
                color: hasBudget
                    ? _ExpensesTokens.safeGreen
                    : _ExpensesTokens.budgetGold,
                fontSize: 11,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            hasBudget
                ? 'Your full allowance is safely preserved. Any expenses you add today will be deducted from this budget and logged here in real-time.'
                : 'You have not spent anything today. Set a daily budget or log an expense to track your daily allowance.',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 11.5,
              fontWeight: FontWeight.w500,
              color: tokens.textSecondary,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  /// Card shown in Tier 3 when a day has 0 logged expenses
  Widget _buildEmptyDayLogCard({
    required DateTime day,
    required double dayBudget,
    required _ExpensesTokens tokens,
  }) {
    final bool hasBudget = dayBudget > 0;
    return BentoCard(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      borderRadius: 18,
      borderColor: hasBudget
          ? _ExpensesTokens.safeGreen.withValues(alpha: 0.35)
          : tokens.cardBorder,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: tokens.tint(
                hasBudget
                    ? _ExpensesTokens.safeGreen
                    : _ExpensesTokens.budgetGold,
                0.12,
              ),
              shape: BoxShape.circle,
            ),
            child: Icon(
              hasBudget
                  ? Icons.savings_rounded
                  : Icons.event_available_rounded,
              size: 28,
              color: hasBudget
                  ? _ExpensesTokens.safeGreen
                  : _ExpensesTokens.budgetGold,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            hasBudget ? 'Full Budget Unspent!' : 'No Expenses Logged',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: tokens.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            hasBudget
                ? 'Full daily allowance of ${formatPeso(dayBudget)} was unspent and logged as savings for ${DateFormat('MMMM d, yyyy').format(day)}.'
                : 'No spending was recorded and no budget was set for ${DateFormat('MMMM d, yyyy').format(day)} (₱0.00 spent).',
            textAlign: TextAlign.center,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: tokens.textSecondary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),
          SoftPill(
            text: hasBudget ? 'Saved to History Log' : 'Recorded in History Log',
            color: hasBudget
                ? _ExpensesTokens.safeGreen
                : _ExpensesTokens.budgetGold,
            fontSize: 11,
          ),
        ],
      ),
    );
  }

  /// Empty State for Daily View
  Widget _buildEmptyDailyState(_ExpensesTokens tokens) {
    return Center(
      child: BentoCard(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        borderRadius: 20,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: tokens.tint(_ExpensesTokens.expenseRed, 0.10),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.receipt_long_outlined,
                size: 32,
                color: _ExpensesTokens.expenseRed,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'No Expenses Today',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: tokens.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _searchController.text.isNotEmpty || _selectedCategory != null
                  ? 'No expenses today match your search or filter.'
                  : "You haven't spent anything today. Keep up the good savings!",
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12.5,
                fontWeight: FontWeight.w500,
                color: tokens.textSecondary,
              ),
            ),
            if (_searchController.text.isNotEmpty ||
                _selectedCategory != null) ...<Widget>[
              const SizedBox(height: 16),
              FilledButton.tonal(
                onPressed: () {
                  setState(() {
                    _searchController.clear();
                    _selectedCategory = null;
                  });
                },
                child: Text(
                  'Reset Filters',
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w700,
                    fontSize: 12.5,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// 4. Transaction Card Tile
  Widget _buildTransactionTile(
    BuildContext context, {
    required ExpenseEntry expense,
    required _ExpensesTokens tokens,
  }) {
    final IconData icon = _iconForCategory(expense.category);
    final String cleanNoteText = _cleanNote(expense.note);
    final String timeStr = DateFormat('h:mm a').format(expense.dateTime);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _showExpenseDetailsSheet(context, expense, tokens),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: tokens.cardBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: tokens.cardBorder, width: 1.0),
          ),
          child: Row(
            children: <Widget>[
              // Category Icon in 10% alpha circular box
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: tokens.tint(_ExpensesTokens.expenseRed, 0.10),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  size: 16,
                  color: _ExpensesTokens.expenseRed,
                ),
              ),
              const SizedBox(width: 12),

              // Title, Subtitle, Category Pill
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
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: tokens.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: <Widget>[
                        Text(
                          timeStr,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: tokens.textSecondary,
                          ),
                        ),
                        if (cleanNoteText.isNotEmpty) ...<Widget>[
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              '• $cleanNoteText',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 11,
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
              const SizedBox(width: 8),

              // Trailing Expense Amount in bold Dark Red
              Text(
                '- ${formatPeso(expense.amount)}',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w800,
                  color: _ExpensesTokens.expenseRed,
                  letterSpacing: -0.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 5. Detail & Action Bottom Sheet Modal with Standardized Solid Buttons
  void _showExpenseDetailsSheet(
    BuildContext context,
    ExpenseEntry expense,
    _ExpensesTokens tokens,
  ) {
    final String cleanNoteText = _cleanNote(expense.note);

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: tokens.cardBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (BuildContext sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                // Subtle top drag handle
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

                // Top Header Row
                Row(
                  children: <Widget>[
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: tokens.tint(_ExpensesTokens.expenseRed, 0.10),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _iconForCategory(expense.category),
                        size: 18,
                        color: _ExpensesTokens.expenseRed,
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
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: tokens.textPrimary,
                            ),
                          ),
                          Text(
                            expense.category.label,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: tokens.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 20),
                      onPressed: () => Navigator.of(sheetContext).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Large Amount Display
                Center(
                  child: Text(
                    '- ${formatPeso(expense.amount)}',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      color: _ExpensesTokens.expenseRed,
                      letterSpacing: -1.0,
                    ),
                  ),
                ),
                const SizedBox(height: 18),

                // Transaction Details Bento Breakdown Box
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: tokens.subCardBg,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: tokens.cardBorder, width: 1.0),
                  ),
                  child: Column(
                    children: <Widget>[
                      _buildDetailRow(
                        label: 'Date & Time',
                        value: DateFormat('EEEE, MMMM d, y • h:mm a')
                            .format(expense.dateTime),
                        tokens: tokens,
                      ),
                      const Divider(height: 16),
                      _buildDetailRow(
                        label: 'Category',
                        value: expense.category.label,
                        tokens: tokens,
                      ),
                      const Divider(height: 16),
                      _buildDetailRow(
                        label: 'Payment Method',
                        value: expense.source == 'togetherSpend'
                            ? 'Shared Together Wallet'
                            : (expense.source == 'quick_spend' ||
                                    expense.source == 'spend_screen'
                                ? 'Cash / Quick Log'
                                : 'Cash / Manual Entry'),
                        tokens: tokens,
                      ),
                      const Divider(height: 16),
                      _buildDetailRow(
                        label: 'Budget Scope',
                        value: expense.source == 'togetherSpend'
                            ? 'Together Budget'
                            : 'Personal Daily Budget',
                        tokens: tokens,
                      ),
                      if (cleanNoteText.isNotEmpty) ...<Widget>[
                        const Divider(height: 16),
                        _buildDetailRow(
                          label: 'Notes',
                          value: cleanNoteText,
                          tokens: tokens,
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 18),

                // Standardized Solid Action Buttons: Edit (Gold) & Delete (Dark Red)
                Row(
                  children: <Widget>[
                    // Edit Expense Button (Solid Gold)
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () {
                          Navigator.of(sheetContext).pop();
                          _showAddOrEditExpenseDialog(context, existing: expense);
                        },
                        icon: const Icon(Icons.edit_rounded,
                            size: 15, color: Colors.white),
                        label: Text(
                          'Edit',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        style: FilledButton.styleFrom(
                          backgroundColor: _ExpensesTokens.budgetGold,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    // Delete Expense Button (Solid Dark Red)
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () async {
                          Navigator.of(sheetContext).pop();
                          final bool shouldDelete =
                              await _confirmDeleteDialog(context, expense, tokens);
                          if (shouldDelete) {
                            ref
                                .read(budgetBuddyControllerProvider.notifier)
                                .deleteExpense(expense.id);
                            if (context.mounted) {
                              showAppAlert(context, message: 'Expense deleted successfully.', title: 'Alert', icon: Icons.warning_amber_rounded,

                                accentColor: _ExpensesTokens.expenseRed,

                              );
                            }
                          }
                        },
                        icon: const Icon(Icons.delete_outline_rounded,
                            size: 15, color: Colors.white),
                        label: Text(
                          'Delete',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        style: FilledButton.styleFrom(
                          backgroundColor: _ExpensesTokens.expenseRed,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Close Button (Solid Dark Green)
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => Navigator.of(sheetContext).pop(),
                    style: FilledButton.styleFrom(
                      backgroundColor: _ExpensesTokens.safeGreen,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      'Close',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
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
  }

  Widget _buildDetailRow({
    required String label,
    required String value,
    required _ExpensesTokens tokens,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SizedBox(
          width: 95,
          child: Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: tokens.textSecondary,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: tokens.textPrimary,
            ),
          ),
        ),
      ],
    );
  }

  /// Delete Confirmation Dialog
  Future<bool> _confirmDeleteDialog(
    BuildContext context,
    ExpenseEntry expense,
    _ExpensesTokens tokens,
  ) async {
    final bool? result = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: tokens.cardBg,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: BorderSide(color: tokens.cardBorder, width: 1.0),
          ),
          title: Row(
            children: <Widget>[
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: tokens.tint(_ExpensesTokens.expenseRed, 0.10),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.delete_outline_rounded,
                  color: _ExpensesTokens.expenseRed,
                  size: 18,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Delete Expense?',
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                  color: tokens.textPrimary,
                ),
              ),
            ],
          ),
          content: Text(
            'Are you sure you want to permanently delete this expense of ${formatPeso(expense.amount)}?',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: tokens.textSecondary,
            ),
          ),
          actions: <Widget>[
            FilledButton.icon(
              onPressed: () => Navigator.of(dialogContext).pop(false),
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
                backgroundColor: _ExpensesTokens.safeGreen,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            FilledButton.icon(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              icon: const Icon(Icons.delete_outline_rounded,
                  size: 14, color: Colors.white),
              label: Text(
                'Delete',
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  fontSize: 12,
                ),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: _ExpensesTokens.expenseRed,
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

    return result ?? false;
  }

  /// Add / Edit Expense Dialog
  Future<void> _showAddOrEditExpenseDialog(
    BuildContext context, {
    ExpenseEntry? existing,
  }) async {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final _ExpensesTokens tokens = _ExpensesTokens(isDark);

    final TextEditingController titleCtrl =
        TextEditingController(text: existing?.title ?? '');
    final TextEditingController amountCtrl = TextEditingController(
        text: existing != null ? existing.amount.toStringAsFixed(0) : '');
    final TextEditingController noteCtrl =
        TextEditingController(text: _cleanNote(existing?.note ?? ''));
    BudgetCategory category = existing?.category ?? BudgetCategory.food;

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
              title: Text(
                existing == null ? 'Add Expense' : 'Edit Expense',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: tokens.textPrimary,
                ),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    // Title field
                    TextField(
                      controller: titleCtrl,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: tokens.textPrimary,
                      ),
                      decoration: InputDecoration(
                        labelText: 'Title / Description',
                        labelStyle: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          color: tokens.textSecondary,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: tokens.cardBorder),
                        ),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Amount field
                    TextField(
                      controller: amountCtrl,
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true),
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: _ExpensesTokens.expenseRed,
                      ),
                      decoration: InputDecoration(
                        labelText: 'Amount',
                        prefixText: '₱ ',
                        labelStyle: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          color: tokens.textSecondary,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: tokens.cardBorder),
                        ),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Category Selector
                    Text(
                      'Category',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: tokens.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: BudgetCategory.values.map((BudgetCategory cat) {
                        final bool isSel = category == cat;
                        return ChoiceChip(
                          label: Text(cat.label),
                          labelStyle: GoogleFonts.plusJakartaSans(
                            fontSize: 11,
                            fontWeight: isSel ? FontWeight.w800 : FontWeight.w600,
                            color: isSel ? Colors.white : tokens.textSecondary,
                          ),
                          selected: isSel,
                          selectedColor: _ExpensesTokens.safeGreen,
                          backgroundColor: tokens.subCardBg,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(999),
                            side: BorderSide(
                              color: isSel
                                  ? _ExpensesTokens.safeGreen
                                  : tokens.cardBorder,
                            ),
                          ),
                          onSelected: (bool selected) {
                            if (selected) {
                              setModalState(() {
                                category = cat;
                              });
                            }
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 12),

                    // Note field
                    TextField(
                      controller: noteCtrl,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: tokens.textPrimary,
                      ),
                      decoration: InputDecoration(
                        labelText: 'Additional Notes (Optional)',
                        labelStyle: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          color: tokens.textSecondary,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: tokens.cardBorder),
                        ),
                        isDense: true,
                      ),
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
                FilledButton(
                  onPressed: () {
                    final double? amount =
                        double.tryParse(amountCtrl.text.trim());
                    if (amount == null || amount <= 0) return;

                    final String title = titleCtrl.text.trim().isNotEmpty
                        ? titleCtrl.text.trim()
                        : category.label;
                    final String note = noteCtrl.text.trim();

                    if (existing != null) {
                      ref
                          .read(budgetBuddyControllerProvider.notifier)
                          .updateExpense(
                            existing.copyWith(
                              title: title,
                              amount: amount,
                              category: category,
                              note: note,
                            ),
                          );
                    } else {
                      ref.read(budgetBuddyControllerProvider.notifier).addExpense(
                            title: title,
                            amount: amount,
                            category: category,
                            note: note,
                            source: widget.isTogetherOnly
                                ? 'togetherSpend'
                                : 'manual',
                          );
                    }

                    Navigator.of(dialogContext).pop();
                    showAppAlert(context, message: existing != null
                            ? 'Expense updated!'
                            : 'Expense added!', title: 'Success', icon: Icons.check_circle_outline_rounded,

                      accentColor: _ExpensesTokens.safeGreen,

                    );
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: _ExpensesTokens.safeGreen,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: Text(
                    existing != null ? 'Save Changes' : 'Add',
                    style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.w800,
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

  /// Empty State Widget
  Widget _buildEmptyState(_ExpensesTokens tokens) {
    return Center(
      child: BentoCard(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        borderRadius: 20,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: tokens.tint(_ExpensesTokens.expenseRed, 0.10),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.receipt_long_outlined,
                size: 32,
                color: _ExpensesTokens.expenseRed,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'No Expenses Found',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: tokens.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _searchController.text.isNotEmpty || _selectedCategory != null
                  ? 'No transactions match your search or category filter.'
                  : 'You have no logged expenses for this time period.',
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12.5,
                fontWeight: FontWeight.w500,
                color: tokens.textSecondary,
              ),
            ),
            if (_searchController.text.isNotEmpty ||
                _selectedCategory != null) ...<Widget>[
              const SizedBox(height: 16),
              FilledButton.tonal(
                onPressed: () {
                  setState(() {
                    _searchController.clear();
                    _selectedCategory = null;
                  });
                },
                child: Text(
                  'Reset Filters',
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w700,
                    fontSize: 12.5,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}




