// Author: Prince Jiteshbhai Khakhariya
// Contributors: Prince Jiteshbhai Khakhariya, Ihab Al-Nasheei
// Last updated by: Ihab Al-Nasheei

abstract final class Env {
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    //defaultValue: 'http://10.0.2.2:8080',
    defaultValue: 'https://kinetic-tasting-venue.ngrok-free.dev',
  );
}
