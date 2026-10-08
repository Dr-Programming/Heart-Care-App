import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/widgets.dart';
import '../../domain/entities/activity_entry.dart';
import '../controllers/activity_form_controller.dart';

class ActivityFormScreen extends ConsumerWidget {
  const ActivityFormScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ActivityFormState state = ref.watch(activityFormControllerProvider);
    final ActivityFormController controller = ref.read(
      activityFormControllerProvider.notifier,
    );
    final TextTheme text = Theme.of(context).textTheme;

    return UnsavedChangesGuard(
      dirty: state.isDirty,
      child: AppScaffold.banded(
        showBack: false,
        bandChild: BandHeader(
          title: 'activity.form.title'.tr(),
          subtitle: 'activity.form.subtitle'.tr(),
        ),
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            const SizedBox(height: AppSpacing.xl),
            Text('activity.form.type'.tr(), style: text.titleMedium),
            const SizedBox(height: AppSpacing.sm),
            PillChoice(
              wrap: true,
              value: state.type.wire,
              onChanged: (String v) =>
                  controller.setType(ActivityType.fromWire(v)),
              options: <(String, String)>[
                for (final ActivityType t in ActivityType.values)
                  (t.wire, 'activity.type.${t.wire}'.tr()),
              ],
            ),
            const SizedBox(height: AppSpacing.xl),
            Text('activity.form.intensity'.tr(), style: text.titleMedium),
            const SizedBox(height: AppSpacing.sm),
            PillChoice(
              value: state.intensity.wire,
              onChanged: (String v) =>
                  controller.setIntensity(Intensity.fromWire(v)),
              options: <(String, String)>[
                for (final Intensity i in Intensity.values)
                  (i.wire, 'activity.intensity.${i.wire}'.tr()),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'activity.intensityHint.${state.intensity.wire}'.tr(),
              style: text.bodySmall,
            ),
            const SizedBox(height: AppSpacing.xl),
            AppTextField(
              label: 'activity.form.duration'.tr(),
              hint: '30',
              keyboardType: TextInputType.number,
              inputFormatters: <TextInputFormatter>[
                FilteringTextInputFormatter.digitsOnly,
              ],
              errorText: state.durationError?.tr(),
              onChanged: controller.setDuration,
            ),
            const SizedBox(height: AppSpacing.lg),
            AppTextField(
              label: 'activity.form.steps'.tr(),
              keyboardType: TextInputType.number,
              inputFormatters: <TextInputFormatter>[
                FilteringTextInputFormatter.digitsOnly,
              ],
              errorText: state.stepsError?.tr(),
              onChanged: controller.setSteps,
            ),
            const SizedBox(height: AppSpacing.lg),
            AppTextField(
              label: 'activity.form.note'.tr(),
              maxLines: 3,
              errorText: state.noteError?.tr(),
              onChanged: controller.setNote,
            ),
            const SizedBox(height: AppSpacing.md),
            Text('activity.form.safety'.tr(), style: text.bodySmall),
            const SizedBox(height: AppSpacing.xl),
            AppButton(
              label: 'activity.form.save'.tr(),
              isLoading: state.isSaving,
              onPressed: () async {
                final bool saved = await controller.save();
                if (saved && context.mounted) {
                  showAppToast(context, 'activity.form.saved'.tr());
                  Navigator.of(context).pop();
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}
