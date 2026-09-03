import 'package:flutter_test/flutter_test.dart';
import 'package:libu_care/core/network/api_response.dart';

void main() {
  group('ApiResponse', () {
    test('unwraps a successful payload', () {
      final json = {
        'success': true,
        'data': {'id': '3f2a9c1e', 'name': 'Abebe Bekele'},
        'message': 'OK',
        'timestamp': '2026-08-06T10:00:00Z',
      };

      final res = ApiResponse.fromJson(
        json,
        (d) => (d! as Map<String, dynamic>)['name'] as String,
      );

      expect(res.success, isTrue);
      expect(res.data, 'Abebe Bekele');
      expect(res.message, 'OK');
      expect(res.timestamp, DateTime.utc(2026, 8, 6, 10));
    });

    test('handles the error envelope, where data is null', () {
      final json = {
        'success': false,
        'data': null,
        'message': 'Invalid phone or PIN',
        'timestamp': '2026-08-06T10:00:00Z',
      };

      final res = ApiResponse.fromJson(json, (d) => d);

      expect(res.success, isFalse);
      expect(res.data, isNull);
      expect(res.message, 'Invalid phone or PIN');
    });

    test('survives a malformed timestamp rather than throwing', () {
      final res = ApiResponse.fromJson(
        {'success': true, 'data': null, 'message': 'OK', 'timestamp': 'not-a-date'},
        (d) => d,
      );
      expect(res.timestamp, isNull);
    });
  });
}
