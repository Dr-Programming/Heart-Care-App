import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:libu_care/core/db/app_database.dart';
import 'package:libu_care/core/providers/core_providers.dart';
import 'package:libu_care/features/profile/data/datasources/profile_local_datasource.dart';
import 'package:libu_care/features/profile/presentation/onboarding/onboarding_step1_screen.dart';
import 'package:libu_care/features/profile/presentation/onboarding/onboarding_step2_screen.dart';
import 'package:libu_care/features/profile/presentation/onboarding/onboarding_step3_screen.dart';

import '../../../helpers/fake_dio.dart';
import '../../../helpers/pump_app.dart';
import '../../../helpers/test_database.dart';

void main() {
  setUpWidgetTests();

  late AppDatabase db;
  const userId = 'u-1';

  setUp(() async {
    db = testDatabase();
    await db.cachedUserDao.save(
      const CachedUsersCompanion(
        id: Value(userId),
        name: Value('Abebe Bekele'),
        phone: Value('+251911234567'),
        preferredLanguage: Value('en'),
        role: Value('PATIENT'),
      ),
    );
  });

  tearDown(() => db.close());

  Future<GoRouter> pumpWizard(WidgetTester tester) async {
    final fakeDio = FakeDio();
    fakeDio.stubAll(FakeResponse.offline());
    final List<Override> overrides = <Override>[
      appDatabaseProvider.overrideWithValue(db),
      dioProvider.overrideWithValue(fakeDio.dio),
      connectivityStreamProvider.overrideWithValue(
        const Stream<bool>.empty(),
      ),
    ];

    return pumpRoutedApp(
      tester,
      initialLocation: '/onboarding',
      overrides: overrides,
      // Mirrors app_wiring.dart exactly: step-2 and step-3 are siblings
      // nested under /onboarding, not chained — the screens themselves
      // `context.push` the absolute paths, so the route tree has to match.
      routes: [
        GoRoute(
          path: '/onboarding',
          builder: (BuildContext context, GoRouterState state) =>
              const OnboardingStep1Screen(),
          routes: [
            GoRoute(
              path: 'step-2',
              builder: (BuildContext context, GoRouterState state) =>
                  const OnboardingStep2Screen(),
            ),
            GoRoute(
              path: 'step-3',
              builder: (BuildContext context, GoRouterState state) =>
                  const OnboardingStep3Screen(),
            ),
          ],
        ),
        GoRoute(
          path: '/home',
          builder: (BuildContext context, GoRouterState state) =>
              const Scaffold(body: Text('Home')),
        ),
      ],
    );
  }

  testWidgets('shows the name prefilled from the session, read-only', (
    WidgetTester tester,
  ) async {
    await pumpWizard(tester);

    expect(find.byKey(const ValueKey('onboarding-name')), findsOneWidget);
    expect(find.text('Abebe Bekele'), findsOneWidget);
  });

  testWidgets('an out-of-range birth year blocks the step', (
    WidgetTester tester,
  ) async {
    await pumpWizard(tester);

    await tester.enterText(
      find.widgetWithText(TextFormField, '').first,
      '1500',
    );
    await tester.tap(find.text('Next  →'));
    await tester.pumpAndSettle();

    // Still on step 1 — the invalid year kept the wizard from advancing.
    expect(find.text('Tell us about yourself'), findsOneWidget);
    expect(find.text('Medical profile'), findsNothing);
    expect(find.text('Birth year must be between 1900 and 2100'),
        findsOneWidget);
  });

  testWidgets(
    'advances through all three steps, goes back with answers intact, '
    'and finish writes the complete profile',
    (WidgetTester tester) async {
      final GoRouter router = await pumpWizard(tester);

      await tester.enterText(
        find.widgetWithText(TextFormField, '').first,
        '1965',
      );
      await tester.tap(find.text('Next  →'));
      await tester.pumpAndSettle();
      expect(find.text('Medical profile'), findsOneWidget);

      await tester.enterText(
        find.widgetWithText(TextFormField, 'e.g. Coronary artery disease')
            .first,
        'Stable angina',
      );
      await tester.tap(find.text('Next  →'));
      await tester.pumpAndSettle();
      expect(find.text('Your goals'), findsOneWidget);

      // Back to step 2, then step 1 — the entered values must still be
      // there, because `push` keeps each step's State alive underneath.
      router.pop();
      await tester.pumpAndSettle();
      expect(find.text('Stable angina'), findsOneWidget);

      router.pop();
      await tester.pumpAndSettle();
      expect(find.text('1965'), findsOneWidget);

      // Forward again, all the way to finish.
      await tester.tap(find.text('Next  →'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Next  →'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextFormField, 'e.g. 70').first,
        '78',
      );
      await settleAsync(tester);
      await tester.tap(find.text('Finish setup  →'));
      await settleAsync(tester);
      await tester.pumpAndSettle();

      final saved = await ProfileLocalDatasource(db).getProfile(userId);
      expect(saved.birthYear, 1965);
      expect(saved.chdStage, 'Stable angina');
      expect(saved.goals?.targetWeightKg, 78);
    },
  );

  testWidgets('skip still writes whatever was captured across steps 1-2', (
    WidgetTester tester,
  ) async {
    await pumpWizard(tester);

    await tester.enterText(
      find.widgetWithText(TextFormField, '').first,
      '1970',
    );
    await tester.tap(find.text('Next  →'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Next  →'));
    await tester.pumpAndSettle();

    await settleAsync(tester);
    await tester.tap(find.text('Skip for now'));
    await settleAsync(tester);
    await tester.pumpAndSettle();

    final saved = await ProfileLocalDatasource(db).getProfile(userId);
    expect(saved.birthYear, 1970);
    expect(saved.goals, isNull);
  });
}
