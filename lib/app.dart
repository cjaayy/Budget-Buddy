import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/state/app_controller.dart';
import 'core/models/budget_models.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/auth_screen.dart';
import 'features/onboarding/onboarding_screen.dart';
import 'features/splash/splash_screen.dart';
import 'features/home/home_shell.dart';

class BudgetBuddyApp extends ConsumerWidget {
  const BudgetBuddyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final BudgetBuddyState state = ref.watch(budgetBuddyControllerProvider);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'BudgetBuddy',
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: state.themeMode,
      home: _AppGate(state: state),
    );
  }
}

class _AppGate extends StatelessWidget {
  const _AppGate({required this.state});

  final BudgetBuddyState state;

  @override
  Widget build(BuildContext context) {
    if (state.isBootstrapping) {
      return const SplashScreen();
    }

    if (!state.onboardingComplete) {
      return const OnboardingScreen();
    }

    if (!state.loggedIn) {
      return const AuthScreen();
    }

    return const HomeShell();
  }
}
