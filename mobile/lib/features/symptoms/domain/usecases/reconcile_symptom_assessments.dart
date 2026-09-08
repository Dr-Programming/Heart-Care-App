import '../repositories/symptom_repository.dart';

/// Thin by design — see `SymptomRepository.reconcileServerAssessments` for
/// what this actually does and why it exists.
class ReconcileSymptomAssessments {
  const ReconcileSymptomAssessments(this._repository);

  final SymptomRepository _repository;

  Future<void> call() => _repository.reconcileServerAssessments();
}
