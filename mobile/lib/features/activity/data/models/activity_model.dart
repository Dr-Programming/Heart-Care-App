import 'package:drift/drift.dart' show Value;
import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../../core/db/app_database.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../domain/entities/activity_session.dart';

part 'activity_model.freezed.dart';

/// The wire/storage shape of one activity session.
///
/// Enums travel as their wire strings (`type`, `intensity`) rather than
/// [ActivityType]/[Intensity]: this class bridges Drift's companion and the
/// API's JSON, and neither speaks a Dart enum.
@freezed
abstract class ActivityModel with _$ActivityModel {
  const ActivityModel._();

  const factory ActivityModel({
    required String clientRecordId,
    String? serverId,
    required String type,
    required int durationMinutes,
    required String intensity,
    int? steps,
    double? distanceMeters,
    required DateTime measuredAt,
    String? note,
  }) = _ActivityModel;

  /// From a session just captured on-device — logging always starts here.
  factory ActivityModel.fromEntity(ActivitySession session) => ActivityModel(
    clientRecordId: session.clientRecordId,
    type: session.type.wire,
    durationMinutes: session.durationMinutes,
    intensity: session.intensity.wire,
    steps: session.steps,
    distanceMeters: session.distanceMeters,
    measuredAt: session.measuredAt,
    note: session.note,
  );

  /// From a Drift row.
  factory ActivityModel.fromRow(ActivityLog row) => ActivityModel(
    clientRecordId: row.clientRecordId,
    serverId: row.serverId,
    type: row.type,
    durationMinutes: row.durationMinutes,
    intensity: row.intensity,
    steps: row.steps,
    distanceMeters: row.distanceMeters,
    measuredAt: row.measuredAt,
    note: row.note,
  );

  /// From one item of `GET /api/v1/activities`, or the `data` echoed back by
  /// `POST /api/v1/activities` (`backend/docs/API.md` §6) — both nest the
  /// typed fields under `data` and carry the server id as `id`.
  factory ActivityModel.fromApiJson(Map<String, dynamic> json) {
    final Map<String, dynamic> data = (json['data'] as Map)
        .cast<String, dynamic>();
    return ActivityModel(
      clientRecordId: json['clientRecordId'] as String,
      serverId: json['id'] as String?,
      type: data['type'] as String,
      durationMinutes: data['durationMinutes'] as int,
      intensity: data['intensity'] as String,
      steps: data['steps'] as int?,
      distanceMeters: (data['distanceMeters'] as num?)?.toDouble(),
      measuredAt: DateTime.parse(json['measuredAt'] as String),
      note: json['note'] as String?,
    );
  }

  ActivitySession toEntity() => ActivitySession(
    clientRecordId: clientRecordId,
    type: ActivityType.fromWire(type),
    durationMinutes: durationMinutes,
    intensity: Intensity.fromWire(intensity),
    measuredAt: measuredAt,
    steps: steps,
    distanceMeters: distanceMeters,
    note: note,
  );

  ActivityLogsCompanion toCompanion() => ActivityLogsCompanion.insert(
    clientRecordId: clientRecordId,
    serverId: Value<String?>(serverId),
    type: type,
    durationMinutes: durationMinutes,
    intensity: intensity,
    steps: Value<int?>(steps),
    distanceMeters: Value<double?>(distanceMeters),
    measuredAt: measuredAt,
    note: Value<String?>(note),
  );

  /// The exact `POST /api/v1/activities` body — also what a `SYNC` record's
  /// `payload` carries verbatim (`backend/docs/API.md` §6, §8).
  Map<String, dynamic> toApiRequestBody() => <String, dynamic>{
    'clientRecordId': clientRecordId,
    'measuredAt': DateFormatter.toApiDateTime(measuredAt),
    if (note != null) 'note': note,
    'data': <String, dynamic>{
      'type': type,
      'durationMinutes': durationMinutes,
      'intensity': intensity,
      if (steps != null) 'steps': steps,
      if (distanceMeters != null) 'distanceMeters': distanceMeters,
    },
  };
}
