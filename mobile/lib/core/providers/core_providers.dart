import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../config/env.dart';
import '../db/app_database.dart';
import '../localization/language.dart';
import '../network/dio_client.dart';
import '../security/token_store.dart';
import '../sync/sync_queue_dao.dart';
import '../sync/sync_service.dart';

final Provider<AppDatabase> appDatabaseProvider = Provider<AppDatabase>((
  Ref ref,
) {
  final AppDatabase db = AppDatabase(openDatabaseConnection());
  ref.onDispose(db.close);
  return db;
});

final Provider<FlutterSecureStorage> secureStorageProvider =
    Provider<FlutterSecureStorage>(
      (Ref ref) => const FlutterSecureStorage(aOptions: AndroidOptions()),
    );

final Provider<TokenStore> tokenStoreProvider = Provider<TokenStore>(
  (Ref ref) => TokenStore(ref.watch(secureStorageProvider)),
);

final Provider<Dio> dioProvider = Provider<Dio>((Ref ref) {
  final TokenStore tokens = ref.watch(tokenStoreProvider);
  return buildDio(baseUrl: Env.apiBaseUrl, readToken: tokens.read);
});

final Provider<Future<bool> Function()> isOnlineProvider =
    Provider<Future<bool> Function()>((Ref ref) {
      return () async {
        final List<ConnectivityResult> result = await Connectivity()
            .checkConnectivity();
        return !result.every(
          (ConnectivityResult r) => r == ConnectivityResult.none,
        );
      };
    });

final Provider<Stream<bool>>
connectivityStreamProvider = Provider<Stream<bool>>((Ref ref) {
  bool usable(List<ConnectivityResult> results) =>
      !results.every((ConnectivityResult r) => r == ConnectivityResult.none);

  return Connectivity().onConnectivityChanged.map(usable).asBroadcastStream();
});

final StreamProvider<bool> onlineStatusProvider = StreamProvider<bool>(
  (Ref ref) => ref.watch(connectivityStreamProvider),
);

final Provider<LanguageStore> languageStoreProvider = Provider<LanguageStore>(
  (Ref ref) => LanguageStore(ref.watch(appDatabaseProvider).preferencesDao),
);

final StreamProvider<CachedUser?> cachedUserProvider =
    StreamProvider<CachedUser?>(
      (Ref ref) => ref.watch(appDatabaseProvider).cachedUserDao.watchCurrent(),
    );

final Provider<SyncQueueDao> syncQueueDaoProvider = Provider<SyncQueueDao>(
  (Ref ref) => SyncQueueDao(ref.watch(appDatabaseProvider)),
);

final Provider<SyncEnqueuer> syncEnqueuerProvider = Provider<SyncEnqueuer>(
  (Ref ref) => ref.watch(syncQueueDaoProvider),
);

final Provider<SyncService> syncServiceProvider = Provider<SyncService>((
  Ref ref,
) {
  final SyncService service = SyncService(
    dio: ref.watch(dioProvider),
    queue: ref.watch(syncQueueDaoProvider),
    isOnline: ref.watch(isOnlineProvider),
  );
  service.start(
    ref.watch(connectivityStreamProvider).handleError((Object _) {}),
  );

  unawaited(service.syncNow());
  ref.onDispose(service.dispose);
  return service;
});

final StreamProvider<int> pendingSyncCountProvider = StreamProvider<int>(
  (Ref ref) => ref.watch(syncQueueDaoProvider).watchPendingCount(),
);
