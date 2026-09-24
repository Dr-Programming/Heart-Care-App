import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../config/env.dart';
import '../db/app_database.dart';
import '../localization/language.dart';
import '../network/dio_client.dart';
import '../network/server_reachability.dart';
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

final Provider<ServerProbe> serverProbeProvider = Provider<ServerProbe>((
  Ref ref,
) {
  return ServerProbe(
    dio: ref.watch(dioProvider),
    hasConnectivity: ref.watch(isOnlineProvider),
  );
});

/// Live answer to "can we reach the API?", re-probed whenever the radio state
/// changes and on demand via [ServerReachabilityNotifier.refresh].
///
/// Screens that can only work online — registration — watch this to decide
/// whether to accept input at all.
class ServerReachabilityNotifier extends Notifier<ServerReachability> {
  /// Bumped on every rebuild *and* on dispose, so a probe that comes back late
  /// cannot write to a notifier that has moved on or been torn down.
  int _generation = 0;

  @override
  ServerReachability build() {
    final int generation = ++_generation;
    final ServerProbe probe = ref.watch(serverProbeProvider);

    final StreamSubscription<bool> subscription = ref
        .watch(connectivityStreamProvider)
        .listen(
          (bool _) => unawaited(_probe(probe, generation)),
          onError: (Object _) {},
        );
    ref.onDispose(subscription.cancel);
    ref.onDispose(() => _generation++);

    unawaited(_probe(probe, generation));
    return ServerReachability.checking;
  }

  Future<void> _probe(ServerProbe probe, int generation) async {
    final ServerReachability result = await probe.check();
    if (generation != _generation) return;
    state = result;
  }

  /// Re-runs the probe — used by the "try again" affordance on blocked screens.
  Future<void> refresh() async {
    final int generation = _generation;
    state = ServerReachability.checking;
    await _probe(ref.read(serverProbeProvider), generation);
  }
}

final NotifierProvider<ServerReachabilityNotifier, ServerReachability>
serverReachabilityProvider =
    NotifierProvider<ServerReachabilityNotifier, ServerReachability>(
      ServerReachabilityNotifier.new,
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

/// Run by the sync engine before every push. Returns false when the session
/// is no longer valid and the push should not happen. The auth feature
/// overrides this to trade an offline sign-in for a server token; core cannot
/// see auth, so the default is a no-op.
final Provider<Future<bool> Function()> sessionRefresherProvider =
    Provider<Future<bool> Function()>(
      (Ref ref) =>
          () async => true,
    );

final Provider<SyncService> syncServiceProvider = Provider<SyncService>((
  Ref ref,
) {
  final SyncService service = SyncService(
    dio: ref.watch(dioProvider),
    queue: ref.watch(syncQueueDaoProvider),
    isOnline: ref.watch(isOnlineProvider),
    refreshSession: ref.watch(sessionRefresherProvider),
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
