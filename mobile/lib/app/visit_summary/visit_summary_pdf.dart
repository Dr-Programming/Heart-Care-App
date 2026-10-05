import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

/// One A4 page's share of the captured summary, in image pixels.
class PageSlice {
  const PageSlice(this.top, this.height);

  final int top;
  final int height;
}

/// Turns the on-screen summary into a PDF and opens the system sheet to save
/// or share it.
///
/// The summary is captured as an image rather than re-typeset, so Amharic
/// text renders exactly as on screen without bundling an Ethiopic font, and
/// the export works offline. The image is cut across standard A4 pages so it
/// prints at full width.
class VisitSummaryPdf {
  const VisitSummaryPdf._();

  static const double _margin = 24;

  static PdfPageFormat get _format => PdfPageFormat.a4.copyWith(
    marginLeft: _margin,
    marginRight: _margin,
    marginTop: _margin,
    marginBottom: _margin,
  );

  /// How a capture [width] x [height] pixels is split across pages.
  static List<PageSlice> slices({required int width, required int height}) {
    final PdfPageFormat format = _format;
    final int perPage = (width * format.availableHeight / format.availableWidth)
        .floor();
    return <PageSlice>[
      for (int top = 0; top < height; top += perPage)
        PageSlice(top, (height - top) < perPage ? height - top : perPage),
    ];
  }

  static Future<Uint8List> build(RenderRepaintBoundary boundary) async {
    final ui.Image image = await boundary.toImage(pixelRatio: 3);
    final pw.Document doc = pw.Document();
    for (final PageSlice slice in slices(
      width: image.width,
      height: image.height,
    )) {
      final Uint8List png = await _crop(image, slice);
      doc.addPage(
        pw.Page(
          pageFormat: _format,
          build: (pw.Context _) => pw.Align(
            alignment: pw.Alignment.topCenter,
            child: pw.Image(pw.MemoryImage(png), fit: pw.BoxFit.fitWidth),
          ),
        ),
      );
    }
    image.dispose();
    return doc.save();
  }

  static Future<Uint8List> _crop(ui.Image image, PageSlice slice) async {
    final ui.PictureRecorder recorder = ui.PictureRecorder();
    ui.Canvas(recorder).drawImageRect(
      image,
      ui.Rect.fromLTWH(
        0,
        slice.top.toDouble(),
        image.width.toDouble(),
        slice.height.toDouble(),
      ),
      ui.Rect.fromLTWH(0, 0, image.width.toDouble(), slice.height.toDouble()),
      ui.Paint(),
    );
    final ui.Image part = await recorder.endRecording().toImage(
      image.width,
      slice.height,
    );
    final ByteData? bytes = await part.toByteData(
      format: ui.ImageByteFormat.png,
    );
    part.dispose();
    return bytes!.buffer.asUint8List();
  }

  static Future<void> share(
    RenderRepaintBoundary boundary, {
    required String filename,
  }) async {
    await Printing.sharePdf(bytes: await build(boundary), filename: filename);
  }
}
