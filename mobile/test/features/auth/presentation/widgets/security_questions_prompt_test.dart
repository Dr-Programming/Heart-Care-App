import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:libu_care/core/db/app_database.dart';
import 'package:libu_care/core/providers/core_providers.dart';
import 'package:libu_care/core/router/routes.dart';
import 'package:libu_care/features/auth/auth_providers.dart';
import 'package:libu_care/features/auth/presentation/widgets/security_questions_prompt.dart';

import '../../../../helpers/fake_pin_repository.dart';
import '../../../../helpers/pump_app.dart';
import '../../../../helpers/test_database.dart';

void main() {
  setUpWidgetTests();

  late FakePinRepository repo;
  late AppDatabase db;

  Future<void> pump(WidgetTester tester, {bool? configured}) async {
    repo = FakePinRepository()..status = configured;
    db = testDatabase();
    addTearDown(db.close);
    await pumpApp(
      tester,
      const SecurityQuestionsPrompt(),
      overrides: <Override>[
        pinRepositoryProvider.overrideWithValue(repo),
        appDatabaseProvider.overrideWithValue(db),
      ],
    );
    await tester.pumpAndSettle();
  }

  testWidgets('shown when the account has no security questions', (
    tester,
  ) async {
    await pump(tester, configured: false);

    expect(find.text('auth.securityPrompt.title'.tr()), findsOneWidget);
    expect(find.text('auth.securityPrompt.setUp'.tr()), findsOneWidget);
    expect(find.text('auth.securityPrompt.later'.tr()), findsOneWidget);
  });

  testWidgets('hidden when they are already set', (tester) async {
    await pump(tester, configured: true);
    expect(find.text('auth.securityPrompt.title'.tr()), findsNothing);
  });

  testWidgets('hidden when the status is unknown (offline)', (tester) async {
    await pump(tester, configured: null);
    expect(find.text('auth.securityPrompt.title'.tr()), findsNothing);
  });

  testWidgets('Later hides it and remembers that choice', (tester) async {
    await pump(tester, configured: false);

    await tester.tap(find.text('auth.securityPrompt.later'.tr()));
    await tester.pumpAndSettle();

    expect(find.text('auth.securityPrompt.title'.tr()), findsNothing);
    expect(
      await db.preferencesDao.get(
        PreferenceKeys.securityQuestionsPromptDismissed,
      ),
      'true',
    );
  });

  testWidgets('stays hidden once dismissed', (tester) async {
    repo = FakePinRepository()..status = false;
    db = testDatabase();
    addTearDown(db.close);
    await db.preferencesDao.set(
      PreferenceKeys.securityQuestionsPromptDismissed,
      'true',
    );
    await pumpApp(
      tester,
      const SecurityQuestionsPrompt(),
      overrides: <Override>[
        pinRepositoryProvider.overrideWithValue(repo),
        appDatabaseProvider.overrideWithValue(db),
      ],
    );
    await tester.pumpAndSettle();

    expect(find.text('auth.securityPrompt.title'.tr()), findsNothing);
  });

  testWidgets('Set up opens the security questions screen', (tester) async {
    repo = FakePinRepository()..status = false;
    db = testDatabase();
    addTearDown(db.close);
    await pumpApp(
      tester,
      MaterialApp.router(
        routerConfig: GoRouter(
          initialLocation: '/home',
          routes: <RouteBase>[
            GoRoute(
              path: '/home',
              builder: (BuildContext _, GoRouterState _) =>
                  const Scaffold(body: SecurityQuestionsPrompt()),
            ),
            GoRoute(
              path: AppRoutes.securityQuestionsPath,
              name: AppRoutes.securityQuestions,
              builder: (BuildContext _, GoRouterState _) =>
                  const Scaffold(body: Text('security questions destination')),
            ),
          ],
        ),
      ),
      overrides: <Override>[
        pinRepositoryProvider.overrideWithValue(repo),
        appDatabaseProvider.overrideWithValue(db),
      ],
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('auth.securityPrompt.setUp'.tr()));
    await tester.pumpAndSettle();

    expect(find.text('security questions destination'), findsOneWidget);
  });
}
