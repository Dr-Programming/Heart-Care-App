import 'package:dio/dio.dart';

import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/network/list_request.dart';

class ActivityRemoteDataSource {
  const ActivityRemoteDataSource(this._dio);

  final Dio _dio;

  /// Every activity the server holds for the signed-in patient.
  /// Records between [from] and [to] (yyyy-MM-dd, both included); all of
  /// them when left out.
  Future<List<Map<String, dynamic>>> history({String? from, String? to}) =>
      getJsonList(
        _dio,
        ApiEndpoints.activities,
        query: <String, dynamic>{'from': ?from, 'to': ?to},
      );
}
