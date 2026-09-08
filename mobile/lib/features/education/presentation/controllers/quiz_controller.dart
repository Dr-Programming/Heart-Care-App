import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'quiz_controller.g.dart';

/// `questionIndex >= questions.length` (checked by the screen, which is the
/// only place that knows how many questions there are) means finished.
class QuizState {
  const QuizState({this.questionIndex = 0, this.selectedOption});

  final int questionIndex;

  /// Null means the current question is unanswered.
  final int? selectedOption;
}

/// FR-EDU-008 — one question at a time, immediate feedback, retakeable, no
/// score kept. Ephemeral: nothing here persists past the screen closing.
@riverpod
class QuizController extends _$QuizController {
  @override
  QuizState build() => const QuizState();

  void selectOption(int index) {
    state = QuizState(
      questionIndex: state.questionIndex,
      selectedOption: index,
    );
  }

  void next() {
    state = QuizState(questionIndex: state.questionIndex + 1);
  }

  void restart() {
    state = const QuizState();
  }
}
