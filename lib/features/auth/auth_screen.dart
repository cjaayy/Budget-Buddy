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
  final TextEditingController _cityController =
      TextEditingController(text: 'Makati');

  @override
  void dispose() {
    _nameController.dispose();
    _cityController.dispose();
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
              const SizedBox(height: 32),
              Text('BudgetBuddy',
                  style: Theme.of(context)
                      .textTheme
                      .headlineMedium
                      ?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              Text(
                'Sign in or register locally to start tracking your daily budget.',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 28),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: <Widget>[
                      TextField(
                        controller: _nameController,
                        decoration: const InputDecoration(
                            labelText: 'Display name',
                            prefixIcon: Icon(Icons.person_rounded)),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _cityController,
                        decoration: const InputDecoration(
                            labelText: 'City',
                            prefixIcon: Icon(Icons.location_on_rounded)),
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: () {
                            ref
                                .read(budgetBuddyControllerProvider.notifier)
                                .login(
                                  _nameController.text,
                                  city: _cityController.text,
                                );
                          },
                          child: const Text('Login'),
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed: () {
                            ref
                                .read(budgetBuddyControllerProvider.notifier)
                                .login(
                                  _nameController.text,
                                  city: _cityController.text,
                                );
                          },
                          child: const Text('Register'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              const _FeaturePreview(
                  icon: Icons.lock_open_rounded,
                  title: 'Offline first',
                  subtitle: 'Data stays on the device with local storage.'),
              const _FeaturePreview(
                  icon: Icons.auto_graph_rounded,
                  title: 'Smart insights',
                  subtitle:
                      'Budget, meal, and gala recommendations update instantly.'),
              const _FeaturePreview(
                  icon: Icons.notifications_active_rounded,
                  title: 'Daily reminders',
                  subtitle: 'Keep your spending on track with notifications.'),
            ],
          ),
        ),
      ),
    );
  }
}

class _FeaturePreview extends StatelessWidget {
  const _FeaturePreview(
      {required this.icon, required this.title, required this.subtitle});

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        children: <Widget>[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color:
                  Theme.of(context).colorScheme.primary.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: Theme.of(context).colorScheme.primary),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(title,
                    style: const TextStyle(fontWeight: FontWeight.w700)),
                Text(subtitle),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
