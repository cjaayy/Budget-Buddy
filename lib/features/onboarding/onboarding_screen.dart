import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/state/app_controller.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final PageController _controller = PageController();
  int _index = 0;

  final List<_OnboardingStep> _steps = const <_OnboardingStep>[
    _OnboardingStep(
      icon: Icons.account_balance_wallet_rounded,
      title: 'Track every peso',
      description:
          'Set daily limits for food, transport, and gala plans in one clean view.',
    ),
    _OnboardingStep(
      icon: Icons.restaurant_menu_rounded,
      title: 'Get smart meal ideas',
      description:
          'See budget meals and healthier alternatives that fit your remaining balance.',
    ),
    _OnboardingStep(
      icon: Icons.explore_rounded,
      title: 'Plan the day wisely',
      description:
          'Balance meals, errands, and strolling without blowing your budget.',
    ),
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: <Widget>[
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () {
                    ref
                        .read(budgetBuddyControllerProvider.notifier)
                        .completeOnboarding();
                  },
                  child: const Text('Skip'),
                ),
              ),
              Expanded(
                child: PageView.builder(
                  controller: _controller,
                  onPageChanged: (int value) => setState(() => _index = value),
                  itemCount: _steps.length,
                  itemBuilder: (BuildContext context, int index) {
                    final _OnboardingStep step = _steps[index];
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: <Widget>[
                          Container(
                            padding: const EdgeInsets.all(28),
                            decoration: BoxDecoration(
                              color: Theme.of(context)
                                  .colorScheme
                                  .primary
                                  .withValues(alpha: 0.10),
                              borderRadius: BorderRadius.circular(32),
                            ),
                            child: Icon(step.icon,
                                size: 72,
                                color: Theme.of(context).colorScheme.primary),
                          ),
                          const SizedBox(height: 28),
                          Text(
                            step.title,
                            textAlign: TextAlign.center,
                            style: Theme.of(context)
                                .textTheme
                                .headlineMedium
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            step.description,
                            textAlign: TextAlign.center,
                            style: Theme.of(context)
                                .textTheme
                                .bodyLarge
                                ?.copyWith(height: 1.5),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List<Widget>.generate(
                  _steps.length,
                  (int index) => AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: _index == index ? 22 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: _index == index
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).colorScheme.outlineVariant,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () {
                    if (_index < _steps.length - 1) {
                      _controller.nextPage(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeOut);
                    } else {
                      ref
                          .read(budgetBuddyControllerProvider.notifier)
                          .completeOnboarding();
                    }
                  },
                  child: Text(
                      _index < _steps.length - 1 ? 'Continue' : 'Get Started'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OnboardingStep {
  const _OnboardingStep(
      {required this.icon, required this.title, required this.description});

  final IconData icon;
  final String title;
  final String description;
}
