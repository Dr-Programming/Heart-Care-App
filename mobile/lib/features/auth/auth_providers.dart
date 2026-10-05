import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/sync/history_window.dart';
import '../../core/providers/core_providers.dart';
import '../../core/router/auth_gate.dart';
import 'data/datasources/auth_local_datasource.dart';
import 'data/datasources/auth_remote_datasource.dart';
import 'data/datasources/offline_credential_store.dart';
import 'data/datasources/pending_pin_change_store.dart';
import 'data/repositories/auth_repository_impl.dart';
import 'domain/repositories/auth_repository.dart';
import 'domain/repositories/pin_repository.dart';

final Provider<OfflineCredentialStore> offlineCredentialStoreProvider =
    Provider<OfflineCredentialStore>(
      (ref) => OfflineCredentialStore(ref.watch(secureStorageProvider)),
    );

/// Process-wide: it must outlive any rebuild of [authRepositoryProvider].
final Provider<OfflineSession> offlineSessionProvider =
    Provider<OfflineSession>((ref) => OfflineSession());

final Provider<PendingPinChangeStore> pendingPinChangeStoreProvider =
    Provider<PendingPinChangeStore>(
      (ref) => PendingPinChangeStore(ref.watch(secureStorageProvider)),
    );

/// The one implementation behind both [authRepositoryProvider] and
/// [pinRepositoryProvider], so sign-in and PIN changes share the same stores.
final Provider<AuthRepositoryImpl> authRepositoryImplProvider =
    Provider<AuthRepositoryImpl>((ref) {
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
        pending: ref.watch(pendingPinChangeStoreProvider),
        isOnline: ref.watch(isOnlineProvider),
        onPatientSwitch: () => ref.read(patientSwitchHandlerProvider)(),
        unsentRecordCount: () => db.unsentRecordCount(),
      );
    });

final Provider<AuthRepository> authRepositoryProvider =
    Provider<AuthRepository>((ref) => ref.watch(authRepositoryImplProvider));

/// PIN change and forgot-PIN (both work offline).
final Provider<PinRepository> pinRepositoryProvider = Provider<PinRepository>(
  (ref) => ref.watch(authRepositoryImplProvider),
);

/// Why the app last signed the patient out by itself, shown once on the
/// sign-in screen. Set from [PinRepository.takeSignOutReason].
class SignOutNoticeNotifier extends Notifier<SignOutReason?> {
  @override
  SignOutReason? build() => null;

  void show(SignOutReason? reason) {
    if (reason != null) state = reason;
  }

  void clear() => state = null;
}

final NotifierProvider<SignOutNoticeNotifier, SignOutReason?>
signOutNoticeProvider = NotifierProvider<SignOutNoticeNotifier, SignOutReason?>(
  SignOutNoticeNotifier.new,
);

/// Plugged into the sync engine as [sessionRefresherProvider]: before each
/// sync, an offline sign-in is traded for a server session, and a patient
/// whose PIN the server no longer accepts is sent back to the sign-in screen.
final Provider<Future<bool> Function()> authSessionRefresherProvider =
    Provider<Future<bool> Function()>((ref) {
      return () async {
        final bool stillValid = await ref
            .read(authRepositoryProvider)
            .refreshSession();
        // An offline sign-in or reset just became a server session: fetch
        // what the phone is missing, as a sign-in would.
        if (stillValid &&
            ref.read(authRepositoryImplProvider).takeServerSessionStarted()) {
          unawaited(
            ref.read(restoreFromServerProvider)().catchError((Object _) {}),
          );
        }
        if (!stillValid) {
          final AuthRepository repo = ref.read(authRepositoryProvider);
          if (repo case final PinRepository pins) {
            ref
                .read(signOutNoticeProvider.notifier)
                .show(pins.takeSignOutReason());
          }
          await ref.read(realAuthGateProvider.notifier).refresh();
        }
        return stillValid;
      };
    });

/// Plugged into core as [sessionExpiredHandlerProvider]: the server refused
/// to renew the session, so end it here and let the gate send the patient to
/// the sign-in screen.
final Provider<Future<void> Function()> authSessionExpiredHandlerProvider =
    Provider<Future<void> Function()>((ref) {
      return () async {
        await ref.read(authRepositoryImplProvider).expireSession();
        await ref.read(realAuthGateProvider.notifier).refresh();
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
      // The checks above take a moment; the gate may have been rebuilt or
      // disposed meanwhile (sign-out, a test tearing down), and a disposed
      // notifier must not be written to.
      if (!ref.mounted) return;
      state = RealAuthGate(
        isResolved: true,
        isSignedIn: signedIn,
        hasChosenLanguage: hasChosenLanguage,
        needsOnboarding: needsOnboarding,
      );
    } on Object {
      if (!ref.mounted) return;
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
