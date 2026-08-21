// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'preferences_dao.dart';

// ignore_for_file: type=lint
mixin _$PreferencesDaoMixin on DatabaseAccessor<AppDatabase> {
  $PreferencesTable get preferences => attachedDatabase.preferences;
  PreferencesDaoManager get managers => PreferencesDaoManager(this);
}

class PreferencesDaoManager {
  final _$PreferencesDaoMixin _db;
  PreferencesDaoManager(this._db);
  $$PreferencesTableTableManager get preferences =>
      $$PreferencesTableTableManager(_db.attachedDatabase, _db.preferences);
}
