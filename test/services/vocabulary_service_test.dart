import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yunchuang/database/app_database.dart';
import 'package:yunchuang/database/daos/book_dao.dart';
import 'package:yunchuang/database/daos/vocabulary_dao.dart';
import 'package:yunchuang/providers/ai/ai_book_content_service.dart';
import 'package:yunchuang/services/vocabulary_service.dart';

void main() {
  late AppDatabase database;
  late VocabularyDao dao;
  late VocabularyService service;
  late int bookId;
  late int firstChapterId;

  setUp(() async {
    database = AppDatabase.connect(NativeDatabase.memory());
    dao = VocabularyDao(database);
    service = VocabularyService(
      dao,
      AIBookContentService(BookDao(database)),
      backgroundSearchThresholdChars: 1,
    );
    bookId = await database.into(database.books).insert(
          BooksCompanion.insert(
            title: '测试书',
            filePath: 'book.txt',
            format: 'txt',
            fileSize: 1,
          ),
        );
    firstChapterId = await database.into(database.chapters).insert(
          ChaptersCompanion.insert(
            bookId: bookId,
            title: '开篇',
            content: const Value('方源从山寨醒来。这里提到了方源。'),
            contentIndex: 0,
            sortOrder: 0,
          ),
        );
    await database.into(database.chapters).insert(
          ChaptersCompanion.insert(
            bookId: bookId,
            title: '后续',
            content: const Value('他人只称其为方源，不知他的来历。'),
            contentIndex: 1,
            sortOrder: 1,
          ),
        );
  });

  tearDown(() => database.close());

  test('finds exact Chinese occurrences without reading unrelated books',
      () async {
    final otherBookId = await database.into(database.books).insert(
          BooksCompanion.insert(
            title: '另一册',
            filePath: 'other.txt',
            format: 'txt',
            fileSize: 1,
          ),
        );
    await database.into(database.chapters).insert(
          ChaptersCompanion.insert(
            bookId: otherBookId,
            title: '不应命中',
            content: const Value('方源方源'),
            contentIndex: 0,
            sortOrder: 0,
          ),
        );

    final result = await service.findOccurrences(
      bookId: bookId,
      term: ' 方源 ',
      limit: 2,
    );

    expect(result.totalCount, 3);
    expect(result.occurrences, hasLength(2));
    expect(result.occurrences.first.chapterId, firstChapterId);
    expect(result.occurrences.first.snippet, contains('方源'));
    expect(result.occurrences.first.locator.bookId, bookId);
    expect(result.occurrences.first.locator.selectedText, '方源');
    expect(result.occurrences.first.locator.textOffsetStart, 0);
    expect(result.occurrences.first.locator.textOffsetEnd, 2);
  });

  test('exports Markdown and CSV with source metadata', () async {
    await service.save(
      bookId: bookId,
      chapterId: firstChapterId,
      term: '春秋蝉',
      definition: '能使宿主重生的蛊虫',
      contextText: '春秋蝉振翅。',
      positionStart: 0,
      positionEnd: 3,
    );
    final entries = await dao.watchAllDetails().first;

    final markdown = service.exportMarkdown(entries);
    expect(markdown, contains('## 春秋蝉'));
    expect(markdown, contains('能使宿主重生的蛊虫'));
    expect(markdown, contains('测试书 / 开篇'));
    expect(markdown, contains('春秋蝉振翅。'));

    final csv = service.exportCsv(entries);
    expect(csv, startsWith('词条,释义,书籍,章节,原句'));
    expect(csv, contains('春秋蝉'));
    expect(csv, contains('测试书'));
  });

  test('rejects empty and oversized lookup terms', () async {
    expect(
      service.findOccurrences(bookId: bookId, term: '  '),
      throwsArgumentError,
    );
    expect(
      service.findOccurrences(bookId: bookId, term: 'x' * 201),
      throwsArgumentError,
    );
  });
}
