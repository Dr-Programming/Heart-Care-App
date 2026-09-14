import '../entities/medication.dart';
import '../repositories/medication_repository.dart';

class EditMedication {
  const EditMedication(this._repository);
  final MedicationRepository _repository;

  Future<Medication> call(Medication updated) => _repository.edit(updated);
}
