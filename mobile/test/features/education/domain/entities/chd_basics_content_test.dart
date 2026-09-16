import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:libu_care/features/education/domain/entities/quiz.dart';
import 'package:libu_care/features/education/domain/entities/topic.dart';

void main() {
  test('chd-basics topic parses from the real content file (en)', () {
    final List<dynamic> json = jsonDecode(
      File('assets/content/topics_en.json').readAsStringSync(),
    ) as List<dynamic>;
    final Topic topic = Topic.fromJson(
      (json.first as Map<Object?, Object?>).cast(),
    );
    expect(topic.id, 'chd-basics');
    expect(topic.sections, isNotEmpty);
  });

  test('chd-basics topic parses from the real content file (am)', () {
    final List<dynamic> json = jsonDecode(
      File('assets/content/topics_am.json').readAsStringSync(),
    ) as List<dynamic>;
    final Topic topic = Topic.fromJson(
      (json.first as Map<Object?, Object?>).cast(),
    );
    expect(topic.id, 'chd-basics');
  });

  test('chd-basics quiz has an explanation on every option, en and am', () {
    for (final String lang in <String>['en', 'am']) {
      final List<dynamic> json = jsonDecode(
        File('assets/content/quiz_$lang.json').readAsStringSync(),
      ) as List<dynamic>;
      final Quiz quiz = Quiz.fromJson(
        (json.first as Map<Object?, Object?>).cast(),
      );
      expect(quiz.topicId, 'chd-basics');
      for (final QuizQuestion q in quiz.questions) {
        expect(q.options.where((QuizOption o) => o.correct).length, 1);
        for (final QuizOption o in q.options) {
          expect(o.explanation, isNotEmpty);
        }
      }
    }
  });
}
