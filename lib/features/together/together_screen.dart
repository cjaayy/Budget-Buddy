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
                title: 'Together',
                subtitle:
                    'Shared planning for the people you manage money with.',
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
                            leading: Icon(Icons.group_add_rounded),
                            title: Text('Invite your circle'),
                            subtitle: Text(
                              'Add the people who should see shared goals and budgets.',
                            ),
                          ),
                          Divider(height: 1),
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: Icon(Icons.handshake_rounded),
                            title: Text('Coordinate goals'),
                            subtitle: Text(
                              'Track common savings targets and spending plans together.',
                            ),
                          ),
                          Divider(height: 1),
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: Icon(Icons.chat_bubble_outline_rounded),
                            title: Text('Stay in sync'),
                            subtitle: Text(
                              'Keep everyone aligned with a shared money workspace.',
                            ),
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
