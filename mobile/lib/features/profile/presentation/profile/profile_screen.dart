import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../providers/profile_providers.dart';
import '../widgets/comorbidity_options.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(patientProfileProvider);

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
                  Text(
                    'profile.screen.headline'.tr(),
                    style: Theme.of(context).textTheme.headlineLarge,
                  ),
                  Text(
                    'profile.screen.subtitle'.tr(),
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
            Expanded(
              child: profileAsync.when(
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (error, _) => Center(
                  child: Text(
                    'profile.errors.loadFailed'.tr(),
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
                data: (profile) => SingleChildScrollView(
                  padding: const EdgeInsets.all(AppSpacing.gutter),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _SectionCard(
                        title: 'profile.sections.medical'.tr(),
                        rows: [
                          _InfoRow(
                            label: 'profile.fields.diagnosis'.tr(),
                            value: profile.chdStage ??
                                'profile.values.notSet'.tr(),
                          ),
                          _InfoRow(
                            label: 'profile.fields.diseaseHistory'.tr(),
                            value: profile.diseaseHistory ??
                                'profile.values.notSet'.tr(),
                          ),
                          _InfoRow(
                            label: 'profile.fields.managementPlan'.tr(),
                            value: profile.managementPlan ??
                                'profile.values.notSet'.tr(),
                          ),
                          _InfoRow(
                            label: 'profile.fields.comorbidities'.tr(),
                            value: describeComorbidities(
                              profile.comorbidities,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      _SectionCard(
                        title: 'profile.sections.personal'.tr(),
                        rows: [
                          _InfoRow(
                            label: 'profile.fields.birthYear'.tr(),
                            value: profile.birthYear?.toString() ??
                                'profile.values.notSet'.tr(),
                          ),
                          _InfoRow(
                            label: 'profile.fields.heightCm'.tr(),
                            value: profile.heightCm != null
                                ? '${profile.heightCm} cm'
                                : 'profile.values.notSet'.tr(),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      if (profile.goals != null)
                        _SectionCard(
                          title: 'profile.sections.goals'.tr(),
                          rows: [
                            _InfoRow(
                              label: 'profile.fields.targetBp'.tr(),
                              value: profile.goals!.bpSystolic != null
                                  ? '${profile.goals!.bpSystolic}/${profile.goals!.bpDiastolic ?? '-'}'
                                  : 'profile.values.notSet'.tr(),
                            ),
                            _InfoRow(
                              label: 'profile.fields.targetWeight'.tr(),
                              value: profile.goals!.targetWeightKg != null
                                  ? '${profile.goals!.targetWeightKg} kg'
                                  : 'profile.values.notSet'.tr(),
                            ),
                            _InfoRow(
                              label: 'profile.fields.stepsGoal'.tr(),
                              value:
                                  profile.goals!.stepsPerDay?.toString() ??
                                      'profile.values.notSet'.tr(),
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
              child: Column(
                children: [
                  FilledButton(
                    onPressed: () => context.pushNamed('profileEdit'),
                    child: Text('profile.actions.editProfile'.tr()),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  OutlinedButton(
                    onPressed: () => context.pushNamed('settings'),
                    child: Text('profile.actions.settings'.tr()),
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

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.rows});

  final String title;
  final List<_InfoRow> rows;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(AppSpacing.fieldRadius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: AppSpacing.sm),
          ...rows,
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ),
        ],
      ),
    );
  }
}
