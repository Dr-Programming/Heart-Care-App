import 'package:flutter_test/flutter_test.dart';
import 'package:libu_care/app/visit_summary/visit_summary_pdf.dart';

void main() {
  test('a summary taller than a page is split across A4 pages', () {
    // A4 content box at 24 pt margins is about 547 x 794 pt, so a 1000 px
    // wide capture fits about 1451 px of height on each page.
    final List<PageSlice> slices = VisitSummaryPdf.slices(
      width: 1000,
      height: 3000,
    );

    expect(slices.length, 3);
    expect(slices.first.top, 0);
    expect(slices.last.top + slices.last.height, 3000);
    for (int i = 1; i < slices.length; i++) {
      expect(slices[i].top, slices[i - 1].top + slices[i - 1].height);
    }
  });

  test('a short summary is one page', () {
    expect(VisitSummaryPdf.slices(width: 1000, height: 900), hasLength(1));
  });
}
