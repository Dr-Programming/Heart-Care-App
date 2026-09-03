import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libu_care/core/localization/language.dart';
import 'package:libu_care/core/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Call once in `setUpAll`. `easy_localization` persists the chosen locale
/// through shared_preferences, whose platform channel is absent in tests.
Future<void> initLocalization() async {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues(<String, Object>{});
  await EasyLocalization.ensureInitialized();
}

/// Pumps a screen inside the same localization + theme + provider stack the
/// real app uses.
///
/// The first `pumpWidget` runs inside `tester.runAsync` because
/// `easy_localization` reads its JSON through real asset I/O; on this Flutter
/// toolchain that future only completes in the real async zone, and without it
/// the second widget test in a file renders an empty `Localizations` subtree.
Future<void> pumpScreen(
  WidgetTester tester,
  Widget screen, {
  List<Override> overrides = const <Override>[],
}) async {
  // A tall logical surface (400 x 1400) so a scrollable screen lays its whole
  // body out and `tap()` can reach controls near the bottom.
  tester.view.physicalSize = const Size(1200, 4200);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);

  await tester.runAsync(() async {
    await tester.pumpWidget(
      EasyLocalization(
        supportedLocales:
            AppLanguage.values.map((AppLanguage l) => l.locale).toList(),
        path: 'assets/translations',
        fallbackLocale: AppLanguage.en.locale,
        child: ProviderScope(
          overrides: overrides,
          child: Builder(
            builder: (BuildContext context) => MaterialApp(
              theme: AppTheme.light(context.locale.languageCode),
              localizationsDelegates: context.localizationDelegates,
              supportedLocales: context.supportedLocales,
              locale: context.locale,
              home: screen,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  });
  await tester.pumpAndSettle();
}
