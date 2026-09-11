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
    expect(progress.percentage, 0.5);
    expect(progress.chapterId, isNull);
    expect((await database.select(database.notes).getSingle()).content, '保留笔记');
    expect(
      (await database.select(database.bookCollectionItems).getSingle())
          .collectionId,
      collectionId,
    );
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
