import 'package:flutter_test/flutter_test.dart';
import 'package:libu_care/features/activity/domain/entities/activity_session.dart';
import 'package:libu_care/features/activity/domain/validators/activity_validators.dart';

void main() {
  group('activity duration validation (API bound: 1-1440 minutes)', () {
    test('accepts the bounds themselves', () {
      expect(validateActivitySession(durationMinutes: 1), isEmpty);
      expect(validateActivitySession(durationMinutes: 1440), isEmpty);
    });

    test('accepts an ordinary value in the middle', () {
      expect(validateActivitySession(durationMinutes: 30), isEmpty);
    });

    test('rejects zero and negative durations', () {
      expect(
        validateActivitySession(durationMinutes: 0),
        contains(ActivityValidationError.durationOutOfRange),
      );
      expect(
        validateActivitySession(durationMinutes: -5),
        contains(ActivityValidationError.durationOutOfRange),
      );
    });

    test('rejects a duration past 1440', () {
      expect(
        validateActivitySession(durationMinutes: 1441),
        contains(ActivityValidationError.durationOutOfRange),
      );
    });
  });

  group(
    'ActivityType — all seven values round-trip through their wire form',
    () {
      test('every ActivityType maps to and from its wire spelling', () {
        expect(ActivityType.values, hasLength(7));
        for (final ActivityType type in ActivityType.values) {
          expect(ActivityType.fromWire(type.wire), type);
        }
      });

      test('the wire spellings match the API contract exactly', () {
        expect(ActivityType.walking.wire, 'WALKING');
        expect(ActivityType.jogging.wire, 'JOGGING');
        expect(ActivityType.cycling.wire, 'CYCLING');
        expect(ActivityType.household.wire, 'HOUSEHOLD');
        expect(ActivityType.farming.wire, 'FARMING');
        expect(ActivityType.stretching.wire, 'STRETCHING');
        expect(ActivityType.other.wire, 'OTHER');
      });
    },
  );

  group('Intensity round-trips through its wire form', () {
    test('every Intensity maps to and from its wire spelling', () {
      expect(Intensity.values, hasLength(3));
      for (final Intensity intensity in Intensity.values) {
        expect(Intensity.fromWire(intensity.wire), intensity);
      }
    });

    test('the wire spellings match the API contract exactly', () {
      expect(Intensity.light.wire, 'LIGHT');
      expect(Intensity.moderate.wire, 'MODERATE');
      expect(Intensity.vigorous.wire, 'VIGOROUS');
    });
  });

  group('ActivitySession construction', () {
    test('steps and distance are optional', () {
      final ActivitySession withoutOptional = ActivitySession(
        clientRecordId: 'a',
        type: ActivityType.walking,
        durationMinutes: 20,
        intensity: Intensity.light,
        measuredAt: DateTime(2026, 9, 1),
      );
      expect(withoutOptional.steps, isNull);
      expect(withoutOptional.distanceMeters, isNull);
      expect(withoutOptional.note, isNull);

      final ActivitySession withOptional = ActivitySession(
        clientRecordId: 'b',
        type: ActivityType.cycling,
        durationMinutes: 45,
        intensity: Intensity.vigorous,
        measuredAt: DateTime(2026, 9, 1),
        steps: 3000,
        distanceMeters: 8000,
        note: 'felt good',
      );
      expect(withOptional.steps, 3000);
      expect(withOptional.distanceMeters, 8000);
      expect(withOptional.note, 'felt good');
    });
  });
}
