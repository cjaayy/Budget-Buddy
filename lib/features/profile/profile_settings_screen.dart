// ignore_for_file: use_build_context_synchronously

import 'dart:io';
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../core/models/budget_models.dart';
import '../../core/state/app_controller.dart';
import '../../core/services/budget_service.dart';
import '../../core/services/update_service.dart';
import '../../core/widgets/update_dialog.dart';
import '../auth/auth_screen.dart';
import '../splash/splash_screen.dart';
import '../../core/widgets/budget_ai_assistant.dart';
import 'package:budgetbuddy/core/utils/alert_dialog.dart';

/// Palette defining the unified design tokens for Settings & Profile.
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

  Color get scaffoldBg =>
      isDark ? const Color(0xFF0B1120) : const Color(0xFFF8FAFC);
  Color get cardBg =>
      isDark ? const Color(0xFF111827) : const Color(0xFFFFFFFF);
  Color get borderColor =>
      isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0);
  Color get segmentBg =>
      isDark ? const Color(0xFF0B1120) : const Color(0xFFF1F5F9);
}

class ProfileSettingsScreen extends ConsumerStatefulWidget {
  const ProfileSettingsScreen({super.key});

  @override
  ConsumerState<ProfileSettingsScreen> createState() =>
      _ProfileSettingsScreenState();
}

class _ProfileSettingsScreenState extends ConsumerState<ProfileSettingsScreen> {
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
        showAppAlert(
          context,
          message:
              'Budget Buddy is up to date! (v${_appVersion?.version ?? "1.0.0"})',
          title: 'Notice',
          icon: Icons.info_outline_rounded,
          accentColor: const Color(0xFF0F766E),
        );
      }
    } catch (e) {
      if (mounted) {
        showAppAlert(
          context,
          message: 'Failed to check for updates: $e',
          title: 'Notice',
          icon: Icons.info_outline_rounded,
          accentColor: const Color(0xFF991B1B),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isCheckingUpdate = false);
      }
    }
  }

  void _showDevUpdateModal(BuildContext context, {bool mandatory = false}) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog<void>(
      context: context,
      barrierDismissible: !mandatory,
      builder: (BuildContext dialogContext) => CenterUpdateDialog(
        isDark: isDark,
        isMandatory: mandatory,
        currentVersion: _appVersion?.version ?? '1.0.0',
        newVersion: '1.2.0',
        releaseNotes: const <String>[
          'Clean Flat Bento Minimalist UI across all modules',
          '7-Core bottom dock with density label optimization',
          '100% Offline database & instant local verification',
          'Daily midnight 12:00 AM auto-reset calculation engine',
        ],
        onUpdateNow: () {
          Navigator.of(dialogContext).pop();
          showAppAlert(
            context,
            message: 'Update download for v1.2.0 initiated.',
            title: 'Update Triggered',
            icon: Icons.download_done_rounded,
            accentColor: const Color(0xFF0F766E),
          );
        },
        onBack: () => Navigator.of(dialogContext).pop(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final BudgetBuddyState state = ref.watch(budgetBuddyControllerProvider);
    final BudgetSummary summary = BudgetService().computeSummary(state);
    final DateTime currentClock = state.effectiveDate;
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final _SettingsPalette palette = _SettingsPalette(isDark);

    return Scaffold(
      backgroundColor: palette.scaffoldBg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              _buildTopBar(context, currentClock),
              const SizedBox(height: 14),
              Expanded(
                child: ListView(
                  padding: EdgeInsets.zero,
                  children: <Widget>[
                    // 1. Header Bento Card (App Identity & Offline Status)
                    _buildHeaderBentoCard(context, state, palette),
                    const SizedBox(height: 14),

                    // 2. Appearance & Theme Preferences
                    _buildAppearanceBentoCard(context, state, palette),
                    const SizedBox(height: 14),

                    // 3. Financial & Budget Defaults
                    _buildFinancialDefaultsBentoCard(context, state, palette),
                    const SizedBox(height: 14),

                    // 4. Local Data & Privacy Management
                    _buildLocalDataBentoCard(
                        context, state, summary, palette),
                    const SizedBox(height: 14),

                    // 5. App Info, Licenses & Account Actions
                    _buildAppInfoBentoCard(context, palette),
                    const SizedBox(height: 14),

                    // 6. Developer Mode & Diagnostics (Debug mode only)
                    if (kDebugMode) ...<Widget>[
                      _buildDevTestingBentoCard(context, state, palette),
                      const SizedBox(height: 14),
                    ],

                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar(BuildContext context, DateTime currentClock) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'Settings & Profile',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          DateFormat('EEEE, MMMM d, yyyy').format(currentClock),
          style: GoogleFonts.plusJakartaSans(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  // 1. Header Bento Card (App Identity & Offline Status)
  Widget _buildHeaderBentoCard(
    BuildContext context,
    BudgetBuddyState state,
    _SettingsPalette palette,
  ) {
    final String name = state.profile.displayName.trim().isNotEmpty &&
            state.profile.displayName != 'Budget Buddy'
        ? state.profile.displayName.trim()
        : 'Budget Buddy';
    final String initials = _buildInitials(name);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: palette.cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: palette.borderColor, width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              // App / User Logo Badge
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: palette.darkGreen,
                  borderRadius: BorderRadius.circular(14),
                ),
                alignment: Alignment.center,
                child: Text(
                  initials,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      name,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Budget Buddy • Offline Personal Finance',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w500,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              // Edit Profile Button (Solid Gold #D97706)
              FilledButton.icon(
                onPressed: () => _openProfileMenu(context, state),
                icon: const Icon(Icons.edit_rounded, size: 14),
                label: Text(
                  'Edit',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: palette.gold,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  elevation: 0,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // 100% Offline Data Badge Capsule
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: palette.darkGreenBg,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: palette.darkGreenBorder, width: 1),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: palette.darkGreen,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '100% OFFLINE & PRIVATE • ZERO CLOUD SYNC',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.6,
                    color: palette.darkGreen,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 2. Appearance & Theme Preferences
  Widget _buildAppearanceBentoCard(
    BuildContext context,
    BudgetBuddyState state,
    _SettingsPalette palette,
  ) {
    final ThemeMode currentMode = state.themeMode;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: palette.cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: palette.borderColor, width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _buildSectionHeader(
            context: context,
            title: 'Appearance & Theme',
            icon: Icons.palette_rounded,
            accentColor: palette.darkGreen,
          ),
          const SizedBox(height: 12),
          Text(
            'Select your preferred visual style across all screens:',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 10),
          // Theme Mode Switcher Segmented Pill
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: palette.segmentBg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: palette.borderColor),
            ),
            child: Row(
              children: <Widget>[
                _buildThemeSegmentOption(
                  label: 'Light',
                  icon: Icons.light_mode_rounded,
                  isSelected: currentMode == ThemeMode.light,
                  palette: palette,
                  onTap: () {
                    ref
                        .read(budgetBuddyControllerProvider.notifier)
                        .setThemeMode(ThemeMode.light);
                  },
                ),
                _buildThemeSegmentOption(
                  label: 'Dark',
                  icon: Icons.dark_mode_rounded,
                  isSelected: currentMode == ThemeMode.dark,
                  palette: palette,
                  onTap: () {
                    ref
                        .read(budgetBuddyControllerProvider.notifier)
                        .setThemeMode(ThemeMode.dark);
                  },
                ),
                _buildThemeSegmentOption(
                  label: 'System',
                  icon: Icons.brightness_auto_rounded,
                  isSelected: currentMode == ThemeMode.system,
                  palette: palette,
                  onTap: () {
                    ref
                        .read(budgetBuddyControllerProvider.notifier)
                        .setThemeMode(ThemeMode.system);
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildThemeSegmentOption({
    required String label,
    required IconData icon,
    required bool isSelected,
    required _SettingsPalette palette,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? palette.darkGreen : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Icon(
                icon,
                size: 16,
                color: isSelected
                    ? Colors.white
                    : Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  fontWeight:
                      isSelected ? FontWeight.w800 : FontWeight.w600,
                  color: isSelected
                      ? Colors.white
                      : Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 3. Financial & Currency Settings
  Widget _buildFinancialDefaultsBentoCard(
    BuildContext context,
    BudgetBuddyState state,
    _SettingsPalette palette,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: palette.cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: palette.borderColor, width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _buildSectionHeader(
            context: context,
            title: 'Financial & Regional Defaults',
            icon: Icons.account_balance_wallet_rounded,
            accentColor: palette.darkGreen,
          ),
          const SizedBox(height: 8),

          // Currency Symbol Settings
          _buildBentoTile(
            context: context,
            title: 'Currency Symbol',
            subtitle: 'Default formatter set to Philippine Peso (₱)',
            icon: Icons.payments_rounded,
            iconColor: palette.darkGreen,
            iconBg: palette.darkGreenBg,
            iconBorder: palette.darkGreenBorder,
            trailing: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: palette.darkGreenBg,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: palette.darkGreenBorder),
              ),
              child: Text(
                '₱ PHP',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: palette.darkGreen,
                ),
              ),
            ),
            onTap: () => _showCurrencyDialog(context, palette),
          ),
        ],
      ),
    );
  }

  // 4. Local Data & Privacy Management
  Widget _buildLocalDataBentoCard(
    BuildContext context,
    BudgetBuddyState state,
    BudgetSummary summary,
    _SettingsPalette palette,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: palette.cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: palette.borderColor, width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _buildSectionHeader(
            context: context,
            title: 'Local Data & Privacy Management',
            icon: Icons.security_rounded,
            accentColor: palette.darkGreen,
          ),
          const SizedBox(height: 12),

          // Export / Backup Local Data Grid
          Row(
            children: <Widget>[
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _exportPdf(context, state, summary),
                  icon: const Icon(Icons.picture_as_pdf_rounded, size: 16),
                  label: Text(
                    'Export PDF',
                    style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _exportCsv(context, state),
                  icon: const Icon(Icons.table_view_rounded, size: 16),
                  label: Text(
                    'Export CSV',
                    style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: <Widget>[
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => _backupSnapshot(context, state),
                  icon: const Icon(Icons.cloud_upload_rounded, size: 16),
                  label: Text(
                    'Backup JSON',
                    style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: palette.darkGreen,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    elevation: 0,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => _restoreSnapshot(context),
                  icon: const Icon(Icons.cloud_download_rounded, size: 16),
                  label: Text(
                    'Restore JSON',
                    style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: palette.gold,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    elevation: 0,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Divider(height: 1, color: palette.borderColor),
          const SizedBox(height: 10),

          // Clear All Local Data / Reset App Tile (Destructive Accent #991B1B)
          _buildBentoTile(
            context: context,
            title: 'Clear All Local Data / Reset App',
            subtitle: 'Wipe all budgets, logs, debt, and history back to 0',
            icon: Icons.delete_forever_rounded,
            iconColor: palette.darkRed,
            iconBg: palette.darkRedBg,
            iconBorder: palette.darkRedBorder,
            trailing: FilledButton(
              onPressed: () => _confirmResetApp(context),
              style: FilledButton.styleFrom(
                backgroundColor: palette.darkRed,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                elevation: 0,
              ),
              child: Text(
                'Reset',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            onTap: () => _confirmResetApp(context),
          ),
        ],
      ),
    );
  }

  // 5. App Info & Licenses
  Widget _buildAppInfoBentoCard(BuildContext context, _SettingsPalette palette) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: palette.cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: palette.borderColor, width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _buildSectionHeader(
            context: context,
            title: 'App Info & Licenses',
            icon: Icons.info_outline_rounded,
            accentColor: palette.darkGreen,
          ),
          const SizedBox(height: 10),

          _buildBentoTile(
            context: context,
            title: 'Budget Buddy Application',
            subtitle: _appVersion != null
                ? 'Version ${_appVersion!.version} (Build ${_appVersion!.buildNumber})'
                : 'Version 1.0.0 (Production Release)',
            icon: Icons.system_update_rounded,
            iconColor: palette.darkGreen,
            iconBg: palette.darkGreenBg,
            iconBorder: palette.darkGreenBorder,
            trailing: _isCheckingUpdate
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : FilledButton(
                    onPressed: _checkForAppUpdate,
                    style: FilledButton.styleFrom(
                      backgroundColor: palette.darkGreen,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      'Check',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
            onTap: _checkForAppUpdate,
          ),
          Divider(height: 1, color: palette.borderColor),
          const SizedBox(height: 10),

          // Offline Privacy Pledge & Credits Card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: palette.segmentBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: palette.borderColor),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Icon(
                      Icons.verified_user_rounded,
                      size: 16,
                      color: palette.darkGreen,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'OFFLINE PRIVACY PLEDGE',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                        color: palette.darkGreen,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Budget Buddy runs 100% locally on your device. No analytics, tracking, or cloud servers. Crafted for personal privacy and full financial autonomy.',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11.5,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Divider(height: 1, color: palette.borderColor),

          _buildBentoTile(
            context: context,
            title: 'Logout / Switch Session',
            subtitle: 'Safely sign out from current session',
            icon: Icons.logout_rounded,
            iconColor: palette.darkRed,
            iconBg: palette.darkRedBg,
            iconBorder: palette.darkRedBorder,
            onTap: () => _confirmLogout(context),
          ),
        ],
      ),
    );
  }

  // 6. Developer Mode & Diagnostics (Debug mode only)
  Widget _buildDevTestingBentoCard(
    BuildContext context,
    BudgetBuddyState state,
    _SettingsPalette palette,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: palette.cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: palette.goldBorder, width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: palette.goldBg,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'DEV MODE ONLY',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    color: palette.gold,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'DIAGNOSTICS & SIMULATION',
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Test midnight 12:00 AM auto-reset, clock simulation, and screen previews.',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 11.5,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
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
                icon: const Icon(Icons.login_rounded, size: 14),
                label: Text(
                  'Preview Login',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
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
                icon: const Icon(Icons.home_rounded, size: 14),
                label: Text(
                  'Preview Splash',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              OutlinedButton.icon(
                onPressed: () =>
                    _showDevUpdateModal(context, mandatory: false),
                icon: const Icon(Icons.system_update_rounded, size: 14),
                label: Text(
                  'Preview Update',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              OutlinedButton.icon(
                onPressed: () =>
                    _showDevUpdateModal(context, mandatory: true),
                icon: const Icon(Icons.warning_amber_rounded, size: 14),
                label: Text(
                  'Required Update',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF991B1B),
                  ),
                ),
              ),
              OutlinedButton.icon(
                onPressed: () => showBudsChat(context),
                icon: const Icon(Icons.auto_awesome_rounded, size: 14),
                label: Text(
                  'Open Buds AI',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Time Simulation Box
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: palette.segmentBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: palette.borderColor),
            ),
            child: Row(
              children: <Widget>[
                Icon(
                  state.isTimeSimulated
                      ? Icons.schedule_rounded
                      : Icons.access_time_rounded,
                  color: state.isTimeSimulated
                      ? palette.gold
                      : palette.darkGreen,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        state.isTimeSimulated
                            ? 'Simulated App Clock'
                            : 'Device Real Time',
                        style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.w700,
                          fontSize: 12.5,
                        ),
                      ),
                      Text(
                        DateFormat('EEE, MMM d, yyyy • h:mm:ss a')
                            .format(state.effectiveDate),
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11.5,
                          color: Theme.of(context)
                              .colorScheme
                              .onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                if (state.isTimeSimulated)
                  TextButton(
                    onPressed: () async {
                      await ref
                          .read(budgetBuddyControllerProvider.notifier)
                          .resetSimulatedTime();
                      setState(() {});
                      if (context.mounted) {
                        showAppAlert(
                          context,
                          message: 'Reverted to device real time.',
                          title: 'Real Time Restored',
                          accentColor: palette.darkGreen,
                          icon: Icons.check_circle_outline_rounded,
                        );
                      }
                    },
                    child: Text(
                      'Reset',
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.w700,
                        color: palette.darkGreen,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          FilledButton.icon(
            onPressed: () async {
              await ref
                  .read(budgetBuddyControllerProvider.notifier)
                  .simulateMidnightReset();
              setState(() {});
              if (context.mounted) {
                showAppAlert(
                  context,
                  message:
                      'Simulated 12:00 AM! Today\'s active budget & expenses have reset.',
                  title: 'Midnight Auto-Reset',
                  icon: Icons.nightlight_round,
                  accentColor: palette.darkGreen,
                );
              }
            },
            icon: const Icon(Icons.nightlight_round, size: 16),
            label: Text(
              'Simulate 12:00 AM Midnight Reset',
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.w800,
                fontSize: 13,
              ),
            ),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(42),
              backgroundColor: palette.darkGreen,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 0,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: <Widget>[
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _pickDevTimeOnly(context),
                  icon: const Icon(Icons.access_time_rounded, size: 14),
                  label: Text(
                    'Set Time (12 AM)',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _pickDevSimulatedTime(context),
                  icon: const Icon(Icons.edit_calendar_rounded, size: 14),
                  label: Text(
                    'Set Date & Time',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
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
                        .read(budgetBuddyControllerProvider.notifier)
                        .setSimulatedTimeTo1159PM();
                    setState(() {});
                    if (context.mounted) {
                      showAppAlert(
                        context,
                        message: 'Time set to 11:59 PM (1 min before midnight).',
                        title: 'Time Simulation',
                        accentColor: palette.gold,
                        icon: Icons.bedtime_outlined,
                      );
                    }
                  },
                  icon: const Icon(Icons.bedtime_outlined, size: 14),
                  label: Text(
                    'Set 11:59 PM',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () async {
                    await ref
                        .read(budgetBuddyControllerProvider.notifier)
                        .fastForwardOneDay();
                    setState(() {});
                    if (context.mounted) {
                      showAppAlert(
                        context,
                        message: 'Fast-forwarded +1 day past midnight.',
                        title: 'Time Simulation',
                        accentColor: palette.gold,
                        icon: Icons.fast_forward_rounded,
                      );
                    }
                  },
                  icon: const Icon(Icons.fast_forward_rounded, size: 14),
                  label: Text(
                    '+1 Day (12 AM)',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader({
    required BuildContext context,
    required String title,
    required IconData icon,
    required Color accentColor,
  }) {
    return Row(
      children: <Widget>[
        Icon(icon, size: 16, color: accentColor),
        const SizedBox(width: 8),
        Text(
          title,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 13.5,
            fontWeight: FontWeight.w800,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
      ],
    );
  }

  /// Clean settings Bento tile with badge icon, bold title, subtitle, and trailing action
  Widget _buildBentoTile({
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
              child: Icon(icon, color: iconColor, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    title,
                    style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11.5,
                      color: theme.colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w500,
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
                size: 20,
                color: theme.colorScheme.onSurfaceVariant,
              ),
          ],
        ),
      ),
    );
  }

  void _showCurrencyDialog(
    BuildContext context,
    _SettingsPalette palette,
  ) {
    showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: palette.cardBg,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: <Widget>[
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: palette.darkGreenBg,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: palette.darkGreenBorder),
                ),
                child: Icon(
                  Icons.payments_rounded,
                  color: palette.darkGreen,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Currency Symbol',
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w800,
                    fontSize: 17,
                  ),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'Budget Buddy formats all financial records using Philippine Peso (₱).',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12.5,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: palette.darkGreenBg,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: palette.darkGreen, width: 1.5),
                ),
                child: Row(
                  children: <Widget>[
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: palette.darkGreen,
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        '₱',
                        style: GoogleFonts.plusJakartaSans(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            'Philippine Peso (PHP)',
                            style: GoogleFonts.plusJakartaSans(
                              fontWeight: FontWeight.w800,
                              fontSize: 13.5,
                            ),
                          ),
                          Text(
                            'Symbol: ₱ • Standard Formatter',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.check_circle_rounded,
                      color: palette.darkGreen,
                      size: 22,
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: <Widget>[
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: palette.darkGreen,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 10,
                ),
              ),
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(
                'Confirm',
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
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
                  color: Color(0xFF0F766E),
                ),
                const SizedBox(height: 8),
                Text(
                  'Back Up Data Snapshot',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 12),
                ListTile(
                  leading: const Icon(Icons.download_rounded),
                  title: Text(
                    'Download',
                    style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  subtitle: const Text('Save JSON to device Downloads'),
                  onTap: () => Navigator.of(context).pop('download'),
                ),
                ListTile(
                  leading: const Icon(Icons.share_rounded),
                  title: Text(
                    'Share',
                    style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  subtitle: const Text('Share via other apps'),
                  onTap: () => Navigator.of(context).pop('share'),
                ),
                ListTile(
                  leading: const Icon(Icons.copy_all_rounded),
                  title: Text(
                    'Copy JSON',
                    style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
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
                      child: Text(
                        'Cancel',
                        style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
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
        await _showDownloadedModal(
          context,
          displayPath: displayPath,
          label: 'Backup JSON',
        );
        return;
      } catch (e) {
        debugPrint('Backup save error: $e');
        if (!mounted) return;
        showAppAlert(
          context,
          message: 'Could not save backup to Downloads.',
          title: 'Notice',
          icon: Icons.info_outline_rounded,
          accentColor: const Color(0xFF991B1B),
        );
      }
    }

    if (choice == 'share') {
      await Share.shareXFiles(
        <XFile>[XFile(file.path)],
        text: 'BudgetBuddy backup snapshot',
      );
      return;
    }

    if (choice == 'copy') {
      await Clipboard.setData(ClipboardData(text: jsonText));
      if (!mounted) return;
      showAppAlert(
        context,
        message: 'Backup JSON copied to clipboard.',
        title: 'Notice',
        icon: Icons.info_outline_rounded,
        accentColor: const Color(0xFF0F766E),
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
                  color: Color(0xFFD97706),
                ),
                const SizedBox(height: 12),
                Text(
                  'Restore Backup Data',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Choose how to restore your local database snapshot:',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12.5,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        onPressed: () => Navigator.of(context).pop('paste'),
                        icon: const Icon(Icons.content_paste_rounded),
                        label: Text(
                          'Paste JSON',
                          style: GoogleFonts.plusJakartaSans(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF0F766E),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        onPressed: () => Navigator.of(context).pop('file'),
                        icon: const Icon(Icons.folder_open_rounded),
                        label: Text(
                          'Select File',
                          style: GoogleFonts.plusJakartaSans(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
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
                    child: Text(
                      'Cancel',
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
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
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            icon: const Icon(
              Icons.check_circle_rounded,
              color: Color(0xFF0F766E),
              size: 48,
            ),
            title: Text(
              'Restore Complete',
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.w800,
              ),
            ),
            content: Text(
              'Expenses, Savings (daily/monthly), and Budget Together data have been restored successfully.',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
              ),
              textAlign: TextAlign.center,
            ),
            actions: <Widget>[
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF0F766E),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: Text(
                  'OK',
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w800,
                  ),
                ),
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
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          icon: const Icon(
            Icons.check_circle_rounded,
            color: Color(0xFF0F766E),
            size: 48,
          ),
          title: Text(
            'Reset Complete',
            style: GoogleFonts.plusJakartaSans(
              fontWeight: FontWeight.w800,
            ),
          ),
          content: Text(
            'App data has been reset to zero successfully.',
            style: GoogleFonts.plusJakartaSans(fontSize: 13),
            textAlign: TextAlign.center,
          ),
          actions: <Widget>[
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF0F766E),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(
                'OK',
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _exportPdf(
    BuildContext context,
    BudgetBuddyState state,
    BudgetSummary summary,
  ) async {
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
                  color: Color(0xFF991B1B),
                ),
                const SizedBox(height: 8),
                Text(
                  'Export PDF Report',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 12),
                ListTile(
                  leading: const Icon(Icons.download_rounded),
                  title: Text(
                    'Download',
                    style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  subtitle: const Text('Save PDF report to device Downloads'),
                  onTap: () => Navigator.of(context).pop('download'),
                ),
                ListTile(
                  leading: const Icon(Icons.share_rounded),
                  title: Text(
                    'Share',
                    style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
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
                      child: Text(
                        'Cancel',
                        style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
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
      final File file = await ref.read(reportServiceProvider).exportDailyReport(
            state: state,
            summary: summary,
          );

      if (choice == 'download') {
        try {
          final String filename =
              'BudgetBuddy_Report_${DateTime.now().millisecondsSinceEpoch}.pdf';
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
        } catch (e) {
          debugPrint('Save error: $e');
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
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF0F766E),
                      foregroundColor: Colors.white,
                    ),
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
            showAppAlert(
              context,
              message: 'PDF report shared successfully.',
              title: 'Notice',
              icon: Icons.info_outline_rounded,
              accentColor: const Color(0xFF0F766E),
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
        showAppAlert(
          context,
          message: 'PDF report shared successfully.',
          title: 'Notice',
          icon: Icons.info_outline_rounded,
          accentColor: const Color(0xFF0F766E),
        );
        return;
      }
    } catch (_) {
      if (!context.mounted) return;
      showAppAlert(
        context,
        message: 'Could not export PDF report.',
        title: 'Notice',
        icon: Icons.info_outline_rounded,
        accentColor: const Color(0xFF991B1B),
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
                  color: Color(0xFF0F766E),
                ),
                const SizedBox(height: 8),
                Text(
                  'Export CSV Data',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 12),
                ListTile(
                  leading: const Icon(Icons.download_rounded),
                  title: Text(
                    'Download',
                    style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  subtitle: const Text('Save CSV to device Downloads'),
                  onTap: () => Navigator.of(context).pop('download'),
                ),
                ListTile(
                  leading: const Icon(Icons.share_rounded),
                  title: Text(
                    'Share',
                    style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
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
                      child: Text(
                        'Cancel',
                        style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
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
        } catch (e) {
          debugPrint('Save error: $e');
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
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF0F766E),
                      foregroundColor: Colors.white,
                    ),
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
            showAppAlert(
              context,
              message: 'CSV shared successfully.',
              title: 'Notice',
              icon: Icons.info_outline_rounded,
              accentColor: const Color(0xFF0F766E),
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
        showAppAlert(
          context,
          message: 'CSV shared successfully.',
          title: 'Notice',
          icon: Icons.info_outline_rounded,
          accentColor: const Color(0xFF0F766E),
        );
        return;
      }
    } catch (_) {
      if (!mounted) return;
      showAppAlert(
        context,
        message: 'Could not export CSV file.',
        title: 'Notice',
        icon: Icons.info_outline_rounded,
        accentColor: const Color(0xFF991B1B),
      );
    }
  }

  Future<void> _showDownloadedModal(
    BuildContext context, {
    required String displayPath,
    required String label,
  }) async {
    final String path = displayPath;
    await showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            '$label saved',
            style: GoogleFonts.plusJakartaSans(
              fontWeight: FontWeight.w800,
            ),
          ),
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
                showAppAlert(
                  context,
                  message: 'Path copied to clipboard.',
                  title: 'Notice',
                  icon: Icons.info_outline_rounded,
                  accentColor: const Color(0xFF0F766E),
                );
              },
              child: Text(
                'Copy path',
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF0F766E),
                ),
              ),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF0F766E),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'Close',
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w800,
                ),
              ),
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
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            'Logout Session?',
            style: GoogleFonts.plusJakartaSans(
              fontWeight: FontWeight.w800,
            ),
          ),
          content: Text(
            'Are you sure you want to sign out of your local session?',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13,
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(
                'Cancel',
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w700,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF991B1B),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(
                'Logout',
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w800,
                ),
              ),
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
    showAppAlert(
      context,
      message: 'Logged out successfully.',
      title: 'Notice',
      icon: Icons.info_outline_rounded,
      accentColor: const Color(0xFF0F766E),
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
              12,
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
                              'Profile Settings',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.plusJakartaSans(
                                fontWeight: FontWeight.w800,
                                fontSize: 17,
                              ),
                            ),
                          ),
                          const SizedBox(width: 48),
                        ],
                      ),
                      Text(
                        'Customize your display name across Budget Buddy',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          color:
                              Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        initialValue: originalName,
                        enabled: isEditing || !hasCustomName,
                        textInputAction: TextInputAction.done,
                        onChanged: (String value) {
                          setModalState(() => updatedName = value);
                        },
                        decoration: InputDecoration(
                          labelText: 'Display Name',
                          hintText: 'Enter your name',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (!hasCustomName && !isEditing) ...<Widget>[
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xFF0F766E),
                              foregroundColor: Colors.white,
                              padding:
                                  const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            onPressed: canSave
                                ? () async {
                                    ref
                                        .read(budgetBuddyControllerProvider
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
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(20),
                                          ),
                                          title: Text(
                                            'Saved',
                                            style: GoogleFonts
                                                .plusJakartaSans(
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                          content: Text(
                                            'Profile name saved successfully.',
                                            style: GoogleFonts
                                                .plusJakartaSans(
                                              fontSize: 13,
                                            ),
                                          ),
                                          actions: <Widget>[
                                            FilledButton(
                                              style: FilledButton.styleFrom(
                                                backgroundColor:
                                                    const Color(0xFF0F766E),
                                                foregroundColor: Colors.white,
                                                shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                          12),
                                                ),
                                              ),
                                              onPressed: () =>
                                                  Navigator.of(context).pop(),
                                              child: Text(
                                                'OK',
                                                style: GoogleFonts
                                                    .plusJakartaSans(
                                                  fontWeight: FontWeight.w800,
                                                ),
                                              ),
                                            ),
                                          ],
                                        );
                                      },
                                    );
                                  }
                                : null,
                            icon: const Icon(Icons.check_circle_rounded),
                            label: Text(
                              'Save Name',
                              style: GoogleFonts.plusJakartaSans(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                      ] else if (hasCustomName && !isEditing) ...<Widget>[
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xFFD97706),
                              foregroundColor: Colors.white,
                              padding:
                                  const EdgeInsets.symmetric(vertical: 12),
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
                            icon: const Icon(Icons.edit_rounded, size: 16),
                            label: Text(
                              'Edit Name',
                              style: GoogleFonts.plusJakartaSans(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ] else ...<Widget>[
                        Row(
                          children: <Widget>[
                            Expanded(
                              child: FilledButton.icon(
                                style: FilledButton.styleFrom(
                                  backgroundColor: const Color(0xFF991B1B),
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
                                    updatedName = originalName;
                                    isEditing = false;
                                  });
                                },
                                icon: const Icon(Icons.close_rounded,
                                    size: 16),
                                label: Text(
                                  'Cancel',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: FilledButton.icon(
                                style: FilledButton.styleFrom(
                                  backgroundColor: const Color(0xFF0F766E),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  elevation: 0,
                                ),
                                icon: const Icon(Icons.save_rounded,
                                    size: 16),
                                label: Text(
                                  'Save',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                onPressed: canSave
                                    ? () async {
                                        final bool? confirmSave =
                                            await showDialog<bool>(
                                          context: context,
                                          builder: (BuildContext context) {
                                            return AlertDialog(
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(
                                                        20),
                                              ),
                                              title: Text(
                                                'Confirm Save',
                                                style: GoogleFonts
                                                    .plusJakartaSans(
                                                  fontWeight: FontWeight.w800,
                                                ),
                                              ),
                                              content: Text(
                                                'Do you want to save this profile name change?',
                                                style: GoogleFonts
                                                    .plusJakartaSans(
                                                  fontSize: 13,
                                                ),
                                              ),
                                              actions: <Widget>[
                                                TextButton(
                                                  onPressed: () =>
                                                      Navigator.of(context)
                                                          .pop(false),
                                                  child: Text(
                                                    'No',
                                                    style: GoogleFonts
                                                        .plusJakartaSans(
                                                      fontWeight:
                                                          FontWeight.w700,
                                                      color: Theme.of(context)
                                                          .colorScheme
                                                          .onSurfaceVariant,
                                                    ),
                                                  ),
                                                ),
                                                FilledButton(
                                                  style:
                                                      FilledButton.styleFrom(
                                                    backgroundColor:
                                                        const Color(
                                                            0xFF0F766E),
                                                    foregroundColor:
                                                        Colors.white,
                                                    shape:
                                                        RoundedRectangleBorder(
                                                      borderRadius:
                                                          BorderRadius
                                                              .circular(12),
                                                    ),
                                                  ),
                                                  onPressed: () =>
                                                      Navigator.of(context)
                                                          .pop(true),
                                                  child: Text(
                                                    'Yes',
                                                    style: GoogleFonts
                                                        .plusJakartaSans(
                                                      fontWeight:
                                                          FontWeight.w800,
                                                    ),
                                                  ),
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
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(
                                                        20),
                                              ),
                                              title: Text(
                                                'Saved',
                                                style: GoogleFonts
                                                    .plusJakartaSans(
                                                  fontWeight: FontWeight.w800,
                                                ),
                                              ),
                                              content: Text(
                                                'Profile name saved successfully.',
                                                style: GoogleFonts
                                                    .plusJakartaSans(
                                                  fontSize: 13,
                                                ),
                                              ),
                                              actions: <Widget>[
                                                FilledButton(
                                                  style:
                                                      FilledButton.styleFrom(
                                                    backgroundColor:
                                                        const Color(
                                                            0xFF0F766E),
                                                    foregroundColor:
                                                        Colors.white,
                                                    shape:
                                                        RoundedRectangleBorder(
                                                      borderRadius:
                                                          BorderRadius
                                                              .circular(12),
                                                    ),
                                                  ),
                                                  onPressed: () =>
                                                      Navigator.of(context)
                                                          .pop(),
                                                  child: Text(
                                                    'OK',
                                                    style: GoogleFonts
                                                        .plusJakartaSans(
                                                      fontWeight:
                                                          FontWeight.w800,
                                                    ),
                                                  ),
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
      showAppAlert(
        context,
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
      showAppAlert(
        context,
        message:
            'Simulated time set to: ${DateFormat('MMM d, yyyy • h:mm a').format(newSimulatedTime)}',
        title: 'Success',
        icon: Icons.check_circle_outline_rounded,
        accentColor: const Color(0xFF0F766E),
      );
    }
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
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      title: Text(
        'Reset Entire App to 0?',
        style: GoogleFonts.plusJakartaSans(
          fontWeight: FontWeight.w800,
          color: const Color(0xFF991B1B),
        ),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'This will reset the entire local database to zero. All budgets, expenses, spending records, savings, debts, and daily logs will be set to 0. Type RESET to continue.',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _confirmationController,
              decoration: InputDecoration(
                labelText: 'Type RESET',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(
            'Cancel',
            style: GoogleFonts.plusJakartaSans(
              fontWeight: FontWeight.w700,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        FilledButton(
          onPressed: () {
            if (_confirmationController.text.trim().toUpperCase() == 'RESET') {
              Navigator.of(context).pop(true);
            }
          },
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF991B1B),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          ),
          child: Text(
            isTimerDone
                ? 'Reset All to 0'
                : 'Reset All to 0 (${_secondsRemaining}s)',
            style: GoogleFonts.plusJakartaSans(
              fontWeight: FontWeight.w800,
            ),
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
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      title: Text(
        'Paste JSON Backup',
        style: GoogleFonts.plusJakartaSans(
          fontWeight: FontWeight.w800,
        ),
      ),
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
                  icon: const Icon(Icons.content_paste_rounded, size: 16),
                  label: Text(
                    'Paste Clipboard',
                    style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              TextField(
                controller: _controller,
                maxLines: 8,
                decoration: InputDecoration(
                  labelText: 'Paste JSON text here',
                  alignLabelWithHint: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(
            'Cancel',
            style: GoogleFonts.plusJakartaSans(
              fontWeight: FontWeight.w700,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF0F766E),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          ),
          onPressed: () {
            if (_controller.text.trim().isNotEmpty) {
              Navigator.of(context).pop(_controller.text.trim());
            }
          },
          child: Text(
            'Restore',
            style: GoogleFonts.plusJakartaSans(
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }
}
