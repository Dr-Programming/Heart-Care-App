import '../../../../core/localization/language.dart';
import '../entities/auth_user.dart';

/// The auth feature's only outward contract.
///
/// Every method either returns its value or throws a `Failure` subclass;
/// there is no nullable-error return convention to remember.
abstract interface class AuthRepository {
  /// Requires connectivity. Throws `NetworkFailure` when offline,
  /// `InvalidCredentialsFailure` on a bad PIN, `AccountLockedFailure` on 423.
  Future<AuthUser> login({required String phone, required String pin});

  /// Requires connectivity. Throws `PhoneAlreadyRegisteredFailure` on 409.
  /// Succeeds auto-logged-in: the token is stored before this returns.
  Future<AuthUser> register({
    required String phone,
    required String pin,
    required String name,
    required AppLanguage language,
  });

  /// Fetches the user from the server. Throws `SessionExpiredFailure` on 401.
  Future<AuthUser> getMe();

  /// The locally cached user, or null. Never touches the network — this is
  /// what makes an offline launch land on Home.
  Future<AuthUser?> cachedUser();

  /// True when a token is stored and its `exp` has not passed. Checked
  /// locally; the server is not consulted.
  Future<bool> hasValidSession();

  /// Drops the token and the cached user.
  Future<void> logout();
}
