import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:libu_care/core/db/app_database.dart';
import 'package:libu_care/core/providers/core_providers.dart';
import 'package:libu_care/features/profile/data/datasources/profile_local_datasource.dart';
import 'package:libu_care/features/profile/data/models/patient_profile_model.dart';
import 'package:libu_care/features/profile/presentation/settings/settings_screen.dart';

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
    await ProfileLocalDatasource(
      db,
    ).saveProfile(userId, const PatientProfileModel(preferredLanguage: 'en'));
  });

  tearDown(() => db.close());

  List<Override> overrides() {
    final fakeDio = FakeDio();
    fakeDio.stubAll(FakeResponse.offline());
    return <Override>[
      appDatabaseProvider.overrideWithValue(db),
      dioProvider.overrideWithValue(fakeDio.dio),
      connectivityStreamProvider.overrideWithValue(const Stream<bool>.empty()),
      pendingSyncCountProvider.overrideWith((ref) => Stream<int>.value(0)),
    ];
  }

  testWidgets('shows the tap target that reports how many records are '
      'waiting to sync', (WidgetTester tester) async {
    await pumpApp(tester, const SettingsScreen(), overrides: overrides());

    expect(find.text('Up to date'), findsOneWidget);
  });

  testWidgets(
    'tapping a language switches the app locale immediately and persists '
    'the device-local choice (M2 Decision 5)',
    (WidgetTester tester) async {
      await pumpApp(tester, const SettingsScreen(), overrides: overrides());

      // Still English before the switch.
      expect(find.text('Settings'), findsOneWidget);

      await tester.tap(find.text('Language'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('አማርኛ'));
      // changeAppLanguage awaits real Drift I/O (LanguageStore.write), which
      // the fake-async zone a plain pump runs in cannot advance — the same
      // reason pumpApp itself uses runAsync for the initial locale load.
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pumpAndSettle();

      // The screen itself re-renders in the new language...
      expect(find.text('ቅንብሮች'), findsOneWidget);

      // ...and the switch is the device-local LanguageStore, not just the
      // in-memory locale — this is what makes it survive a relaunch.
      final stored = await db.preferencesDao.get(PreferenceKeys.language);
      expect(stored, 'am');
    },
  );
}
