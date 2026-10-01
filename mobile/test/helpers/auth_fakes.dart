import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:libu_care/core/security/token_store.dart';
import 'package:libu_care/features/auth/data/datasources/offline_credential_store.dart';
import 'package:libu_care/features/auth/data/datasources/pending_pin_change_store.dart';

/// In-memory stand-ins for the secure-storage-backed auth stores. They subclass the real stores
/// and override only the raw read/write hooks, so every bit of the stores' own logic still runs.

class FakeTokenStore extends TokenStore {
  FakeTokenStore() : super(const FlutterSecureStorage());

  String? value;

  @override
  Future<void> clear() async => value = null;

  @override
  Future<String?> read() async => value;

  @override
  Future<void> write(String token) async => value = token;
}

class MemoryCredentialStore extends OfflineCredentialStore {
  MemoryCredentialStore({super.clock}) : super(const FlutterSecureStorage());

  final Map<String, String> values = <String, String>{};

  @override
  Future<String?> readRaw(String key) async => values[key];

  @override
  Future<void> writeRaw(String key, String value) async => values[key] = value;

  @override
  Future<void> deleteRaw(String key) async => values.remove(key);
}

class MemoryPendingPinChangeStore extends PendingPinChangeStore {
  MemoryPendingPinChangeStore() : super(const FlutterSecureStorage());

  final Map<String, String> values = <String, String>{};

  @override
  Future<String?> readRaw(String key) async => values[key];

  @override
  Future<void> writeRaw(String key, String value) async => values[key] = value;

  @override
  Future<void> deleteRaw(String key) async => values.remove(key);
}
