import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/core_providers.dart';
import '../../core/router/auth_gate.dart';
import 'data/datasources/auth_local_datasource.dart';
import 'data/datasources/auth_remote_datasource.dart';
import 'data/repositories/auth_repository_impl.dart';
import 'domain/repositories/auth_repository.dart';
import 'domain/usecases/get_me.dart';
import 'domain/usecases/login.dart';
import 'domain/usecases/logout.dart';
import 'domain/usecases/register.dart';
import 'presentation/controllers/auth_controller.dart';
import 'presentation/controllers/auth_state.dart';

final Provider<AuthRemoteDataSource> authRemoteDataSourceProvider =
    Provider<AuthRemoteDataSource>(
      (Ref ref) => AuthRemoteDataSource(ref.watch(dioProvider)),
    );

final Provider<AuthLocalDataSource> authLocalDataSourceProvider =
    Provider<AuthLocalDataSource>(
      (Ref ref) => AuthLocalDataSource(
        tokenStore: ref.watch(tokenStoreProvider),
        cachedUserDao: ref.watch(appDatabaseProvider).cachedUserDao,
      ),
    );

final Provider<AuthRepository> authRepositoryProvider =
    Provider<AuthRepository>(
      (Ref ref) => AuthRepositoryImpl(
        remote: ref.watch(authRemoteDataSourceProvider),
        local: ref.watch(authLocalDataSourceProvider),
        isOnline: ref.watch(isOnlineProvider),
      ),
    );

final Provider<Login> loginUseCaseProvider = Provider<Login>(
  (Ref ref) => Login(ref.watch(authRepositoryProvider)),
);

final Provider<Register> registerUseCaseProvider = Provider<Register>(
  (Ref ref) => Register(ref.watch(authRepositoryProvider)),
);

final Provider<GetMe> getMeUseCaseProvider = Provider<GetMe>(
  (Ref ref) => GetMe(ref.watch(authRepositoryProvider)),
);

final Provider<Logout> logoutUseCaseProvider = Provider<Logout>(
  (Ref ref) => Logout(ref.watch(authRepositoryProvider)),
);

/// True once the device has a stored language choice. A one-shot read rather
/// than a stream — `PreferencesDao` has no watch API — refreshed explicitly
/// by the language picker after it writes (see `LanguageScreen`).
final FutureProvider<bool> languageChosenProvider = FutureProvider<bool>(
  (Ref ref) => ref.watch(languageStoreProvider).hasChosen(),
);

/// The concrete [AuthGate]: derives every gate question from state `core/`
/// already owns the shape of — [AuthController]'s resolved session and
/// [languageChosenProvider] — without making a network call of its own, per
/// the contract on `AuthGate`.
class RealAuthGate implements AuthGate {
  const RealAuthGate({required this._authState, required this._languageChosen});

  final AsyncValue<AuthState> _authState;
  final AsyncValue<bool> _languageChosen;

  /// True once each side has produced a value at least once.
  ///
  /// Deliberately not `!isLoading` alone: `languageChosenProvider` is
  /// invalidated and refreshed every time `LanguageScreen` writes a choice,
  /// and Riverpod puts a refreshing provider back into a loading state while
  /// it recomputes — even though it still has last known value cached. Since
  /// `ProviderRefresh` re-runs the redirect on every change, an `isLoading`
  /// check alone would flip this false for that instant and bounce the app
  /// to splash mid-refresh. `hasValue` is true through a refresh (the cached
  /// value survives), so checking either lets a genuine first-ever load
  /// (`isLoading` with no value yet) count as unresolved while a later
  /// refresh does not. This also covers a failed login's bare [AsyncError]
  /// the same way `hasValue` alone would have: an error is neither loading
  /// nor unresolved, so it already passed before this change and still does.
  @override
  bool get isResolved =>
      (!_authState.isLoading || _authState.hasValue) &&
      (!_languageChosen.isLoading || _languageChosen.hasValue);

  @override
  bool get isSignedIn => _authState.value is AuthAuthenticated;

  @override
  bool get hasChosenLanguage => _languageChosen.value ?? false;

  /// Always false in this slice — the onboarding wizard is M2. Registration
  /// does not set this; flip it once M2's wizard exists.
  @override
  bool get needsOnboarding => false;
}

final Provider<AuthGate> realAuthGateProvider = Provider<AuthGate>(
  (Ref ref) => RealAuthGate(
    authState: ref.watch(authControllerProvider),
    languageChosen: ref.watch(languageChosenProvider),
  ),
);
