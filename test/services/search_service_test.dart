import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yunchuang/database/app_database.dart';
import 'package:yunchuang/services/search_service.dart';

void main() {
  late AppDatabase database;
  late SearchService service;

  setUp(() {
    database = AppDatabase.connect(NativeDatabase.memory());
    service = SearchService(database);
  });

  tearDown(() => database.close());

  Future<int> insertBook({
    required String title,
    String author = '',
    String? description,
    String filePath = 'book.txt',
  }) {
    return database.into(database.books).insert(
          BooksCompanion.insert(
            title: title,
            author: Value(author),
            description: Value(description),
            filePath: filePath,
            format: 'txt',
            fileSize: 1,
          ),
        );
  }

  Future<int> insertChapter({
    required int bookId,
    required String title,
    required String content,
    int sortOrder = 0,
  }) {
    return database.into(database.chapters).insert(
          ChaptersCompanion.insert(
            bookId: bookId,
            title: title,
            content: Value(content),
            contentIndex: sortOrder,
            sortOrder: sortOrder,
          ),
        );
  }

  Future<int> insertNote({
    required int bookId,
    String? selectedText,
    String? content,
  }) {
    return database.into(database.notes).insert(
          NotesCompanion.insert(
            bookId: bookId,
            selectedText: Value(selectedText),
            content: Value(content),
          ),
        );
  }

  List<SearchResult> ofType(List<SearchResult> results, String type) =>
      results.where((result) => result.type == type).toList();

  group('SearchPlan', () {
    test('routes CJK, kana and hangul queries to the substring backend', () {
      for (final query in ['计算机', 'ひらがな', 'カタカナ', '한글', '深入 计算机']) {
        expect(
          SearchPlan.forQuery(query).substring,
          isTrue,
          reason: '$query should not use FTS',
        );
      }
    });

    test('keeps space-delimited scripts on the FTS backend', () {
      for (final query in ['pipeline', 'clean architecture', 'GC-1024']) {
        expect(
          SearchPlan.forQuery(query).substring,
          isFalse,
          reason: '$query should use FTS',
        );
      }
    });

    test('phrase quotes each term and ANDs them', () {
      expect(
        SearchPlan.forQuery('  clean   architecture  ').ftsQuery,
        '"clean" AND "architecture"',
      );
    });

    test('escapes embedded quotes so FTS takes them literally', () {
      expect(SearchPlan.forQuery('say"hi').ftsQuery, '"say""hi"');
    });

    test('a whitespace-only query yields no terms', () {
      expect(SearchPlan.forQuery('   ').isEmpty, isTrue);
    });
  });

  group('Chinese search (regression: unicode61 tokenises CJK runs as one)', () {
    test('finds a book by a substring of its title', () async {
      await insertBook(title: '深入理解计算机系统', author: '兰德尔');

      final results = await service.search('计算机');

      expect(ofType(results, 'book'), hasLength(1));
      expect(ofType(results, 'book').single.title, '深入理解计算机系统');
    });

    test('finds a book by a substring of its author and description', () async {
      await insertBook(
        title: '未命名',
        author: '兰德尔·布莱恩特',
        description: '一本讲体系结构的书',
        filePath: 'a.txt',
      );

      expect(ofType(await service.search('布莱恩特'), 'book'), hasLength(1));
      expect(ofType(await service.search('体系结构'), 'book'), hasLength(1));
    });

    test('finds chapter body text by substring', () async {
      final bookId = await insertBook(title: '计算机组成');
      await insertChapter(
        bookId: bookId,
        title: '第一章',
        content: '这是一段关于计算机体系结构的正文内容，讨论了流水线技术。',
      );

      final chapters = ofType(await service.search('流水线'), 'chapter');

      expect(chapters, hasLength(1));
      expect(chapters.single.chapterTitle, '第一章');
      expect(chapters.single.highlight, contains('流水线'));
      expect(chapters.single.locator?.query, '流水线');
    });

    // searchChaptersLike 会在查询词不含 ASCII 字母时省掉 lower()——那几次
    // 折叠每次都要复制一份整章正文。省掉的前提是它对匹配结果无影响，这两个
    // 用例把分界的两侧都钉住：纯中文走免折叠路径，混入大小写不一致的 ASCII
    // 时必须仍然大小写不敏感。
    // 首词是 ASCII 且与正文大小写不一致——这正是免折叠会出错的那种输入。
    // 片段由首词的 instr 位置裁剪，定位失败时会退回正文开头，所以把关键词
    // 埋在远离开头的位置，回退与命中才区分得开。
    test('首词为大小写不一致的 ASCII 时仍能定位片段', () async {
      final bookId = await insertBook(title: '计算机组成');
      final filler = '这是一段与关键词无关的铺垫正文。' * 12;
      await insertChapter(
        bookId: bookId,
        title: '第一章',
        content: '$filler 讨论 CPU 的流水线技术。',
      );

      final chapters = ofType(await service.search('cpu 流水线'), 'chapter');

      expect(chapters, hasLength(1));
      expect(chapters.single.highlight, contains('CPU'));
    });

    test('纯中文查询的片段与排序不受免折叠影响', () async {
      final bookId = await insertBook(title: '计算机组成');
      await insertChapter(
        bookId: bookId,
        title: '少',
        content: '流水线。',
        sortOrder: 0,
      );
      await insertChapter(
        bookId: bookId,
        title: '多',
        content: '流水线，流水线，还是流水线。',
        sortOrder: 1,
      );

      final chapters = ofType(await service.search('流水线'), 'chapter');

      expect(chapters, hasLength(2));
      // 命中次数多的排前面，说明 hit_count 在免折叠路径下算对了。
      expect(chapters.first.chapterTitle, '多');
      expect(chapters.first.highlight, contains('流水线'));
    });

    // 三字以上的中日韩查询走 trigram 索引做前置过滤，索引由触发器维护。
    // 触发器漏掉任何一种写操作，搜索都会静默丢结果而不是报错——这一组把
    // 增、改、删三条路径都钉住。
    group('trigram 索引与正文保持同步', () {
      test('新插入的章节立刻能搜到', () async {
        final bookId = await insertBook(title: '书');
        await insertChapter(
          bookId: bookId,
          title: '新章',
          content: '这一章讲的是分布式共识算法。',
        );

        expect(ofType(await service.search('分布式'), 'chapter'), hasLength(1));
      });

      test('改过正文后旧词搜不到、新词搜得到', () async {
        final bookId = await insertBook(title: '书');
        final chapterId = await insertChapter(
          bookId: bookId,
          title: '章',
          content: '原本讲的是分布式共识。',
        );

        await (database.update(database.chapters)
              ..where((t) => t.id.equals(chapterId)))
            .write(const ChaptersCompanion(
          content: Value('改成了讲垃圾回收机制。'),
        ));

        expect(ofType(await service.search('分布式'), 'chapter'), isEmpty);
        expect(ofType(await service.search('垃圾回收'), 'chapter'), hasLength(1));
      });

      test('删掉的章节搜不到', () async {
        final bookId = await insertBook(title: '书');
        final chapterId = await insertChapter(
          bookId: bookId,
          title: '章',
          content: '这一章讲的是分布式共识算法。',
        );

        await (database.delete(database.chapters)
              ..where((t) => t.id.equals(chapterId)))
            .go();

        expect(ofType(await service.search('分布式'), 'chapter'), isEmpty);
      });

      // trigram 三字起步，两字查询用不了索引，必须仍走全表扫描的回退路径。
      // 这条断言就是那条回退路径还活着的证据。
      test('两字查询绕过索引仍能命中', () async {
        final bookId = await insertBook(title: '书');
        await insertChapter(
          bookId: bookId,
          title: '章',
          content: '这一章讲的是分布式共识算法。',
        );

        expect(ofType(await service.search('共识'), 'chapter'), hasLength(1));
      });
    });

    test('finds notes by substring of highlight and of body', () async {
      final bookId = await insertBook(title: '书');
      await insertNote(bookId: bookId, selectedText: '划线的中文句子', content: null);
      await insertNote(bookId: bookId, selectedText: null, content: '笔记正文里的想法');

      expect(ofType(await service.search('中文句子'), 'note'), hasLength(1));
      expect(ofType(await service.search('里的想法'), 'note'), hasLength(1));
    });

    test('two-character words match — the most common Chinese query', () async {
      final bookId = await insertBook(title: '深入理解计算机系统');
      await insertChapter(
        bookId: bookId,
        title: '章',
        content: '系统调用的实现细节。',
      );

      expect(ofType(await service.search('系统'), 'book'), hasLength(1));
      expect(ofType(await service.search('系统'), 'chapter'), hasLength(1));
    });

    test('all terms must match, not just one', () async {
      await insertBook(title: '深入理解计算机系统', filePath: 'a.txt');
      await insertBook(title: '深入浅出设计模式', filePath: 'b.txt');

      final both = ofType(await service.search('深入 计算机'), 'book');
      expect(both, hasLength(1));
      expect(both.single.title, '深入理解计算机系统');

      expect(ofType(await service.search('深入'), 'book'), hasLength(2));
    });

    test('ranks title matches above description-only matches', () async {
      await insertBook(title: '别的书', description: '提到了计算机', filePath: 'a.txt');
      await insertBook(title: '计算机网络', filePath: 'b.txt');

      final books = ofType(await service.search('计算机'), 'book');

      expect(books, hasLength(2));
      expect(books.first.title, '计算机网络');
    });

    test('LIKE wildcards in the query are matched literally', () async {
      await insertBook(title: '100%纯天然', filePath: 'a.txt');
      await insertBook(title: '其他中文书', filePath: 'b.txt');

      final results = ofType(await service.search('100%纯'), 'book');

      expect(results, hasLength(1));
      expect(results.single.title, '100%纯天然');
    });

    test('a query matching nothing returns no results', () async {
      await insertBook(title: '深入理解计算机系统');

      expect(await service.search('量子力学'), isEmpty);
    });
  });

  group('Latin search keeps using the FTS backend', () {
    test('finds a book, a note and a chapter by keyword', () async {
      final bookId = await insertBook(
        title: 'Designing Data-Intensive Applications',
        author: 'Kleppmann',
      );
      await insertChapter(
        bookId: bookId,
        title: 'Replication',
        content: 'Leader based replication and failover pipeline.',
      );
      await insertNote(bookId: bookId, selectedText: 'quorum writes');

      expect(ofType(await service.search('kleppmann'), 'book'), hasLength(1));
      expect(ofType(await service.search('failover'), 'chapter'), hasLength(1));
      expect(ofType(await service.search('quorum'), 'note'), hasLength(1));
    });

    test('FTS operators in the query are taken literally', () async {
      await insertBook(title: 'A OR B', filePath: 'a.txt');

      expect(
        await service.search('NOT'),
        isEmpty,
      );
    });
  });
}
