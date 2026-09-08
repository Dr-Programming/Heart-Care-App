import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../data/datasources/content_local_datasource.dart';
import '../../domain/entities/quiz_question.dart';
import '../../domain/entities/topic.dart';

part 'education_providers.g.dart';

@riverpod
ContentLocalDatasource contentLocalDatasource(Ref ref) =>
    const ContentLocalDatasource();

/// [languageCode] comes from `context.locale.languageCode` at the call
/// site — content has no reactive "current language" of its own, easy_
/// localization already is one.
///
/// **Needs `assets/content/` declared in `pubspec.yaml` to resolve** — see
/// `ContentLocalDatasource.loadTopics`. Until then this throws, which
/// `topics.when(error: ...)` on the Learn screen renders as an `ErrorView`
/// rather than crashing the app.
@riverpod
Future<List<Topic>> topics(Ref ref, String languageCode) {
  return ref.watch(contentLocalDatasourceProvider).loadTopics(languageCode);
}

/// Same blocker as [topics] — needs `assets/content/` in `pubspec.yaml`.
@riverpod
Future<List<QuizQuestion>> quizQuestions(Ref ref, String languageCode) {
  return ref.watch(contentLocalDatasourceProvider).loadQuiz(languageCode);
}
