import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/widgets.dart';
import '../../auth_providers.dart';
import '../../domain/security_question.dart';
import '../../domain/validators.dart';
import '../widgets/pin_field.dart';
import '../widgets/security_questions_fields.dart';

/// Set up, or replace, the three security questions used to reset a forgotten
/// PIN. Needs a connection; afterwards this phone can check the answers
/// offline.
class SecurityQuestionsScreen extends ConsumerStatefulWidget {
  const SecurityQuestionsScreen({super.key});

  @override
  ConsumerState<SecurityQuestionsScreen> createState() => _SecurityQuestionsScreenState();
}

class _SecurityQuestionsScreenState extends ConsumerState<SecurityQuestionsScreen> {
  final SecurityQuestionsFieldsController _fields = SecurityQuestionsFieldsController();
  final TextEditingController _pin = TextEditingController();

  bool _configured = false;
  String? _pinErrorKey;
  String? _formError;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _loadConfigured();
  }

  Future<void> _loadConfigured() async {
    final List<SecurityQuestion> configured =
        await ref.read(pinRepositoryProvider).configuredQuestions();
    if (!mounted || configured.length != 3) return;
    setState(() {
      _configured = true;
      _fields.replaceQuestions(configured);
    });
  }

  @override
  void dispose() {
    _fields.dispose();
    _pin.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final List<SecurityAnswer>? answers = _fields.validate();
    final String? pinKey = validatePin(_pin.text);
    setState(() {
      _pinErrorKey = pinKey;
      _formError = null;
    });
    if (answers == null || pinKey != null) return;

    setState(() => _busy = true);
    try {
      await ref.read(pinRepositoryProvider).setSecurityAnswers(currentPin: _pin.text, answers: answers);
      if (!mounted) return;
      showAppToast(context, 'auth.securityQuestions.saved'.tr(), icon: Icons.check_circle_outline);
      setState(() => _configured = true);
      _fields.clearAnswers();
      _pin.clear();
    } on Failure catch (failure) {
      if (mounted) setState(() => _formError = _messageFor(failure));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _messageFor(Failure failure) {
    return switch (failure) {
      NetworkFailure() => 'auth.securityQuestions.needsConnection'.tr(),
      InvalidCredentialsFailure() => 'auth.changePin.wrongCurrent'.tr(),
      AccountLockedFailure(:final int? minutesRemaining) => minutesRemaining != null
          ? 'auth.errors.locked'.tr(namedArgs: <String, String>{'minutes': '$minutesRemaining'})
          : 'auth.errors.lockedNoTime'.tr(),
      _ => 'errors.generic'.tr(),
    };
  }

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    return AppScaffold(
      title: 'auth.securityQuestions.title'.tr(),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            const SizedBox(height: AppSpacing.md),
            Text(
              _configured ? 'auth.securityQuestions.replaceIntro'.tr() : 'auth.securityQuestions.intro'.tr(),
              style: text.bodyMedium,
            ),
            const SizedBox(height: AppSpacing.lg),
            SecurityQuestionsFields(controller: _fields, enabled: !_busy),
            PinField(
              controller: _pin,
              label: 'auth.securityQuestions.currentPin'.tr(),
              errorText: _pinErrorKey?.tr(),
            ),
            if (_formError != null) ...<Widget>[
              const SizedBox(height: AppSpacing.md),
              Text(_formError!, style: text.bodyMedium?.copyWith(color: AppColors.critical)),
            ],
            const SizedBox(height: AppSpacing.lg),
            AppButton(
              key: const Key('securityQuestionsSubmit'),
              label: 'auth.securityQuestions.submit'.tr(),
              isLoading: _busy,
              onPressed: _busy ? null : _submit,
            ),
          ],
        ),
      ),
    );
  }
}
