import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';

import '../constants/api_endpoints.dart';
import '../db/app_database.dart';
import '../error/failure.dart';
import '../network/api_response.dart';
import '../network/dio_client.dart';
import 'sync_queue_dao.dart';

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

  final int retryable;

  final Failure? failure;

  final bool skippedOffline;

  bool get didWork => synced + conflicts + rejected > 0;

  bool get shouldNotifyUser => failure != null || rejected > 0;
}

class SyncService {
  SyncService({
    required this._dio,
    required this._queue,
    required this._isOnline,
    Future<bool> Function()? refreshSession,
  }) : _refreshSession = refreshSession ?? _alwaysValid;

  final Dio _dio;
  final SyncQueueDao _queue;
  final Future<bool> Function() _isOnline;
  final Future<bool> Function() _refreshSession;

  static Future<bool> _alwaysValid() async => true;

  StreamSubscription<bool>? _connectivity;

  bool _draining = false;

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

  Future<SyncReport> syncNow() async {
    if (_draining) return const SyncReport();
    _draining = true;
    try {
      if (!await _isOnline()) return const SyncReport.offline();

      if (!await _refreshSession()) {
        return const SyncReport(
          failure: SessionExpiredFailure('Sign in again to sync.'),
        );
      }

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

  LocalSyncStatus _statusFromWire(String? status) => switch (status) {
    'SAVED' => LocalSyncStatus.synced,
    'DUPLICATE' => LocalSyncStatus.synced,
    'CONFLICT' => LocalSyncStatus.conflict,
    'REJECTED' => LocalSyncStatus.rejected,
    _ => LocalSyncStatus.pending,
  };
}
