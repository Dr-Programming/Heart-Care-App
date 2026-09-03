import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libu_care/core/theme/app_colors.dart';
import 'package:libu_care/core/theme/app_theme.dart';

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  group('AppColors', () {
    test('carries the exact Figma palette', () {
      expect(AppColors.primary, const Color(0xFFFCAB10));
      expect(AppColors.accent, const Color(0xFF1D4ED8));
      expect(AppColors.critical, const Color(0xFFDC2626));
      expect(AppColors.ink, const Color(0xFF282A2A));
      expect(AppColors.textSecondary, const Color(0xFF6B7280));
      expect(AppColors.textTertiary, const Color(0xFF9CA3AF));
      expect(AppColors.surface, const Color(0xFFFFFFFF));
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

    test('English text renders in the bundled Poppins', () {
      final theme = AppTheme.light('en');
      expect(theme.textTheme.bodyMedium!.fontFamily, 'Poppins');
    });

    test('Amharic keeps Poppins for Latin but falls back to a bundled '
        'Ethiopic-capable family, because Poppins has no Ethiopic glyphs', () {
      final theme = AppTheme.light('am');
      expect(theme.textTheme.bodyMedium!.fontFamily, 'Poppins');
      expect(theme.textTheme.bodyMedium!.fontFamilyFallback,
          contains('Noto Sans Ethiopic'));
    });

    test('carries the contractual Figma type sizes', () {
      final text = AppTheme.light('en').textTheme;
      expect(text.headlineLarge!.fontSize, 24);
      expect(text.headlineLarge!.fontWeight, FontWeight.w700);
      expect(text.headlineMedium!.fontSize, 22);
      expect(text.headlineMedium!.fontWeight, FontWeight.w700);
      expect(text.titleMedium!.fontSize, 15);
      expect(text.titleMedium!.fontWeight, FontWeight.w700);
      expect(text.bodyMedium!.fontSize, 12);
      expect(text.bodyMedium!.fontWeight, FontWeight.w400);
    });
  });
}
