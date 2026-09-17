import 'package:flutter_test/flutter_test.dart';
import 'package:libu_care/features/education/domain/entities/quiz.dart';

void main() {
  test('parses a quiz with questions and options', () {
    final Quiz quiz = Quiz.fromJson(<String, dynamic>{
      'topicId': 'chd-basics',
      'questions': <Map<String, dynamic>>[
        <String, dynamic>{
          'question': 'What is CHD?',
          'options': <Map<String, dynamic>>[
            <String, dynamic>{
              'text': 'Plaque build-up in the heart arteries',
              'correct': true,
              'explanation': 'Correct - this is the definition of CHD.',
            },
            <String, dynamic>{
              'text': 'A lung infection',
              'correct': false,
              'explanation': 'Not quite - that is not related to CHD.',
            },
          ],
        },
      ],
    });

    expect(quiz.topicId, 'chd-basics');
    expect(quiz.questions.single.options.length, 2);
    expect(quiz.questions.single.options.first.correct, true);
  });

  test('every option carries a non-empty explanation', () {
    final Quiz quiz = Quiz.fromJson(<String, dynamic>{
      'topicId': 't',
      'questions': <Map<String, dynamic>>[
        <String, dynamic>{
          'question': 'Q',
          'options': <Map<String, dynamic>>[
            <String, dynamic>{
              'text': 'A',
              'correct': true,
              'explanation': 'Because A.',
            },
          ],
        },
      ],
    });

    for (final QuizQuestion q in quiz.questions) {
      for (final QuizOption o in q.options) {
        expect(o.explanation, isNotEmpty);
      }
    }
  });
}
