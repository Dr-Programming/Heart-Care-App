import '../../../../core/clinical/alert_evaluator.dart';

class SymptomCheckIn {
  const SymptomCheckIn({
    required this.clientRecordId,
    required this.data,
    required this.overall,
    required this.perSymptom,
    required this.measuredAt,
    this.note,
  });

  final String clientRecordId;
  final Map<String, dynamic> data;
  final Severity overall;
  final Map<String, Severity> perSymptom;
  final DateTime measuredAt;
  final String? note;

  bool get chestPainPresent => data['chestPain'] is Map
      ? (data['chestPain'] as Map)['present'] == true
      : false;

  String get shortnessOfBreath =>
      (data['shortnessOfBreath'] as String?) ?? 'NONE';

  bool get swelling => data['swelling'] == true;

  int get energyLevel => (data['energyLevel'] as num?)?.toInt() ?? 5;
}
