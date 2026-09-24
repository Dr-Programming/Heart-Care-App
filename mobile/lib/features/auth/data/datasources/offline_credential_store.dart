import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../domain/entities/auth_user.dart';

/// Result of checking a phone + PIN against the account remembered on this
/// phone.
enum OfflineCheck {
  /// Phone and PIN match the remembered account.
  match,

  /// The phone matches but the PIN does not.
  wrongPin,

  /// No account for this phone has ever signed in on this device, so there is
  /// nothing to check against — the server has to answer.
  unknownAccount,

  /// Too many wrong PINs in a row; see [OfflineCredentialStore.lockedFor].
  locked,
}

/// Lets a patient who has signed in on this phone before sign in again
/// without the server.
///
/// After every successful online sign-in or registration the account is
/// remembered here: the profile, and a salted PBKDF2 hash of the PIN — never
/// the PIN itself. It lives in secure storage (Android Keystore) and survives
/// sign-out on purpose, so "sign out, then sign back in on the bus" works.
///
/// Mirrors the backend's lockout (5 wrong PINs, 15 minutes), because a 4-digit
/// PIN checked locally with no limit could simply be counted through.
class OfflineCredentialStore {
  OfflineCredentialStore(this._storage, {DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  final FlutterSecureStorage _storage;
  final DateTime Function() _clock;

  static const String _key = 'offline_credential';
  static const int _iterations = 10000;
  static const int maxAttempts = 5;
  static const Duration lockout = Duration(minutes: 15);

  Future<String?> readRaw(String key) => _storage.read(key: key);

  Future<void> writeRaw(String key, String value) =>
      _storage.write(key: key, value: value);

  Future<void> deleteRaw(String key) => _storage.delete(key: key);

  /// Remembers [user] with [pin] as the credential for the next offline
  /// sign-in, replacing whatever account was remembered before.
  Future<void> remember({required AuthUser user, required String pin}) async {
    final Uint8List salt = _randomSalt();
    await _write(<String, dynamic>{
      'user': <String, dynamic>{
        'id': user.id,
        'name': user.name,
        'phone': user.phone,
        'preferredLanguage': user.preferredLanguage,
        'role': user.role,
      },
      'salt': base64Encode(salt),
      'hash': base64Encode(_derive(pin, salt)),
      'failures': 0,
    });
  }

  /// The remembered account, if any.
  Future<AuthUser?> rememberedUser() async {
    final Map<String, dynamic>? record = await _read();
    if (record == null) return null;
    final Map<String, dynamic> user = (record['user'] as Map<Object?, Object?>)
        .cast<String, dynamic>();
    return AuthUser(
      id: user['id'] as String,
      name: user['name'] as String,
      phone: user['phone'] as String,
      preferredLanguage: user['preferredLanguage'] as String,
      role: user['role'] as String,
    );
  }

  /// Checks [phone] + [pin], counting a wrong PIN towards the lockout.
  Future<OfflineCheck> verify({
    required String phone,
    required String pin,
  }) async {
    final Map<String, dynamic>? record = await _read();
    if (record == null) return OfflineCheck.unknownAccount;
    final Map<Object?, Object?> user = record['user'] as Map<Object?, Object?>;
    if (user['phone'] != phone) return OfflineCheck.unknownAccount;

    if (_lockedUntil(record)?.isAfter(_clock()) ?? false) {
      return OfflineCheck.locked;
    }

    final Uint8List salt = base64Decode(record['salt'] as String);
    final Uint8List expected = base64Decode(record['hash'] as String);
    if (_constantTimeEquals(_derive(pin, salt), expected)) {
      record
        ..['failures'] = 0
        ..remove('lockedUntil');
      await _write(record);
      return OfflineCheck.match;
    }

    final int failures = ((record['failures'] as int?) ?? 0) + 1;
    if (failures >= maxAttempts) {
      record
        ..['failures'] = 0
        ..['lockedUntil'] = _clock().add(lockout).toUtc().toIso8601String();
      await _write(record);
      return OfflineCheck.locked;
    }
    record['failures'] = failures;
    await _write(record);
    return OfflineCheck.wrongPin;
  }

  /// Whole minutes left on the lockout, rounded up; `null` when not locked.
  Future<int?> lockedFor() async {
    final Map<String, dynamic>? record = await _read();
    if (record == null) return null;
    final DateTime? until = _lockedUntil(record);
    if (until == null) return null;
    final Duration left = until.difference(_clock());
    if (left <= Duration.zero) return null;
    return (left.inSeconds / 60).ceil();
  }

  /// Forgets the remembered account entirely.
  Future<void> forget() => deleteRaw(_key);

  DateTime? _lockedUntil(Map<String, dynamic> record) {
    final Object? raw = record['lockedUntil'];
    return raw is String ? DateTime.tryParse(raw) : null;
  }

  Future<Map<String, dynamic>?> _read() async {
    final String? raw = await readRaw(_key);
    if (raw == null) return null;
    try {
      final Object? decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return null;
      if (decoded['user'] is! Map ||
          decoded['salt'] is! String ||
          decoded['hash'] is! String) {
        return null;
      }
      return decoded;
    } on FormatException {
      return null;
    }
  }

  Future<void> _write(Map<String, dynamic> record) =>
      writeRaw(_key, jsonEncode(record));

  static Uint8List _randomSalt() {
    final Random random = Random.secure();
    return Uint8List.fromList(
      List<int>.generate(16, (_) => random.nextInt(256)),
    );
  }

  /// PBKDF2-HMAC-SHA256, one 32-byte block.
  static Uint8List _derive(String pin, Uint8List salt) {
    final Hmac hmac = Hmac(sha256, utf8.encode(pin));
    Uint8List u = Uint8List.fromList(
      hmac.convert(<int>[...salt, 0, 0, 0, 1]).bytes,
    );
    final Uint8List out = Uint8List.fromList(u);
    for (int i = 1; i < _iterations; i++) {
      u = Uint8List.fromList(hmac.convert(u).bytes);
      for (int j = 0; j < out.length; j++) {
        out[j] ^= u[j];
      }
    }
    return out;
  }

  static bool _constantTimeEquals(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    int diff = 0;
    for (int i = 0; i < a.length; i++) {
      diff |= a[i] ^ b[i];
    }
    return diff == 0;
  }
}

/// The patient signed in against [OfflineCredentialStore] rather than the
/// server, so there is no fresh token behind this session yet.
///
/// Held in memory only, for the life of the process. That is deliberate: the
/// PIN has to be kept somewhere to trade the offline session for a real one as
/// soon as the server answers, and keeping it past a restart would mean
/// writing it to disk. After a restart with an expired token the patient
/// simply enters their PIN again — which works offline too.
class OfflineSession {
  ({String phone, String pin})? _credentials;

  bool get isActive => _credentials != null;

  ({String phone, String pin})? get credentials => _credentials;

  void begin({required String phone, required String pin}) =>
      _credentials = (phone: phone, pin: pin);

  void end() => _credentials = null;
}
