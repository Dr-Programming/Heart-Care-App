import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/providers/core_providers.dart';
import '../../../../core/widgets/widgets.dart';

/// The message for a sign-in refused to protect the previous patient's data.
String patientSwitchMessage(PatientSwitchFailure failure) {
  final String name =
      failure.previousPatient ?? 'auth.switch.anotherPatient'.tr();
  if (failure.needsConnection) {
    return 'auth.switch.needsConnection'.tr(
      namedArgs: <String, String>{'name': name},
    );
  }
  return plural(
    'auth.switch.unsent',
    failure.unsentRecords,
    namedArgs: <String, String>{'name': name},
  );
}

/// After [failure] for unsent records: asks whether to delete them and sign
/// the new patient in. Returns true once they are deleted, so the caller can
/// try again.
Future<bool> offerToDiscardUnsent(
  BuildContext context,
  WidgetRef ref,
  PatientSwitchFailure failure,
) async {
  if (failure.needsConnection || failure.unsentRecords == 0) return false;
  final bool confirmed = await ConfirmSheet.show(
    context,
    title: 'auth.switch.discardTitle'.tr(),
    message:
        '${patientSwitchMessage(failure)}\n\n${'auth.switch.discardBody'.tr()}',
    confirmLabel: 'auth.switch.discardConfirm'.tr(),
    cancelLabel: 'auth.switch.keep'.tr(),
    isDestructive: true,
  );
  if (!confirmed) return false;
  await ref.read(discardUnsentRecordsProvider)();
  return true;
}
