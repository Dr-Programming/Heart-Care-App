import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:libu_care/features/profile/domain/validators.dart';

void main() {
  group('ProfileValidators.birthYear', () {
    test('accepts null', () {
      expect(ProfileValidators.birthYear(null).isValid, true);
    });

    test('accepts a valid year', () {
      expect(ProfileValidators.birthYear(1990).isValid, true);
    });

    test('rejects a year before 1900', () {
      expect(ProfileValidators.birthYear(1899).isValid, false);
    });

    test('rejects a year after 2100', () {
      expect(ProfileValidators.birthYear(2101).isValid, false);
    });
  });

  group('ProfileValidators.heightCm', () {
    test('accepts null', () {
      expect(ProfileValidators.heightCm(null).isValid, true);
    });

    test('accepts a valid height', () {
      expect(ProfileValidators.heightCm(170).isValid, true);
    });

    test('rejects below 50', () {
      expect(ProfileValidators.heightCm(49).isValid, false);
    });

    test('rejects above 250', () {
      expect(ProfileValidators.heightCm(251).isValid, false);
    });
  });

  group('ProfileValidators.chdStage', () {
    test('accepts null', () {
      expect(ProfileValidators.chdStage(null).isValid, true);
    });

    test('accepts a short diagnosis string', () {
      expect(ProfileValidators.chdStage('Coronary artery disease').isValid, true);
    });

    test('rejects a string over 50 characters', () {
      final longStage = 'x' * 51;
      expect(ProfileValidators.chdStage(longStage).isValid, false);
    });
  });

  group('ProfileValidators.nonNegative', () {
    test('accepts null', () {
      expect(ProfileValidators.nonNegative(null).isValid, true);
    });

    test('accepts zero', () {
      expect(ProfileValidators.nonNegative(0).isValid, true);
    });

    test('accepts a positive number', () {
      expect(ProfileValidators.nonNegative(5000).isValid, true);
    });

    test('rejects a negative number', () {
      expect(ProfileValidators.nonNegative(-1).isValid, false);
    });
  });

  group('error messages are translation keys', () {
    // Every failure must return a key that actually exists in en.json — a
    // bare English sentence here would silently defeat FR-LOC-002, since the
    // domain layer has no business deciding what a patient reads.
    late Map<String, dynamic> en;

    setUpAll(() async {
      final raw = await File(
        'assets/translations/en.json',
      ).readAsString();
      en = jsonDecode(raw) as Map<String, dynamic>;
    });

    bool keyExists(String dottedKey) {
      dynamic node = en;
      for (final part in dottedKey.split('.')) {
        if (node is! Map<String, dynamic> || !node.containsKey(part)) {
          return false;
        }
        node = node[part];
      }
      return node is String;
    }

    test('birthYear out-of-range key exists', () {
      final result = ProfileValidators.birthYear(1899);
      expect(keyExists(result.errorMessage!), isTrue);
    });

    test('heightCm out-of-range key exists', () {
      final result = ProfileValidators.heightCm(10);
      expect(keyExists(result.errorMessage!), isTrue);
    });

    test('chdStage too-long key exists', () {
      final result = ProfileValidators.chdStage('x' * 51);
      expect(keyExists(result.errorMessage!), isTrue);
    });

    test('nonNegative negative-value key exists', () {
      final result = ProfileValidators.nonNegative(-1);
      expect(keyExists(result.errorMessage!), isTrue);
    });
  });
}