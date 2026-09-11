import 'package:flutter_test/flutter_test.dart';
import 'package:yunchuang/database/app_database.dart';
import 'package:yunchuang/providers/book_reading_settings_provider.dart';
import 'package:yunchuang/providers/preferences_provider.dart';

void main() {
  test('book layout overrides typography while retaining global app settings',
      () {
    const global = ReadingPreferences(
      fontSize: 18,
      lineHeight: 1.8,
      theme: 'dark',
      keepScreenOn: false,
      preferredOrientation: 'portrait',
      readingBrightness: 0.6,
      brightnessGestureEnabled: true,
      lineFocusEnabled: true,
      lineFocusLineCount: 5,
      lineFocusDimAmount: 0.4,
      pdfCropAmount: 0.04,
      pdfContrast: 1.1,
      pdfPageLayout: 'single',
      margin: 20,
      fontFamily: 'sans-serif',
      paragraphSpacing: 12,
      letterSpacing: 0.5,
      wordSpacing: 0,
      boldText: false,
      textAlignment: 'start',
      paragraphIndent: 0,
      pageTurnEffect: 'curl',
      topContentPadding: 16,
    );
    final book = BookReadingSetting(
      bookId: 7,
      fontSize: 22,
      lineHeight: 2,
      margin: 28,
      fontFamily: null,
      paragraphSpacing: 18,
      letterSpacing: 1,
      wordSpacing: 2,
      boldText: true,
      textAlignment: 'justify',
      paragraphIndent: 2,
      pdfCropAmount: 0.14,
      pdfContrast: 1.6,
      pdfPageLayout: 'double',
      topContentPadding: 32,
      pageTurnEffect: 'slide',
      updatedAt: DateTime(2026),
    );

    final effective = applyBookReadingSettings(global, book);

    expect(effective.fontSize, 22);
    expect(effective.fontFamily, isNull);
    expect(effective.pageTurnEffect, 'slide');
    expect(effective.wordSpacing, 2);
    expect(effective.boldText, isTrue);
    expect(effective.textAlignment, 'justify');
    expect(effective.paragraphIndent, 2);
    expect(effective.pdfCropAmount, 0.14);
    expect(effective.pdfContrast, 1.6);
    expect(effective.pdfPageLayout, 'double');
    expect(effective.theme, 'dark');
    expect(effective.keepScreenOn, isFalse);
    expect(effective.preferredOrientation, 'portrait');
    expect(effective.readingBrightness, 0.6);
    expect(effective.brightnessGestureEnabled, isTrue);
    expect(effective.lineFocusEnabled, isTrue);
    expect(effective.lineFocusLineCount, 5);
    expect(effective.lineFocusDimAmount, 0.4);
  });

  test('missing book layout returns the global preference object', () {
    const global = ReadingPreferences(fontSize: 19);
    expect(applyBookReadingSettings(global, null), same(global));
  });
}
