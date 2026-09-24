import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/models/budget_models.dart';
import '../../core/state/app_controller.dart';
import '../../core/utils/formatters.dart';
import '../budget/budget_planner_screen.dart';
import '../together/budget_together_screen.dart';

/// Palette defining the 3 primary design colors matching Daily Budget: Dark Red, Gold, and Dark Green.
class _SpendPalette {
  const _SpendPalette(this.isDark);

  final bool isDark;

  // Dark Red: expenses, overspent alert, delete/cancel actions
  Color get darkRed => const Color(0xFF991B1B);
  Color get darkRedBg =>
      const Color(0xFF991B1B).withValues(alpha: isDark ? 0.20 : 0.08);
  Color get darkRedBorder => const Color(0xFF991B1B).withValues(alpha: 0.25);

  // Gold: target budget, currency symbols, preset accents
  Color get gold => const Color(0xFFD97706);
  Color get goldBg =>
      const Color(0xFFD97706).withValues(alpha: isDark ? 0.20 : 0.08);
  Color get goldBorder => const Color(0xFFD97706).withValues(alpha: 0.25);

  // Dark Green: remaining safe balance, log/confirm actions, active badges
  Color get darkGreen => const Color(0xFF0F766E);
  Color get darkGreenBg =>
      const Color(0xFF0F766E).withValues(alpha: isDark ? 0.20 : 0.08);
  Color get darkGreenBorder => const Color(0xFF0F766E).withValues(alpha: 0.25);
}

/// Represents an item in the batch queue ready to be logged in 1 click
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

class SpendScreen extends ConsumerStatefulWidget {
  const SpendScreen({super.key, this.isTogetherOnly = false});

  final bool isTogetherOnly;

  @override
  ConsumerState<SpendScreen> createState() => _SpendScreenState();
}

class _SpendScreenState extends ConsumerState<SpendScreen> {
  static const String _spendTag = '[SPEND]';
  final List<_PendingSpendItem> _pendingSpends = <_PendingSpendItem>[];

  void _addToQueue({
    required String title,
    required double amount,
    required BudgetCategory category,
    required Color color,
    required IconData icon,
    String note = '',
  }) {
    setState(() {
      _pendingSpends.add(
        _PendingSpendItem(
          id: '${DateTime.now().microsecondsSinceEpoch}_${_pendingSpends.length}',
          title: title,
          amount: amount,
          category: category,
          color: color,
          icon: icon,
          note: note,
        ),
      );
    });
  }

  void _removeFromQueue(String id) {
    setState(() {
      _pendingSpends.removeWhere((item) => item.id == id);
    });
  }

  void _clearQueue() {
    setState(() {
      _pendingSpends.clear();
    });
  }

  void _logAllPendingSpends(BuildContext context, _SpendPalette palette) {
    if (_pendingSpends.isEmpty) return;

    final controller = ref.read(budgetBuddyControllerProvider.notifier);
    final DateTime now = controller.now;
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

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '$count ${count == 1 ? 'spend' : 'spends'} logged (${formatPeso(total)})$suffix',
        ),
        backgroundColor: palette.darkGreen,
        behavior: SnackBarBehavior.floating,
      ),
    );
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
          return AlertDialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            titlePadding: const EdgeInsets.fromLTRB(18, 18, 18, 6),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
            actionsPadding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
            icon: const Icon(
              Icons.warning_amber_rounded,
              color: Color(0xFF991B1B),
              size: 40,
            ),
            title: Text(
              widget.isTogetherOnly
                  ? 'Budget Together Required'
                  : 'Daily Budget Required',
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
            ),
            content: Text(
              widget.isTogetherOnly
                  ? 'You cannot log expenses until you set a Budget Together amount. Please set a budget first.'
                  : 'You cannot log expenses until you set a daily budget. Please set a budget first.',
              textAlign: TextAlign.center,
            ),
            actions: <Widget>[
              FilledButton.icon(
                onPressed: () => Navigator.of(dialogContext).pop(),
                icon: const Icon(Icons.arrow_back_rounded,
                    size: 14, color: Colors.white),
                label: const Text('Back',
                    style: TextStyle(
                        fontWeight: FontWeight.w700, color: Colors.white)),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF991B1B),
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
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
                  backgroundColor: const Color(0xFF0F766E),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text('Set Budget'),
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
    final _SpendPalette palette = _SpendPalette(isDark);

    final bool hasBudget = widget.isTogetherOnly
        ? state.togetherBudget > 0
        : state.settings.totalDailyBudget > 0;

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
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              // Back Button (If pushed on top of another screen)
              if (Navigator.of(context).canPop()) ...<Widget>[
                FilledButton.tonalIcon(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.arrow_back_rounded, size: 16),
                  label: Text(
                    widget.isTogetherOnly ? 'Back to Budget Together' : 'Back',
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 12),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: palette.darkGreenBg,
                    foregroundColor: palette.darkGreen,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    visualDensity: VisualDensity.compact,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
              ],

              // 1. Compact Header (matching Daily Budget screen)
              _buildHeader(
                context,
                currentClock: currentClock,
                hasBudget: hasBudget,
                isOver: isOver,
                palette: palette,
              ),
              const SizedBox(height: 12),

              // 2. Main Content
              Expanded(
                child: ListView(
                  padding: EdgeInsets.zero,
                  children: <Widget>[
                    // Matching Compact Spending Card (Budget, Spent, Remaining)
                    _buildSpendingCard(
                      context,
                      currentBudget: currentBudget,
                      currentSpent: currentSpent,
                      remaining: remaining,
                      progressValue: progressValue,
                      dailySummary: dailySummary,
                      hasBudget: hasBudget,
                      palette: palette,
                    ),
                    const SizedBox(height: 12),

                    // Quick Spend Categories Card (with Plus buttons)
                    _buildCategoriesCard(context, palette),

                    // Pending Spends Batch Card (Visible when items are in queue)
                    if (_pendingSpends.isNotEmpty) ...<Widget>[
                      const SizedBox(height: 12),
                      _buildPendingSpendsCard(context, palette),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      // Persistent Bottom Action Bar when items are queued for 1-tap logging
      bottomNavigationBar: _pendingSpends.isNotEmpty
          ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: Theme.of(context).cardTheme.color ??
                    Theme.of(context).cardColor,
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.12),
                    blurRadius: 10,
                    offset: const Offset(0, -3),
                  ),
                ],
                border: Border(top: BorderSide(color: palette.goldBorder)),
              ),
              child: SafeArea(
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            '${_pendingSpends.length} ${_pendingSpends.length == 1 ? 'spend' : 'spends'} ready',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                            ),
                          ),
                          Text(
                            formatPeso(totalPendingAmount),
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              color: palette.gold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    FilledButton.icon(
                      onPressed: () => _logAllPendingSpends(context, palette),
                      icon: const Icon(Icons.check_circle_rounded, size: 18),
                      label: const Text('Log Spend (1-Tap)'),
                      style: FilledButton.styleFrom(
                        backgroundColor: palette.darkGreen,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 18, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            )
          : null,
    );
  }

  /// Compact header without redundant subtitles or duplicate pills
  Widget _buildHeader(
    BuildContext context, {
    required DateTime currentClock,
    required bool hasBudget,
    required bool isOver,
    required _SpendPalette palette,
  }) {
    final Color statusColor =
        !hasBudget || isOver ? Colors.white : Colors.white;
    final Color statusBg = !hasBudget
        ? palette.darkRed
        : (isOver ? palette.darkRed : palette.darkGreen);
    final Color statusBorder = !hasBudget
        ? palette.darkRed
        : (isOver ? palette.darkRed : palette.darkGreen);
    final IconData statusIcon = !hasBudget
        ? Icons.radio_button_unchecked_rounded
        : (isOver ? Icons.warning_amber_rounded : Icons.check_circle_rounded);
    final String statusLabel =
        !hasBudget ? 'No Budget' : (isOver ? 'Overspent' : 'Active');

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: <Widget>[
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              widget.isTogetherOnly ? 'Spend (Together)' : 'Spend',
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
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: statusBg,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: statusBorder),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(statusIcon, size: 12, color: statusColor),
              const SizedBox(width: 5),
              Text(
                statusLabel,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: statusColor,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Compact Spending Card (Budget, Spent, Remaining with solid bg colors)
  Widget _buildSpendingCard(
    BuildContext context, {
    required double currentBudget,
    required double currentSpent,
    required double remaining,
    required double progressValue,
    required BudgetPeriodSummary dailySummary,
    required bool hasBudget,
    required _SpendPalette palette,
  }) {
    final ThemeData theme = Theme.of(context);
    final bool isOver = remaining < 0;

    final Color barColor = isOver
        ? palette.darkRed
        : (dailySummary.isWarning ? palette.gold : palette.darkGreen);
    const Color badgeColor = Colors.white;
    final Color badgeBg = isOver
        ? palette.darkRed
        : (dailySummary.isWarning ? palette.gold : palette.darkGreen);
    final Color badgeBorder = isOver
        ? palette.darkRed
        : (dailySummary.isWarning ? palette.gold : palette.darkGreen);

    final String badgeLabel = !hasBudget
        ? 'Unset'
        : isOver
            ? 'Over by ${formatPeso(remaining.abs())}'
            : '${(progressValue * 100).toInt()}% Used';

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
      child: Stack(
        children: <Widget>[
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              // Header Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Icon(Icons.analytics_rounded,
                          size: 16, color: palette.darkGreen),
                      const SizedBox(width: 6),
                      Text(
                        'Daily Spending',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: badgeBg,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: badgeBorder),
                    ),
                    child: Text(
                      badgeLabel,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: badgeColor,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Linear progress bar
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: progressValue,
                  minHeight: 7,
                  backgroundColor: barColor.withValues(alpha: 0.12),
                  valueColor: AlwaysStoppedAnimation<Color>(barColor),
                ),
              ),
              const SizedBox(height: 12),

              // 3 Compact Metric Tiles: Budget (Gold), Spent (Dark Red), Remaining (Green / Red)
              Row(
                children: <Widget>[
                  Expanded(
                    child: _CompactMetricTile(
                      label: 'Budget',
                      value: formatPeso(currentBudget),
                      bgColor: palette.gold,
                      icon: Icons.account_balance_wallet_rounded,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _CompactMetricTile(
                      label: 'Spent',
                      value: formatPeso(currentSpent),
                      bgColor: palette.darkRed,
                      icon: Icons.trending_down_rounded,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _CompactMetricTile(
                      label: isOver ? 'Over' : 'Remaining',
                      value: formatPeso(remaining.abs()),
                      bgColor: isOver ? palette.darkRed : palette.darkGreen,
                      icon: isOver
                          ? Icons.warning_amber_rounded
                          : Icons.savings_rounded,
                    ),
                  ),
                ],
              ),

              // Warning Notice
              if (hasBudget &&
                  (dailySummary.isOverspent ||
                      dailySummary.isWarning)) ...<Widget>[
                const SizedBox(height: 8),
                Row(
                  children: <Widget>[
                    Icon(
                      Icons.info_outline_rounded,
                      size: 14,
                      color: dailySummary.isOverspent
                          ? palette.darkRed
                          : palette.gold,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        dailySummary.warningMessage,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: dailySummary.isOverspent
                              ? palette.darkRed
                              : palette.gold,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  /// Categories Card with visible Plus (+) buttons on each category
  Widget _buildCategoriesCard(BuildContext context, _SpendPalette palette) {
    final ThemeData theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.cardTheme.color ?? theme.cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: palette.goldBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // Header Row
          Row(
            children: <Widget>[
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: palette.goldBg,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.shopping_bag_rounded,
                  size: 16,
                  color: palette.gold,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Quick Spend Categories',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    Text(
                      'Tap + to add quick spends in 1 click',
                      style: TextStyle(
                        fontSize: 11,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Grid of categories
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              childAspectRatio: 1.6,
            ),
            itemCount: _spendCategories.length,
            itemBuilder: (BuildContext context, int index) {
              final _SpendCategoryOption option = _spendCategories[index];
              // Calculate pending spends for this category
              final List<_PendingSpendItem> matching = _pendingSpends
                  .where((item) => item.title == option.title)
                  .toList();
              final double categoryPendingTotal =
                  matching.fold(0.0, (sum, item) => sum + item.amount);

              return _CategoryGridTile(
                option: option,
                pendingCount: matching.length,
                pendingTotal: categoryPendingTotal,
                palette: palette,
                onTap: () => _showQuickCategorySheet(context, option, palette),
                onQuickAdd: () {
                  if (!_ensureBudgetSet(context)) return;
                  final double stepAmount =
                      matching.isNotEmpty ? matching.last.amount : 50.0;
                  _addToQueue(
                    title: option.title,
                    amount: stepAmount,
                    category: option.budgetCategory,
                    color: option.color,
                    icon: option.icon,
                  );
                },
                onQuickRemove: matching.isNotEmpty
                    ? () => _removeFromQueue(matching.last.id)
                    : null,
              );
            },
          ),
          const SizedBox(height: 10),

          // Custom Spend Button
          SizedBox(
            width: double.infinity,
            child: FilledButton.tonalIcon(
              onPressed: () => _showCustomSpendSheet(context, palette: palette),
              icon: const Icon(Icons.add_circle_outline_rounded, size: 16),
              label: const Text('Custom Expense'),
              style: FilledButton.styleFrom(
                backgroundColor: palette.darkGreen,
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(40),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Pending Spends Batch Card (Shows queued items with 1-tap Log Spend button)
  Widget _buildPendingSpendsCard(BuildContext context, _SpendPalette palette) {
    final ThemeData theme = Theme.of(context);
    final double totalPending =
        _pendingSpends.fold(0.0, (sum, item) => sum + item.amount);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.cardTheme.color ?? theme.cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: palette.goldBorder, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // Header Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Icon(Icons.playlist_add_check_rounded,
                      size: 18, color: palette.darkGreen),
                  const SizedBox(width: 6),
                  Text(
                    'Ready to Log (${_pendingSpends.length})',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
              InkWell(
                onTap: _clearQueue,
                borderRadius: BorderRadius.circular(6),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  child: Text(
                    'Clear All',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: palette.darkRed,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Itemized Queue List
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _pendingSpends.length,
            separatorBuilder: (BuildContext context, int index) =>
                const SizedBox(height: 8),
            itemBuilder: (BuildContext context, int index) {
              final _PendingSpendItem item = _pendingSpends[index];
              return Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: theme.cardTheme.color ?? theme.cardColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: theme.colorScheme.outlineVariant
                        .withValues(alpha: 0.35),
                  ),
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: Row(
                  children: <Widget>[
                    // Category Icon Avatar
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: item.color.withValues(alpha: 0.14),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(item.icon, size: 16, color: item.color),
                    ),
                    const SizedBox(width: 10),

                    // Title & Note
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            item.title,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          if (item.note.isNotEmpty) ...<Widget>[
                            const SizedBox(height: 2),
                            Text(
                              item.note,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),

                    // Queued Amount Badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: palette.goldBg,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: palette.goldBorder),
                      ),
                      child: Text(
                        formatPeso(item.amount),
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                          color: palette.gold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Remove Button
                    InkWell(
                      onTap: () => _removeFromQueue(item.id),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: palette.darkRedBg,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: palette.darkRedBorder),
                        ),
                        child: Icon(
                          Icons.delete_outline_rounded,
                          size: 16,
                          color: palette.darkRed,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 12),

          // Total Queue Summary Row
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: palette.darkGreenBg,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: palette.darkGreenBorder),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Text(
                  'Total Queued (${_pendingSpends.length} items):',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: palette.darkGreen,
                  ),
                ),
                Text(
                  formatPeso(totalPending),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    color: palette.darkGreen,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // 1-Tap Log All Button
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => _logAllPendingSpends(context, palette),
              icon: const Icon(Icons.check_circle_rounded, size: 18),
              label: Text(
                'Log Spend (${_pendingSpends.length} items • ${formatPeso(totalPending)})',
              ),
              style: FilledButton.styleFrom(
                backgroundColor: palette.darkGreen,
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(44),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showQuickCategorySheet(
    BuildContext context,
    _SpendCategoryOption option,
    _SpendPalette palette,
  ) {
    if (!_ensureBudgetSet(context)) return;

    final TextEditingController amountController =
        TextEditingController(text: '');
    final TextEditingController noteController = TextEditingController();
    const List<double> quickPresets = <double>[20, 50, 100, 150, 200, 500];

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext sheetContext) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            final double currentAmount =
                double.tryParse(amountController.text) ?? 0;
            final double totalPending =
                _pendingSpends.fold(0.0, (sum, item) => sum + item.amount);
            final int grandCount =
                _pendingSpends.length + (currentAmount > 0 ? 1 : 0);

            return ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(sheetContext).size.height * 0.88,
              ),
              child: SingleChildScrollView(
                padding: EdgeInsets.only(
                  left: 20,
                  right: 20,
                  top: 14,
                  bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 20,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    // Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: <Widget>[
                        Row(
                          children: <Widget>[
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: option.color.withValues(alpha: 0.15),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(option.icon,
                                  color: option.color, size: 18),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              option.title,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded, size: 20),
                          onPressed: () => Navigator.of(sheetContext).pop(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // 1-Click Quick Add Presets
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: <Widget>[
                        Text(
                          '1-Click Quick Add Presets:',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Theme.of(sheetContext)
                                .colorScheme
                                .onSurfaceVariant,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: palette.goldBg,
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(color: palette.goldBorder),
                          ),
                          child: Text(
                            'Tap to set amount',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: palette.gold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // 3x2 Grid of Presets with solid background & high-contrast visible numbers
                    GridView.count(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisCount: 3,
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 8,
                      childAspectRatio: 2.1,
                      children: quickPresets.map((double preset) {
                        final bool isSelected = currentAmount == preset;
                        final Color btnBg =
                            isSelected ? palette.darkGreen : palette.gold;

                        return Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () {
                              setModalState(() {
                                amountController.text =
                                    preset.toStringAsFixed(0);
                                amountController.selection =
                                    TextSelection.fromPosition(
                                  TextPosition(
                                      offset: amountController.text.length),
                                );
                              });
                            },
                            borderRadius: BorderRadius.circular(12),
                            child: Ink(
                              decoration: BoxDecoration(
                                color: btnBg,
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: <BoxShadow>[
                                  BoxShadow(
                                    color: btnBg.withValues(alpha: 0.35),
                                    blurRadius: 5,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: <Widget>[
                                  Icon(
                                    isSelected
                                        ? Icons.check_circle_rounded
                                        : Icons.add_rounded,
                                    size: 15,
                                    color: Colors.white,
                                  ),
                                  const SizedBox(width: 3),
                                  Text(
                                    '₱${preset.toStringAsFixed(0)}',
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w900,
                                      color: Colors.white,
                                      letterSpacing: -0.2,
                                      shadows: <Shadow>[
                                        Shadow(
                                          color: Colors.black26,
                                          blurRadius: 2,
                                          offset: Offset(0, 1),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 14),

                    // Custom Amount Input
                    TextField(
                      controller: amountController,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      onChanged: (_) {
                        setModalState(() {});
                      },
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: palette.gold,
                      ),
                      decoration: InputDecoration(
                        isDense: true,
                        prefixIcon: Container(
                          padding: const EdgeInsets.only(left: 12, right: 6),
                          alignment: Alignment.centerLeft,
                          width: 32,
                          child: Text(
                            '₱',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: palette.gold,
                            ),
                          ),
                        ),
                        labelText: 'Custom Amount',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: palette.gold, width: 2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: noteController,
                      decoration: InputDecoration(
                        isDense: true,
                        labelText: 'Note (Optional)',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Action Buttons: Add to Queue OR Log Now (All at Once)
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: () {
                              final double amount =
                                  double.tryParse(amountController.text) ?? 0;
                              if (amount <= 0) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                        'Enter or pick an amount greater than 0.'),
                                  ),
                                );
                                return;
                              }
                              _addToQueue(
                                title: option.title,
                                amount: amount,
                                category: option.budgetCategory,
                                color: option.color,
                                icon: option.icon,
                                note: noteController.text.trim(),
                              );
                              setModalState(() {
                                amountController.clear();
                                noteController.clear();
                              });
                            },
                            icon: const Icon(Icons.add_rounded, size: 16),
                            label: const Text('Add to Queue'),
                            style: FilledButton.styleFrom(
                              backgroundColor: palette.gold,
                              foregroundColor: Colors.white,
                              minimumSize: const Size.fromHeight(42),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: () {
                              final double amount =
                                  double.tryParse(amountController.text) ?? 0;
                              if (amount <= 0 && _pendingSpends.isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                        'Enter or select an amount to log.'),
                                  ),
                                );
                                return;
                              }
                              if (amount > 0) {
                                _addToQueue(
                                  title: option.title,
                                  amount: amount,
                                  category: option.budgetCategory,
                                  color: option.color,
                                  icon: option.icon,
                                  note: noteController.text.trim(),
                                );
                              }
                              Navigator.of(sheetContext).pop();
                              _logAllPendingSpends(context, palette);
                            },
                            icon: const Icon(Icons.check_circle_rounded,
                                size: 16),
                            label: Text(
                              grandCount > 0
                                  ? 'Log Now (${grandCount == 1 ? '1 item' : '$grandCount items'})'
                                  : 'Log Now',
                            ),
                            style: FilledButton.styleFrom(
                              backgroundColor: palette.darkGreen,
                              foregroundColor: Colors.white,
                              minimumSize: const Size.fromHeight(42),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),

                    // Queued Spends List inside sheet ("in tap put the list of queue to it")
                    if (_pendingSpends.isNotEmpty) ...<Widget>[
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: <Widget>[
                          Row(
                            children: <Widget>[
                              Icon(Icons.playlist_add_check_rounded,
                                  size: 16, color: palette.darkGreen),
                              const SizedBox(width: 6),
                              Text(
                                'Queued Spends (${_pendingSpends.length})',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: Theme.of(sheetContext)
                                      .colorScheme
                                      .onSurface,
                                ),
                              ),
                            ],
                          ),
                          Text(
                            formatPeso(totalPending),
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w900,
                              color: palette.gold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 180),
                        child: ListView.separated(
                          shrinkWrap: true,
                          itemCount: _pendingSpends.length,
                          separatorBuilder: (BuildContext context, int index) =>
                              const SizedBox(height: 6),
                          itemBuilder: (BuildContext context, int index) {
                            final _PendingSpendItem item =
                                _pendingSpends[index];
                            return Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 8),
                              decoration: BoxDecoration(
                                color: Theme.of(sheetContext).cardTheme.color ??
                                    Theme.of(sheetContext).cardColor,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: Theme.of(sheetContext)
                                      .colorScheme
                                      .outlineVariant
                                      .withValues(alpha: 0.3),
                                ),
                              ),
                              child: Row(
                                children: <Widget>[
                                  Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: item.color.withValues(alpha: 0.14),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(item.icon,
                                        size: 14, color: item.color),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: <Widget>[
                                        Text(
                                          item.title,
                                          style: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        if (item.note.isNotEmpty)
                                          Text(
                                            item.note,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontSize: 10,
                                              color: Theme.of(sheetContext)
                                                  .colorScheme
                                                  .onSurfaceVariant,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: palette.goldBg,
                                      borderRadius: BorderRadius.circular(6),
                                      border:
                                          Border.all(color: palette.goldBorder),
                                    ),
                                    child: Text(
                                      formatPeso(item.amount),
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w900,
                                        color: palette.gold,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  InkWell(
                                    onTap: () {
                                      _removeFromQueue(item.id);
                                      setModalState(() {});
                                    },
                                    borderRadius: BorderRadius.circular(6),
                                    child: Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: BoxDecoration(
                                        color: palette.darkRedBg,
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Icon(
                                        Icons.close_rounded,
                                        size: 14,
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
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showCustomSpendSheet(
    BuildContext context, {
    ExpenseEntry? existing,
    required _SpendPalette palette,
  }) {
    if (existing == null && !_ensureBudgetSet(context)) return;

    const List<double> quickPresets = <double>[20, 50, 100, 150, 200, 500];

    final TextEditingController nameController =
        TextEditingController(text: existing?.title ?? '');
    final TextEditingController amountController = TextEditingController(
      text: existing != null ? existing.amount.toStringAsFixed(0) : '',
    );
    final TextEditingController noteController =
        TextEditingController(text: _stripSpendTag(existing?.note ?? ''));
    final BudgetCategory selectedCategory =
        existing?.category ?? BudgetCategory.miscellaneous;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext sheetContext) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            final double currentAmount =
                double.tryParse(amountController.text) ?? 0;

            return ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(sheetContext).size.height * 0.88,
              ),
              child: SingleChildScrollView(
                padding: EdgeInsets.only(
                  left: 20,
                  right: 20,
                  top: 14,
                  bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 20,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: <Widget>[
                        Text(
                          existing == null ? 'Custom Expense' : 'Edit Expense',
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded, size: 20),
                          onPressed: () => Navigator.of(sheetContext).pop(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: nameController,
                      decoration: InputDecoration(
                        isDense: true,
                        labelText: 'Name',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Quick Add Presets
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: <Widget>[
                        Text(
                          'Quick Add Presets:',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Theme.of(sheetContext)
                                .colorScheme
                                .onSurfaceVariant,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: palette.goldBg,
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(color: palette.goldBorder),
                          ),
                          child: Text(
                            'Tap to set amount',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: palette.gold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // 3x2 Grid of Presets with solid background & high-contrast visible numbers
                    GridView.count(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisCount: 3,
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 8,
                      childAspectRatio: 2.1,
                      children: quickPresets.map((double preset) {
                        final bool isSelected = currentAmount == preset;
                        final Color btnBg =
                            isSelected ? palette.darkGreen : palette.gold;

                        return Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () {
                              setModalState(() {
                                amountController.text =
                                    preset.toStringAsFixed(0);
                                amountController.selection =
                                    TextSelection.fromPosition(
                                  TextPosition(
                                      offset: amountController.text.length),
                                );
                              });
                            },
                            borderRadius: BorderRadius.circular(12),
                            child: Ink(
                              decoration: BoxDecoration(
                                color: btnBg,
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: <BoxShadow>[
                                  BoxShadow(
                                    color: btnBg.withValues(alpha: 0.35),
                                    blurRadius: 5,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: <Widget>[
                                  Icon(
                                    isSelected
                                        ? Icons.check_circle_rounded
                                        : Icons.add_rounded,
                                    size: 15,
                                    color: Colors.white,
                                  ),
                                  const SizedBox(width: 3),
                                  Text(
                                    '₱${preset.toStringAsFixed(0)}',
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w900,
                                      color: Colors.white,
                                      letterSpacing: -0.2,
                                      shadows: <Shadow>[
                                        Shadow(
                                          color: Colors.black26,
                                          blurRadius: 2,
                                          offset: Offset(0, 1),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 12),

                    TextField(
                      controller: amountController,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      onChanged: (_) {
                        setModalState(() {});
                      },
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: palette.gold,
                      ),
                      decoration: InputDecoration(
                        isDense: true,
                        prefixIcon: Container(
                          padding: const EdgeInsets.only(left: 12, right: 6),
                          alignment: Alignment.centerLeft,
                          width: 32,
                          child: Text(
                            '₱',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: palette.gold,
                            ),
                          ),
                        ),
                        labelText: 'Amount',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: palette.gold, width: 2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: noteController,
                      decoration: InputDecoration(
                        isDense: true,
                        labelText: 'Note (Optional)',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: <Widget>[
                        if (existing != null) ...<Widget>[
                          Expanded(
                            child: FilledButton.icon(
                              onPressed: () {
                                ref
                                    .read(budgetBuddyControllerProvider.notifier)
                                    .deleteExpense(existing.id);
                                Navigator.of(sheetContext).pop();
                              },
                              icon: const Icon(Icons.delete_outline_rounded,
                                  size: 16),
                              label: const Text('Delete'),
                              style: FilledButton.styleFrom(
                                backgroundColor: palette.darkRed,
                                foregroundColor: Colors.white,
                                minimumSize: const Size.fromHeight(42),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                        ] else ...<Widget>[
                          Expanded(
                            child: FilledButton.icon(
                              onPressed: () {
                                final double amount =
                                    double.tryParse(amountController.text) ?? 0;
                                final String title = nameController.text.trim();
                                if (amount <= 0 || title.isEmpty) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                          'Enter a name and an amount greater than 0.'),
                                    ),
                                  );
                                  return;
                                }
                                _addToQueue(
                                  title: title,
                                  amount: amount,
                                  category: selectedCategory,
                                  color: palette.darkGreen,
                                  icon: Icons.receipt_long_rounded,
                                  note: noteController.text.trim(),
                                );
                                Navigator.of(sheetContext).pop();
                              },
                              icon: const Icon(Icons.add_rounded, size: 16),
                              label: const Text('Add to Queue'),
                              style: FilledButton.styleFrom(
                                backgroundColor: palette.gold,
                                foregroundColor: Colors.white,
                                minimumSize: const Size.fromHeight(42),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                        ],
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: () {
                              final double amount =
                                  double.tryParse(amountController.text) ?? 0;
                              final String title = nameController.text.trim();
                              if (amount <= 0 || title.isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                        'Enter a name and an amount greater than 0.'),
                                  ),
                                );
                                return;
                              }

                              Navigator.of(sheetContext).pop();
                              if (existing == null) {
                                if (_pendingSpends.isNotEmpty) {
                                  _addToQueue(
                                    title: title,
                                    amount: amount,
                                    category: selectedCategory,
                                    color: palette.darkGreen,
                                    icon: Icons.receipt_long_rounded,
                                    note: noteController.text.trim(),
                                  );
                                  _logAllPendingSpends(context, palette);
                                } else {
                                  _logSingleSpend(
                                    context,
                                    title: title,
                                    amount: amount,
                                    category: selectedCategory,
                                    note: noteController.text.trim(),
                                  );
                                }
                                return;
                              }

                              ref
                                  .read(budgetBuddyControllerProvider.notifier)
                                  .updateExpense(
                                    existing.copyWith(
                                      title: title,
                                      amount: amount,
                                      category: selectedCategory,
                                      note: _stripSpendTag(
                                          noteController.text.trim()),
                                    ),
                                  );
                            },
                            icon: const Icon(Icons.check_rounded, size: 16),
                            label: Text(existing == null ? 'Log Now' : 'Save'),
                            style: FilledButton.styleFrom(
                              backgroundColor: palette.darkGreen,
                              foregroundColor: Colors.white,
                              minimumSize: const Size.fromHeight(42),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
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
      },
    );
  }

  void _logSingleSpend(
    BuildContext context, {
    required String title,
    required double amount,
    required BudgetCategory category,
    required String note,
  }) {
    ref.read(budgetBuddyControllerProvider.notifier).addExpense(
          title: title,
          amount: amount,
          category: category,
          note: _stripSpendTag(note),
          dateTime: ref.read(budgetBuddyControllerProvider.notifier).now,
          source: widget.isTogetherOnly ? 'togetherSpend' : 'manual',
          spendCategory: title,
        );

    final BudgetSummary summary = widget.isTogetherOnly
        ? ref.read(budgetTogetherSummaryProvider)
        : ref.read(budgetSummaryProvider);
    final BudgetPeriodSummary? daySummary =
        summary.periodSummaries[BudgetPeriod.daily];
    final String suffix = daySummary == null || !daySummary.isActive
        ? ''
        : ' • Left: ${formatPeso(daySummary.remaining)}';

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$title logged$suffix'),
        backgroundColor: const Color(0xFF0F766E),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  String _stripSpendTag(String note) {
    final String trimmed = note.trim();
    if (trimmed.startsWith(_spendTag)) {
      return trimmed.substring(_spendTag.length).trim();
    }
    return trimmed;
  }
}

/// Compact Metric Tile for Budget, Spent, and Remaining matching Daily Budget screen
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
                shadows: <Shadow>[
                  Shadow(
                    color: Colors.black26,
                    blurRadius: 2,
                    offset: Offset(0, 1),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Category Grid Tile with prominent Plus (+) button and active queue stepper
class _CategoryGridTile extends StatelessWidget {
  const _CategoryGridTile({
    required this.option,
    required this.onTap,
    this.pendingCount = 0,
    this.pendingTotal = 0,
    required this.palette,
    this.onQuickAdd,
    this.onQuickRemove,
  });

  final _SpendCategoryOption option;
  final VoidCallback onTap;
  final int pendingCount;
  final double pendingTotal;
  final _SpendPalette palette;
  final VoidCallback? onQuickAdd;
  final VoidCallback? onQuickRemove;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool hasPending = pendingCount > 0;

    return Material(
      color: hasPending
          ? palette.goldBg
          : (theme.cardTheme.color ?? theme.cardColor),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: hasPending
              ? palette.gold
              : theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
          width: hasPending ? 1.5 : 1.0,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Row(
            children: <Widget>[
              // Category Icon
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: option.color.withValues(alpha: 0.14),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  option.icon,
                  color: option.color,
                  size: 18,
                ),
              ),
              const SizedBox(width: 8),
              // Category Name & pending amount badge
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      option.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                    if (hasPending) ...<Widget>[
                      const SizedBox(height: 2),
                      Text(
                        '+ ${formatPeso(pendingTotal)}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: palette.gold,
                        ),
                      ),
                    ] else ...<Widget>[
                      const SizedBox(height: 2),
                      Text(
                        'Tap to add',
                        style: TextStyle(
                          fontSize: 10,
                          color: theme.colorScheme.onSurfaceVariant
                              .withValues(alpha: 0.65),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              // Plus / Stepper Actions
              if (hasPending) ...<Widget>[
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    if (onQuickRemove != null)
                      InkWell(
                        onTap: onQuickRemove,
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.all(3),
                          decoration: BoxDecoration(
                            color: palette.darkRedBg,
                            shape: BoxShape.circle,
                            border: Border.all(color: palette.darkRedBorder),
                          ),
                          child: Icon(
                            Icons.remove_rounded,
                            size: 13,
                            color: palette.darkRed,
                          ),
                        ),
                      ),
                    const SizedBox(width: 4),
                    InkWell(
                      onTap: onQuickAdd,
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          color: palette.gold,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.add_rounded,
                          size: 13,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ] else ...<Widget>[
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: palette.darkGreenBg,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.add_rounded,
                    size: 16,
                    color: palette.darkGreen,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
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
    title: 'Health',
    icon: Icons.health_and_safety_rounded,
    budgetCategory: BudgetCategory.miscellaneous,
    color: Color(0xFF0F766E), // Dark Green
  ),
  _SpendCategoryOption(
    title: 'Bills & Utilities',
    icon: Icons.receipt_long_rounded,
    budgetCategory: BudgetCategory.miscellaneous,
    color: Color(0xFF991B1B), // Dark Red
  ),
];
