import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/providers/core_providers.dart';
import '../../data/datasources/activity_local_datasource.dart';
import '../../data/repositories/activity_repository_impl.dart';
import '../../domain/entities/activity_session.dart';
import '../../domain/repositories/activity_repository.dart';
import '../../domain/usecases/watch_activity_history.dart';

part 'activity_providers.g.dart';

/// The one place this feature builds its repository. Screens and controllers
/// depend on [ActivityRepository], never on this concrete type.
@riverpod
ActivityRepository activityRepository(Ref ref) {
  return ActivityRepositoryImpl(
    local: ActivityLocalDatasource(ref.watch(appDatabaseProvider)),
    sync: ref.watch(syncEnqueuerProvider),
  );
}

/// Reverse-chronological activity history, read from Drift. [from]/[to] let a
/// screen ask for exactly the window it needs — the full log, "today", or a
/// 7-day window for the weekly total — without over-fetching.
@riverpod
Stream<List<ActivitySession>> activityHistory(
  Ref ref, {
  DateTime? from,
  DateTime? to,
}) {
  final ActivityRepository repository = ref.watch(activityRepositoryProvider);
  return WatchActivityHistory(repository).call(from: from, to: to);
}
