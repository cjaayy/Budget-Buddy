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

enum _DateFilterOption {
  thisMonth,
  today,
  last7Days,
  allTime,
  custom,
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
  _DateFilterOption _dateFilter = _DateFilterOption.thisMonth;
  DateTimeRange? _customDateRange;

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

  String _dateFilterLabel(_DateFilterOption option) {
    return switch (option) {
      _DateFilterOption.thisMonth => 'This Month',
      _DateFilterOption.today => 'Today',
      _DateFilterOption.last7Days => 'Last 7 Days',
      _DateFilterOption.allTime => 'All Time',
      _DateFilterOption.custom => _customDateRange != null
          ? '${DateFormat('MMM d').format(_customDateRange!.start)} - ${DateFormat('MMM d').format(_customDateRange!.end)}'
          : 'Custom Range',
    };
  }

  List<ExpenseEntry> _filterExpenses(
    List<ExpenseEntry> allExpenses,
    DateTime currentClock,
  ) {
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

      // Date range filter
      final DateTime eDate = expense.dateTime;
      final DateTime today =
          DateTime(currentClock.year, currentClock.month, currentClock.day);
      final DateTime eDay = DateTime(eDate.year, eDate.month, eDate.day);

      switch (_dateFilter) {
        case _DateFilterOption.today:
          if (eDay != today) return false;
          break;
        case _DateFilterOption.thisMonth:
          if (eDate.year != currentClock.year ||
              eDate.month != currentClock.month) {
            return false;
          }
          break;
        case _DateFilterOption.last7Days:
          final DateTime sevenDaysAgo = today.subtract(const Duration(days: 7));
          if (eDay.isBefore(sevenDaysAgo) || eDay.isAfter(today)) return false;
          break;
        case _DateFilterOption.custom:
          if (_customDateRange != null) {
            final DateTime start = DateTime(_customDateRange!.start.year,
                _customDateRange!.start.month, _customDateRange!.start.day);
            final DateTime end = DateTime(_customDateRange!.end.year,
                _customDateRange!.end.month, _customDateRange!.end.day);
            if (eDay.isBefore(start) || eDay.isAfter(end)) return false;
          }
          break;
        case _DateFilterOption.allTime:
          break;
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

  Map<DateTime, List<ExpenseEntry>> _groupByDay(List<ExpenseEntry> list) {
    final Map<DateTime, List<ExpenseEntry>> grouped =
        <DateTime, List<ExpenseEntry>>{};
    for (final ExpenseEntry item in list) {
      final DateTime dayKey =
          DateTime(item.dateTime.year, item.dateTime.month, item.dateTime.day);
      grouped.putIfAbsent(dayKey, () => <ExpenseEntry>[]).add(item);
    }
    return grouped;
  }

  Future<void> _pickCustomDateRange() async {
    final DateTime now = DateTime.now();
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 3),
      lastDate: DateTime(now.year + 1),
      initialDateRange: _customDateRange ??
          DateTimeRange(
            start: now.subtract(const Duration(days: 30)),
            end: now,
          ),
      builder: (BuildContext context, Widget? child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
                  primary: _ExpensesTokens.safeGreen,
                  onPrimary: Colors.white,
                ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _customDateRange = picked;
        _dateFilter = _DateFilterOption.custom;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final BudgetBuddyState state = ref.watch(budgetBuddyControllerProvider);
    final DateTime currentClock =
        ref.read(budgetBuddyControllerProvider.notifier).currentEffectiveTime;
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final _ExpensesTokens tokens = _ExpensesTokens(isDark);

    final List<ExpenseEntry> filteredExpenses =
        _filterExpenses(state.expenses, currentClock);
    final double totalFilteredAmount = filteredExpenses.fold<double>(
        0.0, (double sum, ExpenseEntry e) => sum + e.amount);

    final Map<DateTime, List<ExpenseEntry>> groupedExpenses =
        _groupByDay(filteredExpenses);
    final List<DateTime> sortedDays = groupedExpenses.keys.toList()
      ..sort((DateTime a, DateTime b) => b.compareTo(a));

    return Scaffold(
      backgroundColor: tokens.scaffoldBg,
      body: SafeArea(
        child: CustomScrollView(
          slivers: <Widget>[
            // 1. Header & Search Bar
            SliverToBoxAdapter(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    // Back button if in together mode
                    if (widget.isTogetherOnly && Navigator.of(context).canPop()) ...<Widget>[
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

                    // Search Input Field
                    _buildSearchBar(tokens),
                    const SizedBox(height: 12),

                    // 2. Filter Section (Categories & Date Range)
                    _buildFilterSection(tokens),
                    const SizedBox(height: 12),

                    // 3. Filtered Total Summary Bento Card
                    _buildFilteredSummaryCard(
                      totalAmount: totalFilteredAmount,
                      count: filteredExpenses.length,
                      tokens: tokens,
                    ),
                  ],
                ),
              ),
            ),

            // 4. Chronological Transaction History List
            if (filteredExpenses.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _buildEmptyState(tokens),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (BuildContext context, int index) {
                      final DateTime day = sortedDays[index];
                      final List<ExpenseEntry> dayItems =
                          groupedExpenses[day] ?? <ExpenseEntry>[];
                      final double dayTotal = dayItems.fold<double>(
                          0.0, (double sum, ExpenseEntry e) => sum + e.amount);

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          // Day Header Row
                          _buildDayHeader(day, dayTotal, currentClock, tokens),
                          const SizedBox(height: 8),

                          // Transaction Cards for this day
                          ...dayItems.map((ExpenseEntry expense) {
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: _buildTransactionTile(
                                context,
                                expense: expense,
                                tokens: tokens,
                              ),
                            );
                          }),
                          const SizedBox(height: 8),
                        ],
                      );
                    },
                    childCount: sortedDays.length,
                  ),
                ),
              ),
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
          hintText: 'Search expenses by name, category, or note...',
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

  /// 2. Filter Section: Category Capsule Chips & Date Range Selector
  Widget _buildFilterSection(_ExpensesTokens tokens) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        // Date Range Selector Row
        Row(
          children: <Widget>[
            Text(
              'Date Filter:',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: tokens.textSecondary,
              ),
            ),
            const SizedBox(width: 8),
            // Popup Menu or Date Range Trigger
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => _showDateFilterSheet(tokens),
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: tokens.subCardBg,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: tokens.cardBorder, width: 1.0),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      const Icon(
                        Icons.calendar_today_rounded,
                        size: 13,
                        color: _ExpensesTokens.safeGreen,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _dateFilterLabel(_dateFilter),
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: tokens.textPrimary,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        Icons.keyboard_arrow_down_rounded,
                        size: 15,
                        color: tokens.textSecondary,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),

        // Horizontal Category Capsule List
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: <Widget>[
              // 'All' Chip
              _buildCategoryChip(
                label: 'All',
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
        ),
      ],
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

  /// Date Filter Selection Modal Bottom Sheet
  void _showDateFilterSheet(_ExpensesTokens tokens) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: tokens.cardBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(18),
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
                Text(
                  'Select Date Filter',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: tokens.textPrimary,
                  ),
                ),
                const SizedBox(height: 12),
                ...<MapEntry<_DateFilterOption, String>>[
                  const MapEntry(_DateFilterOption.thisMonth, 'This Month'),
                  const MapEntry(_DateFilterOption.today, 'Today'),
                  const MapEntry(_DateFilterOption.last7Days, 'Last 7 Days'),
                  const MapEntry(_DateFilterOption.allTime, 'All Time'),
                  const MapEntry(_DateFilterOption.custom, 'Custom Date Range...'),
                ].map((entry) {
                  final bool isSelected = _dateFilter == entry.key;

                  return ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      entry.value,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13.5,
                        fontWeight:
                            isSelected ? FontWeight.w800 : FontWeight.w600,
                        color: isSelected
                            ? _ExpensesTokens.safeGreen
                            : tokens.textPrimary,
                      ),
                    ),
                    trailing: isSelected
                        ? const Icon(Icons.check_circle_rounded,
                            size: 18, color: _ExpensesTokens.safeGreen)
                        : null,
                    onTap: () {
                      Navigator.of(sheetContext).pop();
                      if (entry.key == _DateFilterOption.custom) {
                        _pickCustomDateRange();
                      } else {
                        setState(() {
                          _dateFilter = entry.key;
                        });
                      }
                    },
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }

  /// 3. Filtered Total Summary Bento Card
  Widget _buildFilteredSummaryCard({
    required double totalAmount,
    required int count,
    required _ExpensesTokens tokens,
  }) {
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
                  'Total Outlays (${_dateFilterLabel(_dateFilter)})',
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
            text: 'Showing $count ${count == 1 ? "expense" : "expenses"}',
            color: _ExpensesTokens.budgetGold,
            fontSize: 11,
          ),
        ],
      ),
    );
  }

  /// Day Header Row
  Widget _buildDayHeader(
    DateTime day,
    double dayTotal,
    DateTime currentClock,
    _ExpensesTokens tokens,
  ) {
    final DateTime today =
        DateTime(currentClock.year, currentClock.month, currentClock.day);
    final DateTime yesterday = today.subtract(const Duration(days: 1));

    final String dayLabel = DateUtils.isSameDay(day, today)
        ? 'Today'
        : (DateUtils.isSameDay(day, yesterday)
            ? 'Yesterday'
            : DateFormat('EEEE, MMM d').format(day));

    return Row(
      children: <Widget>[
        Text(
          dayLabel,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: tokens.textSecondary,
          ),
        ),
        const Spacer(),
        Text(
          'Total: ${formatPeso(dayTotal)}',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: tokens.textPrimary,
          ),
        ),
      ],
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
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Expense deleted successfully.'),
                                  behavior: SnackBarBehavior.floating,
                                  backgroundColor: _ExpensesTokens.expenseRed,
                                ),
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
                            dateTime: DateTime.now(),
                            source: widget.isTogetherOnly
                                ? 'togetherSpend'
                                : 'manual',
                          );
                    }

                    Navigator.of(dialogContext).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(existing != null
                            ? 'Expense updated!'
                            : 'Expense added!'),
                        backgroundColor: _ExpensesTokens.safeGreen,
                        behavior: SnackBarBehavior.floating,
                      ),
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
                    _dateFilter = _DateFilterOption.allTime;
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
