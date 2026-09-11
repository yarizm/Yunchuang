import '../database/app_database.dart';
import '../models/reader_locator.dart';

class SearchResult {
  final String type; // 'book' | 'note' | 'chapter'
  final int id;
  final String title;
  final String? subtitle;
  final String? highlight;

  // chapter-only fields
  final int? bookId;
  final int? chapterId;
  final String? bookTitle;
  final String? chapterTitle;
  final ReaderLocator? locator;

  SearchResult({
    required this.type,
    required this.id,
    required this.title,
    this.subtitle,
    this.highlight,
    this.bookId,
    this.chapterId,
    this.bookTitle,
    this.chapterTitle,
    this.locator,
  });
}

class SearchService {
  final AppDatabase _db;

  SearchService(this._db);

  Future<List<SearchResult>> search(String query) async {
    if (query.trim().isEmpty) return [];

    final plan = SearchPlan.forQuery(query);
    if (plan.isEmpty) return [];

    final groups = await Future.wait([
      _searchBooks(plan),
      _searchNotes(plan),
      _searchChapters(plan),
    ]);
    return groups.expand((group) => group).toList();
  }

  Future<List<SearchResult>> _searchBooks(SearchPlan plan) async {
    try {
      final books = plan.substring
          ? await _db.searchBooksLike(plan.terms)
          : await _db.searchBooks(plan.ftsQuery);
      return books
          .map((b) => SearchResult(
                type: 'book',
                id: b.id,
                title: b.title,
                subtitle: b.author,
              ))
          .toList();
    } catch (error) {
      throw SearchException('书籍索引查询失败', error);
    }
  }

  Future<List<SearchResult>> _searchNotes(SearchPlan plan) async {
    final rawQuery = plan.rawQuery;
    try {
      final notes = plan.substring
          ? await _db.searchNotesLike(plan.terms)
          : await _db.searchNotes(plan.ftsQuery);
      return notes
          .map((n) => SearchResult(
                type: 'note',
                id: n.id,
                title: n.selectedText ?? n.content ?? '',
                subtitle: '笔记',
                highlight: n.content,
                bookId: n.bookId,
                chapterId: n.chapterId,
                locator: n.chapterId == null && n.pageNumber == null
                    ? null
                    : ReaderLocator(
                        bookId: n.bookId,
                        chapterId: n.chapterId,
                        pageNumber: n.pageNumber,
                        textOffsetStart: n.positionStart,
                        textOffsetEnd: n.positionEnd,
                        query: rawQuery,
                        selectedText: n.selectedText,
                      ),
              ))
          .toList();
    } catch (error) {
      throw SearchException('笔记索引查询失败', error);
    }
  }

  Future<List<SearchResult>> _searchChapters(SearchPlan plan) async {
    final rawQuery = plan.rawQuery;
    try {
      final chapters = plan.substring
          ? await _db.searchChaptersLike(plan.terms)
          : await _db.searchChapters(plan.ftsQuery);
      return chapters
          .map((c) => SearchResult(
                type: 'chapter',
                id: c.chapterId,
                title: c.chapterTitle,
                subtitle: c.bookTitle,
                highlight: c.snippet,
                bookId: c.bookId,
                chapterId: c.chapterId,
                bookTitle: c.bookTitle,
                chapterTitle: c.chapterTitle,
                locator: ReaderLocator(
                  bookId: c.bookId,
                  chapterId: c.chapterId,
                  query: rawQuery,
                ),
              ))
          .toList();
    } catch (error) {
      throw SearchException('正文索引查询失败', error);
    }
  }
}

/// Decides which of the two search backends a query has to use.
///
/// FTS5's `unicode61` tokenizer treats Han, Kana and Hangul as token
/// characters, so an unbroken run of them is indexed as a single token:
/// searching `计算机` cannot match `深入理解计算机系统` no matter how the MATCH
/// expression is written. Queries containing such scripts are therefore routed
/// to the substring (`LIKE`) methods on [AppDatabase]; everything else keeps
/// using the indexed, bm25-ranked FTS path.
class SearchPlan {
  /// The user's query, trimmed. Carried into [ReaderLocator] so the reader can
  /// re-find the hit in the original text.
  final String rawQuery;

  /// Whitespace-separated terms; every term must match (AND semantics).
  final List<String> terms;

  /// Whether the substring backend must be used instead of FTS.
  final bool substring;

  const SearchPlan({
    required this.rawQuery,
    required this.terms,
    required this.substring,
  });

  factory SearchPlan.forQuery(String query) {
    final rawQuery = query.trim();
    final terms = rawQuery
        .split(RegExp(r'\s+'))
        .where((term) => term.isNotEmpty)
        .toList(growable: false);
    return SearchPlan(
      rawQuery: rawQuery,
      terms: terms,
      substring: unsegmentableScript.hasMatch(rawQuery),
    );
  }

  bool get isEmpty => terms.isEmpty;

  /// The query rewritten as an FTS5 MATCH expression. Each term is phrase
  /// quoted so punctuation and FTS operators are taken literally.
  String get ftsQuery =>
      terms.map((term) => '"${term.replaceAll('"', '""')}"').join(' AND ');

  /// Scripts written without word separators, which `unicode61` collapses into
  /// one token per run: CJK ideographs (incl. extensions and compatibility
  /// forms), Japanese kana, and Hangul syllables.
  static final RegExp unsegmentableScript = RegExp(
    r'[\u3040-\u30FF]' // Hiragana, Katakana
    r'|[\u3400-\u4DBF]' // CJK Unified Ideographs Extension A
    r'|[\u4E00-\u9FFF]' // CJK Unified Ideographs
    r'|[\uAC00-\uD7AF]' // Hangul Syllables
    r'|[\uF900-\uFAFF]' // CJK Compatibility Ideographs
    r'|[\u{20000}-\u{2FA1F}]', // CJK Extension B and beyond
    unicode: true,
  );
}

class SearchException implements Exception {
  final String message;
  final Object cause;

  const SearchException(this.message, this.cause);

  @override
  String toString() => message;
}
