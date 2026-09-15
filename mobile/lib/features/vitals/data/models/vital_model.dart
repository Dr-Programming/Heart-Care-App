import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../../core/db/app_database.dart' as drift_db;
import '../../domain/entities/vital_reading.dart';
import '../../domain/entities/vital_type.dart';

part 'vital_model.freezed.dart';

@freezed
abstract class VitalModel with _$VitalModel {
  const VitalModel._();

  const factory VitalModel({
    required String clientRecordId,
    String? serverId,
    required String type,
    required Map<String, double> values,
    bool? flagged,
    double? bmi,
    required DateTime measuredAt,
    String? note,
  }) = _VitalModel;

  factory VitalModel.fromJson(Map<String, dynamic> json) {
    return VitalModel(
      clientRecordId: json['clientRecordId'] as String? ?? '',
      serverId: json['id'] as String?,
      type: json['type'] as String,
      values: (json['values'] as Map<String, dynamic>).map(
        (String key, dynamic value) =>
            MapEntry<String, double>(key, (value as num).toDouble()),
      ),
      flagged: json['flagged'] as bool?,
      bmi: (json['bmi'] as num?)?.toDouble(),
      measuredAt: DateTime.parse(json['measuredAt'] as String),
      note: json['note'] as String?,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'clientRecordId': clientRecordId,
    if (serverId != null) 'id': serverId,
    'type': type,
    'values': values,
    if (flagged != null) 'flagged': flagged,
    if (bmi != null) 'bmi': bmi,
    'measuredAt': measuredAt.toUtc().toIso8601String(),
    if (note != null) 'note': note,
  };

  factory VitalModel.fromEntity(VitalReading reading) => VitalModel(
    clientRecordId: reading.clientRecordId,
    serverId: reading.serverId,
    type: reading.type.wire,
    values: reading.values,
    flagged: reading.flagged,
    bmi: reading.bmi,
    measuredAt: reading.measuredAt,
    note: reading.note,
  );

  VitalReading toEntity() => VitalReading(
    clientRecordId: clientRecordId,
    serverId: serverId,
    type: VitalType.fromWire(type),
    values: values,
    flagged: flagged,
    bmi: bmi,
    measuredAt: measuredAt,
    note: note,
  );

  drift_db.VitalsLogsCompanion toCompanion() => drift_db.VitalsLogsCompanion.insert(
    clientRecordId: clientRecordId,
    serverId: Value<String?>(serverId),
    type: type,
    valuesJson: jsonEncode(values),
    flagged: Value<bool?>(flagged),
    bmi: Value<double?>(bmi),
    measuredAt: measuredAt,
    note: Value<String?>(note),
  );

  factory VitalModel.fromRow(drift_db.VitalsLog row) => VitalModel(
    clientRecordId: row.clientRecordId,
    serverId: row.serverId,
    type: row.type,
    values: (jsonDecode(row.valuesJson) as Map<String, dynamic>).map(
      (String key, dynamic value) =>
          MapEntry<String, double>(key, (value as num).toDouble()),
    ),
    flagged: row.flagged,
    bmi: row.bmi,
    measuredAt: row.measuredAt,
    note: row.note,
  );
}
