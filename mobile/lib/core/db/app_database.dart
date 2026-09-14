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
  int get schemaVersion => 2;

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
    },
  );
}

QueryExecutor openDatabaseConnection() {
  return LazyDatabase(() async {
    final Directory dir = await getApplicationDocumentsDirectory();
    return NativeDatabase(File(p.join(dir.path, 'libu_care.sqlite')));
  });
}
