import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:libu_care/features/symptoms/domain/entities/symptom_answer.dart';
import 'package:libu_care/features/symptoms/domain/entities/symptom_check_in.dart';
import 'package:libu_care/features/symptoms/domain/repositories/symptom_repository.dart';
import 'package:libu_care/features/symptoms/domain/validators/symptom_validators.dart';
import 'package:libu_care/features/symptoms/presentation/controllers/check_in_controller.dart';
import 'package:libu_care/features/symptoms/presentation/providers/symptom_providers.dart';
import 'package:mocktail/mocktail.dart';

class _MockSymptomRepository extends Mock implements SymptomRepository {}

void main() {
  late _MockSymptomRepository repository;
  late ProviderContainer container;

  setUpAll(() {
    registerFallbackValue(
      SymptomCheckIn(
        clientRecordId: 'fallback',
        chestPain: ChestPain.none,
        shortnessOfBreath: ShortnessOfBreath.none,
        heartRate: 72,
        bloodPressure: const BloodPressureReading(systolic: 120, diastolic: 80),
        swelling: false,
        energyLevel: 7,
        measuredAt: DateTime(2000),
      ),
    );
  });

  setUp(() {
    repository = _MockSymptomRepository();
    when(() => repository.log(any())).thenAnswer((_) async {});
    container = ProviderContainer(
      overrides: <Override>[
        symptomRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(container.dispose);
  });

  test(
    '"fine today" — the all-default check-in — logs through the repository',
    () async {
      final CheckInController notifier = container.read(
        checkInControllerProvider.notifier,
      );

      await notifier.submit(
        chestPain: ChestPain.none,
        shortnessOfBreath: ShortnessOfBreath.none,
        heartRate: 72,
        bloodPressure: const BloodPressureReading(systolic: 120, diastolic: 80),
        swelling: false,
        energyLevel: 7,
      );

      final List<dynamic> captured = verify(() => repository.log(captureAny()))
          .captured;
      final SymptomCheckIn logged = captured.single as SymptomCheckIn;
      expect(logged.chestPain.present, isFalse);
      expect(logged.clientRecordId, isNotEmpty);

      final AsyncValue<void> state = container.read(checkInControllerProvider);
      expect(state.hasValue, isTrue);
      expect(state.hasError, isFalse);
    },
  );

  test(
    'reported chest pain without a severity never reaches the repository',
    () async {
      final CheckInController notifier = container.read(
        checkInControllerProvider.notifier,
      );

      await notifier.submit(
        chestPain: const ChestPain(present: true),
        shortnessOfBreath: ShortnessOfBreath.none,
        heartRate: 72,
        bloodPressure: const BloodPressureReading(systolic: 120, diastolic: 80),
        swelling: false,
        energyLevel: 7,
      );

      verifyNever(() => repository.log(any()));

      final AsyncValue<void> state = container.read(checkInControllerProvider);
      expect(state.hasError, isTrue);
      final Object? error = state.error;
      expect(error, isA<SymptomValidationFailed>());
      expect(
        (error as SymptomValidationFailed).errors,
        contains(SymptomValidationError.chestPainSeverityRequired),
      );
    },
  );

  test('an out-of-range heart rate never reaches the repository', () async {
    final CheckInController notifier = container.read(
      checkInControllerProvider.notifier,
    );

    await notifier.submit(
      chestPain: ChestPain.none,
      shortnessOfBreath: ShortnessOfBreath.none,
      heartRate: 400,
      bloodPressure: const BloodPressureReading(systolic: 120, diastolic: 80),
      swelling: false,
      energyLevel: 7,
    );

    verifyNever(() => repository.log(any()));
    final AsyncValue<void> state = container.read(checkInControllerProvider);
    final Object? error = state.error;
    expect(
      (error as SymptomValidationFailed).errors,
      contains(SymptomValidationError.heartRateOutOfRange),
    );
  });

  test(
    'a repository failure surfaces through the async state, not a throw',
    () async {
      when(() => repository.log(any())).thenThrow(StateError('disk full'));
      final CheckInController notifier = container.read(
        checkInControllerProvider.notifier,
      );

      await notifier.submit(
        chestPain: ChestPain.none,
        shortnessOfBreath: ShortnessOfBreath.none,
        heartRate: 72,
        bloodPressure: const BloodPressureReading(systolic: 120, diastolic: 80),
        swelling: false,
        energyLevel: 7,
      );

      final AsyncValue<void> state = container.read(checkInControllerProvider);
      expect(state.hasError, isTrue);
      expect(state.error, isA<StateError>());
    },
  );

  test('mints a fresh clientRecordId on every submission', () async {
    final CheckInController notifier = container.read(
      checkInControllerProvider.notifier,
    );

    Future<void> submitOnce() => notifier.submit(
      chestPain: ChestPain.none,
      shortnessOfBreath: ShortnessOfBreath.none,
      heartRate: 72,
      bloodPressure: const BloodPressureReading(systolic: 120, diastolic: 80),
      swelling: false,
      energyLevel: 7,
    );

    await submitOnce();
    await submitOnce();

    final List<dynamic> captured = verify(() => repository.log(captureAny()))
        .captured;
    final List<String> ids = captured
        .cast<SymptomCheckIn>()
        .map((SymptomCheckIn c) => c.clientRecordId)
        .toList();
    expect(ids.toSet(), hasLength(2));
  });
}
