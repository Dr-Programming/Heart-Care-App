// Author: Ihab Al-Nasheei
// Last updated by: Ihab Al-Nasheei

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/notifications/sms_sender.dart';
import '../../../core/providers/core_providers.dart';
import '../data/caregiver_notify_store.dart';
import '../domain/entities/medication.dart';
import '../medication_providers.dart';

/// A dose marked "Missed" for a medicine with "Notify caregiver" on: the
/// caregiver gets a text message right away.
class CaregiverMissedDoseAlert {
  const CaregiverMissedDoseAlert(this._ref);

  final Ref _ref;

  /// True when a text was sent (or, on iOS, opened in Messages).
  Future<bool> send(Medication medication, {required String time}) async {
    try {
      final CaregiverNotifySettings settings = await _ref
          .read(caregiverNotifyStoreProvider)
          .get(medication.clientRecordId);
      final String phone = settings.phone.trim();
      if (!settings.enabled || phone.isEmpty) return false;

      final String name =
          (await _ref.read(appDatabaseProvider).cachedUserDao.current())
              ?.name ??
          '';
      final String dose = medication.doseMg % 1 == 0
          ? medication.doseMg.toStringAsFixed(0)
          : medication.doseMg.toString();
      final String message = 'meds.caregiverSms.message'.tr(
        namedArgs: <String, String>{
          'name': name,
          'medicine': medication.name,
          'dose': dose,
          'time': time,
        },
      );
      return await _ref
          .read(smsSenderProvider)
          .send(phone: phone, message: message);
    } on Object {
      return false;
    }
  }
}

final Provider<CaregiverMissedDoseAlert> caregiverMissedDoseAlertProvider =
    Provider<CaregiverMissedDoseAlert>(CaregiverMissedDoseAlert.new);
