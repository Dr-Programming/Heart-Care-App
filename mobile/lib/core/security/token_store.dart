import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// The server session: a short-lived access token plus the refresh token that
/// renews it. Each refresh token works once, so a new pair replaces the old.
class TokenStore {
  const TokenStore(this._storage);

  static const String accessKey = 'auth_token';
  static const String refreshKey = 'auth_refresh_token';
  static const String refreshExpiryKey = 'auth_refresh_expires_at';

  final FlutterSecureStorage _storage;

  Future<String?> read() => readRaw(accessKey);

  Future<String?> readRefresh() => readRaw(refreshKey);

  /// When the refresh token stops working, if the server said.
  Future<DateTime?> readRefreshExpiry() async {
    final String? raw = await readRaw(refreshExpiryKey);
    return raw == null ? null : DateTime.tryParse(raw);
  }

  Future<void> write(String token) => writeRaw(accessKey, token);

  /// Saves a new pair. A response without a refresh token (an older server)
  /// leaves no stale one behind.
  Future<void> writeSession({
    required String access,
    String? refresh,
    DateTime? refreshExpiresAt,
  }) async {
    await writeRaw(accessKey, access);
    if (refresh == null) {
      await deleteRaw(refreshKey);
    } else {
      await writeRaw(refreshKey, refresh);
    }
    if (refresh == null || refreshExpiresAt == null) {
      await deleteRaw(refreshExpiryKey);
    } else {
      await writeRaw(
        refreshExpiryKey,
        refreshExpiresAt.toUtc().toIso8601String(),
      );
    }
  }

  Future<void> clear() async {
    await deleteRaw(accessKey);
    await deleteRaw(refreshKey);
    await deleteRaw(refreshExpiryKey);
  }

  Future<String?> readRaw(String key) => _storage.read(key: key);

  Future<void> writeRaw(String key, String value) =>
      _storage.write(key: key, value: value);

  Future<void> deleteRaw(String key) => _storage.delete(key: key);
}
