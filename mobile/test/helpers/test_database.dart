import 'package:drift/native.dart';
import 'package:libu_care/core/db/app_database.dart';

/// A real database, in memory.
///
/// Use this rather than mocking Drift. The local database is the source of
/// truth in an offline-first app, so a test that fakes it is not testing the
/// thing that matters — and an in-memory SQLite is fast enough to run in every
/// test.
///
/// ```dart
/// late AppDatabase db;
/// setUp(() => db = testDatabase());
/// tearDown(() => db.close());
/// ```
AppDatabase testDatabase() => AppDatabase(NativeDatabase.memory());
