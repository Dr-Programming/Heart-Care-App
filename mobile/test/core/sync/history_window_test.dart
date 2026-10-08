import 'package:flutter_test/flutter_test.dart';
import 'package:libu_care/core/db/app_database.dart';
import 'package:libu_care/core/sync/history_window.dart';
import 'package:libu_care/core/sync/sync_queue_dao.dart';

import '../../helpers/test_database.dart';

void main() {
  final DateTime now = DateTime(2026, 10, 30, 14);

  test('downloads the last 7 days first, then the 3 weeks before', () {
    expect(restoreRanges(now: now), <DayRange>[
      DayRange(DateTime(2026, 10, 24), DateTime(2026, 10, 30)),
      DayRange(DateTime(2026, 10, 1), DateTime(2026, 10, 23)),
    ]);
    expect(restoreRanges(now: now).first.fromParam, '2026-10-24');
  });

  test('keeps 30 days, today included', () {
    expect(oldestKeptDay(now: now), DateTime(2026, 10, 1));
  });

  group('on the phone', () {
    late AppDatabase db;
    late SyncQueueDao queue;
    setUp(() {
      db = testDatabase();
      queue = SyncQueueDao(db);
    });
    tearDown(() => db.close());

    Future<void> vital(String id, DateTime at) => db
        .into(db.vitalsLogs)
        .insert(
          VitalsLogsCompanion.insert(
            clientRecordId: id,
            type: 'HEART_RATE',
            valuesJson: '{"heartRate":70}',
            measuredAt: at,
          ),
        );

    Future<void> queued(String id, DateTime at, LocalSyncStatus status) async {
      await queue.enqueue(
        clientRecordId: id,
        entityType: SyncEntityType.vital,
        payload: <String, dynamic>{},
        recordedAt: at,
      );
      if (status != LocalSyncStatus.pending) {
        final int entry = (await queue.pending())
            .firstWhere((e) => e.clientRecordId == id)
            .id;
        await queue.markSyncing(<int>[entry]);
        await queue.markResult(entry, status: status);
      }
    }

    Future<List<String>> vitalIds() async =>
        (await db.select(db.vitalsLogs).get())
            .map((VitalsLog v) => v.clientRecordId)
            .toList();

    test(
      'deletes synced records older than the month and keeps the rest',
      () async {
        final DateTime old = DateTime(2026, 9, 20);
        await vital('old-synced', old);
        await queued('old-synced', old, LocalSyncStatus.synced);
        await vital('old-from-server', old); // downloaded, never queued here
        await vital('old-unsent', old);
        await queued('old-unsent', old, LocalSyncStatus.pending);
        await vital('recent', DateTime(2026, 10, 20));

        final int removed = await db.pruneOldSyncedRecords(now: now);

        expect(removed, 2);
        expect(
          await vitalIds(),
          unorderedEquals(<String>['old-unsent', 'recent']),
        );
        // The finished queue entry went too; the unsent one stays.
        final List<String> left = (await db.select(db.syncQueueEntries).get())
            .map((e) => e.clientRecordId)
            .toList();
        expect(left, <String>['old-unsent']);
      },
    );

    test('old dose logs go by their scheduled day; medications stay', () async {
      await db
          .into(db.medications)
          .insert(
            MedicationsCompanion.insert(
              clientRecordId: 'm1',
              name: 'Amlodipine',
              doseMg: 5,
              frequency: 'QD',
              scheduleTimesJson: '["08:00"]',
              createdAt: DateTime(2026, 8, 1),
              updatedAt: DateTime(2026, 8, 1),
            ),
          );
      for (final (String id, String day) in <(String, String)>[
        ('d-old', '2026-09-15'),
        ('d-new', '2026-10-15'),
      ]) {
        await db
            .into(db.doseLogs)
            .insert(
              DoseLogsCompanion.insert(
                clientRecordId: id,
                medicationClientRecordId: 'm1',
                status: 'TAKEN',
                scheduledDate: day,
                loggedAt: DateTime.parse(day),
              ),
            );
      }

      await db.pruneOldSyncedRecords(now: now);

      expect(
        (await db.select(db.doseLogs).get()).map((d) => d.clientRecordId),
        <String>['d-new'],
      );
      expect(await db.select(db.medications).get(), hasLength(1));
    });

    test('counts records the server has not received yet', () async {
      await queued('a', now, LocalSyncStatus.pending);
      await queued('b', now, LocalSyncStatus.synced);
      await queued('c', now, LocalSyncStatus.rejected);

      expect(await db.unsentRecordCount(), 1);
    });
  });
}
