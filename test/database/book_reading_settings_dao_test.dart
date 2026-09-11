import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yunchuang/database/app_database.dart';
import 'package:yunchuang/database/daos/book_reading_settings_dao.dart';

void main() {
  late AppDatabase database;
  late BookReadingSettingsDao dao;
  late int bookId;

  setUp(() async {
    database = AppDatabase.connect(NativeDatabase.memory());
    dao = BookReadingSettingsDao(database);
    bookId = await database.into(database.books).insert(
          BooksCompanion.insert(
            title: '单书排版',
            filePath: 'layout.txt',
            format: 'txt',
            fileSize: 1,
          ),
        );
  });

  tearDown(() => database.close());

  test('creates, updates, watches, and resets one book profile', () async {
    final changes = <BookReadingSetting?>[];
    final subscription = dao.watchForBook(bookId).listen(changes.add);
    addTearDown(subscription.cancel);

    await dao.save(
      bookId: bookId,
      fontSize: 20,
      lineHeight: 1.9,
      margin: 24,
      fontFamily: ' serif ',
      paragraphSpacing: 14,
      letterSpacing: 0.8,
      wordSpacing: 1.2,
      boldText: true,
      textAlignment: 'justify',
      paragraphIndent: 2,
      pdfCropAmount: 0.12,
      pdfContrast: 1.4,
      pdfPageLayout: 'double',
      topContentPadding: 30,
      pageTurnEffect: 'slide',
    );
    var settings = await dao.getForBook(bookId);
    expect(settings?.fontSize, 20);
    expect(settings?.fontFamily, 'serif');
    expect(settings?.pageTurnEffect, 'slide');
    expect(settings?.wordSpacing, 1.2);
    expect(settings?.boldText, isTrue);
    expect(settings?.textAlignment, 'justify');
    expect(settings?.paragraphIndent, 2);
    expect(settings?.pdfCropAmount, 0.12);
    expect(settings?.pdfContrast, 1.4);
    expect(settings?.pdfPageLayout, 'double');

    await dao.save(
      bookId: bookId,
      fontSize: 16,
      lineHeight: 1.5,
      margin: 18,
      paragraphSpacing: 8,
      letterSpacing: 0.2,
      wordSpacing: 0,
      boldText: false,
      textAlignment: 'start',
      paragraphIndent: 0,
      pdfCropAmount: 0,
      pdfContrast: 1,
      pdfPageLayout: 'single',
      topContentPadding: 12,
      pageTurnEffect: 'plain',
    );
    settings = await dao.getForBook(bookId);
    expect(settings?.fontSize, 16);
    expect(settings?.fontFamily, isNull);
    expect(settings?.pageTurnEffect, 'plain');

    expect(await dao.reset(bookId), 1);
    expect(await dao.getForBook(bookId), isNull);
    await Future<void>.delayed(Duration.zero);
    expect(changes.whereType<BookReadingSetting>(), hasLength(2));
    expect(changes.last, isNull);
  });

  test('validates numeric ranges, page effects, and font names', () async {
    Future<void> save({
      double fontSize = 18,
      double wordSpacing = 0,
      String textAlignment = 'start',
      int paragraphIndent = 0,
      double pdfCropAmount = 0,
      double pdfContrast = 1,
      String pdfPageLayout = 'single',
      String pageTurnEffect = 'curl',
      String? fontFamily,
    }) {
      return dao.save(
        bookId: bookId,
        fontSize: fontSize,
        lineHeight: 1.8,
        margin: 20,
        fontFamily: fontFamily,
        paragraphSpacing: 12,
        letterSpacing: 0.5,
        wordSpacing: wordSpacing,
        boldText: false,
        textAlignment: textAlignment,
        paragraphIndent: paragraphIndent,
        pdfCropAmount: pdfCropAmount,
        pdfContrast: pdfContrast,
        pdfPageLayout: pdfPageLayout,
        topContentPadding: 16,
        pageTurnEffect: pageTurnEffect,
      );
    }

    expect(save(fontSize: 40), throwsArgumentError);
    expect(save(wordSpacing: 9), throwsArgumentError);
    expect(save(textAlignment: 'center'), throwsArgumentError);
    expect(save(paragraphIndent: 5), throwsArgumentError);
    expect(save(pdfCropAmount: 0.21), throwsArgumentError);
    expect(save(pdfContrast: 2.1), throwsArgumentError);
    expect(save(pdfPageLayout: 'spread'), throwsArgumentError);
    expect(save(pageTurnEffect: 'instant'), throwsArgumentError);
    expect(
      save(fontFamily: List.filled(101, 'x').join()),
      throwsArgumentError,
    );
  });

  test('deleting a book cascades its reading profile', () async {
    await dao.save(
      bookId: bookId,
      fontSize: 18,
      lineHeight: 1.8,
      margin: 20,
      paragraphSpacing: 12,
      letterSpacing: 0.5,
      wordSpacing: 0,
      boldText: false,
      textAlignment: 'start',
      paragraphIndent: 0,
      pdfCropAmount: 0,
      pdfContrast: 1,
      pdfPageLayout: 'single',
      topContentPadding: 16,
      pageTurnEffect: 'curl',
    );

    await (database.delete(database.books)
          ..where((book) => book.id.equals(bookId)))
        .go();

    expect(await dao.getForBook(bookId), isNull);
  });
}
