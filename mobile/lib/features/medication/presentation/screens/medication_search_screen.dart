import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/widgets.dart';
import '../../domain/medication_library.dart';

class MedicationSearchOutcome {
  const MedicationSearchOutcome(this.entry);

  final MedicationLibraryEntry? entry;
}

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

      showBack: false,

      bandHeight: 130,
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
          const SizedBox(height: AppSpacing.xs),

          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text('meds.search.title'.tr(), style: text.headlineLarge?.copyWith(fontSize: 28)),
          ),
          const SizedBox(height: AppSpacing.xs),

          Text(
            'meds.search.subtitle'.tr(),
            style: text.bodyMedium?.copyWith(color: AppColors.ink),
          ),
        ],
      ),

      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const SizedBox(height: AppSpacing.xl),

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
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: AppColors.ink, fontWeight: FontWeight.bold),
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
