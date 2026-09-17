import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:libu_care/features/education/domain/entities/quiz.dart';
import 'package:libu_care/features/education/domain/entities/topic.dart';

void main() {
  test('heart-attack topic parses from the real content file (en and am)', () {
    for (final String lang in <String>['en', 'am']) {
      final List<dynamic> json = jsonDecode(
        File('assets/content/topics_$lang.json').readAsStringSync(),
      ) as List<dynamic>;
      final Topic topic = Topic.fromJson(
        (json[2] as Map<Object?, Object?>).cast(),
      );
      expect(topic.id, 'heart-attack');
      expect(topic.sections, isNotEmpty);
    }
  });

  test('heart-attack quiz has exactly one correct option per question, en and am', () {
    for (final String lang in <String>['en', 'am']) {
      final List<dynamic> json = jsonDecode(
        File('assets/content/quiz_$lang.json').readAsStringSync(),
      ) as List<dynamic>;
      final Quiz quiz = Quiz.fromJson(
        (json[2] as Map<Object?, Object?>).cast(),
      );
      expect(quiz.topicId, 'heart-attack');
      for (final QuizQuestion q in quiz.questions) {
        expect(q.options.where((QuizOption o) => o.correct).length, 1);
      }
    }
  });
}
