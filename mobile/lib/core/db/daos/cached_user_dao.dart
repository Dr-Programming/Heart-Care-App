import 'package:drift/drift.dart';

import '../app_database.dart';

part 'cached_user_dao.g.dart';

@DriftAccessor(tables: <Type>[CachedUsers])
class CachedUserDao extends DatabaseAccessor<AppDatabase>
    with _$CachedUserDaoMixin {
  CachedUserDao(super.db);

  Future<void> save(CachedUsersCompanion user) async {
    await transaction(() async {
      await delete(cachedUsers).go();
      await into(cachedUsers).insert(user);
    });
  }

  Future<CachedUser?> current() =>
      (select(cachedUsers)..limit(1)).getSingleOrNull();

  Stream<CachedUser?> watchCurrent() =>
      (select(cachedUsers)..limit(1)).watchSingleOrNull();

  Future<void> clear() => delete(cachedUsers).go();
}
