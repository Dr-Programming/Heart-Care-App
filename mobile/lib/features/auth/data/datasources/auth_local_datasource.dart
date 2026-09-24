import '../../../../core/db/app_database.dart';
import '../../../../core/db/daos/cached_user_dao.dart';
import '../../../../core/db/daos/preferences_dao.dart';
import '../../../../core/security/jwt.dart';
import '../../../../core/security/token_store.dart';
import '../../domain/entities/auth_user.dart';

class AuthLocalDataSource {
  const AuthLocalDataSource({
    required this.tokenStore,
    required this.cachedUserDao,
    required this.preferencesDao,
  });

  final TokenStore tokenStore;
  final CachedUserDao cachedUserDao;
  final PreferencesDao preferencesDao;

  static const String _needsOnboardingKey = 'auth_needs_onboarding';

  Future<void> saveSession({
    required String token,
    required AuthUser user,
  }) async {
    await tokenStore.write(token);
    await saveUser(user);
  }

  /// Caches [user] as the signed-in patient without touching the token — an
  /// offline sign-in has no new token to write.
  Future<void> saveUser(AuthUser user) async {
    await cachedUserDao.save(
      CachedUsersCompanion.insert(
        id: user.id,
        name: user.name,
        phone: user.phone,
        preferredLanguage: user.preferredLanguage,
        role: user.role,
      ),
    );
  }

  Future<AuthUser?> cachedUser() async {
    final CachedUser? row = await cachedUserDao.current();
    if (row == null) return null;
    return AuthUser(
      id: row.id,
      name: row.name,
      phone: row.phone,
      preferredLanguage: row.preferredLanguage,
      role: row.role,
    );
  }

  Future<bool> isSignedIn() async {
    final String? token = await tokenStore.read();
    if (token == null) return false;
    return !isJwtExpired(token);
  }

  Future<void> clearSession() async {
    await tokenStore.clear();
    await cachedUserDao.clear();
    await preferencesDao.remove(_needsOnboardingKey);
  }

  Future<void> setNeedsOnboarding(bool value) =>
      preferencesDao.set(_needsOnboardingKey, value.toString());

  Future<bool> needsOnboarding() async =>
      await preferencesDao.get(_needsOnboardingKey) == 'true';
}
