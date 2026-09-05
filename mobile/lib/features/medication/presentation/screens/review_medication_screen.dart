import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax/iconsax.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/widgets.dart';
import '../../data/caregiver_notify_store.dart';
import '../../data/medication_instructions_store.dart';
import '../../domain/entities/medication.dart';
import '../controllers/medication_form_controller.dart';

class ReviewMedicationScreen extends ConsumerWidget {
  const ReviewMedicationScreen({
    required this.notifyCaregiverEnabled,
    this.caregiverPhone = '',
    this.instructions,
    super.key,
  });

  final bool notifyCaregiverEnabled;

  final String caregiverPhone;

  final MedicationInstructions? instructions;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final MedicationFormState state = ref.watch(medicationFormControllerProvider);
    final MedicationFormController controller =
        ref.read(medicationFormControllerProvider.notifier);

    final bool isAsNeeded =
        state.frequency == MedicationFrequency.custom && state.scheduleTimes.isEmpty;

    final MedicationInstructions instructionsValue = instructions ?? MedicationInstructions.none;

    ref.listen<MedicationFormState>(medicationFormControllerProvider, (
      MedicationFormState? previous,
      MedicationFormState next,
    ) {
      if (next.saved && (previous == null || !previous.saved) && context.mounted) {

        final NavigatorState navigator = Navigator.of(context);
        if (next.reminderSchedulingFailed) {

          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(
              SnackBar(
                content: Text('meds.review.reminderSchedulingFailed'.tr()),
                duration: const Duration(seconds: 3),
              ),
            );
          Future<void>.delayed(const Duration(milliseconds: 1200), () {
            if (!context.mounted) return;
            if (navigator.canPop()) navigator.pop();
            if (navigator.canPop()) navigator.pop();
          });
          return;
        }
        if (navigator.canPop()) navigator.pop();
        if (navigator.canPop()) navigator.pop();
      }
    });

    return AppScaffold.banded(

      showBack: false,

      bandHeight: 130,
      scrollable: true,
      bandChild: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          IconButton(
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            icon: const Icon(Icons.arrow_back, color: AppColors.ink),
            onPressed: () => Navigator.of(context).pop(),
          ),
          const SizedBox(height: AppSpacing.xs),

          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              'meds.review.title'.tr(),
              style: Theme.of(context).textTheme.headlineLarge?.copyWith(fontSize: 28),
            ),
          ),
          const SizedBox(height: AppSpacing.xs),

          Text(
            'meds.review.subtitle'.tr(),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.ink),
          ),
        ],
      ),

      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const SizedBox(height: AppSpacing.xl),
          SectionCard(
            title: state.name,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                _SummaryRow(label: 'meds.form.doseMg'.tr(), value: '${state.doseMg} mg'),
                _SummaryRow(
                  label: 'meds.review.frequency'.tr(),
                  value: isAsNeeded
                      ? 'meds.frequency.asNeeded'.tr()
                      : 'meds.frequency.${state.frequency.name}'.tr(),
                ),
                _SummaryRow(
                  label: 'meds.form.scheduleTimes'.tr(),
                  value: isAsNeeded
                      ? 'meds.review.noFixedSchedule'.tr()
                      : state.scheduleTimes.join(', '),
                ),

                _StatusRow(
                  label: 'meds.review.reminder'.tr(),
                  on: !isAsNeeded,
                ),
                _StatusRow(
                  label: 'meds.review.notifyCaregiver'.tr(),
                  on: notifyCaregiverEnabled,
                ),
                _SummaryRow(
                  label: 'meds.form.instructions.title'.tr(),
                  value: instructionsValue == MedicationInstructions.none
                      ? 'meds.review.instructionsNotSet'.tr()
                      : 'meds.form.instructions.${instructionsValue.name}'.tr(),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          SectionCard(
            padding: EdgeInsets.zero,
            child: Container(
              width: double.infinity,
              color: AppColors.accentBg,
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[

                  const Icon(Iconsax.notification, color: AppColors.accent, size: 20),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[

                        Text(
                          isAsNeeded
                              ? 'meds.form.asNeededCaption'.tr()
                              : 'meds.review.remindersSet'.tr(
                                  namedArgs: <String, String>{
                                    'times': state.scheduleTimes.join(', '),
                                  },
                                ),
                          style: Theme.of(
                            context,
                          ).textTheme.bodySmall?.copyWith(color: AppColors.accent),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          'meds.review.offlineNote'.tr(),
                          style: Theme.of(
                            context,
                          ).textTheme.bodySmall?.copyWith(color: AppColors.accent),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xxl),
          AppButton(
            label: 'meds.review.save'.tr(),
            isLoading: state.isSaving,
            onPressed: () => _save(context, controller),
          ),
          const SizedBox(height: AppSpacing.sm),
          AppButton(
            label: 'meds.review.edit'.tr(),
            variant: AppButtonVariant.text,
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  Future<void> _save(BuildContext context, MedicationFormController controller) async {
    try {
      await controller.save(
        caregiverSettings: CaregiverNotifySettings(
          enabled: notifyCaregiverEnabled,
          phone: caregiverPhone,
        ),
        instructions: instructions ?? MedicationInstructions.none,
      );
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              error is Failure ? error.message : 'errors.generic'.tr(),
            ),
          ),
        );
    }
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[

          Flexible(
            child: Text(
              label,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: AppColors.ink, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusRow extends StatelessWidget {
  const _StatusRow({required this.label, required this.on});

  final String label;
  final bool on;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          Flexible(
            child: Text(
              label,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          _StatusPill(on: on, label: on ? 'meds.review.on'.tr() : 'meds.review.off'.tr()),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.on, required this.label});

  final bool on;
  final String label;

  @override
  Widget build(BuildContext context) {
    final Color foreground = on ? AppColors.success : AppColors.accent;
    final Color background = on ? AppColors.successBg : AppColors.accentBg;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xs),
      decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(AppSpacing.lg)),
      child: Text(
        label,
        style: Theme.of(
          context,
        ).textTheme.bodySmall?.copyWith(color: foreground, fontWeight: FontWeight.bold),
      ),
    );
  }
}
