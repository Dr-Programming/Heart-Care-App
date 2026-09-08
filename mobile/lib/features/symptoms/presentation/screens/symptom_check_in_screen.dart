import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/widgets.dart';
import '../../domain/entities/symptom_answer.dart';
import '../../domain/entities/symptom_history_entry.dart';
import '../../domain/validators/symptom_validators.dart';
import '../controllers/check_in_controller.dart';
import '../providers/symptom_providers.dart';
import '../widgets/severity_result_banner.dart';
import '../widgets/severity_slider.dart';
import '../widgets/yes_no_field.dart';

/// FR-SYM-001…010 — the daily check-in (design decision 1: one screen, not
/// a wizard). Every field defaults to the "fine" answer, so "I'm fine
/// today" is two taps: open this screen, tap Save.
///
/// After a successful save this screen switches to showing the result
/// in-place (design decision 3) rather than navigating away — read from
/// `todayCheckInProvider`, the same Drift-backed stream the hub and history
/// screens use, so there is exactly one place that computes "what does a
/// saved check-in look like."
class SymptomCheckInScreen extends ConsumerStatefulWidget {
  const SymptomCheckInScreen({super.key});

  @override
  ConsumerState<SymptomCheckInScreen> createState() =>
      _SymptomCheckInScreenState();
}

class _SymptomCheckInScreenState extends ConsumerState<SymptomCheckInScreen> {
  bool _submitted = false;

  bool _chestPainPresent = false;
  int _chestPainSeverity = 5;
  bool _chestPainWorse = false;

  ShortnessOfBreath _shortnessOfBreath = ShortnessOfBreath.none;

  final TextEditingController _heartRate = TextEditingController(text: '72');
  final TextEditingController _systolic = TextEditingController(text: '120');
  final TextEditingController _diastolic = TextEditingController(text: '80');

  bool _swelling = false;
  bool _swellingWorse = false;

  int _energyLevel = 7;

  final TextEditingController _note = TextEditingController();

  @override
  void dispose() {
    _heartRate.dispose();
    _systolic.dispose();
    _diastolic.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final ChestPain chestPain = _chestPainPresent
        ? ChestPain(present: true, severity: _chestPainSeverity)
        : ChestPain.none;
    final BloodPressureReading bloodPressure = BloodPressureReading(
      systolic: int.tryParse(_systolic.text) ?? 0,
      diastolic: int.tryParse(_diastolic.text) ?? 0,
    );
    final Map<SymptomKey, bool> worseThanYesterday = <SymptomKey, bool>{
      if (_chestPainPresent) SymptomKey.chestPain: _chestPainWorse,
      if (_swelling) SymptomKey.swelling: _swellingWorse,
    };

    final CheckInController notifier = ref.read(
      checkInControllerProvider.notifier,
    );
    await notifier.submit(
      chestPain: chestPain,
      shortnessOfBreath: _shortnessOfBreath,
      heartRate: int.tryParse(_heartRate.text) ?? 0,
      bloodPressure: bloodPressure,
      swelling: _swelling,
      energyLevel: _energyLevel,
      worseThanYesterday: worseThanYesterday,
      note: _note.text.trim().isEmpty ? null : _note.text.trim(),
    );

    if (!mounted) return;
    final AsyncValue<void> result = ref.read(checkInControllerProvider);
    // Not `result.hasValue`: Riverpod's AsyncError carries the previous
    // state's value forward (for seamless "keep showing old data" UIs), so
    // hasValue is true even for a validation failure here. hasError is the
    // one that actually distinguishes "saved" from "rejected".
    if (!result.hasError && !result.isLoading) {
      setState(() => _submitted = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_submitted) return const _ResultScreen();
    return _FormScreen(
      chestPainPresent: _chestPainPresent,
      onChestPainPresentChanged: (bool v) =>
          setState(() => _chestPainPresent = v),
      chestPainSeverity: _chestPainSeverity,
      onChestPainSeverityChanged: (int v) =>
          setState(() => _chestPainSeverity = v),
      chestPainWorse: _chestPainWorse,
      onChestPainWorseChanged: (bool v) => setState(() => _chestPainWorse = v),
      shortnessOfBreath: _shortnessOfBreath,
      onShortnessOfBreathChanged: (ShortnessOfBreath v) =>
          setState(() => _shortnessOfBreath = v),
      heartRate: _heartRate,
      systolic: _systolic,
      diastolic: _diastolic,
      swelling: _swelling,
      onSwellingChanged: (bool v) => setState(() => _swelling = v),
      swellingWorse: _swellingWorse,
      onSwellingWorseChanged: (bool v) => setState(() => _swellingWorse = v),
      energyLevel: _energyLevel,
      onEnergyLevelChanged: (int v) => setState(() => _energyLevel = v),
      note: _note,
      onSave: _save,
    );
  }
}

class _ResultScreen extends ConsumerWidget {
  const _ResultScreen();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<SymptomHistoryEntry?> today = ref.watch(
      todayCheckInProvider,
    );

    return AppScaffold(
      title: 'symptoms.checkIn.title'.tr(),
      showBack: false,
      body: today.when(
        data: (SymptomHistoryEntry? entry) => entry == null
            ? const Center(child: CircularProgressIndicator())
            : Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  SeverityResultBanner(severity: entry.overallSeverity),
                  const SizedBox(height: AppSpacing.xl),
                  AppButton(
                    label: 'common.done'.tr(),
                    onPressed: () {
                      final NavigatorState navigator = Navigator.of(context);
                      if (navigator.canPop()) navigator.pop();
                    },
                  ),
                ],
              ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (Object _, StackTrace _) =>
            const Center(child: CircularProgressIndicator()),
      ),
    );
  }
}

class _FormScreen extends ConsumerWidget {
  const _FormScreen({
    required this.chestPainPresent,
    required this.onChestPainPresentChanged,
    required this.chestPainSeverity,
    required this.onChestPainSeverityChanged,
    required this.chestPainWorse,
    required this.onChestPainWorseChanged,
    required this.shortnessOfBreath,
    required this.onShortnessOfBreathChanged,
    required this.heartRate,
    required this.systolic,
    required this.diastolic,
    required this.swelling,
    required this.onSwellingChanged,
    required this.swellingWorse,
    required this.onSwellingWorseChanged,
    required this.energyLevel,
    required this.onEnergyLevelChanged,
    required this.note,
    required this.onSave,
  });

  final bool chestPainPresent;
  final ValueChanged<bool> onChestPainPresentChanged;
  final int chestPainSeverity;
  final ValueChanged<int> onChestPainSeverityChanged;
  final bool chestPainWorse;
  final ValueChanged<bool> onChestPainWorseChanged;
  final ShortnessOfBreath shortnessOfBreath;
  final ValueChanged<ShortnessOfBreath> onShortnessOfBreathChanged;
  final TextEditingController heartRate;
  final TextEditingController systolic;
  final TextEditingController diastolic;
  final bool swelling;
  final ValueChanged<bool> onSwellingChanged;
  final bool swellingWorse;
  final ValueChanged<bool> onSwellingWorseChanged;
  final int energyLevel;
  final ValueChanged<int> onEnergyLevelChanged;
  final TextEditingController note;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<void> state = ref.watch(checkInControllerProvider);
    final Object? error = state.error;
    final Set<SymptomValidationError> errors = error is SymptomValidationFailed
        ? error.errors
        : <SymptomValidationError>{};

    return AppScaffold(
      title: 'symptoms.checkIn.title'.tr(),
      scrollable: true,
      bottomBar: AppButton(
        label: 'common.save'.tr(),
        isLoading: state.isLoading,
        onPressed: onSave,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          YesNoField(
            label: 'symptoms.checkIn.chestPain'.tr(),
            value: chestPainPresent,
            onChanged: onChestPainPresentChanged,
          ),
          if (chestPainPresent) ...<Widget>[
            const SizedBox(height: AppSpacing.lg),
            SeveritySlider(
              label: 'symptoms.checkIn.chestPainSeverity'.tr(),
              value: chestPainSeverity,
              onChanged: onChestPainSeverityChanged,
            ),
            const SizedBox(height: AppSpacing.lg),
            YesNoField(
              label: 'symptoms.checkIn.worseThanYesterday'.tr(),
              value: chestPainWorse,
              onChanged: onChestPainWorseChanged,
            ),
          ],
          const SizedBox(height: AppSpacing.xl),
          Text(
            'symptoms.checkIn.breathlessness'.tr(),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            children: <Widget>[
              for (final ShortnessOfBreath option in ShortnessOfBreath.values)
                ChoiceChip(
                  label: Text(
                    'symptoms.checkIn.breathlessnessOption.${option.wire.toLowerCase()}'
                        .tr(),
                  ),
                  selected: option == shortnessOfBreath,
                  onSelected: (_) => onShortnessOfBreathChanged(option),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          AppTextField(
            label: 'symptoms.checkIn.heartRate'.tr(),
            controller: heartRate,
            keyboardType: TextInputType.number,
            inputFormatters: <TextInputFormatter>[
              FilteringTextInputFormatter.digitsOnly,
            ],
            errorText:
                errors.contains(SymptomValidationError.heartRateOutOfRange)
                ? 'symptoms.checkIn.heartRateError'.tr()
                : null,
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: <Widget>[
              Expanded(
                child: AppTextField(
                  label: 'symptoms.checkIn.systolic'.tr(),
                  controller: systolic,
                  keyboardType: TextInputType.number,
                  inputFormatters: <TextInputFormatter>[
                    FilteringTextInputFormatter.digitsOnly,
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: AppTextField(
                  label: 'symptoms.checkIn.diastolic'.tr(),
                  controller: diastolic,
                  keyboardType: TextInputType.number,
                  inputFormatters: <TextInputFormatter>[
                    FilteringTextInputFormatter.digitsOnly,
                  ],
                ),
              ),
            ],
          ),
          if (errors.contains(SymptomValidationError.bloodPressureOutOfRange) ||
              errors.contains(
                SymptomValidationError.bloodPressureNotGreaterThanDiastolic,
              )) ...<Widget>[
            const SizedBox(height: AppSpacing.xs),
            Text(
              'symptoms.checkIn.bloodPressureError'.tr(),
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: Theme.of(context).colorScheme.error),
            ),
          ],
          const SizedBox(height: AppSpacing.xl),
          YesNoField(
            label: 'symptoms.checkIn.swelling'.tr(),
            value: swelling,
            onChanged: onSwellingChanged,
          ),
          if (swelling) ...<Widget>[
            const SizedBox(height: AppSpacing.lg),
            YesNoField(
              label: 'symptoms.checkIn.worseThanYesterday'.tr(),
              value: swellingWorse,
              onChanged: onSwellingWorseChanged,
            ),
          ],
          const SizedBox(height: AppSpacing.xl),
          SeveritySlider(
            label: 'symptoms.checkIn.energyLevel'.tr(),
            value: energyLevel,
            onChanged: onEnergyLevelChanged,
          ),
          const SizedBox(height: AppSpacing.xl),
          AppTextField(
            label: 'symptoms.checkIn.note'.tr(),
            controller: note,
            maxLines: 3,
          ),
        ],
      ),
    );
  }
}
