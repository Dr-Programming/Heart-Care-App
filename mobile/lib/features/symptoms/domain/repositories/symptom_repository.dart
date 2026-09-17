import '../entities/symptom_check_in.dart';

abstract interface class SymptomRepository {
  Future<SymptomCheckIn> submit({
    required Map<String, dynamic> data,
    String? note,
    DateTime? measuredAt,
  });

  Future<SymptomCheckIn?> latestToday();

  Future<List<SymptomCheckIn>> history();
}
