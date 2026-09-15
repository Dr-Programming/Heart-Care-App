import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax/iconsax.dart';

import '../../../../core/shell/home_card.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/widgets.dart';
import '../../domain/entities/health_goals.dart';
import '../../domain/entities/patient_profile.dart';
import '../controllers/profile_controller.dart';

final HomeCard profileHomeCard = HomeCard(
  id: 'profile-summary',
  order: 300,
  builder: (context) => const _ProfileHomeCardBody(),
);

class _ProfileHomeCardBody extends ConsumerWidget {
  const _ProfileHomeCardBody();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<PatientProfile> asyncProfile = ref.watch(
      profileControllerProvider,
    );

    final PatientProfile? profile = asyncProfile.asData?.value;

    return AccentCard(
      accent: AppColors.warning,
      icon: Iconsax.user,
      title: 'profile.home.title'.tr(),
      child: _ProfileSummary(profile: profile),
    );
  }
}

class _ProfileSummary extends StatelessWidget {
  const _ProfileSummary({required this.profile});

  final PatientProfile? profile;

  bool get _isUnset =>
      profile == null ||
      (profile!.birthYear == null &&
          profile!.heightCm == null &&
          profile!.comorbidities.isEmpty);

  String get _chdStageValue {
    final String? stage = profile?.chdStage;
    return (stage == null || stage.trim().isEmpty) ? '—' : stage;
  }

  String get _goalValue {
    final HealthGoals? goals = profile?.goals;
    if (goals == null) return '—';
    if (goals.stepsPerDay != null) {
      return 'profile.home.goalSteps'.tr(
        namedArgs: <String, String>{'value': goals.stepsPerDay.toString()},
      );
    }
    if (goals.bpSystolic != null || goals.bpDiastolic != null) {
      return 'profile.fields.bpTargetValue'.tr(
        namedArgs: <String, String>{
          'systolic': goals.bpSystolic?.toString() ?? '—',
          'diastolic': goals.bpDiastolic?.toString() ?? '—',
        },
      );
    }
    if (goals.targetWeightKg != null) {
      return 'profile.home.goalWeight'.tr(
        namedArgs: <String, String>{'value': goals.targetWeightKg.toString()},
      );
    }
    return '—';
  }

  @override
  Widget build(BuildContext context) {
    if (_isUnset) {
      return Text(
        'profile.home.emptyMessage'.tr(),
        style: Theme.of(context).textTheme.bodyMedium,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        _SummaryRow(
          label: 'profile.fields.chdStage'.tr(),
          value: _chdStageValue,
        ),
        const SizedBox(height: AppSpacing.xs),
        _SummaryRow(label: 'profile.home.goalLabel'.tr(), value: _goalValue),
      ],
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Expanded(child: Text(label, style: text.bodySmall)),
        Expanded(
          child: Text(value, style: text.bodyMedium, textAlign: TextAlign.end),
        ),
      ],
    );
  }
}
