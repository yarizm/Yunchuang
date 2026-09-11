import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yunchuang/pages/reader/pdf_reader.dart';

void main() {
  test('PDF crop scale clamps input and removes symmetric margins', () {
    expect(pdfCropScale(-1), 1);
    expect(pdfCropScale(0.1), closeTo(1.25, 0.0001));
    expect(pdfCropScale(1), closeTo(5 / 3, 0.0001));
  });

  test('PDF contrast matrix preserves alpha and adjusts RGB around midpoint',
      () {
    expect(
      pdfContrastMatrix(1),
      const <double>[
        1,
        0,
        0,
        0,
        0,
        0,
        1,
        0,
        0,
        0,
        0,
        0,
        1,
        0,
        0,
        0,
        0,
        0,
        1,
        0,
      ],
    );
    final matrix = pdfContrastMatrix(1.5);
    expect(matrix[0], 1.5);
    expect(matrix[4], -64);
    expect(matrix[18], 1);
  });

  test('PDF double-page mode is active only in landscape', () {
    expect(
      pdfDoublePageActive(
        enabled: true,
        orientation: Orientation.landscape,
      ),
      isTrue,
    );
    expect(
      pdfDoublePageActive(
        enabled: true,
        orientation: Orientation.portrait,
      ),
      isFalse,
    );
    expect(
      pdfDoublePageActive(
        enabled: false,
        orientation: Orientation.landscape,
      ),
      isFalse,
    );
  });

  test('selected PDF line page wins over controller viewport page', () {
    expect(
      resolvePdfSelectionPageIndex(
        selectedLinePageIndex: 6,
        controllerPageNumber: 4,
        pageCount: 10,
      ),
      6,
    );
    expect(
      resolvePdfSelectionPageIndex(
        controllerPageNumber: 4,
        pageCount: 10,
      ),
      3,
    );
  });

  testWidgets('PDF page effects avoid unnecessary layers at defaults',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: PdfPageEffects(
          cropAmount: 0,
          contrast: 1,
          child: SizedBox(),
        ),
      ),
    );

    expect(find.byKey(const Key('pdf-crop-clip')), findsNothing);
    expect(find.byKey(const Key('pdf-contrast-filter')), findsNothing);
  });

  testWidgets('PDF page effects apply crop and contrast layers',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: PdfPageEffects(
          cropAmount: 0.1,
          contrast: 1.5,
          child: SizedBox(),
        ),
      ),
    );

    expect(find.byKey(const Key('pdf-crop-clip')), findsOneWidget);
    expect(find.byKey(const Key('pdf-contrast-filter')), findsOneWidget);
    final transform = tester.widget<Transform>(
      find.byKey(const Key('pdf-crop-transform')),
    );
    expect(transform.transform.getMaxScaleOnAxis(), closeTo(1.25, 0.0001));
  });

  testWidgets('PDF selection action bar exposes copy, lookup and translation',
      (tester) async {
    var copied = 0;
    var lookedUp = 0;
    var translated = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 220,
              child: PdfSelectionActionBar(
                onCopy: () => copied++,
                onVocabulary: () => lookedUp++,
                onTranslate: () => translated++,
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byTooltip('复制'));
    await tester.tap(find.byKey(const Key('pdf-vocabulary-action')));
    await tester.tap(find.byKey(const Key('pdf-translation-action')));

    expect(copied, 1);
    expect(lookedUp, 1);
    expect(translated, 1);
  });
}
