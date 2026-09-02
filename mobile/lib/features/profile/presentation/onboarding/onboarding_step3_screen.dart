import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../domain/entities/health_goals.dart';
import '../../domain/validators.dart';
import '../providers/profile_providers.dart';
import 'onboarding_controller.dart';

class OnboardingStep3Screen extends ConsumerStatefulWidget {
  const OnboardingStep3Screen({super.key});

  @override
  ConsumerState<OnboardingStep3Screen> createState() =>
      _OnboardingStep3ScreenState();
}

class _OnboardingStep3ScreenState
    extends ConsumerState<OnboardingStep3Screen> {
  final _formKey = GlobalKey<FormState>();
  final _systolicController = TextEditingController();
  final _diastolicController = TextEditingController();
  final _weightController = TextEditingController();
  final _stepsController = TextEditingController();
  final _cholesterolController = TextEditingController();
  final _dietNoteController = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _systolicController.dispose();
    _diastolicController.dispose();
    _weightController.dispose();
    _stepsController.dispose();
    _cholesterolController.dispose();
    _dietNoteController.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);

    final goals = HealthGoals(
      bpSystolic: _tryParseInt(_systolicController.text),
      bpDiastolic: _tryParseInt(_diastolicController.text),
      targetWeightKg: _tryParseDouble(_weightController.text),
      stepsPerDay: _tryParseInt(_stepsController.text),
      totalCholesterol: _tryParseDouble(_cholesterolController.text),
      dietNote: _dietNoteController.text.isEmpty
          ? null
          : _dietNoteController.text,
    );

    ref.read(onboardingControllerProvider.notifier).updateGoals(goals);

    // TODO(M2/M1): once the real AuthGate lands (see AuthGate.needsOnboarding
    // in core/router/auth_gate.dart), clear the onboarding flag here on both
    // this path and the skip path below, so the router lets the patient
    // through to Home instead of bouncing them back to /onboarding.
    final state = ref.read(onboardingControllerProvider);
    await ref.read(saveProfileProvider)(state.toPatientProfile());

    if (mounted) context.go('/home');
  }

  Future<void> _skip() async {
    // Per the M2 spec: skipping still writes whatever was captured across
    // steps 1-2, it just never collects goals. Nothing here is optional to
    // skip past — the wizard is skippable, but a skip is not a discard.
    final state = ref.read(onboardingControllerProvider);
    await ref.read(saveProfileProvider)(state.toPatientProfile());

    if (mounted) context.go('/home');
  }

  int? _tryParseInt(String value) =>
      value.isEmpty ? null : int.tryParse(value);

  double? _tryParseDouble(String value) =>
      value.isEmpty ? null : double.tryParse(value);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.gutter,
                vertical: AppSpacing.lg,
              ),
              color: AppColors.headerBand,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      IconButton(
                        onPressed: () => context.pop(),
                        icon: const Icon(Icons.arrow_back),
                        color: AppColors.ink,
                      ),
                      Expanded(
                        child: Text(
                          'profile.onboarding.step3.title'.tr(),
                          style: Theme.of(context).textTheme.headlineLarge,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    'profile.onboarding.step3.progress'.tr(),
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpacing.gutter),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'profile.onboarding.step3.intro'.tr(),
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      Text(
                        'profile.fields.targetBp'.tr(),
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _systolicController,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                hintText: 'profile.fields.systolicHint'.tr(),
                              ),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: TextFormField(
                              controller: _diastolicController,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                hintText: 'profile.fields.diastolicHint'.tr(),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      Text(
                        'profile.fields.targetWeight'.tr(),
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      TextFormField(
                        controller: _weightController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: InputDecoration(
                          hintText: 'profile.fields.targetWeightHint'.tr(),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) return null;
                          final result = ProfileValidators.nonNegative(
                            double.tryParse(value),
                          );
                          return result.isValid
                              ? null
                              : result.errorMessage!.tr();
                        },
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      Text(
                        'profile.fields.stepsGoal'.tr(),
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      TextFormField(
                        controller: _stepsController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          hintText: 'profile.fields.stepsGoalHint'.tr(),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) return null;
                          final result = ProfileValidators.nonNegative(
                            int.tryParse(value),
                          );
                          return result.isValid
                              ? null
                              : result.errorMessage!.tr();
                        },
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      Text(
                        'profile.fields.targetCholesterol'.tr(),
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      TextFormField(
                        controller: _cholesterolController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: InputDecoration(
                          hintText:
                              'profile.fields.targetCholesterolHint'.tr(),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      Text(
                        'profile.fields.dietNote'.tr(),
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      TextFormField(
                        controller: _dietNoteController,
                        maxLines: 2,
                        decoration: InputDecoration(
                          hintText: 'profile.fields.dietNoteHint'.tr(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.gutter,
                0,
                AppSpacing.gutter,
                AppSpacing.gutter,
              ),
              child: Column(
                children: [
                  FilledButton(
                    onPressed: _saving ? null : _finish,
                    child: _saving
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text('${'profile.onboarding.step3.finish'.tr()}  →'),
                  ),
                  TextButton(
                    onPressed: _saving ? null : _skip,
                    child: Text('profile.onboarding.step3.skip'.tr()),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
