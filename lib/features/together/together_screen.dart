import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/models/budget_models.dart';
import '../../core/state/app_controller.dart';
import '../../core/utils/formatters.dart';
import '../expenses/expense_tracker_screen.dart';
import '../savings/savings_screen.dart';
import '../spend/spend_screen.dart';
import 'budget_together_screen.dart';

/// Palette defining the unified 3 primary design colors matching Daily Budget, Spend, and Savings.
class _TogetherPalette {
  const _TogetherPalette(this.isDark);

  final bool isDark;

  Color get darkRed => const Color(0xFF991B1B);
  Color get darkRedBg =>
      const Color(0xFF991B1B).withValues(alpha: isDark ? 0.20 : 0.08);
  Color get darkRedBorder => const Color(0xFF991B1B).withValues(alpha: 0.25);

  Color get gold => const Color(0xFFD97706);
  Color get goldBg =>
      const Color(0xFFD97706).withValues(alpha: isDark ? 0.20 : 0.08);
  Color get goldBorder => const Color(0xFFD97706).withValues(alpha: 0.25);

  Color get darkGreen => const Color(0xFF0F766E);
  Color get darkGreenBg =>
      const Color(0xFF0F766E).withValues(alpha: isDark ? 0.20 : 0.08);
  Color get darkGreenBorder => const Color(0xFF0F766E).withValues(alpha: 0.25);
}

/// Compact Metric Tile matching Daily Budget, Spend, and Savings screens
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
                fontSize: 15,
                fontWeight: FontWeight.w900,
                color: Colors.white,
                letterSpacing: -0.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class TogetherScreen extends ConsumerWidget {
  const TogetherScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final BudgetBuddyState state = ref.watch(budgetBuddyControllerProvider);
    final DateTime currentClock =
        ref.read(budgetBuddyControllerProvider.notifier).currentEffectiveTime;
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final _TogetherPalette palette = _TogetherPalette(isDark);

    final double totalBudget = state.togetherBudget;
    final double spent = state.expenses
        .where((ExpenseEntry e) => e.source == 'togetherSpend')
        .fold<double>(0.0, (double sum, ExpenseEntry e) => sum + e.amount);
    final double remaining = totalBudget - spent;
    final bool hasBudget = totalBudget > 0;
    final bool isOver = remaining < 0;
    final bool isWarning = !isOver && hasBudget && spent >= (totalBudget * 0.8);
    final double progressValue =
        totalBudget > 0 ? (spent / totalBudget).clamp(0.0, 1.0) : 0.0;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              // 1. Compact Header matching app design
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
                    // Main Overview Card for Budget Together
                    _buildOverviewCard(
                      context,
                      totalBudget: totalBudget,
                      spent: spent,
                      remaining: remaining,
                      progressValue: progressValue,
                      hasBudget: hasBudget,
                      isOver: isOver,
                      isWarning: isWarning,
                      palette: palette,
                    ),
                    const SizedBox(height: 12),

                    // Quick Action Buttons
                    _buildQuickActions(context, palette),
                    const SizedBox(height: 14),

                    // Hub Menu Sections Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: <Widget>[
                        Row(
                          children: <Widget>[
                            Icon(Icons.hub_rounded,
                                size: 16, color: palette.gold),
                            const SizedBox(width: 6),
                            Text(
                              'Together Modules',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: palette.gold,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            '4 Sections',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // 1. Budget Together Module
                    _buildHubTile(
                      context,
                      title: 'Tab Budget',
                      subtitle: hasBudget
                          ? 'Current limit: ${formatPeso(totalBudget)}'
                          : 'Set dedicated group tab budget',
                      icon: Icons.account_balance_wallet_rounded,
                      accentColor: palette.gold,
                      accentBg: palette.goldBg,
                      accentBorder: palette.goldBorder,
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (BuildContext context) =>
                                const BudgetTogetherScreen(),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 8),

                    // 2. Spend Module
                    _buildHubTile(
                      context,
                      title: 'Spend & Log',
                      subtitle: 'Add quick spend items and batch queue',
                      icon: Icons.shopping_bag_rounded,
                      accentColor: palette.darkGreen,
                      accentBg: palette.darkGreenBg,
                      accentBorder: palette.darkGreenBorder,
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (BuildContext context) =>
                                const SpendScreen(isTogetherOnly: true),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 8),

                    // 3. Expenses Module
                    _buildHubTile(
                      context,
                      title: 'Logged Expenses',
                      subtitle: 'Review and manage group transactions',
                      icon: Icons.receipt_long_rounded,
                      accentColor: palette.darkRed,
                      accentBg: palette.darkRedBg,
                      accentBorder: palette.darkRedBorder,
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (BuildContext context) =>
                                const ExpenseTrackerScreen(
                              isTogetherOnly: true,
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 8),

                    // 4. Savings Module
                    _buildHubTile(
                      context,
                      title: 'Tab Savings',
                      subtitle: 'Track today\'s and monthly savings progress',
                      icon: Icons.savings_rounded,
                      accentColor: palette.gold,
                      accentBg: palette.goldBg,
                      accentBorder: palette.goldBorder,
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (BuildContext context) =>
                                const SavingsScreen(
                              isTogetherOnly: true,
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Compact Header matching Daily Budget & Spend screens
  Widget _buildHeader(
    BuildContext context, {
    required DateTime currentClock,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'Budget Together',
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

  /// Compact Overview Card with 3 Solid Metric Tiles
  Widget _buildOverviewCard(
    BuildContext context, {
    required double totalBudget,
    required double spent,
    required double remaining,
    required double progressValue,
    required bool hasBudget,
    required bool isOver,
    required bool isWarning,
    required _TogetherPalette palette,
  }) {
    final ThemeData theme = Theme.of(context);

    final Color barColor = isOver
        ? palette.darkRed
        : (isWarning ? palette.gold : palette.darkGreen);
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
                Icons.groups_rounded,
                size: 16,
                color: palette.darkGreen,
              ),
              const SizedBox(width: 6),
              Text(
                'Together Overview',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ],
          ),
              const SizedBox(height: 10),

              // Progress Bar
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: progressValue,
                  minHeight: 7,
                  backgroundColor: barColor.withValues(alpha: 0.12),
                  valueColor: AlwaysStoppedAnimation<Color>(barColor),
                ),
              ),
              const SizedBox(height: 8),

              // Progress caption
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  Text(
                    hasBudget
                        ? '${formatPeso(spent)} spent of ${formatPeso(totalBudget)}'
                        : 'No budget set for Budget Together',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  Text(
                    isOver
                        ? 'Over limit'
                        : '${formatPeso(remaining > 0 ? remaining : 0)} left',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: isOver ? palette.darkRed : palette.darkGreen,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // 3 Compact Metric Tiles
              Row(
                children: <Widget>[
                  Expanded(
                    child: _CompactMetricTile(
                      label: 'Remaining',
                      value: (isOver ? '-' : '') + formatPeso(remaining.abs()),
                      bgColor: isOver ? palette.darkRed : palette.darkGreen,
                      icon: isOver
                          ? Icons.trending_down_rounded
                          : Icons.savings_rounded,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _CompactMetricTile(
                      label: 'Tab Budget',
                      value: formatPeso(totalBudget),
                      bgColor: palette.gold,
                      icon: Icons.account_balance_wallet_rounded,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _CompactMetricTile(
                      label: 'Tab Spent',
                      value: formatPeso(spent),
                      bgColor: isOver
                          ? palette.darkRed
                          : (isWarning ? palette.gold : palette.darkGreen),
                      icon: Icons.shopping_bag_rounded,
                    ),
                  ),
                ],
              ),

              // Over-budget Warning Alert Banner
              if (isOver) ...<Widget>[
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
                          'Over-budget warning: Tab spending exceeded budget by ${formatPeso(remaining.abs())}.',
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

  /// Solid Quick Action Buttons
  Widget _buildQuickActions(BuildContext context, _TogetherPalette palette) {
    return Row(
      children: <Widget>[
        Expanded(
          child: FilledButton.icon(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (BuildContext context) =>
                      const SpendScreen(isTogetherOnly: true),
                ),
              );
            },
            icon: const Icon(Icons.add_shopping_cart_rounded, size: 16),
            label: const Text(
              'Log Spend',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
            ),
            style: FilledButton.styleFrom(
              backgroundColor: palette.darkGreen,
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(42),
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
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (BuildContext context) =>
                      const BudgetTogetherScreen(),
                ),
              );
            },
            icon: const Icon(Icons.account_balance_wallet_rounded, size: 16),
            label: const Text(
              'Set Budget',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
            ),
            style: FilledButton.styleFrom(
              backgroundColor: palette.gold,
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(42),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Hub Navigation Card
  Widget _buildHubTile(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required Color accentColor,
    required Color accentBg,
    required Color accentBorder,
    required VoidCallback onTap,
  }) {
    final ThemeData theme = Theme.of(context);

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest
              .withValues(alpha: 0.35),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.25),
          ),
        ),
        child: Row(
          children: <Widget>[
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: accentBg,
                shape: BoxShape.circle,
                border: Border.all(color: accentBorder),
              ),
              child: Icon(icon, color: accentColor, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              Icons.chevron_right_rounded,
              size: 22,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}
