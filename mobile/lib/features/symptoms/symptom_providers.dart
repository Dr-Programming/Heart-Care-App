import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/core_providers.dart';
import 'data/datasources/symptom_local_datasource.dart';
import 'data/repositories/symptom_repository_impl.dart';
import 'domain/repositories/symptom_repository.dart';

final Provider<SymptomLocalDataSource> symptomLocalDataSourceProvider =
    Provider<SymptomLocalDataSource>(
      (Ref ref) => SymptomLocalDataSource(ref.watch(appDatabaseProvider)),
    );

final Provider<SymptomRepository> symptomRepositoryProvider =
    Provider<SymptomRepository>(
      (Ref ref) => SymptomRepositoryImpl(
        local: ref.watch(symptomLocalDataSourceProvider),
        syncEnqueuer: ref.watch(syncEnqueuerProvider),
      ),
    );
