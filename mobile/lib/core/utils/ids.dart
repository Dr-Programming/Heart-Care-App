import 'package:uuid/uuid.dart';

const Uuid _uuid = Uuid();

/// Mints a `client_record_id`.
///
/// Every user-generated record gets one of these the instant it is captured,
/// before anything touches the network. The server enforces
/// `UNIQUE (user_id, client_record_id)`, so re-posting the same record after a
/// dropped connection is a no-op rather than a duplicate row. This is the
/// entire idempotency mechanism for offline sync — there is no server-side
/// queue — so never generate one server-side, never reuse one across records,
/// and never regenerate one on retry.
String newClientRecordId() => _uuid.v4();
