// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'cached_user_dao.dart';

// ignore_for_file: type=lint
mixin _$CachedUserDaoMixin on DatabaseAccessor<AppDatabase> {
  $CachedUsersTable get cachedUsers => attachedDatabase.cachedUsers;
  CachedUserDaoManager get managers => CachedUserDaoManager(this);
}

class CachedUserDaoManager {
  final _$CachedUserDaoMixin _db;
  CachedUserDaoManager(this._db);
  $$CachedUsersTableTableManager get cachedUsers =>
      $$CachedUsersTableTableManager(_db.attachedDatabase, _db.cachedUsers);
}
