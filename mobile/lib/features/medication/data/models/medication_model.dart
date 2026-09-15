import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../../core/db/app_database.dart' as drift_db;
import '../../domain/entities/medication.dart';

part 'medication_model.freezed.dart';

@freezed
abstract class MedicationModel with _$MedicationModel {
  const MedicationModel._();

  const factory MedicationModel({
    String? id,
    required String name,
    required double doseMg,
    required String frequency,
    required List<String> scheduleTimes,
    required bool active,
    String? clientRecordId,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) = _MedicationModel;

  factory MedicationModel.fromJson(Map<String, dynamic> json) {
    return MedicationModel(
      id: json['id'] as String?,
      name: json['name'] as String,
      doseMg: (json['doseMg'] as num).toDouble(),
      frequency: json['frequency'] as String,
      scheduleTimes: (json['scheduleTimes'] as List<dynamic>).cast<String>(),
      active: json['active'] as bool,
      clientRecordId: json['clientRecordId'] as String?,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : null,
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    if (id != null) 'id': id,
    'name': name,
    'doseMg': doseMg,
    'frequency': frequency,
    'scheduleTimes': scheduleTimes,
    'active': active,
    if (clientRecordId != null) 'clientRecordId': clientRecordId,
    if (createdAt != null) 'createdAt': createdAt!.toIso8601String(),
    if (updatedAt != null) 'updatedAt': updatedAt!.toIso8601String(),
  };

  factory MedicationModel.fromEntity(Medication medication) => MedicationModel(
    id: medication.serverId,
    name: medication.name,
    doseMg: medication.doseMg,
    frequency: medication.frequency.wire,
    scheduleTimes: medication.scheduleTimes,
    active: medication.active,
    clientRecordId: medication.clientRecordId,
    createdAt: medication.createdAt,
    updatedAt: medication.updatedAt,
  );

  Medication toEntity() {
    final DateTime now = DateTime.now().toUtc();
    return Medication(
      clientRecordId: clientRecordId!,
      serverId: id,
      name: name,
      doseMg: doseMg,
      frequency: MedicationFrequency.fromWire(frequency),
      scheduleTimes: scheduleTimes,
      active: active,
      createdAt: createdAt ?? now,
      updatedAt: updatedAt ?? now,
    );
  }

  drift_db.MedicationsCompanion toCompanion() {
    final DateTime now = DateTime.now().toUtc();
    return drift_db.MedicationsCompanion.insert(
      clientRecordId: clientRecordId!,
      serverId: Value<String?>(id),
      name: name,
      doseMg: doseMg,
      frequency: frequency,
      scheduleTimesJson: jsonEncode(scheduleTimes),
      active: Value<bool>(active),
      createdAt: createdAt ?? now,
      updatedAt: updatedAt ?? now,
    );
  }
}
