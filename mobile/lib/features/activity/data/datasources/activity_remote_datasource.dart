import 'package:dio/dio.dart';

import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/network/api_response.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/utils/date_formatter.dart';
import '../models/activity_model.dart';

/// `POST`/`GET /api/v1/activities` — Dio only, per architectural rule #3.
///
/// Never called directly for a write: `ActivityRepositoryImpl` writes to
/// Drift first and reaches this class only through the sync queue. `GET` is
/// used to restore history on a fresh install or second device
/// (`backend/docs/API.md` §8) — there is no pull direction on sync itself.
class ActivityRemoteDatasource {
  const ActivityRemoteDatasource(this._dio);

  final Dio _dio;

  /// Logs one session directly. Throws a [Failure] — see
  /// `core/network/dio_client.dart` for the status-to-`Failure` mapping.
  Future<ActivityModel> log(ActivityModel model) async {
    try {
      final Response<dynamic> response = await _dio.post<dynamic>(
        ApiEndpoints.activities,
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
  Future<List<ActivityModel>> fetchHistory({
    DateTime? from,
    DateTime? to,
  }) async {
    try {
      final Response<dynamic> response = await _dio.get<dynamic>(
        ApiEndpoints.activities,
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

  ActivityModel _unwrapOne(Response<dynamic> response) {
    final ApiResponse<ActivityModel> envelope =
        ApiResponse<ActivityModel>.fromJson(
          (response.data as Map<Object?, Object?>).cast<String, dynamic>(),
          (Object? data) => ActivityModel.fromApiJson(
            (data as Map<Object?, Object?>).cast<String, dynamic>(),
          ),
        );
    return envelope.data!;
  }

  List<ActivityModel> _unwrapList(Response<dynamic> response) {
    final ApiResponse<List<ActivityModel>> envelope =
        ApiResponse<List<ActivityModel>>.fromJson(
          (response.data as Map<Object?, Object?>).cast<String, dynamic>(),
          (Object? data) => (data as List<dynamic>)
              .map(
                (dynamic item) => ActivityModel.fromApiJson(
                  (item as Map<Object?, Object?>).cast<String, dynamic>(),
                ),
              )
              .toList(),
        );
    return envelope.data ?? <ActivityModel>[];
  }
}
