import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/state/app_controller.dart';

class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  final TextEditingController _nameController = TextEditingController();
  bool _isEditingName = false;

  String _buildInitials(String displayName) {
    final String trimmed = displayName.trim();
    if (trimmed.isEmpty) {
      return 'BB';
    }
    return trimmed
        .split(RegExp(r'\s+'))
        .take(2)
        .map((String part) => part.isNotEmpty ? part[0] : '')
        .join()
        .toUpperCase();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(budgetBuddyControllerProvider);
    final String savedDisplayName = state.profile.displayName;
    final String placeholderName =
        savedDisplayName.trim().isEmpty || savedDisplayName == 'Budget Buddy'
            ? 'Enter display name'
            : savedDisplayName;

    final String normalizedSavedName =
        savedDisplayName == 'Budget Buddy' ? '' : savedDisplayName.trim();
    final String currentInputName = _nameController.text.trim();
    final bool canSaveName = _isEditingName &&
        currentInputName.isNotEmpty &&
        currentInputName != normalizedSavedName;
    if (!state.loggedIn &&
        _nameController.text.trim().isEmpty &&
        normalizedSavedName.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        _nameController.value = TextEditingValue(
          text: normalizedSavedName,
          selection:
              TextSelection.collapsed(offset: normalizedSavedName.length),
        );
      });
    }

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
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
                                .withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Icon(Icons.savings_rounded,
                              size: 48,
                              color: Theme.of(context).colorScheme.primary),
                        ),
                        const SizedBox(height: 12),
                        Text('Budget Buddy',
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
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    TextField(
                      controller: _nameController,
                      readOnly: !_isEditingName,
                      onChanged: (_) {
                        if (_isEditingName) {
                          setState(() {});
                        }
                      },
                      decoration: InputDecoration(
                        labelText: 'Display Name',
                        hintText: placeholderName,
                        prefixIcon: const Icon(Icons.person_rounded),
                        suffixIcon: !_isEditingName
                            ? TextButton(
                                onPressed: () {
                                  setState(() {
                                    _isEditingName = true;
                                  });
                                },
                                child: const Text('Edit'),
                              )
                            : null,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: <Widget>[
                        if (_isEditingName) ...<Widget>[
                          FilledButton(
                            onPressed: canSaveName
                                ? () {
                                    final String updatedName =
                                        _nameController.text.trim();
                                    ref
                                        .read(budgetBuddyControllerProvider
                                            .notifier)
                                        .updateProfile(
                                          state.profile.copyWith(
                                            displayName: updatedName,
                                            avatarSeed:
                                                _buildInitials(updatedName),
                                          ),
                                        );
                                    setState(() {
                                      _isEditingName = false;
                                    });
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                          content: Text('Display name saved')),
                                    );
                                  }
                                : null,
                            child: const Text('Save'),
                          ),
                          const SizedBox(width: 8),
                          OutlinedButton(
                            onPressed: () {
                              _nameController.value = TextEditingValue(
                                text: normalizedSavedName,
                                selection: TextSelection.collapsed(
                                    offset: normalizedSavedName.length),
                              );
                              setState(() {
                                _isEditingName = false;
                              });
                            },
                            child: const Text('Cancel'),
                          ),
                        ],
                      ],
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
                                        ?.copyWith(
                                            fontWeight: FontWeight.w700)),
                                const SizedBox(height: 8),
                                const Text(
                                    'Use the app locally without registering.'),
                                const SizedBox(height: 4),
                                const Text(
                                  'Tap Edit to change name, then Save.',
                                ),
                                const SizedBox(height: 16),
                                FilledButton(
                                  onPressed: () {
                                    ref
                                        .read(budgetBuddyControllerProvider
                                            .notifier)
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
                                        ?.copyWith(
                                            fontWeight: FontWeight.w700)),
                                const SizedBox(height: 8),
                                const Text(
                                    'Register a local account to persist your profile and data on this device.'),
                                const SizedBox(height: 16),
                                OutlinedButton(
                                  onPressed: () {
                                    if (mounted) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
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
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
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
          ],
        ),
      ),
    );
  }
}
