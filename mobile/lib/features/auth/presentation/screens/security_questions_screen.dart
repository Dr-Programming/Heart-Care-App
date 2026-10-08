import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/widgets.dart';
import '../../auth_providers.dart';
import '../../domain/repositories/pin_repository.dart';
import '../../domain/security_question.dart';
import '../../domain/validators.dart';
import '../widgets/own_question_field.dart';
import '../widgets/pin_field.dart';
import '../widgets/security_questions_fields.dart';

/// Set up, or replace, the three security questions used to reset a forgotten
/// PIN. Needs a connection; afterwards this phone can check the answers
/// offline.
class SecurityQuestionsScreen extends ConsumerStatefulWidget {
  const SecurityQuestionsScreen({super.key});

  @override
  ConsumerState<SecurityQuestionsScreen> createState() =>
      _SecurityQuestionsScreenState();
}

class _SecurityQuestionsScreenState
    extends ConsumerState<SecurityQuestionsScreen> {
  final SecurityQuestionsFieldsController _fields =
      SecurityQuestionsFieldsController();
  final TextEditingController _pin = TextEditingController();
  final OwnQuestionController _own = OwnQuestionController();
  final TextEditingController _ownPin = TextEditingController();
  String? _ownQuestion;
  String? _ownPinErrorKey;
  String? _ownError;
  bool _ownBusy = false;

  bool _configured = false;
  String? _pinErrorKey;
  String? _formError;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _loadConfigured();
  }

  Future<void> _loadOwnQuestion() async {
    final PinRepository pins = ref.read(pinRepositoryProvider);
    final String? phone =
        (await ref.read(authRepositoryProvider).cachedUser())?.phone;
    final String? question = phone == null
        ? null
        : await pins.customRecoveryQuestion(phone);
    if (mounted) setState(() => _ownQuestion = question);
  }

  Future<void> _saveOwnQuestion({bool remove = false}) async {
    final String? pinKey = validatePin(_ownPin.text);
    final bool ok = remove || _own.validate();
    setState(() {
      _ownPinErrorKey = pinKey;
      _ownError = (!remove && !_own.enabled)
          ? 'auth.ownQuestion.turnOn'.tr()
          : null;
    });
    if (pinKey != null || !ok || _ownError != null) return;
    setState(() => _ownBusy = true);
    try {
      final PinRepository pins = ref.read(pinRepositoryProvider);
      final ({String question, String answer})? own = _own.value;
      if (remove || own == null) {
        await pins.clearCustomQuestion(currentPin: _ownPin.text);
      } else {
        await pins.setCustomQuestion(
          currentPin: _ownPin.text,
          question: own.question,
          answer: own.answer,
        );
      }
      if (!mounted) return;
      showAppToast(
        context,
        (remove ? 'auth.ownQuestion.removed' : 'auth.ownQuestion.saved').tr(),
        icon: Icons.check_circle_outline,
      );
      _own.clear();
      _ownPin.clear();
      await _loadOwnQuestion();
    } on Failure catch (failure) {
      if (mounted) setState(() => _ownError = _messageFor(failure));
    } finally {
      if (mounted) setState(() => _ownBusy = false);
    }
  }

  Future<void> _loadConfigured() async {
    unawaited(_loadOwnQuestion());
    final List<SecurityQuestion> configured = await ref
        .read(pinRepositoryProvider)
        .configuredQuestions();
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
    _own.dispose();
    _ownPin.dispose();
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
      await ref
          .read(pinRepositoryProvider)
          .setSecurityAnswers(currentPin: _pin.text, answers: answers);
      if (!mounted) return;
      showAppToast(
        context,
        'auth.securityQuestions.saved'.tr(),
        icon: Icons.check_circle_outline,
      );
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
      AccountLockedFailure(:final int? minutesRemaining) =>
        minutesRemaining != null
            ? 'auth.errors.locked'.tr(
                namedArgs: <String, String>{'minutes': '$minutesRemaining'},
              )
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
              _configured
                  ? 'auth.securityQuestions.replaceIntro'.tr()
                  : 'auth.securityQuestions.intro'.tr(),
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
              Text(
                _formError!,
                style: text.bodyMedium?.copyWith(color: AppColors.critical),
              ),
            ],
            const SizedBox(height: AppSpacing.lg),
            AppButton(
              key: const Key('securityQuestionsSubmit'),
              label: 'auth.securityQuestions.submit'.tr(),
              isLoading: _busy,
              onPressed: _busy ? null : _submit,
            ),
            const SizedBox(height: AppSpacing.xl),
            OwnQuestionField(
              controller: _own,
              enabled: !_ownBusy,
              currentQuestion: _ownQuestion,
              onToggled: () => setState(() {}),
            ),
            // Its PIN box and buttons appear once there is something to save
            // or remove, so the screen doesn't show two PIN boxes for nothing.
            if (_own.enabled || _ownQuestion != null) ...<Widget>[
              const SizedBox(height: AppSpacing.md),
              PinField(
                controller: _ownPin,
                label: 'auth.securityQuestions.currentPin'.tr(),
                errorText: _ownPinErrorKey?.tr(),
              ),
              if (_ownError != null) ...<Widget>[
                const SizedBox(height: AppSpacing.md),
                Text(
                  _ownError!,
                  style: text.bodyMedium?.copyWith(color: AppColors.critical),
                ),
              ],
              const SizedBox(height: AppSpacing.md),
              if (_own.enabled)
                AppButton(
                  key: const Key('ownQuestionSave'),
                  label: 'auth.ownQuestion.save'.tr(),
                  variant: AppButtonVariant.secondary,
                  isLoading: _ownBusy,
                  onPressed: _ownBusy ? null : () => _saveOwnQuestion(),
                ),
              if (_ownQuestion != null)
                Center(
                  child: AppButton(
                    key: const Key('ownQuestionRemove'),
                    label: 'auth.ownQuestion.remove'.tr(),
                    variant: AppButtonVariant.danger,
                    onPressed: _ownBusy
                        ? null
                        : () => _saveOwnQuestion(remove: true),
                  ),
                ),
            ],
            const SizedBox(height: AppSpacing.lg),
          ],
        ),
      ),
    );
  }
}
