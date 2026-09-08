import 'package:flutter_test/flutter_test.dart';
import 'package:libu_care/core/db/app_database.dart';
import 'package:libu_care/core/utils/date_formatter.dart';
import 'package:libu_care/features/symptoms/data/datasources/dose_log_reader.dart';

import '../../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late DoseLogReader reader;

  setUp(() {
    db = testDatabase();
    reader = DoseLogReader(db);
  });

  tearDown(() => db.close());

  Future<void> insertDose({
    required String clientRecordId,
    required String status,
    required DateTime scheduledDate,
  }) async {
    await db
        .into(db.doseLogs)
        .insert(
          DoseLogsCompanion.insert(
            clientRecordId: clientRecordId,
            medicationClientRecordId: 'med-1',
            status: status,
            scheduledDate: DateFormatter.toApiDate(scheduledDate),
            loggedAt: scheduledDate,
          ),
        );
  }

  test(
    'no dose rows at all means no missed dose — M3 not yet landed',
    () async {
      expect(
        await reader.hasMissedDose(date: DateTime.utc(2026, 8, 30)),
        isFalse,
      );
    },
  );

  test('a TAKEN dose today is not a missed dose', () async {
    await insertDose(
      clientRecordId: 'a',
      status: 'TAKEN',
      scheduledDate: DateTime.utc(2026, 8, 30),
    );

    expect(
      await reader.hasMissedDose(date: DateTime.utc(2026, 8, 30)),
      isFalse,
    );
  });

  test(
    'a SKIPPED dose today is not a missed dose — the patient decided',
    () async {
      await insertDose(
        clientRecordId: 'a',
        status: 'SKIPPED',
        scheduledDate: DateTime.utc(2026, 8, 30),
      );

      expect(
        await reader.hasMissedDose(date: DateTime.utc(2026, 8, 30)),
        isFalse,
      );
    },
  );

  test('a MISSED dose today is a missed dose', () async {
    await insertDose(
      clientRecordId: 'a',
      status: 'MISSED',
      scheduledDate: DateTime.utc(2026, 8, 30),
    );

    expect(await reader.hasMissedDose(date: DateTime.utc(2026, 8, 30)), isTrue);
  });

  test('a MISSED dose on a different day does not count for today', () async {
    await insertDose(
      clientRecordId: 'a',
      status: 'MISSED',
      scheduledDate: DateTime.utc(2026, 8, 29),
    );

    expect(
      await reader.hasMissedDose(date: DateTime.utc(2026, 8, 30)),
      isFalse,
    );
  });

  test('defaults to today when no date is given', () async {
    await insertDose(
      clientRecordId: 'a',
      status: 'MISSED',
      scheduledDate: DateTime.now(),
    );

    expect(await reader.hasMissedDose(), isTrue);
  });
}
