import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/localization/language.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../domain/entities/health_goals.dart';
import '../../domain/entities/patient_profile.dart';
import '../../domain/validators.dart';
import '../language_actions.dart';
import '../providers/profile_providers.dart';
import '../widgets/comorbidity_options.dart';
import '../widgets/selectable_chip.dart';

class ProfileEditScreen extends ConsumerStatefulWidget {
  const ProfileEditScreen({super.key});

  @override
  ConsumerState<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends ConsumerState<ProfileEditScreen> {
  final _formKey = GlobalKey<FormState>();
  final _birthYearController = TextEditingController();
  final _heightController = TextEditingController();
  final _chdStageController = TextEditingController();
  final _diseaseHistoryController = TextEditingController();
  final _managementPlanController = TextEditingController();
  final _otherComorbidityController = TextEditingController();
  final _systolicController = TextEditingController();
  final _diastolicController = TextEditingController();
  final _weightController = TextEditingController();
  final _stepsController = TextEditingController();
  final _cholesterolController = TextEditingController();
  final _dietNoteController = TextEditingController();

  bool _initialized = false;
  bool _saving = false;
  AppLanguage _language = AppLanguage.en;
  final Set<String> _selectedComorbidities = {};

  void _prefill(PatientProfile profile) {
    _birthYearController.text = profile.birthYear?.toString() ?? '';
    _heightController.text = profile.heightCm?.toString() ?? '';
    _chdStageController.text = profile.chdStage ?? '';
    _diseaseHistoryController.text = profile.diseaseHistory ?? '';
    _managementPlanController.text = profile.managementPlan ?? '';
    _language =
        AppLanguage.fromCode(profile.preferredLanguage) ?? AppLanguage.en;

    final split = splitComorbidities(profile.comorbidities);
    _selectedComorbidities
      ..clear()
      ..addAll(split.selected);
    _otherComorbidityController.text = split.otherText;

    if (profile.goals != null) {
      _systolicController.text = profile.goals!.bpSystolic?.toString() ?? '';
      _diastolicController.text =
          profile.goals!.bpDiastolic?.toString() ?? '';
      _weightController.text =
          profile.goals!.targetWeightKg?.toString() ?? '';
      _stepsController.text = profile.goals!.stepsPerDay?.toString() ?? '';
      _cholesterolController.text =
          profile.goals!.totalCholesterol?.toString() ?? '';
      _dietNoteController.text = profile.goals!.dietNote ?? '';
    }
  }

  @override
  void dispose() {
    _birthYearController.dispose();
    _heightController.dispose();
    _chdStageController.dispose();
    _diseaseHistoryController.dispose();
    _managementPlanController.dispose();
    _otherComorbidityController.dispose();
    _systolicController.dispose();
    _diastolicController.dispose();
    _weightController.dispose();
    _stepsController.dispose();
    _cholesterolController.dispose();
    _dietNoteController.dispose();
    super.dispose();
  }

  int? _int(String v) => v.isEmpty ? null : int.tryParse(v);
  double? _double(String v) => v.isEmpty ? null : double.tryParse(v);

  Future<void> _selectLanguage(AppLanguage language) async {
    setState(() => _language = language);
    await changeAppLanguage(context, ref, language);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);

    // Full-replace PUT: this must carry every field, not just the ones the
    // user touched, or the untouched fields get cleared server-side.
    final updated = PatientProfile(
      birthYear: _int(_birthYearController.text),
      preferredLanguage: _language.code,
      heightCm: _double(_heightController.text),
      chdStage: _chdStageController.text.isEmpty
          ? null
          : _chdStageController.text,
      diseaseHistory: _diseaseHistoryController.text.isEmpty
          ? null
          : _diseaseHistoryController.text,
      managementPlan: _managementPlanController.text.isEmpty
          ? null
          : _managementPlanController.text,
      comorbidities: mergeComorbidities(
        _selectedComorbidities,
        _otherComorbidityController.text,
      ),
      goals: HealthGoals(
        bpSystolic: _int(_systolicController.text),
        bpDiastolic: _int(_diastolicController.text),
        targetWeightKg: _double(_weightController.text),
        stepsPerDay: _int(_stepsController.text),
        totalCholesterol: _double(_cholesterolController.text),
        dietNote: _dietNoteController.text.isEmpty
            ? null
            : _dietNoteController.text,
      ),
    );

    await ref.read(saveProfileProvider)(updated);
    ref.invalidate(patientProfileProvider);

    if (mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(patientProfileProvider);

    return Scaffold(
      body: SafeArea(
        child: profileAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Center(
            child: Text(
              'profile.errors.loadFailed'.tr(),
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
          data: (profile) {
            if (!_initialized) {
              _prefill(profile);
              _initialized = true;
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.gutter,
                    vertical: AppSpacing.lg,
                  ),
                  color: AppColors.headerBand,
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => context.pop(),
                        icon: const Icon(Icons.arrow_back),
                        color: AppColors.ink,
                      ),
                      Expanded(
                        child: Text(
                          'profile.actions.editProfile'.tr(),
                          style: Theme.of(context).textTheme.headlineLarge,
                        ),
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
                            'profile.fields.birthYear'.tr(),
                            style: Theme.of(context).textTheme.bodyLarge,
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          TextFormField(
                            controller: _birthYearController,
                            keyboardType: TextInputType.number,
                            validator: (v) {
                              if (v == null || v.isEmpty) return null;
                              final y = int.tryParse(v);
                              if (y == null) return 'errors.invalidNumber'.tr();
                              final r = ProfileValidators.birthYear(y);
                              return r.isValid ? null : r.errorMessage!.tr();
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
                            keyboardType:
                                const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            validator: (v) {
                              if (v == null || v.isEmpty) return null;
                              final h = double.tryParse(v);
                              if (h == null) return 'errors.invalidNumber'.tr();
                              final r = ProfileValidators.heightCm(h);
                              return r.isValid ? null : r.errorMessage!.tr();
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
                          const SizedBox(height: AppSpacing.xl),
                          Text(
                            'profile.fields.diagnosis'.tr(),
                            style: Theme.of(context).textTheme.bodyLarge,
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          TextFormField(
                            controller: _chdStageController,
                            maxLength: 50,
                            validator: (v) {
                              final r = ProfileValidators.chdStage(v);
                              return r.isValid ? null : r.errorMessage!.tr();
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
                              hintText:
                                  'profile.fields.managementPlanHint'.tr(),
                            ),
                          ),
                          const SizedBox(height: AppSpacing.xl),
                          Text(
                            'profile.fields.comorbidities'.tr(),
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
                            controller: _otherComorbidityController,
                            decoration: InputDecoration(
                              hintText:
                                  'profile.fields.comorbidityOther'.tr(),
                            ),
                          ),
                          const SizedBox(height: AppSpacing.xl),
                          Text(
                            'profile.sections.goals'.tr(),
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
                                    hintText:
                                        'profile.fields.systolicHint'.tr(),
                                  ),
                                ),
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              Expanded(
                                child: TextFormField(
                                  controller: _diastolicController,
                                  keyboardType: TextInputType.number,
                                  decoration: InputDecoration(
                                    hintText:
                                        'profile.fields.diastolicHint'.tr(),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.md),
                          TextFormField(
                            controller: _weightController,
                            keyboardType:
                                const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: InputDecoration(
                              hintText: 'profile.fields.targetWeightHint'.tr(),
                            ),
                            validator: (v) {
                              if (v == null || v.isEmpty) return null;
                              final r = ProfileValidators.nonNegative(
                                double.tryParse(v),
                              );
                              return r.isValid ? null : r.errorMessage!.tr();
                            },
                          ),
                          const SizedBox(height: AppSpacing.md),
                          TextFormField(
                            controller: _stepsController,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              hintText: 'profile.fields.stepsGoalHint'.tr(),
                            ),
                            validator: (v) {
                              if (v == null || v.isEmpty) return null;
                              final r = ProfileValidators.nonNegative(
                                int.tryParse(v),
                              );
                              return r.isValid ? null : r.errorMessage!.tr();
                            },
                          ),
                          const SizedBox(height: AppSpacing.md),
                          TextFormField(
                            controller: _cholesterolController,
                            keyboardType:
                                const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: InputDecoration(
                              hintText:
                                  'profile.fields.targetCholesterolHint'.tr(),
                            ),
                          ),
                          const SizedBox(height: AppSpacing.md),
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
                  padding: const EdgeInsets.all(AppSpacing.gutter),
                  child: FilledButton(
                    onPressed: _saving ? null : _save,
                    child: _saving
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text('profile.actions.saveChanges'.tr()),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
