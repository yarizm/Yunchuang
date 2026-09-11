import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../database/app_database.dart';
import '../../parsers/epub_parser.dart';
import '../../parsers/pdf_parser.dart';
import '../../parsers/txt_parser.dart';
import '../../providers/database_provider.dart';
import '../../utils/text_file_decoder.dart';

final readerDataLoaderProvider = Provider<ReaderDataSource>((ref) {
  return ReaderDataLoader(ref);
});

class ReaderData {
  final Book book;
  final List<Chapter> chapters;
  final List<String> chapterContents;
  final int initialChapterIndex;
  final ReadingProgressData? savedProgress;

  ReaderData({
    required this.book,
    required this.chapters,
    required this.chapterContents,
    required this.initialChapterIndex,
    this.savedProgress,
  });
}

abstract interface class ReaderDataSource {
  Future<ReaderData?> loadBook(int bookId, {int? targetChapterId});

  Future<Map<int, String>> loadPdfPageTexts(
    Book book,
    List<Chapter> chapters,
    Iterable<int> chapterIndexes, {
    Set<int>? ignoreIndexes,
  });
}

class ReaderDataLoader implements ReaderDataSource {
  final Ref _ref;

  ReaderDataLoader(this._ref);

  @override
  Future<ReaderData?> loadBook(int bookId, {int? targetChapterId}) async {
    final bookDao = _ref.read(bookDaoProvider);
    final progressDao = _ref.read(progressDaoProvider);

    final book = await bookDao.getBookById(bookId);
    if (book == null) return null;

    final chapters = await bookDao.getChapterSummariesForBook(bookId);
    final progress = await progressDao.getProgress(bookId);

    var startIndex = 0;
    if (progress != null) {
      final idx = chapters.indexWhere((c) => c.id == progress.chapterId);
      if (idx >= 0) startIndex = idx;
    }
    // 若来自正文搜索跳转，覆盖到目标章节
    if (targetChapterId != null) {
      final idx = chapters.indexWhere((c) => c.id == targetChapterId);
      if (idx >= 0) startIndex = idx;
    }

    final loaded = await loadChapterContents(
      book,
      chapters,
      initialChapterIndex: startIndex,
    );

    final loadedChapters = loaded.chapters;
    final contents = loaded.contents;
    startIndex = loaded.initialIndex;

    if (loadedChapters.isNotEmpty) {
      await progressDao.ensureProgress(book.id, loadedChapters[startIndex].id);
    }

    return ReaderData(
      book: book,
      chapters: loadedChapters,
      chapterContents: contents,
      initialChapterIndex: startIndex,
      savedProgress: progress,
    );
  }

  /// Load chapter content from the book file.
  ///
  /// Returns the (possibly rebuilt) chapter list, the per-chapter content list
  /// with at least the initial chapter filled, and the index to open at.
  Future<({List<Chapter> chapters, List<String> contents, int initialIndex})>
      loadChapterContents(
    Book book,
    List<Chapter> chapters, {
    int initialChapterIndex = 0,
  }) async {
    if (chapters.isEmpty) {
      return (chapters: chapters, contents: <String>[], initialIndex: 0);
    }
    final file = File(book.filePath);
    if (!await file.exists()) {
      return (
        chapters: chapters,
        contents: List.filled(chapters.length, '文件不存在: ${book.filePath}'),
        initialIndex: initialChapterIndex,
      );
    }

    if (book.format == 'txt') {
      final cached = await _ref
          .read(bookDaoProvider)
          .getChapterContent(chapters[initialChapterIndex].id);
      if (cached != null) {
        final contents = List.filled(chapters.length, '');
        contents[initialChapterIndex] = cached;
        return (
          chapters: chapters,
          contents: contents,
          initialIndex: initialChapterIndex,
        );
      }
      final text = await TextFileDecoder.readAsString(
        book.filePath,
        normalizeToUtf8: true,
      );
      final parsedChapters =
          await Isolate.run(() => TxtParser.parseChapters(text));
      return rebuildChapters(book.id, parsedChapters);
    } else if (book.format == 'epub') {
      final cached = await _ref
          .read(bookDaoProvider)
          .getChapterContent(chapters[initialChapterIndex].id);
      if (cached != null) {
        final contents = List.filled(chapters.length, '');
        contents[initialChapterIndex] = cached;
        return (
          chapters: chapters,
          contents: contents,
          initialIndex: initialChapterIndex,
        );
      }
      final parsed = await Isolate.run(
        () => EpubParser.parseFile(book.filePath),
      );
      return rebuildChapters(book.id, parsed.chapters);
    } else if (book.format == 'pdf') {
      final contents = List.filled(chapters.length, '');
      if (initialChapterIndex >= 0 && initialChapterIndex < contents.length) {
        final loaded = await loadPdfPageTexts(
          book,
          chapters,
          [
            initialChapterIndex,
            initialChapterIndex - 1,
            initialChapterIndex + 1
          ],
        );
        for (final entry in loaded.entries) {
          contents[entry.key] = entry.value;
        }
      }
      return (
        chapters: chapters,
        contents: contents,
        initialIndex: initialChapterIndex,
      );
    }

    return (
      chapters: chapters,
      contents: List.filled(chapters.length, '暂不支持此格式的阅读'),
      initialIndex: initialChapterIndex,
    );
  }

  /// Re-derives chapters for a migrated book (whose stored content was empty)
  /// by replacing them with freshly parsed chapters, then returns the reloaded
  /// chapter list with the first chapter's content filled.
  Future<({List<Chapter> chapters, List<String> contents, int initialIndex})>
      rebuildChapters(int bookId, List<ParsedChapter> parsedChapters) async {
    final dao = _ref.read(bookDaoProvider);
    await dao.replaceChapters(
      bookId,
      parsedChapters
          .map((chapter) => (int id) => ChaptersCompanion(
                bookId: Value(id),
                title: Value(chapter.title),
                content: Value(chapter.content),
                contentIndex: Value(chapter.sortOrder),
                sortOrder: Value(chapter.sortOrder),
              ))
          .toList(),
    );
    final chapters = await dao.getChapterSummariesForBook(bookId);
    final contents = List.filled(chapters.length, '');
    if (chapters.isNotEmpty) {
      contents[0] = await dao.getChapterContent(chapters[0].id) ?? '';
    }
    return (chapters: chapters, contents: contents, initialIndex: 0);
  }

  @override
  Future<Map<int, String>> loadPdfPageTexts(
    Book book,
    List<Chapter> chapters,
    Iterable<int> chapterIndexes, {
    Set<int>? ignoreIndexes,
  }) async {
    final indexes = chapterIndexes
        .where((index) =>
            index >= 0 &&
            index < chapters.length &&
            (ignoreIndexes == null || !ignoreIndexes.contains(index)))
        .toSet()
        .toList()
      ..sort();
    if (indexes.isEmpty) return const {};

    final dao = _ref.read(bookDaoProvider);
    final result = <int, String>{};
    final missing = <int>[];
    for (final index in indexes) {
      final cached = await dao.getChapterContent(chapters[index].id);
      if (cached != null) {
        result[index] = cached;
      } else {
        missing.add(index);
      }
    }

    if (missing.isNotEmpty) {
      final pageIndexes = {
        for (final index in missing) chapters[index].contentIndex,
      };
      final filePath = book.filePath;
      final extracted = await Isolate.run(
        () => PdfParser.extractPageTexts(filePath, pageIndexes),
      );
      final cache = <int, String>{};
      for (final index in missing) {
        final content = extracted[chapters[index].contentIndex] ?? '';
        result[index] = content;
        cache[chapters[index].id] = content;
      }
      if (cache.isNotEmpty) {
        await dao.cacheChapterContents(cache);
      }
    }

    return result;
  }
}
