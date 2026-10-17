import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/providers/core_providers.dart';
import '../../../../core/router/routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/widgets.dart';
import '../../auth_providers.dart';

/// "Before you start": what the app is for and who sees the patient's
/// information. Shown once after the language is chosen, before any account
/// screen; [readOnly] is the copy opened again from Settings.
class TermsScreen extends ConsumerStatefulWidget {
  const TermsScreen({this.readOnly = false, super.key});

  final bool readOnly;

  /// Sections in the order they are shown; each has a title and bullet
  /// points under `legal.terms.<id>`.
  static const List<(String, int)> sections = <(String, int)>[
    ('notDoctor', 2),
    ('whatWeKeep', 3),
    ('whoSees', 3),
    ('phoneOnly', 1),
    ('safety', 2),
    ('choices', 2),
  ];

  @override
  ConsumerState<TermsScreen> createState() => _TermsScreenState();
}

class _TermsScreenState extends ConsumerState<TermsScreen> {
  bool _agreed = false;
  bool _saving = false;

  Future<void> _continue() async {
    setState(() => _saving = true);
    await ref.read(termsStoreProvider).accept();
    await ref.read(realAuthGateProvider.notifier).refresh();
    if (!mounted) return;
    // Signed out, this is the sign-in screen; a signed-in patient seeing new
    // terms is sent on to Home by the router.
    context.goNamed(AppRoutes.login);
  }

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    return AppScaffold.banded(
      // The band header draws the back arrow; a second one here would add
      // an extra bar above it.
      showBack: false,
      bandChild: BandHeader(
        title: 'legal.terms.title'.tr(),
        subtitle: 'legal.terms.subtitle'.tr(),
        showBack: widget.readOnly,
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text('legal.terms.intro'.tr(), style: text.bodyLarge),
            const SizedBox(height: AppSpacing.lg),
            for (final (String id, int points) in TermsScreen.sections) ...<Widget>[
              SectionCard(
                key: Key('terms_$id'),
                title: 'legal.terms.$id.title'.tr(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    for (int i = 1; i <= points; i++)
                      _Point(text: 'legal.terms.$id.p$i'.tr()),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),
            ],
            if (!widget.readOnly) ...<Widget>[
              const SizedBox(height: AppSpacing.sm),
              CheckboxListTile(
                key: const Key('termsAgreeCheckbox'),
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                value: _agreed,
                title: Text('legal.terms.agree'.tr(), style: text.bodyMedium),
                onChanged: _saving
                    ? null
                    : (bool? on) => setState(() => _agreed = on ?? false),
              ),
              const SizedBox(height: AppSpacing.md),
              AppButton(
                key: const Key('termsContinueButton'),
                label: 'legal.terms.continue'.tr(),
                isLoading: _saving,
                onPressed: _agreed && !_saving ? _continue : null,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'legal.terms.readLater'.tr(),
                textAlign: TextAlign.center,
                style: text.bodySmall?.copyWith(color: AppColors.textSecondary),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Point extends StatelessWidget {
  const _Point({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final TextTheme theme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.only(top: 7, right: AppSpacing.sm),
            child: Container(
              width: 6,
              height: 6,
              decoration: const BoxDecoration(
                color: AppColors.accent,
                shape: BoxShape.circle,
              ),
            ),
          ),
          Expanded(child: Text(text, style: theme.bodyMedium)),
        ],
      ),
    );
  }
}
