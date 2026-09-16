import '../entities/quiz.dart';
import '../entities/topic.dart';

abstract interface class EducationRepository {
  Future<List<Topic>> topics(String languageCode);
  Future<Topic?> topicById(String id, String languageCode);
  Future<Quiz?> quizForTopic(String topicId, String languageCode);
}
