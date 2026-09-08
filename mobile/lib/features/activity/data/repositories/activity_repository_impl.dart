import '../../../../core/db/app_database.dart' show SyncEntityType;
import '../../../../core/sync/sync_queue_dao.dart' show SyncEnqueuer;
import '../../domain/entities/activity_session.dart';
import '../../domain/repositories/activity_repository.dart';
import '../datasources/activity_local_datasource.dart';
import '../models/activity_model.dart';

/// The offline-first write path for activity logging (FR-ACT-005).
///
/// Writes go local-then-queue, unconditionally — this class never checks
/// connectivity and never calls the API directly. Unlike symptoms, the
/// server computes nothing from an activity session (`backend/docs/API.md`
/// §6), so there is nothing worth fetching back immediately; `core/sync`
/// drains the queue on its own schedule.
class ActivityRepositoryImpl implements ActivityRepository {
  const ActivityRepositoryImpl({required this._local, required this._sync});

  final ActivityLocalDatasource _local;
  final SyncEnqueuer _sync;

  @override
  Future<void> log(ActivitySession session) async {
    final ActivityModel model = ActivityModel.fromEntity(session);
    await _local.insert(model); // 1. device first, always
    await _sync.enqueue(
      // 2. then owe it to the server
      clientRecordId: session.clientRecordId,
      entityType: SyncEntityType.activity,
      payload: model.toApiRequestBody(),
      recordedAt: session.measuredAt,
    ); // never awaits the network
  }

  @override
  Stream<List<ActivitySession>> watchHistory({DateTime? from, DateTime? to}) {
    return _local
        .watchHistory(from: from, to: to)
        .map(
          (List<ActivityModel> models) =>
              models.map((ActivityModel m) => m.toEntity()).toList(),
        );
  }
}
