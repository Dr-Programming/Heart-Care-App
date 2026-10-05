import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/core_providers.dart';
import 'data/datasources/activity_local_datasource.dart';
import 'data/datasources/activity_remote_datasource.dart';
import 'data/repositories/activity_repository_impl.dart';
import 'domain/repositories/activity_repository.dart';

final Provider<ActivityLocalDataSource> activityLocalDataSourceProvider =
    Provider<ActivityLocalDataSource>(
      (Ref ref) => ActivityLocalDataSource(ref.watch(appDatabaseProvider)),
    );

final Provider<ActivityRepository> activityRepositoryProvider =
    Provider<ActivityRepository>(
      (Ref ref) => ref.watch(activityRepositoryImplProvider),
    );

final Provider<ActivityRepositoryImpl> activityRepositoryImplProvider =
    Provider<ActivityRepositoryImpl>(
      (Ref ref) => ActivityRepositoryImpl(
        local: ref.watch(activityLocalDataSourceProvider),
        syncEnqueuer: ref.watch(syncEnqueuerProvider),
        remote: ActivityRemoteDataSource(ref.watch(dioProvider)),
        isOnline: ref.watch(isOnlineProvider),
      ),
    );
