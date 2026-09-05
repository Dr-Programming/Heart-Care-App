import '../entities/adherence.dart';
import '../entities/dose_log.dart';
import '../entities/medication.dart';
import '../entities/scheduled_dose.dart';

abstract interface class MedicationRepository {
  Future<List<Medication>> activeMedications();
  Future<List<Medication>> allMedications({bool includeInactive = false});

  Future<Medication> add({
    required String name,
    required double doseMg,
    required MedicationFrequency frequency,
    required List<String> scheduleTimes,
  });

  Future<Medication> edit(Medication updated);

  Future<Medication> deactivate(String clientRecordId);

  Future<DoseLog> logDose({
    required String medicationClientRecordId,
    required DoseStatus status,
    required String scheduledDate,
    String? scheduledTime,
    String? note,
  });

  Future<List<ScheduledDose>> todaysDoses({DateTime? now});

  Future<List<DoseLog>> doseHistory({
    String? medicationClientRecordId,
    DateTime? from,
    DateTime? to,
  });

  Future<Adherence> adherence({
    String? medicationClientRecordId,
    required int windowDays,
    DateTime? now,
  });

  Future<void> replayPendingEdits();
}
