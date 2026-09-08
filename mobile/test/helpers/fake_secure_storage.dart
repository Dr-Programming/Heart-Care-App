import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const MethodChannel _channel = MethodChannel(
  'plugins.it_nomads.com/flutter_secure_storage',
);

/// Answers `flutter_secure_storage`'s platform channel with an in-memory map,
/// so `TokenStore` works under `flutter test` without touching a real
/// keystore. Call in `setUp`; each call resets the backing store.
void setUpFakeSecureStorage() {
  final Map<String, String> backing = <String, String>{};
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(_channel, (MethodCall call) async {
        switch (call.method) {
          case 'write':
            final Map<Object?, Object?> args =
                call.arguments as Map<Object?, Object?>;
            backing[args['key'] as String] = args['value'] as String;
            return null;
          case 'read':
            final Map<Object?, Object?> args =
                call.arguments as Map<Object?, Object?>;
            return backing[args['key'] as String];
          case 'delete':
            final Map<Object?, Object?> args =
                call.arguments as Map<Object?, Object?>;
            backing.remove(args['key'] as String);
            return null;
          case 'readAll':
            return backing;
          default:
            return null;
        }
      });
}
