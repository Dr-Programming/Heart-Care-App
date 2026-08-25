import 'package:flutter_test/flutter_test.dart';
import 'package:libu_care/features/medication/domain/entities/adherence.dart';

void main() {
  test('percentage divides taken by due', () {
    const Adherence a = Adherence(taken: 3, due: 4, skipped: 0, windowDays: 7);
    expect(a.hasData, isTrue);
    expect(a.percentage, closeTo(0.75, 0.0001));
  });

  test('zero due doses reports no data instead of dividing by zero', () {
    const Adherence a = Adherence(taken: 0, due: 0, skipped: 0, windowDays: 7);
    expect(a.hasData, isFalse);
    expect(a.percentage, isNull);
  });
}
