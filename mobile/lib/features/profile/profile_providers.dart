import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/core_providers.dart';
import 'data/datasources/profile_local_datasource.dart';
import 'data/datasources/profile_remote_datasource.dart';
import 'data/repositories/profile_repository_impl.dart';
import 'domain/repositories/profile_repository.dart';

final Provider<ProfileRepository> profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return ProfileRepositoryImpl(
    remote: ProfileRemoteDataSource(ref.watch(dioProvider)),
    local: ProfileLocalDataSource(db: db, preferencesDao: db.preferencesDao),
    isOnline: ref.watch(isOnlineProvider),
  );
});
