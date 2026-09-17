import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:libu_care/app/app_wiring.dart';
import 'package:libu_care/core/db/app_database.dart';
import 'package:libu_care/core/localization/language.dart';
import 'package:libu_care/core/providers/core_providers.dart';
import 'package:libu_care/core/router/routes.dart';
import 'package:libu_care/core/security/token_store.dart';
import 'package:libu_care/core/shell/app_shell.dart';
import 'package:libu_care/core/theme/app_theme.dart';

import 'helpers/fake_dio.dart';
import 'helpers/fake_jwt.dart';
import 'helpers/fake_secure_storage.dart';
import 'helpers/pump_app.dart';
import 'helpers/test_database.dart';

/// Boots the real app - the real router, the real shell, the real wiring in
/// `app_wiring.dart` - and checks it lands somewhere usable.
///
/// This is the test that catches "the app does not start", which no amount of
/// unit testing will. It matters most while the five feature slices are
/// landing at different times: it proves the shell still runs with some, or
/// none, of them present.
///
/// Only the three providers that would reach a platform channel are replaced
/// (database file, HTTP client, connectivity). Everything else is the app.
void main() {
  setUpWidgetTests();

  late AppDatabase db;
  late FakeDio http;

  setUp(() {
    db = testDatabase();
    http = FakeDio();
    setUpFakeSecureStorage();
  });

  tearDown(() => db.close());

  /// Seeds a resolved, signed-in session directly through the real
  /// datasources — a chosen language, a cached user and a valid token — so a
  /// boot test can reach the shell without mocking `AuthGate` itself. This
  /// file deliberately exercises the real app, not a stub.
  Future<void> seedSignedInSession() async {
    await db.preferencesDao.set(PreferenceKeys.language, AppLanguage.en.code);
    await db.preferencesDao.set(PreferenceKeys.languageChosen, 'true');
    await db.cachedUserDao.save(
      CachedUsersCompanion.insert(
        id: 'u1',
        name: 'Abebe Girma',
        phone: '+251911234567',
        preferredLanguage: 'en',
        role: 'PATIENT',
      ),
    );
    const TokenStore tokenStore = TokenStore(FlutterSecureStorage());
    await tokenStore.write(
      fakeJwt(expiresAt: DateTime.now().add(const Duration(days: 7))),
    );
  }

  List<Override> bootOverrides() => <Override>[
    ...featureOverrides(),
    appDatabaseProvider.overrideWithValue(db),
    dioProvider.overrideWithValue(http.dio),
    isOnlineProvider.overrideWithValue(() async => false),
    connectivityStreamProvider.overrideWithValue(const Stream<bool>.empty()),
    onlineStatusProvider.overrideWith((Ref ref) => Stream<bool>.value(true)),
  ];

  Future<GoRouter> bootApp(WidgetTester tester) async {
    final ProviderContainer container = ProviderContainer(
      overrides: bootOverrides(),
    );
    addTearDown(container.dispose);

    final GoRouter router = container.read(routerProvider);

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
            useFallbackTranslations: true,
            child: Builder(
              builder: (BuildContext context) => MaterialApp.router(
                theme: AppTheme.light(context.locale.languageCode),
                localizationsDelegates: context.localizationDelegates,
                supportedLocales: context.supportedLocales,
                locale: context.locale,
                routerConfig: router,
              ),
            ),
          ),
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });

    await tester.pumpAndSettle(
      const Duration(milliseconds: 100),
      EnginePhase.sendSemanticsUpdate,
      const Duration(seconds: 10),
    );

    return router;
  }

  testWidgets('the app boots without throwing', (WidgetTester tester) async {
    await bootApp(tester);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'a fresh install with no language chosen lands on the language picker',
    (WidgetTester tester) async {
      final GoRouter router = await bootApp(tester);

      // M1's real AuthGate is wired in now, and a first-ever launch has
      // neither a chosen language nor a session — FR-LOC-003 sends it to the
      // picker before anything else, not Home.
      expect(
        router.routerDelegate.currentConfiguration.uri.path,
        AppRoutes.languagePath,
      );
    },
  );

  testWidgets('a signed-in session lands the user in the shell', (
    WidgetTester tester,
  ) async {
    await seedSignedInSession();
    final GoRouter router = await bootApp(tester);

    expect(
      router.routerDelegate.currentConfiguration.uri.path,
      AppRoutes.homePath,
    );
    expect(find.byType(AppShell), findsOneWidget);
  });

  testWidgets('every bottom-nav destination is reachable', (
    WidgetTester tester,
  ) async {
    await seedSignedInSession();
    await bootApp(tester);

    final Finder navBar = find.byType(NavigationBar);
    expect(navBar, findsOneWidget);
    expect(
      tester.widget<NavigationBar>(navBar).destinations.length,
      AppShell.tabs.length,
    );

    // Tabs whose slice has not landed yet must say so rather than crash or
    // show a blank screen.
    for (final ShellTab tab in AppShell.tabs.skip(1)) {
      await tester.tap(find.text(tab.labelKey.tr()));
      await tester.pumpAndSettle(
        const Duration(milliseconds: 100),
        EnginePhase.sendSemanticsUpdate,
        const Duration(seconds: 10),
      );
      expect(tester.takeException(), isNull, reason: tab.labelKey);
    }
  });

  testWidgets('boots in Amharic without falling back to Latin script', (
    WidgetTester tester,
  ) async {
    await pumpApp(
      tester,
      const SizedBox.shrink(),
      overrides: bootOverrides(),
      language: AppLanguage.am,
    );

    // The nav labels are the most-seen strings in the app; if these are still
    // English, the Amharic bundle did not load.
    expect('nav.home'.tr(), isNot('Home'));
    expect('nav.medications'.tr(), isNot('Medicines'));
  });
}
