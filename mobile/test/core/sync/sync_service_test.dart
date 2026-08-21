import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:libu_care/core/constants/api_endpoints.dart';
import 'package:libu_care/core/db/app_database.dart';
import 'package:libu_care/core/error/failure.dart';
import 'package:libu_care/core/sync/sync_queue_dao.dart';
import 'package:libu_care/core/sync/sync_service.dart';

import '../../helpers/fake_dio.dart';
import '../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late SyncQueueDao queue;
  late FakeDio http;

  setUp(() {
    db = testDatabase();
    queue = SyncQueueDao(db);
    http = FakeDio();
  });

  tearDown(() => db.close());

  SyncService serviceWith({bool online = true}) =>
      SyncService(dio: http.dio, queue: queue, isOnline: () async => online);

  Future<void> enqueueVital(String clientRecordId) => queue.enqueue(
    clientRecordId: clientRecordId,
    entityType: SyncEntityType.vital,
    payload: <String, dynamic>{
      'type': 'BLOOD_PRESSURE',
      'values': <String, dynamic>{'systolic': 130, 'diastolic': 85},
    },
    recordedAt: DateTime(2026, 8, 22, 9),
  );

  void stubResults(List<Map<String, dynamic>> results) {
    http.stub(
      ApiEndpoints.sync,
      FakeResponse.ok(<String, dynamic>{
        'results': results,
      }, message: 'Sync processed'),
    );
  }

  group('enqueue', () {
    test('a record starts pending', () async {
      await enqueueVital('a1');
      expect(await queue.statusFor('a1'), LocalSyncStatus.pending);
      expect(await queue.watchPendingCount().first, 1);
    });

    test('enqueuing the same record twice is a no-op', () async {
      await enqueueVital('a1');
      await enqueueVital('a1');
      expect((await queue.pending()).length, 1);
    });

    test('the payload is stored ready to post', () async {
      await enqueueVital('a1');
      final SyncQueueEntry entry = (await queue.pending()).single;
      expect(entry.entityType, 'VITAL');
      expect(
        (jsonDecode(entry.payloadJson) as Map<String, dynamic>)['type'],
        'BLOOD_PRESSURE',
      );
    });
  });

  group('syncNow', () {
    test('does nothing while offline, and keeps the record queued', () async {
      await enqueueVital('a1');

      final SyncReport report = await serviceWith(online: false).syncNow();

      expect(report.skippedOffline, isTrue);
      expect(http.requests, isEmpty);
      expect(await queue.statusFor('a1'), LocalSyncStatus.pending);
    });

    test('posts the queued records in one batch', () async {
      await enqueueVital('a1');
      await enqueueVital('a2');
      stubResults(<Map<String, dynamic>>[
        <String, dynamic>{'clientRecordId': 'a1', 'status': 'SAVED'},
        <String, dynamic>{'clientRecordId': 'a2', 'status': 'SAVED'},
      ]);

      await serviceWith().syncNow();

      expect(http.requests.length, 1, reason: 'FR-OFF-005: one batched call');
      final List<dynamic> sent =
          http.requests.single.json['records'] as List<dynamic>;
      expect(sent.length, 2);
      expect((sent.first as Map<String, dynamic>)['clientRecordId'], 'a1');
    });

    test('SAVED clears the record and records the server id', () async {
      await enqueueVital('a1');
      stubResults(<Map<String, dynamic>>[
        <String, dynamic>{
          'clientRecordId': 'a1',
          'status': 'SAVED',
          'serverId': 'srv-1',
        },
      ]);

      final SyncReport report = await serviceWith().syncNow();

      expect(report.synced, 1);
      expect(await queue.statusFor('a1'), LocalSyncStatus.synced);
      expect(await queue.serverIds(<String>['a1']), <String, String>{
        'a1': 'srv-1',
      });
      expect(await queue.watchPendingCount().first, 0);
    });

    test('DUPLICATE is success - an earlier attempt already landed', () async {
      await enqueueVital('a1');
      stubResults(<Map<String, dynamic>>[
        <String, dynamic>{'clientRecordId': 'a1', 'status': 'DUPLICATE'},
      ]);

      final SyncReport report = await serviceWith().syncNow();

      expect(report.synced, 1);
      expect(await queue.statusFor('a1'), LocalSyncStatus.synced);
    });

    test('CONFLICT is terminal - the stored record wins', () async {
      await enqueueVital('a1');
      stubResults(<Map<String, dynamic>>[
        <String, dynamic>{
          'clientRecordId': 'a1',
          'status': 'CONFLICT',
          'reason': 'A different payload is already stored.',
        },
      ]);

      final SyncReport report = await serviceWith().syncNow();

      expect(report.conflicts, 1);
      expect(await queue.statusFor('a1'), LocalSyncStatus.conflict);
      expect(await queue.pending(), isEmpty, reason: 'never retried');
    });

    test('REJECTED is terminal and is surfaced to the user', () async {
      await enqueueVital('a1');
      stubResults(<Map<String, dynamic>>[
        <String, dynamic>{
          'clientRecordId': 'a1',
          'status': 'REJECTED',
          'reason': 'systolic: must be at most 300',
        },
      ]);

      final SyncReport report = await serviceWith().syncNow();

      expect(report.rejected, 1);
      expect(report.shouldNotifyUser, isTrue);
      expect(await queue.pending(), isEmpty);
      expect(
        (await queue.rejected()).single.lastError,
        'systolic: must be at most 300',
      );
    });

    test(
      'a dropped connection requeues the batch and counts an attempt',
      () async {
        await enqueueVital('a1');
        http.stub(ApiEndpoints.sync, FakeResponse.offline());

        final SyncReport report = await serviceWith().syncNow();

        expect(report.failure, isA<NetworkFailure>());
        expect(report.retryable, 1);
        expect(report.shouldNotifyUser, isTrue, reason: 'FR-OFF-008');

        final SyncQueueEntry entry = (await queue.pending()).single;
        expect(entry.status, LocalSyncStatus.pending);
        expect(entry.attempts, 1);
      },
    );

    test('an expired token requeues rather than discarding records', () async {
      await enqueueVital('a1');
      http.stub(ApiEndpoints.sync, FakeResponse.error(401, 'Unauthorized'));

      final SyncReport report = await serviceWith().syncNow();

      expect(report.failure, isA<InvalidCredentialsFailure>());
      expect(await queue.statusFor('a1'), LocalSyncStatus.pending);
    });

    test('a record the server did not answer for stays queued', () async {
      await enqueueVital('a1');
      await enqueueVital('a2');
      stubResults(<Map<String, dynamic>>[
        <String, dynamic>{'clientRecordId': 'a1', 'status': 'SAVED'},
      ]);

      final SyncReport report = await serviceWith().syncNow();

      expect(report.synced, 1);
      expect(report.retryable, 1);
      expect(await queue.statusFor('a1'), LocalSyncStatus.synced);
      expect(
        await queue.statusFor('a2'),
        LocalSyncStatus.pending,
        reason: 'must not be stranded in syncing',
      );
    });

    test('an empty queue makes no request', () async {
      final SyncReport report = await serviceWith().syncNow();

      expect(http.requests, isEmpty);
      expect(report.didWork, isFalse);
    });

    test('drains oldest capture first', () async {
      await queue.enqueue(
        clientRecordId: 'newer',
        entityType: SyncEntityType.vital,
        payload: <String, dynamic>{},
        recordedAt: DateTime(2026, 8, 22, 18),
      );
      await queue.enqueue(
        clientRecordId: 'older',
        entityType: SyncEntityType.vital,
        payload: <String, dynamic>{},
        recordedAt: DateTime(2026, 8, 22, 6),
      );
      stubResults(<Map<String, dynamic>>[]);

      await serviceWith().syncNow();

      final List<dynamic> sent =
          http.requests.single.json['records'] as List<dynamic>;
      expect((sent.first as Map<String, dynamic>)['clientRecordId'], 'older');
    });
  });
}
