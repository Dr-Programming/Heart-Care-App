import '../entities/medication.dart';
import '../repositories/medication_repository.dart';

class DeactivateMedication {
  const DeactivateMedication(this._repository);
  final MedicationRepository _repository;

  Future<Medication> call(String clientRecordId) =>
      _repository.deactivate(clientRecordId);
}
