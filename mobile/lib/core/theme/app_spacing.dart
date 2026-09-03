/// Geometry measured from the Figma frames. A 402-pt-wide design with a ~30-pt
/// gutter gives a ~342-pt content column.
abstract final class AppSpacing {
  static const double gutter = 30;
  static const double fieldHeight = 52;
  static const double fieldRadius = 24;
  static const double buttonHeight = 52;
  static const double buttonRadius = 24;
  static const double pillHeight = 44;

  /// Header band + logo, measured off Figma frame `368:680` (402x874, ~214px
  /// band). 212 = logoTopInset (36) + logoHeight (160) + 16px cream below the
  /// mark, matching the frame's ~15px bottom slack; the logo sits top-aligned.
  static const double headerBandHeight = 212;
  static const double logoHeight = 160;
  static const double logoTopInset = 36;

  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
}
