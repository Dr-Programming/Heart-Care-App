/// The recovery questions a patient can choose from. Mirrors the backend's
/// `SecurityQuestion` enum: the server only knows the [id]s; the question text
/// lives in the translation files under `auth.securityQuestions.items.<id>`.
///
/// Never rename or remove an [id]: stored answers reference them.
enum SecurityQuestion {
  firstSchool('FIRST_SCHOOL'),
  childhoodFriend('CHILDHOOD_FRIEND'),
  favoriteTeacher('FAVORITE_TEACHER'),
  childhoodStreet('CHILDHOOD_STREET'),
  firstJobPlace('FIRST_JOB_PLACE'),
  favoriteChildhoodFood('FAVORITE_CHILDHOOD_FOOD'),
  firstPhoneBrand('FIRST_PHONE_BRAND'),
  childhoodHero('CHILDHOOD_HERO');

  const SecurityQuestion(this.id);

  /// The server's identifier.
  final String id;

  /// Translation key for the question text.
  String get labelKey => 'auth.securityQuestions.items.$id';

  /// The question for a server [id], or null for an ID this build doesn't know.
  static SecurityQuestion? fromId(String id) {
    for (final SecurityQuestion question in values) {
      if (question.id == id) return question;
    }
    return null;
  }
}

/// One question and the patient's answer, as typed.
class SecurityAnswer {
  const SecurityAnswer(this.question, this.answer);

  final SecurityQuestion question;
  final String answer;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'questionId': question.id,
    'answer': answer,
  };

  static SecurityAnswer? fromJson(Map<String, dynamic> json) {
    final SecurityQuestion? question = SecurityQuestion.fromId(
      json['questionId'] as String? ?? '',
    );
    final Object? answer = json['answer'];
    if (question == null || answer is! String) return null;
    return SecurityAnswer(question, answer);
  }

  @override
  bool operator ==(Object other) =>
      other is SecurityAnswer &&
      other.question == question &&
      other.answer == answer;

  @override
  int get hashCode => Object.hash(question, answer);
}
