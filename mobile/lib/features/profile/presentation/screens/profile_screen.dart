import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/db/app_database.dart' show CachedUser;
import '../../../../core/providers/core_providers.dart';
import '../../../../core/router/routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/widgets.dart';
import '../../domain/entities/health_goals.dart';
import '../../domain/entities/patient_profile.dart';
import '../controllers/profile_controller.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<PatientProfile> profileState = ref.watch(
      profileControllerProvider,
    );
    final AsyncValue<CachedUser?> cachedUser = ref.watch(cachedUserProvider);

    return AppScaffold.banded(
      showBack: false,
      scrollable: true,
      bandChild: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Text(
                'profile.title'.tr(),
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              Row(
                children: <Widget>[
                  IconButton(
                    icon: const Icon(Icons.edit_outlined),
                    tooltip: 'common.edit'.tr(),
                    onPressed: () => context.pushNamed(AppRoutes.profileEdit),
                  ),
                  IconButton(
                    icon: const Icon(Icons.settings_outlined),
                    tooltip: 'profile.actions.settings'.tr(),
                    onPressed: () => context.pushNamed(AppRoutes.settings),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
      body: switch (profileState) {
        AsyncData<PatientProfile>(value: final profile) => _ProfileBody(
          profile: profile,
          name: cachedUser.value?.name,
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
}

class _ProfileBody extends StatelessWidget {
  const _ProfileBody({required this.profile, required this.name});

  final PatientProfile profile;
  final String? name;

  bool get _isEmpty =>
      profile.birthYear == null &&
      profile.heightCm == null &&
      profile.comorbidities.isEmpty;

  @override
  Widget build(BuildContext context) {
    if (_isEmpty) {
      return EmptyState(
        icon: Icons.person_outline_rounded,
        title: 'profile.empty.title'.tr(),
        message: 'profile.empty.message'.tr(),
        actionLabel: 'profile.empty.action'.tr(),
        onAction: () => context.pushNamed(AppRoutes.profileEdit),
      );
    }

    final HealthGoals? goals = profile.goals;
    final bool hasGoals =
        goals != null &&
        (goals.bpSystolic != null ||
            goals.bpDiastolic != null ||
            goals.totalCholesterol != null ||
            goals.stepsPerDay != null ||
            goals.targetWeightKg != null ||
            (goals.dietNote != null && goals.dietNote!.trim().isNotEmpty));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        SectionCard(
          title: 'profile.sections.personal'.tr(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              _InfoRow(label: 'profile.fields.name'.tr(), value: name),
              _InfoRow(
                label: 'profile.fields.birthYear'.tr(),
                value: profile.birthYear?.toString(),
              ),
              _InfoRow(
                label: 'profile.fields.height'.tr(),
                value: profile.heightCm == null
                    ? null
                    : 'profile.fields.heightValue'.tr(
                        namedArgs: <String, String>{
                          'value': _formatHeight(profile.heightCm!),
                        },
                      ),
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
              _InfoRow(
                label: 'profile.fields.chdStage'.tr(),
                value: profile.chdStage,
              ),
              if (profile.comorbidities.isNotEmpty) ...<Widget>[
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'profile.fields.comorbidities'.tr(),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: AppSpacing.xs),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: <Widget>[
                    for (final String comorbidity in profile.comorbidities)
                      Chip(
                        label: Text(_humanize(comorbidity)),
                        backgroundColor: AppColors.surfaceAlt,
                        side: const BorderSide(color: AppColors.border),
                      ),
                  ],
                ),
              ],
              _InfoRow(
                label: 'profile.fields.diseaseHistory'.tr(),
                value: profile.diseaseHistory,
              ),
            ],
          ),
        ),
        if (hasGoals) ...<Widget>[
          const SizedBox(height: AppSpacing.lg),
          SectionCard(
            title: 'profile.sections.goals'.tr(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                if (goals.bpSystolic != null || goals.bpDiastolic != null)
                  _InfoRow(
                    label: 'profile.fields.bpTarget'.tr(),
                    value: 'profile.fields.bpTargetValue'.tr(
                      namedArgs: <String, String>{
                        'systolic': goals.bpSystolic?.toString() ?? '—',
                        'diastolic': goals.bpDiastolic?.toString() ?? '—',
                      },
                    ),
                  ),
                _InfoRow(
                  label: 'profile.fields.cholesterolTarget'.tr(),
                  value: goals.totalCholesterol?.toString(),
                ),
                _InfoRow(
                  label: 'profile.fields.stepsTarget'.tr(),
                  value: goals.stepsPerDay?.toString(),
                ),
                _InfoRow(
                  label: 'profile.fields.weightTarget'.tr(),
                  value: goals.targetWeightKg?.toString(),
                ),
                _InfoRow(
                  label: 'profile.fields.dietNote'.tr(),
                  value: goals.dietNote,
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  static String _formatHeight(double cm) =>
      cm == cm.roundToDouble() ? cm.toStringAsFixed(0) : cm.toString();

  static String _humanize(String value) {
    final String spaced = value.replaceAll('_', ' ');
    if (spaced.isEmpty) return spaced;
    return spaced[0].toUpperCase() + spaced.substring(1);
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String? value;

  @override
  Widget build(BuildContext context) {
    if (value == null || value!.trim().isEmpty) return const SizedBox.shrink();
    final TextTheme text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Expanded(child: Text(label, style: text.bodySmall)),
          Expanded(
            child: Text(
              value!,
              style: text.bodyMedium,
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }
}
