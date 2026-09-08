/// The four content shapes a topic section is built from (design decision
/// 5) — one renderer (`BlockRenderer`) handles all of them, so authoring a
/// new topic never needs a new widget. Reference links only, deliberately:
/// no embedded video, both because it is right for metered data and because
/// FR-EDU says so explicitly.
sealed class ContentBlock {
  const ContentBlock();
}

class ParagraphBlock extends ContentBlock {
  const ParagraphBlock(this.text);

  final String text;
}

class BulletListBlock extends ContentBlock {
  const BulletListBlock(this.items);

  final List<String> items;
}

/// A tone, not a severity — this is educational content, not a clinical
/// assessment. [warning] is for safety-critical guidance (e.g. heart attack
/// warning signs); it must never be used to imply a diagnosis.
enum CalloutTone { info, warning }

class CalloutBlock extends ContentBlock {
  const CalloutBlock({required this.text, this.tone = CalloutTone.info});

  final String text;
  final CalloutTone tone;
}

class ReferenceLinkBlock extends ContentBlock {
  const ReferenceLinkBlock({required this.label, required this.url});

  final String label;
  final String url;
}
