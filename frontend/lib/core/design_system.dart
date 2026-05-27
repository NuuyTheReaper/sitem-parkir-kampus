import 'package:flutter/material.dart';
import 'app_theme.dart';

/// Design System - Spacing, Layout, and Component Standards
class DesignSystem {
  // ═══════════════════════════════════════════════════════════
  // SPACING SYSTEM (8px base unit)
  // ═══════════════════════════════════════════════════════════
  static const double space0 = 0;
  static const double space1 = 4;
  static const double space2 = 8;
  static const double space3 = 12;
  static const double space4 = 16;
  static const double space5 = 20;
  static const double space6 = 24;
  static const double space7 = 28;
  static const double space8 = 32;
  static const double space10 = 40;
  static const double space12 = 48;
  static const double space16 = 64;
  static const double space20 = 80;

  // ═══════════════════════════════════════════════════════════
  // BORDER RADIUS
  // ═══════════════════════════════════════════════════════════
  static const double radiusXs = 6;
  static const double radiusSm = 8;
  static const double radiusMd = 12;
  static const double radiusLg = 16;
  static const double radiusXl = 20;
  static const double radius2xl = 24;
  static const double radiusFull = 9999;

  // ═══════════════════════════════════════════════════════════
  // ELEVATION & SHADOWS
  // ═══════════════════════════════════════════════════════════
  static List<BoxShadow> get shadowSm => [
        BoxShadow(
          color: AppTheme.slate900.withOpacity(0.04),
          blurRadius: 4,
          offset: const Offset(0, 1),
        ),
      ];

  static List<BoxShadow> get shadowMd => [
        BoxShadow(
          color: AppTheme.slate900.withOpacity(0.06),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ];

  static List<BoxShadow> get shadowLg => [
        BoxShadow(
          color: AppTheme.slate900.withOpacity(0.08),
          blurRadius: 16,
          offset: const Offset(0, 4),
        ),
      ];

  static List<BoxShadow> get shadowXl => [
        BoxShadow(
          color: AppTheme.slate900.withOpacity(0.1),
          blurRadius: 24,
          offset: const Offset(0, 8),
        ),
      ];

  // ═══════════════════════════════════════════════════════════
  // CARD COMPONENTS
  // ═══════════════════════════════════════════════════════════
  
  /// Standard card with border
  static BoxDecoration card({Color? color}) => BoxDecoration(
        color: color ?? Colors.white,
        borderRadius: BorderRadius.circular(radiusLg),
        border: Border.all(color: AppTheme.slate200, width: 1),
      );

  /// Elevated card with shadow
  static BoxDecoration cardElevated({Color? color}) => BoxDecoration(
        color: color ?? Colors.white,
        borderRadius: BorderRadius.circular(radiusLg),
        boxShadow: shadowMd,
      );

  /// Card with subtle background
  static BoxDecoration cardSubtle({Color? color}) => BoxDecoration(
        color: color ?? AppTheme.slate50,
        borderRadius: BorderRadius.circular(radiusLg),
        border: Border.all(color: AppTheme.slate200, width: 1),
      );

  /// Gradient card
  static BoxDecoration cardGradient({
    required List<Color> colors,
    AlignmentGeometry begin = Alignment.topLeft,
    AlignmentGeometry end = Alignment.bottomRight,
  }) =>
      BoxDecoration(
        gradient: LinearGradient(
          colors: colors,
          begin: begin,
          end: end,
        ),
        borderRadius: BorderRadius.circular(radiusLg),
        boxShadow: shadowMd,
      );

  // ═══════════════════════════════════════════════════════════
  // STAT CARD COMPONENT
  // ═══════════════════════════════════════════════════════════
  static Widget statCard({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
    String? subtitle,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(radiusLg),
      child: Container(
        padding: const EdgeInsets.all(space4),
        decoration: card(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(space2),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(radiusMd),
                  ),
                  child: Icon(icon, size: 20, color: color),
                ),
                const Spacer(),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.slate500,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: space3),
            Text(
              value,
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w700,
                color: AppTheme.slate900,
                letterSpacing: -1,
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: space1),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 11,
                  color: AppTheme.slate400,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // INFO CARD COMPONENT
  // ═══════════════════════════════════════════════════════════
  static Widget infoCard({
    required IconData icon,
    required String title,
    required String subtitle,
    Color? color,
    VoidCallback? onTap,
  }) {
    final cardColor = color ?? AppTheme.maroon;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(radiusLg),
      child: Container(
        padding: const EdgeInsets.all(space4),
        decoration: cardSubtle(),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(space3),
              decoration: BoxDecoration(
                color: cardColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(radiusMd),
              ),
              child: Icon(icon, size: 24, color: cardColor),
            ),
            const SizedBox(width: space3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.slate900,
                      letterSpacing: -0.2,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 13,
                      color: AppTheme.slate500,
                    ),
                  ),
                ],
              ),
            ),
            if (onTap != null)
              Icon(Icons.chevron_right_rounded,
                  color: AppTheme.slate400, size: 20),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // SECTION HEADER
  // ═══════════════════════════════════════════════════════════
  static Widget sectionHeader({
    required String title,
    String? subtitle,
    Widget? action,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: space3),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.slate900,
                    letterSpacing: -0.3,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 13,
                      color: AppTheme.slate500,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (action != null) action,
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // BADGE COMPONENT
  // ═══════════════════════════════════════════════════════════
  static Widget badge({
    required String label,
    required Color color,
    IconData? icon,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: icon != null ? space2 : space3,
        vertical: space1,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(radiusSm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: color),
            const SizedBox(width: space1),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // EMPTY STATE
  // ═══════════════════════════════════════════════════════════
  static Widget emptyState({
    required IconData icon,
    required String title,
    required String message,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(space8),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(space6),
              decoration: BoxDecoration(
                color: AppTheme.slate50,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 48, color: AppTheme.slate400),
            ),
            const SizedBox(height: space5),
            Text(
              title,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppTheme.slate900,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: space2),
            Text(
              message,
              style: TextStyle(
                fontSize: 14,
                color: AppTheme.slate500,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: space6),
              ElevatedButton(
                onPressed: onAction,
                child: Text(actionLabel),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // GRID LAYOUT HELPERS
  // ═══════════════════════════════════════════════════════════
  static Widget gridRow({
    required List<Widget> children,
    double spacing = space3,
  }) {
    return Row(
      children: [
        for (int i = 0; i < children.length; i++) ...[
          Expanded(child: children[i]),
          if (i < children.length - 1) SizedBox(width: spacing),
        ],
      ],
    );
  }

  static Widget gridColumn({
    required List<Widget> children,
    double spacing = space3,
  }) {
    return Column(
      children: [
        for (int i = 0; i < children.length; i++) ...[
          children[i],
          if (i < children.length - 1) SizedBox(height: spacing),
        ],
      ],
    );
  }
}
