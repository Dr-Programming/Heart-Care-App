import 'package:flutter_test/flutter_test.dart';
import 'package:libu_care/core/clinical/alert_evaluator.dart';
import 'package:libu_care/features/education/domain/entities/content_block.dart';

void main() {
  test('parses a paragraph block', () {
    final ContentBlock block = ContentBlock.fromJson(<String, dynamic>{
      'type': 'paragraph',
      'text': 'Hello',
    });
    expect(block, isA<ParagraphBlock>());
    expect((block as ParagraphBlock).text, 'Hello');
  });

  test('parses a bullet list block', () {
    final ContentBlock block = ContentBlock.fromJson(<String, dynamic>{
      'type': 'bulletList',
      'items': <String>['a', 'b'],
    });
    expect((block as BulletListBlock).items, <String>['a', 'b']);
  });

  test('parses a callout block', () {
    final ContentBlock block = ContentBlock.fromJson(<String, dynamic>{
      'type': 'callout',
      'style': 'warning',
      'text': 'Careful',
    });
    final CalloutBlock callout = block as CalloutBlock;
    expect(callout.style, CalloutStyle.warning);
    expect(callout.text, 'Careful');
  });

  test('parses a reference link block', () {
    final ContentBlock block = ContentBlock.fromJson(<String, dynamic>{
      'type': 'referenceLink',
      'label': 'Watch',
      'url': 'https://example.com',
      'kind': 'video',
    });
    final ReferenceLinkBlock link = block as ReferenceLinkBlock;
    expect(link.kind, ReferenceKind.video);
  });

  test('parses a categoryRanges chart block', () {
    final ContentBlock block = ContentBlock.fromJson(<String, dynamic>{
      'type': 'chart',
      'chartType': 'categoryRanges',
      'title': 'Blood pressure categories',
      'citation': 'Source',
      'unit': 'mmHg',
      'ranges': <Map<String, dynamic>>[
        <String, dynamic>{
          'label': 'Normal',
          'low': 0,
          'high': 89,
          'severity': 'NONE',
        },
      ],
    });
    final CategoryRangesChartBlock chart = block as CategoryRangesChartBlock;
    expect(chart.ranges.single.severity, Severity.none);
  });

  test('parses a bar chart block', () {
    final ContentBlock block = ContentBlock.fromJson(<String, dynamic>{
      'type': 'chart',
      'chartType': 'bar',
      'title': 'NCD statistics',
      'citation': 'Source',
      'unit': '%',
      'bars': <Map<String, dynamic>>[
        <String, dynamic>{'label': 'Hypertension', 'value': 15.8},
      ],
    });
    final BarChartBlock chart = block as BarChartBlock;
    expect(chart.bars.single.value, 15.8);
  });

  test('an unknown block type throws', () {
    expect(
      () => ContentBlock.fromJson(<String, dynamic>{'type': 'video'}),
      throwsFormatException,
    );
  });
}
