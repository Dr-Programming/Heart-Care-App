import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/db/app_database.dart';
import '../../../../core/providers/core_providers.dart';
import '../../../../core/router/routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/widgets.dart';
import '../../domain/validators.dart';
import '../controllers/onboarding_controller.dart';
import '../widgets/comorbidity_chips.dart';
import '../widgets/wizard_progress.dart';
import '../widgets/year_field.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  late final TextEditingController _nameController;
  late final TextEditingController _birthYearController;
  late final TextEditingController _heightController;
  late final TextEditingController _otherComorbidityController;
  late final ProviderSubscription<AsyncValue<CachedUser?>> _cachedUserSub;

  String? _birthYearError;
  String? _heightError;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    final OnboardingState initial = ref.read(onboardingControllerProvider);
    _nameController = TextEditingController(text: initial.name ?? '');
    _birthYearController = TextEditingController(
      text: initial.birthYear?.toString() ?? '',
    );
    _heightController = TextEditingController(
      text: initial.heightCm == null ? '' : _formatHeight(initial.heightCm!),
    );
    _otherComorbidityController = TextEditingController(
      text: initial.otherComorbidity ?? '',
    );
    _otherComorbidityController.addListener(() {
      ref
          .read(onboardingControllerProvider.notifier)
          .setOtherComorbidity(_otherComorbidityController.text);
    });

    _cachedUserSub = ref.listenManual<AsyncValue<CachedUser?>>(
      cachedUserProvider,
      (AsyncValue<CachedUser?>? previous, AsyncValue<CachedUser?> next) {
        final CachedUser? user = next.value;
        if (user != null && _nameController.text.isEmpty) {
          _nameController.text = user.name;
          ref
              .read(onboardingControllerProvider.notifier)
              .setName(_nameController.text);
        }
      },
      fireImmediately: true,
    );
  }

  @override
  void dispose() {
    _cachedUserSub.close();
    _nameController.dispose();
    _birthYearController.dispose();
    _heightController.dispose();
    _otherComorbidityController.dispose();
    super.dispose();
  }

  static String _formatHeight(double cm) =>
      cm == cm.roundToDouble() ? cm.toStringAsFixed(0) : cm.toString();

  void _handleNext() {
    final OnboardingState state = ref.read(onboardingControllerProvider);
    final String? birthYearErrorKey = validateBirthYear(state.birthYear);
    final String? heightErrorKey = validateHeightCm(state.heightCm);
    setState(() {
      _birthYearError = birthYearErrorKey?.tr();
      _heightError = heightErrorKey?.tr();
    });
    if (birthYearErrorKey != null || heightErrorKey != null) return;
    ref.read(onboardingControllerProvider.notifier).next();
  }

  Future<void> _handleFinish() async {
    setState(() => _isSubmitting = true);
    await ref.read(onboardingControllerProvider.notifier).finish();
    if (!mounted) return;
    context.goNamed(AppRoutes.home);
  }

  Future<void> _handleSkip() async {
    setState(() => _isSubmitting = true);
    await ref.read(onboardingControllerProvider.notifier).skip();
    if (!mounted) return;
    context.goNamed(AppRoutes.home);
  }

  @override
  Widget build(BuildContext context) {
    final OnboardingState state = ref.watch(onboardingControllerProvider);
    final OnboardingController controller = ref.read(
      onboardingControllerProvider.notifier,
    );
    final TextTheme text = Theme.of(context).textTheme;

    final List<String> titles = <String>[
      'profile.onboarding.step1Title'.tr(),
      'profile.onboarding.step2Title'.tr(),
      'profile.onboarding.step3Title'.tr(),
    ];
    final List<String> subtitles = <String>[
      'profile.onboarding.step1Subtitle'.tr(),
      'profile.onboarding.step2Subtitle'.tr(),
      'profile.onboarding.step3Subtitle'.tr(),
    ];

    final Widget stepBody = switch (state.step) {
      0 => _buildStep1(context, state, controller),
      1 => _buildStep2(context, state, controller),
      _ => _buildStep3(context, state, controller),
    };

    final VoidCallback primaryAction = switch (state.step) {
      0 => _handleNext,
      1 => controller.next,
      _ => _handleFinish,
    };

    return AppScaffold.banded(
      showBack: false,
      bandChild: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.end,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Expanded(
                child: Text(titles[state.step], style: text.headlineMedium),
              ),
              AppButton(
                label: 'common.skip'.tr(),
                variant: AppButtonVariant.text,
                expand: false,
                onPressed: _isSubmitting ? null : _handleSkip,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(subtitles[state.step], style: text.bodyMedium),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          stepBody,
          const SizedBox(height: AppSpacing.xl),
          WizardProgress(step: state.step, totalSteps: 3),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: <Widget>[
              if (state.step > 0) ...<Widget>[
                Expanded(
                  child: AppButton(
                    label: 'common.back'.tr(),
                    variant: AppButtonVariant.secondary,
                    onPressed: _isSubmitting ? null : controller.back,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
              ],
              Expanded(
                child: AppButton(
                  label: state.step == 2
                      ? 'profile.onboarding.finish'.tr()
                      : 'common.next'.tr(),
                  isLoading: _isSubmitting,
                  onPressed: _isSubmitting ? null : primaryAction,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStep1(
    BuildContext context,
    OnboardingState state,
    OnboardingController controller,
  ) {
    final TextTheme text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        AppTextField(
          key: const Key('onboarding_name_field'),
          label: 'profile.onboarding.nameLabel'.tr(),
          controller: _nameController,
          enabled: false,
          helper: 'profile.onboarding.nameHelper'.tr(),
          textInputAction: TextInputAction.next,
          onChanged: controller.setName,
        ),
        const SizedBox(height: AppSpacing.lg),
        YearField(
          key: const Key('onboarding_birthYear_field'),
          controller: _birthYearController,
          label: 'profile.onboarding.birthYearLabel'.tr(),
          errorText: _birthYearError,
          onChanged: (String v) =>
              controller.setBirthYear(v.isEmpty ? null : int.tryParse(v)),
        ),
        const SizedBox(height: AppSpacing.lg),
        AppTextField(
          key: const Key('onboarding_height_field'),
          label: 'profile.onboarding.heightLabel'.tr(),
          controller: _heightController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: <TextInputFormatter>[
            FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*$')),
          ],
          errorText: _heightError,
          onChanged: (String v) =>
              controller.setHeightCm(v.isEmpty ? null : double.tryParse(v)),
        ),
        const SizedBox(height: AppSpacing.lg),
        Text('profile.onboarding.languageLabel'.tr(), style: text.titleMedium),
        const SizedBox(height: AppSpacing.sm),
        _LanguageToggle(
          value: state.preferredLanguage,
          onChanged: controller.setPreferredLanguage,
        ),
      ],
    );
  }

  Widget _buildStep2(
    BuildContext context,
    OnboardingState state,
    OnboardingController controller,
  ) {
    final TextTheme text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text('profile.onboarding.diagnosisLabel'.tr(), style: text.titleMedium),
        const SizedBox(height: AppSpacing.sm),
        ComorbidityChips(
          curated: const <(String, String)>[
            ('heart_failure', 'Heart failure'),
            ('arrhythmia', 'Arrhythmia'),
          ],
          selected: state.diagnosisSelection,
          onChanged: controller.setDiagnosisSelection,
        ),
        const SizedBox(height: AppSpacing.xl),
        Text(
          'profile.onboarding.comorbiditiesLabel'.tr(),
          style: text.titleMedium,
        ),
        const SizedBox(height: AppSpacing.sm),
        ComorbidityChips(
          curated: const <(String, String)>[
            ('diabetes', 'Diabetes'),
            ('hypertension', 'Hypertension'),
            ('kidney_disease', 'Kidney disease'),
            ('high_cholesterol', 'High cholesterol'),
            ('previous_heart_attack', 'Previous heart attack'),
            ('stroke', 'Stroke'),
          ],
          selected: state.comorbidities,
          onChanged: controller.setComorbidities,
          allowOther: true,
          otherController: _otherComorbidityController,
        ),
      ],
    );
  }

  Widget _buildStep3(
    BuildContext context,
    OnboardingState state,
    OnboardingController controller,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _ReminderRow(
          title: 'profile.onboarding.medicationReminderTitle'.tr(),
          subtitle: 'profile.onboarding.medicationReminderSubtitle'.tr(),
          value: state.medicationReminderOn,
          onChanged: controller.setMedicationReminder,
        ),
        const SizedBox(height: AppSpacing.lg),
        _ReminderRow(
          title: 'profile.onboarding.vitalsReminderTitle'.tr(),
          subtitle: 'profile.onboarding.vitalsReminderSubtitle'.tr(),
          value: state.vitalsReminderOn,
          onChanged: controller.setVitalsReminder,
        ),
        const SizedBox(height: AppSpacing.lg),
        _ReminderRow(
          title: 'profile.onboarding.symptomReminderTitle'.tr(),
          subtitle: 'profile.onboarding.symptomReminderSubtitle'.tr(),
          value: state.symptomReminderOn,
          onChanged: controller.setSymptomReminder,
        ),
      ],
    );
  }
}

class _LanguageToggle extends StatelessWidget {
  const _LanguageToggle({required this.value, required this.onChanged});

  final String? value;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(
          child: _option(
            context,
            'en',
            'profile.onboarding.languageEnglish'.tr(),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: _option(
            context,
            'am',
            'profile.onboarding.languageAmharic'.tr(),
          ),
        ),
      ],
    );
  }

  Widget _option(BuildContext context, String code, String label) {
    final bool selected = value == code;
    return GestureDetector(
      onTap: () => onChanged(code),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? AppColors.ink : AppColors.surfaceAlt,
          borderRadius: BorderRadius.circular(AppSpacing.fieldRadius),
          border: Border.all(
            color: selected ? AppColors.ink : AppColors.border,
          ),
        ),
        child: Text(
          label,
          style: Theme.of(context).textTheme.titleMedium
              ?.copyWith(color: selected ? AppColors.surface : AppColors.ink),
        ),
      ),
    );
  }
}

class _ReminderRow extends StatelessWidget {
  const _ReminderRow({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    return Row(
      children: <Widget>[
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(title, style: text.titleMedium),
              const SizedBox(height: AppSpacing.xs),
              Text(subtitle, style: text.bodySmall),
            ],
          ),
        ),
        Switch(value: value, onChanged: onChanged),
      ],
    );
  }
}
