import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:libu_care/core/theme/app_colors.dart';
import 'package:libu_care/core/theme/app_theme.dart';

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    GoogleFonts.config.allowRuntimeFetching = false;

    // Under `flutter test` google_fonts can neither fetch nor find a bundled
    // Poppins / Noto Sans Ethiopic file, so for every requested family it logs a
    // multi-line "unable to load font" block via debugPrint. The requested
    // family name is still stamped onto the TextStyle (the assertions below rely
    // on exactly that), so the block is pure noise. Filter that one block and
    // pass every other message straight through, keeping test output pristine.
    final superPrint = debugPrint;
    var inGoogleFontsNoise = false;
    debugPrint = (String? message, {int? wrapWidth}) {
      if (message != null &&
          message.contains('google_fonts was unable to load font')) {
        inGoogleFontsNoise = true;
        return;
      }
      if (inGoogleFontsNoise) {
        if (message == null ||
            message.contains('github.com/flutter/flutter/issues/new/choose')) {
          inGoogleFontsNoise = false;
        }
        return;
      }
      superPrint(message, wrapWidth: wrapWidth);
    };
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

    test('English uses Poppins', () {
      final theme = AppTheme.light('en');
      expect(theme.textTheme.bodyMedium!.fontFamily, contains('Poppins'));
    });

    test('Amharic falls back to an Ethiopic-capable family, because Poppins '
        'has no Ethiopic glyphs', () {
      final theme = AppTheme.light('am');
      expect(theme.textTheme.bodyMedium!.fontFamily, contains('Noto'));
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
