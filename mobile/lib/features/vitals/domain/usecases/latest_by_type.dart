import '../entities/vital_reading.dart';
import '../entities/vital_type.dart';
import '../repositories/vitals_repository.dart';

/// FR-DASH-002..005 (the Home card) and Decision 7 (the form's hint).
class LatestByType {
  const LatestByType(this._repository);

  final VitalsRepository _repository;

  Future<VitalReading?> call(VitalType type) => _repository.latestByType(type);
}
