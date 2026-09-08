import '../../../../core/localization/language.dart';
import '../entities/auth_user.dart';

/// The auth vertical's boundary between domain and data.
///
/// `login`/`register` throw [NetworkFailure] when offline (no request is
/// attempted — first-time auth is the one part of the app allowed to require
/// connectivity), [InvalidCredentialsFailure]/[AccountLockedFailure] on a
/// rejected login, [PhoneAlreadyRegisteredFailure] on a taken phone.
/// `getMe` throws [SessionExpiredFailure] on a 401, never
/// [InvalidCredentialsFailure] — the token expired, the PIN was never wrong.
///
/// `cachedUser`/`hasValidSession` are local-only reads with no use case of
/// their own: they back session restore, not a user action.
abstract interface class AuthRepository {
  Future<AuthUser> login({required String phone, required String pin});

  Future<AuthUser> register({
    required String phone,
    required String pin,
    required String name,
    required AppLanguage language,
  });

  Future<AuthUser> getMe();

  Future<void> logout();

  /// The last user cached on this device, or null if none is cached.
  Future<AuthUser?> cachedUser();

  /// True when a token exists and has not locally expired. Never touches the
  /// network — this is what the real `AuthGate` implementation is built from.
  Future<bool> hasValidSession();
}
