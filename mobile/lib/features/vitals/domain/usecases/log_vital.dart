import '../entities/vital_reading.dart';
import '../entities/vital_type.dart';
import '../repositories/vitals_repository.dart';

class LogVital {
  const LogVital(this._repository);

  final VitalsRepository _repository;

  Future<VitalReading> call({
    required VitalType type,
    required Map<String, double> values,
    DateTime? measuredAt,
    String? note,
  }) => _repository.logReading(
    type: type,
    values: values,
    measuredAt: measuredAt,
    note: note,
  );
}
