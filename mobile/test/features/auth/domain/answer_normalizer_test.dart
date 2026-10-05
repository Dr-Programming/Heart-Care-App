import 'package:flutter_test/flutter_test.dart';
import 'package:libu_care/features/auth/domain/answer_normalizer.dart';
import 'package:libu_care/features/auth/domain/security_question.dart';

/// Mirrors backend SecurityAnswerNormalizerTest: the phone's offline check and the server's check
/// must reach the same answer for the same input.
void main() {
  test('ignores case and surrounding space', () {
    expect(normalizeAnswer('  Bole School '), normalizeAnswer('bole school'));
  });

  test('collapses inner whitespace', () {
    expect(normalizeAnswer('Bole \t  School'), 'bole school');
  });

  test('applies no Unicode compatibility folding (matches the server)', () {
    expect(normalizeAnswer('ＢＯＬＥ'), 'ｂｏｌｅ');
  });

  test('keeps Amharic text', () {
    expect(normalizeAnswer(' አዲስ  አበባ '), 'አዲስ አበባ');
  });

  test('answers must be 2 to 100 characters after normalising', () {
    expect(isValidAnswer(' a '), isFalse);
    expect(isValidAnswer('ab'), isTrue);
    expect(isValidAnswer('x' * 100), isTrue);
    expect(isValidAnswer('x' * 101), isFalse);
  });

  test('question IDs match the server catalogue', () {
    expect(SecurityQuestion.values.map((SecurityQuestion q) => q.id), <String>[
      'FIRST_SCHOOL',
      'CHILDHOOD_FRIEND',
      'FAVORITE_TEACHER',
      'CHILDHOOD_STREET',
      'FIRST_JOB_PLACE',
      'FAVORITE_CHILDHOOD_FOOD',
      'FIRST_PHONE_BRAND',
      'CHILDHOOD_HERO',
    ]);
    expect(
      SecurityQuestion.fromId('CHILDHOOD_HERO'),
      SecurityQuestion.childhoodHero,
    );
    expect(SecurityQuestion.fromId('MOTHERS_NAME'), isNull);
  });
}
