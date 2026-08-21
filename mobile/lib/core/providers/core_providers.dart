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

/// Riverpod is the DI container for this app — there is no `get_it`.
///
/// This file must not import anything from `features/`. Feature wiring lives
/// in that feature's own providers file.

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

/// Reads the token straight from the keystore, so the interceptor never needs
/// to know which feature owns the session.
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

/// Live connectivity, as a stream of "is there a usable interface".
///
/// connectivity_plus reports which interfaces exist, not whether the internet
/// is reachable through them, so this is a cheap negative signal: false means
/// definitely offline, true means worth attempting. Anything stronger would
/// need a probe request, which is exactly the kind of traffic NFR-008 asks us
/// not to spend on a metered connection.
///
/// Exposed as a plain stream as well as an [AsyncValue] because the sync
/// engine subscribes imperatively while widgets want the async snapshot.
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

/// The signed-in user as last cached on this device.
///
/// Lives in `core/` rather than the auth feature because the shell greets the
/// user and other features want their name and id, and none of them may import
/// auth. Auth owns *writing* this row; everyone else reads it from here.
///
/// Null means signed out — or means the cache has not been written yet, which
/// is why it is never used to decide whether the user is signed in. That is
/// the auth gate's job.
final StreamProvider<CachedUser?> cachedUserProvider =
    StreamProvider<CachedUser?>(
      (Ref ref) => ref.watch(appDatabaseProvider).cachedUserDao.watchCurrent(),
    );

// ---------------------------------------------------------------------------
// Sync
// ---------------------------------------------------------------------------

final Provider<SyncQueueDao> syncQueueDaoProvider = Provider<SyncQueueDao>(
  (Ref ref) => SyncQueueDao(ref.watch(appDatabaseProvider)),
);

/// What feature repositories depend on. Narrower than [syncQueueDaoProvider]
/// on purpose: a feature may add to the queue and may not drain it.
final Provider<SyncEnqueuer> syncEnqueuerProvider = Provider<SyncEnqueuer>(
  (Ref ref) => ref.watch(syncQueueDaoProvider),
);

/// Owns the push half of offline-first. Starts listening for reconnects as
/// soon as it is first read, which `AppShell` does on mount.
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
  ref.onDispose(service.dispose);
  return service;
});

/// How many records are still waiting to reach the server (FR-OFF-003).
final StreamProvider<int> pendingSyncCountProvider = StreamProvider<int>(
  (Ref ref) => ref.watch(syncQueueDaoProvider).watchPendingCount(),
);
