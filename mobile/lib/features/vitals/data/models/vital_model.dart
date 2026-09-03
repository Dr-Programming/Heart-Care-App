import 'dart:convert';

import 'package:drift/drift.dart' hide JsonKey;
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:libu_care/core/db/app_database.dart';
import 'package:libu_care/core/utils/date_formatter.dart';

import '../../domain/entities/vital_reading.dart';
import '../../domain/entities/vital_type.dart';

part 'vital_model.freezed.dart';
part 'vital_model.g.dart';

/// The wire (and, via [toCompanion], the Drift) shape of one vitals reading.
///
/// One model serves both directions, but not symmetrically: [toJson] emits
/// only what `POST /api/v1/vitals` accepts (`clientRecordId`, `type`,
/// `values`, `measuredAt`, `note`) — `serverId`, `flagged` and `bmi` are
/// server-computed response fields the client must never send back
/// (`docs/design/2026-07-10-vitals-design.md` Decisions 2–3), so they are
/// marked `includeToJson: false`. [fromJson] still reads all of them, for
/// parsing a response.
///
/// `drift`'s own `JsonKey` (used by its DSL) collides with
/// `freezed_annotation`'s `JsonKey`, so the drift import hides it — this file
/// only ever needs the freezed one.
@freezed
abstract class VitalModel with _$VitalModel {
  const factory VitalModel({
    required String clientRecordId,
    @JsonKey(name: 'id', includeToJson: false) String? serverId,
    required String type,
    @JsonKey(fromJson: _valuesFromJson) required Map<String, double> values,
    @JsonKey(includeToJson: false) required bool flagged,
    @JsonKey(includeToJson: false) double? bmi,
    @JsonKey(fromJson: _measuredAtFromJson, toJson: _measuredAtToJson)
    required DateTime measuredAt,
    String? note,
  }) = _VitalModel;

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

  factory VitalModel.fromJson(Map<String, dynamic> json) =>
      _$VitalModelFromJson(json);
}

/// Conversions kept outside the freezed class body — no need for the
/// private-constructor escape hatch that adding instance methods inside
/// `@freezed` requires.
extension VitalModelMapping on VitalModel {
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

  VitalsLogsCompanion toCompanion() => VitalsLogsCompanion.insert(
    clientRecordId: clientRecordId,
    serverId: Value(serverId),
    type: type,
    valuesJson: jsonEncode(values),
    flagged: Value(flagged),
    bmi: Value(bmi),
    measuredAt: measuredAt,
    note: Value(note),
  );
}

Map<String, double> _valuesFromJson(Map<String, dynamic> json) => json.map(
  (String k, dynamic v) => MapEntry<String, double>(k, (v as num).toDouble()),
);

DateTime _measuredAtFromJson(String value) => DateTime.parse(value).toLocal();

String _measuredAtToJson(DateTime value) => DateFormatter.toApiDateTime(value);
