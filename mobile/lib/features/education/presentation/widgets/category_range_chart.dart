import 'package:flutter/material.dart';

import '../../../../core/widgets/status_chip.dart';
import '../../domain/entities/content_block.dart';

class CategoryRangeChart extends StatelessWidget {
  const CategoryRangeChart({required this.chart, super.key});

  final CategoryRangesChartBlock chart;

  @override
  Widget build(BuildContext context) {
    if (chart.ranges.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(chart.title, style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 4),
          Text(
            chart.citation,
            style: Theme.of(
              context,
            ).textTheme.labelSmall?.copyWith(fontStyle: FontStyle.italic),
          ),
        ],
      );
    }

    final double total = chart.ranges.last.high - chart.ranges.first.low;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(chart.title, style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Row(
            children: <Widget>[
              for (final CategoryRange range in chart.ranges)
                Expanded(
                  flex: ((range.high - range.low) / total * 1000).round(),
                  child: Container(
                    height: 28,
                    color: SeverityStyle.of(range.severity).background,
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 12,
          runSpacing: 4,
          children: <Widget>[
            for (final CategoryRange range in chart.ranges)
              Text(
                '${range.label} (${range.low.toStringAsFixed(0)}-${range.high.toStringAsFixed(0)} ${chart.unit})',
                style: Theme.of(context).textTheme.labelSmall,
              ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          chart.citation,
          style: Theme.of(
            context,
          ).textTheme.labelSmall?.copyWith(fontStyle: FontStyle.italic),
        ),
      ],
    );
  }
}
