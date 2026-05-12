import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/models/budget_models.dart';
import '../../core/state/app_controller.dart';
import '../../core/services/notification_service.dart';
import '../../core/services/budget_service.dart';
import '../../core/widgets/budget_cards.dart';
import '../../core/widgets/section_title.dart';

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

  @override
  Widget build(BuildContext context) {
    final BudgetBuddyState state = ref.watch(budgetBuddyControllerProvider);
    final BudgetSummary summary = BudgetService().computeSummary(state);

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const SectionTitle(
                title: 'Settings',
                subtitle: 'Profile, preferences, and data controls.',
              ),
              const SizedBox(height: 12),
              Expanded(
                child: ListView(
                  padding: EdgeInsets.zero,
                  children: <Widget>[
                    SectionCard(
                      child: Column(
                        children: <Widget>[
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(Icons.person_outline_rounded),
                            title: const Text('Profile'),
                            subtitle: const Text('Edit your name'),
                            trailing: const Icon(Icons.chevron_right_rounded),
                            onTap: () => _openProfileMenu(context, state),
                          ),
                          const Divider(height: 1),
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(Icons.tune_rounded),
                            title: const Text('Preferences'),
                            subtitle:
                                const Text('Notifications and summary options'),
                            trailing: const Icon(Icons.chevron_right_rounded),
                            onTap: () => _showPreferencesSheet(context, state),
                          ),
                          const Divider(height: 1),
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(Icons.storage_rounded),
                            title: const Text('Data'),
                            subtitle:
                                const Text('Export, backup, reset, and logout'),
                            trailing: const Icon(Icons.chevron_right_rounded),
                            onTap: () =>
                                _showDataSheet(context, state, summary),
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

  void _showPreferencesSheet(
    BuildContext parentContext,
    BudgetBuddyState state,
  ) {
    showModalBottomSheet<void>(
      context: parentContext,
      showDragHandle: false,
      isScrollControlled: true,
      builder: (BuildContext context) {
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              20,
              8,
              20,
              20 + MediaQuery.of(context).viewInsets.bottom,
            ),
            child: Consumer(
              builder: (BuildContext _, WidgetRef modalRef, Widget? __) {
                final BudgetSettings settings =
                    modalRef.watch(budgetBuddyControllerProvider).settings;

                return ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height * 0.9,
                  ),
                  child: Column(
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          IconButton(
                            onPressed: () => Navigator.of(context).pop(),
                            icon: const Icon(Icons.arrow_back_rounded),
                          ),
                          Expanded(
                            child: Text(
                              'Preferences',
                              textAlign: TextAlign.center,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleLarge
                                  ?.copyWith(fontWeight: FontWeight.w800),
                            ),
                          ),
                          const SizedBox(width: 48),
                        ],
                      ),
                      Text(
                        'Notifications and summary options',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                            ),
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        child: SingleChildScrollView(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: IconButton(
                                  onPressed: () async {
                                    final NotificationService notifier =
                                        modalRef
                                            .read(notificationServiceProvider);
                                    await notifier.showBudgetReminder(
                                      title: 'Overspend alert (Demo)',
                                      body:
                                          'Demo: You spent ₱620 today — ₱120 over your daily limit.',
                                    );
                                    if (context.mounted) {
                                      _showDemoSentModal(
                                        context,
                                        title: 'Demo Sent',
                                        message:
                                            'Overspend alert demo was sent to your phone.',
                                      );
                                    }
                                  },
                                  icon: const Icon(Icons.play_arrow_rounded),
                                  tooltip: 'Demo overspend alert',
                                ),
                                title: const Text('Overspend Alerts'),
                                subtitle: const Text(
                                    'Notify when spending is getting close to or exceeds the budget.'),
                                trailing: Switch(
                                  value: settings
                                      .budgetWarningNotificationsEnabled,
                                  onChanged: (bool value) async {
                                    final bool confirmed =
                                        await _showToggleConfirmationModal(
                                      context,
                                      settingLabel: 'Overspend Alerts',
                                      nextValue: value,
                                    );
                                    if (!context.mounted || !confirmed) {
                                      return;
                                    }
                                    modalRef
                                        .read(budgetBuddyControllerProvider
                                            .notifier)
                                        .updateProfilePreferences(
                                            budgetWarningNotificationsEnabled:
                                                value);
                                    if (context.mounted) {
                                      _showToggleSuccessModal(
                                        context,
                                        settingLabel: 'Overspend Alerts',
                                        nextValue: value,
                                      );
                                    }
                                  },
                                ),
                              ),
                              ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: IconButton(
                                  onPressed: () async {
                                    final NotificationService notifier =
                                        modalRef
                                            .read(notificationServiceProvider);
                                    await notifier.showEndOfDaySummary(
                                      title: 'End-of-day summary (Demo)',
                                      body: settings
                                              .includeYesterdaySpentInSummary
                                          ? 'Demo: Today ₱450. Yesterday ₱520.'
                                          : 'Demo: Today ₱450.',
                                    );
                                    if (context.mounted) {
                                      _showDemoSentModal(
                                        context,
                                        title: 'Demo Sent',
                                        message:
                                            'End-of-day summary demo was sent to your phone.',
                                      );
                                    }
                                  },
                                  icon: const Icon(Icons.play_arrow_rounded),
                                  tooltip: 'Demo Summary',
                                ),
                                title: const Text('End-of-day summary'),
                                subtitle: const Text(
                                    'Receive a summary when the day ends (includes yesterday\'s spent).'),
                                trailing: Switch(
                                  value: settings.summaryNotificationsEnabled,
                                  onChanged: (bool value) async {
                                    final bool confirmed =
                                        await _showToggleConfirmationModal(
                                      context,
                                      settingLabel: 'End-of-day summary',
                                      nextValue: value,
                                    );
                                    if (!context.mounted || !confirmed) {
                                      return;
                                    }
                                    modalRef
                                        .read(budgetBuddyControllerProvider
                                            .notifier)
                                        .updateProfilePreferences(
                                            summaryNotificationsEnabled: value);
                                    if (context.mounted) {
                                      _showToggleSuccessModal(
                                        context,
                                        settingLabel: 'End-of-day summary',
                                        nextValue: value,
                                      );
                                    }
                                  },
                                ),
                              ),
                              ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: IconButton(
                                  onPressed: () async {
                                    final NotificationService notifier =
                                        modalRef
                                            .read(notificationServiceProvider);
                                    await notifier.showBudgetReminder(
                                      title: 'Daily reset (Demo)',
                                      body:
                                          'Demo: Your daily budget has been reset to ₱500.',
                                    );
                                    if (context.mounted) {
                                      _showDemoSentModal(
                                        context,
                                        title: 'Demo Sent',
                                        message:
                                            'Daily reset demo was sent to your phone.',
                                      );
                                    }
                                  },
                                  icon: const Icon(Icons.play_arrow_rounded),
                                  tooltip: 'Demo daily reset',
                                ),
                                title: const Text(
                                    'Notify when daily budget resets'),
                                subtitle: const Text(
                                    'Receive a notification when the daily budget resets.'),
                                trailing: Switch(
                                  value: settings.notifyOnDailyReset,
                                  onChanged: (bool value) async {
                                    final bool confirmed =
                                        await _showToggleConfirmationModal(
                                      context,
                                      settingLabel: 'Daily reset notifications',
                                      nextValue: value,
                                    );
                                    if (!context.mounted || !confirmed) {
                                      return;
                                    }
                                    modalRef
                                        .read(budgetBuddyControllerProvider
                                            .notifier)
                                        .updateProfilePreferences(
                                            notifyOnDailyReset: value);
                                    if (context.mounted) {
                                      _showToggleSuccessModal(
                                        context,
                                        settingLabel:
                                            'Daily reset notifications',
                                        nextValue: value,
                                      );
                                    }
                                  },
                                ),
                              ),
                              const SizedBox(height: 12),
                              const SizedBox.shrink(),
                              const SizedBox(height: 12),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  void _showDemoSentModal(
    BuildContext parentContext, {
    required String title,
    required String message,
  }) {
    showModalBottomSheet<void>(
      context: parentContext,
      showDragHandle: false,
      isScrollControlled: true,
      builder: (BuildContext context) {
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              20,
              8,
              20,
              20 + MediaQuery.of(context).viewInsets.bottom,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.arrow_back_rounded),
                    ),
                    Expanded(
                      child: Text(
                        title,
                        textAlign: TextAlign.center,
                        style: Theme.of(context)
                            .textTheme
                            .titleLarge
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                    ),
                    const SizedBox(width: 48),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<bool> _showToggleConfirmationModal(
    BuildContext parentContext, {
    required String settingLabel,
    required bool nextValue,
  }) async {
    final bool? confirmed = await showModalBottomSheet<bool>(
      context: parentContext,
      showDragHandle: false,
      isScrollControlled: true,
      builder: (BuildContext context) {
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              20,
              8,
              20,
              20 + MediaQuery.of(context).viewInsets.bottom,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      icon: const Icon(Icons.arrow_back_rounded),
                    ),
                    Expanded(
                      child: Text(
                        'Confirm Change',
                        textAlign: TextAlign.center,
                        style: Theme.of(context)
                            .textTheme
                            .titleLarge
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                    ),
                    const SizedBox(width: 48),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'Turn ${nextValue ? 'on' : 'off'} "$settingLabel"?',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: 16),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(false),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton(
                        onPressed: () => Navigator.of(context).pop(true),
                        child: const Text('Confirm'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );

    return confirmed ?? false;
  }

  void _showToggleSuccessModal(
    BuildContext parentContext, {
    required String settingLabel,
    required bool nextValue,
  }) {
    showModalBottomSheet<void>(
      context: parentContext,
      showDragHandle: false,
      isScrollControlled: true,
      builder: (BuildContext context) {
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              20,
              8,
              20,
              20 + MediaQuery.of(context).viewInsets.bottom,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.arrow_back_rounded),
                    ),
                    Expanded(
                      child: Text(
                        'Success',
                        textAlign: TextAlign.center,
                        style: Theme.of(context)
                            .textTheme
                            .titleLarge
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                    ),
                    const SizedBox(width: 48),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  '"$settingLabel" is now ${nextValue ? 'on' : 'off'}.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('OK'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showDataSheet(
    BuildContext parentContext,
    BudgetBuddyState state,
    BudgetSummary summary,
  ) {
    showModalBottomSheet<void>(
      context: parentContext,
      showDragHandle: false,
      isScrollControlled: true,
      builder: (BuildContext context) {
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              20,
              8,
              20,
              20 + MediaQuery.of(context).viewInsets.bottom,
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.9,
              ),
              child: Column(
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.arrow_back_rounded),
                      ),
                      Expanded(
                        child: Text(
                          'Data',
                          textAlign: TextAlign.center,
                          style: Theme.of(context)
                              .textTheme
                              .titleLarge
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                      ),
                      const SizedBox(width: 48),
                    ],
                  ),
                  Text(
                    'Export, backup, reset, and logout',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
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
                                    icon: const Icon(
                                        Icons.picture_as_pdf_rounded),
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
                                    onPressed: () =>
                                        _backupSnapshot(context, state),
                                    icon:
                                        const Icon(Icons.cloud_upload_rounded),
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
                                    icon: const Icon(
                                        Icons.cloud_download_rounded),
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
                                        .read(budgetBuddyControllerProvider
                                            .notifier)
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
                                  label: 'Reset Day',
                                  child: FilledButton.tonalIcon(
                                    onPressed: () => _confirmResetDay(context),
                                    icon: const Icon(Icons.refresh_rounded),
                                    label: const Text('Reset Day'),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          SectionCard(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(
                                  'Danger Zone',
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleLarge
                                      ?.copyWith(
                                          fontWeight: FontWeight.w800,
                                          color: const Color(0xFFDC2626)),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  'These actions are destructive and should only be used when you want to clear your local data.',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyMedium
                                      ?.copyWith(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurfaceVariant,
                                      ),
                                ),
                                const SizedBox(height: 12),
                                SizedBox(
                                  width: double.infinity,
                                  child: Semantics(
                                    button: true,
                                    label: 'Reset entire app',
                                    child: FilledButton.icon(
                                      onPressed: () =>
                                          _confirmResetApp(context),
                                      icon: const Icon(
                                          Icons.delete_sweep_rounded),
                                      label:
                                          const Text('Reset entire app to 0'),
                                      style: FilledButton.styleFrom(
                                        backgroundColor:
                                            const Color(0xFFDC2626),
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
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
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
              child: const Text('Reset Day'),
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

  Future<void> _exportPdf(BuildContext context, BudgetBuddyState state,
      BudgetSummary summary) async {
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(
      const SnackBar(content: Text('Export PDF not implemented in tests.')),
    );
  }

  Future<void> _exportCsv(BuildContext context, BudgetBuddyState state) async {
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(
      const SnackBar(content: Text('Export CSV not implemented in tests.')),
    );
  }

  void _openProfileMenu(BuildContext parentContext, BudgetBuddyState state) {
    final String originalName = state.profile.displayName;
    String updatedName = originalName;
    bool isEditing = false;

    showModalBottomSheet<void>(
      context: parentContext,
      showDragHandle: false,
      isScrollControlled: true,
      builder: (BuildContext context) {
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              20,
              8,
              20,
              20 + MediaQuery.of(context).viewInsets.bottom,
            ),
            child: StatefulBuilder(
              builder: (BuildContext context, StateSetter setModalState) {
                final String normalizedName = updatedName.trim();
                final bool hasChanges = normalizedName != originalName;
                final bool canSave =
                    isEditing && normalizedName.isNotEmpty && hasChanges;

                return ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height * 0.9,
                  ),
                  child: Column(
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          IconButton(
                            onPressed: () => Navigator.of(context).pop(),
                            icon: const Icon(Icons.arrow_back_rounded),
                          ),
                          Expanded(
                            child: Text(
                              'Profile',
                              textAlign: TextAlign.center,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleLarge
                                  ?.copyWith(fontWeight: FontWeight.w800),
                            ),
                          ),
                          const SizedBox(width: 48),
                        ],
                      ),
                      Text(
                        'Edit your name',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                            ),
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        child: SingleChildScrollView(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              TextFormField(
                                initialValue: originalName,
                                enabled: isEditing,
                                textInputAction: TextInputAction.done,
                                onChanged: (String value) {
                                  setModalState(() => updatedName = value);
                                },
                                decoration: const InputDecoration(
                                  labelText: 'Name',
                                  hintText: 'Enter your name',
                                ),
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: <Widget>[
                                  Expanded(
                                    child: OutlinedButton(
                                      onPressed: () {
                                        setModalState(() {
                                          if (isEditing) {
                                            updatedName = originalName;
                                            isEditing = false;
                                            return;
                                          }
                                          isEditing = true;
                                        });
                                      },
                                      child:
                                          Text(isEditing ? 'Cancel' : 'Edit'),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: FilledButton(
                                      onPressed: canSave
                                          ? () async {
                                              final bool? confirmSave =
                                                  await showDialog<bool>(
                                                context: context,
                                                builder:
                                                    (BuildContext context) {
                                                  return AlertDialog(
                                                    title: const Text(
                                                        'Confirm Save'),
                                                    content: const Text(
                                                      'Do you want to save this name change?',
                                                    ),
                                                    actions: <Widget>[
                                                      TextButton(
                                                        onPressed: () =>
                                                            Navigator.of(
                                                                    context)
                                                                .pop(false),
                                                        child: const Text('No'),
                                                      ),
                                                      FilledButton(
                                                        onPressed: () =>
                                                            Navigator.of(
                                                                    context)
                                                                .pop(true),
                                                        child:
                                                            const Text('Yes'),
                                                      ),
                                                    ],
                                                  );
                                                },
                                              );

                                              if (confirmSave != true) {
                                                return;
                                              }

                                              ref
                                                  .read(
                                                      budgetBuddyControllerProvider
                                                          .notifier)
                                                  .updateProfile(
                                                    state.profile.copyWith(
                                                      displayName:
                                                          normalizedName,
                                                      avatarSeed:
                                                          _buildInitials(
                                                              normalizedName),
                                                    ),
                                                  );

                                              if (!context.mounted ||
                                                  !parentContext.mounted) {
                                                return;
                                              }

                                              Navigator.of(context).pop();

                                              await showDialog<void>(
                                                context: parentContext,
                                                builder:
                                                    (BuildContext context) {
                                                  return AlertDialog(
                                                    title: const Text('Saved'),
                                                    content: const Text(
                                                      'Profile name saved successfully.',
                                                    ),
                                                    actions: <Widget>[
                                                      FilledButton(
                                                        onPressed: () =>
                                                            Navigator.of(
                                                                    context)
                                                                .pop(),
                                                        child: const Text('OK'),
                                                      ),
                                                    ],
                                                  );
                                                },
                                              );
                                            }
                                          : null,
                                      child: const Text('Save'),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                'Only your name is shown in profile.',
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  String _buildInitials(String displayName) {
    final List<String> parts = displayName
        .trim()
        .split(RegExp(r'\s+'))
        .where((String part) => part.isNotEmpty)
        .toList();

    if (parts.isEmpty) {
      return 'BB';
    }

    return parts.take(2).map((String part) => part[0]).join().toUpperCase();
  }
}
