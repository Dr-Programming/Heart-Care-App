import '../../../../core/db/app_database.dart';
import '../../../../core/db/daos/cached_user_dao.dart';
import '../../../../core/security/token_store.dart';
import '../models/user_model.dart';

/// Session storage: the JWT goes in the platform keystore, the user record in
/// Drift. Split on purpose — the token is a credential and belongs in
/// encrypted storage; the user record is ordinary app data the offline launch
/// path needs to read quickly.
class AuthLocalDataSource {
  const AuthLocalDataSource(this._tokens, this._users);

  final TokenStore _tokens;
  final CachedUserDao _users;

  Future<void> saveSession({
    required String token,
    required UserModel user,
  }) async {
    await _tokens.write(token);
    await _users.save(user.toCompanion());
  }

  Future<String?> readToken() => _tokens.read();

  Future<UserModel?> readUser() async {
    final CachedUser? row = await _users.current();
    return row == null ? null : UserModel.fromCached(row);
  }

  Future<void> cacheUser(UserModel user) => _users.save(user.toCompanion());

  Future<void> clear() async {
    await _tokens.clear();
    await _users.clear();
  }
}
