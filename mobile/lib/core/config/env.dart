

abstract final class Env {
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    //defaultValue: 'http://10.0.2.2:8080',
    defaultValue: 'https://kinetic-tasting-venue.ngrok-free.dev',
  );
}
