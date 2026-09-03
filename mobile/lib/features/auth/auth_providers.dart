import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/core_providers.dart';
import 'data/datasources/auth_local_datasource.dart';
import 'data/datasources/auth_remote_datasource.dart';
import 'data/repositories/auth_repository_impl.dart';
import 'domain/repositories/auth_repository.dart';
import 'domain/usecases/get_me.dart';
import 'domain/usecases/login.dart';
import 'domain/usecases/logout.dart';
import 'domain/usecases/register.dart';

final Provider<AuthLocalDataSource> authLocalDataSourceProvider =
    Provider<AuthLocalDataSource>((ref) => AuthLocalDataSource(
          ref.watch(tokenStoreProvider),
          ref.watch(appDatabaseProvider).cachedUserDao,
        ));

final Provider<AuthRemoteDataSource> authRemoteDataSourceProvider =
    Provider<AuthRemoteDataSource>(
        (ref) => AuthRemoteDataSource(ref.watch(dioProvider)));

final Provider<AuthRepository> authRepositoryProvider =
    Provider<AuthRepository>((ref) => AuthRepositoryImpl(
          ref.watch(authRemoteDataSourceProvider),
          ref.watch(authLocalDataSourceProvider),
          isOnline: ref.watch(isOnlineProvider),
        ));

// Use cases (spec §3.4). Thin pass-throughs to the repository; the controller
// talks to these, never to the repository verbs directly.
final Provider<Login> loginUseCaseProvider =
    Provider<Login>((ref) => Login(ref.watch(authRepositoryProvider)));

final Provider<Register> registerUseCaseProvider =
    Provider<Register>((ref) => Register(ref.watch(authRepositoryProvider)));

final Provider<GetMe> getMeUseCaseProvider =
    Provider<GetMe>((ref) => GetMe(ref.watch(authRepositoryProvider)));

final Provider<Logout> logoutUseCaseProvider =
    Provider<Logout>((ref) => Logout(ref.watch(authRepositoryProvider)));
