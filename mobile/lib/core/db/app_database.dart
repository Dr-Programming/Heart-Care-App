import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'daos/cached_user_dao.dart';
import 'daos/preferences_dao.dart';
import 'tables.dart';

export 'tables.dart';

part 'app_database.g.dart';

@DriftDatabase(
  tables: <Type>[
    CachedUsers,
    Preferences,
    PatientProfiles,
    Medications,
    DoseLogs,
    VitalsLogs,
    SymptomLogs,
    ActivityLogs,
    SyncQueueEntries,
  ],
  daos: <Type>[CachedUserDao, PreferencesDao],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.executor);

  @override
  int get schemaVersion => 3;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (Migrator m) => m.createAll(),

    onUpgrade: (Migrator m, int from, int to) async {
      if (from < 2) {
        await m.createTable(patientProfiles);
        await m.createTable(medications);
        await m.createTable(doseLogs);
        await m.createTable(vitalsLogs);
        await m.createTable(symptomLogs);
        await m.createTable(activityLogs);
        await m.createTable(syncQueueEntries);
      }
      if (from == 2) {
        await m.addColumn(medications, medications.deactivatedAt);
        // Best guess for medications already off: the last edit, which is
        // what the app used as the deactivation day until now.
        await customStatement(
          'UPDATE medications SET deactivated_at = updated_at WHERE active = 0',
        );
      }
    },
  );
}

extension PatientDataReset on AppDatabase {
  /// Removes everything recorded for the current patient — health records,
  /// the unsent sync queue and per-patient settings — so the next patient on
  /// this phone starts clean. Device settings such as the language stay.
  Future<void> clearPatientData() => transaction(() async {
    await delete(doseLogs).go();
    await delete(medications).go();
    await delete(vitalsLogs).go();
    await delete(symptomLogs).go();
    await delete(activityLogs).go();
    await delete(patientProfiles).go();
    await delete(syncQueueEntries).go();
    await (delete(preferences)..where(
          ($PreferencesTable t) => t.key.isNotIn(PreferenceKeys.deviceScoped),
        ))
        .go();
  });
}

QueryExecutor openDatabaseConnection() {
  return LazyDatabase(() async {
    final Directory dir = await getApplicationDocumentsDirectory();
    return NativeDatabase(File(p.join(dir.path, 'libu_care.sqlite')));
  });
}
