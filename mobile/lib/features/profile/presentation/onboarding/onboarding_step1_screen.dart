import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../domain/validators.dart';
import 'onboarding_controller.dart';

class OnboardingStep1Screen extends ConsumerStatefulWidget {
  const OnboardingStep1Screen({super.key});

  @override
  ConsumerState<OnboardingStep1Screen> createState() =>
      _OnboardingStep1ScreenState();
}

class _OnboardingStep1ScreenState
    extends ConsumerState<OnboardingStep1Screen> {
  final _formKey = GlobalKey<FormState>();
  final _birthYearController = TextEditingController();
  final _heightController = TextEditingController();
  String _language = 'en';

  @override
  void dispose() {
    _birthYearController.dispose();
    _heightController.dispose();
    super.dispose();
  }

  void _continue() {
    if (!_formKey.currentState!.validate()) return;

    final birthYear = _birthYearController.text.isEmpty
        ? null
        : int.tryParse(_birthYearController.text);
    final heightCm = _heightController.text.isEmpty
        ? null
        : double.tryParse(_heightController.text);

    ref.read(onboardingControllerProvider.notifier).updatePersonalDetails(
          birthYear: birthYear,
          heightCm: heightCm,
          preferredLanguage: _language,
        );

    context.push('/onboarding/step-2');
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
              height: AppSpacing.headerBandHeight,
              color: AppColors.headerBand,
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.gutter,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Step 1 of 3 — Personal details',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Tell us about yourself',
                    style: Theme.of(context).textTheme.headlineLarge,
                  ),
                  const SizedBox(height: AppSpacing.lg),
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
                        'Birth year',
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      TextFormField(
                        controller: _birthYearController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          hintText: 'e.g. 1965',
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) return null;
                          final year = int.tryParse(value);
                          if (year == null) return 'Enter a valid year';
                          final result = ProfileValidators.birthYear(year);
                          return result.isValid ? null : result.errorMessage;
                        },
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      Text(
                        'Height (cm)',
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      TextFormField(
                        controller: _heightController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          hintText: 'e.g. 172',
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) return null;
                          final height = double.tryParse(value);
                          if (height == null) return 'Enter a valid height';
                          final result = ProfileValidators.heightCm(height);
                          return result.isValid ? null : result.errorMessage;
                        },
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      Text(
                        'Preferred language',
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Row(
                        children: [
                          Expanded(
                            child: _LanguageChip(
                              label: 'English',
                              selected: _language == 'en',
                              onTap: () => setState(() => _language = 'en'),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: _LanguageChip(
                              label: 'Amharic',
                              selected: _language == 'am',
                              onTap: () => setState(() => _language = 'am'),
                            ),
                          ),
                        ],
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
                child: const Text('Continue  →'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LanguageChip extends StatelessWidget {
  const _LanguageChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSpacing.buttonRadius),
      child: Container(
        height: AppSpacing.fieldHeight,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? AppColors.ink : AppColors.surface,
          borderRadius: BorderRadius.circular(AppSpacing.buttonRadius),
          border: Border.all(
            color: selected ? AppColors.ink : AppColors.border,
          ),
        ),
        child: Text(
          label,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: selected ? AppColors.surface : AppColors.ink,
              ),
        ),
      ),
    );
  }
}