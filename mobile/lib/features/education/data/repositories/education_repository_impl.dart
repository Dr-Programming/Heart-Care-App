import '../../domain/entities/quiz.dart';
import '../../domain/entities/topic.dart';
import '../../domain/repositories/education_repository.dart';
import '../datasources/content_local_datasource.dart';

class EducationRepositoryImpl implements EducationRepository {
  EducationRepositoryImpl(this._local);

  final ContentLocalDataSource _local;

  final Map<String, List<Topic>> _topicsCache = <String, List<Topic>>{};
  final Map<String, List<Quiz>> _quizzesCache = <String, List<Quiz>>{};

  @override
  Future<List<Topic>> topics(String languageCode) async {
    return _topicsCache[languageCode] ??= await _local.loadTopics(
      languageCode,
    );
  }

  @override
  Future<Topic?> topicById(String id, String languageCode) async {
    final List<Topic> all = await topics(languageCode);
    for (final Topic t in all) {
      if (t.id == id) return t;
    }
    return null;
  }

  @override
  Future<Quiz?> quizForTopic(String topicId, String languageCode) async {
    final List<Quiz> all =
        _quizzesCache[languageCode] ??= await _local.loadQuizzes(languageCode);
    for (final Quiz q in all) {
      if (q.topicId == topicId) return q;
    }
    return null;
  }
}
