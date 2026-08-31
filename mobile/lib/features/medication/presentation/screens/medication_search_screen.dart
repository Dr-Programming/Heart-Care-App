import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/widgets.dart';
import '../../domain/medication_library.dart';

/// What [MedicationSearchScreen] pops itself with.
///
/// The screen is reached via a plain [Navigator] push, and a caller needs to
/// tell apart three distinct outcomes: a suggestion was tapped (`entry` is
/// that suggestion), "Enter manually" was tapped (`entry` is null, but the
/// user explicitly chose to proceed with a blank form), or the system back
/// button/gesture was used (nothing was chosen at all). The first two both
/// mean "proceed" and are represented by this class; the third is
/// represented by the pushed route resolving to `null` instead of an
/// instance of this class — Flutter's default back button calls
/// `Navigator.maybePop`, which pops with no result, so a caller's
/// `await Navigator.push<MedicationSearchOutcome>(...)` sees a bare `null`
/// exactly on back, never on "Enter manually" (which pops
/// `const MedicationSearchOutcome(null)`, a non-null instance whose `entry`
/// happens to be null). Without this wrapper both cases collide on the same
/// `null` value and a caller cannot distinguish "do nothing" from "open a
/// blank form".
class MedicationSearchOutcome {
  const MedicationSearchOutcome(this.entry);

  /// The tapped suggestion, or null if "Enter manually" was chosen instead.
  final MedicationLibraryEntry? entry;
}

/// The Figma "Add medication" search screen (frame 368:2790) — a new screen
/// per Decision E of docs/design/2026-08-27-mobile-m3-figma-fidelity-design.md,
/// reached via a plain [Navigator] push, not a named route. Pops itself with
/// a [MedicationSearchOutcome] (see its doc comment for why); the caller
/// (MedicationsScreen) is responsible for pushing MedicationFormScreen next
/// with that result.
class MedicationSearchScreen extends StatefulWidget {
  const MedicationSearchScreen({super.key});

  @override
  State<MedicationSearchScreen> createState() =>
      _MedicationSearchScreenState();
}

class _MedicationSearchScreenState extends State<MedicationSearchScreen> {
  final TextEditingController _controller = TextEditingController();
  List<MedicationLibraryEntry> _results = const <MedicationLibraryEntry>[];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onQueryChanged(String value) {
    setState(() => _results = searchMedicationLibrary(value));
  }

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;

    return AppScaffold.banded(
      // Figma frame 368:2790 draws its back arrow, title and subtitle
      // inside the cream band itself, not a separate white system AppBar —
      // matching that (rather than the plain `AppScaffold(title: ...)` this
      // screen used before) needs the same `showBack: false` +
      // custom-`bandChild` technique already established on
      // `MedicationsScreen` (see its own doc comment for why `showBack`
      // must be passed explicitly, not omitted). This screen is always
      // reached via a push, so — unlike `MedicationsScreen` — the back
      // arrow is unconditional, not gated on `Navigator.canPop()`.
      showBack: false,
      // 150, not Figma's own raw ~128px for this frame — a real, accessible
      // ~48dp tap target on the back icon needs more room than Figma's
      // small static back-arrow image implies (confirmed by a genuine
      // overflow in this screen's own narrow-width tests at a tighter
      // value). See `MedicationsScreen`'s matching comment for the full
      // reasoning.
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
          Text('meds.search.title'.tr(), style: text.headlineLarge),
          const SizedBox(height: AppSpacing.xs),
          Text('meds.search.subtitle'.tr(), style: text.bodyMedium),
        ],
      ),
      // Figma leaves a real gap (~24px) between the band and whatever comes
      // next — see `MedicationsScreen`'s matching comment.
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const SizedBox(height: AppSpacing.xl),
          // A raw TextField rather than AppTextField: AppTextField always
          // renders a label above the field (by design — FR-LOC-004), but
          // Figma's search bar has no label, just a rounded pill with a
          // leading search icon. Forcing an empty label onto AppTextField
          // would add unwanted vertical space that isn't in the design.
          TextField(
            controller: _controller,
            onChanged: _onQueryChanged,
            style: text.bodyLarge,
            decoration: InputDecoration(
              prefixIcon: const Icon(
                Icons.search,
                size: 20,
                color: AppColors.textTertiary,
              ),
              hintText: 'meds.search.hint'.tr(),
              filled: true,
              fillColor: AppColors.surfaceAlt,
              contentPadding: const EdgeInsets.symmetric(
                vertical: AppSpacing.md,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppSpacing.fieldRadius),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          if (_results.isNotEmpty) ...<Widget>[
            Text(
              'meds.search.suggestions'.tr(),
              style: text.labelSmall?.copyWith(color: AppColors.textTertiary),
            ),
            const SizedBox(height: AppSpacing.sm),
            for (final MedicationLibraryEntry entry in _results)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: _SuggestionCard(
                  entry: entry,
                  onTap: () =>
                      Navigator.of(context).pop(MedicationSearchOutcome(entry)),
                ),
              ),
            const SizedBox(height: AppSpacing.md),
          ],
          // Unlike the suggestions above, this guidance is not gated on
          // `_results.isNotEmpty`: it is most needed exactly when results are
          // empty — a zero-result search, or the screen's initial state —
          // not only after a successful search.
          Text(
            'meds.search.libraryHint'.tr(),
            style: text.bodySmall?.copyWith(color: AppColors.textTertiary),
          ),
          Text(
            'meds.search.cantFind'.tr(),
            style: text.bodySmall?.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.lg),
          AppButton(
            label: 'common.enterManually'.tr(),
            // AppButtonVariant has no `.outlined` value — `.secondary` is
            // the bordered/outlined style (see its doc comment in
            // app_button.dart), which matches Figma's outlined button here.
            variant: AppButtonVariant.secondary,
            onPressed: () =>
                Navigator.of(context).pop(const MedicationSearchOutcome(null)),
          ),
        ],
      ),
    );
  }
}

class _SuggestionCard extends StatelessWidget {
  const _SuggestionCard({required this.entry, required this.onTap});

  final MedicationLibraryEntry entry;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final String dose = entry.doseMg == entry.doseMg.roundToDouble()
        ? entry.doseMg.toStringAsFixed(0)
        : entry.doseMg.toString();

    final Widget row = Row(
      children: <Widget>[
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                '${entry.name} $dose mg',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              Text(
                entry.mostCommon
                    ? '${entry.drugClass} · ${'meds.search.mostCommon'.tr()}'
                    : entry.drugClass,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
        const Icon(Icons.chevron_right, color: AppColors.textTertiary),
      ],
    );

    // SectionCard has no `backgroundColor` parameter, and its own Container
    // already paints an opaque AppColors.surface behind whatever it's given
    // — so wrapping it from the outside can't show a tint through that.
    // Instead, for the most-common entry (Figma's pale-blue top-suggestion
    // row), SectionCard's own padding is zeroed out and an opaque tinted
    // Container carrying the same padding is supplied as its child, which
    // fills the card end to end within its clipped, rounded bounds.
    if (!entry.mostCommon) {
      return SectionCard(onTap: onTap, child: row);
    }
    return SectionCard(
      onTap: onTap,
      padding: EdgeInsets.zero,
      child: Container(
        width: double.infinity,
        color: AppColors.accentBg,
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: row,
      ),
    );
  }
}
