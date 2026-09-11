import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/book_reading_settings.dart';

part 'book_reading_settings_dao.g.dart';

@DriftAccessor(tables: [BookReadingSettings])
class BookReadingSettingsDao extends DatabaseAccessor<AppDatabase>
    with _$BookReadingSettingsDaoMixin {
  BookReadingSettingsDao(super.db);

  Future<BookReadingSetting?> getForBook(int bookId) {
    return (select(bookReadingSettings)
          ..where((settings) => settings.bookId.equals(bookId)))
        .getSingleOrNull();
  }

  Stream<BookReadingSetting?> watchForBook(int bookId) {
    return (select(bookReadingSettings)
          ..where((settings) => settings.bookId.equals(bookId)))
        .watchSingleOrNull();
  }

  Future<void> save({
    required int bookId,
    required double fontSize,
    required double lineHeight,
    required double margin,
    required double paragraphSpacing,
    required double letterSpacing,
    required double wordSpacing,
    required bool boldText,
    required String textAlignment,
    required int paragraphIndent,
    required double pdfCropAmount,
    required double pdfContrast,
    required String pdfPageLayout,
    required double topContentPadding,
    required String pageTurnEffect,
    String? fontFamily,
  }) async {
    _validateRange(fontSize, 'fontSize', 12, 28);
    _validateRange(lineHeight, 'lineHeight', 1.2, 2.5);
    _validateRange(margin, 'margin', 8, 48);
    _validateRange(paragraphSpacing, 'paragraphSpacing', 0, 32);
    _validateRange(letterSpacing, 'letterSpacing', -1, 3);
    _validateRange(wordSpacing, 'wordSpacing', -1, 8);
    _validateRange(topContentPadding, 'topContentPadding', 0, 96);
    if (!const {'curl', 'slide', 'plain'}.contains(pageTurnEffect)) {
      throw ArgumentError.value(
        pageTurnEffect,
        'pageTurnEffect',
        '不支持的翻页效果',
      );
    }
    if (!const {'start', 'justify'}.contains(textAlignment)) {
      throw ArgumentError.value(
        textAlignment,
        'textAlignment',
        '不支持的正文对齐方式',
      );
    }
    if (paragraphIndent < 0 || paragraphIndent > 4) {
      throw ArgumentError.value(
        paragraphIndent,
        'paragraphIndent',
        '段首缩进必须在 0 到 4 个字符之间',
      );
    }
    _validateRange(pdfCropAmount, 'pdfCropAmount', 0, 0.2);
    _validateRange(pdfContrast, 'pdfContrast', 1, 2);
    if (!const {'single', 'double'}.contains(pdfPageLayout)) {
      throw ArgumentError.value(
        pdfPageLayout,
        'pdfPageLayout',
        'must be single or double',
      );
    }
    final normalizedFont = fontFamily?.trim();
    if (normalizedFont != null && normalizedFont.length > 100) {
      throw ArgumentError.value(fontFamily, 'fontFamily', '字体名称过长');
    }

    await into(bookReadingSettings).insertOnConflictUpdate(
      BookReadingSettingsCompanion(
        bookId: Value(bookId),
        fontSize: Value(fontSize),
        lineHeight: Value(lineHeight),
        margin: Value(margin),
        fontFamily: Value(
          normalizedFont == null || normalizedFont.isEmpty
              ? null
              : normalizedFont,
        ),
        paragraphSpacing: Value(paragraphSpacing),
        letterSpacing: Value(letterSpacing),
        wordSpacing: Value(wordSpacing),
        boldText: Value(boldText),
        textAlignment: Value(textAlignment),
        paragraphIndent: Value(paragraphIndent),
        pdfCropAmount: Value(pdfCropAmount),
        pdfContrast: Value(pdfContrast),
        pdfPageLayout: Value(pdfPageLayout),
        topContentPadding: Value(topContentPadding),
        pageTurnEffect: Value(pageTurnEffect),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<int> reset(int bookId) {
    return (delete(bookReadingSettings)
          ..where((settings) => settings.bookId.equals(bookId)))
        .go();
  }

  void _validateRange(
    double value,
    String name,
    double minimum,
    double maximum,
  ) {
    if (!value.isFinite || value < minimum || value > maximum) {
      throw ArgumentError.value(
        value,
        name,
        '必须在 $minimum 到 $maximum 之间',
      );
    }
  }
}
