import 'package:flutter_riverpod/flutter_riverpod.dart';

// `app_database.dart` re-exports `tables.dart`, whose Drift-generated row
// classes for the `Medications`/`DoseLogs` tables default to the names
// `Medication` and `DoseLog` — identical to this feature's domain entities,
// imported below. Hiding them avoids an ambiguous-import error; this file
// only needs `LocalSyncStatus` from this import.
import '../../../../core/db/app_database.dart' hide DoseLog, Medication;
import '../../../../core/providers/core_providers.dart';
import '../../../../core/sync/sync_queue_dao.dart';
import '../../domain/entities/dose_log.dart';
import '../../domain/entities/medication.dart';
import '../../medication_providers.dart';

class DoseHistoryFilter {
  const DoseHistoryFilter({this.medicationClientRecordId, this.from, this.to});
  final String? medicationClientRecordId;
  final DateTime? from;
  final DateTime? to;
}

/// One history row: the log, plus the two things the row has to show that the
/// log itself does not carry (I5).
class DoseHistoryEntry {
  const DoseHistoryEntry({
    required this.log,
    required this.medicationName,
    required this.syncStatus,
  });

  final DoseLog log;

  /// Null only if the medication row has gone missing, which soft-deactivation
  /// (Decision 1) means should not happen — the row still renders, without a
  /// name, rather than being dropped.
  final String? medicationName;

  /// Per-record sync state, read from `core`'s `SyncQueueDao.statusFor`
  /// rather than a status column of this feature's own (working notes).
  /// Null once the queue entry has been pruned, which means "nothing
  /// outstanding".
  final LocalSyncStatus? syncStatus;
}

class DoseHistoryState {
  const DoseHistoryState({
    required this.entries,
    required this.medications,
    required this.filter,
  });

  final List<DoseHistoryEntry> entries;

  /// Every medication, active or not, so the filter can still reach the
  /// history of one the patient has stopped taking.
  final List<Medication> medications;

  final DoseHistoryFilter filter;
}

class DoseHistoryController extends AsyncNotifier<DoseHistoryState> {
  DoseHistoryFilter _filter = const DoseHistoryFilter();

  @override
  Future<DoseHistoryState> build() => _fetch();

  Future<DoseHistoryState> _fetch() async {
    final repository = ref.watch(medicationRepositoryProvider);
    final SyncQueueDao syncQueue = ref.watch(syncQueueDaoProvider);

    final List<Medication> medications = await repository.allMedications(
      includeInactive: true,
    );
    final Map<String, String> namesById = <String, String>{
      for (final Medication m in medications) m.clientRecordId: m.name,
    };

    final List<DoseLog> logs = await repository.doseHistory(
      medicationClientRecordId: _filter.medicationClientRecordId,
      from: _filter.from,
      to: _filter.to,
    );

    // One `statusFor` per row. `SyncQueueDao` exposes no batch lookup for
    // status (only `serverIds`), and these are local SQLite point reads on a
    // list the user is already scrolling — cheap enough, and the alternative
    // would be this feature keeping a sync-status column of its own, which
    // the working notes explicitly rule out.
    final List<DoseHistoryEntry> entries = <DoseHistoryEntry>[];
    for (final DoseLog log in logs) {
      entries.add(
        DoseHistoryEntry(
          log: log,
          medicationName: namesById[log.medicationClientRecordId],
          syncStatus: await syncQueue.statusFor(log.clientRecordId),
        ),
      );
    }

    return DoseHistoryState(
      entries: entries,
      medications: medications,
      filter: _filter,
    );
  }

  Future<void> setFilter(DoseHistoryFilter filter) async {
    _filter = filter;
    ref.invalidateSelf();
  }
}

final AsyncNotifierProvider<DoseHistoryController, DoseHistoryState>
doseHistoryControllerProvider =
    AsyncNotifierProvider<DoseHistoryController, DoseHistoryState>(
      DoseHistoryController.new,
    );
