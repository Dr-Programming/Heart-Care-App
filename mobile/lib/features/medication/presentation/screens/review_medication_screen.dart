import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/widgets.dart';
import '../controllers/medication_form_controller.dart';

/// The Figma "Review medication" screen (frame 368:2651) — a new screen per
/// Decision E of docs/design/2026-08-27-mobile-m3-figma-fidelity-design.md.
/// Purely a read-only summary of the form's current state plus the actual
/// save trigger; reached via a plain [Navigator] push, not a named route.
class ReviewMedicationScreen extends ConsumerWidget {
  const ReviewMedicationScreen({super.key});

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
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    });

    return AppScaffold(
      title: 'meds.review.title'.tr(),
      scrollable: true,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('meds.review.subtitle'.tr(), style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: AppSpacing.lg),
          SectionCard(
            title: state.name,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                _SummaryRow(label: 'meds.form.doseMg'.tr(), value: '${state.doseMg} mg'),
                _SummaryRow(
                  label: 'meds.review.frequency'.tr(),
                  value: 'meds.frequency.${state.frequency.name}'.tr(),
                ),
                _SummaryRow(
                  label: 'meds.form.scheduleTimes'.tr(),
                  value: state.scheduleTimes.join(', '),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          // SectionCard has no `backgroundColor` parameter (confirmed at
          // core/widgets/cards.dart:12-19 — its params are only `child,
          // title, action, padding, onTap`), so this is just an untitled
          // card rather than one with an explicit background override.
          SectionCard(
            child: Text('meds.review.offlineNote'.tr(), style: Theme.of(context).textTheme.bodySmall),
          ),
          const SizedBox(height: AppSpacing.xxl),
          AppButton(
            label: 'meds.review.save'.tr(),
            isLoading: state.isSaving,
            onPressed: () => _save(context, controller),
          ),
          const SizedBox(height: AppSpacing.sm),
          AppButton(
            label: 'meds.review.edit'.tr(),
            variant: AppButtonVariant.text,
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  /// Saves, and tells the user when saving did not work — the identical
  /// structure and translation key as `MedicationFormScreen._save` (I7 of
  /// the original final-review fix wave): a `Failure`'s own message
  /// verbatim, or `errors.generic` for anything else, in a `SnackBar`.
  Future<void> _save(BuildContext context, MedicationFormController controller) async {
    try {
      await controller.save();
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              error is Failure ? error.message : 'errors.generic'.tr(),
            ),
          ),
        );
    }
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          Text(label, style: Theme.of(context).textTheme.bodyMedium),
          Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
