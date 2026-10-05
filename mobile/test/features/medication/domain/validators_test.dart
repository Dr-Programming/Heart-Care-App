import 'package:flutter_test/flutter_test.dart';
import 'package:libu_care/features/medication/domain/entities/medication.dart';
import 'package:libu_care/features/medication/domain/validators.dart';

void main() {
  group('validateMedicationName', () {
    test('rejects blank', () {
      expect(validateMedicationName('   '), 'meds.errors.nameRequired');
    });
    test('rejects over 255 chars', () {
      expect(validateMedicationName('a' * 256), 'meds.errors.nameTooLong');
    });
    test('accepts a normal name', () {
      expect(validateMedicationName('Atorvastatin'), isNull);
    });
  });

  group('validateDoseMg', () {
    test('rejects blank', () {
      expect(validateDoseMg(''), 'meds.errors.doseRequired');
    });
    test('rejects non-numeric', () {
      expect(validateDoseMg('abc'), 'meds.errors.doseInvalid');
    });
    test('rejects zero and negative', () {
      expect(validateDoseMg('0'), 'meds.errors.dosePositive');
      expect(validateDoseMg('-5'), 'meds.errors.dosePositive');
    });
    test('rejects a dose above the server maximum of 10000 mg', () {
      expect(validateDoseMg('10001'), 'meds.errors.doseTooHigh');
      expect(validateDoseMg('10000'), isNull);
    });
    test('accepts a positive number, including decimals', () {
      expect(validateDoseMg('2.5'), isNull);
      expect(validateDoseMg('100'), isNull);
    });
  });

  group('validateScheduleTimes', () {
    test('rejects an empty schedule', () {
      expect(
        validateScheduleTimes(const <String>[]),
        'meds.errors.scheduleRequired',
      );
    });
    test('rejects a malformed time', () {
      expect(
        validateScheduleTimes(const <String>['8am']),
        'meds.errors.scheduleFormat',
      );
      expect(
        validateScheduleTimes(const <String>['25:00']),
        'meds.errors.scheduleFormat',
      );
    });
    test('accepts one or more well-formed times', () {
      expect(validateScheduleTimes(const <String>['08:00', '20:00']), isNull);
    });
  });

  group('validateScheduleCount', () {
    test('fixed frequencies need exactly their number of times', () {
      expect(
        validateScheduleCount(const <String>[
          '08:00',
          '14:00',
          '20:00',
        ], MedicationFrequency.bid),
        'meds.errors.scheduleCountBid',
      );
      expect(
        validateScheduleCount(const <String>['08:00'], MedicationFrequency.tid),
        'meds.errors.scheduleCountTid',
      );
      expect(
        validateScheduleCount(const <String>[
          '08:00',
          '20:00',
        ], MedicationFrequency.onceDaily),
        'meds.errors.scheduleCountOnce',
      );
      expect(
        validateScheduleCount(const <String>[
          '08:00',
          '20:00',
        ], MedicationFrequency.bid),
        isNull,
      );
    });
    test('a time can only appear once', () {
      expect(
        validateScheduleCount(const <String>[
          '08:00',
          '08:00',
        ], MedicationFrequency.bid),
        'meds.errors.scheduleDuplicate',
      );
    });
    test('custom allows up to 12 times', () {
      expect(
        validateScheduleCount(
          List<String>.generate(
            13,
            (int i) => '${(i + 6).toString().padLeft(2, '0')}:00',
          ),
          MedicationFrequency.custom,
        ),
        'meds.errors.scheduleTooMany',
      );
      expect(
        validateScheduleCount(const <String>[], MedicationFrequency.custom),
        isNull,
      );
    });
  });
}
