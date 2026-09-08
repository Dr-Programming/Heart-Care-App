import 'package:dio/dio.dart';

import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/network/api_response.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/utils/date_formatter.dart';
import '../models/symptom_model.dart';

/// `POST`/`GET /api/v1/symptoms` — Dio only, per architectural rule #3.
///
/// `log()` exists for contract completeness and is exercised directly by
/// its own test, but nothing in the write path calls it: a save goes
/// local-then-`SyncEnqueuer`, same as every other feature, and the generic
/// sync engine posts the batch itself. `fetchHistory()` is the one this
/// feature actually depends on — `SymptomRepositoryImpl.reconcileServerAssessments`
/// uses it to pull back the server's assessment for rows the sync queue has
/// already confirmed (see that method for the full design).
class SymptomRemoteDatasource {
  const SymptomRemoteDatasource(this._dio);

  final Dio _dio;

  /// Logs one check-in directly. Throws a `Failure` — see
  /// `core/network/dio_client.dart` for the status-to-`Failure` mapping.
  Future<SymptomModel> log(SymptomModel model) async {
    try {
      final Response<dynamic> response = await _dio.post<dynamic>(
        ApiEndpoints.symptoms,
        data: model.toApiRequestBody(),
      );
      return _unwrapOne(response);
    } on DioException catch (e) {
      throw failureFromDioException(e);
    }
  }

  /// Newest first (`measuredAt` desc, set server-side). [from]/[to] are
  /// inclusive UTC-day bounds, sent as plain dates
  /// (`DateFormatter.toApiDate`) — the only shape the API accepts here.
  Future<List<SymptomModel>> fetchHistory({
    DateTime? from,
    DateTime? to,
  }) async {
    try {
      final Response<dynamic> response = await _dio.get<dynamic>(
        ApiEndpoints.symptoms,
        queryParameters: <String, dynamic>{
          if (from != null) 'from': DateFormatter.toApiDate(from),
          if (to != null) 'to': DateFormatter.toApiDate(to),
        },
      );
      return _unwrapList(response);
    } on DioException catch (e) {
      throw failureFromDioException(e);
    }
  }

  SymptomModel _unwrapOne(Response<dynamic> response) {
    final ApiResponse<SymptomModel> envelope =
        ApiResponse<SymptomModel>.fromJson(
          (response.data as Map<Object?, Object?>).cast<String, dynamic>(),
          (Object? data) => SymptomModel.fromApiJson(
            (data as Map<Object?, Object?>).cast<String, dynamic>(),
          ),
        );
    return envelope.data!;
  }

  List<SymptomModel> _unwrapList(Response<dynamic> response) {
    final ApiResponse<List<SymptomModel>> envelope =
        ApiResponse<List<SymptomModel>>.fromJson(
          (response.data as Map<Object?, Object?>).cast<String, dynamic>(),
          (Object? data) => (data as List<dynamic>)
              .map(
                (dynamic item) => SymptomModel.fromApiJson(
                  (item as Map<Object?, Object?>).cast<String, dynamic>(),
                ),
              )
              .toList(),
        );
    return envelope.data ?? <SymptomModel>[];
  }
}
