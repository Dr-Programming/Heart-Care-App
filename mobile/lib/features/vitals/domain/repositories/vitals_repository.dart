import 'package:libu_care/features/vitals/domain/entities/vital_reading.dart';
import 'package:libu_care/features/vitals/domain/entities/vital_type.dart';

abstract interface class VitalsRepository {
  Future<VitalReading> logReading({
    required VitalType type,
    required Map<String, double> values,
    DateTime? measuredAt,
    String? note,
  });

  Future<List<VitalReading>> history({
    VitalType? type,
    DateTime? from,
    DateTime? to,
  });

  Future<Map<VitalType, VitalReading?>> latestByType();

  Future<double?> latestHeightCm();

  Future<VitalGoals?> latestGoals();
}
