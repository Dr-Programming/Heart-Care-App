import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/widgets.dart';
import '../../data/caregiver_notify_store.dart';
import '../../data/medication_instructions_store.dart';
import '../../domain/entities/medication.dart';
import '../controllers/medication_form_controller.dart';

/// The Figma "Review medication" screen (frame 368:2651) — a new screen per
/// Decision E of docs/design/2026-08-27-mobile-m3-figma-fidelity-design.md.
/// Purely a read-only summary of the form's current state plus the actual
/// save trigger; reached via a plain [Navigator] push, not a named route.
class ReviewMedicationScreen extends ConsumerWidget {
  const ReviewMedicationScreen({
    required this.notifyCaregiverEnabled,
    this.caregiverPhone = '',
    this.instructions,
    super.key,
  });

  /// The caregiver-notify toggle's current value, read from
  /// `_MedicationFormScreenState._caregiverEnabled` at push time — that flag
  /// lives as local `State` on the form screen (see its own doc comment),
  /// not on `MedicationFormState`, so it has to be handed down explicitly
  /// rather than read off the watched form state below.
  final bool notifyCaregiverEnabled;

  /// The caregiver phone number typed so far, read from
  /// `_MedicationFormScreenState._caregiverPhoneController.text` at push
  /// time — same reasoning as [notifyCaregiverEnabled]. Needed here (third
  /// Figma follow-up) so [_save] can pass a complete `CaregiverNotifySettings`
  /// into `MedicationFormController.save()`, which is what finally persists
  /// it once the medication's real id exists, in both add and edit mode.
  final String caregiverPhone;

  /// The selected Instructions chip (second Figma follow-up, Part A), read
  /// from `_MedicationFormScreenState._instructions` at push time — same
  /// reasoning as [notifyCaregiverEnabled] above: local `State` on the form
  /// screen, not part of `MedicationFormState`. Nullable (not just
  /// `MedicationInstructions.none`-defaulted) so existing call sites/tests
  /// that predate this field keep compiling unchanged; treated the same as
  /// `none` wherever it is displayed.
  final MedicationInstructions? instructions;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final MedicationFormState state = ref.watch(medicationFormControllerProvider);
    final MedicationFormController controller =
        ref.read(medicationFormControllerProvider.notifier);

    // Mirrors `MedicationFormScreen`'s own `isAsNeeded` derivation exactly
    // (Part B, second Figma follow-up) — "as needed" is Custom frequency
    // with an empty schedule, not a stored flag, so the review screen
    // special-cases the same state combination rather than trusting
    // `state.frequency.name` to already say the right thing.
    final bool isAsNeeded =
        state.frequency == MedicationFrequency.custom && state.scheduleTimes.isEmpty;

    final MedicationInstructions instructionsValue = instructions ?? MedicationInstructions.none;

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
        if (next.reminderSchedulingFailed) {
          // The medication saved fine; only reminder scheduling failed
          // afterward. Give the warning a moment on screen before popping —
          // a SnackBar shown right before `pop()` would be torn down with
          // this route before anyone could read it.
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(
              SnackBar(
                content: Text('meds.review.reminderSchedulingFailed'.tr()),
                duration: const Duration(seconds: 3),
              ),
            );
          Future<void>.delayed(const Duration(milliseconds: 1200), () {
            if (!context.mounted) return;
            if (navigator.canPop()) navigator.pop();
            if (navigator.canPop()) navigator.pop();
          });
          return;
        }
        if (navigator.canPop()) navigator.pop();
        if (navigator.canPop()) navigator.pop();
      }
    });

    return AppScaffold.banded(
      // Same technique as `MedicationSearchScreen` — see its doc comment.
      // Figma frame 368:2651 draws this screen's back arrow/title/subtitle
      // inside the cream band too, not a separate AppBar.
      showBack: false,
      // See `MedicationsScreen`'s matching comment: 150 leaves real room for
      // an accessible ~48dp back-icon tap target — the actual, concrete
      // reason this value was raised from an initial 130 is that 130
      // genuinely overflowed this screen's own narrow-width regression
      // tests once a real tappable icon was added to the band.
      bandHeight: 150,
      scrollable: true,
      bandChild: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          IconButton(
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            icon: const Icon(Icons.arrow_back, color: AppColors.ink),
            onPressed: () => Navigator.of(context).pop(),
          ),
          const Spacer(),
          Text('meds.review.title'.tr(), style: Theme.of(context).textTheme.headlineLarge),
          const SizedBox(height: AppSpacing.xs),
          // `bodyMedium` alone renders AppColors.textSecondary (its default,
          // confirmed by reading app_typography.dart) — get_design_context
          // for this frame (368:2651) shows this subtitle at #282a2a (ink),
          // not grey.
          Text(
            'meds.review.subtitle'.tr(),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.ink),
          ),
        ],
      ),
      // Figma leaves a real gap (~24px) between the band and whatever comes
      // next — see `MedicationsScreen`'s matching comment.
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const SizedBox(height: AppSpacing.xl),
          SectionCard(
            title: state.name,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                _SummaryRow(label: 'meds.form.doseMg'.tr(), value: '${state.doseMg} mg'),
                _SummaryRow(
                  label: 'meds.review.frequency'.tr(),
                  value: isAsNeeded
                      ? 'meds.frequency.asNeeded'.tr()
                      : 'meds.frequency.${state.frequency.name}'.tr(),
                ),
                _SummaryRow(
                  label: 'meds.form.scheduleTimes'.tr(),
                  value: isAsNeeded
                      ? 'meds.review.noFixedSchedule'.tr()
                      : state.scheduleTimes.join(', '),
                ),
                // A "Reminder: On/Off" row that Figma's frame 368:2651 shows
                // (confirmed via get_design_context) but this screen never
                // had at all — derived from `isAsNeeded` rather than a
                // separate stored flag, since "As needed" already *is* "no
                // reminders" (see `MedicationFormController.validate()`'s
                // doc comment on that state combination).
                _StatusRow(
                  label: 'meds.review.reminder'.tr(),
                  on: !isAsNeeded,
                ),
                _StatusRow(
                  label: 'meds.review.notifyCaregiver'.tr(),
                  on: notifyCaregiverEnabled,
                ),
                _SummaryRow(
                  label: 'meds.form.instructions.title'.tr(),
                  value: instructionsValue == MedicationInstructions.none
                      ? 'meds.review.instructionsNotSet'.tr()
                      : 'meds.form.instructions.${instructionsValue.name}'.tr(),
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
                  // An empty joined `times` would otherwise read as
                  // "Reminders set for  daily" — a blank value rather than a
                  // sentence — for exactly the "as needed" case, so this
                  // reuses the form's own caption copy instead of that
                  // template with nothing to fill in.
                  // `bodySmall` alone renders AppColors.textSecondary (its
                  // default) — get_design_context confirmed both lines in
                  // this banner render at #1d4ed8 (AppColors.accent), the
                  // same blue as the notification bell icon beside them, not
                  // grey.
                  Text(
                    isAsNeeded
                        ? 'meds.form.asNeededCaption'.tr()
                        : 'meds.review.remindersSet'.tr(
                            namedArgs: <String, String>{'times': state.scheduleTimes.join(', ')},
                          ),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.accent),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'meds.review.offlineNote'.tr(),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.accent),
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
      await controller.save(
        caregiverSettings: CaregiverNotifySettings(
          enabled: notifyCaregiverEnabled,
          phone: caregiverPhone,
        ),
        instructions: instructions ?? MedicationInstructions.none,
      );
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
          // Colours confirmed via get_design_context against frame 368:2651:
          // every row label is `#6b7280` (AppColors.textSecondary) at 12px
          // regular, every value is `#282a2a` (AppColors.ink) at 12px bold.
          // `bodyMedium`'s own default is textSecondary, not ink (confirmed
          // by reading app_typography.dart) — so the value needs its own
          // explicit ink override too, not just the label; leaving it bare
          // silently rendered every value in the same grey as its label.
          Flexible(
            child: Text(
              label,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: AppColors.ink, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}

/// A label + coloured status pill row — "Reminder"/"Notify caregiver", both
/// On/Off in frame 368:2651. Distinct from [_SummaryRow] (used for the
/// screen's plain-text rows) because Figma renders these two specifically as
/// a small coloured badge, not plain text: `get_design_context` confirmed
/// the "On" pill uses `AppColors.success`/`successBg` (the same pairing
/// `StatusChip` already uses for a positive clinical status elsewhere in
/// this app) and the "Off" pill uses `AppColors.accent`/`accentBg`.
class _StatusRow extends StatelessWidget {
  const _StatusRow({required this.label, required this.on});

  final String label;
  final bool on;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          Flexible(
            child: Text(
              label,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          _StatusPill(on: on, label: on ? 'meds.review.on'.tr() : 'meds.review.off'.tr()),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.on, required this.label});

  final bool on;
  final String label;

  @override
  Widget build(BuildContext context) {
    final Color foreground = on ? AppColors.success : AppColors.accent;
    final Color background = on ? AppColors.successBg : AppColors.accentBg;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xs),
      decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(AppSpacing.lg)),
      child: Text(
        label,
        style: Theme.of(
          context,
        ).textTheme.bodySmall?.copyWith(color: foreground, fontWeight: FontWeight.bold),
      ),
    );
  }
}
