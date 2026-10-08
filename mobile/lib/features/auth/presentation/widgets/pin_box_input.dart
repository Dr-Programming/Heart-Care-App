import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';

class PinBoxInput extends StatefulWidget {
  const PinBoxInput({
    required this.onCompleted,
    this.onIncomplete,
    this.errorText,
    this.enabled = true,
    super.key,
  });

  final ValueChanged<String> onCompleted;

  final VoidCallback? onIncomplete;
  final String? errorText;

  /// When false the boxes refuse focus, so no keyboard can open over them.
  final bool enabled;

  @override
  State<PinBoxInput> createState() => _PinBoxInputState();
}

class _PinBoxInputState extends State<PinBoxInput> {
  final List<TextEditingController> _controllers = List.generate(
    4,
    (_) => TextEditingController(),
  );
  final List<FocusNode> _focusNodes = List.generate(4, (_) => FocusNode());

  @override
  void initState() {
    super.initState();
    for (var i = 0; i < 4; i++) {
      _focusNodes[i].addListener(() {
        if (_focusNodes[i].hasFocus) {
          _controllers[i].selection = TextSelection(
            baseOffset: 0,
            extentOffset: _controllers[i].text.length,
          );
        }
      });
    }
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  void _onDigitChanged(int index, String value) {
    if (value.isNotEmpty && index < 3) {
      _focusNodes[index + 1].requestFocus();
    } else if (value.isEmpty && index > 0) {
      _focusNodes[index - 1].requestFocus();
    }
    _notify();
  }

  void _notify() {
    final String pin = _controllers.map((c) => c.text).join();

    if (pin.length == 4) {
      widget.onCompleted(pin);
    } else {
      widget.onIncomplete?.call();
    }
  }

  /// Backspace in an empty box changes no text, so onChanged never fires and
  /// the patient would have to tap the previous box by hand. Treat it as
  /// "delete the digit before".
  KeyEventResult _onKey(int index, KeyEvent event) {
    final bool isBackspace =
        event.logicalKey == LogicalKeyboardKey.backspace &&
        (event is KeyDownEvent || event is KeyRepeatEvent);
    if (!isBackspace || index == 0 || _controllers[index].text.isNotEmpty) {
      return KeyEventResult.ignored;
    }
    _controllers[index - 1].clear();
    _focusNodes[index - 1].requestFocus();
    _notify();
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              for (var i = 0; i < 4; i++) ...<Widget>[
                if (i > 0) const SizedBox(width: AppSpacing.sm),
                SizedBox(
                  width: 52,
                  height: 56,
                  child: Focus(
                    canRequestFocus: false,
                    skipTraversal: true,
                    onKeyEvent: (FocusNode _, KeyEvent event) =>
                        _onKey(i, event),
                    child: TextField(
                      controller: _controllers[i],
                      focusNode: _focusNodes[i],
                      enabled: widget.enabled,
                      textAlign: TextAlign.center,
                      obscureText: true,
                      keyboardType: TextInputType.number,
                      maxLength: 1,
                      inputFormatters: <TextInputFormatter>[
                        FilteringTextInputFormatter.digitsOnly,
                      ],
                      decoration: InputDecoration(
                        counterText: '',
                        filled: true,
                        fillColor: AppColors.surfaceAlt,
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(
                            AppSpacing.fieldRadius,
                          ),
                          borderSide: const BorderSide(color: AppColors.border),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(
                            AppSpacing.fieldRadius,
                          ),
                          borderSide: const BorderSide(
                            color: AppColors.primary,
                            width: 2,
                          ),
                        ),
                      ),
                      onChanged: (value) => _onDigitChanged(i, value),
                    ),
                  ),
                ),
              ],
            ],
          ),
          if (widget.errorText != null) ...<Widget>[
            const SizedBox(height: AppSpacing.xs),
            Text(
              widget.errorText!,
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: AppColors.critical),
            ),
          ],
        ],
      ),
    );
  }
}
