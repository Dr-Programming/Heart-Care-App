import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/widgets.dart';
import '../../domain/entities/topic.dart';

/// One row on the Learn list: icon, title and one-line summary (M5 spec §3).
class TopicTile extends StatelessWidget {
  const TopicTile({required this.topic, required this.onTap, super.key});

  final Topic topic;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    return SectionCard(
      onTap: onTap,
      child: Row(
        children: <Widget>[
          Icon(_iconFor(topic.id), size: 28, color: AppColors.accent),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(topic.title, style: text.titleMedium),
                const SizedBox(height: AppSpacing.xs),
                Text(topic.summary, style: text.bodySmall),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          const Icon(Icons.chevron_right_rounded, size: 20),
        ],
      ),
    );
  }
}

/// A fixed mapping for the seven known topic ids (M5 spec §5); an id outside
/// that set still renders — just with a generic icon — rather than crash.
IconData _iconFor(String topicId) => switch (topicId) {
  'chd-basics' => Icons.favorite_border_rounded,
  'symptoms' => Icons.monitor_heart_outlined,
  'heart-attack' => Icons.emergency_outlined,
  'diet' => Icons.restaurant_outlined,
  'exercise' => Icons.directions_walk_rounded,
  'medication-adherence' => Icons.medication_outlined,
  'psychosocial' => Icons.self_improvement_outlined,
  _ => Icons.menu_book_outlined,
};
