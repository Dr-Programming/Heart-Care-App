import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:libu_care/core/localization/language.dart';
import 'package:libu_care/core/theme/app_theme.dart';

/// Call once at the top of any widget test's `main()`.
///
/// Three things have to be arranged before a widget test can run here, and
/// each of them fails in a way that is hard to read if you skip it:
///
///  * `EasyLocalization.ensureInitialized()` must run, or no translation ever
///    loads and every `find.text('Sign in')` finds nothing while the tree
///    renders the raw key;
///  * google_fonts otherwise tries to *download* Poppins at runtime, and the
///    pending request stops `pumpAndSettle` from ever settling — the test then
///    hangs until its timeout with no output at all;
///  * the logger is silenced so asset-loading chatter stays out of the report.
void setUpWidgetTests() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;
  // Untyped on purpose: the element type is `BuildMode` from easy_logger,
  // which is only a transitive dependency, so it is inferred from the setter.
  EasyLocalization.logger.enableBuildModes = const [];

  // easy_localization remembers the chosen locale in SharedPreferences, which
  // has no plugin implementation under `flutter test`. Answering the channel
  // with an empty store is enough, and is preferable to taking a direct
  // dependency on shared_preferences just for its test helper.
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/shared_preferences'),
        (MethodCall call) async =>
            call.method == 'getAll' ? <String, Object>{} : null,
      );

  setUpAll(() async => EasyLocalization.ensureInitialized());
}

/// Pumps [child] inside the same frame the real app gives it: a Riverpod
/// scope, easy_localization, and the themed `MaterialApp`.
///
/// ```dart
/// void main() {
///   setUpWidgetTests();
///
///   testWidgets('shows the phone field', (tester) async {
///     await pumpApp(tester, const LoginScreen(), overrides: [
///       authControllerProvider.overrideWith(FakeAuthController.new),
///     ]);
///     expect(find.text('Phone number'), findsOneWidget);
///   });
/// }
/// ```
///
/// Pass [language] to assert the Amharic rendering of a screen — worth doing
/// for anything with a fixed-width label, since Amharic is often longer.
Future<void> pumpApp(
  WidgetTester tester,
  Widget child, {
  List<Override> overrides = const <Override>[],
  AppLanguage language = AppLanguage.en,
}) async {
  // The container is created and disposed outside the widget tree on purpose.
  //
  // Drift schedules a zero-duration cleanup timer whenever a `watch` query is
  // cancelled. If a `ProviderScope` owned the container, that cancellation
  // would happen while the widget tree unmounts — inside the test's fake-async
  // zone — and the binding fails with "A Timer is still pending even after the
  // widget tree was disposed". Worse, the runner waits on that timer, so it
  // presents as a test that hangs with no output rather than one that fails.
  // Disposing in a tearDown moves the cancellation outside the zone.
  final ProviderContainer container = ProviderContainer(overrides: overrides);
  addTearDown(container.dispose);

  // easy_localization loads its JSON with real async I/O, which the fake-async
  // zone a widget test runs in cannot advance. Pumping it inside `runAsync`
  // lets the load actually finish. Without this the *first* pumpApp in a file
  // happens to work and every later one renders an empty tree, which is a
  // baffling failure to debug.
  await tester.runAsync(() async {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: EasyLocalization(
          supportedLocales: AppLanguage.values
              .map((AppLanguage l) => l.locale)
              .toList(growable: false),
          path: 'assets/translations',
          fallbackLocale: AppLanguage.en.locale,
          startLocale: language.locale,
          useFallbackTranslations: true,
          child: Builder(
            builder: (BuildContext context) => MaterialApp(
              theme: AppTheme.light(context.locale.languageCode),
              localizationsDelegates: context.localizationDelegates,
              supportedLocales: context.supportedLocales,
              locale: context.locale,
              home: child,
            ),
          ),
        ),
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 50));
  });

  // easy_localization loads asynchronously; settling gets past its loading
  // frame so the test sees real strings rather than an empty widget.
  //
  // The short timeout is deliberate. pumpAndSettle defaults to ten minutes,
  // so anything that never stops animating hangs the run with no output;
  // ten seconds turns that into a readable failure.
  await tester.pumpAndSettle(
    const Duration(milliseconds: 100),
    EnginePhase.sendSemanticsUpdate,
    const Duration(seconds: 10),
  );
}
