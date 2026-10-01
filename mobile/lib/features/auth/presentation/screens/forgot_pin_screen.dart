import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/router/routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/widgets.dart';
import '../../auth_providers.dart';
import '../../domain/answer_normalizer.dart';
import '../../domain/repositories/pin_repository.dart';
import '../../domain/security_question.dart';
import '../../domain/validators.dart';
import '../widgets/pin_field.dart';

/// Forgot PIN: phone number, then the patient's three security questions and
/// a new PIN. Works offline on a phone where the answers were set up; the
/// reset then reaches the server at the next sync (see [PinRepository]).
class ForgotPinScreen extends ConsumerStatefulWidget {
  const ForgotPinScreen({super.key});

  @override
  ConsumerState<ForgotPinScreen> createState() => _ForgotPinScreenState();
}

class _ForgotPinScreenState extends ConsumerState<ForgotPinScreen> {
  final TextEditingController _phone = TextEditingController();
  final TextEditingController _newPin = TextEditingController();
  final TextEditingController _confirm = TextEditingController();
  final List<TextEditingController> _answers =
      List<TextEditingController>.generate(3, (_) => TextEditingController());

  List<SecurityQuestion>? _questions;
  String? _phoneErrorKey;
  String? _answerErrorKey;
  String? _pinErrorKey;
  String? _confirmErrorKey;
  String? _formError;
  bool _busy = false;

  @override
  void dispose() {
    _phone.dispose();
    _newPin.dispose();
    _confirm.dispose();
    for (final TextEditingController c in _answers) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _findQuestions() async {
    final String? phoneKey = validatePhone(_phone.text.trim());
    setState(() {
      _phoneErrorKey = phoneKey;
      _formError = null;
    });
    if (phoneKey != null) return;

    setState(() => _busy = true);
    try {
      final List<SecurityQuestion> questions =
          await ref.read(pinRepositoryProvider).recoveryQuestions(_phone.text.trim());
      if (mounted) setState(() => _questions = questions);
    } on Failure catch (failure) {
      if (mounted) setState(() => _formError = _messageFor(failure));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _reset() async {
    final List<SecurityQuestion> questions = _questions!;
    final bool answersOk = _answers.take(questions.length).every((c) => isValidAnswer(c.text));
    final String? pinKey = validatePin(_newPin.text);
    final String? confirmKey = _confirm.text == _newPin.text ? null : 'auth.errors.pinMismatch';
    setState(() {
      _answerErrorKey = answersOk ? null : 'auth.securityQuestions.answerLength';
      _pinErrorKey = pinKey;
      _confirmErrorKey = confirmKey;
      _formError = null;
    });
    if (!answersOk || pinKey != null || confirmKey != null) return;

    setState(() => _busy = true);
    try {
      final PinChangeOutcome outcome = await ref.read(pinRepositoryProvider).resetPin(
        phone: _phone.text.trim(),
        answers: <SecurityAnswer>[
          for (int i = 0; i < questions.length; i++) SecurityAnswer(questions[i], _answers[i].text),
        ],
        newPin: _newPin.text,
      );
      if (!mounted) return;
      showAppToast(
        context,
        outcome == PinChangeOutcome.queued
            ? 'auth.forgotPin.queued'.tr()
            : 'auth.forgotPin.success'.tr(),
        icon: Icons.check_circle_outline,
        duration: const Duration(seconds: 5),
      );
      // Signed in now (online, or offline on this phone): let the gate route home.
      await ref.read(realAuthGateProvider.notifier).refresh();
      if (mounted && GoRouter.maybeOf(context) != null) context.goNamed(AppRoutes.home);
    } on Failure catch (failure) {
      if (mounted) setState(() => _formError = _messageFor(failure));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _messageFor(Failure failure) {
    return switch (failure) {
      InvalidCredentialsFailure() => 'auth.forgotPin.answersDontMatch'.tr(),
      AccountLockedFailure(:final int? minutesRemaining) => minutesRemaining != null
          ? 'auth.errors.locked'.tr(namedArgs: <String, String>{'minutes': '$minutesRemaining'})
          : 'auth.errors.lockedNoTime'.tr(),
      NetworkFailure() => 'auth.forgotPin.needsConnection'.tr(),
      _ => 'errors.generic'.tr(),
    };
  }

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    final List<SecurityQuestion>? questions = _questions;
    return AppScaffold(
      title: 'auth.forgotPin.title'.tr(),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            const SizedBox(height: AppSpacing.md),
            Text(
              questions == null ? 'auth.forgotPin.intro'.tr() : 'auth.forgotPin.answerIntro'.tr(),
              style: text.bodyMedium,
            ),
            const SizedBox(height: AppSpacing.lg),
            if (questions == null) ...<Widget>[
              AppTextField(
                label: 'auth.login.phone'.tr(),
                controller: _phone,
                hint: 'auth.login.phoneHint'.tr(),
                errorText: _phoneErrorKey?.tr(),
                keyboardType: TextInputType.phone,
                prefixIcon: Icons.call_outlined,
              ),
              const SizedBox(height: AppSpacing.lg),
              AppButton(
                key: const Key('forgotPinFindQuestions'),
                label: 'auth.forgotPin.continue'.tr(),
                isLoading: _busy,
                onPressed: _busy ? null : _findQuestions,
              ),
            ] else ...<Widget>[
              for (int i = 0; i < questions.length; i++) ...<Widget>[
                AppTextField(
                  label: questions[i].labelKey.tr(),
                  controller: _answers[i],
                  errorText: i == 0 ? _answerErrorKey?.tr() : null,
                ),
                const SizedBox(height: AppSpacing.md),
              ],
              PinField(
                controller: _newPin,
                label: 'auth.forgotPin.newPin'.tr(),
                errorText: _pinErrorKey?.tr(),
              ),
              const SizedBox(height: AppSpacing.md),
              PinField(
                controller: _confirm,
                label: 'auth.forgotPin.confirmPin'.tr(),
                errorText: _confirmErrorKey?.tr(),
              ),
              const SizedBox(height: AppSpacing.lg),
              AppButton(
                key: const Key('forgotPinSubmit'),
                label: 'auth.forgotPin.submit'.tr(),
                isLoading: _busy,
                onPressed: _busy ? null : _reset,
              ),
            ],
            if (_formError != null) ...<Widget>[
              const SizedBox(height: AppSpacing.md),
              Text(_formError!, style: text.bodyMedium?.copyWith(color: AppColors.critical)),
            ],
            const SizedBox(height: AppSpacing.lg),
            AppButton(
              label: 'auth.forgotPin.back'.tr(),
              variant: AppButtonVariant.secondary,
              onPressed: () => Navigator.of(context).maybePop(),
            ),
          ],
        ),
      ),
    );
  }
}
