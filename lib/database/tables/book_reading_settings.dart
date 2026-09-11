import 'package:drift/drift.dart';

import 'books.dart';

class BookReadingSettings extends Table {
  IntColumn get bookId =>
      integer().references(Books, #id, onDelete: KeyAction.cascade)();
  RealColumn get fontSize => real().customConstraint(
        'NOT NULL CHECK (font_size >= 12 AND font_size <= 28)',
      )();
  RealColumn get lineHeight => real().customConstraint(
        'NOT NULL CHECK (line_height >= 1.2 AND line_height <= 2.5)',
      )();
  RealColumn get margin => real().customConstraint(
        'NOT NULL CHECK (margin >= 8 AND margin <= 48)',
      )();
  TextColumn get fontFamily => text().withLength(max: 100).nullable()();
  RealColumn get paragraphSpacing => real().customConstraint(
        'NOT NULL CHECK (paragraph_spacing >= 0 AND paragraph_spacing <= 32)',
      )();
  RealColumn get letterSpacing => real().customConstraint(
        'NOT NULL CHECK (letter_spacing >= -1 AND letter_spacing <= 3)',
      )();
  RealColumn get wordSpacing => real().customConstraint(
        'NOT NULL DEFAULT 0 CHECK (word_spacing >= -1 AND word_spacing <= 8)',
      )();
  BoolColumn get boldText => boolean().withDefault(const Constant(false))();
  TextColumn get textAlignment => text().customConstraint(
        "NOT NULL DEFAULT 'start' "
        "CHECK (text_alignment IN ('start', 'justify'))",
      )();
  IntColumn get paragraphIndent => integer().customConstraint(
        'NOT NULL DEFAULT 0 CHECK (paragraph_indent >= 0 '
        'AND paragraph_indent <= 4)',
      )();
  RealColumn get pdfCropAmount => real().customConstraint(
        'NOT NULL DEFAULT 0 CHECK (pdf_crop_amount >= 0 '
        'AND pdf_crop_amount <= 0.2)',
      )();
  RealColumn get pdfContrast => real().customConstraint(
        'NOT NULL DEFAULT 1 CHECK (pdf_contrast >= 1 AND pdf_contrast <= 2)',
      )();
  TextColumn get pdfPageLayout => text().customConstraint(
        "NOT NULL DEFAULT 'single' "
        "CHECK (pdf_page_layout IN ('single', 'double'))",
      )();
  RealColumn get topContentPadding => real().customConstraint(
        'NOT NULL CHECK (top_content_padding >= 0 '
        'AND top_content_padding <= 96)',
      )();
  TextColumn get pageTurnEffect => text().customConstraint(
        "NOT NULL CHECK (page_turn_effect IN ('curl', 'slide', 'plain'))",
      )();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {bookId};
}
