import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/models/budget_models.dart';
import '../../core/state/app_controller.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/budget_cards.dart';

class ProfileSettingsScreen extends ConsumerStatefulWidget {
  const ProfileSettingsScreen({super.key});

  @override
  ConsumerState<ProfileSettingsScreen> createState() =>
      _ProfileSettingsScreenState();
}

class _ProfileSettingsScreenState extends ConsumerState<ProfileSettingsScreen> {
  final TextEditingController _backupRestoreController =
      TextEditingController();

  @override
  void dispose() {
    _backupRestoreController.dispose();
    super.dispose();
  }

  Future<void> _pickProfileImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);

    if (image != null) {
      // Get application documents directory
      final Directory docDir = await getApplicationDocumentsDirectory();
      final String fileName =
          'profile_${DateTime.now().millisecondsSinceEpoch}.png';
      final File profileImageFile = File('${docDir.path}/$fileName');

      // Copy image to app directory
      await profileImageFile.writeAsBytes(await image.readAsBytes());

      // Update profile with new image path
      ref
          .read(budgetBuddyControllerProvider.notifier)
          .updateProfileImage(profileImageFile.path);
    }
  }

  @override
  Widget build(BuildContext context) {
    final BudgetBuddyState state = ref.watch(budgetBuddyControllerProvider);
    final BudgetSummary summary = ref.watch(budgetSummaryProvider);
    final BudgetSettings settings = state.settings;

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: <Widget>[
            const Text(
              'Profile & settings',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            Text(
              'Manage your profile and preferences.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            SectionCard(
              child: Column(
                children: <Widget>[
                  GestureDetector(
                    onTap: _pickProfileImage,
                    child: Stack(
                      alignment: Alignment.bottomRight,
                      children: <Widget>[
                        CircleAvatar(
                          radius: 40,
                          backgroundColor: Theme.of(context)
                              .colorScheme
                              .primary
                              .withValues(alpha: 0.12),
                          backgroundImage: state.profile.profileImagePath !=
                                  null
                              ? FileImage(File(state.profile.profileImagePath!))
                              : null,
                          child: state.profile.profileImagePath == null
                              ? Text(
                                  state.profile.avatarSeed,
                                  style: Theme.of(context)
                                      .textTheme
                                      .headlineSmall
                                      ?.copyWith(
                                        fontWeight: FontWeight.w800,
                                      ),
                                )
                              : null,
                        ),
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.primary,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.camera_alt_rounded,
                            size: 16,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    state.profile.displayName,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _SectionShell(
              title: 'My profile',
              child: Column(
                children: <Widget>[
                  Semantics(
                    label: 'Display name',
                    textField: true,
                    child: _ReadonlyRow(
                        label: 'Display name',
                        value: state.profile.displayName),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _SectionShell(
              title: 'Preferences',
              child: Column(
                children: <Widget>[
                  Semantics(
                    label: 'Notifications enabled',
                    child: SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      value: settings.notificationsEnabled,
                      onChanged: (bool value) => ref
                          .read(budgetBuddyControllerProvider.notifier)
                          .updateProfilePreferences(
                              notificationsEnabled: value),
                      title: const Text('Daily notifications'),
                      subtitle: const Text(
                          'Budget warnings, end-of-day summaries, and streak reminders.'),
                    ),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: settings.budgetWarningNotificationsEnabled,
                    onChanged: (bool value) => ref
                        .read(budgetBuddyControllerProvider.notifier)
                        .updateProfilePreferences(
                            budgetWarningNotificationsEnabled: value),
                    title: const Text('Budget warning alerts'),
                    subtitle: const Text(
                        'Notify when spending is getting close to the limit.'),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: settings.summaryNotificationsEnabled,
                    onChanged: (bool value) => ref
                        .read(budgetBuddyControllerProvider.notifier)
                        .updateProfilePreferences(
                            summaryNotificationsEnabled: value),
                    title: const Text('End-of-day summary'),
                    subtitle:
                        const Text('Send a summary when the day wraps up.'),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: settings.streakNotificationsEnabled,
                    onChanged: (bool value) => ref
                        .read(budgetBuddyControllerProvider.notifier)
                        .updateProfilePreferences(
                            streakNotificationsEnabled: value),
                    title: const Text('Streak reminders'),
                    subtitle: const Text('Keep the savings streak visible.'),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<NotificationFrequency>(
                    initialValue: settings.notificationFrequency,
                    items: NotificationFrequency.values
                        .map(
                          (NotificationFrequency frequency) =>
                              DropdownMenuItem<NotificationFrequency>(
                            value: frequency,
                            child: Text(frequency.label),
                          ),
                        )
                        .toList(),
                    onChanged: (NotificationFrequency? value) {
                      if (value == null) {
                        return;
                      }
                      ref
                          .read(budgetBuddyControllerProvider.notifier)
                          .updateProfilePreferences(
                              notificationFrequency: value);
                    },
                    decoration:
                        const InputDecoration(labelText: 'Reminder frequency'),
                  ),
                  const SizedBox(height: 12),
                  _TimeSettingTile(
                    label: 'Reminder time',
                    value: _formatMinuteOfDay(
                        settings.notificationReminderMinuteOfDay),
                    onTap: () => _pickMinuteOfDay(
                      context,
                      title: 'Select reminder time',
                      initialMinuteOfDay:
                          settings.notificationReminderMinuteOfDay,
                      onSelected: (int minuteOfDay) {
                        ref
                            .read(budgetBuddyControllerProvider.notifier)
                            .updateProfilePreferences(
                              notificationReminderMinuteOfDay: minuteOfDay,
                            );
                      },
                    ),
                  ),
                  const SizedBox(height: 8),
                  _TimeSettingTile(
                    label: 'Day starts at',
                    value: _formatMinuteOfDay(settings.dayStartMinuteOfDay),
                    onTap: () => _pickMinuteOfDay(
                      context,
                      title: 'Select day-start time',
                      initialMinuteOfDay: settings.dayStartMinuteOfDay,
                      onSelected: (int minuteOfDay) {
                        ref
                            .read(budgetBuddyControllerProvider.notifier)
                            .updateProfilePreferences(
                                dayStartMinuteOfDay: minuteOfDay);
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: FilledButton.tonalIcon(
                      onPressed: () => ref
                          .read(budgetBuddyControllerProvider.notifier)
                          .sendSummaryNotification(),
                      icon: const Icon(Icons.notifications_active_rounded),
                      label: const Text('Send summary now'),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _SectionShell(
              title: 'Data',
              child: Column(
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: Semantics(
                          button: true,
                          label: 'Export PDF report',
                          child: FilledButton.icon(
                            onPressed: () =>
                                _exportPdf(context, state, summary),
                            icon: const Icon(Icons.picture_as_pdf_rounded),
                            label: const Text('Export PDF'),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Semantics(
                          button: true,
                          label: 'Export CSV report',
                          child: FilledButton.icon(
                            onPressed: () => _exportCsv(context, state),
                            icon: const Icon(Icons.table_view_rounded),
                            label: const Text('Export CSV'),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: Semantics(
                          button: true,
                          label: 'Back up data snapshot',
                          child: OutlinedButton.icon(
                            onPressed: () => _backupSnapshot(context, state),
                            icon: const Icon(Icons.cloud_upload_rounded),
                            label: const Text('Back up JSON'),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Semantics(
                          button: true,
                          label: 'Restore data snapshot',
                          child: OutlinedButton.icon(
                            onPressed: () => _restoreSnapshot(context),
                            icon: const Icon(Icons.cloud_download_rounded),
                            label: const Text('Restore JSON'),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: Semantics(
                          button: true,
                          label: 'Logout of account',
                          child: OutlinedButton.icon(
                            onPressed: () => ref
                                .read(budgetBuddyControllerProvider.notifier)
                                .logout(),
                            icon: const Icon(Icons.logout_rounded),
                            label: const Text('Logout'),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Semantics(
                          button: true,
                          label: 'Reset day',
                          child: FilledButton.tonalIcon(
                            onPressed: () => _confirmResetDay(context),
                            icon: const Icon(Icons.refresh_rounded),
                            label: const Text('Reset day'),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _SectionShell(
              title: 'Danger Zone',
              accentColor: const Color(0xFFDC2626),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'These actions are destructive. Use them only when you want to clear local data or start over.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: Semantics(
                      button: true,
                      label: 'Reset entire app',
                      child: FilledButton.icon(
                        onPressed: () => _confirmResetApp(context),
                        icon: const Icon(Icons.delete_sweep_rounded),
                        label: const Text('Reset all data'),
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFFDC2626),
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _exportPdf(BuildContext context, BudgetBuddyState state,
      BudgetSummary summary) async {
    final file = await ref.read(reportServiceProvider).exportDailyReport(
          state: state,
          summary: summary,
        );
    await Share.shareXFiles(<XFile>[XFile(file.path)],
        text: 'BudgetBuddy daily report');
  }

  Future<void> _exportCsv(BuildContext context, BudgetBuddyState state) async {
    final file = await ref.read(reportServiceProvider).exportCsv(state: state);
    await Share.shareXFiles(<XFile>[XFile(file.path)],
        text: 'BudgetBuddy CSV export');
  }

  Future<void> _backupSnapshot(
      BuildContext context, BudgetBuddyState state) async {
    final Directory directory = await getTemporaryDirectory();
    final File file = File(
      '${directory.path}${Platform.pathSeparator}BudgetBuddy_Backup.json',
    );
    await file.writeAsString(state.encode());
    await Share.shareXFiles(<XFile>[XFile(file.path)],
        text: 'BudgetBuddy backup snapshot');
  }

  Future<void> _restoreSnapshot(BuildContext context) async {
    _backupRestoreController.clear();
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final bool? shouldRestore = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Restore backup snapshot'),
          content: SizedBox(
            width: double.maxFinite,
            child: TextField(
              controller: _backupRestoreController,
              maxLines: 8,
              decoration: const InputDecoration(
                labelText: 'Paste JSON backup here',
                alignLabelWithHint: true,
              ),
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Restore'),
            ),
          ],
        );
      },
    );

    if (!mounted || shouldRestore != true) {
      return;
    }

    try {
      final BudgetBuddyState snapshot = BudgetBuddyState.decode(
        _backupRestoreController.text.trim(),
      );
      ref
          .read(budgetBuddyControllerProvider.notifier)
          .restoreSnapshot(snapshot);
      if (!mounted) {
        return;
      }
      messenger.showSnackBar(
        const SnackBar(content: Text('Backup restored successfully.')),
      );
    } catch (_) {
      if (!mounted) {
        return;
      }
      messenger.showSnackBar(
        const SnackBar(content: Text('Could not restore that backup file.')),
      );
    }
  }

  Future<void> _confirmResetDay(BuildContext context) async {
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Reset today only?'),
          content: const Text(
              'This clears today\'s expenses and starts a fresh day.'),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Reset day'),
            ),
          ],
        );
      },
    );

    if (!mounted || confirm != true) {
      return;
    }

    ref.read(budgetBuddyControllerProvider.notifier).resetForNextDay();
    if (!mounted) {
      return;
    }
    messenger.showSnackBar(
      const SnackBar(content: Text('Day reset successfully.')),
    );
  }

  Future<void> _confirmResetApp(BuildContext context) async {
    final TextEditingController confirmationController =
        TextEditingController();
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Reset entire app?'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Text(
                'This will clear all budgets, expenses, spending records, and daily logs. Type RESET to continue.',
              ),
              const SizedBox(height: 12),
              TextField(
                controller: confirmationController,
                decoration: const InputDecoration(labelText: 'Type RESET'),
              ),
            ],
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                if (confirmationController.text.trim().toUpperCase() ==
                    'RESET') {
                  Navigator.of(context).pop(true);
                }
              },
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFDC2626),
                foregroundColor: Colors.white,
              ),
              child: const Text('Reset'),
            ),
          ],
        );
      },
    );

    confirmationController.dispose();

    if (!mounted || confirm != true) {
      return;
    }

    await ref.read(budgetBuddyControllerProvider.notifier).resetApp();
    if (!mounted) {
      return;
    }
    messenger.showSnackBar(
      const SnackBar(content: Text('App reset to zero successfully.')),
    );
  }

  Future<void> _pickMinuteOfDay(
    BuildContext context, {
    required String title,
    required int initialMinuteOfDay,
    required ValueChanged<int> onSelected,
  }) async {
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final MaterialLocalizations localizations =
        MaterialLocalizations.of(context);
    final TimeOfDay initialTime = TimeOfDay(
      hour: initialMinuteOfDay ~/ 60,
      minute: initialMinuteOfDay % 60,
    );
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: initialTime,
    );
    if (picked == null) {
      return;
    }
    onSelected(picked.hour * 60 + picked.minute);
    messenger.showSnackBar(
      SnackBar(
          content:
              Text('$title set to ${localizations.formatTimeOfDay(picked)}')),
    );
  }

  String _formatMinuteOfDay(int minuteOfDay) {
    final TimeOfDay time = TimeOfDay(
      hour: minuteOfDay ~/ 60,
      minute: minuteOfDay % 60,
    );
    return time.format(context);
  }
}

class _SectionShell extends StatelessWidget {
  const _SectionShell({
    required this.title,
    required this.child,
    this.accentColor,
  });

  final String title;
  final Widget child;
  final Color? accentColor;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            title,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: accentColor,
                ),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _ReadonlyRow extends StatelessWidget {
  const _ReadonlyRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        ),
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}

class _TimeSettingTile extends StatelessWidget {
  const _TimeSettingTile({
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        onTap: onTap,
        leading: const Icon(Icons.schedule_rounded),
        title: Text(label),
        subtitle: Text(value),
        trailing: const Icon(Icons.chevron_right_rounded),
      ),
    );
  }
}
