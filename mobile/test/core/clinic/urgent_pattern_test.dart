import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:libu_care/core/clinic/urgent_pattern.dart';
import 'package:libu_care/core/db/app_database.dart';

import '../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  setUp(() => db = testDatabase());
  tearDown(() => db.close());

  int n = 0;
  Future<void> bp(int systolic, int diastolic, {required DateTime at}) => db
      .into(db.vitalsLogs)
      .insert(
        VitalsLogsCompanion.insert(
          clientRecordId: 'v${n++}',
          type: 'BLOOD_PRESSURE',
          valuesJson: jsonEncode(<String, int>{
            'systolic': systolic,
            'diastolic': diastolic,
          }),
          measuredAt: at,
        ),
      );

  Future<void> checkIn(String severity, {required DateTime at}) => db
      .into(db.symptomLogs)
      .insert(
        SymptomLogsCompanion.insert(
          clientRecordId: 's${n++}',
          dataJson: '{}',
          overallSeverity: Value<String>(severity),
          measuredAt: at,
        ),
      );

  final DateTime now = DateTime.now();

  test('two urgent readings are not yet a pattern', () async {
    await bp(150, 95, at: now.subtract(const Duration(days: 1)));
    await bp(150, 95, at: now.subtract(const Duration(hours: 1)));

    final UrgentPattern p = await readUrgentPattern(db);
    expect(p.count, 2);
    expect(p.shouldRemind, isFalse);
  });

  test('three urgent readings in a week, vitals and check-ins together, remind the patient', () async {
    await bp(150, 95, at: now.subtract(const Duration(days: 3)));
    await bp(185, 100, at: now.subtract(const Duration(days: 2)));
    await checkIn('URGENT', at: now.subtract(const Duration(hours: 2)));

    final UrgentPattern p = await readUrgentPattern(db);
    expect(p.count, 3);
    expect(p.shouldRemind, isTrue);
  });

  test('normal readings and readings older than a week do not count', () async {
    await bp(118, 76, at: now.subtract(const Duration(hours: 3)));
    await checkIn('MONITOR', at: now.subtract(const Duration(hours: 2)));
    await bp(150, 95, at: now.subtract(const Duration(days: 8)));
    await bp(150, 95, at: now.subtract(const Duration(days: 9)));
    await bp(150, 95, at: now.subtract(const Duration(hours: 1)));

    expect((await readUrgentPattern(db)).count, 1);
  });

  test('dismissing hides the reminder until the next urgent reading', () async {
    for (int i = 1; i <= 3; i++) {
      await bp(150, 95, at: now.subtract(Duration(hours: i)));
    }
    await dismissClinicReminder(db);
    expect((await readUrgentPattern(db)).shouldRemind, isFalse);

    await bp(150, 95, at: DateTime.now().add(const Duration(seconds: 1)));
    expect((await readUrgentPattern(db)).shouldRemind, isTrue);
  });
}
