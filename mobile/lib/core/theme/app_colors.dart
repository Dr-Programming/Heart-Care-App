import 'package:flutter/material.dart';

/// The Libu Care palette, read directly from the Figma file
/// (`B2D41kike6v4YRjHQMlszS`, section "LibuCare - Main Design").
///
/// These values are contractual: the design agreement is that colours and
/// fonts match exactly while layout is the implementer's latitude. Never
/// write a raw hex anywhere else in the app.
abstract final class AppColors {
  // Brand
  static const Color primary = Color(0xFFFCAB10);
  static const Color accent = Color(0xFF1D4ED8);

  // Clinical status
  static const Color success = Color(0xFF16A34A);
  static const Color warning = Color(0xFFD97706);
  static const Color critical = Color(0xFFDC2626);

  // Text
  static const Color ink = Color(0xFF282A2A);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color textTertiary = Color(0xFF9CA3AF);

  // Surfaces
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceAlt = Color(0xFFF5F6F8);
  static const Color headerBand = Color(0xFFDBD5B5);

  // Lines
  static const Color border = Color(0xFFEAEDF1);
  static const Color borderStrong = Color(0xFFD1D5DB);

  // Chip backgrounds
  static const Color successBg = Color(0xFFDCFCE7);
  static const Color warningBg = Color(0xFFFEF3C7);
  static const Color criticalBg = Color(0xFFFEE2E2);
  static const Color accentBg = Color(0xFFE8F0FE);
}
