import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/state/app_controller.dart';
import '../../core/models/budget_models.dart';

/// Palette defining the unified 3 primary design colors: Dark Red, Gold, and Dark Green.
class _AuthPalette {
  const _AuthPalette(this.isDark);

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

class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  final TextEditingController _nameController = TextEditingController();
  final FocusNode _nameFocusNode = FocusNode();
  String? _nameError;
  bool _isEditingName = false;
  bool _initializedName = false;

  String _buildInitials(String displayName) {
    final String trimmed = displayName.trim();
    if (trimmed.isEmpty) {
      return 'BB';
    }
    return trimmed
        .split(RegExp(r'\s+'))
        .take(2)
        .map((String part) => part.isNotEmpty ? part[0] : '')
        .join()
        .toUpperCase();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _nameFocusNode.dispose();
    super.dispose();
  }

  void _handleSignIn(String currentInputName, _AuthPalette palette) {
    final String trimmed = currentInputName.trim();
    if (trimmed.isEmpty) {
      setState(() {
        _nameError = 'Name is required to sign in';
      });
      _nameFocusNode.requestFocus();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'Name is required to sign in.',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          behavior: SnackBarBehavior.floating,
          backgroundColor: palette.darkRed,
        ),
      );
      return;
    }

    setState(() {
      _nameError = null;
    });

    ref.read(budgetBuddyControllerProvider.notifier).login(trimmed);
  }

  void _handleSaveName(
    String currentInputName,
    _AuthPalette palette,
    BudgetBuddyState state,
  ) {
    final String trimmed = currentInputName.trim();
    if (trimmed.isEmpty) {
      setState(() {
        _nameError = 'Name is required';
      });
      _nameFocusNode.requestFocus();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'Name cannot be empty.',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          behavior: SnackBarBehavior.floating,
          backgroundColor: palette.darkRed,
        ),
      );
      return;
    }

    ref.read(budgetBuddyControllerProvider.notifier).updateProfile(
          state.profile.copyWith(
            displayName: trimmed,
            avatarSeed: _buildInitials(trimmed),
          ),
        );

    setState(() {
      _nameError = null;
      _isEditingName = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Display name saved!'),
        behavior: SnackBarBehavior.floating,
        backgroundColor: palette.darkGreen,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(budgetBuddyControllerProvider);
    final String savedDisplayName = state.profile.displayName;
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final _AuthPalette palette = _AuthPalette(isDark);
    final ThemeData theme = Theme.of(context);

    final String normalizedSavedName =
        savedDisplayName == 'Budget Buddy' ? '' : savedDisplayName.trim();

    if (!_initializedName) {
      if (normalizedSavedName.isNotEmpty) {
        _nameController.value = TextEditingValue(
          text: normalizedSavedName,
          selection:
              TextSelection.collapsed(offset: normalizedSavedName.length),
        );
      }
      _initializedName = true;
    }

    final String currentInputName = _nameController.text.trim();
    final bool hasSavedName = normalizedSavedName.isNotEmpty;
    final bool canSaveName =
        currentInputName.isNotEmpty && currentInputName != normalizedSavedName;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              // Top Brand Header
              Center(
                child: Column(
                  children: <Widget>[
                    const SizedBox(height: 12),
                    Container(
                      width: 68,
                      height: 68,
                      decoration: BoxDecoration(
                        color: palette.darkGreenBg,
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(
                          color: palette.darkGreenBorder,
                          width: 1.5,
                        ),
                      ),
                      child: Icon(
                        Icons.savings_rounded,
                        size: 36,
                        color: palette.darkGreen,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'Budget Buddy',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.6,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Smart offline budget & tab companion',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),

              // Sign In Card
              Container(
                clipBehavior: Clip.antiAlias,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: theme.cardTheme.color ?? theme.cardColor,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color:
                        theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Icon(
                          Icons.login_rounded,
                          size: 18,
                          color: palette.darkGreen,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Sign In',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: palette.darkGreenBg,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: palette.darkGreenBorder),
                          ),
                          child: Text(
                            'OFFLINE MODE',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              color: palette.darkGreen,
                              letterSpacing: 0.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Enter your name to sign in. Budget Buddy works completely offline without accounts or internet.',
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.colorScheme.onSurfaceVariant,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Name Display or Input Field
                    if (hasSavedName && !_isEditingName) ...<Widget>[
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: palette.darkGreenBg,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: palette.darkGreenBorder),
                        ),
                        child: Row(
                          children: <Widget>[
                            CircleAvatar(
                              radius: 18,
                              backgroundColor: palette.darkGreen,
                              child: Text(
                                _buildInitials(normalizedSavedName),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  Text(
                                    'Signed in as',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color:
                                          theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                  Text(
                                    normalizedSavedName,
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Icon(
                              Icons.check_circle_rounded,
                              color: palette.darkGreen,
                              size: 20,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Solid Gold Edit Button
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: palette.gold,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 13),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 0,
                          ),
                          onPressed: () {
                            setState(() {
                              _isEditingName = true;
                            });
                            _nameFocusNode.requestFocus();
                          },
                          icon: const Icon(Icons.edit_rounded, size: 16),
                          label: const Text(
                            'Edit Name',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ),
                    ] else ...<Widget>[
                      TextField(
                        controller: _nameController,
                        focusNode: _nameFocusNode,
                        textInputAction: TextInputAction.done,
                        onChanged: (String value) {
                          if (_nameError != null && value.trim().isNotEmpty) {
                            setState(() => _nameError = null);
                          } else if (mounted) {
                            setState(() {});
                          }
                        },
                        onSubmitted: (String value) {
                          if (_isEditingName) {
                            _handleSaveName(value, palette, state);
                          } else {
                            _handleSignIn(value, palette);
                          }
                        },
                        decoration: InputDecoration(
                          labelText: 'Your Name *',
                          hintText: 'Enter your name (required to sign in)',
                          errorText: _nameError,
                          prefixIcon: Icon(
                            Icons.badge_rounded,
                            color: _nameError != null
                                ? palette.darkRed
                                : palette.gold,
                            size: 20,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(
                              color: theme.colorScheme.outlineVariant
                                  .withValues(alpha: 0.4),
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(
                              color: palette.gold,
                              width: 1.6,
                            ),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 14,
                          ),
                        ),
                      ),
                      if (_isEditingName) ...<Widget>[
                        const SizedBox(height: 12),
                        Row(
                          children: <Widget>[
                            // Cancel Button: Full solid Dark Red
                            Expanded(
                              child: FilledButton.icon(
                                style: FilledButton.styleFrom(
                                  backgroundColor: palette.darkRed,
                                  foregroundColor: Colors.white,
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  elevation: 0,
                                ),
                                onPressed: () {
                                  _nameController.value = TextEditingValue(
                                    text: normalizedSavedName,
                                    selection: TextSelection.collapsed(
                                      offset: normalizedSavedName.length,
                                    ),
                                  );
                                  setState(() {
                                    _nameError = null;
                                    _isEditingName = false;
                                  });
                                },
                                icon: const Icon(Icons.close_rounded, size: 16),
                                label: const Text(
                                  'Cancel',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            // Save Button: Full solid Dark Green
                            Expanded(
                              child: FilledButton.icon(
                                style: FilledButton.styleFrom(
                                  backgroundColor: palette.darkGreen,
                                  foregroundColor: Colors.white,
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  elevation: 0,
                                ),
                                onPressed: canSaveName
                                    ? () => _handleSaveName(
                                          _nameController.text,
                                          palette,
                                          state,
                                        )
                                    : null,
                                icon: const Icon(Icons.save_rounded, size: 16),
                                label: const Text(
                                  'Save Name',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                    const SizedBox(height: 16),

                    // Feature highlights row with solid fill colors
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: _buildFeaturePill(
                            icon: Icons.wifi_off_rounded,
                            label: '100% Offline',
                            fillColor: palette.darkGreen,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildFeaturePill(
                            icon: Icons.security_rounded,
                            label: 'Private Data',
                            fillColor: palette.gold,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildFeaturePill(
                            icon: Icons.restart_alt_rounded,
                            label: 'Reset 12 AM',
                            fillColor: palette.darkRed,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),

                    // Solid Dark Green Action Button (Requires Name)
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: palette.darkGreen,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          elevation: 0,
                        ),
                        onPressed: () {
                          final String nameToUse = _isEditingName || !hasSavedName
                              ? _nameController.text
                              : normalizedSavedName;
                          _handleSignIn(nameToUse, palette);
                        },
                        icon: const Icon(Icons.login_rounded, size: 18),
                        label: const Text(
                          'Sign In',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Cloud & Accounts (Upcoming) Card
              Container(
                clipBehavior: Clip.antiAlias,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.cardTheme.color ?? theme.cardColor,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color:
                        theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Icon(
                          Icons.cloud_sync_rounded,
                          size: 16,
                          color: palette.gold,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Cloud & Sync',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: palette.goldBg,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: palette.goldBorder),
                          ),
                          child: Text(
                            'COMING SOON',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              color: palette.gold,
                              letterSpacing: 0.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Multi-device synchronization and online cloud backups are currently in active development.',
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.colorScheme.onSurfaceVariant,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            onPressed: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Online account sync is coming in a future update!',
                                  ),
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            },
                            child: const Text('Register Account'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            onPressed: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Online account sync is coming in a future update!',
                                  ),
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            },
                            child: const Text('Sign In to Account'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFeaturePill({
    required IconData icon,
    required String label,
    required Color fillColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 4),
      decoration: BoxDecoration(
        color: fillColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 18, color: Colors.white),
          const SizedBox(height: 5),
          Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              letterSpacing: -0.2,
            ),
          ),
        ],
      ),
    );
  }
}
