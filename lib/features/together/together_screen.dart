import 'package:flutter/material.dart';

import '../../core/widgets/budget_cards.dart';
import '../../core/widgets/section_title.dart';

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
                  children: const <Widget>[
                    SectionCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: Icon(Icons.account_balance_wallet_rounded),
                            title: Text('Budget'),
                            subtitle: Text('Budget planner and budget status.'),
                          ),
                          Divider(height: 1),
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: Icon(Icons.shopping_bag_rounded),
                            title: Text('Spend'),
                            subtitle: Text('Track daily spending.'),
                          ),
                          Divider(height: 1),
                          ListTile(
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
