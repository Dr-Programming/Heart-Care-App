import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/clinical/activity_guidance.dart';
import '../../../../core/clinical/alert_evaluator.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/router/routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/widgets.dart';
import '../../domain/entities/symptom_check_in.dart';
import '../controllers/check_in_hub_controller.dart';
import '../widgets/activity_guidance_card.dart';

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
            if (today == null) ...<Widget>[
              const _CheckInFirstTip(),
              const SizedBox(height: AppSpacing.lg),
            ],
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
            if (today != null) ...<Widget>[
              const SizedBox(height: AppSpacing.lg),
              ActivityGuidanceCard(
                guidance: activityGuidanceFor(
                  overall: today.overall,
                  perSymptom: today.perSymptom,
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.lg),
            SectionCard(
              onTap: () => context.pushNamed(AppRoutes.activity),
              child: Row(
                children: <Widget>[
                  const IconCircle(
                    icon: Icons.directions_run_rounded,
                    color: AppColors.success,
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          'symptoms.hub.activityTitle'.tr(),
                          style: text.titleMedium,
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          'symptoms.hub.activityBody'.tr(),
                          style: text.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            const HealthyExercisesLink(),
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

/// Shown until today's check-in is done: check in first, then exercise.
class _CheckInFirstTip extends StatelessWidget {
  const _CheckInFirstTip();

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('checkInFirstTip'),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.accentBg,
        borderRadius: BorderRadius.circular(AppSpacing.md),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Icon(Icons.lightbulb_outline, color: AppColors.accent),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              'symptoms.hub.checkInFirstTip'.tr(),
              style: Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(color: AppColors.ink),
            ),
          ),
        ],
      ),
    );
  }
}
