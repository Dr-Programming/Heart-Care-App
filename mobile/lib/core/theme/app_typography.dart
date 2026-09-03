import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Poppins is the design font and is now **bundled** as a pubspec asset, so
/// Latin text renders in Poppins offline — no runtime font fetch.
///
/// Poppins ships **no Ethiopic glyphs**, so Amharic text rendered in Poppins
/// alone comes out as tofu. Every style therefore carries a
/// `fontFamilyFallback` of `Noto Sans Ethiopic` (also bundled): Latin always
/// draws from Poppins, and the Ethiopic fallback fills in the glyphs Poppins
/// cannot. This is script coverage, not a substitution of the design font, and
/// it is locale-independent — the fallback engages per-glyph, not per-locale.
abstract final class AppTypography {
  /// [languageCode] is retained for future locale-specific metrics (callers
  /// pass `context.locale.languageCode`); the Ethiopic fallback is
  /// locale-independent so it is currently unused.
  static TextTheme textTheme(String languageCode) {
    final TextTheme base = Typography.material2021().black.apply(
      fontFamily: 'Poppins',
      fontFamilyFallback: const <String>['Noto Sans Ethiopic'],
    );

    return base.copyWith(
      displayLarge: base.displayLarge?.copyWith(
          fontSize: 30, fontWeight: FontWeight.w700, color: AppColors.ink),
      headlineLarge: base.headlineLarge?.copyWith(
          fontSize: 24, fontWeight: FontWeight.w700, color: AppColors.ink),
      headlineMedium: base.headlineMedium?.copyWith(
          fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.ink),
      titleMedium: base.titleMedium?.copyWith(
          fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.ink),
      bodyLarge: base.bodyLarge?.copyWith(
          fontSize: 14, fontWeight: FontWeight.w400, color: AppColors.ink),
      bodyMedium: base.bodyMedium?.copyWith(
          fontSize: 12, fontWeight: FontWeight.w400, color: AppColors.textSecondary),
      bodySmall: base.bodySmall?.copyWith(
          fontSize: 12, fontWeight: FontWeight.w400, color: AppColors.textSecondary),
      labelSmall: base.labelSmall?.copyWith(
          fontSize: 11, fontWeight: FontWeight.w400, color: AppColors.textTertiary),
    );
  }
}
