import 'package:flutter_test/flutter_test.dart';
import 'package:libu_care/features/education/data/datasources/content_local_datasource.dart';
import 'package:libu_care/features/education/domain/entities/block.dart';
import 'package:libu_care/features/education/domain/entities/quiz_question.dart';
import 'package:libu_care/features/education/domain/entities/topic.dart';

void main() {
  group('parseTopics', () {
    test('parses a topic with every block type', () {
      const String raw = '''
      [
        {
          "id": "chd-basics",
          "title": "Understanding CHD",
          "summary": "What coronary heart disease is and why it matters.",
          "sections": [
            {
              "title": "What is CHD?",
              "blocks": [
                { "type": "paragraph", "text": "CHD narrows the arteries that feed your heart." },
                { "type": "bulletList", "items": ["Chest pain", "Shortness of breath"] },
                { "type": "callout", "tone": "warning", "text": "Seek help for sudden chest pain." },
                { "type": "referenceLink", "label": "World Heart Federation", "url": "https://world-heart-federation.org" }
              ]
            }
          ]
        }
      ]
      ''';

      final List<Topic> topics = parseTopics(raw);

      expect(topics, hasLength(1));
      final Topic topic = topics.single;
      expect(topic.id, 'chd-basics');
      expect(topic.title, 'Understanding CHD');
      expect(topic.sections, hasLength(1));

      final List<ContentBlock> blocks = topic.sections.single.blocks;
      expect(blocks, hasLength(4));
      expect(
        (blocks[0] as ParagraphBlock).text,
        'CHD narrows the arteries that feed your heart.',
      );
      expect((blocks[1] as BulletListBlock).items, <String>[
        'Chest pain',
        'Shortness of breath',
      ]);
      final CalloutBlock callout = blocks[2] as CalloutBlock;
      expect(callout.tone, CalloutTone.warning);
      expect(callout.text, 'Seek help for sudden chest pain.');
      final ReferenceLinkBlock link = blocks[3] as ReferenceLinkBlock;
      expect(link.label, 'World Heart Federation');
      expect(link.url, 'https://world-heart-federation.org');
    });

    test('a callout with no tone defaults to info', () {
      const String raw = '''
      [{
        "id": "t",
        "title": "T",
        "summary": "S",
        "sections": [{
          "title": "S",
          "blocks": [{ "type": "callout", "text": "Note this." }]
        }]
      }]
      ''';

      final List<Topic> topics = parseTopics(raw);

      final CalloutBlock callout =
          topics.single.sections.single.blocks.single as CalloutBlock;
      expect(callout.tone, CalloutTone.info);
    });

    test('parses multiple topics in order', () {
      const String raw = '''
      [
        { "id": "a", "title": "A", "summary": "S", "sections": [] },
        { "id": "b", "title": "B", "summary": "S", "sections": [] }
      ]
      ''';

      final List<Topic> topics = parseTopics(raw);

      expect(topics.map((Topic t) => t.id), <String>['a', 'b']);
    });

    test(
      'an unknown block type throws, rather than silently dropping content',
      () {
        const String raw = '''
      [{
        "id": "t",
        "title": "T",
        "summary": "S",
        "sections": [{
          "title": "S",
          "blocks": [{ "type": "video", "url": "https://example.com" }]
        }]
      }]
      ''';

        expect(() => parseTopics(raw), throwsFormatException);
      },
    );
  });

  group('parseQuiz', () {
    test('parses a question with its options and correct index', () {
      const String raw = '''
      [
        {
          "question": "What does CHD stand for?",
          "options": [
            { "text": "Coronary heart disease", "explanation": "Correct — CHD narrows the heart's own arteries." },
            { "text": "Chronic hypertension disorder", "explanation": "This isn't a recognised term for CHD." }
          ],
          "correctIndex": 0
        }
      ]
      ''';

      final List<QuizQuestion> quiz = parseQuiz(raw);

      expect(quiz, hasLength(1));
      final QuizQuestion q = quiz.single;
      expect(q.question, 'What does CHD stand for?');
      expect(q.options, hasLength(2));
      expect(q.correctIndex, 0);
      expect(q.options[0].explanation, isNotEmpty);
      expect(q.options[1].explanation, isNotEmpty);
    });

    test('parses multiple questions', () {
      const String raw = '''
      [
        { "question": "Q1", "options": [{ "text": "A", "explanation": "E" }], "correctIndex": 0 },
        { "question": "Q2", "options": [{ "text": "A", "explanation": "E" }], "correctIndex": 0 }
      ]
      ''';

      final List<QuizQuestion> quiz = parseQuiz(raw);

      expect(quiz.map((QuizQuestion q) => q.question), <String>['Q1', 'Q2']);
    });
  });
}
