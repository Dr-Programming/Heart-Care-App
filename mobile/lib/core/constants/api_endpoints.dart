/// Every API path in the app. Nothing else may hardcode a URL.
///
/// The backend is frozen at `v1.0.0` (see `backend/docs/API.md`). Two traps
/// worth repeating here, because they bite every feature:
///
///  * **Success is always `200`.** The API never returns `201`, not even for
///    creates. Never branch on 201.
///  * Every response, success or error, is wrapped in the
///    `{success, data, message, timestamp}` envelope — unwrap it with
///    `ApiResponse.fromJson` before touching `data`.
abstract final class ApiEndpoints {
  static const String _v1 = '/api/v1';

  // ---------------------------------------------------------------- Auth (M1)
  static const String register = '$_v1/auth/register';
  static const String login = '$_v1/auth/login';
  static const String me = '$_v1/auth/me';

  // ------------------------------------------------------------- Profile (M2)
  /// `GET` never 404s — an unsaved profile comes back as a 200 all-null
  /// skeleton. `PUT` is a **full replace**: omitted fields are cleared to null.
  static const String patientMe = '$_v1/patients/me';

  // --------------------------------------------------------- Medications (M3)
  static const String medications = '$_v1/medications';

  /// `PUT` replaces the medication; `DELETE` is a soft deactivate and is
  /// idempotent — dose history is preserved either way.
  static String medication(String id) => '$_v1/medications/$id';

  static String medicationDoses(String medicationId) =>
      '$_v1/medications/$medicationId/doses';

  /// Supports `?from=&to=&medicationId=`. An unknown-but-valid `medicationId`
  /// returns `200 []`, not a 404.
  static const String doseLogs = '$_v1/dose-logs';

  // -------------------------------------------------------------- Vitals (M4)
  /// `POST` to log, `GET` for history. Supports `?type=&from=&to=`.
  static const String vitals = '$_v1/vitals';

  // ------------------------------------------------------------ Symptoms (M5)
  /// Supports `?from=&to=`.
  static const String symptoms = '$_v1/symptoms';

  // ------------------------------------------------------------ Activity (M5)
  /// Supports `?from=&to=`.
  static const String activities = '$_v1/activities';

  // ---------------------------------------------------------------- Sync (M0)
  /// Batched, push-only. Max 200 records per call. Owned by `core/sync` —
  /// feature code enqueues through `SyncEnqueuer` and never calls this.
  static const String sync = '$_v1/sync';
}
