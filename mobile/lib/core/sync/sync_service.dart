import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';

import '../constants/api_endpoints.dart';
import '../db/app_database.dart';
import '../error/failure.dart';
import '../network/api_response.dart';
import '../network/dio_client.dart';
import 'sync_queue_dao.dart';

/// What one drain of the queue achieved.
class SyncReport {
  const SyncReport({
    this.attempted = 0,
    this.synced = 0,
    this.conflicts = 0,
    this.rejected = 0,
    this.retryable = 0,
    this.failure,
    this.skippedOffline = false,
  });

  const SyncReport.offline() : this(skippedOffline: true);

  final int attempted;
  final int synced;
  final int conflicts;
  final int rejected;

  /// Records that stayed in the queue and will be tried again.
  final int retryable;

  /// Set when the batch failed as a whole rather than per record.
  final Failure? failure;

  final bool skippedOffline;

  bool get didWork => synced + conflicts + rejected > 0;

  /// FR-OFF-008 — the user is told when a sync fails, and the records stay
  /// queued for retry.
  bool get shouldNotifyUser => failure != null || rejected > 0;
}

/// Pushes everything this device owes the server (FR-OFF-003 … FR-OFF-008).
///
/// Push-only by design: `POST /api/v1/sync` has no pull half, so this never
/// overwrites local data. It also never touches a feature table — the queue
/// carries whole payloads, so the engine is ignorant of every feature's
/// schema. That is what lets sync be owned by one person while five people own
/// the features.
class SyncService {
  SyncService({
    required this._dio,
    required this._queue,
    required this._isOnline,
  });

  final Dio _dio;
  final SyncQueueDao _queue;
  final Future<bool> Function() _isOnline;

  StreamSubscription<bool>? _connectivity;

  /// Guards against two drains overlapping — a reconnect event and a manual
  /// pull-to-refresh landing together would otherwise push the same batch
  /// twice. Harmless server-side thanks to `client_record_id`, but it wastes
  /// the metered data FR-OFF-005 exists to conserve.
  bool _draining = false;

  /// FR-OFF-004 — drain automatically whenever the device comes back online.
  ///
  /// Only the false-to-true edge triggers a sync; connectivity_plus emits on
  /// every interface change, and syncing on "wifi to mobile" would spend the
  /// user's data for nothing.
  void start(Stream<bool> onlineChanges) {
    _connectivity?.cancel();
    bool wasOnline = true;
    _connectivity = onlineChanges.listen((bool online) {
      final bool cameBack = online && !wasOnline;
      wasOnline = online;
      if (cameBack) unawaited(syncNow());
    });
  }

  Future<void> dispose() async {
    await _connectivity?.cancel();
    _connectivity = null;
  }

  /// Sends one batch. Call again while [SyncReport.didWork] is true to drain a
  /// backlog larger than a single batch.
  Future<SyncReport> syncNow() async {
    if (_draining) return const SyncReport();
    _draining = true;
    try {
      if (!await _isOnline()) return const SyncReport.offline();

      final List<SyncQueueEntry> batch = await _queue.pending();
      if (batch.isEmpty) return const SyncReport();

      final List<int> ids = batch.map((SyncQueueEntry e) => e.id).toList();
      await _queue.markSyncing(ids);

      try {
        final Response<dynamic> response = await _dio.post<dynamic>(
          ApiEndpoints.sync,
          data: <String, dynamic>{
            'records': batch
                .map(
                  (SyncQueueEntry e) => <String, dynamic>{
                    'clientRecordId': e.clientRecordId,
                    'entityType': e.entityType,
                    'payload': jsonDecode(e.payloadJson),
                  },
                )
                .toList(),
          },
        );
        return await _applyResults(batch, response);
      } on DioException catch (e) {
        final Failure failure = failureFromDioException(e);
        await _queue.releaseForRetry(ids, error: failure.message);
        return SyncReport(
          attempted: batch.length,
          retryable: batch.length,
          failure: failure,
        );
      } catch (e) {
        await _queue.releaseForRetry(ids, error: e.toString());
        return SyncReport(
          attempted: batch.length,
          retryable: batch.length,
          failure: UnknownFailure(e.toString()),
        );
      }
    } finally {
      _draining = false;
    }
  }

  Future<SyncReport> _applyResults(
    List<SyncQueueEntry> batch,
    Response<dynamic> response,
  ) async {
    final ApiResponse<List<dynamic>> envelope =
        ApiResponse<List<dynamic>>.fromJson(
          (response.data as Map<Object?, Object?>).cast<String, dynamic>(),
          (Object? data) =>
              ((data as Map<Object?, Object?>)['results'] as List<dynamic>?) ??
              <dynamic>[],
        );

    // One client record id can, in principle, sit in the queue under two
    // entity types; the constraint is on the pair. Group so a result is
    // applied to every entry it could refer to in this batch.
    final Map<String, List<SyncQueueEntry>> byClientId =
        <String, List<SyncQueueEntry>>{};
    for (final SyncQueueEntry entry in batch) {
      byClientId
          .putIfAbsent(entry.clientRecordId, () => <SyncQueueEntry>[])
          .add(entry);
    }

    int synced = 0;
    int conflicts = 0;
    int rejected = 0;
    final Set<int> answered = <int>{};

    for (final dynamic raw in envelope.data ?? <dynamic>[]) {
      if (raw is! Map) continue;
      final String? clientRecordId = raw['clientRecordId'] as String?;
      final List<SyncQueueEntry>? entries = byClientId[clientRecordId];
      if (entries == null) continue;

      final LocalSyncStatus status = _statusFromWire(raw['status'] as String?);
      for (final SyncQueueEntry entry in entries) {
        answered.add(entry.id);
        await _queue.markResult(
          entry.id,
          status: status,
          serverId: raw['serverId'] as String?,
          error: raw['reason'] as String?,
        );
      }

      switch (status) {
        case LocalSyncStatus.synced:
          synced += entries.length;
        case LocalSyncStatus.conflict:
          conflicts += entries.length;
        case LocalSyncStatus.rejected:
          rejected += entries.length;
        case LocalSyncStatus.pending:
        case LocalSyncStatus.syncing:
          break;
      }
    }

    // Anything the server did not mention stays owed. Leaving it stuck in
    // `syncing` would strand it forever.
    final List<int> unanswered = batch
        .map((SyncQueueEntry e) => e.id)
        .where((int id) => !answered.contains(id))
        .toList();
    await _queue.releaseForRetry(
      unanswered,
      error: 'No result returned for this record.',
    );

    return SyncReport(
      attempted: batch.length,
      synced: synced,
      conflicts: conflicts,
      rejected: rejected,
      retryable: unanswered.length,
    );
  }

  /// Maps the server's four per-record outcomes onto the local lifecycle.
  ///
  /// `SAVED` and `DUPLICATE` are both success — a duplicate means an earlier
  /// attempt already landed, which is exactly what `client_record_id` is for.
  /// `CONFLICT` is terminal because the stored record always wins and the
  /// incoming one is never written. `REJECTED` is permanent and must never be
  /// retried.
  LocalSyncStatus _statusFromWire(String? status) => switch (status) {
    'SAVED' => LocalSyncStatus.synced,
    'DUPLICATE' => LocalSyncStatus.synced,
    'CONFLICT' => LocalSyncStatus.conflict,
    'REJECTED' => LocalSyncStatus.rejected,
    _ => LocalSyncStatus.pending,
  };
}
