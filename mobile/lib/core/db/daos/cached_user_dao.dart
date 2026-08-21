import 'package:drift/drift.dart';

import '../app_database.dart';

part 'cached_user_dao.g.dart';

@DriftAccessor(tables: <Type>[CachedUsers])
class CachedUserDao extends DatabaseAccessor<AppDatabase>
    with _$CachedUserDaoMixin {
  CachedUserDao(super.db);

  /// Replaces the cache wholesale. This device serves one patient, so a second
  /// user row would be a bug rather than a feature — signing in as someone
  /// else must not leave the previous user's record behind.
  Future<void> save(CachedUsersCompanion user) async {
    await transaction(() async {
      await delete(cachedUsers).go();
      await into(cachedUsers).insert(user);
    });
  }

  Future<CachedUser?> current() =>
      (select(cachedUsers)..limit(1)).getSingleOrNull();

  /// Emits on sign-in, sign-out and profile rename.
  ///
  /// The shell greets the user from this rather than from an auth provider,
  /// which is what lets `core/` render a personalised Home without importing
  /// the auth feature.
  Stream<CachedUser?> watchCurrent() =>
      (select(cachedUsers)..limit(1)).watchSingleOrNull();

  Future<void> clear() => delete(cachedUsers).go();
}
