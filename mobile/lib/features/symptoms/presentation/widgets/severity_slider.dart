import 'package:flutter/material.dart';

/// A 0-10 scale control — chest pain severity (FR-SYM-001) and energy level
/// (FR-SYM-007) both use it, just with different labels and a different
/// meaning of "high".
class SeveritySlider extends StatelessWidget {
  const SeveritySlider({
    required this.label,
    required this.value,
    required this.onChanged,
    this.min = 0,
    this.max = 10,
    super.key,
  });

  final String label;
  final int value;
  final ValueChanged<int> onChanged;
  final int min;
  final int max;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(child: Text(label, style: text.titleMedium)),
            Text('$value', style: text.headlineMedium),
          ],
        ),
        Slider(
          value: value.toDouble(),
          min: min.toDouble(),
          max: max.toDouble(),
          divisions: max - min,
          label: '$value',
          onChanged: (double v) => onChanged(v.round()),
        ),
      ],
    );
  }
}
