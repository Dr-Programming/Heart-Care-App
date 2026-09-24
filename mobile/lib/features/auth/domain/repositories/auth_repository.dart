import '../entities/auth_user.dart';

abstract interface class AuthRepository {
  Future<AuthUser> login({required String phone, required String pin});

  Future<AuthUser> register({
    required String phone,
    required String pin,
    required String name,
    required String preferredLanguage,
  });

  Future<AuthUser> getMe();

  /// If the patient signed in offline, trades that session for a real one now
  /// that the server may be reachable. Returns false only when the server
  /// rejected the credentials, meaning the patient must sign in again.
  Future<bool> refreshSession();

  Future<void> logout();

  Future<AuthUser?> cachedUser();

  Future<bool> isSignedIn();

  Future<bool> needsOnboarding();
}
