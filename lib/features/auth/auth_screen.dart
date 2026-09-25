// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/state/app_controller.dart';
import '../../core/models/budget_models.dart';
import 'package:budgetbuddy/core/utils/alert_dialog.dart';

/// Clean Modern Bento Tokens for Auth / Name Onboarding Screen.
class _AuthTokens {
  const _AuthTokens(this.isDark);

  final bool isDark;

  static const Color primaryGreen = Color(0xFF0F766E);
  static const Color teaserGold = Color(0xFFD97706);
  static const Color errorRed = Color(0xFF991B1B);

  Color get scaffoldBg =>
      isDark ? const Color(0xFF0B1120) : const Color(0xFFF8FAFC);
  Color get cardBg =>
      isDark ? const Color(0xFF111827) : const Color(0xFFFFFFFF);
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
      teaserGold.withValues(alpha: isDark ? 0.20 : 0.08);
  Color get goldBorder => teaserGold.withValues(alpha: 0.25);
  Color get redBg =>
      errorRed.withValues(alpha: isDark ? 0.20 : 0.08);
  Color get redBorder => errorRed.withValues(alpha: 0.25);
}

class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  final TextEditingController _nameController = TextEditingController();
  final FocusNode _nameFocusNode = FocusNode();
  String? _errorMessage;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _loadInitialName();
  }

  Future<void> _loadInitialName() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? localName = prefs.getString('userName');
    final BudgetBuddyState state = ref.read(budgetBuddyControllerProvider);
    final String profileName = state.profile.displayName;

    String candidate = '';
    if (localName != null && localName.trim().isNotEmpty) {
      candidate = localName.trim();
    } else if (profileName.trim().isNotEmpty && profileName != 'Budget Buddy') {
      candidate = profileName.trim();
    }

    if (candidate.isNotEmpty && !_isInitialized) {
      _nameController.value = TextEditingValue(
        text: candidate,
        selection: TextSelection.collapsed(offset: candidate.length),
      );
      _isInitialized = true;
      if (mounted) setState(() {});
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _nameFocusNode.dispose();
    super.dispose();
  }

  Future<void> _handleContinue(_AuthTokens tokens) async {
    final String trimmedName = _nameController.text.trim();
    if (trimmedName.isEmpty) {
      HapticFeedback.vibrate();
      setState(() {
        _errorMessage = 'Please enter your name to personalize your budget';
      });
      _nameFocusNode.requestFocus();
      return;
    }

    HapticFeedback.lightImpact();
    setState(() {
      _errorMessage = null;
    });

    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setString('userName', trimmedName);
    } catch (_) {}

    ref.read(budgetBuddyControllerProvider.notifier).login(trimmedName);
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final _AuthTokens tokens = _AuthTokens(isDark);

    return Scaffold(
      backgroundColor: tokens.scaffoldBg,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: <Widget>[
                  // 1. Header Bento Card (App Branding & Badges)
                  _buildHeaderBentoCard(context, tokens),
                  const SizedBox(height: 16),

                  // 2. Name Input Card
                  _buildNameInputCard(context, tokens),
                  const SizedBox(height: 16),

                  // 3. Continue Action Button
                  _buildContinueButton(context, tokens),
                  const SizedBox(height: 20),

                  // 4. Offline Privacy Guarantee Note
                  _buildPrivacyFooter(context, tokens),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // 1. Header Bento Card (App Branding & Badges)
  Widget _buildHeaderBentoCard(BuildContext context, _AuthTokens tokens) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
      decoration: BoxDecoration(
        color: tokens.cardBg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: tokens.borderColor, width: 1.2),
      ),
      child: Column(
        children: <Widget>[
          // App Logo
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: _AuthTokens.primaryGreen,
              borderRadius: BorderRadius.circular(20),
            ),
            alignment: Alignment.center,
            child: const Icon(
              Icons.savings_rounded,
              color: Colors.white,
              size: 34,
            ),
          ),
          const SizedBox(height: 14),

          // App Title
          Text(
            'Budget Buddy',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.6,
              color: tokens.textPrimary,
            ),
          ),
          const SizedBox(height: 4),

          // Subtitle
          Text(
            'Smart Offline Budget & Financial Tracker',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12.5,
              fontWeight: FontWeight.w500,
              color: tokens.textSecondary,
            ),
          ),
          const SizedBox(height: 16),

          // Badges Row: 100% Offline & Cloud Sync Teaser
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              // Offline Badge Capsule
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: tokens.greenBg,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: tokens.greenBorder, width: 1),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Container(
                      width: 7,
                      height: 7,
                      decoration: const BoxDecoration(
                        color: _AuthTokens.primaryGreen,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '100% Offline & Private',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: _AuthTokens.primaryGreen,
                      ),
                    ),
                  ],
                ),
              ),

              // Cloud Sync Teaser Capsule
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: tokens.goldBg,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: tokens.goldBorder, width: 1),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    const Icon(
                      Icons.cloud_sync_outlined,
                      size: 14,
                      color: _AuthTokens.teaserGold,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      'Cloud Sync — Coming Soon',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: _AuthTokens.teaserGold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // 2. Name Input Card
  Widget _buildNameInputCard(BuildContext context, _AuthTokens tokens) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: tokens.cardBg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: tokens.borderColor, width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Welcome! What should we call you?',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 15.5,
              fontWeight: FontWeight.w800,
              color: tokens.textPrimary,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Your name is stored locally on this device to personalize your greeting and financial reports.',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: tokens.textSecondary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),

          // Name Text Input Field
          TextField(
            controller: _nameController,
            focusNode: _nameFocusNode,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.done,
            onChanged: (String value) {
              if (_errorMessage != null && value.trim().isNotEmpty) {
                setState(() => _errorMessage = null);
              } else if (mounted) {
                setState(() {});
              }
            },
            onSubmitted: (_) => _handleContinue(tokens),
            style: GoogleFonts.plusJakartaSans(
              fontSize: 14.5,
              fontWeight: FontWeight.w700,
              color: tokens.textPrimary,
            ),
            decoration: InputDecoration(
              hintText: 'Enter your preferred name',
              hintStyle: GoogleFonts.plusJakartaSans(
                fontSize: 13.5,
                fontWeight: FontWeight.w500,
                color: tokens.textSecondary.withValues(alpha: 0.7),
              ),
              prefixIcon: const Icon(
                Icons.person_outline_rounded,
                color: _AuthTokens.primaryGreen,
                size: 20,
              ),
              suffixIcon: _nameController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear_rounded, size: 18),
                      color: tokens.textSecondary,
                      tooltip: 'Clear',
                      onPressed: () {
                        _nameController.clear();
                        setState(() {});
                      },
                    )
                  : null,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: tokens.borderColor),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: tokens.borderColor, width: 1.2),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(
                  color: _AuthTokens.primaryGreen,
                  width: 1.8,
                ),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(
                  color: _AuthTokens.errorRed,
                  width: 1.4,
                ),
              ),
            ),
          ),

          // Error message banner
          if (_errorMessage != null) ...<Widget>[
            const SizedBox(height: 10),
            Row(
              children: <Widget>[
                const Icon(
                  Icons.error_outline_rounded,
                  size: 15,
                  color: _AuthTokens.errorRed,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    _errorMessage!,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: _AuthTokens.errorRed,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // 3. Continue Action Button
  Widget _buildContinueButton(BuildContext context, _AuthTokens tokens) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: FilledButton.icon(
        style: FilledButton.styleFrom(
          backgroundColor: _AuthTokens.primaryGreen,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 0,
        ),
        onPressed: () => _handleContinue(tokens),
        label: Text(
          'Get Started',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.2,
          ),
        ),
        icon: const Icon(Icons.arrow_forward_rounded, size: 18),
      ),
    );
  }

  // 4. Privacy Footer
  Widget _buildPrivacyFooter(BuildContext context, _AuthTokens tokens) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: tokens.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: tokens.borderColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const Icon(
            Icons.shield_outlined,
            size: 16,
            color: _AuthTokens.primaryGreen,
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              'Zero account registration required • Stored 100% locally',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: tokens.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}
