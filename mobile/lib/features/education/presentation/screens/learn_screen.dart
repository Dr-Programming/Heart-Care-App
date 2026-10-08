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
import '../widgets/topic_tile.dart';

class LearnScreen extends ConsumerWidget {
  const LearnScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final String languageCode = context.locale.languageCode;
    final AsyncValue<List<Topic>> state = ref.watch(
      topicsProvider(languageCode),
    );

    final TextTheme text = Theme.of(context).textTheme;

    return AppScaffold.banded(
      showBack: false,
      scrollable: false,
      bandChild: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Text('education.tabTitle'.tr(), style: text.headlineMedium),
          const SizedBox(height: AppSpacing.xs),
          Text('education.tabSubtitle'.tr(), style: text.bodyMedium),
        ],
      ),
      body: state.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (Object error, StackTrace _) => ErrorView(
          failure: error is Failure ? error : UnknownFailure(error.toString()),
          onRetry: () => ref.invalidate(topicsProvider(languageCode)),
        ),
        data: (List<Topic> topics) => topics.isEmpty
            ? EmptyState(title: 'education.topicsEmpty'.tr())
            : ListView(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
                children: <Widget>[
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.md),
                    child: SectionCard(
                      onTap: () => context.pushNamed(AppRoutes.eatWell),
                      child: Row(
                        children: <Widget>[
                          Container(
                            width: 44,
                            height: 44,
                            alignment: Alignment.center,
                            decoration: const BoxDecoration(
                              color: AppColors.successBg,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.restaurant_outlined,
                              size: 22,
                              color: AppColors.success,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(
                                  'education.eatWell.cardTitle'.tr(),
                                  style: text.titleMedium,
                                ),
                                const SizedBox(height: AppSpacing.xs),
                                Text(
                                  'education.eatWell.cardBody'.tr(),
                                  style: text.bodySmall,
                                ),
                              ],
                            ),
                          ),
                          const Icon(Icons.chevron_right_rounded),
                        ],
                      ),
                    ),
                  ),
                  for (final Topic topic in topics)
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.md),
                      child: TopicTile(
                        topic: topic,
                        onTap: () => context.pushNamed(
                          AppRoutes.learnTopic,
                          pathParameters: <String, String>{'topic': topic.id},
                        ),
                      ),
                    ),
                ],
              ),
      ),
    );
  }
}
