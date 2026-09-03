import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../config/env.dart';
import '../db/app_database.dart';
import '../localization/language.dart';
import '../network/dio_client.dart';
import '../security/token_store.dart';

/// Riverpod is the DI container — there is no `get_it`.
///
/// This file must not import anything from `features/`. Feature wiring lives in
/// that feature's own providers file.

final Provider<AppDatabase> appDatabaseProvider = Provider<AppDatabase>((ref) {
  final AppDatabase db = AppDatabase(openDatabaseConnection());
  ref.onDispose(db.close);
  return db;
});

final Provider<FlutterSecureStorage> secureStorageProvider =
    Provider<FlutterSecureStorage>((ref) => const FlutterSecureStorage(
          // flutter_secure_storage 11.x makes AES-GCM encrypted storage the
          // default on Android; the old `encryptedSharedPreferences` flag no
          // longer exists. `AndroidOptions()` is the strong-security default.
          aOptions: AndroidOptions(),
        ));

final Provider<TokenStore> tokenStoreProvider =
    Provider<TokenStore>((ref) => TokenStore(ref.watch(secureStorageProvider)));

final Provider<Dio> dioProvider = Provider<Dio>((ref) {
  final TokenStore tokens = ref.watch(tokenStoreProvider);
  return buildDio(baseUrl: Env.apiBaseUrl, readToken: tokens.read);
});

final Provider<Future<bool> Function()> isOnlineProvider =
    Provider<Future<bool> Function()>((ref) {
  return () async {
    final List<ConnectivityResult> result =
        await Connectivity().checkConnectivity();
    return !result.every((ConnectivityResult r) => r == ConnectivityResult.none);
  };
});

final Provider<LanguageStore> languageStoreProvider = Provider<LanguageStore>(
    (ref) => LanguageStore(ref.watch(appDatabaseProvider).preferencesDao));
