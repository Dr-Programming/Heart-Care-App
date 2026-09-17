import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/router/routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/widgets.dart';
import '../../domain/entities/topic.dart';
import '../../education_providers.dart';
import '../widgets/block_renderer.dart';
import '../widgets/topic_tile.dart';

class TopicScreen extends ConsumerWidget {
  const TopicScreen({required this.topicId, super.key});

  final String topicId;

  static String topicIdFromRoute(GoRouterState state) =>
      state.pathParameters['topic']!;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final String languageCode = context.locale.languageCode;
    final AsyncValue<Topic?> state = ref.watch(
      topicByIdProvider((topicId, languageCode)),
    );

    return AppScaffold(
      backgroundColor: AppColors.surfaceAlt,
      body: state.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (Object error, StackTrace _) => ErrorView(
          failure: error is Failure ? error : UnknownFailure(error.toString()),
          onRetry: () =>
              ref.invalidate(topicByIdProvider((topicId, languageCode))),
        ),
        data: (Topic? topic) => topic == null
            ? EmptyState(title: 'education.topicsEmpty'.tr())
            : _TopicBody(topic: topic),
      ),
    );
  }
}

class _TopicBody extends StatelessWidget {
  const _TopicBody({required this.topic});

  final Topic topic;

  @override
  Widget build(BuildContext context) {
    final Color accent = topicAccentColor(topic.id);
    final TextTheme text = Theme.of(context).textTheme;

    return ListView(
      padding: const EdgeInsets.only(
        top: AppSpacing.lg,
        bottom: AppSpacing.xxl,
      ),
      children: <Widget>[
        Row(
          children: <Widget>[
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(topic.icon, color: accent, size: 24),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(child: Text(topic.title, style: text.headlineMedium)),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        for (int i = 0; i < topic.sections.length; i++)
          _SectionCard(
            section: topic.sections[i],
            accent: accent,
            isLast: i == topic.sections.length - 1,
          ),
        const SizedBox(height: AppSpacing.sm),
        AppButton(
          label: 'education.quiz.cta'.tr(),
          onPressed: () => context.pushNamed(
            AppRoutes.quiz,
            queryParameters: <String, String>{'topic': topic.id},
          ),
        ),
      ],
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.section,
    required this.accent,
    required this.isLast,
  });

  final TopicSection section;
  final Color accent;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;

    return Container(
      margin: EdgeInsets.only(bottom: isLast ? AppSpacing.lg : AppSpacing.md),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.lg),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(section.title, style: text.titleLarge),
          const SizedBox(height: AppSpacing.sm),
          Container(
            width: 36,
            height: 3,
            decoration: BoxDecoration(
              color: accent,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          for (final block in section.blocks)
            BlockRenderer(block: block, accent: accent),
        ],
      ),
    );
  }
}
