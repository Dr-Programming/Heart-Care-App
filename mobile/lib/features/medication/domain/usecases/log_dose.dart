import '../entities/dose_log.dart';
import '../repositories/medication_repository.dart';

class LogDose {
  const LogDose(this._repository);
  final MedicationRepository _repository;

  Future<DoseLog> call({
    required String medicationClientRecordId,
    required DoseStatus status,
    required String scheduledDate,
    String? scheduledTime,
    String? note,
  }) => _repository.logDose(
    medicationClientRecordId: medicationClientRecordId,
    status: status,
    scheduledDate: scheduledDate,
    scheduledTime: scheduledTime,
    note: note,
  );
}
