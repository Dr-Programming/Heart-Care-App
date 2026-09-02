import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/localization/language.dart';
import '../../../../core/providers/core_providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../domain/validators.dart';
import '../language_actions.dart';
import '../widgets/selectable_chip.dart';
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
  AppLanguage _language = AppLanguage.en;

  @override
  void dispose() {
    _birthYearController.dispose();
    _heightController.dispose();
    super.dispose();
  }

  Future<void> _selectLanguage(AppLanguage language) async {
    setState(() => _language = language);
    // Device-local only — the profile itself is written once, at the end of
    // the wizard (Decision 4). See language_actions.dart.
    await switchDeviceLanguage(context, ref, language);
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
          preferredLanguage: _language.code,
        );

    context.push('/onboarding/step-2');
  }

  @override
  Widget build(BuildContext context) {
    // Display-only, prefilled from the session (M2 spec §3) — the wire
    // contract for PUT /patients/me has no name field, so there is nothing
    // here for a patient to edit or for this screen to submit.
    final cachedUser = ref.watch(cachedUserProvider).value;

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
                    'profile.onboarding.step1.progress'.tr(),
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'profile.onboarding.step1.title'.tr(),
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
                        'profile.fields.name'.tr(),
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      // A real TextFormField here would be misleading — this
                      // is a display, not an editable field, and there is no
                      // name field on the profile PUT to save it to anyway.
                      // (It also sidesteps a genuine bug: TextFormField only
                      // honours `initialValue` on its very first build, and
                      // `cachedUserProvider` almost never has a value that
                      // early, so the field would render blank forever.)
                      Container(
                        key: const ValueKey('onboarding-name'),
                        width: double.infinity,
                        height: AppSpacing.fieldHeight,
                        alignment: Alignment.centerLeft,
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.lg,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceAlt,
                          borderRadius:
                              BorderRadius.circular(AppSpacing.fieldRadius),
                        ),
                        child: Text(
                          cachedUser?.name ?? '',
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      Text(
                        'profile.fields.birthYear'.tr(),
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      TextFormField(
                        controller: _birthYearController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          hintText: 'profile.fields.birthYearHint'.tr(),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) return null;
                          final year = int.tryParse(value);
                          if (year == null) return 'errors.invalidNumber'.tr();
                          final result = ProfileValidators.birthYear(year);
                          return result.isValid
                              ? null
                              : result.errorMessage!.tr();
                        },
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      Text(
                        'profile.fields.heightCm'.tr(),
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      TextFormField(
                        controller: _heightController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: InputDecoration(
                          hintText: 'profile.fields.heightCmHint'.tr(),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) return null;
                          final height = double.tryParse(value);
                          if (height == null) {
                            return 'errors.invalidNumber'.tr();
                          }
                          final result = ProfileValidators.heightCm(height);
                          return result.isValid
                              ? null
                              : result.errorMessage!.tr();
                        },
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      Text(
                        'profile.fields.preferredLanguage'.tr(),
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Row(
                        children: [
                          for (final language in AppLanguage.values) ...[
                            if (language != AppLanguage.values.first)
                              const SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child: SelectableChip(
                                label: language.nativeLabel,
                                selected: _language == language,
                                onTap: () => _selectLanguage(language),
                              ),
                            ),
                          ],
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
                child: Text('${'common.next'.tr()}  →'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
