import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/widgets.dart';
import '../../domain/medication_library.dart';

/// The Figma "Add medication" search screen (frame 368:2790) — a new screen
/// per Decision E of docs/design/2026-08-27-mobile-m3-figma-fidelity-design.md,
/// reached via a plain [Navigator] push, not a named route. Calls
/// [onSelected] with the tapped [MedicationLibraryEntry], or `null` if
/// "Enter manually" was chosen; the caller (MedicationsScreen) is
/// responsible for pushing MedicationFormScreen next with that result.
class MedicationSearchScreen extends StatefulWidget {
  const MedicationSearchScreen({required this.onSelected, super.key});

  final void Function(MedicationLibraryEntry?) onSelected;

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

    return AppScaffold(
      title: 'meds.search.title'.tr(),
      scrollable: true,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('meds.search.subtitle'.tr(), style: text.bodyMedium),
          const SizedBox(height: AppSpacing.lg),
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
                  onTap: () => widget.onSelected(entry),
                ),
              ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'meds.search.libraryHint'.tr(),
              style: text.bodySmall?.copyWith(color: AppColors.textTertiary),
            ),
            Text(
              'meds.search.cantFind'.tr(),
              style: text.bodySmall?.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: AppSpacing.lg),
          ],
          AppButton(
            label: 'common.enterManually'.tr(),
            // AppButtonVariant has no `.outlined` value — `.secondary` is
            // the bordered/outlined style (see its doc comment in
            // app_button.dart), which matches Figma's outlined button here.
            variant: AppButtonVariant.secondary,
            onPressed: () => widget.onSelected(null),
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
