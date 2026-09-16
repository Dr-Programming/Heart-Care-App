import 'package:flutter/widgets.dart';
import 'package:iconsax/iconsax.dart';

import 'content_block.dart';

class TopicSection {
  const TopicSection({required this.title, required this.blocks});

  factory TopicSection.fromJson(Map<String, dynamic> json) => TopicSection(
    title: json['title'] as String,
    blocks: (json['blocks'] as List<dynamic>)
        .map(
          (dynamic e) =>
              ContentBlock.fromJson((e as Map<Object?, Object?>).cast()),
        )
        .toList(),
  );

  final String title;
  final List<ContentBlock> blocks;
}

const Map<String, IconData> _topicIcons = <String, IconData>{
  'chd-basics': Iconsax.heart,
  'symptoms': Iconsax.warning_2,
  'heart-attack': Iconsax.flash_1,
  'diet': Iconsax.reserve,
  'exercise': Iconsax.activity,
  'medication-adherence': Iconsax.calendar_tick,
  'psychosocial': Iconsax.emoji_happy,
};

class Topic {
  const Topic({
    required this.id,
    required this.title,
    required this.summary,
    required this.icon,
    required this.sections,
  });

  factory Topic.fromJson(Map<String, dynamic> json) {
    final String id = json['id'] as String;
    return Topic(
      id: id,
      title: json['title'] as String,
      summary: json['summary'] as String,
      icon: _topicIcons[id] ?? Iconsax.book_1,
      sections: (json['sections'] as List<dynamic>)
          .map(
            (dynamic e) =>
                TopicSection.fromJson((e as Map<Object?, Object?>).cast()),
          )
          .toList(),
    );
  }

  final String id;
  final String title;
  final String summary;
  final IconData icon;
  final List<TopicSection> sections;
}
