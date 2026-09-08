import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../../core/clinical/alert_evaluator.dart';
import '../../../../core/db/app_database.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../domain/entities/symptom_answer.dart';
import '../../domain/entities/symptom_check_in.dart';
import '../../domain/entities/symptom_history_entry.dart';

part 'symptom_model.freezed.dart';

/// The wire/storage shape of one symptom check-in.
///
/// [data] is exactly the API's whitelisted `data` object — the same map
/// serves as the request body's `data`, the stored `dataJson` blob (once
/// `jsonEncode`d), and the input `assessSymptoms` expects. [assessment]
/// mirrors the server's `{overall, symptoms}` shape; it is always populated
/// at write time from the local evaluator (design decision 2) and later
/// replaced with the server's own by `reconcileServerAssessments`.
@freezed
abstract class SymptomModel with _$SymptomModel {
  const SymptomModel._();

  const factory SymptomModel({
    required String clientRecordId,
    String? serverId,
    required Map<String, dynamic> data,
    required Map<String, dynamic> assessment,
    required String overallSeverity,
    required DateTime measuredAt,
    String? note,
  }) = _SymptomModel;

  /// From a check-in just captured on-device. Computes the local assessment
  /// immediately — `assessSymptoms` expects exactly this [data] shape.
  factory SymptomModel.fromEntity(SymptomCheckIn checkIn) {
    final Map<String, dynamic> data = _dataFromEntity(checkIn);
    final SymptomAssessment assessment = assessSymptoms(data);
    return SymptomModel(
      clientRecordId: checkIn.clientRecordId,
      data: data,
      assessment: _assessmentToJson(assessment),
      overallSeverity: assessment.overall.wire,
      measuredAt: checkIn.measuredAt,
      note: checkIn.note,
    );
  }

  /// From a Drift row — `dataJson`/`assessmentJson` are decoded here so
  /// nothing outside this model ever touches a raw JSON string.
  factory SymptomModel.fromRow(SymptomLog row) {
    return SymptomModel(
      clientRecordId: row.clientRecordId,
      serverId: row.serverId,
      data: jsonDecode(row.dataJson) as Map<String, dynamic>,
      assessment: row.assessmentJson == null
          ? const <String, dynamic>{}
          : jsonDecode(row.assessmentJson!) as Map<String, dynamic>,
      overallSeverity: row.overallSeverity ?? Severity.none.wire,
      measuredAt: row.measuredAt,
      note: row.note,
    );
  }

  /// From one item of `GET /api/v1/symptoms`, or the echoed record inside
  /// `POST /api/v1/symptoms`'s response (`backend/docs/API.md` §5) — both
  /// carry the server id as `id` and the server-computed `assessment`.
  factory SymptomModel.fromApiJson(Map<String, dynamic> json) {
    final Map<String, dynamic> assessment = (json['assessment'] as Map)
        .cast<String, dynamic>();
    return SymptomModel(
      clientRecordId: json['clientRecordId'] as String,
      serverId: json['id'] as String?,
      data: (json['data'] as Map).cast<String, dynamic>(),
      assessment: assessment,
      overallSeverity: assessment['overall'] as String,
      measuredAt: DateTime.parse(json['measuredAt'] as String),
      note: json['note'] as String?,
    );
  }

  SymptomCheckIn toEntity() {
    return SymptomCheckIn(
      clientRecordId: clientRecordId,
      chestPain: _chestPainFrom(data['chestPain']),
      shortnessOfBreath: ShortnessOfBreath.fromWire(
        data['shortnessOfBreath'] as String,
      ),
      heartRate: data['heartRate'] as int,
      bloodPressure: _bloodPressureFrom(data['bloodPressure']),
      swelling: data['swelling'] as bool,
      energyLevel: data['energyLevel'] as int,
      worseThanYesterday: _worseThanYesterdayFrom(data['worseThanYesterday']),
      measuredAt: measuredAt,
      note: note,
    );
  }

  SymptomHistoryEntry toHistoryEntry() => SymptomHistoryEntry(
    checkIn: toEntity(),
    assessment: _assessmentFromJson(assessment, overallSeverity),
    serverId: serverId,
  );

  SymptomLogsCompanion toCompanion() => SymptomLogsCompanion.insert(
    clientRecordId: clientRecordId,
    serverId: Value<String?>(serverId),
    dataJson: jsonEncode(data),
    assessmentJson: Value<String?>(jsonEncode(assessment)),
    overallSeverity: Value<String?>(overallSeverity),
    measuredAt: measuredAt,
    note: Value<String?>(note),
  );

  /// The exact `POST /api/v1/symptoms` body — also what a `SYNC` record's
  /// `payload` carries verbatim (`backend/docs/API.md` §5, §8).
  Map<String, dynamic> toApiRequestBody() => <String, dynamic>{
    'clientRecordId': clientRecordId,
    'measuredAt': DateFormatter.toApiDateTime(measuredAt),
    if (note != null) 'note': note,
    'data': data,
  };
}

Map<String, dynamic> _dataFromEntity(SymptomCheckIn checkIn) {
  return <String, dynamic>{
    'chestPain': <String, dynamic>{
      'present': checkIn.chestPain.present,
      if (checkIn.chestPain.present) 'severity': checkIn.chestPain.severity,
    },
    'shortnessOfBreath': checkIn.shortnessOfBreath.wire,
    'heartRate': checkIn.heartRate,
    'bloodPressure': <String, dynamic>{
      'systolic': checkIn.bloodPressure.systolic,
      'diastolic': checkIn.bloodPressure.diastolic,
    },
    'swelling': checkIn.swelling,
    'energyLevel': checkIn.energyLevel,
    if (checkIn.worseThanYesterday.isNotEmpty)
      'worseThanYesterday': <String, dynamic>{
        for (final MapEntry<SymptomKey, bool> e
            in checkIn.worseThanYesterday.entries)
          e.key.wire: e.value,
      },
  };
}

ChestPain _chestPainFrom(dynamic raw) {
  final Map<String, dynamic> map = (raw as Map).cast<String, dynamic>();
  return ChestPain(
    present: map['present'] as bool,
    severity: map['severity'] as int?,
  );
}

BloodPressureReading _bloodPressureFrom(dynamic raw) {
  final Map<String, dynamic> map = (raw as Map).cast<String, dynamic>();
  return BloodPressureReading(
    systolic: map['systolic'] as int,
    diastolic: map['diastolic'] as int,
  );
}

Map<SymptomKey, bool> _worseThanYesterdayFrom(dynamic raw) {
  if (raw == null) return const <SymptomKey, bool>{};
  final Map<String, dynamic> map = (raw as Map).cast<String, dynamic>();
  return <SymptomKey, bool>{
    for (final MapEntry<String, dynamic> e in map.entries)
      SymptomKey.fromWire(e.key): e.value as bool,
  };
}

Map<String, dynamic> _assessmentToJson(SymptomAssessment assessment) {
  return <String, dynamic>{
    'overall': assessment.overall.wire,
    'symptoms': <String, dynamic>{
      for (final MapEntry<String, Severity> e in assessment.symptoms.entries)
        e.key: e.value.wire,
    },
  };
}

SymptomAssessment _assessmentFromJson(
  Map<String, dynamic> json,
  String overallWire,
) {
  final Map<String, dynamic> symptoms =
      (json['symptoms'] as Map?)?.cast<String, dynamic>() ??
      const <String, dynamic>{};
  return SymptomAssessment(
    overall: Severity.fromWire(json['overall'] as String? ?? overallWire),
    symptoms: <String, Severity>{
      for (final MapEntry<String, dynamic> e in symptoms.entries)
        e.key: Severity.fromWire(e.value as String),
    },
  );
}
