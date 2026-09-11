import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:yunchuang/parsers/pdf_parser.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

void main() {
  test('extractPageTexts returns requested PDF pages from one document open',
      () async {
    final tempDir = await Directory.systemTemp.createTemp('pdf_parser_test_');
    addTearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    final file = File('${tempDir.path}${Platform.pathSeparator}sample.pdf');
    final document = PdfDocument();
    try {
      document.pages.add().graphics.drawString(
            'first page text',
            PdfStandardFont(PdfFontFamily.helvetica, 12),
          );
      document.pages.add().graphics.drawString(
            'second page text',
            PdfStandardFont(PdfFontFamily.helvetica, 12),
          );
      await file.writeAsBytes(await document.save(), flush: true);
    } finally {
      document.dispose();
    }

    final pages = await PdfParser.extractPageTexts(file.path, [1, 10]);

    expect(pages[1], contains('second page text'));
    expect(pages[10], '');
  });
}
