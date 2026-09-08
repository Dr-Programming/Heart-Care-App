import 'section.dart';

/// One education module (FR-EDU-001…011): `chd-basics`, `symptoms`,
/// `heart-attack`, `diet`, `exercise`, `medication-adherence`,
/// `psychosocial`. Bundled at build time, no server, no download — it has
/// to work before the patient even has an account.
class Topic {
  const Topic({
    required this.id,
    required this.title,
    required this.summary,
    required this.sections,
  });

  /// Stable identifier, e.g. `chd-basics` — also the `:topic` route
  /// parameter (`AppRoutes.learnTopic`).
  final String id;

  final String title;

  /// The one-line summary shown on the Learn list (M5 spec §3).
  final String summary;

  final List<ContentSection> sections;
}
