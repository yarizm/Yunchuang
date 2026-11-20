import 'dart:io';

import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:yunchuang/database/app_database.dart';
import 'package:yunchuang/database/daos/book_dao.dart';
import 'package:yunchuang/services/book_service.dart';

void main() {
  late Directory directory;
  late AppDatabase database;
  late BookService service;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('book_import_');
    database = AppDatabase.connect(NativeDatabase.memory());
    service = BookService(
      BookDao(database),
      appDirectoryProvider: () async => directory,
    );
  });

  tearDown(() async {
    await database.close();
    if (await directory.exists()) {
      await directory.delete(recursive: true);
    }
  });

  test('detects duplicates and supports skip or keeping a copy', () async {
    final source = await _writeSource(directory, 'source.txt', '第一章\n正文');
    final analysis = await service.analyzeImport(source.path);
    expect(analysis.isDuplicate, isFalse);
    expect(analysis.fileHash, hasLength(64));

    final first = await service.importBook(
      source.path,
      analysis: analysis,
    );
    expect(first.fileHash, analysis.fileHash);
    expect(await File(first.filePath).exists(), isTrue);

    final duplicate = await service.analyzeImport(source.path);
    expect(duplicate.existingBook?.id, first.id);

    final skipped = await service.importBook(
      source.path,
      analysis: duplicate,
      duplicateAction: DuplicateBookAction.skip,
    );
    expect(skipped.id, first.id);
    expect(await database.select(database.books).get(), hasLength(1));

    final copy = await service.importBook(
      source.path,
      analysis: duplicate,
      duplicateAction: DuplicateBookAction.keepCopy,
    );
    expect(copy.id, isNot(first.id));
    expect(copy.fileHash, first.fileHash);
    expect(await database.select(database.books).get(), hasLength(2));

    final thirdAnalysis = await service.analyzeImport(source.path);
    expect(thirdAnalysis.isDuplicate, isTrue);
    expect(thirdAnalysis.existingBook?.id, first.id);
  });

  test('lazily hashes same-sized books imported before schema v11', () async {
    final source = await _writeSource(directory, 'source.txt', 'legacy body');
    final stored = await _writeSource(directory, 'stored.txt', 'legacy body');
    final legacyId = await database.into(database.books).insert(
          BooksCompanion.insert(
            title: 'Legacy',
            filePath: stored.path,
            format: 'txt',
            fileSize: await stored.length(),
          ),
        );

    final analysis = await service.analyzeImport(source.path);

    expect(analysis.existingBook?.id, legacyId);
    final updated = await (database.select(database.books)
          ..where((book) => book.id.equals(legacyId)))
        .getSingle();
    expect(updated.fileHash, analysis.fileHash);
  });

  test('replace preserves user records and restores the managed file',
      () async {
    final source = await _writeSource(directory, 'source.txt', '第一章\n正文');
    final firstAnalysis = await service.analyzeImport(source.path);
    final imported = await service.importBook(
      source.path,
      analysis: firstAnalysis,
    );
    await (database.update(database.books)
          ..where((book) => book.id.equals(imported.id)))
        .write(const BooksCompanion(title: Value('用户书名')));
    final chapter = await database.select(database.chapters).getSingle();
    await database.into(database.readingProgress).insert(
          ReadingProgressCompanion.insert(
            bookId: Value(imported.id),
            chapterId: Value(chapter.id),
            percentage: const Value(0.5),
          ),
        );
    await database.into(database.notes).insert(
          NotesCompanion.insert(
            bookId: imported.id,
            chapterId: Value(chapter.id),
            content: const Value('保留笔记'),
          ),
        );
    final collectionId = await database.into(database.bookCollections).insert(
          BookCollectionsCompanion.insert(name: '保留书架'),
        );
    await database.into(database.bookCollectionItems).insert(
          BookCollectionItemsCompanion.insert(
            collectionId: collectionId,
            bookId: imported.id,
          ),
        );
    await File(imported.filePath).delete();

    final duplicate = await service.analyzeImport(source.path);
    final replaced = await service.importBook(
      source.path,
      analysis: duplicate,
      duplicateAction: DuplicateBookAction.replace,
    );

    expect(replaced.id, imported.id);
    expect(replaced.title, '用户书名');
    expect(replaced.filePath, isNot(imported.filePath));
    expect(await File(replaced.filePath).exists(), isTrue);
    final progress =
        await database.select(database.readingProgress).getSingle();
    final newChapter = await database.select(database.chapters).getSingle();
    expect(progress.percentage, 0.5);
    // 换文件会删掉旧章节；进度和笔记要挂到新章节上，不能回到第一章。
    expect(progress.chapterId, newChapter.id);
    final note = await database.select(database.notes).getSingle();
    expect(note.content, '保留笔记');
    expect(note.chapterId, newChapter.id);
    expect(
      (await database.select(database.bookCollectionItems).getSingle())
          .collectionId,
      collectionId,
    );
  });

  test('resplits a TXT book and moves progress, bookmarks, notes and words',
      () async {
    const fakeBody = '众人一阵欢呼。明月点了点头，转身看向下一场的对手。';
    const text = '第一百四十三章 玉米地的爱恋\n'
        '正文一。\n'
        '1：0，顺利斩杀这支叫做聚义轩的流派\n'
        '$fakeBody\n'
        '\n'
        '第一百四十四章 水云谣\n'
        '正文二。水云谣的曲子从远处传来。';
    final source = await _writeSource(directory, 'book.txt', text);
    final book = await service.importBook(source.path);
    final dao = BookDao(database);
    // 旧规则切出来的样子：「1：0……」那一行被当成了一章。
    const oldSplit = [
      ('第一百四十三章 玉米地的爱恋', '正文一。'),
      ('1：0，顺利斩杀这支叫做聚义轩的流派', fakeBody),
      ('第一百四十四章 水云谣', '正文二。水云谣的曲子从远处传来。'),
    ];
    await dao.replaceBookContent(
      book.id,
      BooksCompanion(updatedAt: Value(DateTime.now())),
      [
        for (final (index, (title, content)) in oldSplit.indexed)
          (int id) => ChaptersCompanion.insert(
                bookId: id,
                title: title,
                content: Value(content),
                contentIndex: index,
                sortOrder: index,
              ),
      ],
    );
    final old = await dao.getChapterSummariesForBook(book.id);
    final at = fakeBody.indexOf('明月');
    await database.into(database.readingProgress).insert(
          ReadingProgressCompanion.insert(
            bookId: Value(book.id),
            chapterId: Value(old[1].id),
            positionInChapter: Value(at / fakeBody.length),
            percentage: const Value(0.4),
          ),
        );
    final noteId = await database.into(database.notes).insert(
          NotesCompanion.insert(
            bookId: book.id,
            chapterId: Value(old[1].id),
            selectedText: const Value('明月'),
            positionStart: Value(at),
            positionEnd: Value(at + 2),
          ),
        );
    final bookmarkId = await database.into(database.notes).insert(
          NotesCompanion.insert(
            bookId: book.id,
            chapterId: Value(old[1].id),
            type: const Value('bookmark'),
            positionStart: Value((at / fakeBody.length * 10000).round()),
          ),
        );
    final wordId = await database.into(database.vocabularyEntries).insert(
          VocabularyEntriesCompanion.insert(
            bookId: book.id,
            chapterId: Value(old[2].id),
            term: '水云谣',
            normalizedTerm: '水云谣',
            positionStart: const Value(4),
            positionEnd: const Value(7),
          ),
        );

    final result = await service.resplitBook(book.id);

    expect(result, (before: 3, after: 2));
    final chapters = await dao.getChapterSummariesForBook(book.id);
    expect(chapters.map((chapter) => chapter.title), [
      '第一百四十三章 玉米地的爱恋',
      '第一百四十四章 水云谣',
    ]);
    final first = (await dao.getChapterContent(chapters[0].id))!;
    final newAt = first.indexOf('明月');

    final progress =
        await database.select(database.readingProgress).getSingle();
    expect(progress.chapterId, chapters[0].id);
    expect(progress.positionInChapter, closeTo(newAt / first.length, 1e-9));
    expect(progress.percentage, 0.4);

    Future<Note> noteById(int id) =>
        (database.select(database.notes)..where((n) => n.id.equals(id)))
            .getSingle();
    final note = await noteById(noteId);
    expect(note.chapterId, chapters[0].id);
    expect(first.substring(note.positionStart!, note.positionEnd!), '明月');
    final bookmark = await noteById(bookmarkId);
    expect(bookmark.chapterId, chapters[0].id);
    expect(bookmark.positionStart, (newAt / first.length * 10000).round());

    final word = await (database.select(database.vocabularyEntries)
          ..where((entry) => entry.id.equals(wordId)))
        .getSingle();
    expect(word.chapterId, chapters[1].id);
    expect(word.positionStart, 4);
    expect(word.positionEnd, 7);
  });

  test('discovers supported books recursively in a folder', () async {
    final nested = Directory(p.join(directory.path, 'nested'));
    await nested.create();
    final txt = await _writeSource(directory, 'b.txt', 'text');
    final epub = await _writeSource(nested, 'a.EPUB', 'epub');
    await _writeSource(nested, 'ignored.md', 'markdown');

    final paths = await service.findSupportedBooksInDirectory(directory.path);

    expect(paths, [epub.path, txt.path]..sort());
  });
}

Future<File> _writeSource(
  Directory directory,
  String name,
  String content,
) async {
  final source = File(p.join(directory.path, name));
  await source.writeAsString(content, flush: true);
  return source;
}
