import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/db/tables.dart';
import '../../../../core/providers/core_providers.dart';
import '../../../../core/router/routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/widgets.dart';
import '../../auth_providers.dart';

/// A one-time Home card for accounts made before sign-up asked for security
/// questions: without them a forgotten PIN can't be reset.
///
/// Shown only when the server confirms none are set. Offline the answer is
/// unknown, and a patient whose questions live only on the server must not be
/// nagged. "Later" hides it for good; Settings keeps showing "Not set".
class SecurityQuestionsPrompt extends ConsumerStatefulWidget {
  const SecurityQuestionsPrompt({super.key});

  @override
  ConsumerState<SecurityQuestionsPrompt> createState() =>
      _SecurityQuestionsPromptState();
}

class _SecurityQuestionsPromptState
    extends ConsumerState<SecurityQuestionsPrompt> {
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    final String? dismissed = await ref
        .read(appDatabaseProvider)
        .preferencesDao
        .get(PreferenceKeys.securityQuestionsPromptDismissed);
    if (dismissed == 'true') {
      if (mounted) setState(() => _visible = false);
      return;
    }
    final bool? configured = await ref
        .read(pinRepositoryProvider)
        .securityQuestionsStatus();
    if (mounted) setState(() => _visible = configured == false);
  }

  Future<void> _later() async {
    setState(() => _visible = false);
    await ref
        .read(appDatabaseProvider)
        .preferencesDao
        .set(PreferenceKeys.securityQuestionsPromptDismissed, 'true');
  }

  Future<void> _setUp() async {
    await context.pushNamed(AppRoutes.securityQuestions);
    await _check(); // hides itself once they are set
  }

  @override
  Widget build(BuildContext context) {
    if (!_visible) return const SizedBox.shrink();
    final TextTheme text = Theme.of(context).textTheme;
    return Container(
      key: const Key('securityQuestionsPrompt'),
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.accentBg,
        borderRadius: BorderRadius.circular(AppSpacing.buttonRadius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Icon(Icons.help_outline, color: AppColors.accent),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  'auth.securityPrompt.title'.tr(),
                  style: text.titleMedium,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text('auth.securityPrompt.body'.tr(), style: text.bodyMedium),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: <Widget>[
              Expanded(
                child: AppButton(
                  label: 'auth.securityPrompt.later'.tr(),
                  variant: AppButtonVariant.secondary,
                  onPressed: _later,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: AppButton(
                  label: 'auth.securityPrompt.setUp'.tr(),
                  onPressed: _setUp,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
