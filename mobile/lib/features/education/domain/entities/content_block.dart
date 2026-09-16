import '../../../../core/clinical/alert_evaluator.dart';

sealed class ContentBlock {
  const ContentBlock();

  factory ContentBlock.fromJson(Map<String, dynamic> json) {
    switch (json['type'] as String) {
      case 'paragraph':
        return ParagraphBlock(json['text'] as String);
      case 'bulletList':
        return BulletListBlock(
          (json['items'] as List<dynamic>).cast<String>(),
        );
      case 'callout':
        return CalloutBlock(
          style: CalloutStyle.values.byName(json['style'] as String),
          text: json['text'] as String,
        );
      case 'referenceLink':
        return ReferenceLinkBlock(
          label: json['label'] as String,
          url: json['url'] as String,
          kind: ReferenceKind.values.byName(json['kind'] as String),
        );
      case 'chart':
        return ChartBlock.fromJson(json);
      default:
        throw FormatException('Unknown block type: ${json['type']}');
    }
  }
}

class ParagraphBlock extends ContentBlock {
  const ParagraphBlock(this.text);
  final String text;
}

class BulletListBlock extends ContentBlock {
  const BulletListBlock(this.items);
  final List<String> items;
}

enum CalloutStyle { info, warning }

class CalloutBlock extends ContentBlock {
  const CalloutBlock({required this.style, required this.text});
  final CalloutStyle style;
  final String text;
}

enum ReferenceKind { article, video }

class ReferenceLinkBlock extends ContentBlock {
  const ReferenceLinkBlock({
    required this.label,
    required this.url,
    required this.kind,
  });
  final String label;
  final String url;
  final ReferenceKind kind;
}

sealed class ChartBlock extends ContentBlock {
  const ChartBlock();

  factory ChartBlock.fromJson(Map<String, dynamic> json) {
    switch (json['chartType'] as String) {
      case 'categoryRanges':
        return CategoryRangesChartBlock(
          title: json['title'] as String,
          citation: json['citation'] as String,
          unit: json['unit'] as String,
          ranges: (json['ranges'] as List<dynamic>)
              .map(
                (dynamic e) =>
                    CategoryRange.fromJson((e as Map<Object?, Object?>).cast()),
              )
              .toList(),
        );
      case 'bar':
        return BarChartBlock(
          title: json['title'] as String,
          citation: json['citation'] as String,
          unit: json['unit'] as String,
          bars: (json['bars'] as List<dynamic>)
              .map(
                (dynamic e) =>
                    BarDatum.fromJson((e as Map<Object?, Object?>).cast()),
              )
              .toList(),
        );
      default:
        throw FormatException('Unknown chart type: ${json['chartType']}');
    }
  }
}

class CategoryRange {
  const CategoryRange({
    required this.label,
    required this.low,
    required this.high,
    required this.severity,
  });

  factory CategoryRange.fromJson(Map<String, dynamic> json) => CategoryRange(
    label: json['label'] as String,
    low: (json['low'] as num).toDouble(),
    high: (json['high'] as num).toDouble(),
    severity: Severity.fromWire((json['severity'] as String).toUpperCase()),
  );

  final String label;
  final double low;
  final double high;
  final Severity severity;
}

class CategoryRangesChartBlock extends ChartBlock {
  const CategoryRangesChartBlock({
    required this.title,
    required this.citation,
    required this.unit,
    required this.ranges,
  });

  final String title;
  final String citation;
  final String unit;
  final List<CategoryRange> ranges;
}

class BarDatum {
  const BarDatum({required this.label, required this.value});

  factory BarDatum.fromJson(Map<String, dynamic> json) => BarDatum(
    label: json['label'] as String,
    value: (json['value'] as num).toDouble(),
  );

  final String label;
  final double value;
}

class BarChartBlock extends ChartBlock {
  const BarChartBlock({
    required this.title,
    required this.citation,
    required this.unit,
    required this.bars,
  });

  final String title;
  final String citation;
  final String unit;
  final List<BarDatum> bars;
}
