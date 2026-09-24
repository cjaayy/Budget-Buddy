import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/models/budget_models.dart';
import '../../core/state/app_controller.dart';
import '../../core/utils/formatters.dart';

/// Palette matching Daily Budget and Spend screens:
/// Dark Red (#991B1B), Gold (#D97706), Dark Green (#0F766E)
class _SavingsPalette {
  const _SavingsPalette(this.isDark);

  final bool isDark;

  // Dark Red: expenses, deficits, savings debt, overspent alert
  Color get darkRed => const Color(0xFF991B1B);
  Color get darkRedBg =>
      const Color(0xFF991B1B).withValues(alpha: isDark ? 0.20 : 0.08);
  Color get darkRedBorder => const Color(0xFF991B1B).withValues(alpha: 0.25);

  // Gold: target budget amounts, savings surplus, presets, monthly overview
  Color get gold => const Color(0xFFD97706);
  Color get goldBg =>
      const Color(0xFFD97706).withValues(alpha: isDark ? 0.20 : 0.08);
  Color get goldBorder => const Color(0xFFD97706).withValues(alpha: 0.25);

  // Dark Green: safe savings, debt-free, positive progress, active status
  Color get darkGreen => const Color(0xFF0F766E);
  Color get darkGreenBg =>
      const Color(0xFF0F766E).withValues(alpha: isDark ? 0.20 : 0.08);
  Color get darkGreenBorder => const Color(0xFF0F766E).withValues(alpha: 0.25);
}

/// Compact Metric Tile for Savings, Total Saved, and Debt matching Daily Budget & Spend screens
class _CompactMetricTile extends StatelessWidget {
  const _CompactMetricTile({
    required this.label,
    required this.value,
    required this.bgColor,
    this.icon,
  });

  final String label;
  final String value;
  final Color bgColor;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Row(
            children: <Widget>[
              if (icon != null) ...<Widget>[
                Icon(
                  icon,
                  size: 12,
                  color: Colors.white.withValues(alpha: 0.88),
                ),
                const SizedBox(width: 4),
              ],
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.2,
                    color: Colors.white.withValues(alpha: 0.88),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              maxLines: 1,
              style: const TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 16,
                letterSpacing: -0.3,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

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
    final _SavingsPalette palette = _SavingsPalette(isDark);

    final List<DailyRecord> records = _getRecords(state, currentClock);
    final List<DateTime> availableMonths = _availableMonths(records);
    final double netSavings = _sectionNetSavings(records, _activeSection);

    final double togetherSpent = widget.isTogetherOnly
        ? state.expenses
            .where((ExpenseEntry e) => e.source == 'togetherSpend')
            .fold(0.0, (double sum, ExpenseEntry e) => sum + e.amount)
        : 0.0;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              // Back Button (When opened from Budget Together)
              if (widget.isTogetherOnly && Navigator.of(context).canPop()) ...<Widget>[
                FilledButton.icon(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.arrow_back_rounded,
                      size: 16, color: Colors.white),
                  label: const Text(
                    'Back',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                      color: Colors.white,
                    ),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: palette.darkGreen,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 8),
                    visualDensity: VisualDensity.compact,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    elevation: 0,
                  ),
                ),
                const SizedBox(height: 8),
              ],

              // 1. Compact Header (matching Daily Budget & Spend screens)
              _buildHeader(
                context,
                currentClock: currentClock,
              ),
              const SizedBox(height: 12),

              // 2. Main Content
              Expanded(
                child: ListView(
                  padding: EdgeInsets.zero,
                  children: <Widget>[
                    // Savings Overview Card (with 3 Solid Metric Tiles)
                    _buildOverviewCard(
                      context,
                      state: state,
                      records: records,
                      availableMonths: availableMonths,
                      netSavings: netSavings,
                      togetherSpent: togetherSpent,
                      palette: palette,
                    ),
                    const SizedBox(height: 12),

                    // Sleek Daily / Monthly Toggle
                    _buildSectionToggle(context, palette),
                    const SizedBox(height: 12),

                    // History Card with records list
                    _buildHistoryCard(
                      context,
                      records: records,
                      availableMonths: availableMonths,
                      currentClock: currentClock,
                      palette: palette,
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

  /// Compact header without redundant subtitles or duplicate pills
  Widget _buildHeader(
    BuildContext context, {
    required DateTime currentClock,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          widget.isTogetherOnly ? 'Together Savings' : 'Savings',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
              ),
        ),
        const SizedBox(height: 2),
        Text(
          DateFormat('EEEE, MMM d').format(currentClock),
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w500,
              ),
        ),
      ],
    );
  }

  /// Compact Overview Card with the 3 Solid Metric Tiles
  Widget _buildOverviewCard(
    BuildContext context, {
    required BudgetBuddyState state,
    required List<DailyRecord> records,
    required List<DateTime> availableMonths,
    required double netSavings,
    required double togetherSpent,
    required _SavingsPalette palette,
  }) {
    final ThemeData theme = Theme.of(context);
    final bool isDeficit = netSavings < 0;

    return Container(
      clipBehavior: Clip.antiAlias,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.cardTheme.color ?? theme.cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // Header Row
          Row(
            children: <Widget>[
              Icon(
                Icons.analytics_rounded,
                size: 16,
                color: palette.darkGreen,
              ),
              const SizedBox(width: 6),
              Text(
                'Savings Overview',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // 3 Compact Metric Tiles: Green/Red, Gold, Dark Red/Green
          Row(
            children: <Widget>[
              Expanded(
                child: _CompactMetricTile(
                  label: _activeSection == SavingsSection.daily
                      ? 'Daily Saved'
                      : 'Monthly Saved',
                  value:
                      (isDeficit ? '-' : '') + formatPeso(netSavings.abs()),
                  bgColor: isDeficit ? palette.darkRed : palette.darkGreen,
                  icon: isDeficit
                      ? Icons.trending_down_rounded
                      : Icons.savings_rounded,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _CompactMetricTile(
                  label:
                      widget.isTogetherOnly ? 'Tab Budget' : 'Total Saved',
                  value: widget.isTogetherOnly
                      ? formatPeso(state.togetherBudget)
                      : formatPeso(state.totalSavings),
                  bgColor: palette.gold,
                  icon: Icons.account_balance_wallet_rounded,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _CompactMetricTile(
                  label: widget.isTogetherOnly
                      ? 'Tab Spent'
                      : (state.savingsDebt > 0
                          ? 'Savings Debt'
                          : 'Debt Status'),
                  value: widget.isTogetherOnly
                      ? formatPeso(togetherSpent)
                      : (state.savingsDebt > 0
                          ? formatPeso(state.savingsDebt)
                          : '₱0 (Clear)'),
                  bgColor: widget.isTogetherOnly
                      ? palette.darkRed
                      : (state.savingsDebt > 0
                          ? palette.darkRed
                          : palette.darkGreen),
                  icon: widget.isTogetherOnly
                      ? Icons.shopping_bag_rounded
                      : (state.savingsDebt > 0
                          ? Icons.warning_amber_rounded
                          : Icons.check_circle_rounded),
                ),
              ),
            ],
          ),

          // Savings Debt Alert (Dark Red Banner)
          if (!widget.isTogetherOnly && state.savingsDebt > 0) ...<Widget>[
            const SizedBox(height: 10),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: palette.darkRedBg,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: palette.darkRedBorder),
              ),
              child: Row(
                children: <Widget>[
                  Icon(Icons.info_outline_rounded,
                      size: 14, color: palette.darkRed),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Savings Debt: ${formatPeso(state.savingsDebt)} carried over to offset your next surplus.',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: palette.darkRed,
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

  /// Sleek segmented Daily / Monthly toggle matching app style
  Widget _buildSectionToggle(BuildContext context, _SavingsPalette palette) {
    final ThemeData theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () {
                if (_activeSection != SavingsSection.daily) {
                  setState(() => _activeSection = SavingsSection.daily);
                }
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 9),
                decoration: BoxDecoration(
                  color: _activeSection == SavingsSection.daily
                      ? palette.darkGreen
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: _activeSection == SavingsSection.daily
                      ? <BoxShadow>[
                          BoxShadow(
                            color: palette.darkGreen.withValues(alpha: 0.35),
                            blurRadius: 4,
                            offset: const Offset(0, 1),
                          ),
                        ]
                      : null,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    Icon(
                      Icons.calendar_today_rounded,
                      size: 14,
                      color: _activeSection == SavingsSection.daily
                          ? Colors.white
                          : theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Daily',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: _activeSection == SavingsSection.daily
                            ? FontWeight.w700
                            : FontWeight.w600,
                        color: _activeSection == SavingsSection.daily
                            ? Colors.white
                            : theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () {
                if (_activeSection != SavingsSection.monthly) {
                  setState(() => _activeSection = SavingsSection.monthly);
                }
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 9),
                decoration: BoxDecoration(
                  color: _activeSection == SavingsSection.monthly
                      ? palette.darkGreen
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: _activeSection == SavingsSection.monthly
                      ? <BoxShadow>[
                          BoxShadow(
                            color: palette.darkGreen.withValues(alpha: 0.35),
                            blurRadius: 4,
                            offset: const Offset(0, 1),
                          ),
                        ]
                      : null,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    Icon(
                      Icons.calendar_month_rounded,
                      size: 14,
                      color: _activeSection == SavingsSection.monthly
                          ? Colors.white
                          : theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Monthly',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: _activeSection == SavingsSection.monthly
                            ? FontWeight.w700
                            : FontWeight.w600,
                        color: _activeSection == SavingsSection.monthly
                            ? Colors.white
                            : theme.colorScheme.onSurfaceVariant,
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

  /// History card containing the list of daily or monthly savings records
  Widget _buildHistoryCard(
    BuildContext context, {
    required List<DailyRecord> records,
    required List<DateTime> availableMonths,
    required DateTime currentClock,
    required _SavingsPalette palette,
  }) {
    final ThemeData theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.cardTheme.color ?? theme.cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(Icons.history_rounded, size: 16, color: palette.gold),
              const SizedBox(width: 6),
              Text(
                _activeSection == SavingsSection.daily
                    ? 'Daily Records'
                    : 'Monthly Records',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (records.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text(
                  widget.isTogetherOnly
                      ? 'No Budget Together savings records yet. Set a budget in Budget Together to start tracking tab savings.'
                      : 'No savings records yet. Set a budget to start tracking your daily and monthly savings.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            )
          else if (_activeSection == SavingsSection.daily)
            ...records.map(
              (DailyRecord record) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _SavingsDateTile(
                    record: record,
                    currentClock: currentClock,
                    palette: palette,
                    onTap: () => _showSavingsDaySheet(context, record, palette),
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
                  child: _SavingsMonthTile(
                    month: month,
                    savings: monthSavings,
                    recordCount: monthRecords.length,
                    palette: palette,
                    onTap: () => _showSavingsMonthSheet(
                      context,
                      month,
                      monthRecords,
                      currentClock,
                      palette,
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Future<void> _showSavingsDaySheet(
    BuildContext context,
    DailyRecord record,
    _SavingsPalette palette,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: false,
      enableDrag: false,
      isDismissible: false,
      backgroundColor: Colors.transparent,
      builder: (BuildContext sheetContext) {
        final ThemeData theme = Theme.of(sheetContext);
        final bool isZeroActivity = record.isZeroActivity;
        final bool isOverspent = record.savings < 0;

        final Color accent = isZeroActivity
            ? palette.gold
            : (isOverspent ? palette.darkRed : palette.darkGreen);
        final Color accentBg = isZeroActivity
            ? palette.goldBg
            : (isOverspent ? palette.darkRedBg : palette.darkGreenBg);
        final Color accentBorder = isZeroActivity
            ? palette.goldBorder
            : (isOverspent ? palette.darkRedBorder : palette.darkGreenBorder);

        final List<MapEntry<String, double>> categories = record
            .categoryTotals.entries
            .where((MapEntry<String, double> entry) => entry.value > 0)
            .toList()
          ..sort(
              (MapEntry<String, double> left, MapEntry<String, double> right) =>
                  right.value.compareTo(left.value));

        return Container(
          decoration: BoxDecoration(
            color: theme.scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SafeArea(
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
                    // Header with back button and date
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: <Widget>[
                        FilledButton.icon(
                          onPressed: () => Navigator.of(sheetContext).pop(),
                          icon: const Icon(Icons.arrow_back_rounded,
                              size: 16, color: Colors.white),
                          label: const Text(
                            'Back',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                              color: Colors.white,
                            ),
                          ),
                          style: FilledButton.styleFrom(
                            backgroundColor: palette.darkGreen,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 8),
                            visualDensity: VisualDensity.compact,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                        Text(
                          DateFormat('EEEE, MMM d, yyyy').format(record.date),
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Main Status Highlight Card
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: accentBg,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: accentBorder),
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
                                    : (isOverspent ? 'Overspent' : 'Saved'),
                                style: TextStyle(
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
                                ? '₱0'
                                : formatPeso(record.savings.abs()),
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              color: accent,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            isZeroActivity
                                ? 'Budget ₱0 • Spent ₱0 • ₱0 balance'
                                : 'Spent ${formatPeso(record.totalSpent)} • Left ${formatPeso(record.remainingBalance)}',
                            style: TextStyle(
                              fontSize: 12,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Category Breakdown Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: <Widget>[
                        Row(
                          children: <Widget>[
                            Icon(Icons.category_rounded,
                                size: 15, color: palette.gold),
                            const SizedBox(width: 6),
                            Text(
                              'Category Breakdown',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: theme.colorScheme.onSurface,
                              ),
                            ),
                          ],
                        ),
                        if (categories.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: palette.gold,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '${categories.length} item${categories.length == 1 ? '' : 's'}',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    if (categories.isEmpty || isZeroActivity)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        child: Center(
                          child: Text(
                            'No expenses logged for this day.',
                            style: TextStyle(
                              fontSize: 12,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      )
                    else
                      Expanded(
                        child: ListView.separated(
                          itemCount: categories.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 8),
                          itemBuilder: (BuildContext ctx, int index) {
                            final MapEntry<String, double> entry =
                                categories[index];
                            return Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 10),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.surfaceContainerHighest
                                    .withValues(alpha: 0.35),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: theme.colorScheme.outlineVariant
                                      .withValues(alpha: 0.25),
                                ),
                              ),
                              child: Row(
                                children: <Widget>[
                                  Expanded(
                                    child: Text(
                                      entry.key,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: palette.darkRedBg,
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(
                                          color: palette.darkRedBorder),
                                    ),
                                    child: Text(
                                      formatPeso(entry.value),
                                      style: TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 12,
                                        color: palette.darkRed,
                                      ),
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
    _SavingsPalette palette,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: false,
      enableDrag: false,
      isDismissible: false,
      backgroundColor: Colors.transparent,
      builder: (BuildContext sheetContext) {
        final ThemeData theme = Theme.of(sheetContext);
        final double monthSavings = records.fold<double>(
          0,
          (double total, DailyRecord record) => total + record.savings,
        );
        final bool isOverspent = monthSavings < 0;
        final Color accent = isOverspent ? palette.darkRed : palette.darkGreen;
        final Color accentBg =
            isOverspent ? palette.darkRedBg : palette.darkGreenBg;
        final Color accentBorder =
            isOverspent ? palette.darkRedBorder : palette.darkGreenBorder;

        return Container(
          decoration: BoxDecoration(
            color: theme.scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SafeArea(
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
                    // Header with back button and month
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: <Widget>[
                        FilledButton.icon(
                          onPressed: () => Navigator.of(sheetContext).pop(),
                          icon: const Icon(Icons.arrow_back_rounded,
                              size: 16, color: Colors.white),
                          label: const Text(
                            'Back',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                              color: Colors.white,
                            ),
                          ),
                          style: FilledButton.styleFrom(
                            backgroundColor: palette.darkGreen,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 8),
                            visualDensity: VisualDensity.compact,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                        Text(
                          DateFormat('MMMM yyyy').format(month),
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Monthly Highlight Card
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: accentBg,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: accentBorder),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: <Widget>[
                              Text(
                                isOverspent
                                    ? 'Month Overspent'
                                    : 'Month Net Saved',
                                style: TextStyle(
                                  color: accent,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 12,
                                ),
                              ),
                              Icon(
                                isOverspent
                                    ? Icons.trending_down_rounded
                                    : Icons.savings_rounded,
                                color: accent,
                                size: 16,
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            (isOverspent ? '-' : '+') +
                                formatPeso(monthSavings.abs()),
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              color: accent,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${records.length} day${records.length == 1 ? '' : 's'} tracked in this period',
                            style: TextStyle(
                              fontSize: 12,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Days in Month Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: <Widget>[
                        Row(
                          children: <Widget>[
                            Icon(Icons.calendar_today_rounded,
                                size: 15, color: palette.gold),
                            const SizedBox(width: 6),
                            Text(
                              'Days in this Month',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: theme.colorScheme.onSurface,
                              ),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: palette.gold,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '${records.length} day${records.length == 1 ? '' : 's'}',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    if (records.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        child: Center(
                          child: Text(
                            'No savings records for this month.',
                            style: TextStyle(
                              fontSize: 12,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      )
                    else
                      Expanded(
                        child: ListView.separated(
                          itemCount: records.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 8),
                          itemBuilder: (BuildContext ctx, int index) {
                            final DailyRecord record = records[index];
                            return _SavingsDateTile(
                              record: record,
                              currentClock: currentClock,
                              palette: palette,
                              onTap: () => _showSavingsDaySheet(
                                  sheetContext, record, palette),
                            );
                          },
                        ),
                      ),
                  ],
                ),
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
      if (state.dailyRecords.isEmpty) {
        final DateTime today =
            DateTime(currentClock.year, currentClock.month, currentClock.day);
        return <DailyRecord>[
          DailyRecord(
            date: today,
            budget: 0.0,
            totalSpent: 0.0,
            remainingBalance: 0.0,
            savings: 0.0,
            biggestExpenseCategory: BudgetCategory.miscellaneous.label,
            categoryTotals: <String, double>{
              for (final BudgetCategory category in BudgetCategory.values)
                category.label: 0.0,
            },
          ),
        ];
      }
      return _sortedRecords(state.dailyRecords);
    }

    final double togetherBudget = state.togetherBudget;
    final List<ExpenseEntry> togetherExpenses = state.expenses
        .where((ExpenseEntry e) => e.source == 'togetherSpend')
        .toList();

    if (togetherBudget <= 0 && togetherExpenses.isEmpty) {
      return <DailyRecord>[];
    }

    final Set<DateTime> dates = <DateTime>{};
    if (togetherBudget > 0) {
      dates.add(
          DateTime(currentClock.year, currentClock.month, currentClock.day));
    }
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
      final double savings =
          togetherBudget > 0 ? togetherBudget - totalSpent : -totalSpent;

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
          budget: togetherBudget,
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

  double _sectionNetSavings(List<DailyRecord> records, SavingsSection section) {
    if (records.isEmpty) {
      return 0;
    }

    if (section == SavingsSection.daily) {
      return records.fold<double>(
        0,
        (double total, DailyRecord record) => total + record.savings,
      );
    }

    final List<DateTime> months = _availableMonths(records);
    return months.fold<double>(0, (double total, DateTime month) {
      final List<DailyRecord> monthRecords = _recordsForMonth(records, month);
      return total +
          monthRecords.fold<double>(
            0,
            (double monthTotal, DailyRecord record) =>
                monthTotal + record.savings,
          );
    });
  }
}

enum SavingsSection { daily, monthly }

class _SavingsDateTile extends StatelessWidget {
  const _SavingsDateTile({
    required this.record,
    required this.onTap,
    required this.palette,
    this.currentClock,
  });

  final DailyRecord record;
  final VoidCallback onTap;
  final _SavingsPalette palette;
  final DateTime? currentClock;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool isZeroActivity = record.isZeroActivity;
    final bool isOverspent = record.savings < 0;

    final Color accent = isZeroActivity
        ? palette.gold
        : (isOverspent ? palette.darkRed : palette.darkGreen);
    final Color accentBg = isZeroActivity
        ? palette.goldBg
        : (isOverspent ? palette.darkRedBg : palette.darkGreenBg);
    final Color accentBorder = isZeroActivity
        ? palette.goldBorder
        : (isOverspent ? palette.darkRedBorder : palette.darkGreenBorder);

    final IconData icon = isZeroActivity
        ? Icons.calendar_today_rounded
        : (isOverspent
            ? Icons.trending_down_rounded
            : Icons.trending_up_rounded);

    final String statusText = isZeroActivity
        ? 'No budget & expenses'
        : (isOverspent
            ? 'Overspent ${formatPeso(record.savings.abs())}'
            : 'Saved ${formatPeso(record.savings)}');

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
          color:
              theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.25),
          ),
        ),
        child: Row(
          children: <Widget>[
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: accentBg,
                shape: BoxShape.circle,
                border: Border.all(color: accentBorder),
              ),
              child: Icon(
                icon,
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
                    _formatDayLabel(record.date, currentClock),
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    statusText,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: accentBg,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: accentBorder),
              ),
              child: Text(
                badgeText,
                style: TextStyle(
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
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
            ),
          ],
        ),
      ),
    );
  }
}

class _SavingsMonthTile extends StatelessWidget {
  const _SavingsMonthTile({
    required this.month,
    required this.savings,
    required this.recordCount,
    required this.palette,
    required this.onTap,
  });

  final DateTime month;
  final double savings;
  final int recordCount;
  final _SavingsPalette palette;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool isOverspent = savings < 0;
    final Color accent = isOverspent ? palette.darkRed : palette.darkGreen;
    final Color accentBg =
        isOverspent ? palette.darkRedBg : palette.darkGreenBg;
    final Color accentBorder =
        isOverspent ? palette.darkRedBorder : palette.darkGreenBorder;

    final String badgeText = isOverspent
        ? '-${formatPeso(savings.abs())}'
        : '+${formatPeso(savings)}';

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color:
              theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.25),
          ),
        ),
        child: Row(
          children: <Widget>[
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: accentBg,
                shape: BoxShape.circle,
                border: Border.all(color: accentBorder),
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
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$recordCount day${recordCount == 1 ? '' : 's'} tracked',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: accentBg,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: accentBorder),
              ),
              child: Text(
                badgeText,
                style: TextStyle(
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
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
            ),
          ],
        ),
      ),
    );
  }
}

String _formatDayLabel(DateTime dateTime, [DateTime? currentClock]) {
  final DateTime now = currentClock ?? DateTime.now();
  if (DateUtils.isSameDay(dateTime, now)) {
    return 'Today, ${DateFormat('MMMM d, yyyy').format(dateTime)}';
  }
  return DateFormat('EEEE, MMM d, yyyy').format(dateTime);
}
