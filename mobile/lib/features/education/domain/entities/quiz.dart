class QuizOption {
  const QuizOption({
    required this.text,
    required this.correct,
    required this.explanation,
  });

  factory QuizOption.fromJson(Map<String, dynamic> json) => QuizOption(
    text: json['text'] as String,
    correct: json['correct'] as bool,
    explanation: json['explanation'] as String,
  );

  final String text;
  final bool correct;
  final String explanation;
}

class QuizQuestion {
  const QuizQuestion({required this.question, required this.options});

  factory QuizQuestion.fromJson(Map<String, dynamic> json) => QuizQuestion(
    question: json['question'] as String,
    options: (json['options'] as List<dynamic>)
        .map(
          (dynamic e) =>
              QuizOption.fromJson((e as Map<Object?, Object?>).cast()),
        )
        .toList(),
  );

  final String question;
  final List<QuizOption> options;
}

class Quiz {
  const Quiz({required this.topicId, required this.questions});

  factory Quiz.fromJson(Map<String, dynamic> json) => Quiz(
    topicId: json['topicId'] as String,
    questions: (json['questions'] as List<dynamic>)
        .map(
          (dynamic e) =>
              QuizQuestion.fromJson((e as Map<Object?, Object?>).cast()),
        )
        .toList(),
  );

  final String topicId;
  final List<QuizQuestion> questions;
}
