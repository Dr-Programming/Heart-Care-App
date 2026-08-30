import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'daos/cached_user_dao.dart';
import 'daos/preferences_dao.dart';
import 'tables.dart';

// Re-exported so `import 'core/db/app_database.dart'` keeps giving callers the
// table classes, PreferenceKeys and the sync enums alongside the generated
// row classes, which drift emits into the part file below.
export 'tables.dart';

part 'app_database.g.dart';

/// The device-side database. It is the source of truth: the UI reads from
/// here, writes land here first, and the sync engine pushes from here. Nothing
/// in the app waits on the network to show or store a record.
///
/// The schema is owned by the foundation slice. Feature slices query their own
/// tables from their own local datasource and never edit this file or
/// `tables.dart`; see the note at the top of `tables.dart` for why.
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
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (Migrator m) => m.createAll(),
    // v1 shipped to nobody but did reach developer devices during the
    // foundation build, where it held only the two auth-support tables.
    // Rather than force a reinstall, add the feature tables in place.
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
    },
  );
}

/// Opens the on-device database file. Used by the app; tests pass
/// `NativeDatabase.memory()` to the constructor instead — see
/// `test/helpers/test_database.dart`.
QueryExecutor openDatabaseConnection() {
  return LazyDatabase(() async {
    final Directory dir = await getApplicationDocumentsDirectory();
    return NativeDatabase(File(p.join(dir.path, 'libu_care.sqlite')));
  });
}
