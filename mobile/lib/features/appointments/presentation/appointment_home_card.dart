import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/routes.dart';
import '../../../core/shell/home_card.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/widgets.dart';
import '../appointment_providers.dart';
import '../domain/appointment.dart';
import 'appointment_text.dart';

/// The next clinic visit, how to prepare once it is close, and the visit
/// summary to show the clinician.
HomeCard appointmentHomeCard() => HomeCard(
  id: 'appointments',
  order: 400,
  builder: (BuildContext context) => const _AppointmentCard(),
);

/// A visit this close gets the preparation list.
const int prepareDaysBefore = 2;

class _AppointmentCard extends ConsumerWidget {
  const _AppointmentCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final List<Appointment> all =
        ref.watch(appointmentsProvider).value ?? const <Appointment>[];
    final DateTime now = DateTime.now();
    Appointment? next;
    for (final Appointment a in all) {
      if (!a.at.isBefore(now)) {
        next = a;
        break;
      }
    }
    final TextTheme text = Theme.of(context).textTheme;
    final bool prepare = next != null && daysUntil(next) <= prepareDaysBefore;

    return AccentCard(
      key: const Key('appointmentHomeCard'),
      accent: AppColors.accent,
      icon: Icons.event_outlined,
      title: 'appointments.homeTitle'.tr(),
      action: AppButton(
        label: (next == null ? 'appointments.add' : 'appointments.seeAll').tr(),
        variant: AppButtonVariant.text,
        expand: false,
        onPressed: () => context.pushNamed(
          next == null ? AppRoutes.appointmentNew : AppRoutes.appointments,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if (next == null)
            Text('appointments.homeEmpty'.tr(), style: text.bodyMedium)
          else ...<Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    appointmentWhen(context, next),
                    style: text.titleMedium,
                  ),
                ),
                Text(
                  appointmentCountdown(next),
                  style: text.labelLarge?.copyWith(color: AppColors.accent),
                ),
              ],
            ),
            if (next.place.isNotEmpty) Text(next.place, style: text.bodyMedium),
            if (prepare) ...<Widget>[
              const SizedBox(height: AppSpacing.md),
              Text('appointments.prepare.title'.tr(), style: text.labelLarge),
              const SizedBox(height: AppSpacing.xs),
              for (final String item in const <String>[
                'medicines',
                'readings',
                'questions',
              ])
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      const Padding(
                        padding: EdgeInsets.only(top: 2),
                        child: Icon(
                          Icons.check_circle_outline,
                          size: 18,
                          color: AppColors.success,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          'appointments.prepare.$item'.tr(),
                          style: text.bodyMedium,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ],
          const SizedBox(height: AppSpacing.md),
          AppButton(
            key: const Key('appointmentHomeSummary'),
            label: 'appointments.openSummary'.tr(),
            icon: Icons.assignment_outlined,
            variant: AppButtonVariant.secondary,
            onPressed: () => context.pushNamed(AppRoutes.visitSummary),
          ),
        ],
      ),
    );
  }
}
