import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/db/app_database.dart' hide Medication;
import '../../../../core/error/failure.dart';
import '../../../../core/providers/core_providers.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/widgets.dart';
import '../../domain/entities/medication.dart';
import '../controllers/medication_list_controller.dart';

class _NotificationsEnabledController extends AsyncNotifier<bool> {
  @override
  Future<bool> build() async {
    final String? raw = await ref
        .watch(appDatabaseProvider)
        .preferencesDao
        .get(PreferenceKeys.notificationsEnabled);
    return raw != 'false';
  }

  Future<void> setEnabled(bool value) async {
    await ref
        .read(appDatabaseProvider)
        .preferencesDao
        .set(PreferenceKeys.notificationsEnabled, value.toString());
    ref.invalidateSelf();
  }
}

final AsyncNotifierProvider<_NotificationsEnabledController, bool>
_notificationsEnabledProvider =
    AsyncNotifierProvider<_NotificationsEnabledController, bool>(
      _NotificationsEnabledController.new,
    );

class ReminderSettingsScreen extends ConsumerWidget {
  const ReminderSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<MedicationListState> meds = ref.watch(medicationListControllerProvider);
    final AsyncValue<bool> enabled = ref.watch(_notificationsEnabledProvider);

    return AppScaffold(
      title: 'meds.reminders.title'.tr(),
      body: meds.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (Object e, StackTrace _) =>
            ErrorView(failure: e is Failure ? e : UnknownFailure(e.toString())),
        data: (MedicationListState data) => ListView(
          children: <Widget>[
            SwitchListTile(
              title: Text('meds.reminders.enabled'.tr()),
              value: enabled.value ?? true,
              onChanged: (bool value) =>
                  ref.read(_notificationsEnabledProvider.notifier).setEnabled(value),
            ),
            const SizedBox(height: AppSpacing.lg),
            for (final Medication medication in data.medications)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                child: SectionCard(
                  title: medication.name,
                  child: Text(
                    '${medication.scheduleTimes.join(' · ')} · ${'meds.reminders.followUp'.tr()}',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
