import '../../../../core/db/app_database.dart' show SyncEntityType;
import '../../../../core/sync/sync_queue_dao.dart';
import '../../domain/entities/symptom_check_in.dart';
import '../../domain/entities/symptom_history_entry.dart';
import '../../domain/repositories/symptom_repository.dart';
import '../datasources/symptom_local_datasource.dart';
import '../datasources/symptom_remote_datasource.dart';
import '../models/symptom_model.dart';

/// The offline-first write path for symptom check-ins (FR-SYM-011), plus the
/// background reconciliation that backfills the server's assessment.
///
/// `log` writes local-then-queue, unconditionally — this class never checks
/// connectivity, and a save never awaits the network. Unlike activity, the
/// server *does* compute something here (the assessment), but the generic
/// `core/sync` engine's per-record result only carries
/// `{clientRecordId, status, serverId, reason}` — no `assessment` — because
/// it deliberately knows nothing about any feature's schema. So getting the
/// server's assessment back is this feature's own job, done lazily by
/// `reconcileServerAssessments` rather than by awaiting the sync push.
class SymptomRepositoryImpl implements SymptomRepository {
  const SymptomRepositoryImpl({
    required this._local,
    required this._sync,
    required this._remote,
    required this._syncQueue,
  });

  final SymptomLocalDatasource _local;
  final SyncEnqueuer _sync;
  final SymptomRemoteDatasource _remote;

  /// Read-only here — only `serverIds()` is used, never draining the queue.
  /// `core/sync`'s own docs name this as the sanctioned way for a feature to
  /// learn per-record sync state without storing one itself.
  final SyncQueueDao _syncQueue;

  @override
  Future<void> log(SymptomCheckIn checkIn) async {
    final SymptomModel model = SymptomModel.fromEntity(checkIn); // computes
    // the local assessment (design decision 2) before anything else happens.
    await _local.insert(model); // 1. device first, always
    await _sync.enqueue(
      // 2. then owe it to the server
      clientRecordId: checkIn.clientRecordId,
      entityType: SyncEntityType.symptom,
      payload: model.toApiRequestBody(),
      recordedAt: checkIn.measuredAt,
    ); // never awaits the network
  }

  @override
  Stream<List<SymptomHistoryEntry>> watchHistory({
    DateTime? from,
    DateTime? to,
  }) {
    return _local
        .watchHistory(from: from, to: to)
        .map(
          (List<SymptomModel> models) =>
              models.map((SymptomModel m) => m.toHistoryEntry()).toList(),
        );
  }

  @override
  Future<void> reconcileServerAssessments() async {
    try {
      final List<SymptomModel> pending = await _local.unconfirmed();
      if (pending.isEmpty) return;

      final Map<String, String> serverIds = await _syncQueue.serverIds(
        pending.map((SymptomModel m) => m.clientRecordId),
      );
      if (serverIds.isEmpty) return; // nothing has synced yet — try later

      final List<SymptomModel> confirmed = pending
          .where((SymptomModel m) => serverIds.containsKey(m.clientRecordId))
          .toList();

      // One GET spans the whole batch rather than one request per row —
      // metered data is a real constraint here (see SyncService's own
      // reasoning for the same choice on the push side).
      final DateTime from = confirmed
          .map((SymptomModel m) => m.measuredAt)
          .reduce((DateTime a, DateTime b) => a.isBefore(b) ? a : b);
      final DateTime to = confirmed
          .map((SymptomModel m) => m.measuredAt)
          .reduce((DateTime a, DateTime b) => a.isAfter(b) ? a : b);

      final List<SymptomModel> authoritative = await _remote.fetchHistory(
        from: from,
        to: to,
      );
      final Map<String, SymptomModel> byClientId = <String, SymptomModel>{
        for (final SymptomModel m in authoritative) m.clientRecordId: m,
      };

      for (final SymptomModel local in confirmed) {
        final SymptomModel? fromServer = byClientId[local.clientRecordId];
        final String? serverId = serverIds[local.clientRecordId];
        if (fromServer == null || serverId == null) continue;
        await _local.applyServerAssessment(
          clientRecordId: local.clientRecordId,
          serverId: serverId,
          assessment: fromServer.assessment,
          overallSeverity: fromServer.overallSeverity,
        );
      }
    } catch (_) {
      // Best-effort: offline, a transport error, or anything else just means
      // "nothing to do this time" — the row stays unconfirmed and is
      // retried on the next call. Never surfaced to the user; this is
      // background consistency, not a user-facing operation.
    }
  }
}
