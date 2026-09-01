import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../domain/validators.dart';
import 'onboarding_controller.dart';

const List<String> _suggestedComorbidities = [
  'Diabetes',
  'Hypertension',
  'Kidney disease',
  'High cholesterol',
  'Previous heart attack',
  'Stroke',
];

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
  final _otherController = TextEditingController();
  final Set<String> _selectedComorbidities = {};

  @override
  void dispose() {
    _chdStageController.dispose();
    _diseaseHistoryController.dispose();
    _otherController.dispose();
    super.dispose();
  }

  void _toggle(String label) {
    setState(() {
      if (_selectedComorbidities.contains(label)) {
        _selectedComorbidities.remove(label);
      } else {
        _selectedComorbidities.add(label);
      }
    });
  }

  void _continue() {
    if (!_formKey.currentState!.validate()) return;

    final comorbidities = [..._selectedComorbidities];
    if (_otherController.text.trim().isNotEmpty) {
      comorbidities.add(_otherController.text.trim());
    }

    ref.read(onboardingControllerProvider.notifier).updateMedicalProfile(
          chdStage: _chdStageController.text.isEmpty
              ? null
              : _chdStageController.text,
          comorbidities: comorbidities,
          diseaseHistory: _diseaseHistoryController.text.isEmpty
              ? null
              : _diseaseHistoryController.text,
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
                          'Medical profile',
                          style: Theme.of(context).textTheme.headlineLarge,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    'Step 2 of 3 — Heart condition details',
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
                        'Diagnosis',
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      TextFormField(
                        controller: _chdStageController,
                        maxLength: 50,
                        decoration: const InputDecoration(
                          hintText: 'e.g. Coronary artery disease',
                        ),
                        validator: (value) {
                          final result =
                              ProfileValidators.chdStage(value);
                          return result.isValid ? null : result.errorMessage;
                        },
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        'Disease history',
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      TextFormField(
                        controller: _diseaseHistoryController,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          hintText: 'e.g. Diagnosed 2019, one prior surgery',
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      Text(
                        'Comorbidities (optional)',
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Wrap(
                        spacing: AppSpacing.sm,
                        runSpacing: AppSpacing.sm,
                        children: _suggestedComorbidities.map((label) {
                          final selected =
                              _selectedComorbidities.contains(label);
                          return _ComorbidityChip(
                            label: label,
                            selected: selected,
                            onTap: () => _toggle(label),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      TextFormField(
                        controller: _otherController,
                        decoration: const InputDecoration(
                          hintText: 'Other (optional)',
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
                child: const Text('Continue  →'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ComorbidityChip extends StatelessWidget {
  const _ComorbidityChip({
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
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.sm,
        ),
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