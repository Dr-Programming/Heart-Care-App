/// Compile-time configuration.
///
/// Supply a real host with:
///   flutter run --dart-define=API_BASE_URL=http://192.168.1.10:8080
///
/// The default targets the Android emulator's alias for the host machine's
/// localhost, which is where `mvn spring-boot:run` serves the backend.
abstract final class Env {
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:8080',
  );
}
