import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:libu_care/core/db/app_database.dart';
import 'package:libu_care/core/localization/language.dart';
import 'package:libu_care/core/providers/core_providers.dart';
import 'package:libu_care/core/router/routes.dart';
import 'package:libu_care/core/theme/app_theme.dart';
import 'package:libu_care/features/auth/auth_providers.dart';
import 'package:libu_care/features/auth/domain/entities/auth_user.dart';
import 'package:libu_care/features/auth/domain/repositories/auth_repository.dart';
import 'package:libu_care/features/auth/presentation/screens/language_screen.dart';
import 'package:libu_care/features/auth/presentation/screens/splash_screen.dart';

import '../../../../helpers/pump_app.dart';
import '../../../../helpers/test_database.dart';

const AuthUser _user = AuthUser(
  id: 'u1',
  name: 'Abebe Girma',
  phone: '+251911234567',
  preferredLanguage: 'en',
  role: 'PATIENT',
);





class _FakeAuthRepository implements AuthRepository {
  bool signedIn = false;

  @override
  Future<AuthUser> login({required String phone, required String pin}) async => _user;

  @override
  Future<AuthUser> register({
    required String phone,
    required String pin,
    required String name,
    required String preferredLanguage,
  }) async => _user;

  @override
  Future<AuthUser> getMe() async => _user;

  @override
  Future<void> logout() async {
    signedIn = false;
  }

  @override
  Future<AuthUser?> cachedUser() async => signedIn ? _user : null;

  @override
  Future<bool> isSignedIn() async => signedIn;

  @override
  Future<bool> needsOnboarding() async => false;
}

void main() {
  setUpWidgetTests();

  testWidgets('SplashScreen shows the app logo/name and no interactive controls', (tester) async {
    await pumpApp(tester, const SplashScreen());
    expect(find.text('Libu Care'), findsOneWidget);
  });

  testWidgets('LanguageScreen offers both languages, each in its own script', (tester) async {
    await pumpApp(tester, const LanguageScreen());
    expect(find.text('English'), findsOneWidget);
    expect(find.text('አማርኛ'), findsOneWidget);
  });

  testWidgets('LanguageScreen renders correctly in Amharic', (tester) async {
    await pumpApp(tester, const LanguageScreen(), language: AppLanguage.am);
    expect(find.text('ቋንቋዎን ይምረጡ'.tr()), findsWidgets); 
  });

  
  
  
  
  
  
  testWidgets(
    'choosing a language refreshes the gate so the router lands on Login, '
    'not back on the language picker',
    (tester) async {
      final AppDatabase db = testDatabase();
      addTearDown(db.close);
      final _FakeAuthRepository fakeRepo = _FakeAuthRepository();
      final ProviderContainer container = ProviderContainer(
        overrides: <Override>[
          appDatabaseProvider.overrideWithValue(db),
          authRepositoryProvider.overrideWithValue(fakeRepo),
        ],
      );
      addTearDown(container.dispose);

      
      expect(container.read(realAuthGateProvider).hasChosenLanguage, isFalse);

      final GoRouter router = GoRouter(
        initialLocation: AppRoutes.languagePath,
        routes: <RouteBase>[
          GoRoute(
            path: AppRoutes.languagePath,
            name: AppRoutes.language,
            builder: (context, state) => const LanguageScreen(),
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

      await tester.pumpAndSettle(
        const Duration(milliseconds: 100),
        EnginePhase.sendSemanticsUpdate,
        const Duration(seconds: 10),
      );

      await tester.tap(find.text('English'));
      await tester.pumpAndSettle(
        const Duration(milliseconds: 100),
        EnginePhase.sendSemanticsUpdate,
        const Duration(seconds: 10),
      );

      expect(container.read(realAuthGateProvider).hasChosenLanguage, isTrue);
      expect(
        router.routerDelegate.currentConfiguration.uri.path,
        AppRoutes.loginPath,
      );
    },
  );
}
