import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/widgets.dart';
import '../../appointment_providers.dart';
import '../../domain/appointment.dart';
import '../appointment_text.dart';

class AppointmentsScreen extends ConsumerWidget {
  const AppointmentsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final List<Appointment> all =
        ref.watch(appointmentsProvider).value ?? const <Appointment>[];
    final DateTime now = DateTime.now();
    final List<Appointment> upcoming = <Appointment>[
      for (final Appointment a in all)
        if (!a.at.isBefore(now)) a,
    ];
    final List<Appointment> past = <Appointment>[
      for (final Appointment a in all.reversed)
        if (a.at.isBefore(now)) a,
    ];
    final TextTheme text = Theme.of(context).textTheme;

    return AppScaffold(
      title: 'appointments.title'.tr(),
      bottomBar: AppButton(
        key: const Key('appointmentsAdd'),
        label: 'appointments.add'.tr(),
        icon: Icons.add_rounded,
        onPressed: () => context.pushNamed(AppRoutes.appointmentNew),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
        children: <Widget>[
          Text('appointments.intro'.tr(), style: text.bodyMedium),
          const SizedBox(height: AppSpacing.lg),
          Text('appointments.upcoming'.tr(), style: text.titleMedium),
          const SizedBox(height: AppSpacing.sm),
          if (upcoming.isEmpty)
            EmptyState(
              icon: Icons.event_outlined,
              title: 'appointments.emptyTitle'.tr(),
              message: 'appointments.emptyBody'.tr(),
            )
          else
            for (final Appointment a in upcoming)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: AppointmentTile(appointment: a),
              ),
          if (past.isNotEmpty) ...<Widget>[
            const SizedBox(height: AppSpacing.lg),
            Text('appointments.past'.tr(), style: text.titleMedium),
            const SizedBox(height: AppSpacing.sm),
            for (final Appointment a in past)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: AppointmentTile(appointment: a, isPast: true),
              ),
          ],
        ],
      ),
    );
  }
}

/// One appointment: when, where, and how soon. Tapping it opens the editor.
class AppointmentTile extends StatelessWidget {
  const AppointmentTile({
    required this.appointment,
    this.isPast = false,
    super.key,
  });

  final Appointment appointment;
  final bool isPast;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    return SectionCard(
      key: Key('appointment_${appointment.id}'),
      onTap: () => context.pushNamed(
        AppRoutes.appointmentEdit,
        pathParameters: <String, String>{'id': appointment.id},
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: (isPast ? AppColors.textTertiary : AppColors.accent)
                  .withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.event_outlined,
              size: 18,
              color: isPast ? AppColors.textTertiary : AppColors.accent,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  appointmentWhen(context, appointment),
                  style: text.titleMedium,
                ),
                if (appointment.place.isNotEmpty) ...<Widget>[
                  const SizedBox(height: AppSpacing.xs),
                  Text(appointment.place, style: text.bodyMedium),
                ],
                if (appointment.note.isNotEmpty)
                  Text(
                    appointment.note,
                    style: text.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
              ],
            ),
          ),
          if (!isPast)
            Text(
              appointmentCountdown(appointment),
              style: text.labelLarge?.copyWith(color: AppColors.accent),
            ),
        ],
      ),
    );
  }
}
