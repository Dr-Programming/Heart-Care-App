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

  Future<void> logout();

  Future<AuthUser?> cachedUser();

  Future<bool> isSignedIn();

  Future<bool> needsOnboarding();
}
