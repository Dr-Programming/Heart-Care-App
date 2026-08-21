import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:libu_care/core/theme/app_colors.dart';
import 'package:libu_care/core/theme/app_theme.dart';

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  group('AppColors', () {
    test('carries the exact Figma palette', () {
      expect(AppColors.primary, const Color(0xFFFCAB10));
      expect(AppColors.accent, const Color(0xFF1D4ED8));
      expect(AppColors.success, const Color(0xFF16A34A));
      expect(AppColors.warning, const Color(0xFFD97706));
      expect(AppColors.critical, const Color(0xFFDC2626));
      expect(AppColors.ink, const Color(0xFF282A2A));
      expect(AppColors.textSecondary, const Color(0xFF6B7280));
      expect(AppColors.textTertiary, const Color(0xFF9CA3AF));
      expect(AppColors.surface, const Color(0xFFFFFFFF));
      expect(AppColors.surfaceAlt, const Color(0xFFF5F6F8));
      expect(AppColors.headerBand, const Color(0xFFDBD5B5));
      expect(AppColors.border, const Color(0xFFEAEDF1));
    });
  });

  group('AppTheme', () {
    test('uses the brand amber as the primary colour', () {
      final theme = AppTheme.light('en');
      expect(theme.colorScheme.primary, AppColors.primary);
      expect(theme.scaffoldBackgroundColor, AppColors.surface);
    });

    test('English uses Poppins', () {
      final theme = AppTheme.light('en');
      expect(theme.textTheme.bodyMedium!.fontFamily, contains('Poppins'));
    });

    test('Amharic falls back to an Ethiopic-capable family, because Poppins '
        'has no Ethiopic glyphs', () {
      final theme = AppTheme.light('am');
      expect(theme.textTheme.bodyMedium!.fontFamily, contains('Noto'));
    });
  });
}
