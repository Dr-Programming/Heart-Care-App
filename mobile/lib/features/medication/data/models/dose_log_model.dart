import 'package:drift/drift.dart' show Value;
import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../../core/db/app_database.dart' as drift_db;
import '../../domain/entities/dose_log.dart';

part 'dose_log_model.freezed.dart';

/// The `POST/GET .../doses` response shape. Never carries the client-side
/// medication link on the wire (Decision 3) — every conversion that needs it
/// takes it as a parameter from the caller, which already knows which
/// medication it was logging against.
///
/// `fromJson`/`toJson` are hand-written rather than `json_serializable`-
/// generated — see [MedicationModel]'s doc comment for why.
@freezed
abstract class DoseLogModel with _$DoseLogModel {
  const DoseLogModel._();

  const factory DoseLogModel({
    String? id,
    required String medicationId,
    required String status,
    required String scheduledDate,
    String? scheduledTime,
    DateTime? loggedAt,
    String? note,
    String? clientRecordId,
    DateTime? createdAt,
  }) = _DoseLogModel;

  factory DoseLogModel.fromJson(Map<String, dynamic> json) {
    return DoseLogModel(
      id: json['id'] as String?,
      medicationId: json['medicationId'] as String,
      status: json['status'] as String,
      scheduledDate: json['scheduledDate'] as String,
      scheduledTime: json['scheduledTime'] as String?,
      loggedAt: json['loggedAt'] != null
          ? DateTime.parse(json['loggedAt'] as String)
          : null,
      note: json['note'] as String?,
      clientRecordId: json['clientRecordId'] as String?,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    if (id != null) 'id': id,
    'medicationId': medicationId,
    'status': status,
    'scheduledDate': scheduledDate,
    if (scheduledTime != null) 'scheduledTime': scheduledTime,
    if (loggedAt != null) 'loggedAt': loggedAt!.toIso8601String(),
    if (note != null) 'note': note,
    if (clientRecordId != null) 'clientRecordId': clientRecordId,
    if (createdAt != null) 'createdAt': createdAt!.toIso8601String(),
  };

  factory DoseLogModel.fromEntity(DoseLog log) => DoseLogModel(
    id: log.serverId,
    medicationId: log.medicationServerId ?? '',
    status: log.status.wire,
    scheduledDate: log.scheduledDate,
    scheduledTime: log.scheduledTime,
    loggedAt: log.loggedAt,
    note: log.note,
    clientRecordId: log.clientRecordId,
    createdAt: log.loggedAt,
  );

  DoseLog toEntity({required String medicationClientRecordId}) {
    return DoseLog(
      clientRecordId: clientRecordId!,
      serverId: id,
      medicationClientRecordId: medicationClientRecordId,
      medicationServerId: medicationId.isEmpty ? null : medicationId,
      status: DoseStatus.fromWire(status),
      scheduledDate: scheduledDate,
      scheduledTime: scheduledTime,
      loggedAt: loggedAt ?? DateTime.now().toUtc(),
      note: note,
    );
  }

  drift_db.DoseLogsCompanion toCompanion({
    required String medicationClientRecordId,
  }) {
    return drift_db.DoseLogsCompanion.insert(
      clientRecordId: clientRecordId!,
      serverId: Value<String?>(id),
      medicationClientRecordId: medicationClientRecordId,
      medicationServerId: Value<String?>(
        medicationId.isEmpty ? null : medicationId,
      ),
      status: status,
      scheduledDate: scheduledDate,
      scheduledTime: Value<String?>(scheduledTime),
      loggedAt: loggedAt ?? DateTime.now().toUtc(),
      note: Value<String?>(note),
    );
  }
}
