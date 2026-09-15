import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/core_providers.dart';
import 'data/datasources/vitals_local_datasource.dart';
import 'data/repositories/vitals_repository_impl.dart';
import 'domain/repositories/vitals_repository.dart';
import 'domain/usecases/build_series.dart';
import 'domain/usecases/latest_by_type.dart';
import 'domain/usecases/log_vital.dart';
import 'domain/usecases/watch_history.dart';

final Provider<VitalsLocalDataSource> vitalsLocalDataSourceProvider =
    Provider<VitalsLocalDataSource>(
      (Ref ref) => VitalsLocalDataSource(ref.watch(appDatabaseProvider)),
    );

final Provider<VitalsRepository> vitalsRepositoryProvider =
    Provider<VitalsRepository>(
      (Ref ref) => VitalsRepositoryImpl(
        local: ref.watch(vitalsLocalDataSourceProvider),
        syncEnqueuer: ref.watch(syncEnqueuerProvider),
      ),
    );

final Provider<LogVital> logVitalProvider = Provider<LogVital>(
  (Ref ref) => LogVital(ref.watch(vitalsRepositoryProvider)),
);

final Provider<WatchHistory> watchHistoryProvider = Provider<WatchHistory>(
  (Ref ref) => WatchHistory(ref.watch(vitalsRepositoryProvider)),
);

final Provider<LatestByType> latestByTypeProvider = Provider<LatestByType>(
  (Ref ref) => LatestByType(ref.watch(vitalsRepositoryProvider)),
);

final Provider<BuildSeries> buildSeriesProvider = Provider<BuildSeries>(
  (Ref ref) => BuildSeries(ref.watch(vitalsRepositoryProvider)),
);
