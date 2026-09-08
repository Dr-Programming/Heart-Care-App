import '../entities/symptom_check_in.dart';
import '../repositories/symptom_repository.dart';

/// Thin by design — the offline-first write path (Drift first, then
/// enqueue, never awaiting the network) lives in the repository
/// implementation, not here.
class SubmitCheckIn {
  const SubmitCheckIn(this._repository);

  final SymptomRepository _repository;

  Future<void> call(SymptomCheckIn checkIn) => _repository.log(checkIn);
}
