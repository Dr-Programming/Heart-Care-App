import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:libu_care/core/providers/core_providers.dart';

import 'data/datasources/vitals_local_datasource.dart';
import 'data/datasources/vitals_remote_datasource.dart';
import 'data/repositories/vitals_repository_impl.dart';
import 'domain/repositories/vitals_repository.dart';
import 'domain/usecases/build_series.dart';
import 'domain/usecases/latest_by_type.dart';
import 'domain/usecases/log_vital.dart';
import 'domain/usecases/watch_history.dart';

/// This feature's own provider graph. Nothing here is imported by another
/// feature; cross-feature composition happens only in
/// `lib/app/app_wiring.dart` (architectural rule #1).

/// Not read by anything in this slice — see the design note on Task 7 and
/// Task 9. Declared for architecture-template consistency and so a future
/// restore-on-login feature has it ready to inject.
final Provider<VitalsRemoteDataSource> vitalsRemoteDataSourceProvider =
    Provider<VitalsRemoteDataSource>(
      (Ref ref) => VitalsRemoteDataSource(ref.watch(dioProvider)),
    );

final Provider<VitalsLocalDataSource> vitalsLocalDataSourceProvider =
    Provider<VitalsLocalDataSource>(
      (Ref ref) => VitalsLocalDataSource(ref.watch(appDatabaseProvider)),
    );

final Provider<VitalsRepository> vitalsRepositoryProvider =
    Provider<VitalsRepository>(
      (Ref ref) => VitalsRepositoryImpl(
        local: ref.watch(vitalsLocalDataSourceProvider),
        sync: ref.watch(syncEnqueuerProvider),
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
  (Ref ref) => const BuildSeries(),
);
