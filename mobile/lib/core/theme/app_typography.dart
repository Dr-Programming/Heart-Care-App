import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

/// Poppins is the design font, but it ships **no Ethiopic glyphs** — Amharic
/// text rendered in Poppins comes out as tofu. The Figma file never exposed
/// this because it labels the language option "Amharic" in Latin script.
///
/// So: Latin locales get Poppins exactly as designed; the Amharic locale gets
/// Noto Sans Ethiopic. This is an addition for a script the design font cannot
/// draw, not a substitution of the design font.
abstract final class AppTypography {
  static TextTheme textTheme(String languageCode) {
    final TextTheme base = languageCode == 'am'
        ? GoogleFonts.notoSansEthiopicTextTheme()
        : GoogleFonts.poppinsTextTheme();

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
