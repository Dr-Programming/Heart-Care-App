import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:libu_care/core/db/app_database.dart';
import 'package:libu_care/core/providers/core_providers.dart';
import 'package:libu_care/features/education/data/datasources/content_local_datasource.dart';
import 'package:libu_care/features/education/domain/entities/quiz_question.dart';
import 'package:libu_care/features/education/domain/entities/section.dart';
import 'package:libu_care/features/education/domain/entities/topic.dart';
import 'package:libu_care/features/education/presentation/providers/education_providers.dart';
import 'package:libu_care/features/education/presentation/screens/learn_screen.dart';

import '../../../helpers/pump_app.dart';
import '../../../helpers/test_database.dart';

class _FakeContentLocalDatasource implements ContentLocalDatasource {
  const _FakeContentLocalDatasource({
    this.topics = const <Topic>[],
    this.quiz = const <QuizQuestion>[],
  });

  final List<Topic> topics;
  final List<QuizQuestion> quiz;

  @override
  Future<List<Topic>> loadTopics(String languageCode) async => topics;

  @override
  Future<List<QuizQuestion>> loadQuiz(String languageCode) async => quiz;
}

const List<Topic> _topics = <Topic>[
  Topic(
    id: 'chd-basics',
    title: 'Understanding CHD',
    summary: 'What coronary heart disease is.',
    sections: <ContentSection>[],
  ),
  Topic(
    id: 'diet',
    title: 'Eating for your heart',
    summary: 'Whole-teff injera, shiro and more.',
    sections: <ContentSection>[],
  ),
];

void main() {
  setUpWidgetTests();

  late AppDatabase db;

  setUp(() => db = testDatabase());
  tearDown(() => db.close());

  // AppScaffold pulls in OfflineBanner, which watches the real
  // appDatabaseProvider/onlineStatusProvider — every screen test needs
  // these overridden, same as core/shell/home_screen_test.dart.
  List<Override> overrides({
    List<Topic> topics = _topics,
    List<QuizQuestion> quiz = const <QuizQuestion>[],
  }) => <Override>[
    contentLocalDatasourceProvider.overrideWithValue(
      _FakeContentLocalDatasource(topics: topics, quiz: quiz),
    ),
    appDatabaseProvider.overrideWithValue(db),
    onlineStatusProvider.overrideWith((Ref ref) => Stream<bool>.value(true)),
  ];

  testWidgets('lists every topic with its summary', (
    WidgetTester tester,
  ) async {
    await pumpApp(tester, const LearnScreen(), overrides: overrides());

    expect(find.text('Understanding CHD'), findsOneWidget);
    expect(find.text('What coronary heart disease is.'), findsOneWidget);
    expect(find.text('Eating for your heart'), findsOneWidget);
    expect(find.text('Whole-teff injera, shiro and more.'), findsOneWidget);
  });
}
