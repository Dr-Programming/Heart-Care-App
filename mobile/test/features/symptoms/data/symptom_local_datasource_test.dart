import 'package:flutter_test/flutter_test.dart';
import 'package:libu_care/core/clinical/alert_evaluator.dart';
import 'package:libu_care/core/db/app_database.dart';
import 'package:libu_care/features/symptoms/data/datasources/symptom_local_datasource.dart';
import 'package:libu_care/features/symptoms/data/models/symptom_model.dart';
import 'package:libu_care/features/symptoms/domain/entities/symptom_answer.dart';
import 'package:libu_care/features/symptoms/domain/entities/symptom_check_in.dart';

import '../../../helpers/test_database.dart';

SymptomModel _model({
  required String clientRecordId,
  required DateTime measuredAt,
  ChestPain chestPain = ChestPain.none,
  bool worseChestPain = false,
}) {
  final SymptomCheckIn checkIn = SymptomCheckIn(
    clientRecordId: clientRecordId,
    chestPain: chestPain,
    shortnessOfBreath: ShortnessOfBreath.none,
    heartRate: 72,
    bloodPressure: const BloodPressureReading(systolic: 120, diastolic: 80),
    swelling: false,
    energyLevel: 7,
    measuredAt: measuredAt,
    worseThanYesterday: worseChestPain
        ? <SymptomKey, bool>{SymptomKey.chestPain: true}
        : const <SymptomKey, bool>{},
    note: 'after climbing stairs',
  );
  return SymptomModel.fromEntity(checkIn);
}

void main() {
  late AppDatabase db;
  late SymptomLocalDatasource datasource;

  setUp(() {
    db = testDatabase();
    datasource = SymptomLocalDatasource(db);
  });

  tearDown(() => db.close());

  test(
    'a saved check-in round-trips every field, including worseThanYesterday',
    () async {
      final SymptomModel model = _model(
        clientRecordId: 'a',
        measuredAt: DateTime.utc(2026, 8, 30, 7),
        chestPain: const ChestPain(present: true, severity: 6),
        worseChestPain: true,
      );

      await datasource.insert(model);
      final SymptomModel saved = (await datasource.watchHistory().first).single;

      final SymptomCheckIn entity = saved.toEntity();
      expect(entity.chestPain.present, isTrue);
      expect(entity.chestPain.severity, 6);
      expect(entity.worseThanYesterday, <SymptomKey, bool>{
        SymptomKey.chestPain: true,
      });
      expect(entity.note, 'after climbing stairs');
      expect(saved.serverId, isNull);
    },
  );

  test(
    'overallSeverity is stored and reflects the locally computed assessment',
    () async {
      final SymptomModel model = _model(
        clientRecordId: 'a',
        measuredAt: DateTime.utc(2026, 8, 30),
        chestPain: const ChestPain(present: true, severity: 8),
      );

      await datasource.insert(model);
      final SymptomModel saved = (await datasource.watchHistory().first).single;

      expect(saved.overallSeverity, Severity.emergency.wire);
      expect(saved.toHistoryEntry().overallSeverity, Severity.emergency);
    },
  );

  test('history is newest-first', () async {
    await datasource.insert(
      _model(clientRecordId: 'oldest', measuredAt: DateTime.utc(2026, 8, 1)),
    );
    await datasource.insert(
      _model(clientRecordId: 'newest', measuredAt: DateTime.utc(2026, 8, 3)),
    );
    await datasource.insert(
      _model(clientRecordId: 'middle', measuredAt: DateTime.utc(2026, 8, 2)),
    );

    final List<SymptomModel> history = await datasource.watchHistory().first;

    expect(history.map((SymptomModel m) => m.clientRecordId).toList(), <String>[
      'newest',
      'middle',
      'oldest',
    ]);
  });

  test('"checked in today" is correct across a midnight boundary', () async {
    final DateTime todayStart = DateTime.utc(2026, 8, 30);
    await datasource.insert(
      _model(
        clientRecordId: 'yesterday-late',
        measuredAt: todayStart.subtract(const Duration(seconds: 1)),
      ),
    );
    await datasource.insert(
      _model(clientRecordId: 'today-early', measuredAt: todayStart),
    );

    final List<SymptomModel> today = await datasource
        .watchHistory(from: todayStart)
        .first;

    expect(today.map((SymptomModel m) => m.clientRecordId).toList(), <String>[
      'today-early',
    ]);
  });

  group('unconfirmed / applyServerAssessment (reconciliation support)', () {
    test('a freshly inserted row is unconfirmed (serverId is null)', () async {
      await datasource.insert(
        _model(clientRecordId: 'a', measuredAt: DateTime.utc(2026, 8, 30)),
      );

      final List<SymptomModel> unconfirmed = await datasource.unconfirmed();

      expect(unconfirmed.map((SymptomModel m) => m.clientRecordId), <String>[
        'a',
      ]);
    });

    test(
      'applying a server assessment sets serverId and replaces the assessment',
      () async {
        await datasource.insert(
          _model(
            clientRecordId: 'a',
            measuredAt: DateTime.utc(2026, 8, 30),
            chestPain: const ChestPain(present: true, severity: 2),
          ),
        );
        // Locally this scores MONITOR; the "server" disagrees and says URGENT,
        // to prove the server's answer actually wins.
        final SymptomModel before =
            (await datasource.watchHistory().first).single;
        expect(before.overallSeverity, Severity.monitor.wire);

        await datasource.applyServerAssessment(
          clientRecordId: 'a',
          serverId: 'server-id-1',
          assessment: <String, dynamic>{
            'overall': 'URGENT',
            'symptoms': <String, dynamic>{'chestPain': 'URGENT'},
          },
          overallSeverity: 'URGENT',
        );

        final SymptomModel after =
            (await datasource.watchHistory().first).single;
        expect(after.serverId, 'server-id-1');
        expect(after.overallSeverity, Severity.urgent.wire);
        expect(after.toHistoryEntry().assessment.overall, Severity.urgent);
        // The patient's own entered data is untouched.
        expect(after.toEntity().chestPain.severity, 2);
        expect(after.note, 'after climbing stairs');

        expect(await datasource.unconfirmed(), isEmpty);
      },
    );
  });

  test(
    'watchHistory with no check-ins yet returns an empty list, not an error',
    () async {
      final List<SymptomModel> history = await datasource.watchHistory().first;
      expect(history, isEmpty);
    },
  );
}
