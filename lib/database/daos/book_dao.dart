import 'package:drift/drift.dart';
import '../app_database.dart';
import '../tables/books.dart';
import '../tables/book_collection_items.dart';
import '../tables/chapters.dart';
import '../tables/reading_progress.dart';
import '../../models/book_reading_status.dart';
import '../../models/book_shelf_options.dart';

part 'book_dao.g.dart';

@DriftAccessor(
  tables: [Books, BookCollectionItems, Chapters, ReadingProgress],
)
class BookDao extends DatabaseAccessor<AppDatabase> with _$BookDaoMixin {
  BookDao(super.db);

  Future<List<Book>> getAllBooks() => select(books).get();

  Stream<List<Book>> watchShelfBooks({
    int? collectionId,
    String? seriesName,
    BookReadingStatus? readingStatus,
    BookSortMode sortMode = BookSortMode.recentlyRead,
  }) {
    final usesProgress = sortMode == BookSortMode.recentlyRead ||
        sortMode == BookSortMode.readingTime ||
        readingStatus != null;
    final query = select(books).join([
      if (collectionId != null)
        innerJoin(
          bookCollectionItems,
          bookCollectionItems.bookId.equalsExp(books.id),
          useColumns: false,
        ),
      if (usesProgress)
        leftOuterJoin(
          readingProgress,
          readingProgress.bookId.equalsExp(books.id),
          useColumns: false,
        ),
    ]);
    if (collectionId != null) {
      query.where(bookCollectionItems.collectionId.equals(collectionId));
    }
    if (seriesName != null) {
      query.where(books.seriesName.equals(seriesName));
    }
    if (readingStatus != null) {
      query.where(_readingStatusPredicate(readingStatus));
    }
    query.orderBy(_shelfOrdering(sortMode));
    return query.watch().map(
          (rows) =>
              rows.map((row) => row.readTable(books)).toList(growable: false),
        );
  }

  List<OrderingTerm> _shelfOrdering(BookSortMode mode) {
    switch (mode) {
      case BookSortMode.recentlyRead:
        return [
          OrderingTerm.desc(readingProgress.lastReadAt),
          OrderingTerm.desc(books.createdAt),
          OrderingTerm.desc(books.id),
        ];
      case BookSortMode.importedNewest:
        return [
          OrderingTerm.desc(books.createdAt),
          OrderingTerm.desc(books.id),
        ];
      case BookSortMode.title:
        return [
          OrderingTerm.asc(books.title),
          OrderingTerm.asc(books.id),
        ];
      case BookSortMode.author:
        return [
          OrderingTerm.asc(books.author),
          OrderingTerm.asc(books.title),
          OrderingTerm.asc(books.id),
        ];
      case BookSortMode.series:
        return [
          OrderingTerm.asc(books.seriesName.isNull()),
          OrderingTerm.asc(books.seriesName),
          OrderingTerm.asc(books.seriesIndex),
          OrderingTerm.asc(books.title),
          OrderingTerm.asc(books.id),
        ];
      case BookSortMode.readingTime:
        return [
          OrderingTerm.desc(readingProgress.totalReadingSeconds),
          OrderingTerm.desc(readingProgress.lastReadAt),
          OrderingTerm.asc(books.title),
        ];
    }
  }

  Stream<List<String>> watchSeriesNames() {
    final query = selectOnly(books, distinct: true)
      ..addColumns([books.seriesName])
      ..where(
          books.seriesName.isNotNull() & books.seriesName.isBiggerThanValue(''))
      ..orderBy([OrderingTerm.asc(books.seriesName)]);
    return query.watch().map(
          (rows) => rows
              .map((row) => row.read(books.seriesName))
              .whereType<String>()
              .toList(growable: false),
        );
  }

  Expression<bool> _readingStatusPredicate(BookReadingStatus status) {
    final manual = books.readingStatus.equals(status.storageValue);
    final automatic = books.readingStatus.isNull();
    switch (status) {
      case BookReadingStatus.unread:
        final noProgress = readingProgress.bookId.isNull();
        final noActivity = readingProgress.percentage.equals(0) &
            readingProgress.totalReadingSeconds.equals(0);
        return manual | (automatic & (noProgress | noActivity));
      case BookReadingStatus.reading:
        final hasActivity = readingProgress.percentage.isBiggerThanValue(0) |
            readingProgress.totalReadingSeconds.isBiggerThanValue(0);
        return manual |
            (automatic &
                readingProgress.percentage.isSmallerThanValue(0.995) &
                hasActivity);
      case BookReadingStatus.finished:
        return manual |
            (automatic &
                readingProgress.percentage.isBiggerOrEqualValue(0.995));
      case BookReadingStatus.paused:
        return manual;
    }
  }

  Future<Book?> getBookById(int id) =>
      (select(books)..where((b) => b.id.equals(id))).getSingleOrNull();

  Future<Book?> getBookByFileHash(String fileHash) {
    return (select(books)
          ..where((book) => book.fileHash.equals(fileHash))
          ..orderBy([(book) => OrderingTerm.asc(book.id)])
          ..limit(1))
        .getSingleOrNull();
  }

  Future<List<Book>> getBooksByFileSize(int fileSize) =>
      (select(books)..where((book) => book.fileSize.equals(fileSize))).get();

  Future<Map<int, Book>> getBooksByIds(List<int> ids) async {
    if (ids.isEmpty) return {};
    final list = await (select(books)..where((b) => b.id.isIn(ids))).get();
    return {for (final b in list) b.id: b};
  }

  Future<int> insertBook(BooksCompanion entry) => into(books).insert(entry);

  Future<bool> updateBook(BooksCompanion entry) => update(books).replace(entry);

  Future<int> updateBookReadingStatus(int bookId, String? status) {
    return (update(books)..where((book) => book.id.equals(bookId))).write(
      BooksCompanion(
        readingStatus: Value(status),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<int> updateBookFileHash(int bookId, String fileHash) {
    return (update(books)..where((book) => book.id.equals(bookId))).write(
      BooksCompanion(fileHash: Value(fileHash)),
    );
  }

  Future<int> updateBooksReadingStatus(
    Set<int> bookIds,
    String? status,
  ) {
    if (bookIds.isEmpty) return Future.value(0);
    return (update(books)..where((book) => book.id.isIn(bookIds))).write(
      BooksCompanion(
        readingStatus: Value(status),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<int> deleteBook(int id) =>
      (delete(books)..where((b) => b.id.equals(id))).go();

  Future<int> deleteBooks(Set<int> ids) {
    if (ids.isEmpty) return Future.value(0);
    return (delete(books)..where((book) => book.id.isIn(ids))).go();
  }

  Future<List<Chapter>> getChaptersForBook(int bookId) => (select(chapters)
        ..where((c) => c.bookId.equals(bookId))
        ..orderBy([(c) => OrderingTerm.asc(c.sortOrder)]))
      .get();

  Future<List<Chapter>> getChapterSummariesForBook(int bookId) async {
    final query = selectOnly(chapters)
      ..addColumns([
        chapters.id,
        chapters.bookId,
        chapters.title,
        chapters.contentIndex,
        chapters.sortOrder,
      ])
      ..where(chapters.bookId.equals(bookId))
      ..orderBy([OrderingTerm.asc(chapters.sortOrder)]);
    final rows = await query.get();
    return rows
        .map((row) => Chapter(
              id: row.read(chapters.id)!,
              bookId: row.read(chapters.bookId)!,
              title: row.read(chapters.title)!,
              contentIndex: row.read(chapters.contentIndex)!,
              sortOrder: row.read(chapters.sortOrder)!,
            ))
        .toList();
  }

  Future<List<Chapter>> getMissingContentChapterSummariesForBook(
    int bookId,
  ) async {
    final query = selectOnly(chapters)
      ..addColumns([
        chapters.id,
        chapters.bookId,
        chapters.title,
        chapters.contentIndex,
        chapters.sortOrder,
      ])
      ..where(
        chapters.bookId.equals(bookId) & chapters.content.isNull(),
      )
      ..orderBy([OrderingTerm.asc(chapters.sortOrder)]);
    final rows = await query.get();
    return rows.map(_chapterSummaryFromRow).toList(growable: false);
  }

  Future<Chapter?> getChapterSummaryForBook(int bookId, int chapterId) async {
    final query = selectOnly(chapters)
      ..addColumns([
        chapters.id,
        chapters.bookId,
        chapters.title,
        chapters.contentIndex,
        chapters.sortOrder,
      ])
      ..where(
        chapters.bookId.equals(bookId) & chapters.id.equals(chapterId),
      )
      ..limit(1);
    final row = await query.getSingleOrNull();
    return row == null ? null : _chapterSummaryFromRow(row);
  }

  Future<int> countMissingChapterContent(int bookId) async {
    final count = chapters.id.count();
    final query = selectOnly(chapters)
      ..addColumns([count])
      ..where(
        chapters.bookId.equals(bookId) & chapters.content.isNull(),
      );
    final row = await query.getSingle();
    return row.read(count) ?? 0;
  }

  Chapter _chapterSummaryFromRow(TypedResult row) {
    return Chapter(
      id: row.read(chapters.id)!,
      bookId: row.read(chapters.bookId)!,
      title: row.read(chapters.title)!,
      contentIndex: row.read(chapters.contentIndex)!,
      sortOrder: row.read(chapters.sortOrder)!,
    );
  }

  Future<String?> getChapterContent(int chapterId) {
    return (selectOnly(chapters)
          ..addColumns([chapters.content])
          ..where(chapters.id.equals(chapterId)))
        .map((row) => row.read(chapters.content))
        .getSingleOrNull();
  }

  Future<int> insertChapter(ChaptersCompanion entry) =>
      into(chapters).insert(entry);

  /// 这些书缓存的正文一共多少字符。
  ///
  /// 删书之后要不要跑压缩由它决定：压缩的开销跟索引规模走，删一本没缓存
  /// 正文的小书还去跑一遍不划算。见 `AppDatabase.compact`。
  Future<int> cachedContentLength(Iterable<int> bookIds) async {
    if (bookIds.isEmpty) return 0;
    final placeholders = List.filled(bookIds.length, '?').join(', ');
    final row = await customSelect(
      'SELECT COALESCE(SUM(length(content)), 0) AS total FROM chapters '
      'WHERE book_id IN ($placeholders)',
      variables: [for (final id in bookIds) Variable.withInt(id)],
      readsFrom: {chapters},
    ).getSingle();
    return row.read<int>('total');
  }

  Future<void> cacheChapterContents(Map<int, String> contentsByChapterId) {
    return transaction(() async {
      for (final entry in contentsByChapterId.entries) {
        await (update(chapters)
              ..where((chapter) => chapter.id.equals(entry.key)))
            .write(ChaptersCompanion(content: Value(entry.value)));
      }
    });
  }

  Future<int> insertBookWithChapters(
    BooksCompanion book,
    List<ChaptersCompanion Function(int bookId)> chapterFactories,
  ) {
    return transaction(() async {
      final bookId = await into(books).insert(book);
      final chapterEntries = [
        for (final createChapter in chapterFactories) createChapter(bookId),
      ];
      if (chapterEntries.isNotEmpty) {
        await batch((batch) {
          batch.insertAll(chapters, chapterEntries);
        });
      }
      return bookId;
    });
  }

  /// Replaces all chapters of [bookId] in one transaction (delete + insert).
  /// Used when a migrated book's chapters must be re-derived by the current
  /// parser; the foreign key cascade sets reading_progress.chapterId to NULL
  /// for the removed rows.
  Future<void> replaceChapters(
    int bookId,
    List<ChaptersCompanion Function(int bookId)> chapterFactories,
  ) {
    return transaction(() async {
      await (delete(chapters)..where((c) => c.bookId.equals(bookId))).go();
      final entries = [
        for (final createChapter in chapterFactories) createChapter(bookId),
      ];
      if (entries.isNotEmpty) {
        await batch((batch) {
          batch.insertAll(chapters, entries);
        });
      }
    });
  }

  Future<void> replaceBookContent(
    int bookId,
    BooksCompanion bookChanges,
    List<ChaptersCompanion Function(int bookId)> chapterFactories,
  ) {
    return transaction(() async {
      final updated = await (update(books)
            ..where((book) => book.id.equals(bookId)))
          .write(bookChanges);
      if (updated == 0) throw StateError('书籍不存在');
      await (delete(chapters)
            ..where((chapter) => chapter.bookId.equals(bookId)))
          .go();
      final entries = [
        for (final createChapter in chapterFactories) createChapter(bookId),
      ];
      if (entries.isNotEmpty) {
        await batch((batch) => batch.insertAll(chapters, entries));
      }
    });
  }

  Future<ReadingProgressData?> getProgress(int bookId) =>
      (select(readingProgress)..where((p) => p.bookId.equals(bookId)))
          .getSingleOrNull();

  Future<void> saveProgress(ReadingProgressCompanion entry) =>
      into(readingProgress).insertOnConflictUpdate(entry);
}
