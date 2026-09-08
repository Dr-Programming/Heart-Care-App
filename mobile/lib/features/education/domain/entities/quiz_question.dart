/// One answer choice. [explanation] is shown for every option, right or
/// wrong (design decision 8) — the quiz reinforces, it does not grade.
class QuizOption {
  const QuizOption({required this.text, required this.explanation});

  final String text;
  final String explanation;
}

/// FR-EDU-008 — multiple choice, immediate feedback, retakeable, no score
/// kept and no pass mark. Entered from the CHD basics module.
class QuizQuestion {
  const QuizQuestion({
    required this.question,
    required this.options,
    required this.correctIndex,
  });

  final String question;
  final List<QuizOption> options;

  /// Index into [options].
  final int correctIndex;
}
