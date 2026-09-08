import '../../../../core/db/app_database.dart';
import '../../../../core/db/daos/cached_user_dao.dart';
import '../../../../core/security/jwt.dart';
import '../../../../core/security/token_store.dart';
import '../models/user_model.dart';

/// The device-side half of a session: the token in secure storage, and the
/// one-row user cache in Drift. Written together on sign-in, cleared together
/// on sign-out — never one without the other.
class AuthLocalDataSource {
  AuthLocalDataSource({
    required this._tokenStore,
    required this._cachedUserDao,
  });

  final TokenStore _tokenStore;
  final CachedUserDao _cachedUserDao;

  Future<void> saveSession({
    required String token,
    required UserModel user,
  }) async {
    await _tokenStore.write(token);
    await _cachedUserDao.save(
      CachedUsersCompanion.insert(
        id: user.id,
        name: user.name,
        phone: user.phone,
        preferredLanguage: user.preferredLanguage,
        role: user.role,
      ),
    );
  }

  /// Refreshes the cached user without touching the token — used after a
  /// successful `getMe()`, which is never allowed to affect sign-in state.
  Future<void> cacheUser(UserModel user) => _cachedUserDao.save(
    CachedUsersCompanion.insert(
      id: user.id,
      name: user.name,
      phone: user.phone,
      preferredLanguage: user.preferredLanguage,
      role: user.role,
    ),
  );

  Future<void> clearSession() async {
    await _tokenStore.clear();
    await _cachedUserDao.clear();
  }

  Future<String?> readToken() => _tokenStore.read();

  Future<UserModel?> cachedUser() async {
    final CachedUser? row = await _cachedUserDao.current();
    if (row == null) return null;
    return UserModel(
      id: row.id,
      name: row.name,
      phone: row.phone,
      preferredLanguage: row.preferredLanguage,
      role: row.role,
    );
  }

  /// True when a token exists and has not locally expired. Never touches the
  /// network.
  Future<bool> hasValidSession() async {
    final String? token = await _tokenStore.read();
    if (token == null) return false;
    return !isJwtExpired(token);
  }
}
