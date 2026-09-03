import 'package:dio/dio.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/localization/language.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/security/jwt.dart';
import '../../domain/entities/auth_user.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_local_datasource.dart';
import '../datasources/auth_remote_datasource.dart';
import '../models/auth_response_model.dart';
import '../models/user_model.dart';

class AuthRepositoryImpl implements AuthRepository {
  const AuthRepositoryImpl(
    this._remote,
    this._local, {
    required Future<bool> Function() isOnline,
    // Keep the public parameter name `isOnline`; the backing field stays private.
    // ignore: prefer_initializing_formals
  }) : _isOnline = isOnline;

  final AuthRemoteDataSource _remote;
  final AuthLocalDataSource _local;
  final Future<bool> Function() _isOnline;

  @override
  Future<AuthUser> login({required String phone, required String pin}) async {
    await _requireConnection();
    final AuthResponseModel result =
        await _guard(() => _remote.login(phone: phone, pin: pin));
    await _local.saveSession(token: result.token, user: result.user);
    return result.user.toEntity();
  }

  @override
  Future<AuthUser> register({
    required String phone,
    required String pin,
    required String name,
    required AppLanguage language,
  }) async {
    await _requireConnection();
    final AuthResponseModel result = await _guard(
      () => _remote.register(
        phone: phone, pin: pin, name: name, languageCode: language.code,
      ),
    );
    await _local.saveSession(token: result.token, user: result.user);
    return result.user.toEntity();
  }

  @override
  Future<AuthUser> getMe() async {
    final UserModel user = await _guard(_remote.me, unauthorizedMeansExpired: true);
    await _local.cacheUser(user);
    return user.toEntity();
  }

  @override
  Future<AuthUser?> cachedUser() async => (await _local.readUser())?.toEntity();

  @override
  Future<bool> hasValidSession() async {
    final String? token = await _local.readToken();
    if (token == null || token.isEmpty) return false;
    return !isJwtExpired(token);
  }

  @override
  Future<void> logout() => _local.clear();

  /// First-time auth is inherently online. Checking up front turns a confusing
  /// timeout into an immediate, honest message.
  Future<void> _requireConnection() async {
    if (!await _isOnline()) {
      throw const NetworkFailure('errors.offline');
    }
  }

  /// Converts Dio's exceptions into the `Failure` vocabulary.
  ///
  /// [unauthorizedMeansExpired] disambiguates 401: on `login` it means the PIN
  /// was wrong, on `me` it means the 7-day token ran out. The status code
  /// alone cannot tell these apart, so the caller supplies the context.
  Future<T> _guard<T>(
    Future<T> Function() action, {
    bool unauthorizedMeansExpired = false,
  }) async {
    try {
      return await action();
    } on DioException catch (e) {
      final Failure failure = failureFromDioException(e);
      if (unauthorizedMeansExpired && failure is InvalidCredentialsFailure) {
        throw SessionExpiredFailure(failure.message);
      }
      throw failure;
    }
  }
}
