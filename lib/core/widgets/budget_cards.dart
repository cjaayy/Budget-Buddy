import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Clean Modern Flat Bento Card container with solid background and subtle 1px border.
/// No glassmorphism, no blur.
class BentoCard extends StatelessWidget {
  const BentoCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.borderRadius = 20,
    this.borderColor,
    this.backgroundColor,
    this.onTap,
  });

  final Widget child;
  final EdgeInsets padding;
  final double borderRadius;
  final Color? borderColor;
  final Color? backgroundColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color defaultBg =
        isDark ? const Color(0xFF111827) : const Color(0xFFFFFFFF);
    final Color defaultBorder =
        isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0);

    final Widget card = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: backgroundColor ?? defaultBg,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(
          color: borderColor ?? defaultBorder,
          width: 1.0,
        ),
      ),
      child: child,
    );

    if (onTap == null) {
      return card;
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(borderRadius),
        child: card,
      ),
    );
  }
}

/// Small Bento Tile with 12px border radius, high-contrast typography, and 10% alpha icon background.
class BentoMetricTile extends StatelessWidget {
  const BentoMetricTile({
    super.key,
    required this.label,
    required this.value,
    required this.accentColor,
    this.icon,
    this.subtitle,
    this.onTap,
  });

  final String label;
  final String value;
  final Color accentColor;
  final IconData? icon;
  final String? subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color cardBg =
        isDark ? const Color(0xFF111827) : const Color(0xFFFFFFFF);
    final Color cardBorder =
        isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0);
    final Color textSecondary =
        isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    final Widget content = Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cardBorder, width: 1.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Row(
            children: <Widget>[
              if (icon != null) ...<Widget>[
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.10),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, size: 14, color: accentColor),
                ),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: textSecondary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              maxLines: 1,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 17,
                fontWeight: FontWeight.w900,
                color: accentColor,
                letterSpacing: -0.4,
              ),
            ),
          ),
          if (subtitle != null) ...<Widget>[
            const SizedBox(height: 3),
            Text(
              subtitle!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: textSecondary,
              ),
            ),
          ],
        ],
      ),
    );

    if (onTap == null) {
      return content;
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: content,
      ),
    );
  }
}

/// Visual Health Bar / Progress Bar for Bento Cards
class BentoHealthBar extends StatelessWidget {
  const BentoHealthBar({
    super.key,
    required this.progress,
    required this.color,
    this.backgroundColor,
    this.height = 8,
  });

  final double progress;
  final Color color;
  final Color? backgroundColor;
  final double height;

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color defaultBg = backgroundColor ??
        (isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0));

    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: Container(
        height: height,
        width: double.infinity,
        color: defaultBg,
        child: FractionallySizedBox(
          alignment: Alignment.centerLeft,
          widthFactor: progress.clamp(0.0, 1.0),
          child: Container(
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
        ),
      ),
    );
  }
}

/// Upgraded BudgetMetricCard with Flat Bento styling and crisp Plus Jakarta Sans typography.
/// Retains backwards compatibility for other feature screens.
class BudgetMetricCard extends StatelessWidget {
  const BudgetMetricCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    this.subtitle,
    this.onTap,
    this.centerContent = false,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final String? subtitle;
  final VoidCallback? onTap;
  final bool centerContent;

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color cardBg =
        isDark ? const Color(0xFF111827) : const Color(0xFFFFFFFF);
    final Color cardBorder =
        isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0);
    final Color textSecondary =
        isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final bool compact =
            constraints.maxHeight < 130 || constraints.maxWidth < 150;
        final EdgeInsets padding =
            compact ? const EdgeInsets.all(12) : const EdgeInsets.all(16);
        final double iconPadding = compact ? 6 : 8;
        final double iconSize = compact ? 16 : 20;
        final double topGap = compact ? 8 : 12;

        return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(20),
            child: Container(
              padding: padding,
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: cardBorder, width: 1.0),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: centerContent
                    ? CrossAxisAlignment.center
                    : CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    mainAxisAlignment: centerContent
                        ? MainAxisAlignment.center
                        : MainAxisAlignment.start,
                    children: <Widget>[
                      Container(
                        padding: EdgeInsets.all(iconPadding),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.10),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(icon, size: iconSize, color: color),
                      ),
                      if (!centerContent) ...<Widget>[
                        const Spacer(),
                        if (onTap != null)
                          Icon(
                            Icons.arrow_forward_ios_rounded,
                            size: compact ? 12 : 14,
                            color: textSecondary,
                          ),
                      ],
                    ],
                  ),
                  SizedBox(height: topGap),
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign:
                        centerContent ? TextAlign.center : TextAlign.start,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: compact ? 11 : 12,
                      fontWeight: FontWeight.w600,
                      color: textSecondary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: centerContent
                        ? Alignment.center
                        : Alignment.centerLeft,
                    child: Text(
                      value,
                      maxLines: 1,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: compact ? 16 : 20,
                        fontWeight: FontWeight.w900,
                        color: color,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ),
                  if (subtitle != null) ...<Widget>[
                    const SizedBox(height: 3),
                    Text(
                      subtitle!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: centerContent
                          ? TextAlign.center
                          : TextAlign.start,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: textSecondary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Upgraded SectionCard with solid flat Bento styling.
class SectionCard extends StatelessWidget {
  const SectionCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.borderRadius = 20,
  });

  final Widget child;
  final EdgeInsets padding;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    return BentoCard(
      padding: padding,
      borderRadius: borderRadius,
      child: child,
    );
  }
}

/// Clean Pill component with alpha tinted background (0.10) and crisp text.
class SoftPill extends StatelessWidget {
  const SoftPill({
    super.key,
    required this.text,
    required this.color,
    this.icon,
    this.fontSize = 11,
  });

  final String text;
  final Color color;
  final IconData? icon;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.20), width: 1.0),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (icon != null) ...<Widget>[
            Icon(icon, size: fontSize + 2, color: color),
            const SizedBox(width: 4),
          ],
          Text(
            text,
            style: GoogleFonts.plusJakartaSans(
              fontSize: fontSize,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
