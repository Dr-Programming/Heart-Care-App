import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:libu_care/features/education/domain/entities/quiz.dart';
import 'package:libu_care/features/education/presentation/screens/eat_well_screen.dart';

void main() {
  test('the old diet topic is gone: Eat well replaces it (en and am)', () {
    for (final String lang in <String>['en', 'am']) {
      final List<dynamic> json = jsonDecode(
        File('assets/content/topics_$lang.json').readAsStringSync(),
      ) as List<dynamic>;
      final Iterable<String> ids = json.map(
        (dynamic e) => (e as Map<Object?, Object?>)['id'] as String,
      );
      expect(ids, isNot(contains('diet')));
    }
  });

  test('the eating quiz opened from Eat well exists, one correct option per question, en and am', () {
    for (final String lang in <String>['en', 'am']) {
      final List<dynamic> json = jsonDecode(
        File('assets/content/quiz_$lang.json').readAsStringSync(),
      ) as List<dynamic>;
      final Quiz quiz = json
          .map((dynamic e) => Quiz.fromJson((e as Map<Object?, Object?>).cast()))
          .firstWhere((Quiz q) => q.topicId == eatWellQuizTopicId);
      expect(quiz.questions, isNotEmpty);
      for (final QuizQuestion q in quiz.questions) {
        expect(q.options.where((QuizOption o) => o.correct).length, 1);
      }
    }
  });
}
