import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/router/routes.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/widgets.dart';
import '../../domain/entities/block.dart';
import '../../domain/entities/section.dart';
import '../../domain/entities/topic.dart';
import '../providers/education_providers.dart';
import '../widgets/block_renderer.dart';

/// One education module, rendered from its bundled JSON (FR-EDU-001…011).
/// [topicId] comes from the `:topic` path parameter.
class TopicScreen extends ConsumerWidget {
  const TopicScreen({required this.topicId, super.key});

  final String topicId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final String languageCode = context.locale.languageCode;
    final AsyncValue<List<Topic>> topics = ref.watch(
      topicsProvider(languageCode),
    );

    return AppScaffold(
      title: 'education.learn.title'.tr(),
      scrollable: true,
      body: topics.when(
        data: (List<Topic> list) {
          Topic? topic;
          for (final Topic candidate in list) {
            if (candidate.id == topicId) {
              topic = candidate;
              break;
            }
          }
          if (topic == null) {
            return EmptyState(title: 'education.topic.notFound'.tr());
          }
          return _TopicBody(topic: topic);
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (Object e, StackTrace _) =>
            ErrorView(failure: e is Failure ? e : UnknownFailure(e.toString())),
      ),
    );
  }
}

class _TopicBody extends StatelessWidget {
  const _TopicBody({required this.topic});

  final Topic topic;

  Future<void> _copyLink(BuildContext context, String url) async {
    await Clipboard.setData(ClipboardData(text: url));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('education.linkCopied'.tr())));
  }

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(topic.title, style: text.headlineMedium),
        const SizedBox(height: AppSpacing.sm),
        Text(topic.summary, style: text.bodyMedium),
        const SizedBox(height: AppSpacing.xl),
        for (final ContentSection section in topic.sections) ...<Widget>[
          Text(section.title, style: text.titleLarge),
          const SizedBox(height: AppSpacing.md),
          for (final ContentBlock block in section.blocks)
            BlockRenderer(
              block: block,
              onOpenLink: (String url) => _copyLink(context, url),
            ),
          const SizedBox(height: AppSpacing.lg),
        ],
        // FR-EDU-008 — the quiz reinforces the CHD basics module specifically.
        if (topic.id == 'chd-basics')
          AppButton(
            label: 'education.quiz.cta'.tr(),
            variant: AppButtonVariant.secondary,
            onPressed: () => context.goNamed(AppRoutes.quiz),
          ),
      ],
    );
  }
}
