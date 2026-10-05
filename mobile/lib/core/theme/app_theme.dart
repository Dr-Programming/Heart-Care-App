import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_spacing.dart';
import 'app_typography.dart';

abstract final class AppTheme {
  static ThemeData light(String languageCode) {
    final TextTheme text = AppTypography.textTheme(languageCode);

    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: AppColors.surface,
      textTheme: text,
      colorScheme: const ColorScheme.light(
        primary: AppColors.primary,
        secondary: AppColors.accent,
        error: AppColors.critical,
        surface: AppColors.surface,
        onPrimary: AppColors.surface,
        onSurface: AppColors.ink,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        hintStyle: text.bodyLarge?.copyWith(color: AppColors.textTertiary),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.fieldRadius),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.fieldRadius),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.fieldRadius),
          borderSide: const BorderSide(color: AppColors.accent),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.fieldRadius),
          borderSide: const BorderSide(color: AppColors.critical),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.fieldRadius),
          borderSide: const BorderSide(color: AppColors.critical),
        ),
      ),
      // Every selectable chip looks the same: a pill, black when selected.
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.surfaceAlt,
        selectedColor: AppColors.ink,
        checkmarkColor: AppColors.surface,
        side: const BorderSide(color: AppColors.border),
        shape: const StadiumBorder(),
        labelStyle: text.bodyMedium?.copyWith(color: AppColors.ink),
        secondaryLabelStyle: text.bodyMedium?.copyWith(
          color: AppColors.surface,
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs,
        ),
      ),
      // Text links are the app's blue everywhere, not the orange primary.
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: AppColors.accent),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.surface,
          minimumSize: const Size.fromHeight(AppSpacing.buttonHeight),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.buttonRadius),
          ),
          textStyle: text.titleMedium,
        ),
      ),
    );
  }
}
