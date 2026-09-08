import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/router/routes.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/widgets.dart';
import '../../domain/entities/topic.dart';
import '../providers/education_providers.dart';
import '../widgets/topic_tile.dart';

/// The `learn` tab root (M5 spec §3) — every topic, always loaded, since
/// content is bundled at build time and needs no account and no network
/// (FR-EDU-009).
class LearnScreen extends ConsumerWidget {
  const LearnScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final String languageCode = context.locale.languageCode;
    final AsyncValue<List<Topic>> topics = ref.watch(
      topicsProvider(languageCode),
    );

    return AppScaffold(
      title: 'education.learn.title'.tr(),
      showBack: false,
      scrollable: true,
      body: topics.when(
        data: (List<Topic> list) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            for (final Topic topic in list)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: TopicTile(
                  topic: topic,
                  onTap: () => context.goNamed(
                    AppRoutes.learnTopic,
                    pathParameters: <String, String>{'topic': topic.id},
                  ),
                ),
              ),
          ],
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (Object e, StackTrace _) =>
            ErrorView(failure: e is Failure ? e : UnknownFailure(e.toString())),
      ),
    );
  }
}
