import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:uuid/uuid.dart';

import '../../domain/security_question.dart';

enum PendingPinChangeKind {
  /// Proven with the PIN the server still has.
  change,

  /// Proven with the security answers.
  reset,
}

/// A PIN change made on this phone while offline, waiting to reach the server.
class PendingPinChange {
  const PendingPinChange({
    required this.changeId,
    required this.phone,
    required this.kind,
    required this.newPin,
    required this.createdAt,
    this.currentPin,
    this.answers = const <SecurityAnswer>[],
  });

  /// Sent with the request so a retry after a lost response is recognised by
  /// the server instead of looking like a conflict.
  final String changeId;
  final String phone;
  final PendingPinChangeKind kind;

  /// For [PendingPinChangeKind.change]: the PIN the server still has.
  final String? currentPin;

  /// For [PendingPinChangeKind.reset]: the answers that prove the reset.
  final List<SecurityAnswer> answers;
  final String newPin;
  final DateTime createdAt;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'changeId': changeId,
    'phone': phone,
    'kind': kind.name,
    'currentPin': currentPin,
    'answers': answers.map((SecurityAnswer a) => a.toJson()).toList(),
    'newPin': newPin,
    'createdAt': createdAt.toUtc().toIso8601String(),
  };

  static PendingPinChange? fromJson(Map<String, dynamic> json) {
    final PendingPinChangeKind? kind = PendingPinChangeKind.values
        .where((PendingPinChangeKind k) => k.name == json['kind'])
        .firstOrNull;
    final Object? changeId = json['changeId'];
    final Object? phone = json['phone'];
    final Object? newPin = json['newPin'];
    if (kind == null || changeId is! String || phone is! String || newPin is! String) {
      return null;
    }
    final List<SecurityAnswer> answers = <SecurityAnswer>[
      for (final Object? raw in (json['answers'] as List<Object?>?) ?? <Object?>[])
        if (raw is Map) ?SecurityAnswer.fromJson(raw.cast<String, dynamic>()),
    ];
    return PendingPinChange(
      changeId: changeId,
      phone: phone,
      kind: kind,
      currentPin: json['currentPin'] as String?,
      answers: answers,
      newPin: newPin,
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
    );
  }
}

/// The one PIN change waiting to reach the server, kept in secure storage
/// (Android Keystore) so it survives an app restart.
///
/// It holds the old PIN, or the security answers, until the server accepts
/// the change; that is the proof the server checks, and it is deleted the
/// moment the change is applied. Unlike [OfflineSession], which keeps the PIN
/// in memory only, this must survive a restart: a patient may change the PIN
/// on the bus and not open the app again until tomorrow.
class PendingPinChangeStore {
  PendingPinChangeStore(this._storage);

  final FlutterSecureStorage _storage;

  static const String _key = 'pending_pin_change';
  static const Uuid _uuid = Uuid();

  Future<String?> readRaw(String key) => _storage.read(key: key);

  Future<void> writeRaw(String key, String value) =>
      _storage.write(key: key, value: value);

  Future<void> deleteRaw(String key) => _storage.delete(key: key);

  Future<PendingPinChange?> read() async {
    final String? raw = await readRaw(_key);
    if (raw == null) return null;
    try {
      final Object? decoded = jsonDecode(raw);
      return decoded is Map<String, dynamic> ? PendingPinChange.fromJson(decoded) : null;
    } on FormatException {
      return null;
    }
  }

  /// Queues a change proven by [currentPin]. If a change is already pending
  /// for this phone, its original proof is kept (it is what the server still
  /// has) and only the new PIN moves forward.
  Future<void> recordChange({
    required String phone,
    required String currentPin,
    required String newPin,
  }) {
    return _record(
      phone: phone,
      newPin: newPin,
      fresh: () => (kind: PendingPinChangeKind.change, currentPin: currentPin, answers: <SecurityAnswer>[]),
    );
  }

  /// Queues a reset proven by [answers]; merges like [recordChange].
  Future<void> recordReset({
    required String phone,
    required List<SecurityAnswer> answers,
    required String newPin,
  }) {
    return _record(
      phone: phone,
      newPin: newPin,
      fresh: () => (kind: PendingPinChangeKind.reset, currentPin: null, answers: answers),
    );
  }

  Future<void> clear() => deleteRaw(_key);

  Future<void> _record({
    required String phone,
    required String newPin,
    required ({PendingPinChangeKind kind, String? currentPin, List<SecurityAnswer> answers}) Function() fresh,
  }) async {
    final PendingPinChange? existing = await read();
    final bool merge = existing != null && existing.phone == phone;
    final proof = fresh();
    final PendingPinChange next = PendingPinChange(
      // A new ID every time: the new PIN differs, so it is a different change.
      changeId: _uuid.v4(),
      phone: phone,
      kind: merge ? existing.kind : proof.kind,
      currentPin: merge ? existing.currentPin : proof.currentPin,
      answers: merge ? existing.answers : proof.answers,
      newPin: newPin,
      createdAt: merge ? existing.createdAt : DateTime.now(),
    );
    await writeRaw(_key, jsonEncode(next.toJson()));
  }
}
