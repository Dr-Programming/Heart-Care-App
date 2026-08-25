import '../entities/medication.dart';
import '../repositories/medication_repository.dart';

class AddMedication {
  const AddMedication(this._repository);
  final MedicationRepository _repository;

  Future<Medication> call({
    required String name,
    required double doseMg,
    required MedicationFrequency frequency,
    required List<String> scheduleTimes,
  }) => _repository.add(
    name: name,
    doseMg: doseMg,
    frequency: frequency,
    scheduleTimes: scheduleTimes,
  );
}
