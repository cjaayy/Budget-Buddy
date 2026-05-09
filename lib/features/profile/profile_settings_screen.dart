import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/models/budget_models.dart';
import '../../core/state/app_controller.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/budget_cards.dart';
import '../../core/widgets/section_title.dart';

class ProfileSettingsScreen extends ConsumerWidget {
  const ProfileSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final BudgetBuddyState state = ref.watch(budgetBuddyControllerProvider);
    final BudgetSummary summary = ref.watch(budgetSummaryProvider);

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: <Widget>[
            const SectionTitle(
                title: 'Profile & settings',
                subtitle: 'Manage the look, reminders, and reports.'),
            const SizedBox(height: 16),
            SectionCard(
              child: Row(
                children: <Widget>[
                  CircleAvatar(
                      radius: 28, child: Text(state.profile.avatarSeed)),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(state.profile.displayName,
                            style: const TextStyle(
                                fontWeight: FontWeight.w700, fontSize: 18)),
                        Text(state.profile.city),
                        Text(
                            '${state.profile.savingsStreak} day savings streak'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SectionCard(
              child: Column(
                children: <Widget>[
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: state.notificationsEnabled,
                    onChanged: (bool value) => ref
                        .read(budgetBuddyControllerProvider.notifier)
                        .setNotificationsEnabled(value),
                    title: const Text('Daily notifications'),
                    subtitle:
                        const Text('Budget reminders and end-of-day summaries'),
                  ),
                  const Divider(),
                  DropdownButtonFormField<ThemeMode>(
                    initialValue: state.themeMode,
                    items: const <DropdownMenuItem<ThemeMode>>[
                      DropdownMenuItem(
                          value: ThemeMode.system, child: Text('System')),
                      DropdownMenuItem(
                          value: ThemeMode.light, child: Text('Light')),
                      DropdownMenuItem(
                          value: ThemeMode.dark, child: Text('Dark')),
                    ],
                    onChanged: (ThemeMode? value) {
                      if (value != null) {
                        ref
                            .read(budgetBuddyControllerProvider.notifier)
                            .setThemeMode(value);
                      }
                    },
                    decoration: const InputDecoration(labelText: 'Theme mode'),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: () async {
                            final file = await ref
                                .read(reportServiceProvider)
                                .exportDailyReport(
                                    state: state, summary: summary);
                            await Share.shareXFiles(<XFile>[XFile(file.path)],
                                text: 'BudgetBuddy daily report');
                          },
                          icon: const Icon(Icons.picture_as_pdf_rounded),
                          label: const Text('Export PDF'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => ref
                              .read(budgetBuddyControllerProvider.notifier)
                              .sendSummaryNotification(),
                          icon: const Icon(Icons.notifications_active_rounded),
                          label: const Text('Send summary'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => ref
                              .read(budgetBuddyControllerProvider.notifier)
                              .logout(),
                          icon: const Icon(Icons.logout_rounded),
                          label: const Text('Logout'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: FilledButton.tonalIcon(
                          onPressed: () => ref
                              .read(budgetBuddyControllerProvider.notifier)
                              .resetForNextDay(),
                          icon: const Icon(Icons.refresh_rounded),
                          label: const Text('Reset day'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            BudgetMetricCard(
              label: 'Savings today',
              value: formatPeso(summary.savings),
              subtitle:
                  'Weekly and monthly reports are derived from daily logs.',
              icon: Icons.insights_rounded,
              color: const Color(0xFF0F766E),
            ),
          ],
        ),
      ),
    );
  }
}
