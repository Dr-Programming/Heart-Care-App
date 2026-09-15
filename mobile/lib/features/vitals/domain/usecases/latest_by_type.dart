import '../entities/vital_reading.dart';
import '../entities/vital_type.dart';
import '../repositories/vitals_repository.dart';

class LatestByType {
  const LatestByType(this._repository);

  final VitalsRepository _repository;

  Future<Map<VitalType, VitalReading?>> call() => _repository.latestByType();
}
