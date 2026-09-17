import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/clinical/alert_evaluator.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/router/routes.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/widgets.dart';
import '../../domain/entities/symptom_check_in.dart';
import '../controllers/check_in_hub_controller.dart';

class CheckInHubScreen extends ConsumerWidget {
  const CheckInHubScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<SymptomCheckIn?> state = ref.watch(
      checkInHubControllerProvider,
    );
    final TextTheme text = Theme.of(context).textTheme;

    return AppScaffold.banded(
      showBack: false,
      scrollable: false,
      bandChild: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Text('symptoms.tabTitle'.tr(), style: text.headlineMedium),
          const SizedBox(height: AppSpacing.xs),
          Text('symptoms.tabSubtitle'.tr(), style: text.bodyMedium),
        ],
      ),
      body: state.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (Object error, StackTrace _) => ErrorView(
          failure: error is Failure ? error : UnknownFailure(error.toString()),
          onRetry: () =>
              ref.read(checkInHubControllerProvider.notifier).refresh(),
        ),
        data: (SymptomCheckIn? today) => ListView(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
          children: <Widget>[
            SectionCard(
              child: today == null
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          'symptoms.hub.notDoneTitle'.tr(),
                          style: text.titleMedium,
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          'symptoms.hub.notDoneBody'.tr(),
                          style: text.bodyMedium,
                        ),
                        const SizedBox(height: AppSpacing.md),
                        AppButton(
                          label: 'symptoms.hub.startCta'.tr(),
                          onPressed: () =>
                              context.pushNamed(AppRoutes.symptomCheckIn),
                        ),
                      ],
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: <Widget>[
                            Text(
                              'symptoms.hub.doneTitle'.tr(),
                              style: text.titleMedium,
                            ),
                            StatusChip(severity: today.overall),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          actionKeyFor(today.overall).tr(),
                          style: text.bodyMedium,
                        ),
                      ],
                    ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.gutter,
              ),
              child: AppButton(
                label: 'symptoms.hub.historyCta'.tr(),
                variant: AppButtonVariant.text,
                onPressed: () => context.pushNamed(AppRoutes.symptomHistory),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
