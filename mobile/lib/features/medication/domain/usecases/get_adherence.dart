import '../entities/adherence.dart';
import '../repositories/medication_repository.dart';

class GetAdherence {
  const GetAdherence(this._repository);
  final MedicationRepository _repository;

  Future<Adherence> call({
    String? medicationClientRecordId,
    required int windowDays,
    DateTime? now,
  }) => _repository.adherence(
    medicationClientRecordId: medicationClientRecordId,
    windowDays: windowDays,
    now: now,
  );
}
