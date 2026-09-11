import 'dart:io';
import 'dart:math';

import 'package:drift/drift.dart' show Value, driftRuntimeOptions;
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:yunchuang/database/app_database.dart';
import 'package:yunchuang/database/daos/book_dao.dart';
import 'package:yunchuang/services/book_service.dart';

void main() {
  setUpAll(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  });

  late Directory directory;
  late File file;
  late AppDatabase database;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('yunchuang_compact_');
    file = File(p.join(directory.path, 'compact.db'));
    database = AppDatabase.forFile(file);
  });

  tearDown(() async {
    await database.close();
    if (await directory.exists()) await directory.delete(recursive: true);
  });

  /// 落盘后的库文件大小（KB）。先 checkpoint，否则内容还在 WAL 里。
  Future<int> sizeKb() async {
    await database.customStatement('PRAGMA wal_checkpoint(TRUNCATE)');
    return (await file.length()) ~/ 1024;
  }

  /// 插一本 [chapters] 章、每章 [charsPerChapter] 字的书。
  ///
  /// 正文用随机汉字：重复的句子会被 trigram 索引大量去重，撑不出真实体积。
  Future<int> insertBook({
    int chapters = 400,
    int charsPerChapter = 2000,
    String title = '大部头',
  }) async {
    final rnd = Random(42);
    final bookId = await database.into(database.books).insert(
          BooksCompanion.insert(
            title: title,
            filePath: '$title.txt',
            format: 'txt',
            fileSize: 1,
          ),
        );
    await database.batch((b) {
      for (var i = 0; i < chapters; i++) {
        b.insert(
          database.chapters,
          ChaptersCompanion.insert(
            bookId: bookId,
            title: '第 $i 章',
            content: Value(String.fromCharCodes(
              List.generate(
                charsPerChapter,
                (_) => 0x4E00 + rnd.nextInt(0x2000),
              ),
            )),
            contentIndex: i,
            sortOrder: i,
          ),
        );
      }
    });
    return bookId;
  }

  // FTS5 外部内容表删行是往索引里**追加**删除标记，不是就地移除。所以删书
  // 会让库变大，而且不会自己缩回去。这一条把「删完之后确实变小了」钉住。
  test('删掉大书之后库文件真的变小', () async {
    final bookId = await insertBook();
    final afterInsert = await sizeKb();
    expect(afterInsert, greaterThan(1024), reason: '样本不够大，测不出问题');

    await (database.delete(database.books)
          ..where((t) => t.id.equals(bookId)))
        .go();
    final afterDelete = await sizeKb();
    // 删除标记让它先涨一截——这正是要解决的问题。
    expect(afterDelete, greaterThanOrEqualTo(afterInsert));

    await database.compact();
    final afterCompact = await sizeKb();

    expect(afterCompact, lessThan(afterInsert ~/ 4),
        reason: '压缩之后应该只剩零头，实际 ${afterCompact}KB / ${afterInsert}KB');
  });

  // 只做其中一步都没用，这一条是「两步缺一不可」的证据。少了任何一步，
  // 上面那条断言里的 compact() 都会失效。
  test('单独 VACUUM 或单独 optimize 都回收不了', () async {
    final bookId = await insertBook();
    final afterInsert = await sizeKb();
    await (database.delete(database.books)
          ..where((t) => t.id.equals(bookId)))
        .go();
    final afterDelete = await sizeKb();

    await database.customStatement('VACUUM');
    final vacuumOnly = await sizeKb();
    // 删除标记是活数据，搬到新文件里还是那么多。
    expect(vacuumOnly, greaterThan(afterInsert ~/ 2));

    await database.customStatement(
      "INSERT INTO chapters_trigram(chapters_trigram) VALUES('optimize')",
    );
    await database.customStatement(
      "INSERT INTO chapters_fts(chapters_fts) VALUES('optimize')",
    );
    final optimizeOnly = await sizeKb();
    // 标记合并掉了，但腾出来的页还在文件里，不还给系统。
    expect(optimizeOnly, greaterThan(afterInsert ~/ 2));
    expect(afterDelete, greaterThan(0));

    // 补上 VACUUM 才收得回来。
    await database.customStatement('VACUUM');
    expect(await sizeKb(), lessThan(afterInsert ~/ 4));
  });

  test('压缩之后搜索仍然正常', () async {
    final bookId = await insertBook(chapters: 5, charsPerChapter: 50);
    await database.into(database.chapters).insert(
          ChaptersCompanion.insert(
            bookId: bookId,
            title: '关键章',
            content: const Value('这一章讲的是分布式共识算法。'),
            contentIndex: 99,
            sortOrder: 99,
          ),
        );

    await database.compact();

    final hits = await database.searchChaptersLike(['分布式'], limit: 10);
    expect(hits, hasLength(1));
  });

  group('BookService 的压缩门槛', () {
    test('删掉的正文够多就压缩', () async {
      final service = BookService(BookDao(database));
      // 60 万字，超过 50 万的门槛。
      final bookId = await insertBook(chapters: 300, charsPerChapter: 2000);
      final afterInsert = await sizeKb();

      await service.deleteBook(bookId);

      expect(await sizeKb(), lessThan(afterInsert ~/ 4));
    });

    // 压缩开销跟索引规模走，不跟这次删了多少走。删一本小书也跑一遍等于
    // 每次都付全额，所以门槛以下必须跳过。
    test('删掉的正文不够多就跳过，把体积留着', () async {
      final service = BookService(BookDao(database));
      final keeper = await insertBook(title: '留着的大书');
      final small = await insertBook(
        chapters: 2,
        charsPerChapter: 100,
        title: '小书',
      );
      final afterInsert = await sizeKb();

      await service.deleteBook(small);

      // 没跑压缩，所以体积不会掉下来。
      expect(await sizeKb(), greaterThanOrEqualTo(afterInsert));
      // 留下的那本还在。
      final books = await database.select(database.books).get();
      expect(books.map((b) => b.id), [keeper]);
    });
  });
}
