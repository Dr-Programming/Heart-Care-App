import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'data/datasources/content_local_datasource.dart';
import 'data/repositories/education_repository_impl.dart';
import 'domain/entities/quiz.dart';
import 'domain/entities/topic.dart';
import 'domain/repositories/education_repository.dart';

final Provider<ContentLocalDataSource> contentLocalDataSourceProvider =
    Provider<ContentLocalDataSource>((Ref ref) => const ContentLocalDataSource());

final Provider<EducationRepository> educationRepositoryProvider =
    Provider<EducationRepository>(
      (Ref ref) =>
          EducationRepositoryImpl(ref.watch(contentLocalDataSourceProvider)),
    );

final topicsProvider = FutureProvider.family<List<Topic>, String>(
  (Ref ref, String languageCode) =>
      ref.watch(educationRepositoryProvider).topics(languageCode),
);

final topicByIdProvider = FutureProvider.family<Topic?, (String, String)>(
  (Ref ref, (String, String) args) =>
      ref.watch(educationRepositoryProvider).topicById(args.$1, args.$2),
);

final quizForTopicProvider = FutureProvider.family<Quiz?, (String, String)>(
  (Ref ref, (String, String) args) =>
      ref.watch(educationRepositoryProvider).quizForTopic(args.$1, args.$2),
);
