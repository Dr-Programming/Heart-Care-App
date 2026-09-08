import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/clinical/alert_evaluator.dart';
import '../../../../core/db/app_database.dart' show LocalSyncStatus;
import '../../../../core/providers/core_providers.dart';
import '../../data/datasources/dose_log_reader.dart';
import '../../data/datasources/symptom_local_datasource.dart';
import '../../data/datasources/symptom_remote_datasource.dart';
import '../../data/repositories/symptom_repository_impl.dart';
import '../../domain/entities/symptom_history_entry.dart';
import '../../domain/repositories/symptom_repository.dart';
import '../../domain/usecases/get_cross_signal.dart';
import '../../domain/usecases/has_checked_in_today.dart';
import '../../domain/usecases/watch_symptom_history.dart';

part 'symptom_providers.g.dart';

/// The one place this feature builds its repository. Screens and
/// controllers depend on [SymptomRepository], never on this concrete type.
@riverpod
SymptomRepository symptomRepository(Ref ref) {
  return SymptomRepositoryImpl(
    local: SymptomLocalDatasource(ref.watch(appDatabaseProvider)),
    sync: ref.watch(syncEnqueuerProvider),
    remote: SymptomRemoteDatasource(ref.watch(dioProvider)),
    syncQueue: ref.watch(syncQueueDaoProvider),
  );
}

/// Reverse-chronological check-in history, read from Drift.
@riverpod
Stream<List<SymptomHistoryEntry>> symptomHistory(
  Ref ref, {
  DateTime? from,
  DateTime? to,
}) {
  final SymptomRepository repository = ref.watch(symptomRepositoryProvider);
  return WatchSymptomHistory(repository).call(from: from, to: to);
}

/// The check-in hub's "done today" state — the most recent check-in made
/// today, or null.
@riverpod
Stream<SymptomHistoryEntry?> todayCheckIn(Ref ref) {
  final SymptomRepository repository = ref.watch(symptomRepositoryProvider);
  return HasCheckedInToday(repository).call();
}

@riverpod
DoseLogReader doseLogReader(Ref ref) =>
    DoseLogReader(ref.watch(appDatabaseProvider));

/// FR-DEC-003, assembled for whichever screen wants to show it (design
/// decision 4 — no standalone Alerts screen, so this surfaces inline).
@riverpod
Stream<Severity> crossSignal(Ref ref) async* {
  final SymptomRepository repository = ref.watch(symptomRepositoryProvider);
  final DoseLogReader reader = ref.watch(doseLogReaderProvider);
  final bool missedDoseToday = await reader.hasMissedDose();
  yield* GetCrossSignal(repository).call(missedDoseToday: missedDoseToday);
}

/// Per-row sync state for the history list (M5 spec §3) — `SyncQueueDao`'s
/// own docs name `statusFor` as the sanctioned way to show this without a
/// feature storing a status column of its own.
@riverpod
Future<LocalSyncStatus?> symptomSyncStatus(Ref ref, String clientRecordId) {
  return ref.watch(syncQueueDaoProvider).statusFor(clientRecordId);
}
