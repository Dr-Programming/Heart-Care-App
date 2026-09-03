import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// The bearer token at rest, in the platform keystore.
///
/// Lives in `core/`, not the auth feature, because `dioProvider` must read the
/// token to set the `Authorization` header — if core reached into
/// `features/auth` for it, core and auth would import each other.
class TokenStore {
  const TokenStore(this._storage);

  static const String _key = 'auth_token';

  final FlutterSecureStorage _storage;

  Future<String?> read() => _storage.read(key: _key);
  Future<void> write(String token) => _storage.write(key: _key, value: token);
  Future<void> clear() => _storage.delete(key: _key);
}
