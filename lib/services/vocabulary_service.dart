import 'dart:isolate';

import 'package:csv/csv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../database/app_database.dart';
import '../database/daos/book_dao.dart';
import '../database/daos/vocabulary_dao.dart';
import '../models/reader_locator.dart';
import '../providers/ai/ai_book_content_service.dart';
import '../providers/database_provider.dart';

final vocabularyServiceProvider = Provider<VocabularyService>((ref) {
  final database = ref.watch(databaseProvider);
  final bookDao = BookDao(database);
  return VocabularyService(
    ref.watch(vocabularyDaoProvider),
    AIBookContentService(bookDao),
  );
});

final allVocabularyEntriesProvider =
    StreamProvider<List<VocabularyEntryDetails>>((ref) {
  return ref.watch(vocabularyDaoProvider).watchAllDetails();
});

class VocabularyOccurrence {
  final int chapterId;
  final String chapterTitle;
  final int positionStart;
  final int positionEnd;
  final String snippet;
  final ReaderLocator locator;

  const VocabularyOccurrence({
    required this.chapterId,
    required this.chapterTitle,
    required this.positionStart,
    required this.positionEnd,
    required this.snippet,
    required this.locator,
  });
}

class VocabularyLookupResult {
  final int totalCount;
  final List<VocabularyOccurrence> occurrences;

  const VocabularyLookupResult({
    required this.totalCount,
    required this.occurrences,
  });
}

class VocabularyService {
  static const maxTermLength = 200;
  static const defaultBackgroundSearchThresholdChars = 200000;

  final VocabularyDao _dao;
  final AIBookContentService _bookContentService;
  final int backgroundSearchThresholdChars;

  VocabularyService(
    this._dao,
    this._bookContentService, {
    this.backgroundSearchThresholdChars = defaultBackgroundSearchThresholdChars,
  });

  Future<VocabularyEntry?> findForBook(int bookId, String term) {
    return _dao.findForBook(bookId, term);
  }

  Future<VocabularyEntry> save({
    required int bookId,
    required int? chapterId,
    required String term,
    String? definition,
    String? contextText,
    int? positionStart,
    int? positionEnd,
  }) {
    return _dao.save(
      bookId: bookId,
      chapterId: chapterId,
      term: term,
      definition: definition,
      contextText: contextText,
      positionStart: positionStart,
      positionEnd: positionEnd,
    );
  }

  Future<void> updateDefinition(int id, String? definition) {
    return _dao.updateDefinition(id, definition);
  }

  Future<int> deleteEntry(int id) => _dao.deleteEntry(id);

  Future<VocabularyLookupResult> findOccurrences({
    required int bookId,
    required String term,
    int limit = 30,
    int contextChars = 60,
    void Function(String status)? onProgress,
  }) async {
    final query = term.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (query.isEmpty || query.length > maxTermLength) {
      throw ArgumentError.value(term, 'term', '词条长度必须为 1 到 200 个字符');
    }
    final normalizedLimit = limit.clamp(1, 100).toInt();
    final normalizedContextChars = contextChars.clamp(20, 200).toInt();
    final chapters = await _bookContentService.loadAllChapters(
      bookId,
      onProgress: onProgress,
    );
    final searchableChapters = chapters
        .map(
          (chapter) => _VocabularySearchChapter(
            id: chapter.id,
            title: chapter.title,
            content: chapter.content ?? '',
          ),
        )
        .toList(growable: false);
    final request = _VocabularyScanRequest(
      chapters: searchableChapters,
      query: query,
      limit: normalizedLimit,
      contextChars: normalizedContextChars,
    );
    final contentChars = searchableChapters.fold<int>(
      0,
      (total, chapter) => total + chapter.content.length,
    );
    onProgress?.call('正在搜索当前书…');
    final scan = contentChars >= backgroundSearchThresholdChars
        ? await Isolate.run(() => _scanVocabularyOccurrences(request))
        : _scanVocabularyOccurrences(request);
    final occurrences = scan.hits
        .map(
          (hit) => VocabularyOccurrence(
            chapterId: hit.chapterId,
            chapterTitle: hit.chapterTitle,
            positionStart: hit.positionStart,
            positionEnd: hit.positionEnd,
            snippet: hit.snippet,
            locator: ReaderLocator(
              bookId: bookId,
              chapterId: hit.chapterId,
              textOffsetStart: hit.positionStart,
              textOffsetEnd: hit.positionEnd,
              query: query,
              selectedText: hit.selectedText,
            ),
          ),
        )
        .toList(growable: false);
    return VocabularyLookupResult(
      totalCount: scan.totalCount,
      occurrences: List.unmodifiable(occurrences),
    );
  }

  String exportMarkdown(List<VocabularyEntryDetails> entries) {
    final buffer = StringBuffer('# 生词本\n\n');
    for (final details in entries) {
      final entry = details.entry;
      buffer
        ..writeln('## ${entry.term}')
        ..writeln()
        ..writeln(entry.definition?.trim().isNotEmpty == true
            ? entry.definition!.trim()
            : '_暂无释义_')
        ..writeln()
        ..writeln(
          '- 来源：${details.bookTitle}'
          '${details.chapterTitle == null ? '' : ' / ${details.chapterTitle}'}',
        );
      final context = entry.contextText?.trim();
      if (context != null && context.isNotEmpty) {
        buffer
          ..writeln('- 原句：$context')
          ..writeln();
      } else {
        buffer.writeln();
      }
    }
    return buffer.toString();
  }

  String exportCsv(List<VocabularyEntryDetails> entries) {
    final rows = <List<dynamic>>[
      ['词条', '释义', '书籍', '章节', '原句', '创建时间', '更新时间'],
      for (final details in entries)
        [
          details.entry.term,
          details.entry.definition ?? '',
          details.bookTitle,
          details.chapterTitle ?? '',
          details.entry.contextText ?? '',
          details.entry.createdAt.toUtc().toIso8601String(),
          details.entry.updatedAt.toUtc().toIso8601String(),
        ],
    ];
    return const ListToCsvConverter().convert(rows);
  }
}

class _VocabularySearchChapter {
  final int id;
  final String title;
  final String content;

  const _VocabularySearchChapter({
    required this.id,
    required this.title,
    required this.content,
  });
}

class _VocabularyScanRequest {
  final List<_VocabularySearchChapter> chapters;
  final String query;
  final int limit;
  final int contextChars;

  const _VocabularyScanRequest({
    required this.chapters,
    required this.query,
    required this.limit,
    required this.contextChars,
  });
}

class _VocabularyScanHit {
  final int chapterId;
  final String chapterTitle;
  final int positionStart;
  final int positionEnd;
  final String selectedText;
  final String snippet;

  const _VocabularyScanHit({
    required this.chapterId,
    required this.chapterTitle,
    required this.positionStart,
    required this.positionEnd,
    required this.selectedText,
    required this.snippet,
  });
}

class _VocabularyScanResult {
  final int totalCount;
  final List<_VocabularyScanHit> hits;

  const _VocabularyScanResult({
    required this.totalCount,
    required this.hits,
  });
}

_VocabularyScanResult _scanVocabularyOccurrences(
  _VocabularyScanRequest request,
) {
  final hits = <_VocabularyScanHit>[];
  var totalCount = 0;
  final pattern = RegExp(
    RegExp.escape(request.query),
    caseSensitive: false,
  );
  for (final chapter in request.chapters) {
    if (chapter.content.isEmpty) continue;
    for (final match in pattern.allMatches(chapter.content)) {
      totalCount++;
      if (hits.length >= request.limit) continue;
      hits.add(
        _VocabularyScanHit(
          chapterId: chapter.id,
          chapterTitle: chapter.title,
          positionStart: match.start,
          positionEnd: match.end,
          selectedText: chapter.content.substring(match.start, match.end),
          snippet: _vocabularySnippetAround(
            chapter.content,
            match.start,
            match.end - match.start,
            request.contextChars,
          ),
        ),
      );
    }
  }
  return _VocabularyScanResult(
    totalCount: totalCount,
    hits: List.unmodifiable(hits),
  );
}

String _vocabularySnippetAround(
  String content,
  int index,
  int queryLength,
  int contextChars,
) {
  final start = (index - contextChars).clamp(0, content.length).toInt();
  final end =
      (index + queryLength + contextChars).clamp(0, content.length).toInt();
  final snippet =
      content.substring(start, end).replaceAll(RegExp(r'\s+'), ' ').trim();
  return '${start > 0 ? '…' : ''}$snippet${end < content.length ? '…' : ''}';
}
