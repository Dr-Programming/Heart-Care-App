import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/core_providers.dart';
import '../../core/router/auth_gate.dart';
import 'data/datasources/auth_local_datasource.dart';
import 'data/datasources/auth_remote_datasource.dart';
import 'data/repositories/auth_repository_impl.dart';
import 'domain/repositories/auth_repository.dart';

final Provider<AuthRepository> authRepositoryProvider = Provider<AuthRepository>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return AuthRepositoryImpl(
    remote: AuthRemoteDataSource(ref.watch(dioProvider)),
    local: AuthLocalDataSource(
      tokenStore: ref.watch(tokenStoreProvider),
      cachedUserDao: db.cachedUserDao,
      preferencesDao: db.preferencesDao,
    ),
    isOnline: ref.watch(isOnlineProvider),
  );
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
      final bool hasChosenLanguage = await ref.read(languageStoreProvider).hasChosen();
      final bool needsOnboarding = signedIn ? await repo.needsOnboarding() : false;
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
