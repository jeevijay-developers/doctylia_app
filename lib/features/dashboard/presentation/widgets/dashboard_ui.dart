import 'package:doctylia_app/core/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn;

/// Visual tokens shared by the home dashboard widgets.
abstract final class DashboardTokens {
  static const radius = 16.0;
  static const innerRadius = 12.0;

  static const teal = Color(0xFF0EA5B7);
  static const tealDeep = Color(0xFF0B7F8F);
  static const blueDeep = Color(0xFF1D4ED8);

  /// Softer than [AppColors.border] so cards read crisp rather than boxed in.
  static Color border(BuildContext context) => AppColors.isDark(context)
      ? AppColors.darkBorder
      : const Color(0xFFDDE4EE);

  static List<BoxShadow> shadow(BuildContext context) => [
    BoxShadow(
      color: AppColors.shadow(context, alpha: 0.045),
      blurRadius: 16,
      offset: const Offset(0, 6),
    ),
    BoxShadow(
      color: AppColors.shadow(context, alpha: 0.03),
      blurRadius: 2,
      offset: const Offset(0, 1),
    ),
  ];

  static TextStyle eyebrow(BuildContext context) => TextStyle(
    color: AppColors.subtleText(context),
    fontSize: 10,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.6,
  );
}

/// The app runs on Material, so shadcn_flutter components need a shadcn
/// [shadcn.Theme] ancestor. This derives one from the active Material
/// brightness and the Doctylia colour tokens.
class DashboardShadcnScope extends StatelessWidget {
  const DashboardShadcnScope({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDark(context);
    final base = isDark
        ? shadcn.ColorSchemes.darkSlate
        : shadcn.ColorSchemes.lightSlate;
    final foreground = isDark
        ? AppColors.darkForeground
        : AppColors.lightForeground;
    final colorScheme = base.copyWith(
      background: () =>
          isDark ? AppColors.darkBackground : AppColors.lightBackground,
      foreground: () => foreground,
      card: () => isDark ? AppColors.darkCard : AppColors.card,
      cardForeground: () => foreground,
      primary: () => isDark ? AppColors.primary : AppColors.primary600,
      primaryForeground: () => Colors.white,
      secondary: () => AppColors.secondarySurface(context),
      secondaryForeground: () => foreground,
      muted: () => AppColors.secondarySurface(context),
      mutedForeground: () => AppColors.mutedText(context),
      accent: () => AppColors.secondarySurface(context),
      accentForeground: () => foreground,
      destructive: () => AppColors.destructive,
      border: () => DashboardTokens.border(context),
      input: () => DashboardTokens.border(context),
      ring: () => AppColors.primary,
    );
    return shadcn.Theme(
      data: shadcn.ThemeData(
        colorScheme: colorScheme,
        // radiusMd ~10px for buttons; cards set their own 16px radius.
        radius: 0.85,
        typography: const shadcn.Typography.geist(
          sans: TextStyle(fontFamily: 'Inter'),
        ),
      ),
      child: child,
    );
  }
}

/// A shadcn [shadcn.Card] with the dashboard radius, border and shadow, plus
/// an optional Material ink tap layered on top.
class DashboardSurface extends StatelessWidget {
  const DashboardSurface({
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
    this.fillColor,
    this.borderColor,
    super.key,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color? fillColor;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(DashboardTokens.radius);
    final card = shadcn.Card(
      padding: padding,
      borderRadius: radius,
      borderColor: borderColor ?? DashboardTokens.border(context),
      filled: fillColor != null,
      fillColor: fillColor,
      boxShadow: DashboardTokens.shadow(context),
      child: child,
    );
    if (onTap == null) return card;
    return Stack(
      children: [
        card,
        Positioned.fill(
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(onTap: onTap, borderRadius: radius),
          ),
        ),
      ],
    );
  }
}

class DashboardIconTile extends StatelessWidget {
  const DashboardIconTile({
    required this.icon,
    required this.color,
    this.size = 38,
    super.key,
  });

  final IconData icon;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [color.withValues(alpha: 0.14), color.withValues(alpha: 0.06)],
      ),
      borderRadius: BorderRadius.circular(size * 0.3),
      border: Border.all(color: color.withValues(alpha: 0.14)),
    ),
    child: Icon(icon, size: size * 0.46, color: color),
  );
}

/// A shadcn badge tinted with a semantic [color] (success, warning, ...).
class DashboardToneBadge extends StatelessWidget {
  const DashboardToneBadge({
    required this.label,
    required this.color,
    this.icon,
    this.showDot = false,
    super.key,
  });

  final String label;
  final Color color;
  final IconData? icon;
  final bool showDot;

  @override
  Widget build(BuildContext context) {
    final leading = icon != null
        ? Icon(icon, size: 12, color: color)
        : showDot
        ? Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          )
        : null;
    return shadcn.SecondaryBadge(
      leading: leading,
      style:
          const shadcn.ButtonStyle.secondary(
            size: shadcn.ButtonSize.small,
            density: shadcn.ButtonDensity.dense,
          ).copyWith(
            decoration: (context, states, value) => BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: color.withValues(alpha: 0.22)),
            ),
            textStyle: (context, states, value) => value.copyWith(
              color: color,
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
            ),
            iconTheme: (context, states, value) =>
                value.copyWith(color: color, size: 12),
          ),
      child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
    );
  }
}
