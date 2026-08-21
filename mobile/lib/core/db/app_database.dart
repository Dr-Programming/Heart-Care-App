import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'daos/cached_user_dao.dart';
import 'daos/preferences_dao.dart';

part 'app_database.g.dart';

/// The signed-in user, cached so the app can open to a greeting with no
/// network. Exactly one row is ever present — see [CachedUserDao.save].
class CachedUsers extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get phone => text()();
  TextColumn get preferredLanguage => text()();
  TextColumn get role => text()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{id};
}

/// Small key/value store for device-local settings. The language choice lives
/// here because it is device state, not a secret and not server-owned.
class Preferences extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{key};
}

abstract final class PreferenceKeys {
  static const String language = 'language';
  static const String languageChosen = 'language_chosen';
}

@DriftDatabase(
  tables: <Type>[CachedUsers, Preferences],
  daos: <Type>[CachedUserDao, PreferencesDao],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.executor);

  @override
  int get schemaVersion => 1;
}

/// Opens the on-device database file. Used by the app; tests pass
/// `NativeDatabase.memory()` to the constructor instead.
QueryExecutor openDatabaseConnection() {
  return LazyDatabase(() async {
    final Directory dir = await getApplicationDocumentsDirectory();
    return NativeDatabase(File(p.join(dir.path, 'libu_care.sqlite')));
  });
}
