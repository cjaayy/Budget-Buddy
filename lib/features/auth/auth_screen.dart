import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/state/app_controller.dart';

class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  final TextEditingController _nameController =
      TextEditingController(text: 'Juan Dela Cruz');

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const SizedBox(height: 24),
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: Theme.of(context)
                            .colorScheme
                            .primary
                            .withOpacity(0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Icon(Icons.savings_rounded,
                          size: 48,
                          color: Theme.of(context).colorScheme.primary),
                    ),
                    const SizedBox(height: 12),
                    Text('BudgetBuddy',
                        style: Theme.of(context)
                            .textTheme
                            .headlineSmall
                            ?.copyWith(fontWeight: FontWeight.w800)),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'Offline-first. Register an account to save your data.',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(
                    labelText: 'Display Name',
                    prefixIcon: Icon(Icons.person_rounded)),
              ),
              const SizedBox(height: 20),
              LayoutBuilder(
                builder: (BuildContext ctx, BoxConstraints constraints) {
                  final bool wide = constraints.maxWidth >= 600;
                  Widget offlineCard = Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          Text('Offline',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w700)),
                          const SizedBox(height: 8),
                          const Text(
                              'Use the app locally without registering.'),
                          const SizedBox(height: 16),
                          FilledButton(
                            onPressed: () {
                              ref
                                  .read(budgetBuddyControllerProvider.notifier)
                                  .login(
                                    _nameController.text,
                                  );
                            },
                            child: const Text('Sign in (offline)'),
                          ),
                        ],
                      ),
                    ),
                  );

                  Widget saveCard = Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          Text('Save data',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w700)),
                          const SizedBox(height: 8),
                          const Text(
                              'Register a local account to persist your profile and data on this device.'),
                          const SizedBox(height: 16),
                          OutlinedButton(
                            onPressed: () {
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content: Text(
                                          'Coming soon — save-data feature')),
                                );
                              }
                            },
                            child: const Text('Register account'),
                          ),
                          const SizedBox(height: 8),
                          OutlinedButton(
                            onPressed: () {
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content: Text(
                                          'Coming soon — save-data feature')),
                                );
                              }
                            },
                            child: const Text('Sign in to registered'),
                          ),
                        ],
                      ),
                    ),
                  );

                  if (wide) {
                    return Row(
                      children: <Widget>[
                        Expanded(child: offlineCard),
                        const SizedBox(width: 16),
                        Expanded(child: saveCard),
                      ],
                    );
                  }

                  return Column(
                    children: <Widget>[
                      offlineCard,
                      const SizedBox(height: 12),
                      saveCard,
                    ],
                  );
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}
