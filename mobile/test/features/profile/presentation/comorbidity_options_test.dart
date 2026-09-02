import 'package:flutter_test/flutter_test.dart';
import 'package:libu_care/features/profile/presentation/widgets/comorbidity_options.dart';

void main() {
  group('splitComorbidities', () {
    test('separates curated values from free text', () {
      final result = splitComorbidities([
        'diabetes',
        'stroke',
        'gout',
      ]);

      expect(result.selected, {'diabetes', 'stroke'});
      expect(result.otherText, 'gout');
    });

    test('joins multiple free-text entries', () {
      final result = splitComorbidities(['gout', 'arthritis']);

      expect(result.selected, isEmpty);
      expect(result.otherText, 'gout, arthritis');
    });

    test('round-trips through mergeComorbidities', () {
      const stored = ['diabetes', 'hypertension', 'thyroid condition'];

      final split = splitComorbidities(stored);
      final merged = mergeComorbidities(split.selected, split.otherText);

      expect(merged.toSet(), stored.toSet());
    });

    test('handles an empty list', () {
      final result = splitComorbidities(const []);

      expect(result.selected, isEmpty);
      expect(result.otherText, isEmpty);
    });
  });

  group('mergeComorbidities', () {
    test('drops a blank "other" entry rather than storing an empty string',
        () {
      final merged = mergeComorbidities({'diabetes'}, '   ');

      expect(merged, ['diabetes']);
    });

    test('trims the free-text entry', () {
      final merged = mergeComorbidities({}, '  gout  ');

      expect(merged, ['gout']);
    });
  });

  group('ComorbidityOption.isKnown', () {
    test('recognises a curated value', () {
      expect(ComorbidityOption.isKnown('kidney_disease'), isTrue);
    });

    test('rejects free text and legacy display labels alike', () {
      expect(ComorbidityOption.isKnown('Kidney disease'), isFalse);
      expect(ComorbidityOption.isKnown('gout'), isFalse);
    });
  });
}
