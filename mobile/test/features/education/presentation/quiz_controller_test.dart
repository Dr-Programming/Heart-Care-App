import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libu_care/features/education/presentation/controllers/quiz_controller.dart';

void main() {
  late ProviderContainer container;

  setUp(() => container = ProviderContainer());
  tearDown(() => container.dispose());

  test('starts at question 0 with nothing selected', () {
    final QuizState state = container.read(quizControllerProvider);
    expect(state.questionIndex, 0);
    expect(state.selectedOption, isNull);
  });

  test('selecting an option records it without advancing', () {
    container.read(quizControllerProvider.notifier).selectOption(2);

    final QuizState state = container.read(quizControllerProvider);
    expect(state.selectedOption, 2);
    expect(state.questionIndex, 0);
  });

  test('next advances the question and clears the selection', () {
    final QuizController notifier = container.read(
      quizControllerProvider.notifier,
    );
    notifier.selectOption(1);

    notifier.next();

    final QuizState state = container.read(quizControllerProvider);
    expect(state.questionIndex, 1);
    expect(state.selectedOption, isNull);
  });

  test('restart resets to question 0 with nothing selected', () {
    final QuizController notifier = container.read(
      quizControllerProvider.notifier,
    );
    notifier.selectOption(1);
    notifier.next();
    notifier.selectOption(0);

    notifier.restart();

    final QuizState state = container.read(quizControllerProvider);
    expect(state.questionIndex, 0);
    expect(state.selectedOption, isNull);
  });
}
