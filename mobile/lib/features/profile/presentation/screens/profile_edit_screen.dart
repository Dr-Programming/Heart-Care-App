import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/widgets.dart';
import '../../domain/entities/health_goals.dart';
import '../../domain/entities/patient_profile.dart';
import '../../domain/validators.dart';
import '../../profile_providers.dart';
import '../controllers/profile_controller.dart';
import '../widgets/comorbidity_chips.dart';
import '../widgets/goal_field.dart';
import '../widgets/year_field.dart';

class ProfileEditScreen extends ConsumerStatefulWidget {
  const ProfileEditScreen({super.key});

  @override
  ConsumerState<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends ConsumerState<ProfileEditScreen> {
  static const String _chdStage = 'Coronary artery disease';

  static const List<(String, String)> _diagnosisCurated = <(String, String)>[
    ('heart_failure', 'Heart failure'),
    ('arrhythmia', 'Arrhythmia'),
  ];
  static const List<(String, String)> _comorbidityCurated = <(String, String)>[
    ('diabetes', 'Diabetes'),
    ('hypertension', 'Hypertension'),
    ('kidney_disease', 'Kidney disease'),
    ('high_cholesterol', 'High cholesterol'),
    ('previous_heart_attack', 'Previous heart attack'),
    ('stroke', 'Stroke'),
  ];

  late final TextEditingController _birthYearController;
  late final TextEditingController _heightController;
  late final TextEditingController _diseaseHistoryController;
  late final TextEditingController _managementPlanController;
  late final TextEditingController _otherComorbidityController;
  late final TextEditingController _bpSystolicController;
  late final TextEditingController _bpDiastolicController;
  late final TextEditingController _cholesterolController;
  late final TextEditingController _stepsController;
  late final TextEditingController _weightController;
  late final TextEditingController _dietNoteController;

  Set<String> _comorbidities = <String>{};

  String _userId = '';
  String? _preferredLanguage;

  String? _birthYearError;
  String? _heightError;
  String? _bpSystolicError;
  String? _bpDiastolicError;
  String? _cholesterolError;
  String? _stepsError;
  String? _weightError;
  bool _isSubmitting = false;

  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _birthYearController = TextEditingController();
    _heightController = TextEditingController();
    _diseaseHistoryController = TextEditingController();
    _managementPlanController = TextEditingController();
    _otherComorbidityController = TextEditingController();
    _bpSystolicController = TextEditingController();
    _bpDiastolicController = TextEditingController();
    _cholesterolController = TextEditingController();
    _stepsController = TextEditingController();
    _weightController = TextEditingController();
    _dietNoteController = TextEditingController();
  }

  @override
  void dispose() {
    _birthYearController.dispose();
    _heightController.dispose();
    _diseaseHistoryController.dispose();
    _managementPlanController.dispose();
    _otherComorbidityController.dispose();
    _bpSystolicController.dispose();
    _bpDiastolicController.dispose();
    _cholesterolController.dispose();
    _stepsController.dispose();
    _weightController.dispose();
    _dietNoteController.dispose();
    super.dispose();
  }

  void _prefill(PatientProfile profile) {
    if (_initialized) return;
    _initialized = true;

    _userId = profile.userId;
    _preferredLanguage = profile.preferredLanguage;

    _birthYearController.text = profile.birthYear?.toString() ?? '';
    _heightController.text = profile.heightCm?.toString() ?? '';
    _diseaseHistoryController.text = profile.diseaseHistory ?? '';
    _managementPlanController.text = profile.managementPlan ?? '';

    final Set<String> curatedKeys = <String>{
      for (final (String key, _) in _diagnosisCurated) key,
      for (final (String key, _) in _comorbidityCurated) key,
    };
    _comorbidities = profile.comorbidities.where(curatedKeys.contains).toSet();

    final List<String> other = profile.comorbidities
        .where((String c) => !curatedKeys.contains(c))
        .toList(growable: false);
    _otherComorbidityController.text = other.join(', ');

    final HealthGoals? goals = profile.goals;
    _bpSystolicController.text = goals?.bpSystolic?.toString() ?? '';
    _bpDiastolicController.text = goals?.bpDiastolic?.toString() ?? '';
    _cholesterolController.text = goals?.totalCholesterol?.toString() ?? '';
    _stepsController.text = goals?.stepsPerDay?.toString() ?? '';
    _weightController.text = goals?.targetWeightKg?.toString() ?? '';
    _dietNoteController.text = goals?.dietNote ?? '';
  }

  int? _parseInt(String text) =>
      text.trim().isEmpty ? null : int.tryParse(text.trim());

  double? _parseDouble(String text) =>
      text.trim().isEmpty ? null : double.tryParse(text.trim());

  String? _parseText(String text) => text.trim().isEmpty ? null : text.trim();

  Future<void> _handleSave() async {
    final int? birthYear = _parseInt(_birthYearController.text);
    final double? height = _parseDouble(_heightController.text);
    final String? birthYearErrorKey = validateBirthYear(birthYear);
    final String? heightErrorKey = validateHeightCm(height);

    final int? bpSystolic = _parseInt(_bpSystolicController.text);
    final int? bpDiastolic = _parseInt(_bpDiastolicController.text);
    final double? totalCholesterol = _parseDouble(_cholesterolController.text);
    final int? stepsPerDay = _parseInt(_stepsController.text);
    final double? targetWeightKg = _parseDouble(_weightController.text);
    final String? bpSystolicErrorKey = validateGoalValue(
      bpSystolic,
      fieldKey: 'bpSystolic',
    );
    final String? bpDiastolicErrorKey = validateGoalValue(
      bpDiastolic,
      fieldKey: 'bpDiastolic',
    );
    final String? cholesterolErrorKey = validateGoalValue(
      totalCholesterol,
      fieldKey: 'totalCholesterol',
    );
    final String? stepsErrorKey = validateGoalValue(
      stepsPerDay,
      fieldKey: 'stepsPerDay',
    );
    final String? weightErrorKey = validateGoalValue(
      targetWeightKg,
      fieldKey: 'targetWeightKg',
    );

    setState(() {
      _birthYearError = birthYearErrorKey?.tr();
      _heightError = heightErrorKey?.tr();
      _bpSystolicError = bpSystolicErrorKey?.tr();
      _bpDiastolicError = bpDiastolicErrorKey?.tr();
      _cholesterolError = cholesterolErrorKey?.tr();
      _stepsError = stepsErrorKey?.tr();
      _weightError = weightErrorKey?.tr();
    });
    if (birthYearErrorKey != null ||
        heightErrorKey != null ||
        bpSystolicErrorKey != null ||
        bpDiastolicErrorKey != null ||
        cholesterolErrorKey != null ||
        stepsErrorKey != null ||
        weightErrorKey != null) {
      return;
    }

    final Set<String> mergedComorbidities = <String>{
      ..._comorbidities,
      if (_otherComorbidityController.text.trim().isNotEmpty)
        _otherComorbidityController.text.trim(),
    };

    final HealthGoals goals = HealthGoals(
      bpSystolic: bpSystolic,
      bpDiastolic: bpDiastolic,
      totalCholesterol: totalCholesterol,
      stepsPerDay: stepsPerDay,
      targetWeightKg: targetWeightKg,
      dietNote: _parseText(_dietNoteController.text),
    );

    final PatientProfile profile = PatientProfile(
      userId: _userId,
      birthYear: birthYear,
      preferredLanguage: _preferredLanguage,
      heightCm: height,
      chdStage: _chdStage,
      diseaseHistory: _parseText(_diseaseHistoryController.text),
      comorbidities: mergedComorbidities.toList(growable: false),
      managementPlan: _parseText(_managementPlanController.text),
      goals: goals,
      updatedAt: null,
    );

    setState(() => _isSubmitting = true);
    await ref.read(profileRepositoryProvider).saveProfile(profile);
    if (!mounted) return;
    ref.invalidate(profileControllerProvider);
    setState(() => _isSubmitting = false);
    Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<PatientProfile> profileState = ref.watch(
      profileControllerProvider,
    );

    final bool hasProfile = profileState.hasValue;

    return AppScaffold(
      title: 'profile.edit.title'.tr(),
      scrollable: true,
      bottomBar: hasProfile
          ? AppButton(
              label: 'common.save'.tr(),
              isLoading: _isSubmitting,
              onPressed: _isSubmitting ? null : _handleSave,
            )
          : null,
      body: switch (profileState) {
        AsyncData<PatientProfile>(value: final profile) => _buildForm(
          context,
          profile,
        ),
        AsyncError() => Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxl),
          child: EmptyState(
            icon: Icons.error_outline_rounded,
            title: 'errors.generic'.tr(),
          ),
        ),
        _ => const Padding(
          padding: EdgeInsets.symmetric(vertical: AppSpacing.xxl),
          child: Center(child: CircularProgressIndicator()),
        ),
      },
    );
  }

  Widget _buildForm(BuildContext context, PatientProfile profile) {
    _prefill(profile);
    final TextTheme text = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        SectionCard(
          title: 'profile.sections.personal'.tr(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              YearField(
                key: const Key('profile_edit_birthYear_field'),
                controller: _birthYearController,
                label: 'profile.fields.birthYear'.tr(),
                errorText: _birthYearError,
              ),
              const SizedBox(height: AppSpacing.lg),
              AppTextField(
                key: const Key('profile_edit_height_field'),
                label: 'profile.onboarding.heightLabel'.tr(),
                controller: _heightController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: <TextInputFormatter>[
                  FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*$')),
                ],
                errorText: _heightError,
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        SectionCard(
          title: 'profile.sections.medical'.tr(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text(
                'profile.onboarding.diagnosisLabel'.tr(),
                style: text.titleMedium,
              ),
              const SizedBox(height: AppSpacing.sm),
              ComorbidityChips(
                key: const Key('profile_edit_diagnosis_chips'),
                curated: _diagnosisCurated,
                selected: _comorbidities,
                onChanged: (Set<String> next) =>
                    setState(() => _comorbidities = next),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                'profile.onboarding.comorbiditiesLabel'.tr(),
                style: text.titleMedium,
              ),
              const SizedBox(height: AppSpacing.sm),
              ComorbidityChips(
                key: const Key('profile_edit_comorbidity_chips'),
                curated: _comorbidityCurated,
                selected: _comorbidities,
                onChanged: (Set<String> next) =>
                    setState(() => _comorbidities = next),
                allowOther: true,
                otherController: _otherComorbidityController,
              ),
              const SizedBox(height: AppSpacing.lg),
              AppTextField(
                key: const Key('profile_edit_diseaseHistory_field'),
                label: 'profile.fields.diseaseHistory'.tr(),
                controller: _diseaseHistoryController,
                maxLines: 3,
                textInputAction: TextInputAction.newline,
              ),
              const SizedBox(height: AppSpacing.lg),
              AppTextField(
                key: const Key('profile_edit_managementPlan_field'),
                label: 'profile.fields.managementPlan'.tr(),
                controller: _managementPlanController,
                maxLines: 3,
                textInputAction: TextInputAction.newline,
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        SectionCard(
          title: 'profile.sections.goals'.tr(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              GoalField(
                key: const Key('profile_edit_bpSystolic_field'),
                controller: _bpSystolicController,
                label: 'profile.fields.bpSystolicTarget'.tr(),
                suffixText: 'mmHg',
                keyboardType: TextInputType.number,
                errorText: _bpSystolicError,
              ),
              const SizedBox(height: AppSpacing.lg),
              GoalField(
                key: const Key('profile_edit_bpDiastolic_field'),
                controller: _bpDiastolicController,
                label: 'profile.fields.bpDiastolicTarget'.tr(),
                suffixText: 'mmHg',
                keyboardType: TextInputType.number,
                errorText: _bpDiastolicError,
              ),
              const SizedBox(height: AppSpacing.lg),
              GoalField(
                key: const Key('profile_edit_cholesterol_field'),
                controller: _cholesterolController,
                label: 'profile.fields.cholesterolTarget'.tr(),
                suffixText: 'mg/dL',
                errorText: _cholesterolError,
              ),
              const SizedBox(height: AppSpacing.lg),
              GoalField(
                key: const Key('profile_edit_steps_field'),
                controller: _stepsController,
                label: 'profile.fields.stepsTarget'.tr(),
                suffixText: 'steps/day',
                keyboardType: TextInputType.number,
                errorText: _stepsError,
              ),
              const SizedBox(height: AppSpacing.lg),
              GoalField(
                key: const Key('profile_edit_weight_field'),
                controller: _weightController,
                label: 'profile.fields.weightTarget'.tr(),
                errorText: _weightError,
              ),
              const SizedBox(height: AppSpacing.lg),
              AppTextField(
                key: const Key('profile_edit_dietNote_field'),
                label: 'profile.fields.dietNote'.tr(),
                controller: _dietNoteController,
                maxLines: 3,
                textInputAction: TextInputAction.newline,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
