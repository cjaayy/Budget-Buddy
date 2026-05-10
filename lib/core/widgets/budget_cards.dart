import 'package:flutter/material.dart';

class BudgetMetricCard extends StatelessWidget {
  const BudgetMetricCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    this.subtitle,
    this.onTap,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final String? subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final bool compact =
            constraints.maxHeight < 130 || constraints.maxWidth < 150;
        final EdgeInsets padding =
            compact ? const EdgeInsets.all(12) : const EdgeInsets.all(16);
        final double iconPadding = compact ? 8 : 10;
        final double iconSize = compact ? 18 : 24;
        final double iconBoxSize = compact ? 32 : 40;
        final double topGap = compact ? 10 : 16;
        final double labelGap = compact ? 2 : 6;
        final double subtitleGap = compact ? 2 : 4;
        final double contentWidth =
            constraints.maxWidth.isFinite ? constraints.maxWidth : 0.0;

        return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(24),
            child: Container(
              padding: padding,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: <Color>[
                    color.withValues(alpha: 0.92),
                    color.withValues(alpha: 0.72)
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                      color: color.withValues(alpha: 0.22),
                      blurRadius: 24,
                      offset: const Offset(0, 12)),
                ],
              ),
              child: ClipRect(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.topLeft,
                  child: SizedBox(
                    width: contentWidth,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Row(
                          children: <Widget>[
                            Container(
                              width: iconBoxSize,
                              height: iconBoxSize,
                              padding: EdgeInsets.all(iconPadding),
                              decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.18),
                                  shape: BoxShape.circle),
                              child: Icon(icon,
                                  size: iconSize, color: Colors.white),
                            ),
                            const Spacer(),
                            if (onTap != null)
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: <Widget>[
                                  Text(
                                    'Details',
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelMedium
                                        ?.copyWith(
                                          color: Colors.white
                                              .withValues(alpha: 0.88),
                                          fontWeight: FontWeight.w700,
                                        ),
                                  ),
                                  const SizedBox(width: 4),
                                  Icon(
                                    Icons.chevron_right_rounded,
                                    size: compact ? 18 : 20,
                                    color: Colors.white.withValues(alpha: 0.88),
                                  ),
                                ],
                              ),
                          ],
                        ),
                        SizedBox(height: topGap),
                        Text(
                          label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: (compact
                                  ? Theme.of(context).textTheme.labelMedium
                                  : Theme.of(context).textTheme.labelLarge)
                              ?.copyWith(
                                  color: Colors.white.withValues(alpha: 0.85)),
                        ),
                        SizedBox(height: labelGap),
                        Text(
                          value,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: (compact
                                  ? Theme.of(context).textTheme.titleMedium
                                  : Theme.of(context).textTheme.headlineSmall)
                              ?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (subtitle != null) ...<Widget>[
                          SizedBox(height: subtitleGap),
                          Text(
                            subtitle!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: (compact
                                    ? Theme.of(context).textTheme.bodySmall
                                    : Theme.of(context).textTheme.bodySmall)
                                ?.copyWith(
                              color: Colors.white.withValues(alpha: 0.82),
                              fontSize: compact ? 10.5 : null,
                            ),
                          ),
                        ],
                        if (onTap != null) ...<Widget>[
                          SizedBox(height: compact ? 8 : 12),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: TextButton.icon(
                              onPressed: onTap,
                              style: TextButton.styleFrom(
                                foregroundColor: Colors.white,
                                padding: EdgeInsets.zero,
                                visualDensity: VisualDensity.compact,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              icon:
                                  const Icon(Icons.touch_app_rounded, size: 16),
                              label: const Text('Tap for details'),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class SectionCard extends StatelessWidget {
  const SectionCard(
      {super.key,
      required this.child,
      this.padding = const EdgeInsets.all(16)});

  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(padding: padding, child: child),
    );
  }
}

class SoftPill extends StatelessWidget {
  const SoftPill(
      {super.key, required this.text, required this.color, this.icon});

  final String text;
  final Color color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (icon != null) ...<Widget>[
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 6),
          ],
          Text(text,
              style: TextStyle(color: color, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
