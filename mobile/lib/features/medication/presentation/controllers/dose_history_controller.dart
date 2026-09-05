import 'package:flutter_riverpod/flutter_riverpod.dart';

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

class DoseHistoryEntry {
  const DoseHistoryEntry({
    required this.log,
    required this.medicationName,
    required this.syncStatus,
  });

  final DoseLog log;

  final String? medicationName;

  final LocalSyncStatus? syncStatus;
}

class DoseHistoryState {
  const DoseHistoryState({
    required this.entries,
    required this.medications,
    required this.filter,
  });

  final List<DoseHistoryEntry> entries;

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
