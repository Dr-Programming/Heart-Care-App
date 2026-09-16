import 'dart:convert';

import 'package:flutter/services.dart';

import '../../domain/entities/quiz.dart';
import '../../domain/entities/topic.dart';

class ContentLocalDataSource {
  const ContentLocalDataSource();

  Future<List<Topic>> loadTopics(String languageCode) async {
    final String raw = await rootBundle.loadString(
      'assets/content/topics_$languageCode.json',
    );
    final List<dynamic> json = jsonDecode(raw) as List<dynamic>;
    return json
        .map((dynamic e) => Topic.fromJson((e as Map<Object?, Object?>).cast()))
        .toList();
  }

  Future<List<Quiz>> loadQuizzes(String languageCode) async {
    final String raw = await rootBundle.loadString(
      'assets/content/quiz_$languageCode.json',
    );
    final List<dynamic> json = jsonDecode(raw) as List<dynamic>;
    return json
        .map((dynamic e) => Quiz.fromJson((e as Map<Object?, Object?>).cast()))
        .toList();
  }
}
