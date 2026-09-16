import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/clinical/alert_evaluator.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/widgets.dart';
import '../../domain/entities/symptom_check_in.dart';
import '../controllers/check_in_hub_controller.dart';
import '../controllers/symptom_form_controller.dart';
import '../widgets/pill_choice.dart';

class SymptomCheckInScreen extends ConsumerWidget {
  const SymptomCheckInScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final SymptomFormState state = ref.watch(symptomFormControllerProvider);
    final SymptomFormController controller = ref.read(
      symptomFormControllerProvider.notifier,
    );

    return AppScaffold(
      title: 'symptoms.checkIn.title'.tr(),
      body: state.result != null
          ? _ResultView(result: state.result!)
          : _FormView(state: state, controller: controller, ref: ref),
    );
  }
}

class _FormView extends StatelessWidget {
  const _FormView({
    required this.state,
    required this.controller,
    required this.ref,
  });

  final SymptomFormState state;
  final SymptomFormController controller;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;

    return ListView(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
      children: <Widget>[
        Text('symptoms.checkIn.subtitle'.tr(), style: text.bodyMedium),
        const SizedBox(height: AppSpacing.xl),
        Text('symptoms.checkIn.chestPain'.tr(), style: text.titleMedium),
        const SizedBox(height: AppSpacing.sm),
        PillChoice(
          value: state.chestPain,
          onChanged: controller.setChestPain,
          options: <(String, String)>[
            ('NONE', 'symptoms.checkIn.none'.tr()),
            ('MILD', 'symptoms.checkIn.mild'.tr()),
            ('MODERATE', 'symptoms.checkIn.moderate'.tr()),
            ('SEVERE', 'symptoms.checkIn.severe'.tr()),
          ],
        ),
        const SizedBox(height: AppSpacing.xl),
        Text(
          'symptoms.checkIn.shortnessOfBreath'.tr(),
          style: text.titleMedium,
        ),
        const SizedBox(height: AppSpacing.sm),
        PillChoice(
          value: state.shortnessOfBreath,
          onChanged: controller.setShortnessOfBreath,
          options: <(String, String)>[
            ('NONE', 'symptoms.checkIn.none'.tr()),
            ('MILD', 'symptoms.checkIn.mild'.tr()),
            ('SEVERE', 'symptoms.checkIn.severe'.tr()),
          ],
        ),
        const SizedBox(height: AppSpacing.xl),
        Text('symptoms.checkIn.swelling'.tr(), style: text.titleMedium),
        const SizedBox(height: AppSpacing.sm),
        PillChoice(
          value: state.swelling ? 'YES' : 'NO',
          onChanged: (String v) => controller.setSwelling(v == 'YES'),
          options: <(String, String)>[
            ('NO', 'symptoms.checkIn.no'.tr()),
            ('YES', 'symptoms.checkIn.yes'.tr()),
          ],
        ),
        const SizedBox(height: AppSpacing.xl),
        Text('symptoms.checkIn.vitalsTitle'.tr(), style: text.titleMedium),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'symptoms.checkIn.vitalsHint'.tr(),
          style: text.labelSmall?.copyWith(color: AppColors.textTertiary),
        ),
        const SizedBox(height: AppSpacing.sm),
        AppTextField(
          label: 'symptoms.checkIn.heartRate'.tr(),
          keyboardType: TextInputType.number,
          inputFormatters: <TextInputFormatter>[
            FilteringTextInputFormatter.digitsOnly,
          ],
          errorText: state.fieldErrors['heartRate']?.tr(),
          onChanged: (String v) => controller.setHeartRate(int.tryParse(v)),
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(
              child: AppTextField(
                label: 'symptoms.checkIn.bpSystolic'.tr(),
                keyboardType: TextInputType.number,
                inputFormatters: <TextInputFormatter>[
                  FilteringTextInputFormatter.digitsOnly,
                ],
                errorText: state.fieldErrors['bpSystolic']?.tr(),
                onChanged: (String v) =>
                    controller.setBpSystolic(int.tryParse(v)),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: AppTextField(
                label: 'symptoms.checkIn.bpDiastolic'.tr(),
                keyboardType: TextInputType.number,
                inputFormatters: <TextInputFormatter>[
                  FilteringTextInputFormatter.digitsOnly,
                ],
                errorText: state.fieldErrors['bpDiastolic']?.tr(),
                onChanged: (String v) =>
                    controller.setBpDiastolic(int.tryParse(v)),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xl),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            Text('symptoms.checkIn.energyLevel'.tr(), style: text.titleMedium),
            Text('${state.energyLevel} / 10', style: text.titleMedium),
          ],
        ),
        Slider(
          value: state.energyLevel.toDouble(),
          min: 0,
          max: 10,
          divisions: 10,
          onChanged: (double v) => controller.setEnergyLevel(v.round()),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            Text(
              'symptoms.checkIn.exhausted'.tr(),
              style: text.labelSmall?.copyWith(color: AppColors.textTertiary),
            ),
            Text(
              'symptoms.checkIn.energetic'.tr(),
              style: text.labelSmall?.copyWith(color: AppColors.textTertiary),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: state.worseThanYesterday,
          onChanged: controller.setWorseThanYesterday,
          title: Text('symptoms.checkIn.worseThanYesterday'.tr()),
          subtitle: Text(
            'symptoms.checkIn.worseThanYesterdayHint'.tr(),
            style: text.labelSmall,
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        AppTextField(
          label: 'symptoms.checkIn.note'.tr(),
          maxLines: 3,
          onChanged: controller.setNote,
        ),
        if (state.generalError != null) ...<Widget>[
          const SizedBox(height: AppSpacing.sm),
          Text(
            state.generalError!.tr(),
            style: text.bodyMedium?.copyWith(color: AppColors.critical),
          ),
        ],
        const SizedBox(height: AppSpacing.xl),
        AppButton(
          label: 'symptoms.checkIn.next'.tr(),
          isLoading: state.isSubmitting,
          onPressed: () async {
            await controller.submit();
            ref.invalidate(checkInHubControllerProvider);
          },
        ),
      ],
    );
  }
}

class _ResultView extends StatelessWidget {
  const _ResultView({required this.result});

  final SymptomCheckIn result;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;

    return ListView(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
      children: <Widget>[
        Text('symptoms.summary.title'.tr(), style: text.headlineMedium),
        const SizedBox(height: AppSpacing.xs),
        Text('symptoms.summary.subtitle'.tr(), style: text.bodyMedium),
        const SizedBox(height: AppSpacing.lg),
        SectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  Text(
                    'symptoms.summary.overall'.tr(),
                    style: text.titleMedium,
                  ),
                  StatusChip(severity: result.overall),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(actionKeyFor(result.overall).tr(), style: text.bodyMedium),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        for (final MapEntry<String, Severity> entry
            in result.perSymptom.entries)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: SectionCard(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  Text(
                    'symptoms.summary.field.${entry.key}'.tr(),
                    style: text.bodyLarge,
                  ),
                  StatusChip(severity: entry.value),
                ],
              ),
            ),
          ),
        const SizedBox(height: AppSpacing.lg),
        AppButton(
          label: 'symptoms.summary.done'.tr(),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }
}
