import 'dart:io';
import 'dart:isolate';

import 'package:drift/drift.dart' show Value;

import '../../database/app_database.dart';
import '../../database/daos/book_dao.dart';
import '../../parsers/epub_parser.dart';
import '../../parsers/pdf_parser.dart';
import 'ai_provider.dart';

class AIBookContentService {
  static const pdfExtractionBatchSize = 80;
  static const maxCachedEpubCodeUnits = 8 * 1024 * 1024;

  final BookDao bookDao;
  final Future<List<String>> Function(Iterable<String>) _epubNormalizer;
  List<String>? _cachedEpubSources;
  List<String>? _cachedReadableEpubContents;
  String? _cachedSingleEpubSource;
  String? _cachedSingleReadableEpubContent;

  AIBookContentService(
    this.bookDao, {
    Future<List<String>> Function(Iterable<String>)? epubNormalizer,
  }) : _epubNormalizer = epubNormalizer ??
            ((documents) => EpubParser.stripHtmlBatch(documents));

  Future<int> pendingPdfPageCount(int bookId) async {
    final book = await bookDao.getBookById(bookId);
    if (book == null) {
      throw const AIBookContentException('当前书籍不存在，无法准备正文。');
    }
    if (book.format.toLowerCase() != 'pdf') return 0;
    return bookDao.countMissingChapterContent(bookId);
  }

  Future<List<Chapter>> loadAllChapters(
    int bookId, {
    AIRequestCancellation? cancellation,
    void Function(String status)? onProgress,
  }) async {
    await ensureAllChapterContent(
      bookId,
      cancellation: cancellation,
      onProgress: onProgress,
    );
    cancellation?.throwIfCancelled();
    final book = await bookDao.getBookById(bookId);
    if (book == null) {
      throw const AIBookContentException('当前书籍不存在，无法准备正文。');
    }
    final chapters = await bookDao.getChaptersForBook(bookId);
    if (book.format.toLowerCase() != 'epub') return chapters;
    final readableContents = await normalizeEpubDocuments(
      chapters.map((chapter) => chapter.content ?? ''),
    );
    cancellation?.throwIfCancelled();
    return List<Chapter>.generate(
      chapters.length,
      (index) => chapters[index].copyWith(
        content: Value(readableContents[index]),
      ),
      growable: false,
    );
  }

  Future<List<String>> normalizeEpubDocuments(
    Iterable<String> htmlDocuments,
  ) async {
    final sources = List<String>.unmodifiable(htmlDocuments);
    final cachedSources = _cachedEpubSources;
    final cachedContents = _cachedReadableEpubContents;
    if (cachedSources != null &&
        cachedContents != null &&
        _sameDocuments(cachedSources, sources)) {
      return cachedContents;
    }

    final readable = List<String>.unmodifiable(
      await _epubNormalizer(sources),
    );
    if (readable.length != sources.length) {
      throw StateError('EPUB 正文清洗结果数量与输入章节数量不一致。');
    }
    final cacheWeight = _documentChars(sources) + _documentChars(readable);
    if (cacheWeight <= maxCachedEpubCodeUnits) {
      _cachedEpubSources = sources;
      _cachedReadableEpubContents = readable;
    } else {
      _cachedEpubSources = null;
      _cachedReadableEpubContents = null;
    }
    return readable;
  }

  Future<String> normalizeEpubDocument(String htmlDocument) async {
    final cachedSource = _cachedSingleEpubSource;
    final cachedContent = _cachedSingleReadableEpubContent;
    if (cachedSource != null &&
        cachedContent != null &&
        (identical(cachedSource, htmlDocument) ||
            cachedSource == htmlDocument)) {
      return cachedContent;
    }

    final readable = await _epubNormalizer([htmlDocument]);
    if (readable.length != 1) {
      throw StateError('EPUB 正文清洗结果数量与输入章节数量不一致。');
    }
    final content = readable.single;
    if (htmlDocument.length + content.length <= maxCachedEpubCodeUnits) {
      _cachedSingleEpubSource = htmlDocument;
      _cachedSingleReadableEpubContent = content;
    } else {
      _cachedSingleEpubSource = null;
      _cachedSingleReadableEpubContent = null;
    }
    return content;
  }

  bool _sameDocuments(List<String> left, List<String> right) {
    if (left.length != right.length) return false;
    for (var index = 0; index < left.length; index++) {
      if (!identical(left[index], right[index]) &&
          left[index] != right[index]) {
        return false;
      }
    }
    return true;
  }

  int _documentChars(List<String> documents) {
    return documents.fold<int>(0, (total, item) => total + item.length);
  }

  Future<void> ensureAllChapterContent(
    int bookId, {
    AIRequestCancellation? cancellation,
    void Function(String status)? onProgress,
  }) async {
    cancellation?.throwIfCancelled();
    final book = await bookDao.getBookById(bookId);
    if (book == null) {
      throw const AIBookContentException('当前书籍不存在，无法准备正文。');
    }
    if (book.format.toLowerCase() != 'pdf') return;
    final missing =
        await bookDao.getMissingContentChapterSummariesForBook(bookId);
    await _extractPdfChapters(
      book,
      missing,
      cancellation: cancellation,
      onProgress: onProgress,
    );
  }

  Future<void> ensureChapterContent(
    int bookId,
    int chapterId, {
    AIRequestCancellation? cancellation,
    void Function(String status)? onProgress,
  }) async {
    cancellation?.throwIfCancelled();
    final book = await bookDao.getBookById(bookId);
    if (book == null) {
      throw const AIBookContentException('当前书籍不存在，无法准备正文。');
    }
    if (book.format.toLowerCase() != 'pdf') return;

    if (await bookDao.getChapterContent(chapterId) != null) return;
    final target = await bookDao.getChapterSummaryForBook(bookId, chapterId);
    if (target == null) return;
    await _extractPdfChapters(
      book,
      [target],
      cancellation: cancellation,
      onProgress: onProgress,
    );
  }

  Future<void> ensureChapterContents(
    int bookId,
    Iterable<int> chapterIds, {
    AIRequestCancellation? cancellation,
    void Function(String status)? onProgress,
  }) async {
    cancellation?.throwIfCancelled();
    final requestedIds = chapterIds.where((id) => id > 0).toSet();
    if (requestedIds.isEmpty) return;

    final book = await bookDao.getBookById(bookId);
    if (book == null) {
      throw const AIBookContentException('当前书籍不存在，无法准备正文。');
    }
    if (book.format.toLowerCase() != 'pdf') return;

    final missing =
        await bookDao.getMissingContentChapterSummariesForBook(bookId);
    final requested = missing
        .where((chapter) => requestedIds.contains(chapter.id))
        .toList(growable: false);
    await _extractPdfChapters(
      book,
      requested,
      cancellation: cancellation,
      onProgress: onProgress,
    );
  }

  Future<void> _extractPdfChapters(
    Book book,
    List<Chapter> chapters, {
    AIRequestCancellation? cancellation,
    void Function(String status)? onProgress,
  }) async {
    if (chapters.isEmpty) return;
    final file = File(book.filePath);
    if (!await file.exists()) {
      throw const AIBookContentException('PDF 原文件不存在，无法准备正文。');
    }

    for (var offset = 0;
        offset < chapters.length;
        offset += pdfExtractionBatchSize) {
      cancellation?.throwIfCancelled();
      final end =
          (offset + pdfExtractionBatchSize).clamp(0, chapters.length).toInt();
      final batch = chapters.sublist(offset, end);
      onProgress?.call('正在准备 PDF 正文（$offset/${chapters.length} 页）...');
      final filePath = file.path;
      final pageIndexes =
          batch.map((chapter) => chapter.contentIndex).toList(growable: false);
      late final Map<int, String> extracted;
      try {
        extracted = await Isolate.run(
          () => PdfParser.extractPageTexts(filePath, pageIndexes),
        );
      } catch (_) {
        throw const AIBookContentException(
          'PDF 正文提取失败，请确认文件未损坏且包含可提取文本。',
        );
      }
      cancellation?.throwIfCancelled();
      await bookDao.cacheChapterContents({
        for (final chapter in batch)
          chapter.id: extracted[chapter.contentIndex] ?? '',
      });
      onProgress?.call('正在准备 PDF 正文（$end/${chapters.length} 页）...');
    }
  }
}

class AIBookContentException implements Exception {
  final String message;

  const AIBookContentException(this.message);

  @override
  String toString() => message;
}
