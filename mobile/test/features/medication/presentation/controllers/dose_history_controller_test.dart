import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:libu_care/core/db/app_database.dart' hide DoseLog, Medication;
import 'package:libu_care/core/providers/core_providers.dart';
import 'package:libu_care/core/sync/sync_queue_dao.dart';
import 'package:libu_care/features/medication/domain/entities/dose_log.dart';
import 'package:libu_care/features/medication/domain/entities/medication.dart';
import 'package:libu_care/features/medication/medication_providers.dart';
import 'package:libu_care/features/medication/presentation/controllers/dose_history_controller.dart';

import '../../../../helpers/test_database.dart';
import '../../helpers/fake_medication_repository.dart';

DoseLog _log(String clientRecordId, String medicationId, String date) => DoseLog(
  clientRecordId: clientRecordId,
  serverId: null,
  medicationClientRecordId: medicationId,
  medicationServerId: null,
  status: DoseStatus.taken,
  scheduledDate: date,
  scheduledTime: '08:00',
  loggedAt: DateTime.utc(2026, 8, 25),
  note: null,
);

void main() {
  late AppDatabase db;
  late FakeMedicationRepository repo;

  setUp(() {
    db = testDatabase();
    repo = FakeMedicationRepository(
      medications: <Medication>[
        fakeMedication(clientRecordId: 'm1', name: 'Aspirin'),
        fakeMedication(clientRecordId: 'm2', name: 'Atorvastatin', active: false),
      ],
      history: <DoseLog>[
        _log('d1', 'm1', '2026-08-25'),
        _log('d2', 'm2', '2026-08-24'),
      ],
    );
  });

  tearDown(() => db.close());

  ProviderContainer container() {
    final ProviderContainer c = ProviderContainer(
      overrides: <Override>[
        medicationRepositoryProvider.overrideWithValue(repo),
        appDatabaseProvider.overrideWithValue(db),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  test('build fetches with no filter', () async {
    await container().read(doseHistoryControllerProvider.future);
    expect(repo.historyFilters, <String?>[null]);
  });

  test('setFilter refetches scoped to the chosen medication', () async {
    final ProviderContainer c = container();
    await c.read(doseHistoryControllerProvider.future);

    await c
        .read(doseHistoryControllerProvider.notifier)
        .setFilter(const DoseHistoryFilter(medicationClientRecordId: 'm1'));
    final DoseHistoryState state = await c.read(
      doseHistoryControllerProvider.future,
    );

    expect(repo.historyFilters.last, 'm1');
    // The state carries the filter back out so the chip row can render which
    // one is selected.
    expect(state.filter.medicationClientRecordId, 'm1');
    expect(state.entries, hasLength(1));
  });

  test('each row carries its medication name (I5)', () async {
    final DoseHistoryState state = await container().read(
      doseHistoryControllerProvider.future,
    );

    expect(
      state.entries.map((DoseHistoryEntry e) => e.medicationName),
      <String>['Aspirin', 'Atorvastatin'],
    );
  });

  test('the filter offers deactivated medications too (I5)', () async {
    // History outlives deactivation (Decision 1), so filtering to a stopped
    // medication has to stay possible.
    final DoseHistoryState state = await container().read(
      doseHistoryControllerProvider.future,
    );

    expect(
      state.medications.map((Medication m) => m.clientRecordId),
      <String>['m1', 'm2'],
    );
  });

  test('each row carries its sync status from the shared queue (I5)', () async {
    final SyncQueueDao queue = SyncQueueDao(db);
    await queue.enqueue(
      clientRecordId: 'd1',
      entityType: SyncEntityType.doseLog,
      payload: const <String, dynamic>{},
      recordedAt: DateTime.utc(2026, 8, 25),
    );

    final DoseHistoryState state = await container().read(
      doseHistoryControllerProvider.future,
    );

    final DoseHistoryEntry queued = state.entries.firstWhere(
      (DoseHistoryEntry e) => e.log.clientRecordId == 'd1',
    );
    final DoseHistoryEntry notQueued = state.entries.firstWhere(
      (DoseHistoryEntry e) => e.log.clientRecordId == 'd2',
    );

    expect(queued.syncStatus, LocalSyncStatus.pending);
    expect(notQueued.syncStatus, isNull);
  });
}
