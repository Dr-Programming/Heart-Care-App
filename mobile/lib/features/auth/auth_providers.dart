import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/core_providers.dart';
import '../../core/router/auth_gate.dart';
import 'data/datasources/auth_local_datasource.dart';
import 'data/datasources/auth_remote_datasource.dart';
import 'data/datasources/offline_credential_store.dart';
import 'data/repositories/auth_repository_impl.dart';
import 'domain/repositories/auth_repository.dart';

final Provider<OfflineCredentialStore> offlineCredentialStoreProvider =
    Provider<OfflineCredentialStore>(
      (ref) => OfflineCredentialStore(ref.watch(secureStorageProvider)),
    );

/// Process-wide: it must outlive any rebuild of [authRepositoryProvider].
final Provider<OfflineSession> offlineSessionProvider =
    Provider<OfflineSession>((ref) => OfflineSession());

final Provider<AuthRepository> authRepositoryProvider =
    Provider<AuthRepository>((ref) {
      final db = ref.watch(appDatabaseProvider);
      return AuthRepositoryImpl(
        remote: AuthRemoteDataSource(ref.watch(dioProvider)),
        local: AuthLocalDataSource(
          tokenStore: ref.watch(tokenStoreProvider),
          cachedUserDao: db.cachedUserDao,
          preferencesDao: db.preferencesDao,
        ),
        offline: ref.watch(offlineCredentialStoreProvider),
        session: ref.watch(offlineSessionProvider),
        isOnline: ref.watch(isOnlineProvider),
      );
    });

/// Plugged into the sync engine as [sessionRefresherProvider]: before each
/// sync, an offline sign-in is traded for a server session, and a patient
/// whose PIN the server no longer accepts is sent back to the sign-in screen.
final Provider<Future<bool> Function()> authSessionRefresherProvider =
    Provider<Future<bool> Function()>((ref) {
      return () async {
        final bool stillValid = await ref
            .read(authRepositoryProvider)
            .refreshSession();
        if (!stillValid) {
          await ref.read(realAuthGateProvider.notifier).refresh();
        }
        return stillValid;
      };
    });

class RealAuthGate implements AuthGate {
  const RealAuthGate({
    required this.isResolved,
    required this.isSignedIn,
    required this.hasChosenLanguage,
    required this.needsOnboarding,
  });

  const RealAuthGate.unresolved()
    : isResolved = false,
      isSignedIn = false,
      hasChosenLanguage = false,
      needsOnboarding = false;

  @override
  final bool isResolved;

  @override
  final bool isSignedIn;

  @override
  final bool hasChosenLanguage;

  @override
  final bool needsOnboarding;
}

class RealAuthGateNotifier extends Notifier<AuthGate> {
  @override
  AuthGate build() {
    unawaited(_resolve());
    return const RealAuthGate.unresolved();
  }

  Future<void> refresh() => _resolve();

  Future<void> _resolve() async {
    try {
      final repo = ref.read(authRepositoryProvider);
      final bool signedIn = await repo.isSignedIn();
      final bool hasChosenLanguage = await ref
          .read(languageStoreProvider)
          .hasChosen();
      final bool needsOnboarding = signedIn
          ? await repo.needsOnboarding()
          : false;
      state = RealAuthGate(
        isResolved: true,
        isSignedIn: signedIn,
        hasChosenLanguage: hasChosenLanguage,
        needsOnboarding: needsOnboarding,
      );
    } on Object {
      state = const RealAuthGate(
        isResolved: true,
        isSignedIn: false,
        hasChosenLanguage: false,
        needsOnboarding: false,
      );
    }
  }
}

final NotifierProvider<RealAuthGateNotifier, AuthGate> realAuthGateProvider =
    NotifierProvider<RealAuthGateNotifier, AuthGate>(RealAuthGateNotifier.new);
