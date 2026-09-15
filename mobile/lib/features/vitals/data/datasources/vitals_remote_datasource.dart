import 'package:dio/dio.dart';

import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/network/api_response.dart';
import '../models/vital_model.dart';

class VitalsRemoteDataSource {
  const VitalsRemoteDataSource(this._dio);

  final Dio _dio;

  Future<VitalModel> create({
    required String type,
    required Map<String, double> values,
    required String measuredAt,
    String? note,
    String? clientRecordId,
  }) async {
    final Response<dynamic> response = await _dio.post<dynamic>(
      ApiEndpoints.vitals,
      data: <String, dynamic>{
        'type': type,
        'values': values,
        'measuredAt': measuredAt,
        if (note != null) 'note': note,
        if (clientRecordId != null) 'clientRecordId': clientRecordId,
      },
    );
    final ApiResponse<VitalModel> envelope = ApiResponse<VitalModel>.fromJson(
      (response.data as Map<Object?, Object?>).cast<String, dynamic>(),
      (Object? data) =>
          VitalModel.fromJson((data as Map<Object?, Object?>).cast()),
    );
    return envelope.data as VitalModel;
  }
}
