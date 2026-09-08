import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/widgets.dart';
import '../../domain/entities/activity_session.dart';
import '../../domain/validators/activity_validators.dart';
import '../controllers/activity_log_controller.dart';
import '../widgets/activity_type_picker.dart';
import '../widgets/termination_indications.dart';

/// FR-ACT-003 — logs one activity session. Termination indications
/// (FR-ACT-002) sit at the top, ahead of the form, per design decision 7.
class ActivityLogScreen extends ConsumerStatefulWidget {
  const ActivityLogScreen({super.key});

  @override
  ConsumerState<ActivityLogScreen> createState() => _ActivityLogScreenState();
}

class _ActivityLogScreenState extends ConsumerState<ActivityLogScreen> {
  ActivityType _type = ActivityType.walking;
  Intensity _intensity = Intensity.moderate;
  final TextEditingController _duration = TextEditingController();
  final TextEditingController _steps = TextEditingController();
  final TextEditingController _distance = TextEditingController();
  final TextEditingController _note = TextEditingController();

  @override
  void dispose() {
    _duration.dispose();
    _steps.dispose();
    _distance.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final ActivityLogController notifier = ref.read(
      activityLogControllerProvider.notifier,
    );
    await notifier.save(
      type: _type,
      durationMinutes: int.tryParse(_duration.text) ?? 0,
      intensity: _intensity,
      steps: int.tryParse(_steps.text),
      distanceMeters: double.tryParse(_distance.text),
      note: _note.text.trim().isEmpty ? null : _note.text.trim(),
    );
    if (!mounted) return;
    final AsyncValue<void> result = ref.read(activityLogControllerProvider);
    final NavigatorState navigator = Navigator.of(context);
    // Not `result.hasValue`: Riverpod's AsyncError carries the previous
    // state's value forward (for seamless "keep showing old data" UIs), so
    // hasValue is true even for a validation failure here. hasError is the
    // one that actually distinguishes "saved" from "rejected" — without
    // this check, a validation error would still pop the screen whenever
    // there's something to pop back to.
    if (!result.hasError && !result.isLoading && navigator.canPop()) {
      navigator.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<void> state = ref.watch(activityLogControllerProvider);
    final Object? error = state.error;
    final Set<ActivityValidationError> errors =
        error is ActivityValidationFailed
        ? error.errors
        : <ActivityValidationError>{};

    return AppScaffold(
      title: 'activity.log.title'.tr(),
      scrollable: true,
      bottomBar: AppButton(
        label: 'common.save'.tr(),
        isLoading: state.isLoading,
        onPressed: _save,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const TerminationIndications(),
          const SizedBox(height: AppSpacing.xl),
          Text(
            'activity.log.type'.tr(),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: AppSpacing.sm),
          ActivityTypePicker(
            value: _type,
            onChanged: (ActivityType type) => setState(() => _type = type),
          ),
          const SizedBox(height: AppSpacing.lg),
          AppTextField(
            label: 'activity.log.duration'.tr(),
            controller: _duration,
            keyboardType: TextInputType.number,
            inputFormatters: <TextInputFormatter>[
              FilteringTextInputFormatter.digitsOnly,
            ],
            errorText:
                errors.contains(ActivityValidationError.durationOutOfRange)
                ? 'activity.log.durationError'.tr()
                : null,
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            'activity.log.intensity'.tr(),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            children: <Widget>[
              for (final Intensity intensity in Intensity.values)
                ChoiceChip(
                  label: Text(
                    'activity.intensity.${intensity.wire.toLowerCase()}'.tr(),
                  ),
                  selected: intensity == _intensity,
                  onSelected: (_) => setState(() => _intensity = intensity),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          AppTextField(
            label: 'activity.log.steps'.tr(),
            controller: _steps,
            keyboardType: TextInputType.number,
            inputFormatters: <TextInputFormatter>[
              FilteringTextInputFormatter.digitsOnly,
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          AppTextField(
            label: 'activity.log.distance'.tr(),
            controller: _distance,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: <TextInputFormatter>[
              FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*$')),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          AppTextField(
            label: 'activity.log.note'.tr(),
            controller: _note,
            maxLines: 3,
          ),
        ],
      ),
    );
  }
}
