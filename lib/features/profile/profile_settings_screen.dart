// ignore_for_file: use_build_context_synchronously

import 'dart:io';
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../core/models/budget_models.dart';
import '../../core/state/app_controller.dart';
import '../../core/services/budget_service.dart';
import '../../core/widgets/budget_cards.dart';
import '../../core/services/update_service.dart';
import '../../core/widgets/update_dialog.dart';
import '../auth/auth_screen.dart';
import '../splash/splash_screen.dart';
import '../../core/widgets/budget_ai_assistant.dart';
import 'package:budgetbuddy/core/utils/alert_dialog.dart';

/// Palette defining the unified 3 primary design colors: Dark Red, Gold, and Dark Green.
class _SettingsPalette {
  const _SettingsPalette(this.isDark);

  final bool isDark;

  Color get darkRed => const Color(0xFF991B1B);
  Color get darkRedBg =>
      const Color(0xFF991B1B).withValues(alpha: isDark ? 0.20 : 0.08);
  Color get darkRedBorder => const Color(0xFF991B1B).withValues(alpha: 0.25);

  Color get gold => const Color(0xFFD97706);
  Color get goldBg =>
      const Color(0xFFD97706).withValues(alpha: isDark ? 0.20 : 0.08);
  Color get goldBorder => const Color(0xFFD97706).withValues(alpha: 0.25);

  Color get darkGreen => const Color(0xFF0F766E);
  Color get darkGreenBg =>
      const Color(0xFF0F766E).withValues(alpha: isDark ? 0.20 : 0.08);
  Color get darkGreenBorder => const Color(0xFF0F766E).withValues(alpha: 0.25);
}

class ProfileSettingsScreen extends ConsumerStatefulWidget {
  const ProfileSettingsScreen({super.key});

  @override
  ConsumerState<ProfileSettingsScreen> createState() =>
      _ProfileSettingsScreenState();
}

class _ProfileSettingsScreenState extends ConsumerState<ProfileSettingsScreen> {
  final TextEditingController _backupRestoreController =
      TextEditingController();
  final FocusNode _backupRestoreFocusNode = FocusNode();
  AppVersion? _appVersion;
  bool _isCheckingUpdate = false;

  @override
  void initState() {
    super.initState();
    _loadAppVersion();
  }

  Future<void> _loadAppVersion() async {
    final ver = await UpdateService.instance.getCurrentVersion();
    if (mounted) {
      setState(() => _appVersion = ver);
    }
  }

  Future<void> _checkForAppUpdate() async {
    if (_isCheckingUpdate) return;
    setState(() => _isCheckingUpdate = true);

    try {
      final info = await UpdateService.instance.checkForUpdate();
      if (!mounted) return;

      if (info != null && info.isUpdateAvailable) {
        showDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (BuildContext dialogContext) => UpdateDialog(
            updateInfo: info,
            currentVersion: _appVersion,
          ),
        );
      } else {
        showAppAlert(context,
          message: 'Budget Buddy is up to date! (v${_appVersion?.version ?? "1.0.0"})',
          title: 'Notice',
          icon: Icons.info_outline_rounded,
        );
      }
    } catch (e) {
      if (mounted) {
        showAppAlert(context, message: 'Failed to check for updates: $e', title: 'Notice', icon: Icons.info_outline_rounded,

        );
      }
    } finally {
      if (mounted) {
        setState(() => _isCheckingUpdate = false);
      }
    }
  }

  void _showDevUpdateModal(BuildContext context, {bool mandatory = false}) {
    final mockInfo = AppUpdateInfo(
      version: '1.2.0',
      buildNumber: 15,
      tagName: 'v1.2.0',
      title: 'Budget Buddy v1.2.0 is Available!',
      releaseNotes: '• Redesigned Settings and Preferences.\n'
          '• Reset today\'s budget to 0 at 12:00 AM.\n'
          '• Unified visual palette (Dark Red, Gold, Dark Green).\n'
          '• Fixed expense breakdown and category tracking.\n'
          '• Performance optimizations & UI polish.',
      downloadUrl:
          'https://github.com/cjaayy/Budget-Buddy/releases/download/v1.2.0/app-release.apk',
      isUpdateAvailable: true,
      fileSize: 25 * 1024 * 1024,
      mandatory: mandatory,
      publishedAt: DateTime.now(),
    );

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) => UpdateDialog(
        updateInfo: mockInfo,
        currentVersion: _appVersion ??
            const AppVersion(version: '1.0.0', buildNumber: 1),
      ),
    );
  }

  @override
  void dispose() {
    _backupRestoreController.dispose();
    _backupRestoreFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final BudgetBuddyState state = ref.watch(budgetBuddyControllerProvider);
    final BudgetSummary summary = BudgetService().computeSummary(state);
    final DateTime currentClock = state.effectiveDate;
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final _SettingsPalette palette = _SettingsPalette(isDark);

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              _buildHeader(context, currentClock),
              const SizedBox(height: 12),
              Expanded(
                child: ListView(
                  padding: EdgeInsets.zero,
                  children: <Widget>[
                    // 1. Account & Preferences Card
                    Container(
                      clipBehavior: Clip.antiAlias,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Theme.of(context).cardTheme.color ??
                            Theme.of(context).cardColor,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: Theme.of(context)
                              .colorScheme
                              .outlineVariant
                              .withValues(alpha: 0.3),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Row(
                            children: <Widget>[
                              Icon(
                                Icons.person_rounded,
                                size: 16,
                                color: palette.gold,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Account',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: Theme.of(context).colorScheme.onSurface,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          _buildSettingsTile(
                            context: context,
                            title: 'Profile',
                            subtitle: state.profile.displayName.trim().isNotEmpty &&
                                    state.profile.displayName != 'Budget Buddy'
                                ? state.profile.displayName
                                : 'Edit your profile name',
                            icon: Icons.person_outline_rounded,
                            iconColor: palette.gold,
                            iconBg: palette.goldBg,
                            iconBorder: palette.goldBorder,
                            onTap: () => _openProfileMenu(context, state),
                          ),
                          Divider(
                            height: 1,
                            color: Theme.of(context)
                                .colorScheme
                                .outlineVariant
                                .withValues(alpha: 0.2),
                          ),
                          _buildSettingsTile(
                            context: context,
                            title: 'Preferences',
                            subtitle: 'Reset to 0 and budget preferences',
                            icon: Icons.tune_rounded,
                            iconColor: palette.darkGreen,
                            iconBg: palette.darkGreenBg,
                            iconBorder: palette.darkGreenBorder,
                            onTap: () =>
                                _showPreferencesSheet(context, state, palette),
                          ),
                          Divider(
                            height: 1,
                            color: Theme.of(context)
                                .colorScheme
                                .outlineVariant
                                .withValues(alpha: 0.2),
                          ),
                          _buildSettingsTile(
                            context: context,
                            title: 'Data',
                            subtitle: 'Export, backup, reset, and clear',
                            icon: Icons.storage_rounded,
                            iconColor: palette.darkGreen,
                            iconBg: palette.darkGreenBg,
                            iconBorder: palette.darkGreenBorder,
                            onTap: () =>
                                _showDataSheet(context, state, summary),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // 2. Appearance Card
                    Container(
                      clipBehavior: Clip.antiAlias,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Theme.of(context).cardTheme.color ??
                            Theme.of(context).cardColor,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: Theme.of(context)
                              .colorScheme
                              .outlineVariant
                              .withValues(alpha: 0.3),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Row(
                            children: <Widget>[
                              Icon(
                                Icons.palette_rounded,
                                size: 16,
                                color: palette.darkGreen,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Appearance',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color:
                                      Theme.of(context).colorScheme.onSurface,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          _buildSettingsTile(
                            context: context,
                            title: 'Dark Mode',
                            subtitle: state.themeMode == ThemeMode.dark
                                ? 'Dark theme enabled'
                                : 'Light theme enabled',
                            icon: state.themeMode == ThemeMode.dark
                                ? Icons.dark_mode_rounded
                                : Icons.light_mode_rounded,
                            iconColor: palette.darkGreen,
                            iconBg: palette.darkGreenBg,
                            iconBorder: palette.darkGreenBorder,
                            trailing: Switch(
                              value: state.themeMode == ThemeMode.dark,
                              activeColor: palette.darkGreen,
                              onChanged: (bool isDark) {
                                ref
                                    .read(
                                        budgetBuddyControllerProvider.notifier)
                                    .setThemeMode(
                                      isDark
                                          ? ThemeMode.dark
                                          : ThemeMode.light,
                                    );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // 3. About & Updates Card
                    Container(
                      clipBehavior: Clip.antiAlias,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Theme.of(context).cardTheme.color ??
                            Theme.of(context).cardColor,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: Theme.of(context)
                              .colorScheme
                              .outlineVariant
                              .withValues(alpha: 0.3),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Row(
                            children: <Widget>[
                              Icon(
                                Icons.info_outline_rounded,
                                size: 16,
                                color: palette.gold,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'About & Updates',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color:
                                      Theme.of(context).colorScheme.onSurface,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          _buildSettingsTile(
                            context: context,
                            title: 'App Updates',
                            subtitle: _appVersion != null
                                ? 'Version ${_appVersion!.version} (Build ${_appVersion!.buildNumber})'
                                : 'Budget Buddy v1.0.0',
                            icon: Icons.system_update_rounded,
                            iconColor: palette.gold,
                            iconBg: palette.goldBg,
                            iconBorder: palette.goldBorder,
                            trailing: _isCheckingUpdate
                                ? const SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.5,
                                    ),
                                  )
                                : FilledButton.tonal(
                                    onPressed: _checkForAppUpdate,
                                    style: FilledButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 14,
                                        vertical: 8,
                                      ),
                                    ),
                                    child: const Text('Check'),
                                  ),
                            onTap: _checkForAppUpdate,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (kDebugMode) ...<Widget>[
                      Container(
                        clipBehavior: Clip.antiAlias,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Theme.of(context).cardTheme.color ??
                              Theme.of(context).cardColor,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: Theme.of(context)
                                .colorScheme
                                .outlineVariant
                                .withValues(alpha: 0.3),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Row(
                              children: <Widget>[
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.amber.shade900
                                        .withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    'DEBUG ONLY',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w900,
                                      color: Colors.amber.shade800,
                                      letterSpacing: 0.8,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'DEV MODE & TESTING',
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium
                                      ?.copyWith(fontWeight: FontWeight.w800),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Test midnight 12:00 AM auto-reset, clock simulation, and past day backfills.',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: <Widget>[
                                OutlinedButton.icon(
                                  onPressed: () {
                                    Navigator.of(context).push(
                                      MaterialPageRoute<void>(
                                        builder: (_) => const _DevPreviewFrame(
                                          child: AuthScreen(),
                                        ),
                                      ),
                                    );
                                  },
                                  icon: const Icon(Icons.login_rounded),
                                  label: const Text('Preview Login'),
                                ),
                                OutlinedButton.icon(
                                  onPressed: () {
                                    Navigator.of(context).push(
                                      MaterialPageRoute<void>(
                                        builder: (_) => const _DevPreviewFrame(
                                          child: SplashScreen(),
                                        ),
                                      ),
                                    );
                                  },
                                  icon: const Icon(Icons.home_rounded),
                                  label: const Text('Preview First Screen'),
                                ),
                                OutlinedButton.icon(
                                  onPressed: () =>
                                      _showDevUpdateModal(context),
                                  icon: const Icon(Icons.system_update_rounded),
                                  label: const Text('Preview Update Modal'),
                                ),
                                OutlinedButton.icon(
                                  onPressed: () => showBudsChat(context),
                                  icon: const Icon(Icons.auto_awesome_rounded),
                                  label: const Text('Open Buds AI'),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Builder(
                              builder: (BuildContext ctx) {
                                final bool isTimeSimulated =
                                    state.isTimeSimulated;
                                final DateTime currentEffectiveTime =
                                    state.effectiveDate;
                                return Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .surfaceContainerHighest,
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: Row(
                                    children: <Widget>[
                                      Icon(
                                        isTimeSimulated
                                            ? Icons.schedule_rounded
                                            : Icons.access_time_rounded,
                                        color: isTimeSimulated
                                            ? Colors.amber.shade700
                                            : Theme.of(context)
                                                .colorScheme
                                                .primary,
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: <Widget>[
                                            Text(
                                              isTimeSimulated
                                                  ? 'Simulated App Clock'
                                                  : 'Device Real Time',
                                              style: const TextStyle(
                                                  fontWeight: FontWeight.w700,
                                                  fontSize: 13),
                                            ),
                                            Text(
                                              DateFormat(
                                                      'EEE, MMM d, yyyy • h:mm:ss a')
                                                  .format(currentEffectiveTime),
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Theme.of(context)
                                                    .colorScheme
                                                    .onSurfaceVariant,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      if (isTimeSimulated)
                                        TextButton(
                                          onPressed: () async {
                                            await ref.read(budgetBuddyControllerProvider.notifier).resetSimulatedTime();
                                            setState(() {});
                                            if (context.mounted) {
                                              showAppAlert(
                                                context,
                                                message:
                                                    'Reverted to device real time.',
                                                title: 'Real Time Restored',
                                                accentColor:
                                                    const Color(0xFF0F766E),
                                                icon: Icons
                                                    .check_circle_outline_rounded,
                                              );
                                            }
                                          },
                                          child: const Text('Reset'),
                                        ),
                                    ],
                                  ),
                                );
                              },
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: Theme.of(context)
                                    .colorScheme
                                    .surfaceContainerHighest
                                    .withValues(alpha: 0.6),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .outlineVariant
                                      .withValues(alpha: 0.5),
                                ),
                              ),
                              child: Column(
                                children: <Widget>[
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: <Widget>[
                                      Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: <Widget>[
                                          Text(
                                            'Today\'s Budget Limit',
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .onSurfaceVariant,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            state.settings.dailyLimit != null
                                                ? '₱${state.settings.dailyLimit!.toStringAsFixed(0)}'
                                                : '₱0 (Reset / Unset)',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 14,
                                              color:
                                                  state.settings.dailyLimit !=
                                                          null
                                                      ? const Color(0xFF0F766E)
                                                      : Colors.grey,
                                            ),
                                          ),
                                        ],
                                      ),
                                      Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.end,
                                        children: <Widget>[
                                          Text(
                                            'Today\'s Spent',
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .onSurfaceVariant,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            '₱${state.dailySpent.toStringAsFixed(0)}',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 14,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: <Widget>[
                                      Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: <Widget>[
                                          const Text(
                                            'Savings Debt',
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: Color(0xFF991B1B),
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            '₱${state.savingsDebt.toStringAsFixed(0)}',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 14,
                                              color: state.savingsDebt > 0
                                                  ? const Color(0xFF991B1B)
                                                  : Colors.grey,
                                            ),
                                          ),
                                        ],
                                      ),
                                      Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.end,
                                        children: <Widget>[
                                          const Text(
                                            'Total Savings',
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: Color(0xFFD97706),
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            '₱${state.totalSavings.toStringAsFixed(0)}',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 14,
                                              color: state.totalSavings > 0
                                                  ? const Color(0xFFD97706)
                                                  : Colors.grey,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                            FilledButton.icon(
                              onPressed: () async {
                                await ref
                                    .read(
                                        budgetBuddyControllerProvider.notifier)
                                    .simulateMidnightReset();
                                setState(() {});
                                if (context.mounted) {
                                  showAppAlert(context, message: 'Simulated 12:00 AM! Today\'s active budget & expenses have reset.', title: 'Alert', icon: Icons.warning_amber_rounded,

                                    accentColor: Color(0xFF0F766E),

                                  );
                                }
                              },
                              icon:
                                  const Icon(Icons.nightlight_round, size: 18),
                              label:
                                  const Text('Click 12:00 AM Midnight Reset'),
                              style: FilledButton.styleFrom(
                                minimumSize: const Size.fromHeight(44),
                                backgroundColor: const Color(0xFF0F766E),
                                foregroundColor: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: <Widget>[
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: () => _pickDevTimeOnly(context),
                                    icon: const Icon(Icons.access_time_rounded,
                                        size: 16),
                                    label: const Text('Set Time (12 AM)'),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: () =>
                                        _pickDevSimulatedTime(context),
                                    icon: const Icon(
                                        Icons.edit_calendar_rounded,
                                        size: 16),
                                    label: const Text('Set Date & Time'),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: <Widget>[
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: () async {
                                      await ref
                                          .read(budgetBuddyControllerProvider
                                              .notifier)
                                          .setSimulatedTimeTo1159PM();
                                      setState(() {});
                                      if (context.mounted) {
                                        showAppAlert(
                                          context,
                                          message:
                                              'Time set to 11:59 PM (1 min before midnight).',
                                          title: 'Time Simulation',
                                          accentColor: const Color(0xFFD97706),
                                          icon: Icons.bedtime_outlined,
                                        );
                                      }
                                    },
                                    icon: const Icon(Icons.bedtime_outlined,
                                        size: 16),
                                    label: const Text('Set 11:59 PM'),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: () async {
                                      await ref
                                          .read(budgetBuddyControllerProvider
                                              .notifier)
                                          .fastForwardOneDay();
                                      setState(() {});
                                      if (context.mounted) {
                                        showAppAlert(
                                          context,
                                          message:
                                              'Fast-forwarded +1 day past midnight.',
                                          title: 'Time Simulation',
                                          accentColor: const Color(0xFFD97706),
                                          icon: Icons.fast_forward_rounded,
                                        );
                                      }
                                    },
                                    icon: const Icon(Icons.fast_forward_rounded,
                                        size: 16),
                                    label: const Text('+1 Day (12 AM)'),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    Container(
                      clipBehavior: Clip.antiAlias,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Theme.of(context).cardTheme.color ??
                            Theme.of(context).cardColor,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: Theme.of(context)
                              .colorScheme
                              .outlineVariant
                              .withValues(alpha: 0.3),
                        ),
                      ),
                      child: _buildSettingsTile(
                        context: context,
                        title: 'Logout',
                        subtitle: 'Sign out of your account',
                        icon: Icons.logout_rounded,
                        iconColor: palette.darkRed,
                        iconBg: palette.darkRedBg,
                        iconBorder: palette.darkRedBorder,
                        onTap: () => _confirmLogout(context),
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

  /// Compact Header matching app design language
  Widget _buildHeader(BuildContext context, DateTime currentClock) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'Settings',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
              ),
        ),
        const SizedBox(height: 2),
        Text(
          DateFormat('EEEE, MMM d').format(currentClock),
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w500,
              ),
        ),
      ],
    );
  }

  /// Clean settings tile with badge icon, bold title, subtitle, and chevron
  Widget _buildSettingsTile({
    required BuildContext context,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    required Color iconBorder,
    VoidCallback? onTap,
    Widget? trailing,
  }) {
    final ThemeData theme = Theme.of(context);
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
        child: Row(
          children: <Widget>[
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: iconBorder),
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            if (trailing != null)
              trailing
            else if (onTap != null)
              Icon(
                Icons.chevron_right_rounded,
                size: 22,
                color: theme.colorScheme.onSurfaceVariant,
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickDevTimeOnly(BuildContext context) async {
    final devController = ref.read(budgetBuddyControllerProvider.notifier);
    final DateTime initialDate = devController.currentEffectiveTime;
    final TimeOfDay initialTime = TimeOfDay.fromDateTime(initialDate);

    final TimeOfDay? pickedTime = await showTimePicker(
      context: context,
      initialTime: initialTime,
      helpText: 'Select Simulated Time (e.g. 12:00 AM)',
    );

    if (pickedTime == null || !context.mounted) {
      return;
    }

    final int hour = pickedTime.hour;
    final int minute = pickedTime.minute;

    DateTime newSimulatedTime = DateTime(
      initialDate.year,
      initialDate.month,
      initialDate.day,
      hour,
      minute,
    );

    // If 12:00 AM midnight is selected, advance date to next day's 12:00 AM
    // so it tests the midnight rollover that resets today's budget.
    if (hour == 0 && minute == 0) {
      newSimulatedTime = DateTime(
        initialDate.year,
        initialDate.month,
        initialDate.day + 1,
        0,
        0,
      );
    }

    await devController.setSimulatedDateTime(newSimulatedTime);
    setState(() {});

    if (context.mounted) {
      showAppAlert(context,
        message: hour == 0 && minute == 0
                ? 'Time set to 12:00 AM midnight! Today\'s active budget has reset.'
                : 'Simulated time set to: ${DateFormat('h:mm a').format(newSimulatedTime)}',
        title: 'Success',
        icon: Icons.check_circle_outline_rounded,
        accentColor: const Color(0xFF0F766E),
      );
    }
  }

  Future<void> _pickDevSimulatedTime(BuildContext context) async {
    final devController = ref.read(budgetBuddyControllerProvider.notifier);
    final DateTime initialDate = devController.currentEffectiveTime;

    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      helpText: 'Select Simulated Date',
    );

    if (pickedDate == null || !context.mounted) {
      return;
    }

    final TimeOfDay initialTime = TimeOfDay.fromDateTime(initialDate);
    final TimeOfDay? pickedTime = await showTimePicker(
      context: context,
      initialTime: initialTime,
      helpText: 'Select Simulated Time (e.g. 12:00 AM)',
    );

    if (!context.mounted) {
      return;
    }

    final int hour = pickedTime?.hour ?? 0;
    final int minute = pickedTime?.minute ?? 0;

    DateTime newSimulatedTime = DateTime(
      pickedDate.year,
      pickedDate.month,
      pickedDate.day,
      hour,
      minute,
    );

    final bool isCurrentDay = pickedDate.year == initialDate.year &&
        pickedDate.month == initialDate.month &&
        pickedDate.day == initialDate.day;

    if (isCurrentDay && hour == 0 && minute == 0) {
      newSimulatedTime = DateTime(
        pickedDate.year,
        pickedDate.month,
        pickedDate.day + 1,
        0,
        0,
      );
    }

    await devController.setSimulatedDateTime(newSimulatedTime);
    setState(() {});

    if (context.mounted) {
      showAppAlert(context,
        message: 'Simulated time set to: ${DateFormat('MMM d, yyyy • h:mm a').format(newSimulatedTime)}',
        title: 'Success',
        icon: Icons.check_circle_outline_rounded,
        accentColor: const Color(0xFF0F766E),
      );
    }
  }

  void _showPreferencesSheet(
    BuildContext parentContext,
    BudgetBuddyState state,
    _SettingsPalette palette,
  ) {
    showModalBottomSheet<void>(
      context: parentContext,
      showDragHandle: false,
      isScrollControlled: true,
      builder: (BuildContext context) {
        final ThemeData theme = Theme.of(context);
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              20,
              12,
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
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      // Modal Header with solid green back button
                      Row(
                        children: <Widget>[
                          FilledButton.icon(
                            onPressed: () => Navigator.of(context).pop(),
                            icon:
                                const Icon(Icons.arrow_back_rounded, size: 16),
                            label: const Text(
                              'Back',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                            ),
                            style: FilledButton.styleFrom(
                              backgroundColor: palette.darkGreen,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                          Expanded(
                            child: Text(
                              'Preferences',
                              textAlign: TextAlign.center,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          const SizedBox(width: 64),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Reset to 0 Preference Tile Container
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest
                              .withValues(alpha: 0.35),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: theme.colorScheme.outlineVariant
                                .withValues(alpha: 0.25),
                          ),
                        ),
                        child: Row(
                          children: <Widget>[
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: palette.darkGreenBg,
                                shape: BoxShape.circle,
                                border:
                                    Border.all(color: palette.darkGreenBorder),
                              ),
                              child: Icon(
                                Icons.restart_alt_rounded,
                                color: palette.darkGreen,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  const Text(
                                    'Reset to 0',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    "Reset today's budget to 0 at 12:00 AM",
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Switch(
                              value: settings.notifyOnDailyReset,
                              activeColor: palette.darkGreen,
                              onChanged: (bool value) {
                                modalRef
                                    .read(
                                        budgetBuddyControllerProvider.notifier)
                                    .updateProfilePreferences(
                                      notifyOnDailyReset: value,
                                    );
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
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

    final String jsonText = state.encode();

    final String? choice = await showModalBottomSheet<String>(
      context: context,
      builder: (BuildContext context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const Icon(
                  Icons.cloud_upload_rounded,
                  size: 40,
                  color: Color(0xFF2563EB),
                ),
                const SizedBox(height: 8),
                Text(
                  'Back Up Data Snapshot',
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                ListTile(
                  leading: const Icon(Icons.download_rounded),
                  title: const Text('Download'),
                  subtitle: const Text('Save JSON to device Downloads'),
                  onTap: () => Navigator.of(context).pop('download'),
                ),
                ListTile(
                  leading: const Icon(Icons.share_rounded),
                  title: const Text('Share'),
                  subtitle: const Text('Share via other apps'),
                  onTap: () => Navigator.of(context).pop('share'),
                ),
                ListTile(
                  leading: const Icon(Icons.copy_all_rounded),
                  title: const Text('Copy JSON'),
                  subtitle: const Text('Copy backup JSON to clipboard'),
                  onTap: () => Navigator.of(context).pop('copy'),
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF991B1B),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Cancel'),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (choice == null) return;

    if (choice == 'download') {
      try {
        final String filename =
            'BudgetBuddy_Backup_${DateTime.now().millisecondsSinceEpoch}.json';
        const MethodChannel channel = MethodChannel('budgetbuddy/storage');
        final String? saveResult = await channel.invokeMethod<String?>(
          'saveToDownloads',
          <String, dynamic>{
            'sourcePath': file.path,
            'fileName': filename,
            'mimeType': 'application/json',
          },
        );

        final String displayPath =
            saveResult ?? '/storage/emulated/0/Download/$filename';
        if (!mounted) return;
        await _showDownloadedModal(context,
            displayPath: displayPath, label: 'Backup JSON');
        return;
      } catch (e) {
        debugPrint('Backup save error: $e');
        if (!mounted) return;
        showAppAlert(context,
          message: 'Could not save backup to Downloads.',
          title: 'Notice',
          icon: Icons.info_outline_rounded,
        );
      }
    }

    if (choice == 'share') {
      await Share.shareXFiles(<XFile>[XFile(file.path)],
          text: 'BudgetBuddy backup snapshot');
      return;
    }

    if (choice == 'copy') {
      await Clipboard.setData(ClipboardData(text: jsonText));
      if (!mounted) return;
      showAppAlert(context,
        message: 'Backup JSON copied to clipboard.',
        title: 'Notice',
        icon: Icons.info_outline_rounded,
      );
      return;
    }
  }

  Future<void> _restoreSnapshot(BuildContext context) async {
    final String? action = await showModalBottomSheet<String>(
      context: context,
      builder: (BuildContext context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const Icon(
                  Icons.cloud_download_rounded,
                  size: 44,
                  color: Color(0xFF2563EB),
                ),
                const SizedBox(height: 12),
                Text(
                  'Restore Backup Data',
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Choose how to restore your expenses, savings, and Budget Together data:',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => Navigator.of(context).pop('paste'),
                        icon: const Icon(Icons.content_paste_rounded),
                        label: const Text('Paste JSON'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () => Navigator.of(context).pop('file'),
                        icon: const Icon(Icons.folder_open_rounded),
                        label: const Text('Select File'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF991B1B),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (action == null || !mounted) return;

    String? jsonText;

    if (action == 'file') {
      try {
        const MethodChannel channel = MethodChannel('budgetbuddy/storage');
        jsonText = await channel.invokeMethod<String?>('pickJson');
      } catch (e) {
        debugPrint('Native pick error: $e');
        if (!mounted) return;
        showAppAlert(
          context,
          message: 'Could not open file: $e',
          title: 'Import Error',
          accentColor: const Color(0xFF991B1B),
          icon: Icons.error_outline_rounded,
        );
        return;
      }
    } else if (action == 'paste') {
      jsonText = await showDialog<String>(
        context: context,
        builder: (BuildContext context) => const _PasteJsonDialog(),
      );
    }

    if (jsonText == null || jsonText.trim().isEmpty || !mounted) return;

    try {
      final String rawText = jsonText.trim();
      final BudgetBuddyState snapshot = BudgetBuddyState.decode(rawText);
      ref
          .read(budgetBuddyControllerProvider.notifier)
          .restoreSnapshot(snapshot);
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (BuildContext dialogContext) {
          return AlertDialog(
            icon: const Icon(
              Icons.check_circle_rounded,
              color: Color(0xFF16A34A),
              size: 48,
            ),
            title: const Text('Restore Complete'),
            content: const Text(
              'Expenses, Savings (daily/monthly), and Budget Together data have been restored successfully.',
              textAlign: TextAlign.center,
            ),
            actions: <Widget>[
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('OK'),
              ),
            ],
          );
        },
      );
    } catch (e) {
      debugPrint('Restore JSON decode error: $e');
      if (!mounted) return;
      showAppAlert(
        context,
        message: 'Could not restore backup: $e',
        title: 'Restore Failed',
        accentColor: const Color(0xFF991B1B),
        icon: Icons.error_outline_rounded,
      );
    }
  }

  Future<void> _confirmResetApp(BuildContext context) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => const _ResetAppDialog(),
    );

    if (!mounted || confirm != true) {
      return;
    }

    FocusManager.instance.primaryFocus?.unfocus();
    await Future<void>.delayed(const Duration(milliseconds: 150));

    if (!mounted) {
      return;
    }

    await ref.read(budgetBuddyControllerProvider.notifier).resetApp();
    if (!mounted) {
      return;
    }

    await showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          icon: const Icon(
            Icons.check_circle_rounded,
            color: Color(0xFF16A34A),
            size: 48,
          ),
          title: const Text('Reset Complete'),
          content: const Text(
            'App data has been reset to zero successfully.',
            textAlign: TextAlign.center,
          ),
          actions: <Widget>[
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _exportPdf(BuildContext context, BudgetBuddyState state,
      BudgetSummary summary) async {
    final String? choice = await showModalBottomSheet<String>(
      context: context,
      builder: (BuildContext context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const Icon(
                  Icons.picture_as_pdf_rounded,
                  size: 40,
                  color: Color(0xFFDC2626),
                ),
                const SizedBox(height: 8),
                Text(
                  'Export PDF Report',
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                ListTile(
                  leading: const Icon(Icons.download_rounded),
                  title: const Text('Download'),
                  subtitle: const Text('Save PDF report to device Downloads'),
                  onTap: () => Navigator.of(context).pop('download'),
                ),
                ListTile(
                  leading: const Icon(Icons.share_rounded),
                  title: const Text('Share'),
                  subtitle: const Text('Share via other apps'),
                  onTap: () => Navigator.of(context).pop('share'),
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF991B1B),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Cancel'),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (choice == null) {
      return;
    }

    try {
      final File file = await ref.read(reportServiceProvider).exportDailyReport(
            state: state,
            summary: summary,
          );

      if (choice == 'download') {
        try {
          final String filename =
              'BudgetBuddy_Report_${DateTime.now().millisecondsSinceEpoch}.pdf';

          // Use native MethodChannel to save via MediaStore
          const MethodChannel channel = MethodChannel('budgetbuddy/storage');
          final String? saveResult = await channel.invokeMethod<String?>(
            'saveToDownloads',
            <String, dynamic>{
              'sourcePath': file.path,
              'fileName': filename,
              'mimeType': 'application/pdf',
            },
          );

          if (!context.mounted) return;
          final String displayPath =
              saveResult ?? '/storage/emulated/0/Download/$filename';
          await _showDownloadedModal(
            context,
            displayPath: displayPath,
            label: 'PDF report',
          );
          return;
        } catch (e, st) {
          debugPrint('Save error: $e');
          debugPrintStack(stackTrace: st);
          if (!context.mounted) return;
          final bool? share = await showDialog<bool>(
            context: context,
            builder: (BuildContext context) {
              return AlertDialog(
                title: const Text('Save failed'),
                content: SingleChildScrollView(
                  child: Text(e.toString()),
                ),
                actions: <Widget>[
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: const Text('Close'),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    child: const Text('Share'),
                  ),
                ],
              );
            },
          );

          if (share == true) {
            await Share.shareXFiles(
              <XFile>[XFile(file.path)],
              text: 'BudgetBuddy PDF report',
            );
            if (!context.mounted) return;
            showAppAlert(context,
              message: 'PDF report shared successfully.',
              title: 'Notice',
              icon: Icons.info_outline_rounded,
            );
          }
          return;
        }
      }

      if (choice == 'share') {
        await Share.shareXFiles(
          <XFile>[XFile(file.path)],
          text: 'BudgetBuddy PDF report',
        );
        if (!mounted) return;
        showAppAlert(context,
          message: 'PDF report shared successfully.',
          title: 'Notice',
          icon: Icons.info_outline_rounded,
        );
        return;
      }
    } catch (_) {
      if (!context.mounted) return;
      showAppAlert(context,
        message: 'Could not export PDF report.',
        title: 'Notice',
        icon: Icons.info_outline_rounded,
      );
    }
  }

  Future<void> _exportCsv(BuildContext context, BudgetBuddyState state) async {
    final String? choice = await showModalBottomSheet<String>(
      context: context,
      builder: (BuildContext context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const Icon(
                  Icons.table_chart_rounded,
                  size: 40,
                  color: Color(0xFF16A34A),
                ),
                const SizedBox(height: 8),
                Text(
                  'Export CSV Data',
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                ListTile(
                  leading: const Icon(Icons.download_rounded),
                  title: const Text('Download'),
                  subtitle: const Text('Save CSV to device Downloads'),
                  onTap: () => Navigator.of(context).pop('download'),
                ),
                ListTile(
                  leading: const Icon(Icons.share_rounded),
                  title: const Text('Share'),
                  subtitle: const Text('Share via other apps'),
                  onTap: () => Navigator.of(context).pop('share'),
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF991B1B),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Cancel'),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (choice == null) return;

    try {
      final File file = await ref.read(reportServiceProvider).exportCsv(
            state: state,
          );

      if (choice == 'download') {
        try {
          final String filename =
              'BudgetBuddy_Export_${DateTime.now().millisecondsSinceEpoch}.csv';

          // Use native MethodChannel to save via MediaStore
          const MethodChannel channel = MethodChannel('budgetbuddy/storage');
          final String? saveResult = await channel.invokeMethod<String?>(
            'saveToDownloads',
            <String, dynamic>{
              'sourcePath': file.path,
              'fileName': filename,
              'mimeType': 'text/csv',
            },
          );

          if (!context.mounted) return;
          final String displayPath =
              saveResult ?? '/storage/emulated/0/Download/$filename';
          await _showDownloadedModal(
            context,
            displayPath: displayPath,
            label: 'CSV file',
          );
          return;
        } catch (e, st) {
          debugPrint('Save error: $e');
          debugPrintStack(stackTrace: st);
          if (!context.mounted) return;
          final bool? share = await showDialog<bool>(
            context: context,
            builder: (BuildContext context) {
              return AlertDialog(
                title: const Text('Save failed'),
                content: SingleChildScrollView(
                  child: Text(e.toString()),
                ),
                actions: <Widget>[
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: const Text('Close'),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    child: const Text('Share'),
                  ),
                ],
              );
            },
          );

          if (share == true) {
            await Share.shareXFiles(
              <XFile>[XFile(file.path)],
              text: 'BudgetBuddy CSV export',
            );
            if (!context.mounted) return;
            showAppAlert(context,
              message: 'CSV shared successfully.',
              title: 'Notice',
              icon: Icons.info_outline_rounded,
            );
          }
          return;
        }
      }

      if (choice == 'share') {
        await Share.shareXFiles(
          <XFile>[XFile(file.path)],
          text: 'BudgetBuddy CSV export',
        );
        if (!mounted) return;
        showAppAlert(context,
          message: 'CSV shared successfully.',
          title: 'Notice',
          icon: Icons.info_outline_rounded,
        );
        return;
      }
    } catch (_) {
      if (!mounted) return;
      showAppAlert(context,
        message: 'Could not export CSV file.',
        title: 'Notice',
        icon: Icons.info_outline_rounded,
      );
    }
  }

  Future<void> _showDownloadedModal(BuildContext context,
      {required String displayPath, required String label}) async {
    final String path = displayPath;
    await showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('$label saved'),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Text('Saved to:'),
                const SizedBox(height: 8),
                SelectableText(path),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: path));
                Navigator.of(context).pop();
                showAppAlert(context,
                  message: 'Path copied to clipboard.',
                  title: 'Notice',
                  icon: Icons.info_outline_rounded,
                );
              },
              child: const Text('Copy path'),
            ),
            const SizedBox.shrink(),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _confirmLogout(BuildContext context) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Logout?'),
          content:
              const Text('Are you sure you want to sign out of your account?'),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF991B1B),
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Logout'),
            ),
          ],
        );
      },
    );

    if (!mounted || confirm != true) {
      return;
    }

    ref.read(budgetBuddyControllerProvider.notifier).logout();
    if (!mounted) {
      return;
    }
    showAppAlert(context,
      message: 'Logged out.',
      title: 'Notice',
      icon: Icons.info_outline_rounded,
    );
  }

  void _openProfileMenu(BuildContext parentContext, BudgetBuddyState state) {
    final String originalName = state.profile.displayName;
    final bool hasCustomName =
        originalName.trim().isNotEmpty && originalName != 'Budget Buddy';
    String updatedName = originalName;
    bool isEditing = !hasCustomName;

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
                final bool canSave = normalizedName.isNotEmpty &&
                    (!hasCustomName || (isEditing && hasChanges));

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
                                enabled: isEditing || !hasCustomName,
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
                              if (!hasCustomName && !isEditing) ...<Widget>[
                                SizedBox(
                                  width: double.infinity,
                                  child: FilledButton.icon(
                                    onPressed: canSave
                                        ? () async {
                                            ref
                                                .read(
                                                    budgetBuddyControllerProvider
                                                        .notifier)
                                                .updateProfile(
                                                  state.profile.copyWith(
                                                    displayName: normalizedName,
                                                    avatarSeed: _buildInitials(
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
                                              builder: (BuildContext context) {
                                                return AlertDialog(
                                                  title: const Text('Saved'),
                                                  content: const Text(
                                                    'Profile name saved successfully.',
                                                  ),
                                                  actions: <Widget>[
                                                    FilledButton(
                                                      onPressed: () =>
                                                          Navigator.of(context)
                                                              .pop(),
                                                      child: const Text('OK'),
                                                    ),
                                                  ],
                                                );
                                              },
                                            );
                                          }
                                        : null,
                                    icon:
                                        const Icon(Icons.check_circle_rounded),
                                    label: const Text('Save Name'),
                                  ),
                                ),
                              ] else if (hasCustomName &&
                                  !isEditing) ...<Widget>[
                                SizedBox(
                                  width: double.infinity,
                                  child: FilledButton.icon(
                                    style: FilledButton.styleFrom(
                                      backgroundColor: const Color(0xFFD97706),
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 12),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      elevation: 0,
                                    ),
                                    onPressed: () {
                                      setModalState(() {
                                        isEditing = true;
                                      });
                                    },
                                    icon: const Icon(Icons.edit_rounded,
                                        size: 16),
                                    label: const Text(
                                      'Edit Name',
                                      style: TextStyle(
                                          fontWeight: FontWeight.w700),
                                    ),
                                  ),
                                ),
                              ] else ...<Widget>[
                                Row(
                                  children: <Widget>[
                                    Expanded(
                                      child: FilledButton.icon(
                                        style: FilledButton.styleFrom(
                                          backgroundColor:
                                              const Color(0xFF991B1B),
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(
                                              vertical: 12),
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(12),
                                          ),
                                          elevation: 0,
                                        ),
                                        onPressed: () {
                                          setModalState(() {
                                            updatedName = originalName;
                                            isEditing = false;
                                          });
                                        },
                                        icon: const Icon(Icons.close_rounded,
                                            size: 16),
                                        label: const Text(
                                          'Cancel',
                                          style: TextStyle(
                                              fontWeight: FontWeight.w700),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: FilledButton.icon(
                                        style: FilledButton.styleFrom(
                                          backgroundColor:
                                              const Color(0xFF0F766E),
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(
                                              vertical: 12),
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(12),
                                          ),
                                          elevation: 0,
                                        ),
                                        icon: const Icon(Icons.save_rounded,
                                            size: 16),
                                        label: const Text(
                                          'Save',
                                          style: TextStyle(
                                              fontWeight: FontWeight.w700),
                                        ),
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
                                                          child:
                                                              const Text('No'),
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
                                                      title:
                                                          const Text('Saved'),
                                                      content: const Text(
                                                        'Profile name saved successfully.',
                                                      ),
                                                      actions: <Widget>[
                                                        FilledButton(
                                                          onPressed: () =>
                                                              Navigator.of(
                                                                      context)
                                                                  .pop(),
                                                          child:
                                                              const Text('OK'),
                                                        ),
                                                      ],
                                                    );
                                                  },
                                                );
                                              }
                                            : null,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
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

class _DevPreviewFrame extends StatelessWidget {
  const _DevPreviewFrame({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: <Widget>[
        child,
        Positioned(
          top: 8,
          left: 12,
          child: SafeArea(
            child: Material(
              color: Colors.black54,
              shape: const CircleBorder(),
              child: IconButton(
                tooltip: 'Back to Dev Mode',
                onPressed: () {
                  final NavigatorState navigator = Navigator.of(context);
                  if (navigator.canPop()) {
                    navigator.maybePop();
                  }
                },
                icon: const Icon(Icons.arrow_back_rounded),
                color: Colors.white,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ResetAppDialog extends StatefulWidget {
  const _ResetAppDialog();

  @override
  State<_ResetAppDialog> createState() => _ResetAppDialogState();
}

class _ResetAppDialogState extends State<_ResetAppDialog> {
  late final TextEditingController _confirmationController;
  int _secondsRemaining = 5;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _confirmationController = TextEditingController();
    _timer = Timer.periodic(const Duration(seconds: 1), (Timer timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_secondsRemaining <= 1) {
        timer.cancel();
        setState(() {
          _secondsRemaining = 0;
        });
        // Do not auto-confirm when timer finishes
      } else {
        setState(() {
          _secondsRemaining--;
        });
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _confirmationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isTimerDone = _secondsRemaining == 0;
    return AlertDialog(
      title: const Text('Reset entire app to 0?'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Text(
              'This will reset the entire app to zero (no one left as in zero). All budgets, expenses, spending records, savings, debts, and daily logs will be set to 0. Type RESET to continue.',
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _confirmationController,
              decoration: const InputDecoration(labelText: 'Type RESET'),
            ),
          ],
        ),
      ),
      actions: <Widget>[
        FilledButton(
          onPressed: () => Navigator.of(context).pop(false),
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF991B1B),
            foregroundColor: Colors.white,
          ),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            if (_confirmationController.text.trim().toUpperCase() == 'RESET') {
              Navigator.of(context).pop(true);
            }
          },
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFFDC2626),
            foregroundColor: Colors.white,
          ),
          child: Text(
            isTimerDone
                ? 'Reset All to 0'
                : 'Reset All to 0 (${_secondsRemaining}s)',
          ),
        ),
      ],
    );
  }
}

class _PasteJsonDialog extends StatefulWidget {
  const _PasteJsonDialog();

  @override
  State<_PasteJsonDialog> createState() => _PasteJsonDialogState();
}

class _PasteJsonDialogState extends State<_PasteJsonDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    _tryAutoPaste();
  }

  Future<void> _tryAutoPaste() async {
    final ClipboardData? clip = await Clipboard.getData(Clipboard.kTextPlain);
    if (clip?.text != null && clip!.text!.trim().startsWith('{')) {
      if (mounted) {
        setState(() {
          _controller.text = clip.text!.trim();
        });
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Paste JSON Backup'),
      content: SingleChildScrollView(
        child: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () async {
                    final ClipboardData? clip =
                        await Clipboard.getData(Clipboard.kTextPlain);
                    if (clip?.text != null) {
                      _controller.text = clip!.text!.trim();
                    }
                  },
                  icon: const Icon(Icons.content_paste_rounded, size: 18),
                  label: const Text('Paste Clipboard'),
                ),
              ),
              const SizedBox(height: 4),
              TextField(
                controller: _controller,
                maxLines: 8,
                decoration: const InputDecoration(
                  labelText: 'Paste JSON text here',
                  alignLabelWithHint: true,
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: <Widget>[
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF991B1B),
            foregroundColor: Colors.white,
          ),
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF0F766E),
            foregroundColor: Colors.white,
          ),
          onPressed: () {
            if (_controller.text.trim().isNotEmpty) {
              Navigator.of(context).pop(_controller.text.trim());
            }
          },
          child: const Text('Restore'),
        ),
      ],
    );
  }
}






