import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/core_providers.dart';
import '../shell/home_card.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../widgets/widgets.dart';
import 'clinic_call.dart';
import 'clinic_contact.dart';
import 'urgent_pattern.dart';

/// Top of Home while readings keep coming in urgent: asks the patient to
/// call their clinic. Hidden once dismissed, until the next urgent reading.
HomeCard urgentClinicHomeCard() => HomeCard(
  id: 'clinic-urgent',
  order: -2,
  spaced: false,
  builder: (BuildContext context) => const _UrgentClinicCard(),
);

/// The patient's clinic, with a quick way to call it or to add it.
HomeCard clinicHomeCard() => HomeCard(
  id: 'clinic',
  order: 350,
  builder: (BuildContext context) => const _ClinicCard(),
);

class _UrgentClinicCard extends ConsumerWidget {
  const _UrgentClinicCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final UrgentPattern pattern =
        ref.watch(urgentPatternProvider).value ?? UrgentPattern.none;
    if (!pattern.shouldRemind) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: _card(context, ref, pattern),
    );
  }

  Widget _card(BuildContext context, WidgetRef ref, UrgentPattern pattern) {
    return AccentCard(
      key: const Key('clinicUrgentCard'),
      accent: AppColors.critical,
      icon: Icons.local_hospital_outlined,
      title: 'clinic.reminder.title'.tr(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            'clinic.reminder.body'.tr(
              namedArgs: <String, String>{'count': '${pattern.count}'},
            ),
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: AppSpacing.md),
          AppButton(
            label: 'clinic.reminder.call'.tr(),
            icon: Icons.call,
            onPressed: () => showClinicCallOptions(
              context,
              ref.read(clinicContactStoreProvider),
            ),
          ),
          AppButton(
            label: 'clinic.reminder.dismiss'.tr(),
            variant: AppButtonVariant.text,
            onPressed: () =>
                dismissClinicReminder(ref.read(appDatabaseProvider)),
          ),
        ],
      ),
    );
  }
}

class _ClinicCard extends ConsumerWidget {
  const _ClinicCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ClinicContact? clinic = ref.watch(clinicContactProvider).value;
    final ClinicContactStore store = ref.read(clinicContactStoreProvider);
    final TextTheme text = Theme.of(context).textTheme;
    return AccentCard(
      key: const Key('clinicHomeCard'),
      accent: AppColors.accent,
      icon: Icons.local_hospital_outlined,
      title: 'clinic.homeTitle'.tr(),
      action: clinic == null
          ? null
          : AppButton(
              label: 'common.edit'.tr(),
              variant: AppButtonVariant.text,
              expand: false,
              onPressed: () => showClinicEditor(context, store),
            ),
      child: clinic == null
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Text('clinic.homeEmpty'.tr(), style: text.bodyMedium),
                const SizedBox(height: AppSpacing.md),
                AppButton(
                  key: const Key('clinicHomeAdd'),
                  label: 'clinic.add'.tr(),
                  icon: Icons.add,
                  variant: AppButtonVariant.secondary,
                  onPressed: () => showClinicEditor(context, store),
                ),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Text(clinic.displayName, style: text.titleMedium),
                if (clinic.name.isNotEmpty)
                  Text(clinic.phone, style: text.bodyMedium),
                const SizedBox(height: AppSpacing.md),
                AppButton(
                  key: const Key('clinicHomeCall'),
                  label: 'clinic.callCta'.tr(),
                  icon: Icons.call,
                  variant: AppButtonVariant.secondary,
                  onPressed: () => showClinicCallOptions(context, store),
                ),
              ],
            ),
    );
  }
}
