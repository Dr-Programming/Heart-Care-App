import 'package:dio/dio.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/network/dio_client.dart';
import '../../domain/entities/auth_user.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_local_datasource.dart';
import '../datasources/auth_remote_datasource.dart';

const String _offlineMessage = 'You need a connection to sign in the first time';

class AuthRepositoryImpl implements AuthRepository {
  const AuthRepositoryImpl({
    required this.remote,
    required this.local,
    required this.isOnline,
  });

  final AuthRemoteDataSource remote;
  final AuthLocalDataSource local;

  final Future<bool> Function() isOnline;

  @override
  Future<AuthUser> login({required String phone, required String pin}) async {
    if (!await isOnline()) throw const NetworkFailure(_offlineMessage);
    try {
      final response = await remote.login(phone: phone, pin: pin);
      final user = response.user.toDomain();
      await local.saveSession(token: response.token, user: user);
      return user;
    } on DioException catch (e) {
      throw failureFromDioException(e);
    }
  }

  @override
  Future<AuthUser> register({
    required String phone,
    required String pin,
    required String name,
    required String preferredLanguage,
  }) async {
    if (!await isOnline()) throw const NetworkFailure(_offlineMessage);
    try {
      final response = await remote.register(
        phone: phone,
        pin: pin,
        name: name,
        preferredLanguage: preferredLanguage,
      );
      final user = response.user.toDomain();
      await local.saveSession(token: response.token, user: user);
      return user;
    } on DioException catch (e) {
      throw failureFromDioException(e);
    }
  }

  @override
  Future<AuthUser> getMe() async {
    try {
      final model = await remote.me();
      return model.toDomain();
    } on DioException catch (e) {

      if (e.response?.statusCode == 401) {
        final dynamic data = e.response?.data;
        final String message = data is Map && data['message'] is String
            ? data['message'] as String
            : 'Session expired';
        throw SessionExpiredFailure(message);
      }
      throw failureFromDioException(e);
    }
  }

  @override
  Future<void> logout() => local.clearSession();

  @override
  Future<AuthUser?> cachedUser() => local.cachedUser();

  @override
  Future<bool> isSignedIn() => local.isSignedIn();

  @override
  Future<bool> needsOnboarding() => local.needsOnboarding();
}
