import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:libu_care/core/localization/language.dart';
import 'package:libu_care/core/providers/core_providers.dart';
import 'package:libu_care/core/router/routes.dart';
import 'package:libu_care/core/theme/app_theme.dart';
import 'package:libu_care/features/profile/presentation/screens/onboarding_screen.dart';

import '../../../../helpers/fake_dio.dart';
import '../../../../helpers/pump_app.dart';
import '../../../../helpers/test_database.dart';

Future<void> pumpOnboardingWithRouter(
  WidgetTester tester, {
  required List<Override> overrides,
}) async {
  final ProviderContainer container = ProviderContainer(overrides: overrides);
  addTearDown(container.dispose);

  final GoRouter router = GoRouter(
    initialLocation: AppRoutes.onboardingPath,
    routes: <RouteBase>[
      GoRoute(
        path: AppRoutes.onboardingPath,
        name: AppRoutes.onboarding,
        builder: (BuildContext context, GoRouterState state) =>
            const OnboardingScreen(),
      ),
      GoRoute(
        path: AppRoutes.homePath,
        name: AppRoutes.home,
        builder: (BuildContext context, GoRouterState state) =>
            const Scaffold(body: Center(child: Text('HOME_SCREEN_MARKER'))),
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
}

void main() {
  setUpWidgetTests();

  List<Override> baseOverrides() => <Override>[
    appDatabaseProvider.overrideWithValue(testDatabase()),
    dioProvider.overrideWithValue(FakeDio().dio),
    isOnlineProvider.overrideWithValue(() async => false),
  ];

  Finder birthYearField() => find.descendant(
    of: find.byKey(const Key('onboarding_birthYear_field')),
    matching: find.byType(TextField),
  );

  Finder nameField() => find.descendant(
    of: find.byKey(const Key('onboarding_name_field')),
    matching: find.byType(TextField),
  );

  Future<void> tapButton(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
  }

  testWidgets('the wizard advances and goes back with answers intact', (
    tester,
  ) async {
    await pumpApp(tester, const OnboardingScreen(), overrides: baseOverrides());

    await tester.enterText(birthYearField(), '1968');
    await tester.pump();
    await tapButton(tester, find.text('common.next'.tr()));
    await tester.pumpAndSettle();
    expect(find.text('profile.onboarding.step2Title'.tr()), findsOneWidget);

    await tapButton(tester, find.text('common.back'.tr()));
    await tester.pumpAndSettle();
    expect(find.text('1968'), findsOneWidget);
  });

  testWidgets('the name field is read-only and rejects edits', (tester) async {
    await pumpApp(tester, const OnboardingScreen(), overrides: baseOverrides());

    final TextField fieldBefore = tester.widget<TextField>(nameField());
    expect(fieldBefore.enabled, isFalse);
    final String prefilled = fieldBefore.controller!.text;

    await tester.enterText(nameField(), 'Someone Else');
    await tester.pump();

    expect(tester.widget<TextField>(nameField()).controller!.text, prefilled);
  });

  testWidgets('an invalid birth year blocks the step', (tester) async {
    await pumpApp(tester, const OnboardingScreen(), overrides: baseOverrides());

    await tester.enterText(birthYearField(), '1899');
    await tester.pump();
    await tapButton(tester, find.text('common.next'.tr()));
    await tester.pumpAndSettle();

    expect(find.text('profile.errors.birthYearRange'.tr()), findsOneWidget);
    expect(find.text('profile.onboarding.step2Title'.tr()), findsNothing);
  });

  testWidgets('renders correctly in Amharic', (tester) async {
    await pumpApp(
      tester,
      const OnboardingScreen(),
      overrides: baseOverrides(),
      language: AppLanguage.am,
    );
    expect(find.text('profile.onboarding.step1Title'.tr()), findsOneWidget);
  });

  testWidgets(
    'the diagnosis and comorbidities chip groups both render on step 2',
    (tester) async {
      await pumpApp(
        tester,
        const OnboardingScreen(),
        overrides: baseOverrides(),
      );

      await tapButton(tester, find.text('common.next'.tr()));
      await tester.pumpAndSettle();

      expect(find.text('Heart failure'), findsOneWidget);
      expect(find.text('Diabetes'), findsOneWidget);

      await tester.tap(find.text('Diabetes'));
      await tester.pump();

      await tapButton(tester, find.text('common.next'.tr()));
      await tester.pumpAndSettle();
      expect(find.text('profile.onboarding.step3Title'.tr()), findsOneWidget);
    },
  );

  testWidgets(
    'Skip is available on step 1 and finishes the wizard by leaving onboarding',
    (tester) async {
      await pumpOnboardingWithRouter(tester, overrides: baseOverrides());

      expect(find.text('common.skip'.tr()), findsOneWidget);
      await tapButton(tester, find.text('common.skip'.tr()));
      await tester.pumpAndSettle();

      expect(find.byType(OnboardingScreen), findsNothing);
      expect(find.text('HOME_SCREEN_MARKER'), findsOneWidget);
    },
  );

  testWidgets(
    'Finish setup on step 3 completes the wizard and leaves onboarding',
    (tester) async {
      await pumpOnboardingWithRouter(tester, overrides: baseOverrides());

      await tapButton(tester, find.text('common.next'.tr()));
      await tester.pumpAndSettle();
      await tapButton(tester, find.text('common.next'.tr()));
      await tester.pumpAndSettle();

      expect(find.text('profile.onboarding.finish'.tr()), findsOneWidget);
      await tapButton(tester, find.text('profile.onboarding.finish'.tr()));
      await tester.pumpAndSettle();

      expect(find.byType(OnboardingScreen), findsNothing);
      expect(find.text('HOME_SCREEN_MARKER'), findsOneWidget);
    },
  );
}
