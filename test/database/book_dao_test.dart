import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yunchuang/database/app_database.dart';
import 'package:yunchuang/database/daos/book_dao.dart';
import 'package:yunchuang/models/book_reading_status.dart';
import 'package:yunchuang/models/book_shelf_options.dart';

void main() {
  late AppDatabase database;
  late BookDao dao;

  setUp(() {
    database = AppDatabase.connect(NativeDatabase.memory());
    dao = BookDao(database);
  });

  tearDown(() => database.close());

  test('sorts shelf books in the database for every supported mode', () async {
    final gammaId = await _insertBook(
      database,
      title: 'Gamma',
      author: 'Zoe',
      createdAt: DateTime(2026, 1, 1),
    );
    final alphaId = await _insertBook(
      database,
      title: 'Alpha',
      author: 'Yang',
      createdAt: DateTime(2026, 1, 2),
    );
    await _insertBook(
      database,
      title: 'Beta',
      author: 'Amy',
      createdAt: DateTime(2026, 1, 3),
    );
    await database.into(database.readingProgress).insert(
          ReadingProgressCompanion.insert(
            bookId: Value(gammaId),
            totalReadingSeconds: const Value(20),
            lastReadAt: Value(DateTime(2026, 1, 4)),
          ),
        );
    await database.into(database.readingProgress).insert(
          ReadingProgressCompanion.insert(
            bookId: Value(alphaId),
            totalReadingSeconds: const Value(10),
            lastReadAt: Value(DateTime(2026, 1, 5)),
          ),
        );

    expect(
      await _titles(dao, BookSortMode.recentlyRead),
      ['Alpha', 'Gamma', 'Beta'],
    );
    expect(
      await _titles(dao, BookSortMode.importedNewest),
      ['Beta', 'Alpha', 'Gamma'],
    );
    expect(
      await _titles(dao, BookSortMode.title),
      ['Alpha', 'Beta', 'Gamma'],
    );
    expect(
      await _titles(dao, BookSortMode.author),
      ['Beta', 'Alpha', 'Gamma'],
    );
    expect(
      await _titles(dao, BookSortMode.readingTime),
      ['Gamma', 'Alpha', 'Beta'],
    );
  });

  test('limits the sorted query to one custom collection', () async {
    final gammaId = await _insertBook(
      database,
      title: 'Gamma',
      author: '',
      createdAt: DateTime(2026, 1, 1),
    );
    await _insertBook(
      database,
      title: 'Alpha',
      author: '',
      createdAt: DateTime(2026, 1, 2),
    );
    final betaId = await _insertBook(
      database,
      title: 'Beta',
      author: '',
      createdAt: DateTime(2026, 1, 3),
    );
    final collectionId = await database.into(database.bookCollections).insert(
          BookCollectionsCompanion.insert(name: 'Selected'),
        );
    await database.batch((batch) {
      batch.insertAll(database.bookCollectionItems, [
        BookCollectionItemsCompanion.insert(
          collectionId: collectionId,
          bookId: gammaId,
        ),
        BookCollectionItemsCompanion.insert(
          collectionId: collectionId,
          bookId: betaId,
        ),
      ]);
    });

    final books = await dao
        .watchShelfBooks(
          collectionId: collectionId,
          sortMode: BookSortMode.title,
        )
        .first;

    expect(books.map((book) => book.title), ['Beta', 'Gamma']);
  });

  test('updates status and deletes multiple books in one operation', () async {
    final firstId = await _insertBook(
      database,
      title: 'First',
      author: '',
      createdAt: DateTime(2026, 1, 1),
    );
    final secondId = await _insertBook(
      database,
      title: 'Second',
      author: '',
      createdAt: DateTime(2026, 1, 2),
    );

    expect(
      await dao.updateBooksReadingStatus({firstId, secondId}, 'paused'),
      2,
    );
    expect(
      (await database.select(database.books).get())
          .map((book) => book.readingStatus)
          .toSet(),
      {'paused'},
    );

    expect(await dao.deleteBooks({firstId, secondId}), 2);
    expect(await database.select(database.books).get(), isEmpty);
  });

  test('lists, filters, and orders books inside a series', () async {
    await _insertBook(
      database,
      title: 'Volume 2',
      author: '',
      createdAt: DateTime(2026, 1, 1),
      seriesName: 'Saga',
      seriesIndex: 2,
    );
    await _insertBook(
      database,
      title: 'Standalone',
      author: '',
      createdAt: DateTime(2026, 1, 2),
    );
    await _insertBook(
      database,
      title: 'Volume 1',
      author: '',
      createdAt: DateTime(2026, 1, 3),
      seriesName: 'Saga',
      seriesIndex: 1,
    );

    expect(await dao.watchSeriesNames().first, ['Saga']);
    expect(
      await _titles(dao, BookSortMode.series),
      ['Volume 1', 'Volume 2', 'Standalone'],
    );
    final seriesBooks = await dao
        .watchShelfBooks(
          seriesName: 'Saga',
          sortMode: BookSortMode.series,
        )
        .first;
    expect(
      seriesBooks.map((book) => book.seriesIndex),
      [1, 2],
    );
  });

  test('filters inferred and manually overridden reading statuses in SQL',
      () async {
    final unreadId = await _insertBook(
      database,
      title: 'Unread',
      author: '',
      createdAt: DateTime(2026, 1, 1),
    );
    final readingId = await _insertBook(
      database,
      title: 'Reading',
      author: '',
      createdAt: DateTime(2026, 1, 2),
    );
    final finishedId = await _insertBook(
      database,
      title: 'Finished',
      author: '',
      createdAt: DateTime(2026, 1, 3),
    );
    final overrideId = await _insertBook(
      database,
      title: 'Manual unread',
      author: '',
      createdAt: DateTime(2026, 1, 4),
      readingStatus: 'unread',
    );
    await _insertBook(
      database,
      title: 'Paused',
      author: '',
      createdAt: DateTime(2026, 1, 5),
      readingStatus: 'paused',
    );
    await database.batch((batch) {
      batch.insertAll(database.readingProgress, [
        ReadingProgressCompanion.insert(
          bookId: Value(readingId),
          percentage: const Value(0.4),
        ),
        ReadingProgressCompanion.insert(
          bookId: Value(finishedId),
          percentage: const Value(0.995),
        ),
        ReadingProgressCompanion.insert(
          bookId: Value(overrideId),
          percentage: const Value(1),
        ),
      ]);
    });

    Future<Set<String>> filtered(BookReadingStatus status) async {
      final books = await dao.watchShelfBooks(readingStatus: status).first;
      return books.map((book) => book.title).toSet();
    }

    expect(await filtered(BookReadingStatus.unread), {
      'Unread',
      'Manual unread',
    });
    expect(await filtered(BookReadingStatus.reading), {'Reading'});
    expect(await filtered(BookReadingStatus.finished), {'Finished'});
    expect(await filtered(BookReadingStatus.paused), {'Paused'});
    expect(unreadId, greaterThan(0));
  });
}

Future<List<String>> _titles(BookDao dao, BookSortMode sortMode) async {
  final books = await dao.watchShelfBooks(sortMode: sortMode).first;
  return books.map((book) => book.title).toList(growable: false);
}

Future<int> _insertBook(
  AppDatabase database, {
  required String title,
  required String author,
  required DateTime createdAt,
  String? seriesName,
  double? seriesIndex,
  String? readingStatus,
}) {
  return database.into(database.books).insert(
        BooksCompanion.insert(
          title: title,
          author: Value(author),
          filePath: '$title.txt',
          format: 'txt',
          fileSize: 1,
          seriesName: Value(seriesName),
          seriesIndex: Value(seriesIndex),
          readingStatus: Value(readingStatus),
          createdAt: Value(createdAt),
          updatedAt: Value(createdAt),
        ),
      );
}
