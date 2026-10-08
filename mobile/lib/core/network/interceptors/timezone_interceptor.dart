import 'package:dio/dio.dart';

/// Tells the server which calendar the patient lives in, so "today", history
/// filters and "one check-in per day" use local midnight instead of UTC.
///
/// The server reads `X-Timezone` as a Java `ZoneId`, which accepts a fixed
/// offset such as `+03:00`. The offset is read per request, so a patient who
/// travels or crosses a daylight-saving change sends the right one.
class TimezoneInterceptor extends Interceptor {
  TimezoneInterceptor({Duration Function()? offset})
    : _offset = offset ?? (() => DateTime.now().timeZoneOffset);

  static const String header = 'X-Timezone';

  final Duration Function() _offset;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    options.headers[header] = formatOffset(_offset());
    handler.next(options);
  }

  static String formatOffset(Duration offset) {
    final String sign = offset.isNegative ? '-' : '+';
    final int minutes = offset.inMinutes.abs();
    final String hh = (minutes ~/ 60).toString().padLeft(2, '0');
    final String mm = (minutes % 60).toString().padLeft(2, '0');
    return '$sign$hh:$mm';
  }
}
