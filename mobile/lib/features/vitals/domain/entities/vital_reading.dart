import 'vital_type.dart';

class VitalReading {
  const VitalReading({
    required this.clientRecordId,
    required this.serverId,
    required this.type,
    required this.values,
    required this.flagged,
    required this.bmi,
    required this.measuredAt,
    required this.note,
  });

  final String clientRecordId;
  final String? serverId;
  final VitalType type;
  final Map<String, double> values;
  final bool? flagged;
  final double? bmi;
  final DateTime measuredAt;
  final String? note;

  VitalReading copyWith({String? serverId, bool? flagged, double? bmi}) {
    return VitalReading(
      clientRecordId: clientRecordId,
      serverId: serverId ?? this.serverId,
      type: type,
      values: values,
      flagged: flagged ?? this.flagged,
      bmi: bmi ?? this.bmi,
      measuredAt: measuredAt,
      note: note,
    );
  }
}

class VitalGoals {
  const VitalGoals({
    this.bpSystolic,
    this.bpDiastolic,
    this.totalCholesterol,
    this.targetWeightKg,
  });

  final double? bpSystolic;
  final double? bpDiastolic;
  final double? totalCholesterol;
  final double? targetWeightKg;

  factory VitalGoals.fromJson(Map<String, dynamic> json) => VitalGoals(
    bpSystolic: (json['bpSystolic'] as num?)?.toDouble(),
    bpDiastolic: (json['bpDiastolic'] as num?)?.toDouble(),
    totalCholesterol: (json['totalCholesterol'] as num?)?.toDouble(),
    targetWeightKg: (json['targetWeightKg'] as num?)?.toDouble(),
  );
}
