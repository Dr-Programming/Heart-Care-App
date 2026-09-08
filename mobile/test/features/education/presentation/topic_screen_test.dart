import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:libu_care/core/db/app_database.dart';
import 'package:libu_care/core/providers/core_providers.dart';
import 'package:libu_care/features/education/data/datasources/content_local_datasource.dart';
import 'package:libu_care/features/education/domain/entities/block.dart';
import 'package:libu_care/features/education/domain/entities/quiz_question.dart';
import 'package:libu_care/features/education/domain/entities/section.dart';
import 'package:libu_care/features/education/domain/entities/topic.dart';
import 'package:libu_care/features/education/presentation/providers/education_providers.dart';
import 'package:libu_care/features/education/presentation/screens/topic_screen.dart';

import '../../../helpers/pump_app.dart';
import '../../../helpers/test_database.dart';

class _FakeContentLocalDatasource implements ContentLocalDatasource {
  const _FakeContentLocalDatasource(this.topics);

  final List<Topic> topics;

  @override
  Future<List<Topic>> loadTopics(String languageCode) async => topics;

  @override
  Future<List<QuizQuestion>> loadQuiz(String languageCode) async =>
      const <QuizQuestion>[];
}

const Topic _chdBasics = Topic(
  id: 'chd-basics',
  title: 'Understanding CHD',
  summary: 'What coronary heart disease is.',
  sections: <ContentSection>[
    ContentSection(
      title: 'What is CHD?',
      blocks: <ContentBlock>[
        ParagraphBlock('CHD narrows the arteries that feed your heart.'),
      ],
    ),
  ],
);

const Topic _diet = Topic(
  id: 'diet',
  title: 'Eating for your heart',
  summary: 'Whole-teff injera, shiro and more.',
  sections: <ContentSection>[],
);

void main() {
  setUpWidgetTests();

  late AppDatabase db;

  setUp(() => db = testDatabase());
  tearDown(() => db.close());

  List<Override> overrides(List<Topic> topics) => <Override>[
    contentLocalDatasourceProvider.overrideWithValue(
      _FakeContentLocalDatasource(topics),
    ),
    appDatabaseProvider.overrideWithValue(db),
    onlineStatusProvider.overrideWith((Ref ref) => Stream<bool>.value(true)),
  ];

  testWidgets('renders the topic title, summary and section content', (
    WidgetTester tester,
  ) async {
    await pumpApp(
      tester,
      const TopicScreen(topicId: 'chd-basics'),
      overrides: overrides(const <Topic>[_chdBasics, _diet]),
    );

    expect(find.text('Understanding CHD'), findsOneWidget);
    expect(find.text('What is CHD?'), findsOneWidget);
    expect(
      find.text('CHD narrows the arteries that feed your heart.'),
      findsOneWidget,
    );
  });

  testWidgets('shows the quiz entry point only on the CHD basics module', (
    WidgetTester tester,
  ) async {
    await pumpApp(
      tester,
      const TopicScreen(topicId: 'chd-basics'),
      overrides: overrides(const <Topic>[_chdBasics, _diet]),
    );
    expect(find.text('Take the quiz'), findsOneWidget);
  });

  testWidgets('the diet module has no quiz entry point', (
    WidgetTester tester,
  ) async {
    await pumpApp(
      tester,
      const TopicScreen(topicId: 'diet'),
      overrides: overrides(const <Topic>[_chdBasics, _diet]),
    );
    expect(find.text('Take the quiz'), findsNothing);
  });

  testWidgets('an unknown topic id shows "not found" rather than crashing', (
    WidgetTester tester,
  ) async {
    await pumpApp(
      tester,
      const TopicScreen(topicId: 'does-not-exist'),
      overrides: overrides(const <Topic>[_chdBasics, _diet]),
    );

    expect(find.text('Topic not found'), findsOneWidget);
  });
}
