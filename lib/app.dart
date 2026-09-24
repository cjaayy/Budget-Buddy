import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/state/app_controller.dart';
import 'core/models/budget_models.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/auth_screen.dart';
import 'features/onboarding/onboarding_screen.dart';
import 'features/splash/splash_screen.dart';
import 'features/home/home_shell.dart';

class BudgetBuddyApp extends ConsumerStatefulWidget {
  const BudgetBuddyApp({super.key});

  @override
  ConsumerState<BudgetBuddyApp> createState() => _BudgetBuddyAppState();
}

class _BudgetBuddyAppState extends ConsumerState<BudgetBuddyApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState lifecycleState) {
    if (lifecycleState == AppLifecycleState.resumed) {
      ref
          .read(budgetBuddyControllerProvider.notifier)
          .syncDateAndCheckMidnightReset();
    }
  }

  @override
  Widget build(BuildContext context) {
    final BudgetBuddyState state = ref.watch(budgetBuddyControllerProvider);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Budget Buddy',
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
