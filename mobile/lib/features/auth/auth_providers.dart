import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/core_providers.dart';
import 'data/datasources/auth_local_datasource.dart';
import 'data/datasources/auth_remote_datasource.dart';
import 'data/repositories/auth_repository_impl.dart';
import 'domain/repositories/auth_repository.dart';

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
