import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/budget_models.dart' as models;
import '../state/app_controller.dart';

void showBudsChat(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => const _BudsChatSheet(),
  );
}

class BudgetAiAssistant extends ConsumerStatefulWidget {
  const BudgetAiAssistant({super.key});

  @override
  ConsumerState<BudgetAiAssistant> createState() => _BudgetAiAssistantState();
}

class _BudgetAiAssistantState extends ConsumerState<BudgetAiAssistant> {
  double _right = 18;
  double _bottom = 18;

  void _showChat() {
    showBudsChat(context);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        const double bubbleSize = 62;
        final double maxRight = (constraints.maxWidth - bubbleSize - 8)
            .clamp(8.0, double.infinity)
            .toDouble();
        final double maxBottom = (constraints.maxHeight - bubbleSize - 8)
            .clamp(8.0, double.infinity)
            .toDouble();
        final double right = _right.clamp(8.0, maxRight).toDouble();
        final double bottom = _bottom.clamp(8.0, maxBottom).toDouble();

        return Stack(
          fit: StackFit.expand,
          children: <Widget>[
            Positioned(
              right: right,
              bottom: bottom,
              child: GestureDetector(
                onPanUpdate: (DragUpdateDetails details) {
                  setState(() {
                    _right = (_right - details.delta.dx).clamp(8.0, maxRight);
                    _bottom =
                        (_bottom - details.delta.dy).clamp(8.0, maxBottom);
                  });
                },
                onTap: _showChat,
                child: Tooltip(
                  message: 'Ask Buds',
                  child: Material(
                    color: Theme.of(context).colorScheme.primary,
                    elevation: 6,
                    shadowColor: Theme.of(context)
                        .colorScheme
                        .primary
                        .withValues(alpha: 0.35),
                    shape: const CircleBorder(),
                    child: Ink(
                      width: bubbleSize,
                      height: bubbleSize,
                      decoration: const ShapeDecoration(
                        shape: CircleBorder(),
                      ),
                      child: Icon(
                        Icons.auto_awesome_rounded,
                        color: Theme.of(context).colorScheme.onPrimary,
                        size: 29,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _BudsChatSheet extends ConsumerStatefulWidget {
  const _BudsChatSheet();

  @override
  ConsumerState<_BudsChatSheet> createState() => _BudsChatSheetState();
}

class _BudsChatSheetState extends ConsumerState<_BudsChatSheet> {
  final TextEditingController _controller = TextEditingController();
  final List<_BudsMessage> _messages = <_BudsMessage>[
    const _BudsMessage(
      text: "Hi, I'm Buds. What would you like to check today?",
      fromUser: false,
    ),
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _sendMessage([String? preset]) {
    final String text = (preset ?? _controller.text).trim();
    if (text.isEmpty) {
      return;
    }

    final models.BudgetSummary summary = ref.read(budgetSummaryProvider);
    setState(() {
      _messages.add(_BudsMessage(text: text, fromUser: true));
      _messages.add(
        _BudsMessage(text: _replyFor(text, summary), fromUser: false),
      );
      _controller.clear();
    });
  }

  String _replyFor(String prompt, models.BudgetSummary summary) {
    final String query = prompt.toLowerCase();
    final double remaining = summary.remainingBalance;

    if (query.contains('spent') || query.contains('expense')) {
      return 'You have spent ${_peso(summary.totalSpent)} in your current budget period.';
    }
    if (query.contains('left') || query.contains('remain')) {
      return remaining >= 0
          ? 'You have ${_peso(remaining)} left to work with. Keep a little buffer for surprises.'
          : 'You are ${_peso(remaining.abs())} over budget. A small pause on non-essentials can help you recover.';
    }
    if (query.contains('save') || query.contains('saving')) {
      return summary.savings > 0
          ? 'Nice work. Your current savings progress is ${_peso(summary.savings)}.'
          : 'Try setting aside a small amount before your next purchase.';
    }
    if (query.contains('budget')) {
      return 'Your current budget is ${_peso(summary.totalBudget)} with ${_peso(summary.totalSpent)} spent.';
    }
    return remaining >= 0
        ? 'You are on track. Your biggest expense category is ${summary.biggestExpenseCategory}.'
        : 'You are over budget right now. Want to review your expenses by category?';
  }

  String _peso(double amount) => '₱${amount.toStringAsFixed(0)}';

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final MediaQueryData mediaQuery = MediaQuery.of(context);

    return SafeArea(
      child: SizedBox(
        height: mediaQuery.size.height * 0.72,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  CircleAvatar(
                    backgroundColor: scheme.primary.withValues(alpha: 0.12),
                    foregroundColor: scheme.primary,
                    child: const Icon(Icons.auto_awesome_rounded),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          Text(
                            'Buds',
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFD97706)
                                  .withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'DEV',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFFD97706),
                              ),
                            ),
                          ),
                        ],
                      ),
                      Text(
                        'AI Assistant (Under Development)',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                            ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: <Widget>[
                  ActionChip(
                    avatar: const Icon(Icons.account_balance_wallet_outlined,
                        size: 17),
                    label: const Text('Budget status'),
                    onPressed: () => _sendMessage('What is my budget status?'),
                  ),
                  ActionChip(
                    avatar: const Icon(Icons.receipt_long_outlined, size: 17),
                    label: const Text('What did I spend?'),
                    onPressed: () => _sendMessage('What did I spend?'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(
                child: ListView.builder(
                  itemCount: _messages.length,
                  itemBuilder: (BuildContext context, int index) {
                    final _BudsMessage message = _messages[index];
                    return Align(
                      alignment: message.fromUser
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      child: Container(
                        constraints: const BoxConstraints(maxWidth: 310),
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: message.fromUser
                              ? scheme.primary
                              : scheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          message.text,
                          style: TextStyle(
                            color: message.fromUser
                                ? scheme.onPrimary
                                : scheme.onSurface,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: <Widget>[
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _sendMessage(),
                      decoration: const InputDecoration(
                        hintText: 'Ask Buds...',
                        prefixIcon: Icon(Icons.chat_bubble_outline_rounded),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    tooltip: 'Send message',
                    onPressed: _sendMessage,
                    icon: const Icon(Icons.arrow_upward_rounded),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BudsMessage {
  const _BudsMessage({required this.text, required this.fromUser});

  final String text;
  final bool fromUser;
}
