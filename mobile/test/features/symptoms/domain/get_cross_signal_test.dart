import 'package:flutter_test/flutter_test.dart';
import 'package:libu_care/core/clinical/alert_evaluator.dart';
import 'package:libu_care/features/symptoms/domain/entities/symptom_answer.dart';
import 'package:libu_care/features/symptoms/domain/entities/symptom_check_in.dart';
import 'package:libu_care/features/symptoms/domain/entities/symptom_history_entry.dart';
import 'package:libu_care/features/symptoms/domain/repositories/symptom_repository.dart';
import 'package:libu_care/features/symptoms/domain/usecases/get_cross_signal.dart';
import 'package:mocktail/mocktail.dart';

class _MockSymptomRepository extends Mock implements SymptomRepository {}

SymptomHistoryEntry _entryWith({
  ChestPain chestPain = ChestPain.none,
  ShortnessOfBreath shortnessOfBreath = ShortnessOfBreath.none,
}) {
  return SymptomHistoryEntry(
    checkIn: SymptomCheckIn(
      clientRecordId: 'a',
      chestPain: chestPain,
      shortnessOfBreath: shortnessOfBreath,
      heartRate: 72,
      bloodPressure: const BloodPressureReading(systolic: 120, diastolic: 80),
      swelling: false,
      energyLevel: 7,
      measuredAt: DateTime.utc(2026, 8, 30),
    ),
    assessment: const SymptomAssessment(
      overall: Severity.none,
      symptoms: <String, Severity>{},
    ),
  );
}

void main() {
  late _MockSymptomRepository repository;

  setUp(() {
    repository = _MockSymptomRepository();
  });

  void stubToday(List<SymptomHistoryEntry> entries) {
    when(() => repository.watchHistory(from: any(named: 'from')))
        .thenAnswer((_) => Stream<List<SymptomHistoryEntry>>.value(entries));
  }

  test('a missed dose plus chest pain today is urgent', () async {
    stubToday(<SymptomHistoryEntry>[
      _entryWith(chestPain: const ChestPain(present: true, severity: 1)),
    ]);

    final Severity result = await GetCrossSignal(repository)
        .call(missedDoseToday: true)
        .first;

    expect(result, Severity.urgent);
  });

  test('a missed dose plus severe breathlessness today is urgent', () async {
    stubToday(<SymptomHistoryEntry>[
      _entryWith(shortnessOfBreath: ShortnessOfBreath.severe),
    ]);

    final Severity result = await GetCrossSignal(repository)
        .call(missedDoseToday: true)
        .first;

    expect(result, Severity.urgent);
  });

  test('a missed dose alone, with no cardiac symptoms, is a watch', () async {
    stubToday(<SymptomHistoryEntry>[_entryWith()]);

    final Severity result = await GetCrossSignal(repository)
        .call(missedDoseToday: true)
        .first;

    expect(result, Severity.monitor);
  });

  test('cardiac symptoms with no missed dose is none', () async {
    stubToday(<SymptomHistoryEntry>[
      _entryWith(chestPain: const ChestPain(present: true, severity: 8)),
    ]);

    final Severity result = await GetCrossSignal(repository)
        .call(missedDoseToday: false)
        .first;

    expect(result, Severity.none);
  });

  test('neither signal present is none', () async {
    stubToday(<SymptomHistoryEntry>[]);

    final Severity result = await GetCrossSignal(repository)
        .call(missedDoseToday: false)
        .first;

    expect(result, Severity.none);
  });

  test('mild breathlessness alone does not count as the "severe" half of the signal', () async {
    stubToday(<SymptomHistoryEntry>[
      _entryWith(shortnessOfBreath: ShortnessOfBreath.mild),
    ]);

    final Severity result = await GetCrossSignal(repository)
        .call(missedDoseToday: true)
        .first;

    expect(result, Severity.monitor);
  });

  test(
    'chest pain from any check-in today counts, not only the latest',
    () async {
      stubToday(<SymptomHistoryEntry>[
        _entryWith(), // latest: nothing reported
        _entryWith(
          chestPain: const ChestPain(present: true, severity: 3),
        ), // earlier that day: chest pain
      ]);

      final Severity result = await GetCrossSignal(repository)
          .call(missedDoseToday: true)
          .first;

      expect(result, Severity.urgent);
    },
  );
}
