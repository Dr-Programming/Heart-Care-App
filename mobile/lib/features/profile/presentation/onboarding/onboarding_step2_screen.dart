import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../domain/validators.dart';
import '../widgets/comorbidity_options.dart';
import 'onboarding_controller.dart';

class OnboardingStep2Screen extends ConsumerStatefulWidget {
  const OnboardingStep2Screen({super.key});

  @override
  ConsumerState<OnboardingStep2Screen> createState() =>
      _OnboardingStep2ScreenState();
}

class _OnboardingStep2ScreenState
    extends ConsumerState<OnboardingStep2Screen> {
  final _formKey = GlobalKey<FormState>();
  final _chdStageController = TextEditingController();
  final _diseaseHistoryController = TextEditingController();
  final _managementPlanController = TextEditingController();
  final _otherController = TextEditingController();
  final Set<String> _selectedComorbidities = {};

  @override
  void dispose() {
    _chdStageController.dispose();
    _diseaseHistoryController.dispose();
    _managementPlanController.dispose();
    _otherController.dispose();
    super.dispose();
  }

  void _continue() {
    if (!_formKey.currentState!.validate()) return;

    ref.read(onboardingControllerProvider.notifier).updateMedicalProfile(
          chdStage: _chdStageController.text.isEmpty
              ? null
              : _chdStageController.text,
          comorbidities: mergeComorbidities(
            _selectedComorbidities,
            _otherController.text,
          ),
          diseaseHistory: _diseaseHistoryController.text.isEmpty
              ? null
              : _diseaseHistoryController.text,
          managementPlan: _managementPlanController.text.isEmpty
              ? null
              : _managementPlanController.text,
        );

    context.push('/onboarding/step-3');
  }

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
                          'profile.onboarding.step2.title'.tr(),
                          style: Theme.of(context).textTheme.headlineLarge,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    'profile.onboarding.step2.progress'.tr(),
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
                        'profile.fields.diagnosis'.tr(),
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      TextFormField(
                        controller: _chdStageController,
                        maxLength: 50,
                        decoration: InputDecoration(
                          hintText: 'profile.fields.diagnosisHint'.tr(),
                        ),
                        validator: (value) {
                          final result = ProfileValidators.chdStage(value);
                          return result.isValid
                              ? null
                              : result.errorMessage!.tr();
                        },
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        'profile.fields.diseaseHistory'.tr(),
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      TextFormField(
                        controller: _diseaseHistoryController,
                        maxLines: 3,
                        decoration: InputDecoration(
                          hintText: 'profile.fields.diseaseHistoryHint'.tr(),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        'profile.fields.managementPlan'.tr(),
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      TextFormField(
                        controller: _managementPlanController,
                        maxLines: 3,
                        decoration: InputDecoration(
                          hintText: 'profile.fields.managementPlanHint'.tr(),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      Text(
                        'profile.fields.comorbiditiesOptional'.tr(),
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      ComorbidityChips(
                        selected: _selectedComorbidities,
                        onToggle: (value) => setState(() {
                          _selectedComorbidities.contains(value)
                              ? _selectedComorbidities.remove(value)
                              : _selectedComorbidities.add(value);
                        }),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      TextFormField(
                        controller: _otherController,
                        decoration: InputDecoration(
                          hintText: 'profile.fields.comorbidityOther'.tr(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.gutter),
              child: FilledButton(
                onPressed: _continue,
                child: Text('${'common.next'.tr()}  →'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
