import 'dart:convert';

import 'package:drift/drift.dart';

import '../db/app_database.dart';

/// What a feature slice is allowed to do to the sync queue: add to it.
///
/// Draining it, retrying it and interpreting the server's answer all belong to
/// the sync engine. Depending on this narrow interface rather than on
/// [SyncQueueDao] also means a feature's repository test can pass a one-method
/// fake instead of a database.
abstract interface class SyncEnqueuer {
  /// Records that [payload] still has to reach the server.
  ///
  /// Call this in the same transaction as the local write, immediately after
  /// it. [clientRecordId] must be the id already stored on the local row —
  /// that is what makes a replay idempotent.
  Future<void> enqueue({
    required String clientRecordId,
    required SyncEntityType entityType,
    required Map<String, dynamic> payload,
    required DateTime recordedAt,
  });
}

/// Reads and writes the outbound queue.
///
/// Deliberately a plain class over [AppDatabase] rather than a Drift
/// `@DriftAccessor`: feature slices are asked to write their local datasources
/// the same way, so that adding a feature never means regenerating a shared
/// file. This is the reference implementation of that pattern.
class SyncQueueDao implements SyncEnqueuer {
  const SyncQueueDao(this._db);

  final AppDatabase _db;

  /// The server caps a batch at 200 records.
  static const int maxBatchSize = 200;

  @override
  Future<void> enqueue({
    required String clientRecordId,
    required SyncEntityType entityType,
    required Map<String, dynamic> payload,
    required DateTime recordedAt,
  }) async {
    await _db
        .into(_db.syncQueueEntries)
        .insert(
          SyncQueueEntriesCompanion.insert(
            clientRecordId: clientRecordId,
            entityType: entityType.wire,
            payloadJson: jsonEncode(payload),
            status: LocalSyncStatus.pending,
            recordedAt: recordedAt,
            createdLocallyAt: DateTime.now(),
          ),
          // A record can legitimately be enqueued twice - the user taps save,
          // the app dies before the queue row commits, the app retries. The
          // UNIQUE (entity_type, client_record_id) constraint plus this mode
          // makes that a no-op instead of a crash or a duplicate push.
          mode: InsertMode.insertOrIgnore,
        );
  }

  /// The next records to push, oldest capture first.
  ///
  /// Ordered by `recordedAt` so the server receives clinical history in the
  /// order it happened. Dose logs that reference a medication still sitting in
  /// the queue are safe regardless of order: the server always processes
  /// MEDICATION records before DOSE_LOG ones within a batch.
  Future<List<SyncQueueEntry>> pending({int limit = maxBatchSize}) {
    return (_db.select(_db.syncQueueEntries)
          ..where(
            ($SyncQueueEntriesTable t) =>
                t.status.equalsValue(LocalSyncStatus.pending),
          )
          ..orderBy(<OrderingTerm Function($SyncQueueEntriesTable)>[
            ($SyncQueueEntriesTable t) => OrderingTerm.asc(t.recordedAt),
          ])
          ..limit(limit))
        .get();
  }

  Future<void> markSyncing(List<int> ids) async {
    if (ids.isEmpty) return;
    await (_db.update(
      _db.syncQueueEntries,
    )..where(($SyncQueueEntriesTable t) => t.id.isIn(ids))).write(
      const SyncQueueEntriesCompanion(
        status: Value<LocalSyncStatus>(LocalSyncStatus.syncing),
      ),
    );
  }

  /// Records the server's verdict for one entry.
  Future<void> markResult(
    int id, {
    required LocalSyncStatus status,
    String? serverId,
    String? error,
  }) async {
    await (_db.update(
      _db.syncQueueEntries,
    )..where(($SyncQueueEntriesTable t) => t.id.equals(id))).write(
      SyncQueueEntriesCompanion(
        status: Value<LocalSyncStatus>(status),
        serverId: Value<String?>(serverId),
        lastError: Value<String?>(error),
      ),
    );
  }

  /// Puts a batch back after a transport failure and counts the attempt.
  ///
  /// Only entries still marked `syncing` are touched, so a result that did
  /// land is never dragged back into the queue.
  Future<void> releaseForRetry(List<int> ids, {String? error}) async {
    if (ids.isEmpty) return;
    await _db.transaction(() async {
      final List<SyncQueueEntry> stuck =
          await (_db.select(_db.syncQueueEntries)..where(
                ($SyncQueueEntriesTable t) =>
                    t.id.isIn(ids) &
                    t.status.equalsValue(LocalSyncStatus.syncing),
              ))
              .get();

      for (final SyncQueueEntry entry in stuck) {
        await (_db.update(
          _db.syncQueueEntries,
        )..where(($SyncQueueEntriesTable t) => t.id.equals(entry.id))).write(
          SyncQueueEntriesCompanion(
            status: const Value<LocalSyncStatus>(LocalSyncStatus.pending),
            attempts: Value<int>(entry.attempts + 1),
            lastError: Value<String?>(error),
          ),
        );
      }
    });
  }

  /// How many records this device still owes the server. Drives the "N
  /// waiting to sync" indicator (FR-OFF-003).
  Stream<int> watchPendingCount() {
    final Expression<int> count = _db.syncQueueEntries.id.count();
    return (_db.selectOnly(_db.syncQueueEntries)
          ..addColumns(<Expression<Object>>[count])
          ..where(
            _db.syncQueueEntries.status.equalsValue(LocalSyncStatus.pending),
          ))
        .map((TypedResult row) => row.read(count) ?? 0)
        .watchSingle();
  }

  /// Per-record sync state, for a status badge in a history list. Features
  /// join on this instead of storing a status column of their own.
  Future<LocalSyncStatus?> statusFor(String clientRecordId) async {
    final SyncQueueEntry? entry =
        await (_db.select(_db.syncQueueEntries)
              ..where(
                ($SyncQueueEntriesTable t) =>
                    t.clientRecordId.equals(clientRecordId),
              )
              ..limit(1))
            .getSingleOrNull();
    return entry?.status;
  }

  /// Server ids for records that have synced, keyed by client record id.
  Future<Map<String, String>> serverIds(
    Iterable<String> clientRecordIds,
  ) async {
    final List<String> ids = clientRecordIds.toList();
    if (ids.isEmpty) return <String, String>{};
    final List<SyncQueueEntry> rows =
        await (_db.select(_db.syncQueueEntries)..where(
              ($SyncQueueEntriesTable t) =>
                  t.clientRecordId.isIn(ids) & t.serverId.isNotNull(),
            ))
            .get();
    return <String, String>{
      for (final SyncQueueEntry r in rows)
        if (r.serverId != null) r.clientRecordId: r.serverId!,
    };
  }

  /// Records the server refused outright. Surfaced in settings as "N records
  /// could not be saved" rather than retried forever (FR-OFF-008).
  Future<List<SyncQueueEntry>> rejected() {
    return (_db.select(_db.syncQueueEntries)..where(
          ($SyncQueueEntriesTable t) =>
              t.status.equalsValue(LocalSyncStatus.rejected),
        ))
        .get();
  }
}
