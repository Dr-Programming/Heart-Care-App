import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/widgets.dart';

import '../../../core/utils/date_formatter.dart';
import '../domain/appointment.dart';

/// "Tue, Oct 6 · 10:00".
String appointmentWhen(BuildContext context, Appointment appointment) =>
    '${DateFormat.MMMEd(context.locale.languageCode).format(appointment.at)} · '
    '${DateFormatter.toClock(appointment.at)}';

/// "Today", "Tomorrow", "In 3 days".
String appointmentCountdown(Appointment appointment, {DateTime? now}) {
  final int days = daysUntil(appointment, now: now);
  if (days <= 0) return 'appointments.today'.tr();
  if (days == 1) return 'appointments.tomorrow'.tr();
  return 'appointments.inDays'.tr(namedArgs: <String, String>{'days': '$days'});
}
