import 'package:dio/dio.dart';

/// GETs [path] and returns the `data` list of the API envelope as JSON maps.
Future<List<Map<String, dynamic>>> getJsonList(
  Dio dio,
  String path, {
  Map<String, dynamic>? query,
}) async {
  final Response<dynamic> response = await dio.get<dynamic>(
    path,
    queryParameters: query,
  );
  final Object? data = (response.data as Map<Object?, Object?>)['data'];
  if (data is! List) return const <Map<String, dynamic>>[];
  return <Map<String, dynamic>>[
    for (final Object? item in data)
      if (item is Map) item.cast<String, dynamic>(),
  ];
}
