import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/models/budget_models.dart';
import '../../core/state/app_controller.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/budget_cards.dart';
import '../../core/widgets/section_title.dart';

class SavingsScreen extends ConsumerStatefulWidget {
  const SavingsScreen({super.key});

  @override
  ConsumerState<SavingsScreen> createState() => _SavingsScreenState();
}

class _SavingsScreenState extends ConsumerState<SavingsScreen> {
  SavingsSection _activeSection = SavingsSection.daily;

  @override
  Widget build(BuildContext context) {
    final BudgetBuddyState state = ref.watch(budgetBuddyControllerProvider);
    final List<DailyRecord> records = _sortedRecords(state.dailyRecords);
    final List<DateTime> availableMonths = _availableMonths(records);
    final double netSavings = _sectionNetSavings(records, _activeSection);
    final int positiveDayCount =
        records.where((DailyRecord record) => record.savings > 0).length;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const SectionTitle(
                title: 'Savings',
                subtitle:
                    'Track how much you saved each day based on your active budget.',
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ListView(
                  padding: EdgeInsets.zero,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: BudgetMetricCard(
                            label: _activeSection == SavingsSection.daily
                                ? 'Daily Savings'
                                : 'Monthly Savings',
                            value: formatPeso(netSavings),
                            subtitle: _activeSection == SavingsSection.daily
                                ? 'Across ${records.length} day${records.length == 1 ? '' : 's'}'
                                : 'Across ${availableMonths.length} month${availableMonths.length == 1 ? '' : 's'}',
                            icon: Icons.savings_rounded,
                            color: const Color(0xFFF97316),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: BudgetMetricCard(
                            label: 'Positive Days',
                            value: positiveDayCount.toString(),
                            subtitle: 'Days that stayed under budget',
                            icon: Icons.trending_up_rounded,
                            color: const Color(0xFF0F766E),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: FilledButton(
                            onPressed: () => setState(() {
                              _activeSection = SavingsSection.daily;
                            }),
                            style: FilledButton.styleFrom(
                              backgroundColor:
                                  _activeSection == SavingsSection.daily
                                      ? Theme.of(context).colorScheme.primary
                                      : Theme.of(context)
                                          .colorScheme
                                          .surfaceContainerHighest,
                              foregroundColor:
                                  _activeSection == SavingsSection.daily
                                      ? Theme.of(context).colorScheme.onPrimary
                                      : Theme.of(context).colorScheme.onSurface,
                            ),
                            child: const Text('Daily'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton(
                            onPressed: () => setState(() {
                              _activeSection = SavingsSection.monthly;
                            }),
                            style: FilledButton.styleFrom(
                              backgroundColor:
                                  _activeSection == SavingsSection.monthly
                                      ? Theme.of(context).colorScheme.primary
                                      : Theme.of(context)
                                          .colorScheme
                                          .surfaceContainerHighest,
                              foregroundColor:
                                  _activeSection == SavingsSection.monthly
                                      ? Theme.of(context).colorScheme.onPrimary
                                      : Theme.of(context).colorScheme.onSurface,
                            ),
                            child: const Text('Monthly'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SectionCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            _activeSection == SavingsSection.daily
                                ? 'DAILY'
                                : 'MONTHLY',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _activeSection == SavingsSection.daily
                                ? 'Tap a date to view the savings breakdown for that day.'
                                : 'Tap a month to view the savings breakdown for that month.',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                          const SizedBox(height: 12),
                          if (records.isEmpty)
                            Text(
                              'No savings records yet.',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                                  ),
                            )
                          else if (_activeSection == SavingsSection.daily)
                            ...records.map(
                              (DailyRecord record) {
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 10),
                                  child: _SavingsDateTile(
                                    record: record,
                                    onTap: () =>
                                        _showSavingsDaySheet(context, record),
                                  ),
                                );
                              },
                            )
                          else
                            ...availableMonths.map(
                              (DateTime month) {
                                final List<DailyRecord> monthRecords =
                                    _recordsForMonth(records, month);
                                final double monthSavings =
                                    monthRecords.fold<double>(
                                  0,
                                  (double total, DailyRecord record) =>
                                      total + record.savings,
                                );
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 10),
                                  child: _SavingsMonthTile(
                                    month: month,
                                    savings: monthSavings,
                                    recordCount: monthRecords.length,
                                    onTap: () => _showSavingsMonthSheet(
                                      context,
                                      month,
                                      monthRecords,
                                    ),
                                  ),
                                );
                              },
                            ),
                        ],
                      ),
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

  Future<void> _showSavingsDaySheet(
    BuildContext context,
    DailyRecord record,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: false,
      enableDrag: false,
      isDismissible: false,
      builder: (BuildContext sheetContext) {
        final bool isOverspent = record.savings < 0;
        final Color accent =
            isOverspent ? const Color(0xFFDC2626) : const Color(0xFF16A34A);
        final List<MapEntry<String, double>> categories = record
            .categoryTotals.entries
            .toList()
          ..sort(
              (MapEntry<String, double> left, MapEntry<String, double> right) =>
                  right.value.compareTo(left.value));

        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(sheetContext).size.height * 0.78,
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      TextButton.icon(
                        onPressed: () => Navigator.of(sheetContext).pop(),
                        icon: const Icon(Icons.arrow_back_rounded),
                        label: const Text('Back'),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          DateFormat('EEEE, MMM d, yyyy').format(record.date),
                          style: Theme.of(sheetContext)
                              .textTheme
                              .titleLarge
                              ?.copyWith(fontWeight: FontWeight.w700),
                          textAlign: TextAlign.right,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    isOverspent
                        ? 'Overspent ${formatPeso(record.savings.abs())} on this day.'
                        : 'Saved ${formatPeso(record.savings)} on this day.',
                    style:
                        Theme.of(sheetContext).textTheme.bodyMedium?.copyWith(
                              color: Theme.of(sheetContext)
                                  .colorScheme
                                  .onSurfaceVariant,
                            ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: accent.withValues(alpha: 0.16)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          isOverspent ? 'Overspent' : 'Saved',
                          style: Theme.of(sheetContext)
                              .textTheme
                              .labelLarge
                              ?.copyWith(
                                color: accent,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          formatPeso(record.savings.abs()),
                          style: Theme.of(sheetContext)
                              .textTheme
                              .headlineSmall
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Spent ${formatPeso(record.totalSpent)} • Left ${formatPeso(record.remainingBalance)}',
                          style: Theme.of(sheetContext).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Category Breakdown',
                    style: Theme.of(sheetContext)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 12),
                  if (categories.isEmpty)
                    const Text('No category data for this day.')
                  else
                    Expanded(
                      child: ListView.separated(
                        itemCount: categories.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (BuildContext context, int index) {
                          final MapEntry<String, double> entry =
                              categories[index];
                          return Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Theme.of(context)
                                  .colorScheme
                                  .surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Row(
                              children: <Widget>[
                                Expanded(
                                  child: Text(
                                    entry.key,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                Text(formatPeso(entry.value)),
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
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: false,
      enableDrag: false,
      isDismissible: false,
      builder: (BuildContext sheetContext) {
        final double monthSavings = records.fold<double>(
          0,
          (double total, DailyRecord record) => total + record.savings,
        );
        final bool isOverspent = monthSavings < 0;
        final Color accent =
            isOverspent ? const Color(0xFFDC2626) : const Color(0xFF16A34A);

        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(sheetContext).size.height * 0.78,
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      TextButton.icon(
                        onPressed: () => Navigator.of(sheetContext).pop(),
                        icon: const Icon(Icons.arrow_back_rounded),
                        label: const Text('Back'),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          DateFormat('MMMM yyyy').format(month),
                          style: Theme.of(sheetContext)
                              .textTheme
                              .titleLarge
                              ?.copyWith(fontWeight: FontWeight.w700),
                          textAlign: TextAlign.right,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Total savings for this month: ${formatPeso(monthSavings.abs())}',
                    style:
                        Theme.of(sheetContext).textTheme.bodyMedium?.copyWith(
                              color: Theme.of(sheetContext)
                                  .colorScheme
                                  .onSurfaceVariant,
                            ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: accent.withValues(alpha: 0.16)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          isOverspent ? 'Overspent' : 'Saved',
                          style: Theme.of(sheetContext)
                              .textTheme
                              .labelLarge
                              ?.copyWith(
                                color: accent,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          formatPeso(monthSavings.abs()),
                          style: Theme.of(sheetContext)
                              .textTheme
                              .headlineSmall
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '${records.length} day${records.length == 1 ? '' : 's'} tracked',
                          style: Theme.of(sheetContext).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Days in this month',
                    style: Theme.of(sheetContext)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 12),
                  if (records.isEmpty)
                    const Text('No savings records for this month.')
                  else
                    Expanded(
                      child: ListView.separated(
                        itemCount: records.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (BuildContext context, int index) {
                          final DailyRecord record = records[index];
                          return Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Theme.of(context)
                                  .colorScheme
                                  .surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Row(
                              children: <Widget>[
                                Expanded(
                                  child: Text(
                                    _formatDayLabel(record.date),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                Text(formatPeso(record.savings)),
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
  const _SavingsDateTile({required this.record, required this.onTap});

  final DailyRecord record;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bool isOverspent = record.savings < 0;
    final Color accent =
        isOverspent ? const Color(0xFFDC2626) : const Color(0xFF16A34A);

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: accent.withValues(alpha: 0.14)),
        ),
        child: Row(
          children: <Widget>[
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isOverspent
                    ? Icons.trending_down_rounded
                    : Icons.trending_up_rounded,
                color: accent,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    _formatDayLabel(record.date),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    isOverspent
                        ? 'Overspent by ${formatPeso(record.savings.abs())}'
                        : 'Saved ${formatPeso(record.savings)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              formatPeso(record.savings),
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: accent,
              ),
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
    required this.onTap,
  });

  final DateTime month;
  final double savings;
  final int recordCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bool isOverspent = savings < 0;
    final Color accent =
        isOverspent ? const Color(0xFFDC2626) : const Color(0xFF16A34A);

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: accent.withValues(alpha: 0.14)),
        ),
        child: Row(
          children: <Widget>[
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isOverspent ? Icons.calendar_month : Icons.savings_rounded,
                color: accent,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    DateFormat('MMMM yyyy').format(month),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$recordCount day${recordCount == 1 ? '' : 's'} tracked',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              formatPeso(savings),
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: accent,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _formatDayLabel(DateTime dateTime) {
  final DateTime now = DateTime.now();
  if (DateUtils.isSameDay(dateTime, now)) {
    return 'Today, ${DateFormat('MMMM d, yyyy').format(dateTime)}';
  }
  return DateFormat('EEEE, MMM d, yyyy').format(dateTime);
}
