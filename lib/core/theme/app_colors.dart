import 'package:flutter/material.dart';

/// Tokens mirrored from the web Tailwind config and src/index.css.
abstract final class AppColors {
  static const primary = Color(0xFF3C83FC);
  static const primary50 = Color(0xFFEFF6FF);
  static const primary100 = Color(0xFFDBEAFE);
  static const primary200 = Color(0xFFBFDBFE);
  static const primary400 = Color(0xFF60A5FA);
  static const primary600 = Color(0xFF2563EB);

  static const textDark = Color(0xFF1F2937);
  static const textMuted = Color(0xFF6B7280);
  static const textLight = Color(0xFF9CA3AF);
  static const surfaceLight = Color(0xFFF8FAFC);
  static const card = Color(0xFFFFFFFF);

  static const navy = Color(0xFF0B156F);
  static const teal = Color(0xFF11BED4);
  static const spark = Color(0xFFBFE038);
  static const success = Color(0xFF10B981);
  static const warning = Color(0xFFF59E0B);
  static const destructive = Color(0xFFEF4444);
  static const aiPurple = Color(0xFF906CE5);
  static const pink = Color(0xFFEF6191);
  static const orange = Color(0xFFFA8938);

  static const lightBackground = Color(0xFFF4F7FA);
  static const lightForeground = Color(0xFF0F1729);
  static const lightSecondary = Color(0xFFE9EFF7);
  static const lightMuted = Color(0xFFE6ECF4);
  static const lightMutedForeground = Color(0xFF434D60);
  static const lightBorder = Color(0xFFC4CFDE);

  static const darkBackground = Color(0xFF0E121B);
  static const darkForeground = Color(0xFFF1F5F9);
  static const darkCard = Color(0xFF161B27);
  static const darkSecondary = Color(0xFF1B202C);
  static const darkBorder = Color(0xFF2D3443);

  /// Context-aware semantic colours for custom widgets that sit outside
  /// Material's built-in Card/Input themes.
  static bool isDark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

  static Color onSurface(BuildContext context) =>
      Theme.of(context).colorScheme.onSurface;

  static Color mutedText(BuildContext context) =>
      isDark(context) ? const Color(0xFFCBD5E1) : textMuted;

  static Color subtleText(BuildContext context) =>
      isDark(context) ? const Color(0xFF94A3B8) : textLight;

  static Color surface(BuildContext context) =>
      Theme.of(context).colorScheme.surface;

  static Color secondarySurface(BuildContext context) =>
      isDark(context) ? darkSecondary : lightSecondary;

  static Color border(BuildContext context) =>
      isDark(context) ? darkBorder : lightBorder;

  static Color shadow(BuildContext context, {double alpha = 0.05}) =>
      (isDark(context) ? Colors.black : const Color(0xFF12213B)).withValues(
        alpha: isDark(context) ? alpha * 2 : alpha,
      );
}
