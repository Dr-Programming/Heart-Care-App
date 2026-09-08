import 'package:flutter_test/flutter_test.dart';
import 'package:libu_care/core/clinical/alert_evaluator.dart';
import 'package:libu_care/core/constants/api_endpoints.dart';
import 'package:libu_care/core/error/failure.dart';
import 'package:libu_care/features/symptoms/data/datasources/symptom_remote_datasource.dart';
import 'package:libu_care/features/symptoms/data/models/symptom_model.dart';
import 'package:libu_care/features/symptoms/domain/entities/symptom_answer.dart';
import 'package:libu_care/features/symptoms/domain/entities/symptom_check_in.dart';

import '../../../helpers/fake_dio.dart';

SymptomModel _model({
  String clientRecordId = '5c2f8a91-0000-0000-0000-000000000005',
}) {
  final SymptomCheckIn checkIn = SymptomCheckIn(
    clientRecordId: clientRecordId,
    chestPain: const ChestPain(present: true, severity: 8),
    shortnessOfBreath: ShortnessOfBreath.mild,
    heartRate: 82,
    bloodPressure: const BloodPressureReading(systolic: 165, diastolic: 92),
    swelling: true,
    energyLevel: 4,
    worseThanYesterday: const <SymptomKey, bool>{
      SymptomKey.chestPain: true,
      SymptomKey.swelling: false,
    },
    measuredAt: DateTime.utc(2026, 7, 10, 8, 15),
    note: 'tight chest since morning',
  );
  return SymptomModel.fromEntity(checkIn);
}

/// Mirrors the exact example in `backend/docs/API.md` §5.
Map<String, dynamic> _serverEcho({
  String id = 'd41b9900-5555-6666-7777-888899990000',
  String clientRecordId = '5c2f8a91-0000-0000-0000-000000000005',
  Map<String, dynamic> assessment = const <String, dynamic>{
    'overall': 'EMERGENCY',
    'symptoms': <String, dynamic>{
      'chestPain': 'EMERGENCY',
      'shortnessOfBreath': 'MONITOR',
      'bloodPressure': 'URGENT',
      'heartRate': 'NONE',
      'swelling': 'MONITOR',
      'energyLevel': 'NONE',
    },
  },
}) => <String, dynamic>{
  'id': id,
  'data': <String, dynamic>{
    'chestPain': <String, dynamic>{'present': true, 'severity': 8},
    'shortnessOfBreath': 'MILD',
    'heartRate': 82,
    'bloodPressure': <String, dynamic>{'systolic': 165, 'diastolic': 92},
    'swelling': true,
    'energyLevel': 4,
    'worseThanYesterday': <String, dynamic>{
      'chestPain': true,
      'swelling': false,
    },
  },
  'assessment': assessment,
  'measuredAt': '2026-07-10T08:15:00Z',
  'note': 'tight chest since morning',
  'clientRecordId': clientRecordId,
  'createdAt': '2026-07-10T08:15:02Z',
};

void main() {
  group('SymptomRemoteDatasource.log', () {
    test('POSTs exactly the whitelisted request shape', () async {
      final FakeDio fake = FakeDio()
        ..stub(
          ApiEndpoints.symptoms,
          FakeResponse.ok(_serverEcho(), message: 'Symptom check-in logged'),
        );
      final SymptomRemoteDatasource datasource = SymptomRemoteDatasource(
        fake.dio,
      );

      await datasource.log(_model());

      final Map<String, dynamic> sent = fake.requests.single.json;
      expect(sent.keys.toSet(), <String>{
        'clientRecordId',
        'measuredAt',
        'note',
        'data',
      });
      final Map<String, dynamic> data = (sent['data'] as Map).cast();
      expect(data.keys.toSet(), <String>{
        'chestPain',
        'shortnessOfBreath',
        'heartRate',
        'bloodPressure',
        'swelling',
        'energyLevel',
        'worseThanYesterday',
      });
      expect(data['shortnessOfBreath'], 'MILD');
      expect(data['heartRate'], 82);
      expect((data['chestPain'] as Map)['severity'], 8);
      expect((data['bloodPressure'] as Map)['systolic'], 165);
      expect((data['worseThanYesterday'] as Map)['chestPain'], isTrue);
    });

    test('omits worseThanYesterday and note when absent', () async {
      final FakeDio fake = FakeDio()
        ..stub(ApiEndpoints.symptoms, FakeResponse.ok(_serverEcho()));
      final SymptomRemoteDatasource datasource = SymptomRemoteDatasource(
        fake.dio,
      );
      final SymptomCheckIn bare = SymptomCheckIn(
        clientRecordId: 'a',
        chestPain: ChestPain.none,
        shortnessOfBreath: ShortnessOfBreath.none,
        heartRate: 72,
        bloodPressure: const BloodPressureReading(systolic: 120, diastolic: 80),
        swelling: false,
        energyLevel: 7,
        measuredAt: DateTime.utc(2026, 7, 10),
      );

      await datasource.log(SymptomModel.fromEntity(bare));

      final Map<String, dynamic> sent = fake.requests.single.json;
      expect(sent.containsKey('note'), isFalse);
      final Map<String, dynamic> data = (sent['data'] as Map).cast();
      expect(data.containsKey('worseThanYesterday'), isFalse);
      // present: false still omits severity, per design decision "ignored
      // when not present".
      expect((data['chestPain'] as Map).containsKey('severity'), isFalse);
    });

    test("unwraps the 200 envelope, parsing the server's assessment into the "
        'same shape the local evaluator produces', () async {
      final FakeDio fake = FakeDio()
        ..stub(ApiEndpoints.symptoms, FakeResponse.ok(_serverEcho()));
      final SymptomRemoteDatasource datasource = SymptomRemoteDatasource(
        fake.dio,
      );

      final SymptomModel result = await datasource.log(_model());

      expect(result.serverId, 'd41b9900-5555-6666-7777-888899990000');
      final SymptomAssessment assessment = result.toHistoryEntry().assessment;
      expect(assessment.overall, Severity.emergency);
      expect(assessment.symptoms['chestPain'], Severity.emergency);
      expect(assessment.symptoms['bloodPressure'], Severity.urgent);
      expect(assessment.symptoms['heartRate'], Severity.none);
    });

    test(
      'a 400 (e.g. an unwhitelisted key) throws a ValidationFailure',
      () async {
        final FakeDio fake = FakeDio()
          ..stub(
            ApiEndpoints.symptoms,
            FakeResponse.error(400, 'Unrecognized field in data'),
          );
        final SymptomRemoteDatasource datasource = SymptomRemoteDatasource(
          fake.dio,
        );

        await expectLater(
          () => datasource.log(_model()),
          throwsA(isA<ValidationFailure>()),
        );
      },
    );

    test('a transport failure throws a NetworkFailure', () async {
      final FakeDio fake = FakeDio()
        ..stub(ApiEndpoints.symptoms, FakeResponse.offline());
      final SymptomRemoteDatasource datasource = SymptomRemoteDatasource(
        fake.dio,
      );

      await expectLater(
        () => datasource.log(_model()),
        throwsA(isA<NetworkFailure>()),
      );
    });
  });

  group('SymptomRemoteDatasource.fetchHistory', () {
    test('GETs with the from/to window formatted as plain dates', () async {
      final FakeDio fake = FakeDio()
        ..stub(ApiEndpoints.symptoms, FakeResponse.ok(<dynamic>[]));
      final SymptomRemoteDatasource datasource = SymptomRemoteDatasource(
        fake.dio,
      );

      await datasource.fetchHistory(
        from: DateTime.utc(2026, 7, 1),
        to: DateTime.utc(2026, 7, 31),
      );

      final RecordedRequest request = fake.requests.single;
      expect(request.queryParameters['from'], '2026-07-01');
      expect(request.queryParameters['to'], '2026-07-31');
    });

    test('parses each item, including its assessment', () async {
      final FakeDio fake = FakeDio()
        ..stub(
          ApiEndpoints.symptoms,
          FakeResponse.ok(<dynamic>[
            _serverEcho(id: 'id-2', clientRecordId: 'b'),
          ]),
        );
      final SymptomRemoteDatasource datasource = SymptomRemoteDatasource(
        fake.dio,
      );

      final List<SymptomModel> history = await datasource.fetchHistory();

      expect(history, hasLength(1));
      expect(history.single.serverId, 'id-2');
      expect(history.single.clientRecordId, 'b');
      expect(history.single.overallSeverity, 'EMERGENCY');
    });

    test(
      'an empty history responds with an empty list, not an error',
      () async {
        final FakeDio fake = FakeDio()
          ..stub(ApiEndpoints.symptoms, FakeResponse.ok(<dynamic>[]));
        final SymptomRemoteDatasource datasource = SymptomRemoteDatasource(
          fake.dio,
        );

        final List<SymptomModel> history = await datasource.fetchHistory();

        expect(history, isEmpty);
      },
    );
  });
}
