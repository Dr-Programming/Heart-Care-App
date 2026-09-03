import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:libu_care/core/clinical/alert_evaluator.dart';
import 'package:libu_care/core/widgets/widgets.dart';

import '../../domain/entities/vital_type.dart';
import '../../domain/vital_descriptors.dart';
import '../controllers/vital_form_controller.dart';
import '../widgets/vital_form_fields.dart';

class VitalFormScreen extends ConsumerWidget {
  const VitalFormScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final VitalFormState state = ref.watch(vitalFormControllerProvider);
    final VitalFormController controller = ref.read(
      vitalFormControllerProvider.notifier,
    );

    if (state.isSaved) {
      return AppScaffold(
        title: 'vitals.logTitle'.tr(),
        body: _SavedResult(
          severity: state.resultSeverity!,
          onDone: () => Navigator.of(context).pop(),
          onLogAnother: () => controller.selectType(state.type),
        ),
      );
    }

    return AppScaffold(
      title: 'vitals.logTitle'.tr(),
      scrollable: true,
      bottomBar: AppButton(
        label: 'common.save'.tr(),
        isLoading: state.isSaving,
        onPressed: controller.submit,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Wrap(
            spacing: 8,
            children: <Widget>[
              for (final VitalType type in VitalType.values)
                ChoiceChip(
                  label: Text(vitalDescriptors[type]!.labelKey.tr()),
                  selected: state.type == type,
                  onSelected: (_) => controller.selectType(type),
                ),
            ],
          ),
          const SizedBox(height: 16),
          VitalFormFields(
            key: ValueKey<VitalType>(state.type),
            descriptor: vitalDescriptors[state.type]!,
            fieldErrors: state.fieldErrors,
            onChanged: controller.setValue,
            hints: state.hints,
          ),
          if (state.crossFieldError != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                state.crossFieldError!.key.tr(),
                style: Theme.of(context).textTheme.bodySmall
                    ?.copyWith(color: Theme.of(context).colorScheme.error),
              ),
            ),
          AppTextField(
            label: 'vitals.noteLabel'.tr(),
            maxLength: 500,
            maxLines: 3,
            onChanged: controller.setNote,
          ),
        ],
      ),
    );
  }
}

class _SavedResult extends StatelessWidget {
  const _SavedResult({
    required this.severity,
    required this.onDone,
    required this.onLogAnother,
  });

  final Severity severity;
  final VoidCallback onDone;
  final VoidCallback onLogAnother;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            StatusChip(severity: severity),
            const SizedBox(height: 16),
            Text(actionKeyFor(severity).tr(), textAlign: TextAlign.center),
            const SizedBox(height: 24),
            AppButton(
              label: 'vitals.logAnother'.tr(),
              variant: AppButtonVariant.secondary,
              onPressed: onLogAnother,
            ),
            const SizedBox(height: 8),
            AppButton(label: 'common.done'.tr(), onPressed: onDone),
          ],
        ),
      ),
    );
  }
}
