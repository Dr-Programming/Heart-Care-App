import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libu_care/core/db/app_database.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  group('CachedUserDao', () {
    test('returns null before anything is cached', () async {
      expect(await db.cachedUserDao.current(), isNull);
    });

    test('round-trips the cached user', () async {
      await db.cachedUserDao.save(
        const CachedUsersCompanion(
          id: Value('3f2a9c1e-5b7d-4e8a-9f01-2c3d4e5f6a7b'),
          name: Value('Abebe Bekele'),
          phone: Value('+251911234567'),
          preferredLanguage: Value('am'),
          role: Value('PATIENT'),
        ),
      );

      final user = await db.cachedUserDao.current();
      expect(user!.name, 'Abebe Bekele');
      expect(user.phone, '+251911234567');
      expect(user.preferredLanguage, 'am');
    });

    test(
      'save replaces rather than accumulates, so only one user is ever cached',
      () async {
        await db.cachedUserDao.save(
          const CachedUsersCompanion(
            id: Value('user-1'),
            name: Value('First'),
            phone: Value('+251911111111'),
            preferredLanguage: Value('en'),
            role: Value('PATIENT'),
          ),
        );
        await db.cachedUserDao.save(
          const CachedUsersCompanion(
            id: Value('user-2'),
            name: Value('Second'),
            phone: Value('+251922222222'),
            preferredLanguage: Value('en'),
            role: Value('PATIENT'),
          ),
        );

        expect(await db.select(db.cachedUsers).get(), hasLength(1));
        expect((await db.cachedUserDao.current())!.name, 'Second');
      },
    );

    test('clear empties the cache on logout', () async {
      await db.cachedUserDao.save(
        const CachedUsersCompanion(
          id: Value('user-1'),
          name: Value('First'),
          phone: Value('+251911111111'),
          preferredLanguage: Value('en'),
          role: Value('PATIENT'),
        ),
      );
      await db.cachedUserDao.clear();
      expect(await db.cachedUserDao.current(), isNull);
    });
  });

  group('PreferencesDao', () {
    test('returns null for an unset key', () async {
      expect(await db.preferencesDao.get(PreferenceKeys.language), isNull);
    });

    test('round-trips and overwrites a preference', () async {
      await db.preferencesDao.set(PreferenceKeys.language, 'en');
      expect(await db.preferencesDao.get(PreferenceKeys.language), 'en');

      await db.preferencesDao.set(PreferenceKeys.language, 'am');
      expect(await db.preferencesDao.get(PreferenceKeys.language), 'am');
    });

    test('remove deletes a set key so a later get returns null', () async {
      await db.preferencesDao.set(PreferenceKeys.language, 'en');
      await db.preferencesDao.remove(PreferenceKeys.language);
      expect(await db.preferencesDao.get(PreferenceKeys.language), isNull);
    });

    test('remove on a key that was never set does not throw', () async {
      await db.preferencesDao.remove(PreferenceKeys.languageChosen);
      expect(
        await db.preferencesDao.get(PreferenceKeys.languageChosen),
        isNull,
      );
    });
  });

  test(
    'upgrading from v2 adds deactivated_at and backfills inactive rows',
    () async {
      final AppDatabase old = AppDatabase(
        NativeDatabase.memory(
          setup: (rawDb) {
            rawDb.execute('''
            CREATE TABLE medications (
              client_record_id TEXT NOT NULL PRIMARY KEY,
              server_id TEXT NULL,
              name TEXT NOT NULL,
              dose_mg REAL NOT NULL,
              frequency TEXT NOT NULL,
              schedule_times_json TEXT NOT NULL,
              active INTEGER NOT NULL DEFAULT 1,
              created_at INTEGER NOT NULL,
              updated_at INTEGER NOT NULL
            )''');
            rawDb.execute(
              "INSERT INTO medications VALUES ('on', NULL, 'A', 1, 'BID', '[]', 1, 100, 200)",
            );
            rawDb.execute(
              "INSERT INTO medications VALUES ('off', NULL, 'B', 1, 'BID', '[]', 0, 100, 300)",
            );
            rawDb.execute('PRAGMA user_version = 2');
          },
        ),
      );
      addTearDown(old.close);

      final List<Medication> rows = await old.select(old.medications).get();
      final Medication on = rows.firstWhere(
        (Medication m) => m.clientRecordId == 'on',
      );
      final Medication off = rows.firstWhere(
        (Medication m) => m.clientRecordId == 'off',
      );

      expect(on.deactivatedAt, isNull);
      expect(off.deactivatedAt, off.updatedAt);
    },
  );

  test(
    'clearPatientData removes one patient’s records but keeps device settings',
    () async {
      await db
          .into(db.medications)
          .insert(
            MedicationsCompanion.insert(
              clientRecordId: 'm1',
              name: 'Aspirin',
              doseMg: 75,
              frequency: 'ONCE_DAILY',
              scheduleTimesJson: '["08:00"]',
              createdAt: DateTime(2026, 9, 1),
              updatedAt: DateTime(2026, 9, 1),
            ),
          );
      await db
          .into(db.syncQueueEntries)
          .insert(
            SyncQueueEntriesCompanion.insert(
              clientRecordId: 'v1',
              entityType: 'VITAL',
              payloadJson: '{}',
              status: LocalSyncStatus.pending,
              recordedAt: DateTime(2026, 9, 1),
              createdLocallyAt: DateTime(2026, 9, 1),
            ),
          );
      await db.preferencesDao.set(PreferenceKeys.language, 'am');
      await db.preferencesDao.set('m3_pending_medication_edits', '["m1"]');

      await db.clearPatientData();

      expect(await db.select(db.medications).get(), isEmpty);
      expect(await db.select(db.syncQueueEntries).get(), isEmpty);
      expect(await db.preferencesDao.get(PreferenceKeys.language), 'am');
      expect(
        await db.preferencesDao.get('m3_pending_medication_edits'),
        isNull,
      );
    },
  );
}
