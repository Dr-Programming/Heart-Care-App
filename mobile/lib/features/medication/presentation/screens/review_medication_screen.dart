import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/widgets.dart';
import '../controllers/medication_form_controller.dart';

/// The Figma "Review medication" screen (frame 368:2651) — a new screen per
/// Decision E of docs/design/2026-08-27-mobile-m3-figma-fidelity-design.md.
/// Purely a read-only summary of the form's current state plus the actual
/// save trigger; reached via a plain [Navigator] push, not a named route.
class ReviewMedicationScreen extends ConsumerWidget {
  const ReviewMedicationScreen({required this.notifyCaregiverEnabled, super.key});

  /// The caregiver-notify toggle's current value, read from
  /// `_MedicationFormScreenState._caregiverEnabled` at push time — that flag
  /// lives as local `State` on the form screen (see its own doc comment),
  /// not on `MedicationFormState`, so it has to be handed down explicitly
  /// rather than read off the watched form state below.
  final bool notifyCaregiverEnabled;

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
        // `popUntil((route) => route.isFirst)` (this screen's original
        // navigation, before it was wired into the real add/edit flow) would
        // pop all the way to the app's root route — wrong once real
        // navigation landed `MedicationsScreen` (push MedicationSearchScreen
        // or the `medicationEdit` GoRoute) -> `MedicationFormScreen` (push)
        // -> this screen, all on the same per-tab Navigator
        // (`StatefulShellRoute.indexedStack` gives the medications tab its
        // own Navigator, and `medicationEdit`/`medicationNew` are GoRoutes
        // *inside* that tab, not on the root navigator). Two pops — this
        // screen, then the form underneath it — lands exactly back on
        // `MedicationsScreen`, matching the real push depth in both the add
        // flow (search -> form -> review) and the edit flow (GoRouter's
        // medicationEdit -> review).
        // Guarded with `canPop()` rather than two unconditional pops: this
        // screen is also pumped directly as the *only* route in
        // review_medication_screen_test.dart's pre-existing tests (no form,
        // no medications list underneath it), where an unconditional second
        // pop would try to pop a Navigator past its last route. `canPop()`
        // makes each pop a no-op once there is nowhere left to go, so this is
        // "pop up to two levels" rather than "pop exactly two, always".
        final NavigatorState navigator = Navigator.of(context);
        if (navigator.canPop()) navigator.pop();
        if (navigator.canPop()) navigator.pop();
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
                _SummaryRow(
                  label: 'meds.review.notifyCaregiver'.tr(),
                  value: notifyCaregiverEnabled
                      ? 'meds.review.notifyCaregiverOn'.tr()
                      : 'meds.review.notifyCaregiverOff'.tr(),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          // SectionCard has no `backgroundColor` parameter (confirmed at
          // core/widgets/cards.dart:12-19 — its params are only `child,
          // title, action, padding, onTap`), so the pale-blue tint here is
          // applied the same way `MedicationSearchScreen`'s `_SuggestionCard`
          // does it: zero the card's own padding and give it an opaque
          // tinted `Container` (carrying that padding itself) as its child,
          // filling the card end to end within its clipped, rounded bounds.
          SectionCard(
            padding: EdgeInsets.zero,
            child: Container(
              width: double.infinity,
              color: AppColors.accentBg,
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    'meds.review.remindersSet'.tr(
                      namedArgs: <String, String>{'times': state.scheduleTimes.join(', ')},
                    ),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'meds.review.offlineNote'.tr(),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
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
          // Both cells are `Flexible`-guarded — not just the value — because
          // this row now also renders the caregiver-notify label (Fix 2),
          // whose full copy ("Notify caregiver if missed") is long enough on
          // its own to overflow a bare, unwrapped `Text` the same way a long
          // *value* can (an unwrapped Row child gets an effectively
          // unbounded max width during layout, so it never wraps — it just
          // renders at its full single-line width regardless of the
          // container, which is exactly the failure mode `DoseRow` and
          // `MedicationCard`'s own `Flexible`/`Expanded` guards exist to
          // avoid). A plain `Flexible` (not `Expanded`) on the label keeps
          // its current compact, content-sized layout for the existing short
          // labels, while still letting it wrap instead of overflowing when
          // a label — in English or Amharic — turns out to be long.
          Flexible(child: Text(label, style: Theme.of(context).textTheme.bodyMedium)),
          const SizedBox(width: AppSpacing.sm),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
