import 'package:flutter_test/flutter_test.dart';
import 'package:libu_care/core/clinical/alert_evaluator.dart';
import 'package:libu_care/core/utils/date_formatter.dart';
import 'package:libu_care/features/symptoms/domain/entities/symptom_answer.dart';
import 'package:libu_care/features/symptoms/domain/entities/symptom_check_in.dart';
import 'package:libu_care/features/symptoms/domain/entities/symptom_history_entry.dart';
import 'package:libu_care/features/symptoms/domain/repositories/symptom_repository.dart';
import 'package:libu_care/features/symptoms/domain/usecases/has_checked_in_today.dart';
import 'package:libu_care/features/symptoms/domain/usecases/reconcile_symptom_assessments.dart';
import 'package:libu_care/features/symptoms/domain/usecases/submit_check_in.dart';
import 'package:libu_care/features/symptoms/domain/usecases/watch_symptom_history.dart';
import 'package:mocktail/mocktail.dart';

class _MockSymptomRepository extends Mock implements SymptomRepository {}

SymptomCheckIn _checkIn({DateTime? measuredAt}) => SymptomCheckIn(
  clientRecordId: 'a',
  chestPain: ChestPain.none,
  shortnessOfBreath: ShortnessOfBreath.none,
  heartRate: 72,
  bloodPressure: const BloodPressureReading(systolic: 120, diastolic: 80),
  swelling: false,
  energyLevel: 7,
  measuredAt: measuredAt ?? DateTime.utc(2026, 9, 2),
);

SymptomHistoryEntry _log({DateTime? measuredAt}) => SymptomHistoryEntry(
  checkIn: _checkIn(measuredAt: measuredAt),
  assessment: const SymptomAssessment(
    overall: Severity.none,
    symptoms: <String, Severity>{},
  ),
);

void main() {
  late _MockSymptomRepository repository;

  setUp(() {
    repository = _MockSymptomRepository();
  });

  group('SubmitCheckIn', () {
    test('delegates to the repository with the same check-in', () async {
      final SymptomCheckIn checkIn = _checkIn();
      when(() => repository.log(checkIn)).thenAnswer((_) async {});

      await SubmitCheckIn(repository).call(checkIn);

      verify(() => repository.log(checkIn)).called(1);
    });
  });

  group('WatchSymptomHistory', () {
    test(
      'delegates to the repository, passing the from/to window through',
      () async {
        final DateTime from = DateTime.utc(2026, 8, 26);
        final DateTime to = DateTime.utc(2026, 9, 2);
        final List<SymptomHistoryEntry> logs = <SymptomHistoryEntry>[_log()];
        when(() => repository.watchHistory(from: from, to: to))
            .thenAnswer((_) => Stream<List<SymptomHistoryEntry>>.value(logs));

        final Stream<List<SymptomHistoryEntry>> result = WatchSymptomHistory(
          repository,
        ).call(from: from, to: to);

        await expectLater(result, emits(logs));
        verify(() => repository.watchHistory(from: from, to: to)).called(1);
      },
    );
  });

  group('HasCheckedInToday', () {
    test(
      'asks the repository for a window starting at midnight today',
      () async {
        final DateTime now = DateTime.utc(2026, 9, 2, 14, 30);
        final DateTime startOfDay = DateFormatter.startOfDay(now);
        final SymptomHistoryEntry todayLog = _log(measuredAt: now);
        when(() => repository.watchHistory(from: startOfDay)).thenAnswer(
          (_) => Stream<List<SymptomHistoryEntry>>.value(<SymptomHistoryEntry>[
            todayLog,
          ]),
        );

        final Stream<SymptomHistoryEntry?> result = HasCheckedInToday(
          repository,
        ).call(now: now);

        await expectLater(result, emits(todayLog));
      },
    );

    test('emits null when nothing has been logged today', () async {
      final DateTime now = DateTime.utc(2026, 9, 2, 8);
      when(
        () => repository.watchHistory(from: DateFormatter.startOfDay(now)),
      ).thenAnswer(
        (_) => Stream<List<SymptomHistoryEntry>>.value(<SymptomHistoryEntry>[]),
      );

      final Stream<SymptomHistoryEntry?> result = HasCheckedInToday(repository)
          .call(now: now);

      await expectLater(result, emits(isNull));
    });

    test(
      'the most recent entry wins when more than one exists today',
      () async {
        final DateTime now = DateTime.utc(2026, 9, 2, 20);
        final SymptomHistoryEntry latest = _log(measuredAt: now);
        final SymptomHistoryEntry earlier = _log(
          measuredAt: now.subtract(const Duration(hours: 6)),
        );
        // Newest-first, matching how the local datasource orders history.
        when(() => repository.watchHistory(from: DateFormatter.startOfDay(now)))
            .thenAnswer(
              (_) => Stream<List<SymptomHistoryEntry>>.value(
                <SymptomHistoryEntry>[latest, earlier],
              ),
            );

        final Stream<SymptomHistoryEntry?> result = HasCheckedInToday(
          repository,
        ).call(now: now);

        await expectLater(result, emits(latest));
      },
    );
  });

  group('ReconcileSymptomAssessments', () {
    test('delegates to the repository', () async {
      when(() => repository.reconcileServerAssessments())
          .thenAnswer((_) async {});

      await ReconcileSymptomAssessments(repository).call();

      verify(() => repository.reconcileServerAssessments()).called(1);
    });
  });
}
