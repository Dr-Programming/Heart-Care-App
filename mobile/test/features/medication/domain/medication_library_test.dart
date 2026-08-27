import 'package:flutter_test/flutter_test.dart';
import 'package:libu_care/features/medication/domain/medication_library.dart';

void main() {
  test('empty query returns no suggestions', () {
    expect(searchMedicationLibrary(''), isEmpty);
    expect(searchMedicationLibrary('   '), isEmpty);
  });

  test('matches are case-insensitive substring matches on name', () {
    final results = searchMedicationLibrary('metop');
    expect(results, isNotEmpty);
    expect(results.every((e) => e.name.toLowerCase().contains('metop')), isTrue);
  });

  test('most-common entries sort first, then alphabetically by name, then by dose', () {
    final results = searchMedicationLibrary('metoprolol');
    expect(results.first.mostCommon, isTrue);
    for (int i = 1; i < results.length; i++) {
      if (results[i - 1].mostCommon == results[i].mostCommon) {
        final nameCompare = results[i - 1].name.compareTo(results[i].name);
        expect(nameCompare <= 0, isTrue);
        if (nameCompare == 0) {
          expect(results[i - 1].doseMg <= results[i].doseMg, isTrue);
        }
      }
    }
  });

  test('a query matching nothing returns an empty list, not an error', () {
    expect(searchMedicationLibrary('xyzzynotarealdrug'), isEmpty);
  });

  test('kMedicationLibrary has at least 25 entries covering common CHD drug classes', () {
    expect(kMedicationLibrary.length, greaterThanOrEqualTo(25));
    final classes = kMedicationLibrary.map((e) => e.drugClass).toSet();
    expect(classes, containsAll(<String>['Beta-blocker', 'Statin', 'Antiplatelet', 'ACE inhibitor']));
  });
}
