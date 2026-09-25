import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/models/budget_models.dart';
import '../../core/state/app_controller.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/budget_cards.dart';

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

/// Savings Goal Model with local persistence support
class SavingsGoal {
  const SavingsGoal({
    required this.id,
    required this.title,
    required this.targetAmount,
    required this.currentAmount,
    this.targetDate,
    this.iconKey = 'emergency',
    this.note = '',
  });

  final String id;
  final String title;
  final double targetAmount;
  final double currentAmount;
  final DateTime? targetDate;
  final String iconKey;
  final String note;

  double get progress => targetAmount > 0
      ? (currentAmount / targetAmount).clamp(0.0, 1.0)
      : 0.0;

  int get percentage => (progress * 100).round();

  SavingsGoal copyWith({
    String? id,
    String? title,
    double? targetAmount,
    double? currentAmount,
    DateTime? targetDate,
    String? iconKey,
    String? note,
  }) {
    return SavingsGoal(
      id: id ?? this.id,
      title: title ?? this.title,
      targetAmount: targetAmount ?? this.targetAmount,
      currentAmount: currentAmount ?? this.currentAmount,
      targetDate: targetDate ?? this.targetDate,
      iconKey: iconKey ?? this.iconKey,
      note: note ?? this.note,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'title': title,
        'targetAmount': targetAmount,
        'currentAmount': currentAmount,
        'targetDate': targetDate?.toIso8601String(),
        'iconKey': iconKey,
        'note': note,
      };

  factory SavingsGoal.fromJson(Map<String, dynamic> json) {
    return SavingsGoal(
      id: json['id'] as String? ?? UniqueKey().toString(),
      title: json['title'] as String? ?? 'Savings Target',
      targetAmount: (json['targetAmount'] as num?)?.toDouble() ?? 10000.0,
      currentAmount: (json['currentAmount'] as num?)?.toDouble() ?? 0.0,
      targetDate: json['targetDate'] != null
          ? DateTime.tryParse(json['targetDate'] as String)
          : null,
      iconKey: json['iconKey'] as String? ?? 'emergency',
      note: json['note'] as String? ?? '',
    );
  }
}

enum SavingsSection { daily, monthly }

class SavingsScreen extends ConsumerStatefulWidget {
  const SavingsScreen({super.key, this.isTogetherOnly = false});

  final bool isTogetherOnly;

  @override
  ConsumerState<SavingsScreen> createState() => _SavingsScreenState();
}

class _SavingsScreenState extends ConsumerState<SavingsScreen> {
  static const String _goalsPrefsKey = 'budgetbuddy_savings_goals_v2';
  SavingsSection _activeSection = SavingsSection.daily;

  List<SavingsGoal> _goals = <SavingsGoal>[];
  bool _isGoalsLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadGoals();
  }

  Future<void> _loadGoals() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final String? rawJson = prefs.getString(_goalsPrefsKey);
      if (rawJson != null && rawJson.isNotEmpty) {
        final dynamic decoded = jsonDecode(rawJson);
        if (decoded is List) {
          setState(() {
            _goals = decoded
                .map((e) => SavingsGoal.fromJson(e as Map<String, dynamic>))
                .toList();
            _isGoalsLoaded = true;
          });
          return;
        }
      }
    } catch (_) {
      // Fallback to starter goals
    }

    // Default starter goals
    setState(() {
      _goals = <SavingsGoal>[
        SavingsGoal(
          id: 'goal_emergency',
          title: 'Emergency Fund',
          targetAmount: 25000,
          currentAmount: 10000,
          targetDate: DateTime.now().add(const Duration(days: 120)),
          iconKey: 'emergency',
          note: '3-6 months essential buffer',
        ),
        SavingsGoal(
          id: 'goal_gadget',
          title: 'New Phone / Tech',
          targetAmount: 35000,
          currentAmount: 12500,
          targetDate: DateTime.now().add(const Duration(days: 60)),
          iconKey: 'phone',
          note: 'Device upgrade fund',
        ),
        SavingsGoal(
          id: 'goal_vacation',
          title: 'Dream Vacation',
          targetAmount: 20000,
          currentAmount: 4000,
          targetDate: DateTime.now().add(const Duration(days: 90)),
          iconKey: 'vacation',
          note: 'Island getaway trip',
        ),
      ];
      _isGoalsLoaded = true;
    });
    _saveGoals();
  }

  Future<void> _saveGoals() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final String raw =
          jsonEncode(_goals.map((SavingsGoal g) => g.toJson()).toList());
      await prefs.setString(_goalsPrefsKey, raw);
    } catch (_) {}
  }

  IconData _iconForGoalKey(String key) {
    return switch (key) {
      'emergency' || 'shield' => Icons.shield_rounded,
      'phone' || 'gadget' => Icons.phone_iphone_rounded,
      'vacation' || 'travel' => Icons.flight_takeoff_rounded,
      'home' => Icons.home_rounded,
      'school' || 'education' => Icons.school_rounded,
      'car' || 'vehicle' => Icons.directions_car_rounded,
      'shopping' => Icons.shopping_bag_rounded,
      _ => Icons.savings_rounded,
    };
  }

  @override
  Widget build(BuildContext context) {
    final BudgetBuddyState state = ref.watch(budgetBuddyControllerProvider);
    final DateTime currentClock =
        ref.watch(budgetBuddyControllerProvider.notifier).now;
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final _SavingsTokens tokens = _SavingsTokens(isDark);

    final List<DailyRecord> records = _getRecords(state, currentClock);
    final List<DateTime> availableMonths = _availableMonths(records);

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
                      tokens: tokens,
                    ),
                    const SizedBox(height: 14),

                    // 4. Quick Action Buttons
                    _buildQuickActionButtons(context, state: state, tokens: tokens),
                    const SizedBox(height: 20),

                    // 3. Savings Goals Section Title
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
                                Icons.flag_rounded,
                                size: 16,
                                color: _SavingsTokens.targetGold,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Savings Goals & Targets',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: tokens.textPrimary,
                                letterSpacing: -0.4,
                              ),
                            ),
                          ],
                        ),
                        SoftPill(
                          text: '${_goals.length} active',
                          color: _SavingsTokens.savingsGreen,
                          fontSize: 11,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ),

            // 3. Savings Goals Bento Cards Stack
            if (_goals.isEmpty && _isGoalsLoaded)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: BentoCard(
                    padding: const EdgeInsets.all(24),
                    borderRadius: 18,
                    child: Column(
                      children: <Widget>[
                        Icon(Icons.savings_outlined,
                            size: 36, color: tokens.textMuted),
                        const SizedBox(height: 8),
                        Text(
                          'No Savings Goals Yet',
                          style: GoogleFonts.plusJakartaSans(
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                            color: tokens.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Create your first savings target to track your milestone progress.',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            color: tokens.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 12),
                        FilledButton.icon(
                          onPressed: () =>
                              _showAddOrEditGoalSheet(context, tokens: tokens),
                          icon: const Icon(Icons.add_rounded, size: 16),
                          label: const Text('Add Goal'),
                          style: FilledButton.styleFrom(
                            backgroundColor: _SavingsTokens.savingsGreen,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (BuildContext context, int index) {
                      final SavingsGoal goal = _goals[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _buildGoalTileCard(
                          context,
                          goal: goal,
                          tokens: tokens,
                        ),
                      );
                    },
                    childCount: _goals.length,
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
                              'Historical Balance Logs',
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

                    // Daily / Monthly Toggle
                    _buildSectionToggle(context, tokens),
                    const SizedBox(height: 12),

                    // History Bento Card with Records
                    _buildHistoryCard(
                      context,
                      records: records,
                      availableMonths: availableMonths,
                      currentClock: currentClock,
                      tokens: tokens,
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
    final int activeCount = _goals.length;
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
              '$activeCount active ${activeCount == 1 ? "goal" : "goals"} • Track wealth & manage deficits',
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
    required _SavingsTokens tokens,
  }) {
    final double savingsAmount =
        widget.isTogetherOnly ? state.togetherBudget : state.totalSavings;
    final double debtAmount =
        widget.isTogetherOnly ? togetherSpent : state.savingsDebt;
    final bool hasDebt = debtAmount > 0;

    return Row(
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
                      onTap: () => _showQuickDepositSheet(context, tokens: tokens),
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
                  widget.isTogetherOnly ? 'Tab Budget' : 'Total Savings Vault',
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
                    formatPeso(savingsAmount),
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: _SavingsTokens.savingsGreen,
                      letterSpacing: -0.6,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Accumulated balance',
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
        const SizedBox(width: 12),

        // Hero Bento 2: Running Deficit / Debt Tracker (Dark Red #991B1B)
        Expanded(
          child: BentoCard(
            borderRadius: 24,
            padding: const EdgeInsets.all(16),
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
                    SoftPill(
                      text: hasDebt ? 'Deficit to Pay' : 'Clean Record',
                      color: hasDebt
                          ? _SavingsTokens.deficitRed
                          : _SavingsTokens.savingsGreen,
                      fontSize: 10,
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  widget.isTogetherOnly ? 'Tab Spent' : 'Running Deficit',
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
                  hasDebt ? 'Rolled over deficit' : 'No outstanding debt',
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
    );
  }

  /// 4. Quick Action Buttons: Add New Goal / Deposit & Withdraw / Cover Deficit
  Widget _buildQuickActionButtons(
    BuildContext context, {
    required BudgetBuddyState state,
    required _SavingsTokens tokens,
  }) {
    return Row(
      children: <Widget>[
        // Add New Goal / Deposit (Solid Dark Green #0F766E)
        Expanded(
          child: FilledButton.icon(
            onPressed: () => _showAddOrEditGoalSheet(context, tokens: tokens),
            icon: const Icon(Icons.add_rounded, size: 16, color: Colors.white),
            label: Text(
              'Add Goal',
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.w700,
                fontSize: 13,
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
        const SizedBox(width: 10),

        // Withdraw / Cover Deficit (Solid Dark Red #991B1B)
        Expanded(
          child: FilledButton.icon(
            onPressed: () =>
                _showWithdrawOrCoverDeficitSheet(context, state: state, tokens: tokens),
            icon: const Icon(Icons.outbond_rounded, size: 16, color: Colors.white),
            label: Text(
              state.savingsDebt > 0 ? 'Cover Deficit' : 'Withdraw',
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.w700,
                fontSize: 13,
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
    );
  }

  /// 3. Savings Goal Progress Tile Card (BorderRadius 18)
  Widget _buildGoalTileCard(
    BuildContext context, {
    required SavingsGoal goal,
    required _SavingsTokens tokens,
  }) {
    final IconData icon = _iconForGoalKey(goal.iconKey);
    final bool isCompleted = goal.currentAmount >= goal.targetAmount;

    return BentoCard(
      padding: const EdgeInsets.all(15),
      borderRadius: 18,
      onTap: () => _showGoalDetailSheet(context, goal: goal, tokens: tokens),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // Header: Category Icon + Title + Percentage Pill
          Row(
            children: <Widget>[
              // Category icon in soft tinted box (alpha: 0.10)
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: tokens.tint(
                    isCompleted
                        ? _SavingsTokens.savingsGreen
                        : _SavingsTokens.targetGold,
                    0.12,
                  ),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  size: 17,
                  color: isCompleted
                      ? _SavingsTokens.savingsGreen
                      : _SavingsTokens.targetGold,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      goal.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: tokens.textPrimary,
                      ),
                    ),
                    if (goal.targetDate != null) ...<Widget>[
                      const SizedBox(height: 2),
                      Text(
                        'Target by ${DateFormat('MMM d, yyyy').format(goal.targetDate!)}',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: tokens.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Percentage Badge Capsule
              SoftPill(
                text: '${goal.percentage}% completed',
                color: isCompleted
                    ? _SavingsTokens.savingsGreen
                    : _SavingsTokens.targetGold,
                fontSize: 10.5,
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Amounts: Current Saved vs Gold Target Goal (₱10,000 / ₱50,000)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: <Widget>[
                  Text(
                    formatPeso(goal.currentAmount),
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                      color: _SavingsTokens.savingsGreen,
                    ),
                  ),
                  Text(
                    ' / ${formatPeso(goal.targetAmount)}',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: _SavingsTokens.targetGold,
                    ),
                  ),
                ],
              ),
              Text(
                goal.targetAmount > goal.currentAmount
                    ? '${formatPeso(goal.targetAmount - goal.currentAmount)} left'
                    : 'Target Achieved! 🎉',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: isCompleted
                      ? _SavingsTokens.savingsGreen
                      : tokens.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Clean Animated Progress Bar (Dark Green fill on soft track)
          BentoHealthBar(
            progress: goal.progress,
            color: isCompleted
                ? _SavingsTokens.savingsGreen
                : _SavingsTokens.savingsGreen,
            backgroundColor: tokens.subCardBg,
            height: 7,
          ),
        ],
      ),
    );
  }

  /// 5. Goal Detail & Deposit Bottom Sheet Modal
  void _showGoalDetailSheet(
    BuildContext context, {
    required SavingsGoal goal,
    required _SavingsTokens tokens,
  }) {
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

                // Title row
                Row(
                  children: <Widget>[
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: tokens.tint(_SavingsTokens.savingsGreen, 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _iconForGoalKey(goal.iconKey),
                        size: 20,
                        color: _SavingsTokens.savingsGreen,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            goal.title,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: tokens.textPrimary,
                            ),
                          ),
                          Text(
                            'Goal Details & Actions',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12,
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

                // Metrics Bento Breakdown Container
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
                        label: 'Saved So Far',
                        value: formatPeso(goal.currentAmount),
                        valueColor: _SavingsTokens.savingsGreen,
                        tokens: tokens,
                      ),
                      const Divider(height: 16),
                      _buildDetailRow(
                        label: 'Target Goal',
                        value: formatPeso(goal.targetAmount),
                        valueColor: _SavingsTokens.targetGold,
                        tokens: tokens,
                      ),
                      const Divider(height: 16),
                      _buildDetailRow(
                        label: 'Remaining',
                        value: formatPeso(
                            (goal.targetAmount - goal.currentAmount).clamp(0, double.infinity)),
                        tokens: tokens,
                      ),
                      if (goal.targetDate != null) ...<Widget>[
                        const Divider(height: 16),
                        _buildDetailRow(
                          label: 'Target Date',
                          value: DateFormat('MMMM d, yyyy').format(goal.targetDate!),
                          tokens: tokens,
                        ),
                      ],
                      if (goal.note.trim().isNotEmpty) ...<Widget>[
                        const Divider(height: 16),
                        _buildDetailRow(
                          label: 'Note',
                          value: goal.note,
                          tokens: tokens,
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Quick Deposit Pill Trigger
                FilledButton.icon(
                  onPressed: () {
                    Navigator.of(sheetContext).pop();
                    _showDepositDialog(context, targetGoal: goal, tokens: tokens);
                  },
                  icon: const Icon(Icons.savings_rounded,
                      size: 15, color: Colors.white),
                  label: Text(
                    'Deposit Into This Goal',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: _SavingsTokens.savingsGreen,
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(44),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 10),

                // Standardized Solid Buttons: Edit Goal (Gold) & Delete Goal (Dark Red)
                Row(
                  children: <Widget>[
                    // Edit Goal Button (Solid Gold #D97706)
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () {
                          Navigator.of(sheetContext).pop();
                          _showAddOrEditGoalSheet(context,
                              existingGoal: goal, tokens: tokens);
                        },
                        icon: const Icon(Icons.edit_rounded,
                            size: 15, color: Colors.white),
                        label: Text(
                          'Edit Goal',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
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
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),

                    // Delete Goal Button (Solid Dark Red #991B1B)
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () async {
                          Navigator.of(sheetContext).pop();
                          final bool confirmed = await _confirmDeleteGoalDialog(
                              context, goal, tokens);
                          if (confirmed) {
                            setState(() {
                              _goals.removeWhere((g) => g.id == goal.id);
                            });
                            await _saveGoals();
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Goal removed successfully.'),
                                  backgroundColor: _SavingsTokens.deficitRed,
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            }
                          }
                        },
                        icon: const Icon(Icons.delete_outline_rounded,
                            size: 15, color: Colors.white),
                        label: Text(
                          'Delete Goal',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
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

  /// Deposit Dialog
  Future<void> _showDepositDialog(
    BuildContext context, {
    SavingsGoal? targetGoal,
    required _SavingsTokens tokens,
  }) async {
    final TextEditingController amountCtrl = TextEditingController();
    SavingsGoal? selectedGoal = targetGoal ?? (_goals.isNotEmpty ? _goals.first : null);

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
                    if (_goals.isNotEmpty) ...<Widget>[
                      Text(
                        'Allocate to Goal',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: tokens.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<SavingsGoal>(
                        value: selectedGoal,
                        decoration: InputDecoration(
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: tokens.cardBorder),
                          ),
                          isDense: true,
                        ),
                        items: _goals.map((SavingsGoal g) {
                          return DropdownMenuItem<SavingsGoal>(
                            value: g,
                            child: Text(
                              g.title,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          );
                        }).toList(),
                        onChanged: (SavingsGoal? val) {
                          setModalState(() => selectedGoal = val);
                        },
                      ),
                      const SizedBox(height: 12),
                    ],

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

                    // 1. Update Goal Amount if selected
                    if (selectedGoal != null) {
                      setState(() {
                        final int idx =
                            _goals.indexWhere((g) => g.id == selectedGoal!.id);
                        if (idx >= 0) {
                          _goals[idx] = _goals[idx].copyWith(
                            currentAmount: _goals[idx].currentAmount + amount,
                          );
                        }
                      });
                      await _saveGoals();
                    }

                    // 2. Synchronize with global vault
                    final double currentVault = ref
                        .read(budgetBuddyControllerProvider)
                        .totalSavings;
                    ref
                        .read(budgetBuddyControllerProvider.notifier)
                        .setTotalSavings(currentVault + amount);

                    if (dialogContext.mounted) {
                      Navigator.of(dialogContext).pop();
                    }
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                              'Successfully deposited ${formatPeso(amount)}!'),
                          backgroundColor: _SavingsTokens.savingsGreen,
                          behavior: SnackBarBehavior.floating,
                        ),
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

  /// Withdraw / Cover Deficit Modal Bottom Sheet
  void _showWithdrawOrCoverDeficitSheet(
    BuildContext context, {
    required BudgetBuddyState state,
    required _SavingsTokens tokens,
  }) {
    final bool hasDeficit = state.savingsDebt > 0;
    final TextEditingController withdrawCtrl = TextEditingController();

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

                Row(
                  children: <Widget>[
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: tokens.tint(_SavingsTokens.deficitRed, 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.outbond_rounded,
                        size: 20,
                        color: _SavingsTokens.deficitRed,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            hasDeficit ? 'Cover Running Deficit' : 'Withdraw Savings',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: tokens.textPrimary,
                            ),
                          ),
                          Text(
                            hasDeficit
                                ? 'Use savings vault to eliminate past debt'
                                : 'Take funds from your accumulated savings',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12,
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

                if (hasDeficit) ...<Widget>[
                  // Deficit Payoff Card
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: tokens.subCardBg,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                          color: _SavingsTokens.deficitRed.withValues(alpha: 0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        _buildDetailRow(
                          label: 'Current Deficit',
                          value: formatPeso(state.savingsDebt),
                          valueColor: _SavingsTokens.deficitRed,
                          tokens: tokens,
                        ),
                        const Divider(height: 16),
                        _buildDetailRow(
                          label: 'Vault Balance',
                          value: formatPeso(state.totalSavings),
                          valueColor: _SavingsTokens.savingsGreen,
                          tokens: tokens,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Cover Deficit Button (Solid Dark Red)
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () {
                        Navigator.of(sheetContext).pop();
                        final double currentDebt = state.savingsDebt;
                        final double currentSavings = state.totalSavings;

                        if (currentSavings <= 0) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                  'Your savings vault is empty! Deposit first to cover debt.'),
                              backgroundColor: _SavingsTokens.deficitRed,
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                          return;
                        }

                        if (currentSavings >= currentDebt) {
                          ref
                              .read(budgetBuddyControllerProvider.notifier)
                              .setTotalSavings(currentSavings - currentDebt);
                          ref
                              .read(budgetBuddyControllerProvider.notifier)
                              .setSavingsDebt(0.0);
                        } else {
                          ref
                              .read(budgetBuddyControllerProvider.notifier)
                              .setSavingsDebt(currentDebt - currentSavings);
                          ref
                              .read(budgetBuddyControllerProvider.notifier)
                              .setTotalSavings(0.0);
                        }

                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Deficit successfully settled!'),
                            backgroundColor: _SavingsTokens.savingsGreen,
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      },
                      icon: const Icon(Icons.check_circle_rounded,
                          size: 16, color: Colors.white),
                      label: Text(
                        'Pay Off Deficit from Savings',
                        style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
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
                ] else ...<Widget>[
                  // Standard Withdrawal
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
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
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
                  const SizedBox(height: 14),

                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () {
                        final double? amount =
                            double.tryParse(withdrawCtrl.text.trim());
                        if (amount == null || amount <= 0) return;

                        final double currentVault = state.totalSavings;
                        if (amount > currentVault) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                  'Withdrawal amount exceeds total savings!'),
                              backgroundColor: _SavingsTokens.deficitRed,
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                          return;
                        }

                        ref
                            .read(budgetBuddyControllerProvider.notifier)
                            .setTotalSavings(currentVault - amount);
                        Navigator.of(sheetContext).pop();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                                'Withdrew ${formatPeso(amount)} from vault.'),
                            backgroundColor: _SavingsTokens.deficitRed,
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      },
                      style: FilledButton.styleFrom(
                        backgroundColor: _SavingsTokens.deficitRed,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        'Confirm Withdrawal',
                        style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
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
  }

  /// Add / Edit Goal Bottom Sheet Modal
  void _showAddOrEditGoalSheet(
    BuildContext context, {
    SavingsGoal? existingGoal,
    required _SavingsTokens tokens,
  }) {
    final TextEditingController titleCtrl =
        TextEditingController(text: existingGoal?.title ?? '');
    final TextEditingController amountCtrl = TextEditingController(
        text: existingGoal != null
            ? existingGoal.targetAmount.toStringAsFixed(0)
            : '');
    final TextEditingController currentCtrl = TextEditingController(
        text: existingGoal != null
            ? existingGoal.currentAmount.toStringAsFixed(0)
            : '0');
    final TextEditingController noteCtrl =
        TextEditingController(text: existingGoal?.note ?? '');
    DateTime? targetDate = existingGoal?.targetDate;
    String iconKey = existingGoal?.iconKey ?? 'emergency';

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
            return SafeArea(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  20,
                  12,
                  20,
                  MediaQuery.of(sheetContext).viewInsets.bottom + 20,
                ),
                child: SingleChildScrollView(
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
                      const SizedBox(height: 16),
                      Text(
                        existingGoal != null ? 'Edit Savings Goal' : 'New Savings Goal',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: tokens.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Title Field
                      TextField(
                        controller: titleCtrl,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: tokens.textPrimary,
                        ),
                        decoration: InputDecoration(
                          labelText: 'Goal Title (e.g. Emergency Fund)',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: tokens.cardBorder),
                          ),
                          isDense: true,
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Target Amount Field
                      TextField(
                        controller: amountCtrl,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: _SavingsTokens.targetGold,
                        ),
                        decoration: InputDecoration(
                          labelText: 'Target Amount',
                          prefixText: '₱ ',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: tokens.cardBorder),
                          ),
                          isDense: true,
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Current Saved Field
                      TextField(
                        controller: currentCtrl,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: _SavingsTokens.savingsGreen,
                        ),
                        decoration: InputDecoration(
                          labelText: 'Current Amount Already Saved',
                          prefixText: '₱ ',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: tokens.cardBorder),
                          ),
                          isDense: true,
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Category Icon Picker
                      Text(
                        'Category Icon',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: tokens.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 8,
                        children: <MapEntry<String, IconData>>[
                          const MapEntry('emergency', Icons.shield_rounded),
                          const MapEntry('phone', Icons.phone_iphone_rounded),
                          const MapEntry('vacation', Icons.flight_takeoff_rounded),
                          const MapEntry('home', Icons.home_rounded),
                          const MapEntry('school', Icons.school_rounded),
                          const MapEntry('car', Icons.directions_car_rounded),
                        ].map((entry) {
                          final bool isSel = iconKey == entry.key;
                          return InkWell(
                            onTap: () =>
                                setModalState(() => iconKey = entry.key),
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: isSel
                                    ? _SavingsTokens.savingsGreen
                                    : tokens.subCardBg,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: isSel
                                      ? _SavingsTokens.savingsGreen
                                      : tokens.cardBorder,
                                ),
                              ),
                              child: Icon(
                                entry.value,
                                size: 18,
                                color: isSel ? Colors.white : tokens.textSecondary,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 12),

                      // Target Date Trigger
                      InkWell(
                        onTap: () async {
                          final DateTime? picked = await showDatePicker(
                            context: sheetContext,
                            initialDate: targetDate ??
                                DateTime.now().add(const Duration(days: 90)),
                            firstDate: DateTime.now(),
                            lastDate:
                                DateTime.now().add(const Duration(days: 1825)),
                          );
                          if (picked != null) {
                            setModalState(() => targetDate = picked);
                          }
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            color: tokens.subCardBg,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: tokens.cardBorder),
                          ),
                          child: Row(
                            children: <Widget>[
                              const Icon(Icons.calendar_today_rounded,
                                  size: 16, color: _SavingsTokens.savingsGreen),
                              const SizedBox(width: 10),
                              Text(
                                targetDate != null
                                    ? 'Target: ${DateFormat('MMMM d, yyyy').format(targetDate!)}'
                                    : 'Pick Target Date (Optional)',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: tokens.textPrimary,
                                ),
                              ),
                            ],
                          ),
                        ),
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
                          labelText: 'Notes / Target Motivation',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: tokens.cardBorder),
                          ),
                          isDense: true,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Save Goal Button (Solid Dark Green #0F766E or Solid Gold #D97706 for Edit)
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: () async {
                            final String title = titleCtrl.text.trim();
                            final double? targetAmt =
                                double.tryParse(amountCtrl.text.trim());
                            final double currentAmt =
                                double.tryParse(currentCtrl.text.trim()) ?? 0.0;
                            if (title.isEmpty ||
                                targetAmt == null ||
                                targetAmt <= 0) {
                              return;
                            }

                            if (existingGoal != null) {
                              setState(() {
                                final int idx = _goals.indexWhere(
                                    (g) => g.id == existingGoal.id);
                                if (idx >= 0) {
                                  _goals[idx] = existingGoal.copyWith(
                                    title: title,
                                    targetAmount: targetAmt,
                                    currentAmount: currentAmt,
                                    targetDate: targetDate,
                                    iconKey: iconKey,
                                    note: noteCtrl.text.trim(),
                                  );
                                }
                              });
                            } else {
                              setState(() {
                                _goals.add(
                                  SavingsGoal(
                                    id: DateTime.now().millisecondsSinceEpoch.toString(),
                                    title: title,
                                    targetAmount: targetAmt,
                                    currentAmount: currentAmt,
                                    targetDate: targetDate,
                                    iconKey: iconKey,
                                    note: noteCtrl.text.trim(),
                                  ),
                                );
                              });
                            }

                            await _saveGoals();
                            if (sheetContext.mounted) {
                              Navigator.of(sheetContext).pop();
                            }
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(existingGoal != null
                                      ? 'Goal updated!'
                                      : 'Goal created!'),
                                  backgroundColor: existingGoal != null
                                      ? _SavingsTokens.targetGold
                                      : _SavingsTokens.savingsGreen,
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            }
                          },
                          style: FilledButton.styleFrom(
                            backgroundColor: existingGoal != null
                                ? _SavingsTokens.targetGold
                                : _SavingsTokens.savingsGreen,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 13),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            existingGoal != null ? 'Save Changes' : 'Create Goal',
                            style: GoogleFonts.plusJakartaSans(
                              fontWeight: FontWeight.w800,
                              fontSize: 13,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<bool> _confirmDeleteGoalDialog(
    BuildContext context,
    SavingsGoal goal,
    _SavingsTokens tokens,
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
                  color: tokens.tint(_SavingsTokens.deficitRed, 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.delete_outline_rounded,
                  color: _SavingsTokens.deficitRed,
                  size: 18,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Delete Goal?',
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                  color: tokens.textPrimary,
                ),
              ),
            ],
          ),
          content: Text(
            'Are you sure you want to remove "${goal.title}"? Your accumulated vault savings will remain untouched.',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13,
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
                backgroundColor: _SavingsTokens.savingsGreen,
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
                backgroundColor: _SavingsTokens.deficitRed,
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

  /// Segmented Daily / Monthly toggle
  Widget _buildSectionToggle(BuildContext context, _SavingsTokens tokens) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: tokens.subCardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: tokens.cardBorder, width: 1.0),
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
                      size: 13,
                      color: _activeSection == SavingsSection.daily
                          ? Colors.white
                          : tokens.textSecondary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Daily Records',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
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
                      size: 13,
                      color: _activeSection == SavingsSection.monthly
                          ? Colors.white
                          : tokens.textSecondary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Monthly Records',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
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
        ],
      ),
    );
  }

  /// History Bento Card containing the list of daily or monthly savings records
  Widget _buildHistoryCard(
    BuildContext context, {
    required List<DailyRecord> records,
    required List<DateTime> availableMonths,
    required DateTime currentClock,
    required _SavingsTokens tokens,
  }) {
    return BentoCard(
      padding: const EdgeInsets.all(14),
      borderRadius: 20,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (records.isEmpty)
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
                    onTap: () => _showSavingsDaySheet(context, record, tokens),
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

  Widget _buildSavingsDateTile(
    BuildContext context, {
    required DailyRecord record,
    required VoidCallback onTap,
    required _SavingsTokens tokens,
    DateTime? currentClock,
  }) {
    final bool isZeroActivity = record.isZeroActivity;
    final bool isOverspent = record.savings < 0;

    final Color accent = isZeroActivity
        ? _SavingsTokens.targetGold
        : (isOverspent ? _SavingsTokens.deficitRed : _SavingsTokens.savingsGreen);

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
                        DateFormat('EEEE, MMM d, yyyy').format(record.date),
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
                                  : (isOverspent ? 'Overspent' : 'Saved'),
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
                              : 'Spent ${formatPeso(record.totalSpent)} • Left ${formatPeso(record.remainingBalance)}',
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
                              sheetContext, record, tokens),
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
}

String _formatDayLabel(DateTime dateTime, [DateTime? currentClock]) {
  final DateTime now = currentClock ?? DateTime.now();
  if (DateUtils.isSameDay(dateTime, now)) {
    return 'Today, ${DateFormat('MMMM d, yyyy').format(dateTime)}';
  }
  return DateFormat('EEEE, MMM d, yyyy').format(dateTime);
}
