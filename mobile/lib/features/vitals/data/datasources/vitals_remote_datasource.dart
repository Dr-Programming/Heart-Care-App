import 'package:dio/dio.dart';

import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/network/api_response.dart';
import '../../../../core/network/list_request.dart';
import '../models/vital_model.dart';

class VitalsRemoteDataSource {
  const VitalsRemoteDataSource(this._dio);

  final Dio _dio;

  /// Every reading the server holds for the signed-in patient.
  /// Readings between [from] and [to] (yyyy-MM-dd, both included); all of
  /// them when left out.
  Future<List<VitalModel>> history({String? from, String? to}) async =>
      <VitalModel>[
        for (final Map<String, dynamic> json in await getJsonList(
          _dio,
          ApiEndpoints.vitals,
          query: <String, dynamic>{'from': ?from, 'to': ?to},
        ))
          VitalModel.fromJson(json),
      ];

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
