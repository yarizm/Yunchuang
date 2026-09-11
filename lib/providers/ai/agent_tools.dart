import 'dart:convert';
import 'dart:math' as math;

import 'package:drift/drift.dart';

import '../../database/app_database.dart';
import '../../models/reader_locator.dart';
import '../../parsers/epub_parser.dart';
import 'agent_models.dart';
import 'ai_book_content_service.dart';
import 'ai_provider.dart';

abstract class AgentTool {
  String get name;
  String get runningMessage;
  String get description;
  Map<String, dynamic> get inputSchema;

  Future<AgentToolResult> run(Map<String, dynamic> args, AgentContext context,
      {AIRequestCancellation? cancellation});
}

class AgentToolResult {
  final String summary;
  final Map<String, dynamic> data;

  const AgentToolResult({
    required this.summary,
    required this.data,
  });

  String toObservation({int maxChars = 4000}) {
    final encoded = jsonEncode({
      'summary': summary,
      'data': data,
    });
    if (encoded.length <= maxChars) return encoded;
    var payloadChars = math.min(encoded.length, maxChars);
    while (payloadChars > 0) {
      final truncated = jsonEncode({
        'summary': summary,
        'truncated': true,
        'dataText': encoded.substring(0, payloadChars),
      });
      if (truncated.length <= maxChars) return truncated;
      payloadChars -= math.max(1, truncated.length - maxChars);
    }

    final fallback = jsonEncode({
      'truncated': true,
      'dataText': '',
    });
    if (fallback.length <= maxChars) return fallback;
    return maxChars >= 2 ? '{}' : '';
  }
}

class AgentToolRegistry {
  final Map<String, AgentTool> _tools;

  AgentToolRegistry(Iterable<AgentTool> tools)
      : _tools = {for (final tool in tools) tool.name: tool};

  List<AgentTool> get tools => _tools.values.toList(growable: false);

  AgentTool? byName(String name) => _tools[name];

  bool contains(String name) => _tools.containsKey(name);
}

class SearchCurrentBookTool implements AgentTool {
  final AppDatabase db;
  final AIBookContentService? bookContentService;

  SearchCurrentBookTool(this.db, {this.bookContentService});

  @override
  String get name => 'search_current_book';

  @override
  String get runningMessage => '正在搜索当前书...';

  @override
  String get description =>
      '在当前书籍正文中用本地精确关键词搜索，返回命中章节和片段。默认只搜索已读范围；只有用户明确要求未读内容时才使用 full 范围。';

  @override
  Map<String, dynamic> get inputSchema => {
        'type': 'object',
        'properties': {
          'query': {'type': 'string', 'maxLength': _maxToolQueryChars},
          'limit': {'type': 'integer', 'default': 8},
          'contextChars': {'type': 'integer', 'default': 160},
          'scope': {
            'type': 'string',
            'enum': ['read', 'full'],
            'default': 'read',
          },
        },
        'required': ['query'],
      };

  @override
  Future<AgentToolResult> run(Map<String, dynamic> args, AgentContext context,
      {AIRequestCancellation? cancellation}) async {
    cancellation?.throwIfCancelled();
    final bookId = context.bookId;
    if (bookId == null) {
      return const AgentToolResult(
        summary: '没有当前书籍上下文，无法搜索。',
        data: {'matches': []},
      );
    }

    final query = _stringArg(args['query']);
    if (query.isEmpty) {
      return const AgentToolResult(
        summary: '搜索关键词为空。',
        data: {'matches': []},
      );
    }
    if (query.length > _maxToolQueryChars) {
      return const AgentToolResult(
        summary: '搜索关键词过长，最多 200 个字符。',
        data: {'matches': []},
      );
    }

    final limit = _intArg(args['limit'], 8).clamp(1, 20).toInt();
    final contextChars =
        _intArg(args['contextChars'], 160).clamp(40, 400).toInt();
    final book = await (db.select(db.books)
          ..where((candidate) => candidate.id.equals(bookId)))
        .getSingleOrNull();
    cancellation?.throwIfCancelled();
    if (book == null) {
      return const AgentToolResult(
        summary: '当前书籍不存在，无法搜索。',
        data: {'matches': []},
      );
    }

    final boundary = await _resolveReadingBoundary(db, context);
    final requestedFullBook = _requestsFullBook(args);
    if (requestedFullBook && !boundary.unrestricted) {
      return _spoilerBlockedResult(
        context,
        tool: name,
        requestedScope: 'full',
      );
    }
    if (!boundary.unrestricted && !boundary.hasReadableContent) {
      return AgentToolResult(
        summary: '还没有可供 AI 检索的已读正文。',
        data: {
          'query': query,
          'bookId': bookId,
          'bookTitle': context.bookTitle,
          'scope': 'read',
          'matches': const [],
        },
      );
    }

    if (bookContentService != null) {
      if (boundary.unrestricted) {
        await bookContentService!.ensureAllChapterContent(
          bookId,
          cancellation: cancellation,
        );
      } else {
        final readableChapterIds = await _readableChapterIds(
          db,
          bookId,
          boundary,
        );
        await bookContentService!.ensureChapterContents(
          bookId,
          readableChapterIds,
          cancellation: cancellation,
        );
      }
    }
    cancellation?.throwIfCancelled();

    final rankedMatches = book.format.toLowerCase() == 'epub'
        ? await _searchReadableEpubChapters(
            bookId,
            query,
            limit + 1,
            boundary,
            cancellation,
          )
        : await _searchDatabaseChapters(
            bookId,
            query,
            limit + 1,
            boundary,
          );
    cancellation?.throwIfCancelled();

    final hasMore = rankedMatches.length > limit;
    final matches = <Map<String, dynamic>>[];
    for (final match in rankedMatches.take(limit)) {
      final snippets =
          _snippets(match.content, query, contextChars, maxSnippets: 2);
      final queryIndex = _queryIndex(match.content, query);
      final chapterPosition = _queryPosition(
        match.content,
        query,
        fullContentLength: match.fullContentLength,
      );
      matches.add({
        'chapterId': match.chapterId,
        'chapterTitle': match.chapterTitle,
        'hitCount': match.hitCount,
        'chapterPosition': chapterPosition,
        if (queryIndex >= 0)
          ...ReaderLocator.textAnchorJson(
            match.content,
            queryIndex,
            queryIndex + query.length,
          ),
        'isUnread': boundary.isUnread(
          match.chapterId,
          match.sortOrder,
          chapterPosition,
        ),
        'snippets': snippets,
      });
    }
    final containsUnreadContent =
        matches.any((match) => match['isUnread'] == true);

    return AgentToolResult(
      summary: hasMore
          ? '找到至少 ${matches.length} 个章节命中“$query”，已返回相关度最高的结果。'
          : '找到 ${matches.length} 个章节命中“$query”。',
      data: {
        'query': query,
        'bookId': bookId,
        'bookTitle': context.bookTitle,
        'scope': boundary.unrestricted ? 'full' : 'read',
        'containsUnreadContent': containsUnreadContent,
        'hasMore': hasMore,
        'matches': matches,
      },
    );
  }

  Future<List<_BookSearchMatch>> _searchDatabaseChapters(
    int bookId,
    String query,
    int resultLimit,
    _ReadingBoundary boundary,
  ) async {
    final escaped = _escapeLikePattern(query);
    final querySql = boundary.unrestricted
        ? 'SELECT c.id AS id, c.title AS title, c.content AS content, '
            'length(c.content) AS full_length, c.sort_order AS sort_order, '
            'b.format AS book_format, '
            'CAST((length(lower(c.content)) - '
            "length(replace(lower(c.content), lower(?), ''))) / length(?) AS INTEGER) "
            'AS hit_count FROM chapters c '
            'INNER JOIN books b ON b.id = c.book_id '
            'WHERE c.book_id = ? AND c.content IS NOT NULL '
            "AND c.content LIKE ? ESCAPE '\\' "
            'ORDER BY hit_count DESC, c.sort_order LIMIT ?'
        : 'WITH scoped_chapters AS ('
            'SELECT c.id, c.title, c.sort_order, b.format AS book_format, '
            'length(c.content) AS full_length, '
            'CASE WHEN c.id = ? THEN '
            'substr(c.content, 1, CAST(length(c.content) * ? AS INTEGER)) '
            'ELSE c.content END AS content '
            'FROM chapters c INNER JOIN books b ON b.id = c.book_id '
            'WHERE c.book_id = ? AND c.content IS NOT NULL AND '
            '(c.sort_order < ? OR c.id = ?)'
            ') '
            'SELECT id, title, content, full_length, sort_order, book_format, '
            'CAST((length(lower(content)) - '
            "length(replace(lower(content), lower(?), ''))) / length(?) AS INTEGER) "
            'AS hit_count FROM scoped_chapters '
            "WHERE content LIKE ? ESCAPE '\\' "
            'ORDER BY hit_count DESC, sort_order LIMIT ?';
    final variables = boundary.unrestricted
        ? <Variable>[
            Variable.withString(query),
            Variable.withString(query),
            Variable.withInt(bookId),
            Variable.withString('%$escaped%'),
            Variable.withInt(resultLimit),
          ]
        : <Variable>[
            Variable.withInt(boundary.currentChapterId!),
            Variable.withReal(boundary.currentPosition),
            Variable.withInt(bookId),
            Variable.withInt(boundary.currentSortOrder!),
            Variable.withInt(boundary.currentChapterId!),
            Variable.withString(query),
            Variable.withString(query),
            Variable.withString('%$escaped%'),
            Variable.withInt(resultLimit),
          ];
    final rows = await db.customSelect(
      querySql,
      variables: variables,
      readsFrom: {db.chapters, db.books},
    ).get();
    return rows
        .map((row) => _BookSearchMatch(
              chapterId: row.read<int>('id'),
              chapterTitle: row.read<String>('title'),
              sortOrder: row.read<int>('sort_order'),
              content: _readableBookContent(
                row.read<String?>('content') ?? '',
                row.read<String>('book_format'),
              ),
              fullContentLength: row.read<int>('full_length'),
              hitCount: row.read<int>('hit_count'),
            ))
        .toList(growable: false);
  }

  Future<List<_BookSearchMatch>> _searchReadableEpubChapters(
    int bookId,
    String query,
    int resultLimit,
    _ReadingBoundary boundary,
    AIRequestCancellation? cancellation,
  ) async {
    final allChapters = await (db.select(db.chapters)
          ..where((chapter) => chapter.bookId.equals(bookId))
          ..orderBy([(chapter) => OrderingTerm.asc(chapter.sortOrder)]))
        .get();
    final chapters = allChapters
        .where((chapter) => boundary.allowsChapter(
              chapter.id,
              chapter.sortOrder,
            ))
        .toList(growable: false);
    final htmlDocuments = chapters.map((chapter) => chapter.content ?? '');
    final readableContents = bookContentService == null
        ? await EpubParser.stripHtmlBatch(htmlDocuments)
        : await bookContentService!.normalizeEpubDocuments(htmlDocuments);
    cancellation?.throwIfCancelled();
    final matches = <_BookSearchMatch>[];
    for (var index = 0; index < chapters.length; index++) {
      cancellation?.throwIfCancelled();
      final chapter = chapters[index];
      final fullContent = readableContents[index];
      final content = boundary.cropChapterContent(
        chapter.id,
        fullContent,
      );
      final hitCount = _substringHitCount(content, query);
      if (hitCount == 0) continue;
      matches.add(_BookSearchMatch(
        chapterId: chapter.id,
        chapterTitle: chapter.title,
        sortOrder: chapter.sortOrder,
        content: content,
        fullContentLength: fullContent.length,
        hitCount: hitCount,
      ));
    }
    matches.sort((left, right) {
      final byHits = right.hitCount.compareTo(left.hitCount);
      return byHits != 0 ? byHits : left.sortOrder.compareTo(right.sortOrder);
    });
    return matches.take(resultLimit).toList(growable: false);
  }
}

class ReadChapterExcerptTool implements AgentTool {
  final AppDatabase db;
  final AIBookContentService? bookContentService;

  ReadChapterExcerptTool(this.db, {this.bookContentService});

  @override
  String get name => 'read_chapter_excerpt';

  @override
  String get runningMessage => '正在读取章节片段...';

  @override
  String get description =>
      '读取指定章节的短片段，可围绕关键词截取。默认只能读取已读范围；只有用户明确要求未读内容时才使用 full 范围。';

  @override
  Map<String, dynamic> get inputSchema => {
        'type': 'object',
        'properties': {
          'chapterId': {'type': 'integer'},
          'query': {'type': 'string', 'maxLength': _maxToolQueryChars},
          'maxChars': {'type': 'integer', 'default': 1200},
          'scope': {
            'type': 'string',
            'enum': ['read', 'full'],
            'default': 'read',
          },
        },
        'required': ['chapterId'],
      };

  @override
  Future<AgentToolResult> run(Map<String, dynamic> args, AgentContext context,
      {AIRequestCancellation? cancellation}) async {
    cancellation?.throwIfCancelled();
    final bookId = context.bookId;
    if (bookId == null) {
      return const AgentToolResult(
        summary: '没有当前书籍上下文，无法读取章节片段。',
        data: {},
      );
    }

    final chapterId = _intArg(args['chapterId'], -1);
    final maxChars = _intArg(args['maxChars'], 1200).clamp(200, 4000).toInt();
    if (chapterId <= 0) {
      return const AgentToolResult(
        summary: '章节 id 无效。',
        data: {},
      );
    }

    final rows = await db.customSelect(
      'SELECT c.id AS id, c.title AS title, c.content AS content, '
      'c.sort_order AS sort_order, b.format AS book_format FROM chapters c '
      'INNER JOIN books b ON b.id = c.book_id '
      'WHERE c.id = ? AND c.book_id = ? LIMIT 1',
      variables: [Variable.withInt(chapterId), Variable.withInt(bookId)],
      readsFrom: {db.chapters, db.books},
    ).get();
    if (rows.isEmpty) {
      return AgentToolResult(
        summary: '没有找到章节 $chapterId。',
        data: {'chapterId': chapterId},
      );
    }

    final row = rows.first;
    final boundary = await _resolveReadingBoundary(db, context);
    final targetSortOrder = row.read<int>('sort_order');
    final requestedFullBook = _requestsFullBook(args);
    final targetAllowed = boundary.unrestricted ||
        boundary.allowsChapter(chapterId, targetSortOrder);
    if (requestedFullBook && !boundary.unrestricted || !targetAllowed) {
      return _spoilerBlockedResult(
        context,
        tool: name,
        requestedScope: 'full',
        chapterId: chapterId,
      );
    }

    await bookContentService?.ensureChapterContent(
      bookId,
      chapterId,
      cancellation: cancellation,
    );
    cancellation?.throwIfCancelled();
    final preparedRows = await db.customSelect(
      'SELECT c.content AS content, b.format AS book_format '
      'FROM chapters c INNER JOIN books b ON b.id = c.book_id '
      'WHERE c.id = ? AND c.book_id = ? LIMIT 1',
      variables: [Variable.withInt(chapterId), Variable.withInt(bookId)],
      readsFrom: {db.chapters, db.books},
    ).get();
    if (preparedRows.isEmpty) {
      return AgentToolResult(
        summary: '没有找到章节 $chapterId。',
        data: {'chapterId': chapterId},
      );
    }
    final preparedRow = preparedRows.first;
    final fullContent = await _readableBookContentAsync(
      preparedRow.read<String?>('content') ?? '',
      preparedRow.read<String>('book_format'),
      bookContentService,
    );
    final content = boundary.unrestricted
        ? fullContent
        : boundary.cropChapterContent(chapterId, fullContent);
    cancellation?.throwIfCancelled();
    final query = _stringArg(args['query']);
    if (query.length > _maxToolQueryChars) {
      return AgentToolResult(
        summary: '章节定位关键词过长，最多 200 个字符。',
        data: {'chapterId': chapterId},
      );
    }
    final queryMatched = query.isEmpty
        ? null
        : content.toLowerCase().contains(query.toLowerCase());
    final queryIndex = queryMatched == true ? _queryIndex(content, query) : -1;
    final excerpt = _excerpt(content, query, maxChars);
    return AgentToolResult(
      summary: queryMatched == false ? '章节中未找到“$query”，已返回章节开头片段。' : '已读取章节片段。',
      data: {
        'chapterId': row.read<int>('id'),
        'chapterTitle': row.read<String>('title'),
        'bookId': bookId,
        'query': query.isEmpty ? null : query,
        'queryMatched': queryMatched,
        'chapterPosition': queryMatched == true
            ? _queryPosition(
                content,
                query,
                fullContentLength: fullContent.length,
              )
            : 0.0,
        if (queryIndex >= 0)
          ...ReaderLocator.textAnchorJson(
            content,
            queryIndex,
            queryIndex + query.length,
          ),
        'scope': boundary.unrestricted ? 'full' : 'read',
        'isUnread': boundary.isUnread(
          chapterId,
          targetSortOrder,
          queryMatched == true
              ? _queryPosition(
                  content,
                  query,
                  fullContentLength: fullContent.length,
                )
              : 0.0,
        ),
        'excerpt': excerpt,
      },
    );
  }
}

class SearchNotesTool implements AgentTool {
  final AppDatabase db;

  SearchNotesTool(this.db);

  @override
  String get name => 'search_notes';

  @override
  String get runningMessage => '正在搜索笔记...';

  @override
  String get description =>
      '在当前书籍的划线和笔记中搜索关键词，返回命中的笔记片段。默认只搜索已读章节；只有用户明确要求未读内容时才使用 full 范围。';

  @override
  Map<String, dynamic> get inputSchema => {
        'type': 'object',
        'properties': {
          'query': {'type': 'string', 'maxLength': _maxToolQueryChars},
          'limit': {'type': 'integer', 'default': 8},
          'contextChars': {'type': 'integer', 'default': 120},
          'scope': {
            'type': 'string',
            'enum': ['read', 'full'],
            'default': 'read',
          },
        },
        'required': ['query'],
      };

  @override
  Future<AgentToolResult> run(Map<String, dynamic> args, AgentContext context,
      {AIRequestCancellation? cancellation}) async {
    cancellation?.throwIfCancelled();
    final bookId = context.bookId;
    if (bookId == null) {
      return const AgentToolResult(
        summary: '没有当前书籍上下文，无法搜索笔记。',
        data: {'matches': []},
      );
    }

    final query = _stringArg(args['query']);
    if (query.isEmpty) {
      return const AgentToolResult(
        summary: '笔记搜索关键词为空。',
        data: {'matches': []},
      );
    }
    if (query.length > _maxToolQueryChars) {
      return const AgentToolResult(
        summary: '笔记搜索关键词过长，最多 200 个字符。',
        data: {'matches': []},
      );
    }

    final limit = _intArg(args['limit'], 8).clamp(1, 20).toInt();
    final contextChars =
        _intArg(args['contextChars'], 120).clamp(40, 320).toInt();
    final escaped = _escapeLikePattern(query);
    final boundary = await _resolveReadingBoundary(db, context);
    if (_requestsFullBook(args) && !boundary.unrestricted) {
      return _spoilerBlockedResult(
        context,
        tool: name,
        requestedScope: 'full',
      );
    }
    if (!boundary.unrestricted && !boundary.hasEarlierChapters) {
      return AgentToolResult(
        summary: '还没有可供 AI 检索的已读章节笔记。',
        data: {
          'query': query,
          'bookId': bookId,
          'bookTitle': context.bookTitle,
          'scope': 'read',
          'matches': const [],
        },
      );
    }

    final scopeClause = boundary.unrestricted
        ? 'WHERE n.book_id = ?'
        : 'WHERE n.book_id = ? AND c.sort_order < ?';
    final rows = await db.customSelect(
      'WITH searchable_notes AS ('
      '  SELECT n.id, n.book_id, n.chapter_id, n.selected_text, n.content, '
      '  n.page_number, n.position_start, n.position_end, '
      '  n.type, n.updated_at, c.title AS chapter_title, '
      '  c.sort_order AS chapter_sort_order, '
      "  lower(COALESCE(n.selected_text, '') || char(10) || "
      "  COALESCE(n.content, '')) AS search_text "
      '  FROM notes n LEFT JOIN chapters c ON n.chapter_id = c.id '
      '  $scopeClause'
      ') '
      'SELECT id, book_id, chapter_id, selected_text, content, page_number, '
      'position_start, position_end, type, '
      'chapter_title, chapter_sort_order, '
      'CAST((length(search_text) - '
      "length(replace(search_text, lower(?), ''))) / length(?) AS INTEGER) "
      'AS hit_count '
      "FROM searchable_notes WHERE search_text LIKE ? ESCAPE '\\' "
      'ORDER BY hit_count DESC, updated_at DESC LIMIT ?',
      variables: [
        Variable.withInt(bookId),
        if (!boundary.unrestricted)
          Variable.withInt(boundary.currentSortOrder!),
        Variable.withString(query),
        Variable.withString(query),
        Variable.withString('%${escaped.toLowerCase()}%'),
        Variable.withInt(limit + 1),
      ],
      readsFrom: {db.notes, db.chapters},
    ).get();
    cancellation?.throwIfCancelled();

    final hasMore = rows.length > limit;
    final matches = <Map<String, dynamic>>[];
    for (final row in rows.take(limit)) {
      final selectedText = row.read<String?>('selected_text') ?? '';
      final content = row.read<String?>('content') ?? '';
      final searchable = [selectedText, content]
          .where((part) => part.trim().isNotEmpty)
          .join('\n');
      final snippets = _snippets(
        searchable,
        query,
        contextChars,
        maxSnippets: 2,
      );
      matches.add({
        'noteId': row.read<int>('id'),
        'chapterId': row.read<int?>('chapter_id'),
        'chapterTitle': row.read<String?>('chapter_title'),
        'pageNumber': row.read<int?>('page_number'),
        'textOffsetStart': row.read<int?>('position_start'),
        'textOffsetEnd': row.read<int?>('position_end'),
        'query': query,
        'type': row.read<String>('type'),
        'hitCount': row.read<int>('hit_count'),
        'isUnread': boundary.unrestricted &&
            row.read<int?>('chapter_sort_order') != null &&
            boundary.isUnread(
              row.read<int?>('chapter_id') ?? -1,
              row.read<int>('chapter_sort_order'),
              1.0,
            ),
        'selectedText': selectedText.isEmpty
            ? null
            : _excerpt(selectedText, query, contextChars * 2),
        'content':
            content.isEmpty ? null : _excerpt(content, query, contextChars * 2),
        'snippets': snippets,
      });
    }

    return AgentToolResult(
      summary: hasMore
          ? '找到至少 ${matches.length} 条笔记命中“$query”，已返回相关度最高的结果。'
          : '找到 ${matches.length} 条笔记命中“$query”。',
      data: {
        'query': query,
        'bookId': bookId,
        'bookTitle': context.bookTitle,
        'scope': boundary.unrestricted ? 'full' : 'read',
        'containsUnreadContent': matches.any(
          (match) => match['isUnread'] == true,
        ),
        'hasMore': hasMore,
        'matches': matches,
      },
    );
  }
}

class GetCurrentReadingContextTool implements AgentTool {
  @override
  String get name => 'get_current_reading_context';

  @override
  String get runningMessage => '正在获取阅读上下文...';

  @override
  String get description => '获取当前阅读位置、书名、章节名、选中文本和附近上下文。';

  @override
  Map<String, dynamic> get inputSchema => {
        'type': 'object',
        'properties': {},
      };

  @override
  Future<AgentToolResult> run(Map<String, dynamic> args, AgentContext context,
      {AIRequestCancellation? cancellation}) async {
    cancellation?.throwIfCancelled();
    return AgentToolResult(
      summary: '已获取当前阅读上下文。',
      data: context.toJson(),
    );
  }
}

const _maxToolQueryChars = 200;
const _maxSafeInteger = 9007199254740991;

class _ReadingBoundary {
  final bool unrestricted;
  final int? currentChapterId;
  final int? currentSortOrder;
  final double currentPosition;
  final bool hasEarlierChapters;

  const _ReadingBoundary({
    required this.unrestricted,
    required this.currentChapterId,
    required this.currentSortOrder,
    required this.currentPosition,
    required this.hasEarlierChapters,
  });

  bool get hasReadableContent =>
      unrestricted ||
      hasEarlierChapters ||
      currentChapterId != null && currentPosition > 0;

  bool allowsChapter(int chapterId, int sortOrder) {
    if (unrestricted) return true;
    final boundaryOrder = currentSortOrder;
    if (boundaryOrder == null || currentChapterId == null) return false;
    return sortOrder < boundaryOrder || chapterId == currentChapterId;
  }

  String cropChapterContent(int chapterId, String content) {
    if (unrestricted || chapterId != currentChapterId) return content;
    final end = (content.length * currentPosition)
        .floor()
        .clamp(0, content.length)
        .toInt();
    return content.substring(0, end);
  }

  bool isUnread(int chapterId, int sortOrder, double chapterPosition) {
    final boundaryOrder = currentSortOrder;
    if (boundaryOrder == null || currentChapterId == null) return true;
    if (sortOrder < boundaryOrder) return false;
    if (chapterId == currentChapterId) {
      return chapterPosition > currentPosition + 0.000001;
    }
    return true;
  }
}

Future<_ReadingBoundary> _resolveReadingBoundary(
  AppDatabase db,
  AgentContext context,
) async {
  final progress = context.bookId == null
      ? null
      : await (db.select(db.readingProgress)
            ..where((item) => item.bookId.equals(context.bookId!)))
          .getSingleOrNull();
  var chapterId = context.currentChapterId ?? progress?.chapterId;
  var position = context.currentChapterId != null
      ? context.currentPosition
      : progress?.positionInChapter;

  Chapter? chapter;
  if (context.bookId != null && chapterId != null) {
    chapter = await (db.select(db.chapters)
          ..where((item) =>
              item.id.equals(chapterId!) & item.bookId.equals(context.bookId!)))
        .getSingleOrNull();
  }
  if (chapter == null &&
      context.bookId != null &&
      progress?.chapterId != null &&
      progress!.chapterId != chapterId) {
    chapterId = progress.chapterId;
    position = progress.positionInChapter;
    chapter = await (db.select(db.chapters)
          ..where((item) =>
              item.id.equals(chapterId!) & item.bookId.equals(context.bookId!)))
        .getSingleOrNull();
  }

  final normalizedPosition = _normalizedPosition(position);
  final hasEarlierChapters = chapter == null || context.bookId == null
      ? false
      : await (db.select(db.chapters)
            ..where((item) =>
                item.bookId.equals(context.bookId!) &
                item.sortOrder.isSmallerThanValue(chapter!.sortOrder))
            ..limit(1))
          .get()
          .then((items) => items.isNotEmpty);
  return _ReadingBoundary(
    unrestricted: context.unreadContentAuthorized ||
        context.spoilerProtectionLevel == SpoilerProtectionLevel.fullBook,
    currentChapterId: chapter?.id,
    currentSortOrder: chapter?.sortOrder,
    currentPosition: normalizedPosition,
    hasEarlierChapters: hasEarlierChapters,
  );
}

double _normalizedPosition(double? value) {
  if (value == null || !value.isFinite) return 0;
  return value.clamp(0.0, 1.0).toDouble();
}

bool _requestsFullBook(Map<String, dynamic> args) => args['scope'] == 'full';

AgentToolResult _spoilerBlockedResult(
  AgentContext context, {
  required String tool,
  required String requestedScope,
  int? chapterId,
}) {
  final requiresConfirmation =
      context.spoilerProtectionLevel == SpoilerProtectionLevel.ask &&
          !context.unreadContentAuthorized;
  return AgentToolResult(
    summary:
        requiresConfirmation ? '该操作需要访问未读内容，请先获得用户本次授权。' : '防剧透模式已阻止访问未读内容。',
    data: {
      'tool': tool,
      'spoilerBlocked': true,
      'requiresConfirmation': requiresConfirmation,
      'requestedScope': requestedScope,
      if (chapterId != null) 'chapterId': chapterId,
      'matches': const [],
      'excerpt': null,
    },
  );
}

Future<List<int>> _readableChapterIds(
  AppDatabase db,
  int bookId,
  _ReadingBoundary boundary,
) async {
  final chapters = await (db.select(db.chapters)
        ..where((chapter) => chapter.bookId.equals(bookId)))
      .get();
  return chapters
      .where((chapter) =>
          boundary.allowsChapter(chapter.id, chapter.sortOrder) &&
          (chapter.id != boundary.currentChapterId ||
              boundary.currentPosition > 0))
      .map((chapter) => chapter.id)
      .toList(growable: false);
}

class _BookSearchMatch {
  final int chapterId;
  final String chapterTitle;
  final int sortOrder;
  final String content;
  final int fullContentLength;
  final int hitCount;

  const _BookSearchMatch({
    required this.chapterId,
    required this.chapterTitle,
    required this.sortOrder,
    required this.content,
    required this.fullContentLength,
    required this.hitCount,
  });
}

int _intArg(Object? value, int fallback) {
  if (value is int) return value;
  if (value is num) {
    final number = value.toDouble();
    if (!number.isFinite || number.abs() > _maxSafeInteger) return fallback;
    return number.round();
  }
  if (value is String) {
    final parsed = int.tryParse(value);
    if (parsed == null || parsed.abs() > _maxSafeInteger) return fallback;
    return parsed;
  }
  return fallback;
}

String _stringArg(Object? value) => value is String ? value.trim() : '';

int _substringHitCount(String content, String query) {
  if (content.isEmpty || query.isEmpty) return 0;
  final lowerContent = content.toLowerCase();
  final lowerQuery = query.toLowerCase();
  var count = 0;
  var searchFrom = 0;
  while (searchFrom < lowerContent.length) {
    final index = lowerContent.indexOf(lowerQuery, searchFrom);
    if (index < 0) break;
    count++;
    searchFrom = index + lowerQuery.length;
  }
  return count;
}

String _readableBookContent(String content, String format) {
  return format.toLowerCase() == 'epub'
      ? EpubParser.stripHtml(content)
      : content;
}

Future<String> _readableBookContentAsync(
  String content,
  String format,
  AIBookContentService? bookContentService,
) async {
  if (format.toLowerCase() != 'epub') return content;
  if (bookContentService != null) {
    return bookContentService.normalizeEpubDocument(content);
  }
  return (await EpubParser.stripHtmlBatch([content])).single;
}

double _queryPosition(
  String content,
  String query, {
  int? fullContentLength,
}) {
  if (content.isEmpty || query.isEmpty) return 0.0;
  final index = _queryIndex(content, query);
  if (index <= 0) return 0.0;
  final denominator = fullContentLength ?? content.length;
  if (denominator <= 0) return 0.0;
  return (index / denominator).clamp(0.0, 1.0).toDouble();
}

int _queryIndex(String content, String query) {
  if (content.isEmpty || query.isEmpty) return -1;
  return content.toLowerCase().indexOf(query.toLowerCase());
}

String _escapeLikePattern(String value) =>
    value.replaceAll(r'\', r'\\').replaceAll('%', r'\%').replaceAll('_', r'\_');

List<String> _snippets(
  String content,
  String query,
  int contextChars, {
  int maxSnippets = 2,
}) {
  final snippets = <String>[];
  final lowerContent = content.toLowerCase();
  final lowerQuery = query.toLowerCase();
  var searchFrom = 0;
  while (snippets.length < maxSnippets) {
    final index = lowerContent.indexOf(lowerQuery, searchFrom);
    if (index < 0) break;
    snippets.add(_sliceAround(content, index, query.length, contextChars));
    searchFrom = index + math.max(1, query.length);
  }
  return snippets;
}

String _excerpt(String content, String query, int maxChars) {
  if (content.length <= maxChars) return content;
  final lowerContent = content.toLowerCase();
  final index = query.isEmpty ? -1 : lowerContent.indexOf(query.toLowerCase());
  if (index < 0) return content.substring(0, maxChars);
  final halfWindow = (maxChars - query.length).clamp(0, maxChars) ~/ 2;
  var start = math.max(0, index - halfWindow);
  var end = math.min(content.length, start + maxChars);
  if (end - start < maxChars) {
    start = math.max(0, end - maxChars);
  }
  return content.substring(start, end);
}

String _sliceAround(
  String content,
  int index,
  int queryLength,
  int contextChars,
) {
  final start = math.max(0, index - contextChars);
  final end = math.min(content.length, index + queryLength + contextChars);
  final prefix = start > 0 ? '...' : '';
  final suffix = end < content.length ? '...' : '';
  return '$prefix${content.substring(start, end)}$suffix';
}
