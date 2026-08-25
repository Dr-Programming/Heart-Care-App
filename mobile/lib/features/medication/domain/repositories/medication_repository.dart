import '../entities/adherence.dart';
import '../entities/dose_log.dart';
import '../entities/medication.dart';
import '../entities/scheduled_dose.dart';

/// Offline-first: every method reads from and writes to Drift first. A
/// caller never waits on the network. Implemented by
/// `MedicationRepositoryImpl` (Task 14).
abstract interface class MedicationRepository {
  Future<List<Medication>> activeMedications();
  Future<List<Medication>> allMedications({bool includeInactive = false});

  Future<Medication> add({
    required String name,
    required double doseMg,
    required MedicationFrequency frequency,
    required List<String> scheduleTimes,
  });

  /// Full-replace edit of an existing medication (name/doseMg/frequency/
  /// scheduleTimes/active) — same shape the `PUT` endpoint expects.
  Future<Medication> edit(Medication updated);

  /// Soft-deactivate (Decision 1). Idempotent.
  Future<Medication> deactivate(String clientRecordId);

  Future<DoseLog> logDose({
    required String medicationClientRecordId,
    required DoseStatus status,
    required String scheduledDate,
    String? scheduledTime,
    String? note,
  });

  /// Today's derived doses (Decision 2). Pass [now] only in tests.
  Future<List<ScheduledDose>> todaysDoses({DateTime? now});

  Future<List<DoseLog>> doseHistory({
    String? medicationClientRecordId,
    DateTime? from,
    DateTime? to,
  });

  /// Pass [medicationClientRecordId] for one medication's figure, or omit it
  /// for the overall figure across every medication.
  Future<Adherence> adherence({
    String? medicationClientRecordId,
    required int windowDays,
    DateTime? now,
  });

  /// Replays any offline edit/deactivate still owed to the server as a
  /// direct `PUT`, for medications that now have a `serverId` (§ Task 14).
  /// A no-op when there is nothing pending or the device is offline.
  Future<void> replayPendingEdits();
}
