import 'block.dart';

/// One section of a topic — a heading plus the blocks under it.
class ContentSection {
  const ContentSection({required this.title, required this.blocks});

  final String title;
  final List<ContentBlock> blocks;
}
