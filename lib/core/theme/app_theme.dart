import 'package:doctylia_app/core/theme/app_colors.dart';
import 'package:doctylia_app/core/theme/app_spacing.dart';
import 'package:flutter/material.dart';

abstract final class AppTheme {
  static const _headingFont = 'Plus Jakarta Sans';
  static const _bodyFont = 'Inter';

  static ThemeData get light => _build(Brightness.light);
  static ThemeData get dark => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final colors = ColorScheme(
      brightness: brightness,
      primary: AppColors.primary,
      onPrimary: Colors.white,
      secondary: AppColors.teal,
      onSecondary: Colors.white,
      error: AppColors.destructive,
      onError: Colors.white,
      surface: isDark ? AppColors.darkCard : AppColors.card,
      onSurface: isDark ? AppColors.darkForeground : AppColors.lightForeground,
    );

    final baseTextTheme = isDark
        ? Typography.material2021().white
        : Typography.material2021().black;
    final bodyTextTheme = baseTextTheme.apply(fontFamily: _bodyFont);
    final textTheme = bodyTextTheme.copyWith(
      displayLarge: bodyTextTheme.displayLarge?.copyWith(
        fontFamily: _headingFont,
        fontWeight: FontWeight.w800,
      ),
      displayMedium: bodyTextTheme.displayMedium?.copyWith(
        fontFamily: _headingFont,
        fontWeight: FontWeight.w700,
      ),
      headlineLarge: bodyTextTheme.headlineLarge?.copyWith(
        fontFamily: _headingFont,
        fontWeight: FontWeight.w700,
      ),
      headlineMedium: bodyTextTheme.headlineMedium?.copyWith(
        fontFamily: _headingFont,
        fontWeight: FontWeight.w700,
      ),
      titleLarge: bodyTextTheme.titleLarge?.copyWith(
        fontFamily: _headingFont,
        fontWeight: FontWeight.w700,
      ),
      titleMedium: bodyTextTheme.titleMedium?.copyWith(
        fontFamily: _headingFont,
        fontWeight: FontWeight.w600,
      ),
    );

    final borderColor = isDark ? AppColors.darkBorder : AppColors.lightBorder;
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colors,
      scaffoldBackgroundColor: isDark
          ? AppColors.darkBackground
          : AppColors.lightBackground,
      fontFamily: _bodyFont,
      textTheme: textTheme,
      dividerColor: borderColor,
      iconTheme: IconThemeData(color: colors.onSurface),
      dialogTheme: DialogThemeData(
        backgroundColor: colors.surface,
        surfaceTintColor: Colors.transparent,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: colors.surface,
        modalBackgroundColor: colors.surface,
        surfaceTintColor: Colors.transparent,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: isDark ? const Color(0xFF263044) : AppColors.textDark,
        contentTextStyle: const TextStyle(color: Colors.white),
      ),
      listTileTheme: ListTileThemeData(
        textColor: colors.onSurface,
        iconColor: isDark ? AppColors.primary200 : AppColors.textMuted,
      ),
      dividerTheme: DividerThemeData(color: borderColor),
      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: colors.onSurface,
        titleTextStyle: textTheme.titleLarge?.copyWith(color: colors.onSurface),
      ),
      cardTheme: CardThemeData(
        color: colors.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          side: BorderSide(color: borderColor),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colors.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: borderColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: borderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
        labelStyle: TextStyle(
          color: isDark ? const Color(0xFFCBD5E1) : AppColors.textMuted,
        ),
        hintStyle: TextStyle(
          color: isDark ? const Color(0xFF94A3B8) : AppColors.textLight,
        ),
        prefixIconColor: isDark ? const Color(0xFF94A3B8) : AppColors.textMuted,
        suffixIconColor: isDark ? const Color(0xFF94A3B8) : AppColors.textMuted,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(48, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 72,
        backgroundColor: colors.surface,
        indicatorColor: isDark
            ? AppColors.primary.withValues(alpha: 0.22)
            : AppColors.primary100,
        labelTextStyle: WidgetStatePropertyAll(
          textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: colors.onSurface,
        unselectedLabelColor: isDark
            ? const Color(0xFFCBD5E1)
            : AppColors.textMuted,
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: colors.onSurface,
          side: BorderSide(color: borderColor),
        ),
      ),
    );
  }
}
