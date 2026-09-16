import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:libu_care/features/education/domain/entities/quiz.dart';
import 'package:libu_care/features/education/domain/entities/topic.dart';

void main() {
  test('psychosocial topic parses from the real content file (en and am)', () {
    for (final String lang in <String>['en', 'am']) {
      final List<dynamic> json = jsonDecode(
        File('assets/content/topics_$lang.json').readAsStringSync(),
      ) as List<dynamic>;
      final Topic topic = Topic.fromJson(
        (json[6] as Map<Object?, Object?>).cast(),
      );
      expect(topic.id, 'psychosocial');
    }
  });

  test('all 7 topics exist in both languages with the same ids, in the same order', () {
    final List<dynamic> en = jsonDecode(
      File('assets/content/topics_en.json').readAsStringSync(),
    ) as List<dynamic>;
    final List<dynamic> am = jsonDecode(
      File('assets/content/topics_am.json').readAsStringSync(),
    ) as List<dynamic>;

    expect(en.length, 7);
    expect(am.length, 7);

    final List<String> enIds = en
        .map((dynamic e) => (e as Map<Object?, Object?>)['id'] as String)
        .toList();
    final List<String> amIds = am
        .map((dynamic e) => (e as Map<Object?, Object?>)['id'] as String)
        .toList();
    expect(enIds, amIds);
    expect(enIds, <String>[
      'chd-basics',
      'symptoms',
      'heart-attack',
      'diet',
      'exercise',
      'medication-adherence',
      'psychosocial',
    ]);
  });

  test('all 7 quizzes exist in both languages, one per topic, every question has exactly one correct option', () {
    for (final String lang in <String>['en', 'am']) {
      final List<dynamic> json = jsonDecode(
        File('assets/content/quiz_$lang.json').readAsStringSync(),
      ) as List<dynamic>;
      expect(json.length, 7);
      for (final dynamic e in json) {
        final Quiz quiz = Quiz.fromJson((e as Map<Object?, Object?>).cast());
        expect(quiz.questions, isNotEmpty);
        for (final QuizQuestion q in quiz.questions) {
          expect(q.options.where((QuizOption o) => o.correct).length, 1);
          for (final QuizOption o in q.options) {
            expect(o.explanation, isNotEmpty);
          }
        }
      }
    }
  });
}
