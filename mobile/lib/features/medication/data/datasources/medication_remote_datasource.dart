import 'package:dio/dio.dart';

import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/network/api_response.dart';
import '../models/dose_log_model.dart';
import '../models/medication_model.dart';

/// Dio only — no Drift import here (architectural rule 3: local and remote
/// datasources are always separate classes).
class MedicationRemoteDataSource {
  const MedicationRemoteDataSource(this._dio);

  final Dio _dio;

  Future<MedicationModel> create({
    required String name,
    required double doseMg,
    required String frequency,
    required List<String> scheduleTimes,
    bool active = true,
    String? clientRecordId,
  }) async {
    final Response<dynamic> response = await _dio.post<dynamic>(
      ApiEndpoints.medications,
      data: <String, dynamic>{
        'name': name,
        'doseMg': doseMg,
        'frequency': frequency,
        'scheduleTimes': scheduleTimes,
        'active': active,
        if (clientRecordId != null) 'clientRecordId': clientRecordId,
      },
    );
    return _unwrap(response, MedicationModel.fromJson);
  }

  Future<List<MedicationModel>> list({bool includeInactive = false}) async {
    final Response<dynamic> response = await _dio.get<dynamic>(
      ApiEndpoints.medications,
      queryParameters: <String, dynamic>{
        'includeInactive': includeInactive.toString(),
      },
    );
    return _unwrapList(response, MedicationModel.fromJson);
  }

  Future<MedicationModel> update(
    String id, {
    required String name,
    required double doseMg,
    required String frequency,
    required List<String> scheduleTimes,
    required bool active,
  }) async {
    final Response<dynamic> response = await _dio.put<dynamic>(
      ApiEndpoints.medication(id),
      data: <String, dynamic>{
        'name': name,
        'doseMg': doseMg,
        'frequency': frequency,
        'scheduleTimes': scheduleTimes,
        'active': active,
      },
    );
    return _unwrap(response, MedicationModel.fromJson);
  }

  Future<MedicationModel> deactivate(String id) async {
    final Response<dynamic> response = await _dio.delete<dynamic>(
      ApiEndpoints.medication(id),
    );
    return _unwrap(response, MedicationModel.fromJson);
  }

  Future<DoseLogModel> logDose(
    String medicationId, {
    required String status,
    required String scheduledDate,
    String? scheduledTime,
    String? loggedAt,
    String? note,
    String? clientRecordId,
  }) async {
    final Response<dynamic> response = await _dio.post<dynamic>(
      ApiEndpoints.medicationDoses(medicationId),
      data: <String, dynamic>{
        'status': status,
        'scheduledDate': scheduledDate,
        if (scheduledTime != null) 'scheduledTime': scheduledTime,
        if (loggedAt != null) 'loggedAt': loggedAt,
        if (note != null) 'note': note,
        if (clientRecordId != null) 'clientRecordId': clientRecordId,
      },
    );
    return _unwrap(response, DoseLogModel.fromJson);
  }

  Future<List<DoseLogModel>> doseLogs({
    String? from,
    String? to,
    String? medicationId,
  }) async {
    final Response<dynamic> response = await _dio.get<dynamic>(
      ApiEndpoints.doseLogs,
      queryParameters: <String, dynamic>{
        if (from != null) 'from': from,
        if (to != null) 'to': to,
        if (medicationId != null) 'medicationId': medicationId,
      },
    );
    return _unwrapList(response, DoseLogModel.fromJson);
  }

  T _unwrap<T>(
    Response<dynamic> response,
    T Function(Map<String, dynamic>) fromJson,
  ) {
    final ApiResponse<T> envelope = ApiResponse<T>.fromJson(
      (response.data as Map<Object?, Object?>).cast<String, dynamic>(),
      (Object? data) => fromJson((data as Map<Object?, Object?>).cast()),
    );
    return envelope.data as T;
  }

  List<T> _unwrapList<T>(
    Response<dynamic> response,
    T Function(Map<String, dynamic>) fromJson,
  ) {
    final ApiResponse<List<T>> envelope = ApiResponse<List<T>>.fromJson(
      (response.data as Map<Object?, Object?>).cast<String, dynamic>(),
      (Object? data) => (data as List<dynamic>)
          .map((dynamic e) => fromJson((e as Map<Object?, Object?>).cast()))
          .toList(),
    );
    return envelope.data ?? <T>[];
  }
}
