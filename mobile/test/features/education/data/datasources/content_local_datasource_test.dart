import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:libu_care/features/education/domain/entities/quiz.dart';
import 'package:libu_care/features/education/domain/entities/topic.dart';

void main() {
  test('Topic.fromJson parses the fixture topics file', () async {
    final String raw = await File(
      'test/fixtures/content/topics_en.json',
    ).readAsString();
    final List<dynamic> json = jsonDecode(raw) as List<dynamic>;
    final List<Topic> topics = json
        .map((dynamic e) => Topic.fromJson((e as Map<Object?, Object?>).cast()))
        .toList();

    expect(topics, isNotEmpty);
    expect(topics.single.id, 'fixture-topic');
  });

  test('Quiz.fromJson parses the fixture quiz file', () async {
    final String raw = await File(
      'test/fixtures/content/quiz_en.json',
    ).readAsString();
    final List<dynamic> json = jsonDecode(raw) as List<dynamic>;
    final List<Quiz> quizzes = json
        .map((dynamic e) => Quiz.fromJson((e as Map<Object?, Object?>).cast()))
        .toList();

    expect(quizzes, isNotEmpty);
    expect(quizzes.single.topicId, 'fixture-topic');
  });
}
