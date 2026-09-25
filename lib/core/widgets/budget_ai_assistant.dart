import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/budget_models.dart';
import '../state/app_controller.dart';

/// Opens the Buds AI Assistant modal sheet.
/// If opened for the first time, displays the initial intro popup first.
Future<void> showBudsChat(BuildContext context) async {
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  final bool hasSeenIntro = prefs.getBool('buds_ai_intro_seen') ?? false;

  if (!hasSeenIntro && context.mounted) {
    await prefs.setBool('buds_ai_intro_seen', true);
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) => const _BudsIntroDialog(),
    );
  }

  if (context.mounted) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _BudsChatSheet(),
    );
  }
}

/// Floating draggable avatar button for Buds AI.
class BudgetAiAssistant extends ConsumerStatefulWidget {
  const BudgetAiAssistant({super.key});

  @override
  ConsumerState<BudgetAiAssistant> createState() => _BudgetAiAssistantState();
}

class _BudgetAiAssistantState extends ConsumerState<BudgetAiAssistant> {
  double _right = 20;
  double _bottom = 90;
  bool _showGreetingBubble = true;
  Timer? _bubbleTimer;

  @override
  void initState() {
    super.initState();
    _bubbleTimer = Timer(const Duration(seconds: 5), () {
      if (mounted) {
        setState(() {
          _showGreetingBubble = false;
        });
      }
    });
  }

  @override
  void dispose() {
    _bubbleTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        const double bubbleSize = 58;
        final double maxRight = (constraints.maxWidth - bubbleSize - 12)
            .clamp(12.0, double.infinity)
            .toDouble();
        final double maxBottom = (constraints.maxHeight - bubbleSize - 12)
            .clamp(12.0, double.infinity)
            .toDouble();
        final double right = _right.clamp(12.0, maxRight).toDouble();
        final double bottom = _bottom.clamp(12.0, maxBottom).toDouble();

        return Stack(
          fit: StackFit.expand,
          children: <Widget>[
            Positioned(
              right: right,
              bottom: bottom,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  // 5-second auto-closing floating popup text
                  AnimatedOpacity(
                    opacity: _showGreetingBubble ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 300),
                    child: _showGreetingBubble
                        ? GestureDetector(
                            onTap: () {
                              _bubbleTimer?.cancel();
                              setState(() => _showGreetingBubble = false);
                              showBudsChat(context);
                            },
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 10),
                              constraints: const BoxConstraints(maxWidth: 280),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 11,
                              ),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? const Color(0xFF0D9488)
                                    : const Color(0xFF0F766E),
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(
                                  color: const Color(0xFFF59E0B),
                                  width: 2.2,
                                ),
                                boxShadow: <BoxShadow>[
                                  BoxShadow(
                                    color: Colors.black
                                        .withValues(alpha: isDark ? 0.45 : 0.28),
                                    blurRadius: 16,
                                    offset: const Offset(0, 5),
                                  ),
                                  BoxShadow(
                                    color: (isDark
                                            ? const Color(0xFF0D9488)
                                            : const Color(0xFF0F766E))
                                        .withValues(alpha: 0.40),
                                    blurRadius: 10,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: <Widget>[
                                  Container(
                                    width: 30,
                                    height: 30,
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(alpha: 0.20),
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: const Color(0xFFFDE68A),
                                        width: 1.2,
                                      ),
                                    ),
                                    child: const Icon(
                                      Icons.smart_toy_rounded,
                                      size: 17,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Flexible(
                                    child: Text.rich(
                                      TextSpan(
                                        children: <InlineSpan>[
                                          TextSpan(
                                            text: "Hi, I'm ",
                                            style: GoogleFonts.plusJakartaSans(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w700,
                                              color: Colors.white,
                                              height: 1.35,
                                            ),
                                          ),
                                          TextSpan(
                                            text: 'Buds',
                                            style: GoogleFonts.plusJakartaSans(
                                              fontSize: 13.5,
                                              fontWeight: FontWeight.w900,
                                              color: const Color(0xFFFDE68A),
                                              height: 1.35,
                                            ),
                                          ),
                                          TextSpan(
                                            text: ', your AI budget assistant! 🤖💚',
                                            style: GoogleFonts.plusJakartaSans(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w700,
                                              color: Colors.white,
                                              height: 1.35,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  GestureDetector(
                                    onTap: () {
                                      _bubbleTimer?.cancel();
                                      setState(() => _showGreetingBubble = false);
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: BoxDecoration(
                                        color: Colors.white
                                            .withValues(alpha: 0.25),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.close_rounded,
                                        size: 14,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : const SizedBox.shrink(),
                  ),

                  // Floating Avatar Button
                  GestureDetector(
                    onPanUpdate: (DragUpdateDetails details) {
                      setState(() {
                        _right =
                            (_right - details.delta.dx).clamp(12.0, maxRight);
                        _bottom =
                            (_bottom - details.delta.dy).clamp(12.0, maxBottom);
                      });
                    },
                    onTap: () {
                      _bubbleTimer?.cancel();
                      setState(() => _showGreetingBubble = false);
                      showBudsChat(context);
                    },
                    child: Tooltip(
                      message: 'Ask Buds AI',
                      child: Container(
                        width: bubbleSize,
                        height: bubbleSize,
                        decoration: BoxDecoration(
                          color: const Color(0xFF0F766E),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: const Color(0xFFD97706),
                            width: 2.2,
                          ),
                          boxShadow: <BoxShadow>[
                            BoxShadow(
                              color: const Color(0xFF0F766E)
                                  .withValues(alpha: 0.40),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Stack(
                          alignment: Alignment.center,
                          children: <Widget>[
                            const Icon(
                              Icons.smart_toy_rounded,
                              color: Colors.white,
                              size: 28,
                            ),
                            Positioned(
                              right: 4,
                              top: 4,
                              child: Container(
                                width: 10,
                                height: 10,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFD97706),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                      color: Colors.white, width: 1.5),
                                ),
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
          ],
        );
      },
    );
  }
}

/// First open friendly greeting popup dialog.
class _BudsIntroDialog extends StatelessWidget {
  const _BudsIntroDialog();

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color cardBg = isDark ? const Color(0xFF111827) : const Color(0xFFFFFFFF);
    final Color borderColor = isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0);

    return Dialog(
      backgroundColor: cardBg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: const Color(0xFF0F766E), width: 1.8),
      ),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            // Avatar badge
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: const Color(0xFF0F766E),
                shape: BoxShape.circle,
                border: Border.all(
                  color: const Color(0xFFD97706),
                  width: 3,
                ),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: const Color(0xFF0F766E).withValues(alpha: 0.35),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Icon(
                Icons.smart_toy_rounded,
                color: Colors.white,
                size: 38,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              "Hi, I'm Buds, your AI budget assistant! 🤖💚",
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              "I work 100% offline directly on your device. Tap any preset question chip to instantly inspect your savings, debt, daily limits, and spending trends.",
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                height: 1.45,
                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
              ),
            ),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF0F766E).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: const Color(0xFF0F766E).withValues(alpha: 0.25),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  const Icon(
                    Icons.offline_bolt_rounded,
                    color: Color(0xFF0F766E),
                    size: 16,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '100% Offline & Private',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF0F766E),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF0F766E),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  elevation: 0,
                ),
                onPressed: () => Navigator.of(context).pop(),
                child: Text(
                  'Start Chatting',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Main Buds AI Chat Bottom Sheet with preset question chips and calculation engine.
class _BudsChatSheet extends ConsumerStatefulWidget {
  const _BudsChatSheet();

  @override
  ConsumerState<_BudsChatSheet> createState() => _BudsChatSheetState();
}

class _BudsChatSheetState extends ConsumerState<_BudsChatSheet> {
  final ScrollController _scrollController = ScrollController();
  final List<_BudsMessage> _messages = <_BudsMessage>[
    const _BudsMessage(
      text: "Hi, I'm Buds, your AI budget assistant! 🤖💚\nTap any preset question below to query your offline financial records.",
      fromUser: false,
    ),
  ];

  static const List<Map<String, dynamic>> _presetQuestions = <Map<String, dynamic>>[
    <String, dynamic>{
      'label': 'Total Savings',
      'query': 'How much are my total savings?',
      'icon': Icons.savings_rounded,
    },
    <String, dynamic>{
      'label': 'Debt Owed',
      'query': 'How much debt do I owe?',
      'icon': Icons.credit_card_off_rounded,
    },
    <String, dynamic>{
      'label': 'Highest Expense Today',
      'query': 'What was my highest expense today?',
      'icon': Icons.today_rounded,
    },
    <String, dynamic>{
      'label': 'Highest Expense Overall',
      'query': 'What was my highest expense overall?',
      'icon': Icons.trending_up_rounded,
    },
    <String, dynamic>{
      'label': 'Max Daily Budget',
      'query': 'What was my highest daily budget limit?',
      'icon': Icons.arrow_upward_rounded,
    },
    <String, dynamic>{
      'label': 'Min Daily Budget',
      'query': 'What was my lowest daily budget limit?',
      'icon': Icons.arrow_downward_rounded,
    },
    <String, dynamic>{
      'label': 'Safe Budget Today',
      'query': 'How much safe budget do I have remaining for today?',
      'icon': Icons.shield_rounded,
    },
    <String, dynamic>{
      'label': 'Spent This Month',
      'query': 'How much have I spent in total this month?',
      'icon': Icons.calendar_month_rounded,
    },
    <String, dynamic>{
      'label': 'Top Spending Category',
      'query': 'Which category am I spending the most money on?',
      'icon': Icons.pie_chart_rounded,
    },
    <String, dynamic>{
      'label': 'Together Budget Left',
      'query': 'How much is remaining in our Together Budget today?',
      'icon': Icons.people_alt_rounded,
    },
  ];

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _handlePresetQuery(String question) {
    final BudgetBuddyState state = ref.read(budgetBuddyControllerProvider);
    final String answer = _calculateAnswer(question, state);

    setState(() {
      _messages.add(_BudsMessage(text: question, fromUser: true));
      _messages.add(_BudsMessage(text: answer, fromUser: false));
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  String _calculateAnswer(String question, BudgetBuddyState state) {
    switch (question) {
      // 1. Total Savings
      case 'How much are my total savings?':
        final double savings = state.totalSavings;
        return 'Your total savings currently stand at ${_formatPeso(savings)}. Keep up the great work!';

      // 2. Debt Owed
      case 'How much debt do I owe?':
        final double debt = state.savingsDebt;
        if (debt <= 0) {
          return 'You currently have no recorded debt! Great job! 🎉';
        }
        return 'Your total recorded debt/deficit is ${_formatPeso(debt)}.';

      // 3. Highest Expense Today
      case 'What was my highest expense today?':
        final DateTime now = DateTime.now();
        final List<ExpenseEntry> todayExpenses = state.expenses
            .where((ExpenseEntry e) =>
                e.dateTime.year == now.year &&
                e.dateTime.month == now.month &&
                e.dateTime.day == now.day)
            .toList();
        if (todayExpenses.isEmpty) {
          return "You haven't logged any expenses yet today.";
        }
        todayExpenses.sort((ExpenseEntry a, ExpenseEntry b) =>
            b.amount.compareTo(a.amount));
        final ExpenseEntry top = todayExpenses.first;
        final String name = top.title.trim().isNotEmpty
            ? top.title.trim()
            : (top.spendCategory.trim().isNotEmpty
                ? top.spendCategory.trim()
                : 'Expense');
        return 'Your highest expense today was ${_formatPeso(top.amount)} for $name.';

      // 4. Highest Expense Overall
      case 'What was my highest expense overall?':
        if (state.expenses.isEmpty) {
          return 'You have no recorded expenses in the app yet.';
        }
        final List<ExpenseEntry> allExpenses =
            List<ExpenseEntry>.from(state.expenses)
              ..sort((ExpenseEntry a, ExpenseEntry b) =>
                  b.amount.compareTo(a.amount));
        final ExpenseEntry top = allExpenses.first;
        final String name = top.title.trim().isNotEmpty
            ? top.title.trim()
            : (top.spendCategory.trim().isNotEmpty
                ? top.spendCategory.trim()
                : 'Expense');
        final String dateStr =
            DateFormat('MMM d, yyyy').format(top.dateTime);
        return 'Your highest expense overall was ${_formatPeso(top.amount)} for $name on $dateStr.';

      // 5. Max Daily Budget
      case 'What was my highest daily budget limit?':
        final List<BudgetEntry> budgets = state.budgetEntries.toList();
        if (budgets.isNotEmpty) {
          budgets.sort((BudgetEntry a, BudgetEntry b) =>
              b.amount.compareTo(a.amount));
          final BudgetEntry top = budgets.first;
          final String dateStr = DateFormat('MMM d, yyyy').format(top.date);
          return 'Your highest set daily budget was ${_formatPeso(top.amount)} on $dateStr.';
        } else if (state.settings.dailyLimit != null &&
            state.settings.dailyLimit! > 0) {
          return 'Your standard configured daily budget target is ${_formatPeso(state.settings.dailyLimit!)}.';
        }
        return 'You do not have any set daily budget records yet.';

      // 6. Min Daily Budget
      case 'What was my lowest daily budget limit?':
        final List<BudgetEntry> positiveBudgets =
            state.budgetEntries.where((BudgetEntry b) => b.amount > 0).toList();
        if (positiveBudgets.isNotEmpty) {
          positiveBudgets.sort((BudgetEntry a, BudgetEntry b) =>
              a.amount.compareTo(b.amount));
          final BudgetEntry lowest = positiveBudgets.first;
          final String dateStr =
              DateFormat('MMM d, yyyy').format(lowest.date);
          return 'Your lowest set daily budget was ${_formatPeso(lowest.amount)} on $dateStr.';
        } else if (state.settings.dailyLimit != null &&
            state.settings.dailyLimit! > 0) {
          return 'Your standard configured daily budget target is ${_formatPeso(state.settings.dailyLimit!)}.';
        }
        return 'You do not have any set daily budget records yet.';

      // 7. Safe Budget Remaining Today
      case 'How much safe budget do I have remaining for today?':
        final DateTime now = DateTime.now();
        final BudgetEntry? todayBudgetEntry = state.budgetEntries
            .cast<BudgetEntry?>()
            .firstWhere(
              (BudgetEntry? b) =>
                  b != null &&
                  b.date.year == now.year &&
                  b.date.month == now.month &&
                  b.date.day == now.day,
              orElse: () => null,
            );
        final double todayBudget =
            todayBudgetEntry?.amount ?? (state.settings.dailyLimit ?? 0.0);
        final double todaySpent = state.expenses
            .where((ExpenseEntry e) =>
                e.source != 'togetherSpend' &&
                e.dateTime.year == now.year &&
                e.dateTime.month == now.month &&
                e.dateTime.day == now.day)
            .fold(0.0, (double sum, ExpenseEntry e) => sum + e.amount);
        final double remaining = todayBudget - todaySpent;
        if (remaining >= 0) {
          return 'You have ${_formatPeso(remaining)} remaining that you can safely spend today.';
        } else {
          return 'You have exceeded today\'s budget by ${_formatPeso(remaining.abs())}. Try pausing non-essential purchases today.';
        }

      // 8. Spent This Month
      case 'How much have I spent in total this month?':
        final DateTime now = DateTime.now();
        final double monthSpent = state.expenses
            .where((ExpenseEntry e) =>
                e.dateTime.year == now.year && e.dateTime.month == now.month)
            .fold(0.0, (double sum, ExpenseEntry e) => sum + e.amount);
        return 'Your total expenses for this month amount to ${_formatPeso(monthSpent)}.';

      // 9. Top Category
      case 'Which category am I spending the most money on?':
        if (state.expenses.isEmpty) {
          return 'You have no expenses recorded yet.';
        }
        final Map<String, double> totals = <String, double>{};
        for (final ExpenseEntry e in state.expenses) {
          final String cat = e.spendCategory.trim().isNotEmpty
              ? e.spendCategory.trim()
              : e.category.label;
          totals[cat] = (totals[cat] ?? 0.0) + e.amount;
        }
        final List<MapEntry<String, double>> sorted = totals.entries.toList()
          ..sort((MapEntry<String, double> a, MapEntry<String, double> b) =>
              b.value.compareTo(a.value));
        final MapEntry<String, double> topCat = sorted.first;
        return 'The category with your highest spending is ${topCat.key} (${_formatPeso(topCat.value)}).';

      // 10. Together Budget Left Today
      case 'How much is remaining in our Together Budget today?':
        final DateTime now = DateTime.now();
        final double togetherPool = state.togetherBudget;
        final double togetherSpentToday = state.expenses
            .where((ExpenseEntry e) =>
                e.source == 'togetherSpend' &&
                e.dateTime.year == now.year &&
                e.dateTime.month == now.month &&
                e.dateTime.day == now.day)
            .fold(0.0, (double sum, ExpenseEntry e) => sum + e.amount);
        final double remainingTogether =
            (togetherPool - togetherSpentToday).clamp(0.0, double.infinity);
        return 'Your remaining Together Budget for today is ${_formatPeso(remainingTogether)}.';

      default:
        return 'I can query your savings, debt, highest expenses, daily limits, and monthly totals. Tap any preset above!';
    }
  }

  String _formatPeso(double amount) {
    final NumberFormat formatter = NumberFormat('#,##0.00', 'en_PH');
    return '₱${formatter.format(amount)}';
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color cardBg =
        isDark ? const Color(0xFF111827) : const Color(0xFFFFFFFF);
    final Color borderColor =
        isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0);
    final Color scaffoldBg =
        isDark ? const Color(0xFF0B1120) : const Color(0xFFF8FAFC);

    final double screenHeight = MediaQuery.of(context).size.height;

    return Container(
      height: screenHeight * 0.85,
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
        border: Border.all(color: borderColor, width: 1.2),
      ),
      child: Column(
        children: <Widget>[
          // Header Drag Handle
          const SizedBox(height: 10),
          Center(
            child: Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: borderColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Header Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Row(
              children: <Widget>[
                // Avatar badge
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F766E),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFFD97706),
                      width: 2,
                    ),
                  ),
                  child: const Icon(
                    Icons.smart_toy_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          Text(
                            'Buds AI',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0F766E)
                                  .withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: <Widget>[
                                Container(
                                  width: 6,
                                  height: 6,
                                  decoration: const BoxDecoration(
                                    color: Color(0xFF0F766E),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '100% OFFLINE',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w800,
                                    color: const Color(0xFF0F766E),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      Text(
                        'Local Financial Intelligence',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11.5,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded),
                  tooltip: 'Close',
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Divider(height: 1, color: borderColor),

          // Preset Questions Section
          Container(
            color: scaffoldBg,
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  child: Text(
                    'TAP TO QUERY LOCAL DATABASE:',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.6,
                      color: const Color(0xFFD97706),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 38,
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    scrollDirection: Axis.horizontal,
                    itemCount: _presetQuestions.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (BuildContext context, int index) {
                      final Map<String, dynamic> item = _presetQuestions[index];
                      return ActionChip(
                        avatar: Icon(
                          item['icon'] as IconData,
                          size: 15,
                          color: const Color(0xFF0F766E),
                        ),
                        label: Text(
                          item['label'] as String,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(
                            color: const Color(0xFF0F766E)
                                .withValues(alpha: 0.35),
                          ),
                        ),
                        backgroundColor: cardBg,
                        onPressed: () =>
                            _handlePresetQuery(item['query'] as String),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: borderColor),

          // Message Stream
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (BuildContext context, int index) {
                final _BudsMessage message = _messages[index];
                final bool isUser = message.fromUser;

                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    mainAxisAlignment: isUser
                        ? MainAxisAlignment.end
                        : MainAxisAlignment.start,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      if (!isUser) ...<Widget>[
                        Container(
                          width: 28,
                          height: 28,
                          margin: const EdgeInsets.only(top: 2, right: 8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0F766E),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: const Color(0xFFD97706),
                              width: 1.5,
                            ),
                          ),
                          child: const Icon(
                            Icons.smart_toy_rounded,
                            color: Colors.white,
                            size: 15,
                          ),
                        ),
                      ],
                      Flexible(
                        child: Container(
                          constraints: const BoxConstraints(maxWidth: 300),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: isUser
                                ? const Color(0xFF0F766E)
                                : (isDark
                                    ? const Color(0xFF1E293B)
                                    : const Color(0xFFF0FDFA)),
                            borderRadius: BorderRadius.only(
                              topLeft: const Radius.circular(16),
                              topRight: const Radius.circular(16),
                              bottomLeft: Radius.circular(isUser ? 16 : 4),
                              bottomRight: Radius.circular(isUser ? 4 : 16),
                            ),
                            border: Border.all(
                              color: isUser
                                  ? const Color(0xFF0F766E)
                                  : (isDark
                                      ? const Color(0xFF334155)
                                      : const Color(0xFF0F766E)
                                          .withValues(alpha: 0.30)),
                              width: 1.2,
                            ),
                          ),
                          child: Text(
                            message.text,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 13.5,
                              height: 1.42,
                              fontWeight: isUser
                                  ? FontWeight.w700
                                  : FontWeight.w600,
                              color: isUser
                                  ? Colors.white
                                  : (isDark
                                      ? Colors.white
                                      : const Color(0xFF0F172A)),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),

          // Disabled Free-Text Input Row
          Container(
            padding: EdgeInsets.fromLTRB(
              16,
              10,
              16,
              MediaQuery.of(context).viewInsets.bottom + 16,
            ),
            decoration: BoxDecoration(
              color: cardBg,
              border: Border(top: BorderSide(color: borderColor, width: 1)),
            ),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: TextField(
                    enabled: false,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12.5,
                      color: isDark ? Colors.white38 : Colors.black38,
                    ),
                    decoration: InputDecoration(
                      hintText:
                          'Type message disabled — Under Development 🛠️',
                      hintStyle: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white38 : Colors.black45,
                      ),
                      prefixIcon: Icon(
                        Icons.lock_outline_rounded,
                        size: 18,
                        color: isDark ? Colors.white38 : Colors.black45,
                      ),
                      filled: true,
                      fillColor: isDark
                          ? const Color(0xFF1E293B)
                          : const Color(0xFFF1F5F9),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 11,
                      ),
                      disabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(
                          color: isDark
                              ? const Color(0xFF334155)
                              : const Color(0xFFCBD5E1),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F766E).withValues(alpha: 0.20),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.send_rounded,
                    size: 20,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BudsMessage {
  const _BudsMessage({required this.text, required this.fromUser});

  final String text;
  final bool fromUser;
}
