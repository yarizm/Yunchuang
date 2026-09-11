import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yunchuang/database/app_database.dart';
import 'package:yunchuang/database/daos/book_dao.dart';
import 'package:yunchuang/parsers/epub_parser.dart';
import 'package:yunchuang/providers/ai/agent_models.dart';
import 'package:yunchuang/providers/ai/agent_tools.dart';
import 'package:yunchuang/providers/ai/ai_book_content_service.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

void main() {
  late AppDatabase database;

  setUp(() {
    database = AppDatabase.connect(NativeDatabase.memory());
  });

  tearDown(() async {
    await database.close();
  });

  test('search_current_book finds Chinese names with exact substring search',
      () async {
    final bookId = await _insertBook(database, title: '目标书');
    final otherBookId = await _insertBook(database, title: '其他书');
    await _insertChapter(
      database,
      bookId: bookId,
      title: '第一章',
      content: '方源第一次出现。方源选择沉默。',
      sortOrder: 0,
    );
    await _insertChapter(
      database,
      bookId: bookId,
      title: '第二章',
      content: '其他人物登场。',
      sortOrder: 1,
    );
    await _insertChapter(
      database,
      bookId: otherBookId,
      title: '外部章节',
      content: '方源在另一本书里出现。',
      sortOrder: 0,
    );

    final result = await SearchCurrentBookTool(database).run(
      {'query': '方源', 'limit': 8, 'contextChars': 40},
      _fullBookContext(bookId, bookTitle: '目标书'),
    );

    final matches = result.data['matches'] as List;
    expect(matches, hasLength(1));
    expect(matches.single['chapterTitle'], '第一章');
    expect(matches.single['hitCount'], 2);
    expect(matches.single['chapterPosition'], 0.0);
    expect(matches.single['textOffsetStart'], 0);
    expect(matches.single['textOffsetEnd'], 2);
    expect(matches.single['selectedText'], '方源');
    expect(matches.single['contextHash'], isNotEmpty);
    expect((matches.single['snippets'] as List).join('\n'), contains('方源'));
    expect(result.data['hasMore'], isFalse);
    expect(result.toObservation().length, lessThanOrEqualTo(4000));
  });

  test('book tools expose readable EPUB text without mutating source',
      () async {
    final bookId = await _insertBook(
      database,
      title: 'EPUB 测试书',
      format: 'epub',
    );
    final chapterId = await _insertChapter(
      database,
      bookId: bookId,
      title: '第一章',
      content:
          '<p>开端&nbsp;<strong>&#x65B9;</strong><em>&#x6E90;</em>现身 &amp; 观察局势。&#26041;<span>&#28304;</span>继续前进。</p>',
      sortOrder: 0,
    );

    final search = await SearchCurrentBookTool(database).run(
      {'query': '方源'},
      _fullBookContext(bookId),
    );
    final searchSnippet =
        ((search.data['matches'] as List).single['snippets'] as List)
            .join('\n');
    expect(searchSnippet, contains('方源现身 & 观察局势'));
    expect((search.data['matches'] as List).single['hitCount'], 2);
    expect(searchSnippet, isNot(contains('<strong>')));

    final excerpt = await ReadChapterExcerptTool(database).run(
      {'chapterId': chapterId, 'query': '方源', 'maxChars': 400},
      _fullBookContext(bookId),
    );
    expect(excerpt.data['excerpt'], contains('开端 方源现身 & 观察局势'));
    expect(excerpt.data['excerpt'], isNot(contains('<p>')));

    final persisted = await BookDao(database).getChapterContent(chapterId);
    expect(
      persisted,
      contains('<strong>&#x65B9;</strong><em>&#x6E90;</em>'),
    );
  });

  test('EPUB search reuses readable text and invalidates same-size changes',
      () async {
    final bookId = await _insertBook(
      database,
      title: 'EPUB 缓存测试',
      format: 'epub',
    );
    final chapterId = await _insertChapter(
      database,
      bookId: bookId,
      title: '第一章',
      content: '<p>&#26041;&#28304;</p>',
      sortOrder: 0,
    );
    var normalizationCalls = 0;
    final contentService = AIBookContentService(
      BookDao(database),
      epubNormalizer: (documents) async {
        normalizationCalls++;
        return documents.map(EpubParser.stripHtml).toList(growable: false);
      },
    );
    final tool = SearchCurrentBookTool(
      database,
      bookContentService: contentService,
    );

    final first = await tool.run(
      {'query': '方源'},
      _fullBookContext(bookId),
    );
    final second = await tool.run(
      {'query': '方源'},
      _fullBookContext(bookId),
    );
    expect(first.data['matches'], hasLength(1));
    expect(second.data['matches'], hasLength(1));
    expect(normalizationCalls, 1);

    await (database.update(database.chapters)
          ..where((chapter) => chapter.id.equals(chapterId)))
        .write(
      const ChaptersCompanion(
        content: Value('<p>&#30333;&#20957;</p>'),
      ),
    );
    final changed = await tool.run(
      {'query': '方源'},
      _fullBookContext(bookId),
    );

    expect(changed.data['matches'], isEmpty);
    expect(normalizationCalls, 2);
  });

  test('read_chapter_excerpt normalizes EPUB asynchronously and caches it',
      () async {
    final bookId = await _insertBook(
      database,
      title: 'EPUB 章节缓存测试',
      format: 'epub',
    );
    final chapterId = await _insertChapter(
      database,
      bookId: bookId,
      title: '第一章',
      content: '<p>开端<strong>方源</strong>现身。</p>',
      sortOrder: 0,
    );
    final normalizerStarted = Completer<void>();
    final releaseNormalizer = Completer<void>();
    var normalizationCalls = 0;
    final contentService = AIBookContentService(
      BookDao(database),
      epubNormalizer: (documents) async {
        normalizationCalls++;
        if (!normalizerStarted.isCompleted) normalizerStarted.complete();
        await releaseNormalizer.future;
        return documents.map(EpubParser.stripHtml).toList(growable: false);
      },
    );
    final tool = ReadChapterExcerptTool(
      database,
      bookContentService: contentService,
    );

    var completed = false;
    final pending = tool.run(
      {'chapterId': chapterId, 'query': '方源'},
      _fullBookContext(bookId),
    )..then((_) => completed = true);
    await normalizerStarted.future;
    await Future<void>.delayed(Duration.zero);

    expect(completed, isFalse);
    releaseNormalizer.complete();
    final first = await pending;
    final second = await tool.run(
      {'chapterId': chapterId, 'query': '方源'},
      _fullBookContext(bookId),
    );

    expect(first.data['excerpt'], contains('开端方源现身'));
    expect(second.data['excerpt'], first.data['excerpt']);
    expect(normalizationCalls, 1);
    expect(
      await BookDao(database).getChapterContent(chapterId),
      '<p>开端<strong>方源</strong>现身。</p>',
    );
  });

  test('search_current_book indexes unread PDF pages before searching',
      () async {
    final fixture = await _createPdfFixture([
      'opening page',
      'Alice appears on an unread page.',
    ]);
    addTearDown(() => fixture.directory.delete(recursive: true));
    final bookId = await _insertBook(
      database,
      title: 'PDF book',
      filePath: fixture.file.path,
      format: 'pdf',
    );
    await _insertChapter(
      database,
      bookId: bookId,
      title: 'Page 1',
      content: null,
      sortOrder: 0,
    );
    await _insertChapter(
      database,
      bookId: bookId,
      title: 'Page 2',
      content: null,
      sortOrder: 1,
    );

    final result = await SearchCurrentBookTool(
      database,
      bookContentService: AIBookContentService(BookDao(database)),
    ).run(
      {'query': 'Alice'},
      _fullBookContext(bookId, bookTitle: 'PDF book'),
    );

    final matches = result.data['matches'] as List;
    expect(matches, hasLength(1));
    expect(matches.single['chapterTitle'], 'Page 2');
    final cached = await BookDao(database).getChaptersForBook(bookId);
    expect(cached.every((chapter) => chapter.content != null), isTrue);
  });

  test('read_chapter_excerpt only prepares the requested PDF page', () async {
    final fixture = await _createPdfFixture([
      'first page remains unread',
      'target page excerpt',
    ]);
    addTearDown(() => fixture.directory.delete(recursive: true));
    final bookId = await _insertBook(
      database,
      title: 'PDF excerpt',
      filePath: fixture.file.path,
      format: 'pdf',
    );
    await _insertChapter(
      database,
      bookId: bookId,
      title: 'Page 1',
      content: null,
      sortOrder: 0,
    );
    final targetChapterId = await _insertChapter(
      database,
      bookId: bookId,
      title: 'Page 2',
      content: null,
      sortOrder: 1,
    );

    final result = await ReadChapterExcerptTool(
      database,
      bookContentService: AIBookContentService(BookDao(database)),
    ).run(
      {'chapterId': targetChapterId, 'maxChars': 400},
      _fullBookContext(bookId),
    );

    expect(result.data['excerpt'], contains('target page excerpt'));
    final cached = await BookDao(database).getChaptersForBook(bookId);
    expect(cached[0].content, isNull);
    expect(cached[1].content, contains('target page excerpt'));
  });

  test('search_current_book ranks denser matches before earlier chapters',
      () async {
    final bookId = await _insertBook(database, title: '目标书');
    await _insertChapter(
      database,
      bookId: bookId,
      title: '早期弱命中',
      content: '方源短暂出现。',
      sortOrder: 0,
    );
    await _insertChapter(
      database,
      bookId: bookId,
      title: '后期强命中',
      content: '方源作出选择。方源继续前进。方源再次出现。',
      sortOrder: 10,
    );

    final result = await SearchCurrentBookTool(database).run(
      {'query': '方源', 'limit': 1},
      _fullBookContext(bookId),
    );

    final matches = result.data['matches'] as List;
    expect(matches.single['chapterTitle'], '后期强命中');
    expect(matches.single['hitCount'], 3);
    expect(result.data['hasMore'], isTrue);
    expect(result.summary, contains('至少 1 个章节'));
  });

  test('search tools treat LIKE wildcard and escape characters literally',
      () async {
    final bookId = await _insertBook(database, title: '符号书');
    await _insertChapter(
      database,
      bookId: bookId,
      title: '路径章节',
      content: r'模型路径是 C:\AI_100%\model。普通文本不应误命中。',
      sortOrder: 0,
    );
    await database.into(database.notes).insert(
          NotesCompanion.insert(
            bookId: bookId,
            content: const Value(r'笔记路径是 C:\AI_100%\model。'),
            type: const Value('note'),
          ),
        );

    final literal = await SearchCurrentBookTool(database).run(
      {'query': r'C:\AI_100%\model'},
      _fullBookContext(bookId),
    );
    final wildcardOnly = await SearchCurrentBookTool(database).run(
      {'query': r'C:\AI_101%\model'},
      _fullBookContext(bookId),
    );
    final literalNote = await SearchNotesTool(database).run(
      {'query': r'C:\AI_100%\model'},
      _fullBookContext(bookId),
    );
    final wildcardOnlyNote = await SearchNotesTool(database).run(
      {'query': r'C:\AI_101%\model'},
      _fullBookContext(bookId),
    );

    expect(literal.data['matches'], hasLength(1));
    expect(wildcardOnly.data['matches'], isEmpty);
    expect(literalNote.data['matches'], hasLength(1));
    expect(wildcardOnlyNote.data['matches'], isEmpty);
  });

  test('string tool arguments reject non-string model values safely', () async {
    final bookId = await _insertBook(database, title: '目标书');

    final result = await SearchCurrentBookTool(database).run(
      {'query': 123, 'limit': 'bad'},
      _fullBookContext(bookId),
    );

    expect(result.summary, '搜索关键词为空。');
    expect(result.data['matches'], isEmpty);
  });

  test('search tools reject oversized model queries', () async {
    final bookId = await _insertBook(database, title: '目标书');
    final oversizedQuery = List.filled(201, 'a').join();

    final bookResult = await SearchCurrentBookTool(database).run(
      {'query': oversizedQuery},
      _fullBookContext(bookId),
    );
    final noteResult = await SearchNotesTool(database).run(
      {'query': oversizedQuery},
      _fullBookContext(bookId),
    );

    expect(bookResult.summary, contains('200'));
    expect(bookResult.data['matches'], isEmpty);
    expect(noteResult.summary, contains('200'));
    expect(noteResult.data['matches'], isEmpty);
  });

  test('numeric tool arguments fall back for non-finite values', () async {
    final bookId = await _insertBook(database, title: '目标书');
    await _insertChapter(
      database,
      bookId: bookId,
      title: '第一章',
      content: '方源出现。',
      sortOrder: 0,
    );

    final result = await SearchCurrentBookTool(database).run(
      {
        'query': '方源',
        'limit': double.infinity,
        'contextChars': double.nan,
      },
      _fullBookContext(bookId),
    );

    expect(result.data['matches'], hasLength(1));
  });

  test('tool observation remains valid JSON when truncated', () {
    final result = AgentToolResult(
      summary: '长结果',
      data: {
        'text': List.filled(1000, '很长的工具返回').join(),
      },
    );

    final observation = result.toObservation(maxChars: 240);
    final decoded = jsonDecode(observation) as Map<String, dynamic>;

    expect(observation.length, lessThanOrEqualTo(240));
    expect(decoded['truncated'], isTrue);
    expect(decoded['dataText'], isA<String>());
  });

  test('read_chapter_excerpt clamps excerpt length', () async {
    final bookId = await _insertBook(database, title: '目标书');
    final chapterId = await _insertChapter(
      database,
      bookId: bookId,
      title: '长章节',
      content:
          '${List.filled(200, '背景').join()}方源${List.filled(200, '后续').join()}',
      sortOrder: 0,
    );

    final result = await ReadChapterExcerptTool(database).run(
      {'chapterId': chapterId, 'query': '方源', 'maxChars': 200},
      _fullBookContext(bookId),
    );

    final excerpt = result.data['excerpt'] as String;
    expect(excerpt.length, lessThanOrEqualTo(200));
    expect(excerpt, contains('方源'));
    expect(result.data['queryMatched'], isTrue);
    expect(result.data['textOffsetStart'], 400);
    expect(result.data['textOffsetEnd'], 402);
    expect(result.data['selectedText'], '方源');
    expect(result.data['contextHash'], isNotEmpty);
    expect(
      result.data['chapterPosition'],
      closeTo(400 / 802, 0.001),
    );
  });

  test('read_chapter_excerpt rejects oversized location queries', () async {
    final bookId = await _insertBook(database, title: '目标书');
    final chapterId = await _insertChapter(
      database,
      bookId: bookId,
      title: '第一章',
      content: '章节正文',
      sortOrder: 0,
    );

    final result = await ReadChapterExcerptTool(database).run(
      {
        'chapterId': chapterId,
        'query': List.filled(201, 'a').join(),
      },
      _fullBookContext(bookId),
    );

    expect(result.summary, contains('200'));
    expect(result.data['excerpt'], isNull);
  });

  test('read_chapter_excerpt labels a missing query before returning opening',
      () async {
    final bookId = await _insertBook(database, title: '目标书');
    final chapterId = await _insertChapter(
      database,
      bookId: bookId,
      title: '普通章节',
      content: '${List.filled(300, '开头内容').join()}结尾',
      sortOrder: 0,
    );

    final result = await ReadChapterExcerptTool(database).run(
      {'chapterId': chapterId, 'query': '不存在的人名', 'maxChars': 200},
      _fullBookContext(bookId),
    );

    expect(result.data['queryMatched'], isFalse);
    expect(result.summary, contains('未找到“不存在的人名”'));
    expect(result.data['excerpt'], startsWith('开头内容'));
  });

  test('read_chapter_excerpt only reads chapters from current book', () async {
    final bookId = await _insertBook(database, title: '目标书');
    final otherBookId = await _insertBook(database, title: '其他书');
    final otherChapterId = await _insertChapter(
      database,
      bookId: otherBookId,
      title: '外部章节',
      content: '这段内容不应该被当前书工具读取。',
      sortOrder: 0,
    );

    final result = await ReadChapterExcerptTool(database).run(
      {'chapterId': otherChapterId, 'maxChars': 400},
      _fullBookContext(bookId),
    );

    expect(result.data['excerpt'], isNull);
    expect(result.summary, contains('没有找到章节'));
  });

  test('search_notes searches only notes from current book', () async {
    final bookId = await _insertBook(database, title: '目标书');
    final otherBookId = await _insertBook(database, title: '其他书');
    final chapterId = await _insertChapter(
      database,
      bookId: bookId,
      title: '笔记章节',
      content: '正文',
      sortOrder: 0,
    );
    await database.into(database.notes).insert(
          NotesCompanion.insert(
            bookId: bookId,
            chapterId: Value(chapterId),
            selectedText: const Value('方源在这里做出选择。'),
            content: const Value('我的批注提到方源的目标。'),
            positionStart: const Value(12),
            positionEnd: const Value(14),
            type: const Value('note'),
          ),
        );
    await database.into(database.notes).insert(
          NotesCompanion.insert(
            bookId: otherBookId,
            selectedText: const Value('方源出现在其他书。'),
            type: const Value('note'),
          ),
        );

    final result = await SearchNotesTool(database).run(
      {'query': '方源', 'limit': 8, 'contextChars': 60},
      _fullBookContext(bookId, bookTitle: '目标书'),
    );

    final matches = result.data['matches'] as List;
    expect(matches, hasLength(1));
    expect(matches.single['chapterTitle'], '笔记章节');
    expect(matches.single['hitCount'], 2);
    expect(matches.single['textOffsetStart'], 12);
    expect(matches.single['textOffsetEnd'], 14);
    expect((matches.single['snippets'] as List).join('\n'), contains('方源'));
    expect(result.data['hasMore'], isFalse);
    expect(result.toObservation().length, lessThanOrEqualTo(4000));
  });

  test('search_notes ranks denser matches before newer weak matches', () async {
    final bookId = await _insertBook(database, title: '目标书');
    await database.into(database.notes).insert(
          NotesCompanion.insert(
            bookId: bookId,
            content: const Value('方源方源方源，重要线索。'),
            type: const Value('note'),
          ),
        );
    await database.into(database.notes).insert(
          NotesCompanion.insert(
            bookId: bookId,
            content: const Value('方源，较新的弱线索。'),
            type: const Value('note'),
          ),
        );

    final result = await SearchNotesTool(database).run(
      {'query': '方源', 'limit': 1},
      _fullBookContext(bookId),
    );

    final matches = result.data['matches'] as List;
    expect(matches.single['hitCount'], 3);
    expect(matches.single['content'], contains('重要线索'));
    expect(result.data['hasMore'], isTrue);
    expect(result.summary, contains('相关度最高'));
  });

  test('strict spoiler protection excludes future and unread current content',
      () async {
    final bookId = await _insertBook(database, title: '防剧透测试书');
    await _insertChapter(
      database,
      bookId: bookId,
      title: '已读章节',
      content: '方源在此前章节留下线索。',
      sortOrder: 0,
    );
    const readPrefix = '方源看到一条普通线索。';
    const unreadSuffix = '未读反转揭晓真正身份。';
    final currentChapterId = await _insertChapter(
      database,
      bookId: bookId,
      title: '当前章节',
      content: '$readPrefix$unreadSuffix',
      sortOrder: 1,
    );
    await _insertChapter(
      database,
      bookId: bookId,
      title: '未来章节',
      content: '未读反转在未来章节再次确认。',
      sortOrder: 2,
    );
    const currentPosition =
        (readPrefix.length + 0.25) / (readPrefix.length + unreadSuffix.length);
    final context = AgentContext(
      bookId: bookId,
      currentChapterId: currentChapterId,
      currentPosition: currentPosition,
    );

    final readable = await SearchCurrentBookTool(database).run(
      {'query': '方源'},
      context,
    );
    final blockedFuture = await SearchCurrentBookTool(database).run(
      {'query': '未读反转'},
      context,
    );

    expect(readable.data['matches'], hasLength(2));
    expect(readable.data['scope'], 'read');
    expect(readable.data['containsUnreadContent'], isFalse);
    expect(blockedFuture.data['matches'], isEmpty);
  });

  test('strict spoiler protection falls back to persisted reading progress',
      () async {
    final bookId = await _insertBook(database, title: '进度边界测试书');
    await _insertChapter(
      database,
      bookId: bookId,
      title: '已读章节',
      content: '已读证据在这里。',
      sortOrder: 0,
    );
    final currentChapterId = await _insertChapter(
      database,
      bookId: bookId,
      title: '当前章节',
      content: '当前章节也已读完。',
      sortOrder: 1,
    );
    await _insertChapter(
      database,
      bookId: bookId,
      title: '未来章节',
      content: '未来秘密不应出现。',
      sortOrder: 2,
    );
    await database.into(database.readingProgress).insert(
          ReadingProgressCompanion.insert(
            bookId: Value(bookId),
            chapterId: Value(currentChapterId),
            positionInChapter: const Value(1.0),
          ),
        );

    final readable = await SearchCurrentBookTool(database).run(
      {'query': '已读证据'},
      AgentContext(bookId: bookId),
    );
    final future = await SearchCurrentBookTool(database).run(
      {'query': '未来秘密'},
      AgentContext(bookId: bookId),
    );

    expect(readable.data['matches'], hasLength(1));
    expect(future.data['matches'], isEmpty);
  });

  test('ask mode requires confirmation before full-book search', () async {
    final bookId = await _insertBook(database, title: '询问模式测试书');
    final currentChapterId = await _insertChapter(
      database,
      bookId: bookId,
      title: '当前章节',
      content: '目前只知道一半。',
      sortOrder: 0,
    );
    await _insertChapter(
      database,
      bookId: bookId,
      title: '未来章节',
      content: '结局线索在这里。',
      sortOrder: 1,
    );
    final context = AgentContext(
      bookId: bookId,
      currentChapterId: currentChapterId,
      currentPosition: 1,
      spoilerProtectionLevel: SpoilerProtectionLevel.ask,
    );

    final blocked = await SearchCurrentBookTool(database).run(
      {'query': '结局线索', 'scope': 'full'},
      context,
    );
    final allowed = await SearchCurrentBookTool(database).run(
      {'query': '结局线索', 'scope': 'full'},
      context.copyWith(unreadContentAuthorized: true),
    );

    expect(blocked.data['spoilerBlocked'], isTrue);
    expect(blocked.data['requiresConfirmation'], isTrue);
    expect(blocked.data['matches'], isEmpty);
    expect(allowed.data['matches'], hasLength(1));
    expect(allowed.data['containsUnreadContent'], isTrue);
    expect((allowed.data['matches'] as List).single['isUnread'], isTrue);
  });

  test('strict excerpt blocks a future PDF page before extracting it',
      () async {
    final fixture = await _createPdfFixture([
      'already read page',
      'future spoiler page',
    ]);
    addTearDown(() => fixture.directory.delete(recursive: true));
    final bookId = await _insertBook(
      database,
      title: 'PDF 防剧透',
      filePath: fixture.file.path,
      format: 'pdf',
    );
    final currentChapterId = await _insertChapter(
      database,
      bookId: bookId,
      title: 'Page 1',
      content: null,
      sortOrder: 0,
    );
    final futureChapterId = await _insertChapter(
      database,
      bookId: bookId,
      title: 'Page 2',
      content: null,
      sortOrder: 1,
    );

    final result = await ReadChapterExcerptTool(
      database,
      bookContentService: AIBookContentService(BookDao(database)),
    ).run(
      {'chapterId': futureChapterId},
      AgentContext(
        bookId: bookId,
        currentChapterId: currentChapterId,
        currentPosition: 1,
      ),
    );

    expect(result.data['spoilerBlocked'], isTrue);
    expect(await BookDao(database).getChapterContent(futureChapterId), isNull);
  });

  test('strict note search excludes current and future chapter notes',
      () async {
    final bookId = await _insertBook(database, title: '笔记防剧透');
    final previousChapterId = await _insertChapter(
      database,
      bookId: bookId,
      title: '前一章',
      content: '前文',
      sortOrder: 0,
    );
    final currentChapterId = await _insertChapter(
      database,
      bookId: bookId,
      title: '当前章',
      content: '当前正文',
      sortOrder: 1,
    );
    final futureChapterId = await _insertChapter(
      database,
      bookId: bookId,
      title: '后一章',
      content: '后文',
      sortOrder: 2,
    );
    for (final entry in [
      (chapterId: previousChapterId, content: '共同关键词：已读笔记'),
      (chapterId: currentChapterId, content: '共同关键词：当前章笔记'),
      (chapterId: futureChapterId, content: '共同关键词：未来笔记'),
    ]) {
      await database.into(database.notes).insert(
            NotesCompanion.insert(
              bookId: bookId,
              chapterId: Value(entry.chapterId),
              content: Value(entry.content),
            ),
          );
    }

    final result = await SearchNotesTool(database).run(
      {'query': '共同关键词'},
      AgentContext(
        bookId: bookId,
        currentChapterId: currentChapterId,
        currentPosition: 0.8,
      ),
    );

    final matches = result.data['matches'] as List;
    expect(matches, hasLength(1));
    expect(matches.single['chapterId'], previousChapterId);
    expect(result.data['containsUnreadContent'], isFalse);
  });

  test('get_current_reading_context includes selected text', () async {
    final result = await GetCurrentReadingContextTool().run(
      const {},
      const AgentContext(
        bookId: 1,
        bookTitle: '测试书',
        currentChapterId: 2,
        currentChapterTitle: '第一章',
        selectedText: '短选中文本',
        surroundingText: '上下文',
      ),
    );

    expect(result.data['selectedText'], '短选中文本');
    expect(result.data['surroundingText'], '上下文');
  });
}

AgentContext _fullBookContext(int bookId, {String? bookTitle}) {
  return AgentContext(
    bookId: bookId,
    bookTitle: bookTitle,
    spoilerProtectionLevel: SpoilerProtectionLevel.fullBook,
  );
}

Future<int> _insertBook(
  AppDatabase database, {
  required String title,
  String? filePath,
  String format = 'txt',
}) {
  return database.into(database.books).insert(
        BooksCompanion.insert(
          title: title,
          filePath: filePath ?? '$title.$format',
          format: format,
          fileSize: 1,
        ),
      );
}

Future<int> _insertChapter(
  AppDatabase database, {
  required int bookId,
  required String title,
  required String? content,
  required int sortOrder,
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

Future<({Directory directory, File file})> _createPdfFixture(
  List<String> pageTexts,
) async {
  final directory = await Directory.systemTemp.createTemp('ai_tools_pdf_');
  final file = File(
    '${directory.path}${Platform.pathSeparator}fixture.pdf',
  );
  final document = PdfDocument();
  try {
    for (final text in pageTexts) {
      document.pages.add().graphics.drawString(
            text,
            PdfStandardFont(PdfFontFamily.helvetica, 12),
          );
    }
    await file.writeAsBytes(await document.save(), flush: true);
  } finally {
    document.dispose();
  }
  return (directory: directory, file: file);
}
