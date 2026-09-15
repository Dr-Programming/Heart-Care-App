import 'package:drift/drift.dart' show Value;
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:libu_care/core/db/app_database.dart';
import 'package:libu_care/core/localization/language.dart';
import 'package:libu_care/core/providers/core_providers.dart';
import 'package:libu_care/core/router/routes.dart';
import 'package:libu_care/core/theme/app_theme.dart';
import 'package:libu_care/features/profile/presentation/screens/settings_screen.dart';

import '../../../../helpers/fake_dio.dart';
import '../../../../helpers/pump_app.dart';
import '../../../../helpers/test_database.dart';

Future<GoRouter> pumpSettingsWithRouter(
  WidgetTester tester, {
  required List<Override> overrides,
}) async {
  final ProviderContainer container = ProviderContainer(overrides: overrides);
  addTearDown(container.dispose);

  final GoRouter router = GoRouter(
    initialLocation: AppRoutes.settingsPath,
    routes: <RouteBase>[
      GoRoute(
        path: AppRoutes.settingsPath,
        name: AppRoutes.settings,
        builder: (BuildContext context, GoRouterState state) =>
            const SettingsScreen(),
      ),
      GoRoute(
        path: AppRoutes.loginPath,
        name: AppRoutes.login,
        builder: (BuildContext context, GoRouterState state) =>
            const Scaffold(body: Center(child: Text('LOGIN_SCREEN_MARKER'))),
      ),
    ],
  );

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
          startLocale: AppLanguage.en.locale,
          useFallbackTranslations: true,
          child: Builder(
            builder: (BuildContext context) => MaterialApp.router(
              routerConfig: router,
              theme: AppTheme.light(context.locale.languageCode),
              localizationsDelegates: context.localizationDelegates,
              supportedLocales: context.supportedLocales,
              locale: context.locale,
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

void _mockSecureStorageChannel() {
  final Map<String, String> store = <String, String>{};
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
        const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
        (MethodCall call) async {
          final Map<Object?, Object?> args =
              (call.arguments as Map<Object?, Object?>?) ??
              const <Object?, Object?>{};
          switch (call.method) {
            case 'write':
              store[args['key'] as String] = args['value'] as String;
              return null;
            case 'read':
              return store[args['key'] as String];
            case 'delete':
              store.remove(args['key'] as String);
              return null;
            case 'containsKey':
              return store.containsKey(args['key'] as String);
            default:
              return null;
          }
        },
      );
}

void main() {
  setUpWidgetTests();

  setUp(_mockSecureStorageChannel);

  Future<AppDatabase> seededDatabase() async {
    final AppDatabase db = testDatabase();
    await db.cachedUserDao.save(
      const CachedUsersCompanion(
        id: Value('u1'),
        name: Value('Test Patient'),
        phone: Value('+251911234567'),
        preferredLanguage: Value('en'),
        role: Value('PATIENT'),
      ),
    );
    return db;
  }

  testWidgets('tap targets on settings rows are at least 44dp', (tester) async {
    await pumpApp(
      tester,
      const SettingsScreen(),
      overrides: <Override>[
        appDatabaseProvider.overrideWithValue(await seededDatabase()),
        dioProvider.overrideWithValue(FakeDio().dio),
        isOnlineProvider.overrideWithValue(() async => false),
      ],
    );
    await tester.pumpAndSettle();

    expect(find.byType(ListTile), findsWidgets);
    for (final element in tester.widgetList<ListTile>(find.byType(ListTile))) {
      final box = tester.renderObject<RenderBox>(find.byWidget(element));
      expect(box.size.height, greaterThanOrEqualTo(44));
    }
  });

  testWidgets('no "Large text" row is present', (tester) async {
    await pumpApp(
      tester,
      const SettingsScreen(),
      overrides: <Override>[
        appDatabaseProvider.overrideWithValue(await seededDatabase()),
        dioProvider.overrideWithValue(FakeDio().dio),
        isOnlineProvider.overrideWithValue(() async => false),
      ],
    );
    await tester.pumpAndSettle();

    expect(find.text('Large text'), findsNothing);
  });

  testWidgets(
    'shows Language, Notifications, sync status, app version and Sign out rows',
    (tester) async {
      await pumpApp(
        tester,
        const SettingsScreen(),
        overrides: <Override>[
          appDatabaseProvider.overrideWithValue(await seededDatabase()),
          dioProvider.overrideWithValue(FakeDio().dio),
          isOnlineProvider.overrideWithValue(() async => false),
        ],
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('settings_language_row')), findsOneWidget);
      expect(
        find.byKey(const Key('settings_notifications_row')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('settings_sync_row')), findsOneWidget);
      expect(find.byKey(const Key('settings_app_version_row')), findsOneWidget);
      expect(find.byKey(const Key('settings_sign_out_row')), findsOneWidget);
      expect(find.byType(Switch), findsOneWidget);
    },
  );

  testWidgets(
    'switching the language to Amharic actually re-renders the screen in Amharic (C1, final review)',
    (tester) async {
      await pumpApp(
        tester,
        const SettingsScreen(),
        overrides: <Override>[
          appDatabaseProvider.overrideWithValue(await seededDatabase()),
          dioProvider.overrideWithValue(FakeDio().dio),
          isOnlineProvider.overrideWithValue(() async => false),
        ],
      );
      await tester.pumpAndSettle();

      expect(find.text('Notifications'), findsOneWidget);
      expect(find.text('ማሳወቂያዎች'), findsNothing);

      await tester.tap(find.byKey(const Key('settings_language_row')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('settings_language_option_am')));
      await tester.pump();
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 200));
      });
      await tester.pumpAndSettle(
        const Duration(milliseconds: 100),
        EnginePhase.sendSemanticsUpdate,
        const Duration(seconds: 10),
      );

      expect(find.text('ማሳወቂያዎች'), findsOneWidget);
      expect(find.text('Notifications'), findsNothing);
    },
  );

  testWidgets('tapping Language opens a picker of AppLanguage.values', (
    tester,
  ) async {
    await pumpApp(
      tester,
      const SettingsScreen(),
      overrides: <Override>[
        appDatabaseProvider.overrideWithValue(await seededDatabase()),
        dioProvider.overrideWithValue(FakeDio().dio),
        isOnlineProvider.overrideWithValue(() async => false),
      ],
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('settings_language_row')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('settings_language_option_en')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('settings_language_option_am')),
      findsOneWidget,
    );
  });

  testWidgets('signing out clears the session and navigates to login', (
    tester,
  ) async {
    final AppDatabase db = await seededDatabase();
    await db.preferencesDao.set('auth_needs_onboarding', 'true');

    final GoRouter router = await pumpSettingsWithRouter(
      tester,
      overrides: <Override>[
        appDatabaseProvider.overrideWithValue(db),
        dioProvider.overrideWithValue(FakeDio().dio),
        isOnlineProvider.overrideWithValue(() async => false),
      ],
    );

    await tester.tap(find.byKey(const Key('settings_sign_out_row')));
    await tester.pumpAndSettle();

    expect(
      find.text('profile.settings.signOut.confirmTitle'.tr()),
      findsOneWidget,
    );
    await tester.tap(
      find.widgetWithText(
        OutlinedButton,
        'profile.settings.signOut.confirmLabel'.tr(),
      ),
    );
    await tester.pumpAndSettle();

    expect(await db.cachedUserDao.current(), isNull);
    expect(await db.preferencesDao.get('auth_needs_onboarding'), isNull);
    expect(
      router.routerDelegate.currentConfiguration.uri.path,
      AppRoutes.loginPath,
    );
    expect(find.text('LOGIN_SCREEN_MARKER'), findsOneWidget);
  });
}
