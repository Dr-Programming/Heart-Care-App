import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import '../../domain/entities/block.dart';
import '../../domain/entities/quiz_question.dart';
import '../../domain/entities/section.dart';
import '../../domain/entities/topic.dart';

/// Reads bundled education content — no database, no network (FR-OFF-009).
///
/// Split deliberately into two layers:
///
///  * [parseTopics]/[parseQuiz] are pure functions over a JSON string. They
///    need nothing from Flutter and are fully testable today.
///  * [loadTopics]/[loadQuiz] read the actual asset via `rootBundle`. **These
///    two methods are the ones that need `assets/content/` declared in
///    `pubspec.yaml`** — until that lands, calling them throws (the asset
///    simply is not in the bundle), while the parsing functions above already
///    work and are already tested.
class ContentLocalDatasource {
  const ContentLocalDatasource();

  Future<List<Topic>> loadTopics(String languageCode) async {
    final String raw = await rootBundle.loadString(
      'assets/content/topics_$languageCode.json',
    );
    return parseTopics(raw);
  }

  Future<List<QuizQuestion>> loadQuiz(String languageCode) async {
    final String raw = await rootBundle.loadString(
      'assets/content/quiz_$languageCode.json',
    );
    return parseQuiz(raw);
  }
}

/// Parses a `topics_<lang>.json` document: a JSON array of topic objects.
List<Topic> parseTopics(String raw) {
  final List<dynamic> json = jsonDecode(raw) as List<dynamic>;
  return json
      .map((dynamic e) => _topicFromJson((e as Map<String, dynamic>)))
      .toList();
}

/// Parses a `quiz_<lang>.json` document: a JSON array of question objects.
List<QuizQuestion> parseQuiz(String raw) {
  final List<dynamic> json = jsonDecode(raw) as List<dynamic>;
  return json
      .map((dynamic e) => _quizQuestionFromJson((e as Map<String, dynamic>)))
      .toList();
}

Topic _topicFromJson(Map<String, dynamic> json) {
  final List<dynamic> sections = json['sections'] as List<dynamic>;
  return Topic(
    id: json['id'] as String,
    title: json['title'] as String,
    summary: json['summary'] as String,
    sections: sections
        .map((dynamic e) => _sectionFromJson(e as Map<String, dynamic>))
        .toList(),
  );
}

ContentSection _sectionFromJson(Map<String, dynamic> json) {
  final List<dynamic> blocks = json['blocks'] as List<dynamic>;
  return ContentSection(
    title: json['title'] as String,
    blocks: blocks
        .map((dynamic e) => _blockFromJson(e as Map<String, dynamic>))
        .toList(),
  );
}

ContentBlock _blockFromJson(Map<String, dynamic> json) {
  final String type = json['type'] as String;
  switch (type) {
    case 'paragraph':
      return ParagraphBlock(json['text'] as String);
    case 'bulletList':
      return BulletListBlock((json['items'] as List<dynamic>).cast<String>());
    case 'callout':
      return CalloutBlock(
        text: json['text'] as String,
        tone: _calloutToneFromWire(json['tone'] as String?),
      );
    case 'referenceLink':
      return ReferenceLinkBlock(
        label: json['label'] as String,
        url: json['url'] as String,
      );
    default:
      throw FormatException('Unknown content block type "$type"');
  }
}

CalloutTone _calloutToneFromWire(String? value) => switch (value) {
  'warning' => CalloutTone.warning,
  _ => CalloutTone.info,
};

QuizQuestion _quizQuestionFromJson(Map<String, dynamic> json) {
  final List<dynamic> options = json['options'] as List<dynamic>;
  return QuizQuestion(
    question: json['question'] as String,
    options: options
        .map(
          (dynamic e) => QuizOption(
            text: (e as Map<String, dynamic>)['text'] as String,
            explanation: e['explanation'] as String,
          ),
        )
        .toList(),
    correctIndex: json['correctIndex'] as int,
  );
}
