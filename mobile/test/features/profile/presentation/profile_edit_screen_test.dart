import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:libu_care/core/db/app_database.dart';
import 'package:libu_care/core/providers/core_providers.dart';
import 'package:libu_care/features/profile/data/datasources/profile_local_datasource.dart';
import 'package:libu_care/features/profile/data/models/patient_profile_model.dart';
import 'package:libu_care/features/profile/presentation/profile/profile_edit_screen.dart';

import '../../../helpers/fake_dio.dart';
import '../../../helpers/pump_app.dart';
import '../../../helpers/test_database.dart';

/// [ProfileEditScreen] pops itself via `context.pop()` on a successful save,
/// which — unlike a plain `Navigator.pop()` — needs a real `GoRouter`
/// ancestor, so this uses [pumpRoutedApp] rather than plain `pumpApp`: a
/// stand-in "/" screen underneath, then a push to "/edit", exactly the shape
/// the real app produces via `context.pushNamed('profileEdit')` from
/// ProfileScreen.
Future<void> _pumpEditScreen(
  WidgetTester tester, {
  required List<Override> overrides,
}) async {
  final GoRouter router = await pumpRoutedApp(
    tester,
    initialLocation: '/',
    overrides: overrides,
    routes: [
      GoRoute(
        path: '/',
        builder: (BuildContext context, GoRouterState state) =>
            const Scaffold(body: SizedBox()),
      ),
      GoRoute(
        path: '/edit',
        builder: (BuildContext context, GoRouterState state) =>
            const ProfileEditScreen(),
      ),
    ],
  );

  router.push('/edit');
  await tester.pumpAndSettle();
}

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

  List<Override> overrides() {
    final fakeDio = FakeDio();
    fakeDio.stubAll(FakeResponse.offline());
    return <Override>[
      appDatabaseProvider.overrideWithValue(db),
      dioProvider.overrideWithValue(fakeDio.dio),
      connectivityStreamProvider.overrideWithValue(const Stream<bool>.empty()),
    ];
  }

  testWidgets(
    'saving after changing only the birth year preserves every other field '
    '(the full-replace trap the M2 spec warns about)',
    (WidgetTester tester) async {
      await ProfileLocalDatasource(db).saveProfile(
        userId,
        const PatientProfileModel(
          birthYear: 1965,
          heightCm: 172,
          chdStage: 'Stable angina',
          diseaseHistory: 'Diagnosed 2019',
          managementPlan: 'Aspirin, statin, cardiac rehab twice weekly',
          comorbidities: ['diabetes', 'a rare condition'],
        ),
      );

      await _pumpEditScreen(tester, overrides: overrides());

      // Sanity check: the management plan and the custom comorbidity did
      // load into the form, so this test can actually prove they survive.
      expect(
        find.text('Aspirin, statin, cardiac rehab twice weekly'),
        findsOneWidget,
      );
      expect(find.text('a rare condition'), findsOneWidget);

      await tester.enterText(
        find.widgetWithText(TextFormField, '1965').first,
        '1970',
      );
      await tester.tap(find.text('Save changes'));
      await tester.pumpAndSettle();

      final saved = await ProfileLocalDatasource(db).getProfile(userId);
      expect(saved.birthYear, 1970, reason: 'the field that was edited');
      expect(
        saved.managementPlan,
        'Aspirin, statin, cardiac rehab twice weekly',
        reason: 'must not be silently cleared by the full-replace save',
      );
      expect(saved.chdStage, 'Stable angina');
      expect(saved.diseaseHistory, 'Diagnosed 2019');
      expect(saved.comorbidities, ['diabetes', 'a rare condition']);
    },
  );

  testWidgets('prefills every field from the stored profile', (
    WidgetTester tester,
  ) async {
    await ProfileLocalDatasource(db).saveProfile(
      userId,
      const PatientProfileModel(
        birthYear: 1980,
        heightCm: 165,
        chdStage: 'CAD',
        managementPlan: 'Beta-blocker',
        comorbidities: ['hypertension'],
      ),
    );

    await _pumpEditScreen(tester, overrides: overrides());

    expect(find.text('1980'), findsOneWidget);
    expect(find.text('165.0'), findsOneWidget);
    expect(find.text('CAD'), findsOneWidget);
    expect(find.text('Beta-blocker'), findsOneWidget);
  });
}
