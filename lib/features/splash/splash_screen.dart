// ignore_for_file: use_build_context_synchronously

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Clean Modern Bento Tokens for Splash & Center Update Dialog.
class _SplashTokens {
  const _SplashTokens(this.isDark);

  final bool isDark;

  static const Color primaryGreen = Color(0xFF0F766E);
  static const Color warningGold = Color(0xFFD97706);
  static const Color destructiveRed = Color(0xFF991B1B);

  Color get scaffoldBg =>
      isDark ? const Color(0xFF0B1120) : const Color(0xFFF8FAFC);
  Color get dialogBg =>
      isDark ? const Color(0xFF111827) : const Color(0xFFFFFFFF);
  Color get cardBg =>
      isDark ? const Color(0xFF111827) : const Color(0xFFFFFFFF);
  Color get subCardBg =>
      isDark ? const Color(0xFF161F31) : const Color(0xFFF1F5F9);
  Color get borderColor =>
      isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0);
  Color get textPrimary =>
      isDark ? const Color(0xFFF1F5F9) : const Color(0xFF0F172A);
  Color get textSecondary =>
      isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

  Color get greenBg =>
      primaryGreen.withValues(alpha: isDark ? 0.20 : 0.08);
  Color get greenBorder => primaryGreen.withValues(alpha: 0.25);
  Color get goldBg =>
      warningGold.withValues(alpha: isDark ? 0.20 : 0.08);
  Color get goldBorder => warningGold.withValues(alpha: 0.25);
  Color get redBg =>
      destructiveRed.withValues(alpha: isDark ? 0.20 : 0.08);
  Color get redBorder => destructiveRed.withValues(alpha: 0.25);
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final Animation<double> _scaleAnimation;

  static const String _currentVersion = '1.0.0';

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    _scaleAnimation = Tween<double>(begin: 0.97, end: 1.03).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final _SplashTokens tokens = _SplashTokens(isDark);
    final bool canGoBack = Navigator.of(context).canPop();

    return Scaffold(
      backgroundColor: tokens.scaffoldBg,
      body: SafeArea(
        child: Column(
          children: <Widget>[
            // Top Navigation Bar / Back Button (when previewed or can pop)
            if (canGoBack)
              Align(
                alignment: Alignment.topLeft,
                child: Padding(
                  padding: const EdgeInsets.only(left: 16, top: 8),
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back_rounded),
                    onPressed: () => Navigator.of(context).pop(),
                    tooltip: 'Back',
                    style: IconButton.styleFrom(
                      backgroundColor: tokens.subCardBg,
                      side: BorderSide(color: tokens.borderColor),
                    ),
                  ),
                ),
              ),

            const Spacer(flex: 3),

            // Centered App Branding
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  // Crisp Rounded Bento Icon Tile
                  ScaleTransition(
                    scale: _scaleAnimation,
                    child: Container(
                      width: 88,
                      height: 88,
                      decoration: BoxDecoration(
                        color: _SplashTokens.primaryGreen,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: _SplashTokens.primaryGreen
                              .withValues(alpha: 0.35),
                          width: 2.0,
                        ),
                        boxShadow: <BoxShadow>[
                          BoxShadow(
                            color: _SplashTokens.primaryGreen
                                .withValues(alpha: tokens.isDark ? 0.35 : 0.18),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      alignment: Alignment.center,
                      child: const Icon(
                        Icons.savings_rounded,
                        size: 46,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // App Title
                  Text(
                    'Budget Buddy',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 30,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.6,
                      color: tokens.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),

                  // Subtitle
                  Text(
                    '100% Offline Personal Finance',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: tokens.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 100% Offline Status Capsule Badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: tokens.greenBg,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: tokens.greenBorder),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: _SplashTokens.primaryGreen,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '100% OFFLINE VAULT',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.6,
                            color: _SplashTokens.primaryGreen,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const Spacer(flex: 3),

            // Loading & Version Check Sequence
            SizedBox(
              width: 140,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: const LinearProgressIndicator(
                  minHeight: 4,
                  backgroundColor: Color(0xFFE2E8F0),
                  valueColor: AlwaysStoppedAnimation<Color>(
                    _SplashTokens.primaryGreen,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // App Version Display
            Text(
              'v$_currentVersion • Local Vault Ready',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: tokens.textSecondary,
                letterSpacing: 0.3,
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

/// Center Update Modal Dialog (Clean Flat Bento Minimalist)
class CenterUpdateDialog extends StatelessWidget {
  const CenterUpdateDialog({
    super.key,
    required this.isDark,
    required this.isMandatory,
    required this.currentVersion,
    required this.newVersion,
    required this.releaseNotes,
    required this.onUpdateNow,
    required this.onBack,
  });

  final bool isDark;
  final bool isMandatory;
  final String currentVersion;
  final String newVersion;
  final List<String> releaseNotes;
  final VoidCallback onUpdateNow;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final _SplashTokens tokens = _SplashTokens(isDark);

    return Dialog(
      backgroundColor: tokens.dialogBg,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: tokens.borderColor, width: 1.2),
      ),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              // Header Row: Icon + Version Info
              Row(
                children: <Widget>[
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: isMandatory
                          ? _SplashTokens.destructiveRed
                          : _SplashTokens.warningGold,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    alignment: Alignment.center,
                    child: const Icon(
                      Icons.system_update_rounded,
                      color: Colors.white,
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          'Update Available',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: tokens.textPrimary,
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Version $newVersion (Current: v$currentVersion)',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: tokens.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Required / New Version Capsule Tag
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: isMandatory ? tokens.redBg : tokens.goldBg,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: isMandatory ? tokens.redBorder : tokens.goldBorder,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Icon(
                      isMandatory
                          ? Icons.warning_rounded
                          : Icons.auto_awesome_rounded,
                      size: 13,
                      color: isMandatory
                          ? _SplashTokens.destructiveRed
                          : _SplashTokens.warningGold,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      isMandatory
                          ? 'REQUIRED UPDATE'
                          : 'NEW VERSION AVAILABLE',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                        color: isMandatory
                            ? _SplashTokens.destructiveRed
                            : _SplashTokens.warningGold,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Release Notes Bento Box
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: tokens.subCardBg,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: tokens.borderColor),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      "WHAT'S NEW",
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.6,
                        color: tokens.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...releaseNotes.map(
                      (String note) => Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            const Padding(
                              padding: EdgeInsets.only(top: 4),
                              child: Icon(
                                Icons.check_circle_rounded,
                                size: 13,
                                color: _SplashTokens.primaryGreen,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                note,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: tokens.textPrimary,
                                  height: 1.35,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Action Buttons (Solid Fill)
              Row(
                children: <Widget>[
                  // Back / Exit Button: Solid Dark Red (#991B1B) with Back Arrow Icon
                  Expanded(
                    child: SizedBox(
                      height: 46,
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: _SplashTokens.destructiveRed,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          elevation: 0,
                        ),
                        onPressed: onBack,
                        icon: const Icon(
                          Icons.arrow_back_rounded,
                          size: 16,
                        ),
                        label: Text(
                          isMandatory ? 'Exit' : 'Back',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),

                  // Update Now Button: Solid Dark Green (#0F766E)
                  Expanded(
                    flex: 2,
                    child: SizedBox(
                      height: 46,
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: _SplashTokens.primaryGreen,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          elevation: 0,
                        ),
                        onPressed: onUpdateNow,
                        icon: const Icon(
                          Icons.download_rounded,
                          size: 16,
                        ),
                        label: Text(
                          'Update Now',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
