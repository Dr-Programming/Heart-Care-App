import 'dart:convert';

import 'package:drift/drift.dart';

import '../db/app_database.dart';

abstract interface class SyncEnqueuer {
  Future<void> enqueue({
    required String clientRecordId,
    required SyncEntityType entityType,
    required Map<String, dynamic> payload,
    required DateTime recordedAt,
  });
}

class SyncQueueDao implements SyncEnqueuer {
  const SyncQueueDao(this._db);

  final AppDatabase _db;

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

          // A record edited before it is sent (a dose note changed while
          // offline) replaces the queued payload. Once sent it is left alone:
          // the server keeps the first version and would answer CONFLICT.
          onConflict: DoUpdate(
            ($SyncQueueEntriesTable old) => SyncQueueEntriesCompanion(
              payloadJson: Value<String>(jsonEncode(payload)),
              recordedAt: Value<DateTime>(recordedAt),
            ),
            target: <Column<Object>>[
              _db.syncQueueEntries.entityType,
              _db.syncQueueEntries.clientRecordId,
            ],
            where: ($SyncQueueEntriesTable old) =>
                old.status.equalsValue(LocalSyncStatus.pending),
          ),
        );
  }

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

  /// Records the server refused for good (a second check-in on one day, a
  /// dose after the medication was turned off...), for the patient to see.
  Stream<List<SyncQueueEntry>> watchRejected() {
    return (_db.select(_db.syncQueueEntries)..where(
          ($SyncQueueEntriesTable t) =>
              t.status.equalsValue(LocalSyncStatus.rejected),
        ))
        .watch();
  }

  /// The patient has seen why: forget the refused entries. The records stay
  /// on the phone; only their failed delivery is cleared.
  Future<void> dismissRejected() async {
    await (_db.delete(_db.syncQueueEntries)..where(
          ($SyncQueueEntriesTable t) =>
              t.status.equalsValue(LocalSyncStatus.rejected),
        ))
        .go();
  }

  Future<List<SyncQueueEntry>> rejected() {
    return (_db.select(_db.syncQueueEntries)..where(
          ($SyncQueueEntriesTable t) =>
              t.status.equalsValue(LocalSyncStatus.rejected),
        ))
        .get();
  }
}
