import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libu_care/core/network/dio_client.dart';
import 'package:libu_care/core/network/interceptors/timezone_interceptor.dart';

void main() {
  RequestOptions capture(Duration offset) {
    final TimezoneInterceptor interceptor = TimezoneInterceptor(
      offset: () => offset,
    );
    final RequestOptions options = RequestOptions(path: '/api/v1/vitals');
    interceptor.onRequest(options, RequestInterceptorHandler());
    return options;
  }

  test('sends the phone offset so the server buckets by local day', () {
    expect(capture(const Duration(hours: 3)).headers['X-Timezone'], '+03:00');
  });

  test('formats negative and half-hour offsets', () {
    expect(
      capture(const Duration(hours: -5, minutes: -30)).headers['X-Timezone'],
      '-05:30',
    );
    expect(
      capture(const Duration(hours: 5, minutes: 45)).headers['X-Timezone'],
      '+05:45',
    );
  });

  test('UTC is sent as +00:00', () {
    expect(capture(Duration.zero).headers['X-Timezone'], '+00:00');
  });

  test('every Dio built for the app carries the header', () {
    final Dio dio = buildDio(baseUrl: 'http://x', readToken: () async => null);
    expect(dio.interceptors.whereType<TimezoneInterceptor>(), hasLength(1));
  });
}
