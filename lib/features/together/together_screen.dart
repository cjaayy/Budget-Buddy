import 'package:flutter/material.dart';

import '../../core/widgets/budget_cards.dart';
import '../../core/widgets/section_title.dart';
import 'budget_together_screen.dart';
import '../spend/spend_screen.dart';

class TogetherScreen extends StatelessWidget {
  const TogetherScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const SectionTitle(
                title: 'Budget Together',
                subtitle: 'Main menu sections from the shell.',
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ListView(
                  padding: EdgeInsets.zero,
                  children: <Widget>[
                    SectionCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(
                                Icons.account_balance_wallet_rounded),
                            title: const Text('Budget'),
                            subtitle:
                                const Text('Budget planner and budget status.'),
                            trailing: const Icon(Icons.chevron_right_rounded),
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (BuildContext context) =>
                                      const BudgetTogetherScreen(),
                                ),
                              );
                            },
                          ),
                          const Divider(height: 1),
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(Icons.shopping_bag_rounded),
                            title: const Text('Spend'),
                            subtitle: const Text('Track daily spending.'),
                            trailing: const Icon(Icons.chevron_right_rounded),
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (BuildContext context) =>
                                      const SpendScreen(),
                                ),
                              );
                            },
                          ),
                          const Divider(height: 1),
                          const ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: Icon(Icons.receipt_long_rounded),
                            title: Text('Expenses'),
                            subtitle: Text('Review expense tracking.'),
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
}
