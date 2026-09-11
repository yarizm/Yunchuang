import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yunchuang/database/app_database.dart';
import 'package:yunchuang/database/daos/vocabulary_dao.dart';

void main() {
  late AppDatabase database;
  late VocabularyDao dao;
  late int bookId;
  late int chapterId;

  setUp(() async {
    database = AppDatabase.connect(NativeDatabase.memory());
    dao = VocabularyDao(database);
    bookId = await database.into(database.books).insert(
          BooksCompanion.insert(
            title: '蛊真人',
            filePath: 'book.txt',
            format: 'txt',
            fileSize: 1,
          ),
        );
    chapterId = await database.into(database.chapters).insert(
          ChaptersCompanion.insert(
            bookId: bookId,
            title: '第一章',
            contentIndex: 0,
            sortOrder: 0,
          ),
        );
  });

  tearDown(() => database.close());

  test('normalizes and upserts one term per book', () async {
    final first = await dao.save(
      bookId: bookId,
      chapterId: chapterId,
      term: ' 方  源 ',
      definition: '  主角  ',
      contextText: '  方源回到五百年前。  ',
      positionStart: 0,
      positionEnd: 2,
    );

    expect(first.term, '方 源');
    expect(first.normalizedTerm, '方 源');
    expect(first.definition, '主角');
    expect(first.contextText, '方源回到五百年前。');

    final updated = await dao.save(
      bookId: bookId,
      chapterId: chapterId,
      term: '方 源',
      definition: '古月方源',
      positionStart: 4,
      positionEnd: 6,
    );

    expect(updated.id, first.id);
    expect(updated.definition, '古月方源');
    expect(await dao.getForBook(bookId), hasLength(1));
    expect((await dao.findForBook(bookId, '  方   源 '))?.id, first.id);
  });

  test('joins source details and validates chapter ownership', () async {
    await dao.save(
      bookId: bookId,
      chapterId: chapterId,
      term: '春秋蝉',
    );
    final details = await dao.watchAllDetails().first;
    expect(details.single.bookTitle, '蛊真人');
    expect(details.single.chapterTitle, '第一章');

    final otherBookId = await database.into(database.books).insert(
          BooksCompanion.insert(
            title: '另一册',
            filePath: 'other.txt',
            format: 'txt',
            fileSize: 1,
          ),
        );
    expect(
      dao.save(
        bookId: otherBookId,
        chapterId: chapterId,
        term: '无效来源',
      ),
      throwsArgumentError,
    );
  });

  test('deleting a chapter clears its source and deleting a book cascades',
      () async {
    final entry = await dao.save(
      bookId: bookId,
      chapterId: chapterId,
      term: '青茅山',
    );

    await (database.delete(database.chapters)
          ..where((chapter) => chapter.id.equals(chapterId)))
        .go();
    expect(
      (await database.select(database.vocabularyEntries).getSingle()).chapterId,
      isNull,
    );

    await (database.delete(database.books)
          ..where((book) => book.id.equals(bookId)))
        .go();
    expect(await dao.deleteEntry(entry.id), 0);
    expect(await database.select(database.vocabularyEntries).get(), isEmpty);
  });

  test('rejects invalid term, context, and offsets', () async {
    expect(
      dao.save(bookId: bookId, chapterId: chapterId, term: '   '),
      throwsArgumentError,
    );
    expect(
      dao.save(
        bookId: bookId,
        chapterId: chapterId,
        term: '词',
        contextText: 'x' * 2001,
      ),
      throwsArgumentError,
    );
    expect(
      dao.save(
        bookId: bookId,
        chapterId: chapterId,
        term: '词',
        positionStart: 10,
        positionEnd: 9,
      ),
      throwsArgumentError,
    );
  });
}
