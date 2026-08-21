import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../config/env.dart';
import '../db/app_database.dart';
import '../localization/language.dart';
import '../network/dio_client.dart';
import '../security/token_store.dart';

/// Riverpod is the DI container for this app — there is no `get_it`.
///
/// This file must not import anything from `features/`. Feature wiring lives
/// in that feature's own providers file.

final Provider<AppDatabase> appDatabaseProvider = Provider<AppDatabase>((Ref ref) {
  final AppDatabase db = AppDatabase(openDatabaseConnection());
  ref.onDispose(db.close);
  return db;
});

final Provider<FlutterSecureStorage> secureStorageProvider =
    Provider<FlutterSecureStorage>((Ref ref) => const FlutterSecureStorage(
          aOptions: AndroidOptions(),
        ));

final Provider<TokenStore> tokenStoreProvider =
    Provider<TokenStore>((Ref ref) => TokenStore(ref.watch(secureStorageProvider)));

/// Reads the token straight from the keystore, so the interceptor never needs
/// to know which feature owns the session.
final Provider<Dio> dioProvider = Provider<Dio>((Ref ref) {
  final TokenStore tokens = ref.watch(tokenStoreProvider);
  return buildDio(baseUrl: Env.apiBaseUrl, readToken: tokens.read);
});

final Provider<Future<bool> Function()> isOnlineProvider =
    Provider<Future<bool> Function()>((Ref ref) {
  return () async {
    final List<ConnectivityResult> result = await Connectivity().checkConnectivity();
    return !result.every((ConnectivityResult r) => r == ConnectivityResult.none);
  };
});

final Provider<LanguageStore> languageStoreProvider = Provider<LanguageStore>(
    (Ref ref) => LanguageStore(ref.watch(appDatabaseProvider).preferencesDao));
