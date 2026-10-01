import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/widgets.dart';
import '../../auth_providers.dart';
import '../../domain/repositories/pin_repository.dart';
import '../../domain/validators.dart';
import '../widgets/pin_field.dart';

/// Change PIN. Works offline: the phone checks the current PIN and the change
/// reaches the server at the next sync (see [PinRepository]).
class ChangePinScreen extends ConsumerStatefulWidget {
  const ChangePinScreen({super.key});

  @override
  ConsumerState<ChangePinScreen> createState() => _ChangePinScreenState();
}

class _ChangePinScreenState extends ConsumerState<ChangePinScreen> {
  final TextEditingController _current = TextEditingController();
  final TextEditingController _next = TextEditingController();
  final TextEditingController _confirm = TextEditingController();

  String? _currentErrorKey;
  String? _nextErrorKey;
  String? _confirmErrorKey;
  String? _formError;
  bool _busy = false;

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final String? currentKey = validatePin(_current.text);
    String? nextKey = validatePin(_next.text);
    if (nextKey == null && _next.text == _current.text) {
      nextKey = 'auth.changePin.sameAsCurrent';
    }
    final String? confirmKey = _confirm.text == _next.text ? null : 'auth.errors.pinMismatch';
    setState(() {
      _currentErrorKey = currentKey;
      _nextErrorKey = nextKey;
      _confirmErrorKey = confirmKey;
      _formError = null;
    });
    if (currentKey != null || nextKey != null || confirmKey != null) return;

    setState(() => _busy = true);
    try {
      final PinChangeOutcome outcome = await ref
          .read(pinRepositoryProvider)
          .changePin(currentPin: _current.text, newPin: _next.text);
      if (!mounted) return;
      showAppToast(
        context,
        outcome == PinChangeOutcome.queued
            ? 'auth.changePin.queued'.tr()
            : 'auth.changePin.success'.tr(),
        icon: Icons.check_circle_outline,
        duration: const Duration(seconds: 5),
      );
      _current.clear();
      _next.clear();
      _confirm.clear();
    } on Failure catch (failure) {
      if (!mounted) return;
      setState(() => _formError = _messageFor(failure));
    } finally {
      // A change sent at once may have found the PIN changed elsewhere, which
      // signs the patient out; the gate then routes to sign-in.
      ref.read(signOutNoticeProvider.notifier).show(ref.read(pinRepositoryProvider).takeSignOutReason());
      await ref.read(realAuthGateProvider.notifier).refresh();
      if (mounted) setState(() => _busy = false);
    }
  }

  String _messageFor(Failure failure) {
    return switch (failure) {
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
      title: 'auth.changePin.title'.tr(),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            const SizedBox(height: AppSpacing.md),
            Text('auth.changePin.subtitle'.tr(), style: text.bodyMedium),
            const SizedBox(height: AppSpacing.lg),
            PinField(
              controller: _current,
              label: 'auth.changePin.current'.tr(),
              errorText: _currentErrorKey?.tr(),
            ),
            const SizedBox(height: AppSpacing.md),
            PinField(
              controller: _next,
              label: 'auth.changePin.new'.tr(),
              errorText: _nextErrorKey?.tr(),
            ),
            const SizedBox(height: AppSpacing.md),
            PinField(
              controller: _confirm,
              label: 'auth.changePin.confirm'.tr(),
              errorText: _confirmErrorKey?.tr(),
            ),
            if (_formError != null) ...<Widget>[
              const SizedBox(height: AppSpacing.md),
              Text(_formError!, style: text.bodyMedium?.copyWith(color: AppColors.critical)),
            ],
            const SizedBox(height: AppSpacing.lg),
            AppButton(
              key: const Key('changePinSubmit'),
              label: 'auth.changePin.submit'.tr(),
              isLoading: _busy,
              onPressed: _busy ? null : _submit,
            ),
          ],
        ),
      ),
    );
  }
}
