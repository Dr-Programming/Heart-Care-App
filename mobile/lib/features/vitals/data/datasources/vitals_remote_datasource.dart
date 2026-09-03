import 'package:dio/dio.dart';
import 'package:libu_care/core/constants/api_endpoints.dart';
import 'package:libu_care/core/network/api_response.dart';
import 'package:libu_care/core/network/dio_client.dart';

import '../models/vital_model.dart';

/// Dio only — no Drift, no domain types beyond what it returns.
///
/// **Not called by [VitalsRepositoryImpl]'s write path.** Every write goes
/// local-then-queue through `core/sync` (`CONTRIBUTING.md` §8: "it does not
/// check connectivity and it does not call the API"), and reads come from
/// Drift, never the API. This class exists because the API contract
/// documents both endpoints and `GET /vitals` is `backend/docs/API.md`'s
/// stated mechanism for a fresh-install/second-device restore — a real,
/// documented use this slice's screens do not exercise.
class VitalsRemoteDataSource {
  const VitalsRemoteDataSource(this._dio);

  final Dio _dio;

  /// `POST /api/v1/vitals`. Throws the mapped [Failure] on any non-2xx
  /// response.
  Future<VitalModel> post(VitalModel model) async {
    try {
      final Response<dynamic> response = await _dio.post<dynamic>(
        ApiEndpoints.vitals,
        data: model.toJson(),
      );
      final ApiResponse<VitalModel> envelope = ApiResponse<VitalModel>.fromJson(
        (response.data as Map<Object?, Object?>).cast<String, dynamic>(),
        (Object? data) => VitalModel.fromJson(
          (data as Map<Object?, Object?>).cast<String, dynamic>(),
        ),
      );
      return envelope.data!;
    } on DioException catch (e) {
      throw failureFromDioException(e);
    }
  }

  /// `GET /api/v1/vitals?type=&from=&to=`. Newest first.
  Future<List<VitalModel>> getHistory({
    String? type,
    String? from,
    String? to,
  }) async {
    try {
      final Response<dynamic> response = await _dio.get<dynamic>(
        ApiEndpoints.vitals,
        queryParameters: <String, dynamic>{
          'type': ?type,
          'from': ?from,
          'to': ?to,
        },
      );
      final ApiResponse<List<VitalModel>> envelope =
          ApiResponse<List<VitalModel>>.fromJson(
            (response.data as Map<Object?, Object?>).cast<String, dynamic>(),
            (Object? data) => (data as List<dynamic>)
                .map(
                  (dynamic e) => VitalModel.fromJson(
                    (e as Map<Object?, Object?>).cast<String, dynamic>(),
                  ),
                )
                .toList(),
          );
      return envelope.data ?? const <VitalModel>[];
    } on DioException catch (e) {
      throw failureFromDioException(e);
    }
  }
}
