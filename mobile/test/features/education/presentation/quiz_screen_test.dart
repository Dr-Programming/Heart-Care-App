import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:libu_care/core/db/app_database.dart';
import 'package:libu_care/core/providers/core_providers.dart';
import 'package:libu_care/features/education/data/datasources/content_local_datasource.dart';
import 'package:libu_care/features/education/domain/entities/quiz_question.dart';
import 'package:libu_care/features/education/domain/entities/topic.dart';
import 'package:libu_care/features/education/presentation/providers/education_providers.dart';
import 'package:libu_care/features/education/presentation/screens/quiz_screen.dart';

import '../../../helpers/pump_app.dart';
import '../../../helpers/test_database.dart';

class _FakeContentLocalDatasource implements ContentLocalDatasource {
  const _FakeContentLocalDatasource(this.quiz);

  final List<QuizQuestion> quiz;

  @override
  Future<List<Topic>> loadTopics(String languageCode) async => const <Topic>[];

  @override
  Future<List<QuizQuestion>> loadQuiz(String languageCode) async => quiz;
}

const List<QuizQuestion> _quiz = <QuizQuestion>[
  QuizQuestion(
    question: 'What does CHD stand for?',
    options: <QuizOption>[
      QuizOption(
        text: 'Coronary heart disease',
        explanation: "Correct — CHD narrows the heart's own arteries.",
      ),
      QuizOption(
        text: 'Chronic hypertension disorder',
        explanation: "This isn't a recognised term for CHD.",
      ),
    ],
    correctIndex: 0,
  ),
  QuizQuestion(
    question: 'Is chest pain always a heart attack?',
    options: <QuizOption>[
      QuizOption(text: 'Yes', explanation: 'Not always — but never ignore it.'),
      QuizOption(
        text: 'No',
        explanation: 'Correct — but any chest pain deserves attention.',
      ),
    ],
    correctIndex: 1,
  ),
];

void main() {
  setUpWidgetTests();

  late AppDatabase db;

  setUp(() => db = testDatabase());
  tearDown(() => db.close());

  List<Override> overrides({List<QuizQuestion> quiz = _quiz}) => <Override>[
    contentLocalDatasourceProvider.overrideWithValue(
      _FakeContentLocalDatasource(quiz),
    ),
    appDatabaseProvider.overrideWithValue(db),
    onlineStatusProvider.overrideWith((Ref ref) => Stream<bool>.value(true)),
  ];

  testWidgets('shows the first question with no explanation yet', (
    WidgetTester tester,
  ) async {
    await pumpApp(tester, const QuizScreen(), overrides: overrides());

    expect(find.text('What does CHD stand for?'), findsOneWidget);
    expect(
      find.text("Correct — CHD narrows the heart's own arteries."),
      findsNothing,
    );
  });

  testWidgets('selecting an answer reveals the explanation for every option', (
    WidgetTester tester,
  ) async {
    await pumpApp(tester, const QuizScreen(), overrides: overrides());

    await tester.tap(find.text('Chronic hypertension disorder'));
    await tester.pumpAndSettle();

    expect(
      find.text("Correct — CHD narrows the heart's own arteries."),
      findsOneWidget,
    );
    expect(find.text("This isn't a recognised term for CHD."), findsOneWidget);
  });

  testWidgets('advancing moves to the next question', (
    WidgetTester tester,
  ) async {
    await pumpApp(tester, const QuizScreen(), overrides: overrides());

    await tester.tap(find.text('Coronary heart disease'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();

    expect(find.text('Is chest pain always a heart attack?'), findsOneWidget);
  });

  testWidgets(
    'finishing the last question shows the finished view, and retake restarts it',
    (WidgetTester tester) async {
      await pumpApp(tester, const QuizScreen(), overrides: overrides());

      await tester.tap(find.text('Coronary heart disease'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('No'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Finish'));
      await tester.pumpAndSettle();

      expect(find.text('Nicely done!'), findsOneWidget);

      await tester.tap(find.text('Retake the quiz'));
      await tester.pumpAndSettle();

      expect(find.text('What does CHD stand for?'), findsOneWidget);
    },
  );
}
