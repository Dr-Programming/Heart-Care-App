import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../domain/answer_normalizer.dart';
import '../../domain/entities/auth_user.dart';
import '../../domain/security_question.dart';

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
///
/// It also keeps PBKDF2 hashes of the patient's security answers (never the
/// answers), so a forgotten PIN can be reset with no connection. That check has
/// its own lockout, matching the server's recovery lockout (5 tries, 60
/// minutes), because a patient who forgot the PIN has often just locked it.
class OfflineCredentialStore {
  OfflineCredentialStore(this._storage, {DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  final FlutterSecureStorage _storage;
  final DateTime Function() _clock;

  static const String _key = 'offline_credential';

  /// Earlier patients on this phone, by phone number: the same record as
  /// [_key] (hashes only), kept when someone else signs in so they can still
  /// sign in and reset a forgotten PIN offline when they come back.
  static const String _othersKey = 'offline_credential_others';
  static const int _iterations = 10000;
  static const int maxAttempts = 5;
  static const Duration lockout = Duration(minutes: 15);
  static const int recoveryMaxAttempts = 5;
  static const Duration recoveryLockout = Duration(minutes: 60);

  Future<String?> readRaw(String key) => _storage.read(key: key);

  Future<void> writeRaw(String key, String value) =>
      _storage.write(key: key, value: value);

  Future<void> deleteRaw(String key) => _storage.delete(key: key);

  /// Remembers [user] with [pin] as the credential for the next offline
  /// sign-in, replacing whatever account was remembered before. The security
  /// answers survive when it is the same user signing in again.
  Future<void> remember({required AuthUser user, required String pin}) async {
    final Map<String, dynamic>? previous = await _read();
    final bool sameUser =
        previous != null &&
        (previous['user'] as Map<Object?, Object?>)['id'] == user.id;
    final Map<String, dynamic> others = await _readOthers();
    if (previous != null && !sameUser) {
      others[_phoneOf(previous)] = previous;
    }
    // Coming back to this phone: their answers were kept.
    Map<String, dynamic>? returning;
    if (!sameUser && others[user.phone] is Map) {
      final Map<String, dynamic> kept = (others[user.phone] as Map)
          .cast<String, dynamic>();
      if ((kept['user'] as Map<Object?, Object?>)['id'] == user.id) {
        returning = kept;
      }
      others.remove(user.phone);
    }
    await _writeOthers(others);
    final Map<String, dynamic>? answersFrom = sameUser ? previous : returning;
    final Uint8List salt = _randomSalt();
    await _write(<String, dynamic>{
      if (answersFrom?['answers'] != null) 'answers': answersFrom!['answers'],
      if (answersFrom?['customQuestion'] != null)
        'customQuestion': answersFrom!['customQuestion'],
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

  /// Any patient remembered on this phone with [phone]: the active one or
  /// an earlier one.
  Future<AuthUser?> userForPhone(String phone) async {
    final Map<String, dynamic>? record = (await _recordFor(phone))?.record;
    return record == null ? null : _userOf(record);
  }

  /// Makes the patient with [phone] the active account again (they signed in
  /// or reset their PIN offline); the active one is kept as an earlier one.
  Future<void> makeActive(String phone) async {
    final Map<String, dynamic>? active = await _read();
    if (active != null && _phoneOf(active) == phone) return;
    final Map<String, dynamic> others = await _readOthers();
    final Object? entry = others.remove(phone);
    if (entry is! Map) return;
    if (active != null) others[_phoneOf(active)] = active;
    await _writeOthers(others);
    await _write(entry.cast<String, dynamic>());
  }

  /// Checks [phone] + [pin], counting a wrong PIN towards the lockout.
  Future<OfflineCheck> verify({
    required String phone,
    required String pin,
  }) async {
    final ({Map<String, dynamic> record, bool active})? found =
        await _recordFor(phone);
    if (found == null) return OfflineCheck.unknownAccount;
    final Map<String, dynamic> record = found.record;
    Future<void> save() => _save(record, active: found.active);

    if (_lockedUntil(record)?.isAfter(_clock()) ?? false) {
      return OfflineCheck.locked;
    }

    final Uint8List salt = base64Decode(record['salt'] as String);
    final Uint8List expected = base64Decode(record['hash'] as String);
    if (_constantTimeEquals(_derive(pin, salt), expected)) {
      record
        ..['failures'] = 0
        ..remove('lockedUntil');
      await save();
      return OfflineCheck.match;
    }

    final int failures = ((record['failures'] as int?) ?? 0) + 1;
    if (failures >= maxAttempts) {
      record
        ..['failures'] = 0
        ..['lockedUntil'] = _clock().add(lockout).toUtc().toIso8601String();
      await save();
      return OfflineCheck.locked;
    }
    record['failures'] = failures;
    await save();
    return OfflineCheck.wrongPin;
  }

  /// Whole minutes left on the lockout, rounded up; `null` when not locked.
  Future<int?> lockedFor({String? phone}) async {
    final Map<String, dynamic>? record = phone == null
        ? await _read()
        : (await _recordFor(phone))?.record;
    if (record == null) return null;
    final DateTime? until = _lockedUntil(record);
    if (until == null) return null;
    final Duration left = until.difference(_clock());
    if (left <= Duration.zero) return null;
    return (left.inSeconds / 60).ceil();
  }

  /// Forgets the active account. Earlier patients on this phone are kept.
  Future<void> forget() => deleteRaw(_key);

  /// Replaces the remembered PIN, keeping the user and the security answers.
  /// Clears the PIN lockout: the patient just proved who they are.
  ///
  /// Throws [StateError] when no account is remembered.
  Future<void> changePin(String newPin) async {
    final Map<String, dynamic>? record = await _read();
    if (record == null) {
      throw StateError('No remembered account to change the PIN of');
    }
    final Uint8List salt = _randomSalt();
    record
      ..['salt'] = base64Encode(salt)
      ..['hash'] = base64Encode(_derive(newPin, salt))
      ..['failures'] = 0
      ..remove('lockedUntil');
    await _write(record);
  }

  /// Stores hashes of [answers] for the remembered account, replacing any
  /// earlier ones. Does nothing when no account is remembered.
  Future<void> rememberAnswers(List<SecurityAnswer> answers) async {
    final Map<String, dynamic>? record = await _read();
    if (record == null) return;
    record
      ..['answers'] = <Map<String, String>>[
        for (final SecurityAnswer answer in answers) _hashAnswer(answer),
      ]
      ..['recoveryFailures'] = 0
      ..remove('recoveryLockedUntil');
    await _write(record);
  }

  /// Saves the patient's own question and a hash of its answer for the
  /// remembered account, replacing any earlier one. Phone only: the server
  /// knows just its fixed list of questions.
  Future<void> rememberCustomQuestion({
    required String question,
    required String answer,
  }) async {
    final Map<String, dynamic>? record = await _read();
    if (record == null) return;
    final Uint8List salt = _randomSalt();
    record['customQuestion'] = <String, String>{
      'text': question.trim(),
      'salt': base64Encode(salt),
      'hash': base64Encode(_derive(normalizeAnswer(answer), salt)),
    };
    await _write(record);
  }

  /// Removes the remembered account's own question.
  Future<void> clearCustomQuestion() async {
    final Map<String, dynamic>? record = await _read();
    if (record == null || record.remove('customQuestion') == null) return;
    await _write(record);
  }

  /// The patient's own question for [phone] on this phone, if they set one.
  Future<String?> customQuestion(String phone) async {
    final Map<String, dynamic>? record = (await _recordFor(phone))?.record;
    final Object? raw = record?['customQuestion'];
    return raw is Map ? raw['text'] as String? : null;
  }

  /// Whether [answer] matches the stored answer to [record]'s own question;
  /// true when there is none.
  bool _customAnswerMatches(Map<String, dynamic> record, String? answer) {
    final Object? raw = record['customQuestion'];
    if (raw is! Map) return true;
    if (answer == null || !isValidAnswer(answer)) return false;
    return _constantTimeEquals(
      _derive(normalizeAnswer(answer), base64Decode(raw['salt'] as String)),
      base64Decode(raw['hash'] as String),
    );
  }

  /// Checks only the answer to [phone]'s own question, counting a wrong one
  /// towards the recovery lockout. Used before an online reset, when the
  /// server checks the other answers.
  Future<OfflineCheck> verifyCustomAnswer({
    required String phone,
    required String? answer,
  }) async {
    final ({Map<String, dynamic> record, bool active})? found =
        await _recordFor(phone);
    if (found == null || found.record['customQuestion'] == null) {
      return OfflineCheck.match;
    }
    final Map<String, dynamic> record = found.record;
    if (_recoveryLockedUntil(record)?.isAfter(_clock()) ?? false) {
      return OfflineCheck.locked;
    }
    if (_customAnswerMatches(record, answer)) return OfflineCheck.match;
    return _countRecoveryFailure(record, active: found.active);
  }

  Future<OfflineCheck> _countRecoveryFailure(
    Map<String, dynamic> record, {
    required bool active,
  }) async {
    final int failures = ((record['recoveryFailures'] as int?) ?? 0) + 1;
    if (failures >= recoveryMaxAttempts) {
      record
        ..['recoveryFailures'] = 0
        ..['recoveryLockedUntil'] = _clock()
            .add(recoveryLockout)
            .toUtc()
            .toIso8601String();
      await _save(record, active: active);
      return OfflineCheck.locked;
    }
    record['recoveryFailures'] = failures;
    await _save(record, active: active);
    return OfflineCheck.wrongPin;
  }

  /// The questions stored for [phone]; empty when this phone has none for it.
  Future<List<SecurityQuestion>> rememberedQuestions(String phone) async {
    final Map<String, dynamic>? record = (await _recordFor(phone))?.record;
    if (record == null) return const <SecurityQuestion>[];
    return <SecurityQuestion>[
      for (final _StoredAnswer stored in _storedAnswers(record))
        stored.question,
    ];
  }

  /// Checks [answers] against the stored hashes for [phone], counting a wrong
  /// set towards the recovery lockout. [OfflineCheck.wrongPin] here means "the
  /// answers don't match". Every stored answer is always checked.
  Future<OfflineCheck> verifyAnswers({
    required String phone,
    required List<SecurityAnswer> answers,
    String? customAnswer,
  }) async {
    final ({Map<String, dynamic> record, bool active})? found =
        await _recordFor(phone);
    if (found == null) return OfflineCheck.unknownAccount;
    final Map<String, dynamic> record = found.record;
    Future<void> save() => _save(record, active: found.active);
    final List<_StoredAnswer> stored = _storedAnswers(record);
    if (stored.isEmpty) return OfflineCheck.unknownAccount;

    if (_recoveryLockedUntil(record)?.isAfter(_clock()) ?? false) {
      return OfflineCheck.locked;
    }

    final Map<SecurityQuestion, String> given = <SecurityQuestion, String>{
      for (final SecurityAnswer answer in answers)
        answer.question: answer.answer,
    };
    bool allMatch =
        given.length == answers.length && answers.length == stored.length;
    for (final _StoredAnswer expected in stored) {
      final String? candidate = given[expected.question];
      final bool match =
          candidate != null &&
          isValidAnswer(candidate) &&
          _constantTimeEquals(
            _derive(normalizeAnswer(candidate), expected.salt),
            expected.hash,
          );
      allMatch = allMatch && match;
    }
    // The patient's own question, when set on this phone, must match too.
    allMatch = _customAnswerMatches(record, customAnswer) && allMatch;

    if (allMatch) {
      record
        ..['recoveryFailures'] = 0
        ..remove('recoveryLockedUntil');
      await save();
      return OfflineCheck.match;
    }

    return _countRecoveryFailure(record, active: found.active);
  }

  /// Whole minutes left on the recovery lockout, rounded up; `null` when not locked.
  Future<int?> recoveryLockedFor({String? phone}) async {
    final Map<String, dynamic>? record = phone == null
        ? await _read()
        : (await _recordFor(phone))?.record;
    if (record == null) return null;
    final DateTime? until = _recoveryLockedUntil(record);
    if (until == null) return null;
    final Duration left = until.difference(_clock());
    if (left <= Duration.zero) return null;
    return (left.inSeconds / 60).ceil();
  }

  Map<String, String> _hashAnswer(SecurityAnswer answer) {
    final Uint8List salt = _randomSalt();
    return <String, String>{
      'question': answer.question.id,
      'salt': base64Encode(salt),
      'hash': base64Encode(_derive(normalizeAnswer(answer.answer), salt)),
    };
  }

  List<_StoredAnswer> _storedAnswers(Map<String, dynamic> record) {
    final Object? raw = record['answers'];
    if (raw is! List) return const <_StoredAnswer>[];
    return <_StoredAnswer>[
      for (final Object? entry in raw)
        if (entry is Map)
          if (SecurityQuestion.fromId(entry['question'] as String? ?? '')
              case final SecurityQuestion q)
            _StoredAnswer(
              q,
              base64Decode(entry['salt'] as String),
              base64Decode(entry['hash'] as String),
            ),
    ];
  }

  DateTime? _recoveryLockedUntil(Map<String, dynamic> record) {
    final Object? raw = record['recoveryLockedUntil'];
    return raw is String ? DateTime.tryParse(raw) : null;
  }

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

  /// The record for [phone], whether it is the active one.
  Future<({Map<String, dynamic> record, bool active})?> _recordFor(
    String phone,
  ) async {
    final Map<String, dynamic>? active = await _read();
    if (active != null && _phoneOf(active) == phone) {
      return (record: active, active: true);
    }
    final Object? other = (await _readOthers())[phone];
    if (other is! Map ||
        other['user'] is! Map ||
        other['salt'] is! String ||
        other['hash'] is! String) {
      return null;
    }
    return (record: other.cast<String, dynamic>(), active: false);
  }

  Future<void> _save(
    Map<String, dynamic> record, {
    required bool active,
  }) async {
    if (active) return _write(record);
    final Map<String, dynamic> others = await _readOthers();
    others[_phoneOf(record)] = record;
    await _writeOthers(others);
  }

  Future<Map<String, dynamic>> _readOthers() async {
    final String? raw = await readRaw(_othersKey);
    if (raw == null) return <String, dynamic>{};
    try {
      final Object? decoded = jsonDecode(raw);
      return decoded is Map<String, dynamic> ? decoded : <String, dynamic>{};
    } on FormatException {
      return <String, dynamic>{};
    }
  }

  Future<void> _writeOthers(Map<String, dynamic> others) => others.isEmpty
      ? deleteRaw(_othersKey)
      : writeRaw(_othersKey, jsonEncode(others));

  static String _phoneOf(Map<String, dynamic> record) =>
      (record['user'] as Map<Object?, Object?>)['phone'] as String;

  static AuthUser _userOf(Map<String, dynamic> record) {
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

class _StoredAnswer {
  const _StoredAnswer(this.question, this.salt, this.hash);

  final SecurityQuestion question;
  final Uint8List salt;
  final Uint8List hash;
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
