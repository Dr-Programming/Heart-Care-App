import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:libu_care/core/db/app_database.dart';
import 'package:libu_care/core/legal/terms_store.dart';
import 'package:libu_care/core/localization/language.dart';
import 'package:libu_care/core/providers/core_providers.dart';
import 'package:libu_care/core/router/routes.dart';
import 'package:libu_care/core/theme/app_theme.dart';
import 'package:libu_care/features/auth/presentation/screens/terms_screen.dart';

import '../../../../helpers/pump_app.dart';
import '../../../../helpers/test_database.dart';

Future<void> _settle(WidgetTester tester) => tester.pumpAndSettle(
  const Duration(milliseconds: 100),
  EnginePhase.sendSemanticsUpdate,
  const Duration(seconds: 10),
);

void main() {
  setUpWidgetTests();

  group('TermsStore', () {
    test('nothing accepted on a new phone, accepted after accept()', () async {
      final AppDatabase db = testDatabase();
      addTearDown(db.close);
      final TermsStore store = TermsStore(db.preferencesDao);

      expect(await store.hasAccepted(), isFalse);
      await store.accept();
      expect(await store.hasAccepted(), isTrue);
    });

    test('an older accepted version must be agreed to again', () async {
      final AppDatabase db = testDatabase();
      addTearDown(db.close);
      await db.preferencesDao.set(
        PreferenceKeys.termsAcceptedVersion,
        '${currentTermsVersion - 1}',
      );

      expect(await TermsStore(db.preferencesDao).hasAccepted(), isFalse);
    });

    test('kept when a different patient signs in on the phone', () {
      expect(
        PreferenceKeys.deviceScoped,
        contains(PreferenceKeys.termsAcceptedVersion),
      );
    });
  });

  testWidgets('shows every section, and Continue waits for the checkbox', (
    tester,
  ) async {
    final AppDatabase db = testDatabase();
    addTearDown(db.close);
    await pumpApp(
      tester,
      const TermsScreen(),
      overrides: <Override>[appDatabaseProvider.overrideWithValue(db)],
    );

    expect(find.text('Before you start'), findsWidgets);
    for (final (String id, int _) in TermsScreen.sections) {
      expect(find.byKey(Key('terms_$id')), findsOneWidget, reason: id);
    }
    expect(find.textContaining('They never see your name'), findsOneWidget);

    final Finder button = find.byKey(const Key('termsContinueButton'));
    await tester.ensureVisible(button);
    await _settle(tester);
    await tester.tap(button);
    await _settle(tester);
    expect(await TermsStore(db.preferencesDao).hasAccepted(), isFalse);
  });

  testWidgets('the copy opened from Settings has no checkbox or button', (
    tester,
  ) async {
    final AppDatabase db = testDatabase();
    addTearDown(db.close);
    await pumpApp(
      tester,
      const TermsScreen(readOnly: true),
      overrides: <Override>[appDatabaseProvider.overrideWithValue(db)],
    );

    expect(find.byKey(const Key('terms_whoSees')), findsOneWidget);
    expect(find.byKey(const Key('termsAgreeCheckbox')), findsNothing);
    expect(find.byKey(const Key('termsContinueButton')), findsNothing);
  });

  testWidgets('renders in Amharic', (tester) async {
    final AppDatabase db = testDatabase();
    addTearDown(db.close);
    await pumpApp(
      tester,
      const TermsScreen(),
      language: AppLanguage.am,
      overrides: <Override>[appDatabaseProvider.overrideWithValue(db)],
    );

    expect(find.text('ከመጀመርዎ በፊት'), findsWidgets);
  });

  testWidgets('agreeing saves it and moves on to sign-in', (tester) async {
    final AppDatabase db = testDatabase();
    addTearDown(db.close);
    final ProviderContainer container = ProviderContainer(
      overrides: <Override>[appDatabaseProvider.overrideWithValue(db)],
    );
    addTearDown(container.dispose);

    final GoRouter router = GoRouter(
      initialLocation: AppRoutes.termsPath,
      routes: <RouteBase>[
        GoRoute(
          path: AppRoutes.termsPath,
          name: AppRoutes.terms,
          builder: (context, state) => const TermsScreen(),
        ),
        GoRoute(
          path: AppRoutes.loginPath,
          name: AppRoutes.login,
          builder: (context, state) => const Scaffold(body: Text('Login')),
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
    await _settle(tester);

    final Finder checkbox = find.byKey(const Key('termsAgreeCheckbox'));
    await tester.ensureVisible(checkbox);
    await _settle(tester);
    await tester.tap(checkbox);
    await _settle(tester);

    final Finder button = find.byKey(const Key('termsContinueButton'));
    await tester.ensureVisible(button);
    await _settle(tester);
    await tester.runAsync(() async {
      await tester.tap(button);
      await Future<void>.delayed(const Duration(milliseconds: 200));
    });
    await _settle(tester);

    expect(await TermsStore(db.preferencesDao).hasAccepted(), isTrue);
    expect(router.routerDelegate.currentConfiguration.uri.path, AppRoutes.loginPath);
  });
}
