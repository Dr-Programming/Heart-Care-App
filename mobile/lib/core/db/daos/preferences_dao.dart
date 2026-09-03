import 'package:drift/drift.dart';

import '../app_database.dart';

part 'preferences_dao.g.dart';

@DriftAccessor(tables: <Type>[Preferences])
class PreferencesDao extends DatabaseAccessor<AppDatabase>
    with _$PreferencesDaoMixin {
  PreferencesDao(super.db);

  Future<String?> get(String key) async {
    final row = await (select(preferences)
          ..where(($PreferencesTable t) => t.key.equals(key)))
        .getSingleOrNull();
    return row?.value;
  }

  Future<void> set(String key, String value) =>
      into(preferences).insertOnConflictUpdate(
        PreferencesCompanion.insert(key: key, value: value),
      );

  Future<void> remove(String key) => (delete(preferences)
        ..where(($PreferencesTable t) => t.key.equals(key)))
      .go();
}
