import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/widgets.dart';
import '../../domain/entities/medication.dart';
import '../../medication_providers.dart';
import '../controllers/medication_form_controller.dart';
import '../widgets/time_list_field.dart';

// `FutureProvider.autoDispose.family<StateT, ArgT>(...)` returns
// `FutureProviderFamily<StateT, ArgT>` in riverpod 3.4.2, but that type is
// an internal implementation detail not exported from the public barrel
// (neither is `AutoDisposeFutureProviderFamily`, which doesn't exist at
// all in this package version) — so the variable is left untyped and
// inferred rather than explicitly annotated.
final _medicationByIdProvider =
    FutureProvider.autoDispose.family<Medication?, String>((Ref ref, String id) async {
  final List<Medication> medications =
      await ref.watch(medicationRepositoryProvider).allMedications(includeInactive: true);
  for (final Medication m in medications) {
    if (m.clientRecordId == id) return m;
  }
  return null;
});

class MedicationFormScreen extends ConsumerStatefulWidget {
  const MedicationFormScreen({this.editingId, super.key});

  final String? editingId;

  @override
  ConsumerState<MedicationFormScreen> createState() => _MedicationFormScreenState();
}

class _MedicationFormScreenState extends ConsumerState<MedicationFormScreen> {
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _loaded = widget.editingId == null;
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) {
      final AsyncValue<Medication?> medication =
          ref.watch(_medicationByIdProvider(widget.editingId!));
      return medication.when(
        loading: () => const AppScaffold(body: Center(child: CircularProgressIndicator())),
        error: (Object e, StackTrace _) =>
            AppScaffold(body: ErrorView(failure: UnknownFailure(e.toString()))),
        data: (Medication? found) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (found != null) {
              ref.read(medicationFormControllerProvider.notifier).loadForEdit(found);
            }
            if (mounted) setState(() => _loaded = true);
          });
          return const AppScaffold(body: Center(child: CircularProgressIndicator()));
        },
      );
    }
    return const _FormBody();
  }
}

class _FormBody extends ConsumerWidget {
  const _FormBody();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final MedicationFormState state = ref.watch(medicationFormControllerProvider);
    final MedicationFormController controller =
        ref.read(medicationFormControllerProvider.notifier);

    ref.listen<MedicationFormState>(medicationFormControllerProvider, (
      MedicationFormState? previous,
      MedicationFormState next,
    ) {
      if (next.saved && (previous == null || !previous.saved) && context.mounted) {
        context.pop();
      }
    });

    return AppScaffold(
      title: 'meds.form.title'.tr(),
      scrollable: true,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          AppTextField(
            label: 'meds.form.name'.tr(),
            hint: 'meds.form.nameHint'.tr(),
            errorText: state.nameError?.tr(),
            onChanged: controller.setName,
          ),
          const SizedBox(height: AppSpacing.lg),
          AppTextField(
            label: 'meds.form.doseMg'.tr(),
            keyboardType: TextInputType.number,
            errorText: state.doseError?.tr(),
            onChanged: controller.setDoseMg,
          ),
          const SizedBox(height: AppSpacing.lg),
          Wrap(
            spacing: AppSpacing.sm,
            children: <Widget>[
              for (final MedicationFrequency f in MedicationFrequency.values)
                ChoiceChip(
                  label: Text('meds.frequency.${f.name}'.tr()),
                  selected: state.frequency == f,
                  onSelected: (_) => controller.setFrequency(f),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          TimeListField(times: state.scheduleTimes, onChanged: controller.setScheduleTimes),
          if (state.scheduleError != null) ...<Widget>[
            const SizedBox(height: AppSpacing.xs),
            Text(state.scheduleError!.tr(), style: Theme.of(context).textTheme.bodySmall),
          ],
          const SizedBox(height: AppSpacing.xxl),
          AppButton(
            label: 'common.save'.tr(),
            isLoading: state.isSaving,
            onPressed: controller.save,
          ),
        ],
      ),
    );
  }
}
