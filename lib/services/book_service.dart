import 'dart:io';
import 'dart:isolate';
import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../database/app_database.dart';
import '../database/daos/book_dao.dart';
import '../models/book_reading_status.dart';
import '../parsers/txt_parser.dart';
import '../parsers/epub_parser.dart';
import '../parsers/pdf_parser.dart';
import '../utils/text_file_decoder.dart';
import '../utils/app_data_directory.dart';

typedef BookAppDirectoryProvider = Future<Directory> Function();

enum DuplicateBookAction { skip, keepCopy, replace }

class BookImportAnalysis {
  final String sourcePath;
  final String fileHash;
  final int fileSize;
  final Book? existingBook;

  const BookImportAnalysis({
    required this.sourcePath,
    required this.fileHash,
    required this.fileSize,
    required this.existingBook,
  });

  bool get isDuplicate => existingBook != null;
}

class _PreparedImport {
  final String storedPath;
  final String? coverPath;
  final String format;
  final int storedFileSize;
  final ParsedMetadata metadata;
  final List<ParsedChapter> chapters;

  const _PreparedImport({
    required this.storedPath,
    required this.coverPath,
    required this.format,
    required this.storedFileSize,
    required this.metadata,
    required this.chapters,
  });
}

/// Service for importing, listing, and deleting books.
///
/// Handles file copying to app storage, parsing (TXT/EPUB/PDF),
/// and database operations via [BookDao].
///
/// FTS5 index updates are handled automatically by database triggers
/// (books_ai, books_ad, books_au) — no manual FTS insert is needed here.
/// 支持导入的书籍扩展名，不带点，小写。
///
/// 文件选择器的过滤、目录扫描、导入前校验、桌面拖拽四处都用它。
/// 此前这个列表在三个地方各写了一遍，加第四种格式要改四处。
const supportedBookExtensions = {'txt', 'epub', 'pdf'};

class BookService {
  final BookDao _bookDao;
  final BookAppDirectoryProvider _appDirectoryProvider;
  static const _uuid = Uuid();

  BookService(
    this._bookDao, {
    BookAppDirectoryProvider? appDirectoryProvider,
  }) : _appDirectoryProvider =
            appDirectoryProvider ?? appDataDirectory;

  Future<List<String>> findSupportedBooksInDirectory(
    String directoryPath,
  ) {
    return Isolate.run(() => _findSupportedBookFiles(directoryPath));
  }

  /// 把拖进来的路径解析成可导入的书籍文件列表。
  ///
  /// 拖拽给的是原始路径，可能混着文件夹、不支持的格式、以及已经不存在的
  /// 条目（拖到一半源文件被删）。文件夹递归展开，其余按扩展名过滤。
  /// 结果去重并排序，多次拖同一批文件不会重复导入。
  Future<List<String>> resolveDroppedPaths(List<String> paths) async {
    final resolved = <String>{};
    for (final path in paths) {
      if (Directory(path).existsSync()) {
        resolved.addAll(await findSupportedBooksInDirectory(path));
        continue;
      }
      if (!File(path).existsSync()) continue;
      final ext = p.extension(path).toLowerCase().replaceFirst('.', '');
      if (supportedBookExtensions.contains(ext)) resolved.add(path);
    }
    final list = resolved.toList()..sort();
    return list;
  }

  Future<BookImportAnalysis> analyzeImport(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) {
      throw FileSystemException('文件不存在', filePath);
    }

    final ext = p.extension(filePath).toLowerCase().replaceFirst('.', '');
    if (!supportedBookExtensions.contains(ext)) {
      throw ArgumentError('不支持的文件格式: $ext');
    }
    final fileSize = await file.length();
    final fileHash = await Isolate.run(() => _hashFile(filePath));
    var existing = await _bookDao.getBookByFileHash(fileHash);

    if (existing == null) {
      final legacyCandidates = await _bookDao.getBooksByFileSize(fileSize);
      for (final candidate in legacyCandidates) {
        if (candidate.fileHash != null) continue;
        final storedFile = File(candidate.filePath);
        if (!await storedFile.exists()) continue;
        final storedHash =
            await Isolate.run(() => _hashFile(candidate.filePath));
        await _bookDao.updateBookFileHash(candidate.id, storedHash);
        if (storedHash == fileHash) {
          existing = (await _bookDao.getBookById(candidate.id))!;
          break;
        }
      }
    }

    return BookImportAnalysis(
      sourcePath: filePath,
      fileHash: fileHash,
      fileSize: fileSize,
      existingBook: existing,
    );
  }

  Future<Book> importBook(
    String filePath, {
    BookImportAnalysis? analysis,
    DuplicateBookAction duplicateAction = DuplicateBookAction.keepCopy,
  }) async {
    final resolved = analysis ?? await analyzeImport(filePath);
    final existing = resolved.existingBook;
    if (existing != null && duplicateAction == DuplicateBookAction.skip) {
      return existing;
    }

    final replacing =
        existing != null && duplicateAction == DuplicateBookAction.replace;
    final prepared = await _prepareImport(
      resolved,
      persistCover: !replacing,
    );
    try {
      final chapterFactories = _chapterFactories(prepared);
      if (replacing) {
        await _bookDao.replaceBookContent(
          existing.id,
          BooksCompanion(
            filePath: Value(prepared.storedPath),
            format: Value(prepared.format),
            fileSize: Value(prepared.storedFileSize),
            fileHash: Value(resolved.fileHash),
            updatedAt: Value(DateTime.now()),
          ),
          chapterFactories,
        );
        await _deleteFileBestEffort(existing.filePath);
        return (await _bookDao.getBookById(existing.id))!;
      }

      final bookId = await _bookDao.insertBookWithChapters(
        BooksCompanion(
          title: Value(prepared.metadata.title),
          author: Value(prepared.metadata.author),
          description: Value(prepared.metadata.description),
          filePath: Value(prepared.storedPath),
          coverPath: Value(prepared.coverPath),
          format: Value(prepared.format),
          fileSize: Value(prepared.storedFileSize),
          fileHash: Value(resolved.fileHash),
        ),
        chapterFactories,
      );
      return (await _bookDao.getBookById(bookId))!;
    } catch (_) {
      await _deleteFileBestEffort(prepared.storedPath);
      if (prepared.coverPath != null) {
        await _deleteFileBestEffort(prepared.coverPath!);
      }
      rethrow;
    }
  }

  Future<_PreparedImport> _prepareImport(
    BookImportAnalysis analysis, {
    required bool persistCover,
  }) async {
    final file = File(analysis.sourcePath);
    final ext =
        p.extension(analysis.sourcePath).toLowerCase().replaceFirst('.', '');
    final appDir = await _appDirectoryProvider();
    final booksDir = Directory(p.join(appDir.path, 'books'));
    if (!await booksDir.exists()) {
      await booksDir.create(recursive: true);
    }

    final fileName =
        '${_uuid.v4()}${p.extension(analysis.sourcePath).toLowerCase()}';
    final destPath = p.join(booksDir.path, fileName);
    await file.copy(destPath);

    String? coverPath;
    try {
      ParsedMetadata metadata;
      List<ParsedChapter> parsedChapters;
      List<int>? coverBytes;

      switch (ext) {
        case 'epub':
          final result = await Isolate.run(
            () => EpubParser.parseFile(destPath),
          );
          metadata = result.metadata;
          parsedChapters = result.chapters;
          coverBytes = result.coverBytes;
          break;
        case 'pdf':
          final result = await Isolate.run(
            () => PdfParser.parseFile(destPath, extractText: false),
          );
          metadata = result.metadata;
          parsedChapters = result.chapters;
          break;
        case 'txt':
        default:
          final content = await TextFileDecoder.readAsString(
            destPath,
            normalizeToUtf8: true,
          );
          final result = await Isolate.run(() {
            return (
              metadata: TxtParser.parseMetadata(content),
              chapters: TxtParser.parseChapters(content),
            );
          });
          metadata = result.metadata;
          parsedChapters = result.chapters;
          break;
      }

      if (persistCover && coverBytes != null && coverBytes.isNotEmpty) {
        final coversDir = Directory(p.join(appDir.path, 'covers'));
        await coversDir.create(recursive: true);
        coverPath = p.join(coversDir.path, '${_uuid.v4()}_cover.jpg');
        await File(coverPath).writeAsBytes(coverBytes, flush: true);
      }

      return _PreparedImport(
        storedPath: destPath,
        coverPath: coverPath,
        format: ext,
        storedFileSize: await File(destPath).length(),
        metadata: metadata,
        chapters: parsedChapters,
      );
    } catch (_) {
      await _deleteFileBestEffort(destPath);
      if (coverPath != null) {
        await _deleteFileBestEffort(coverPath);
      }
      rethrow;
    }
  }

  List<ChaptersCompanion Function(int bookId)> _chapterFactories(
    _PreparedImport prepared,
  ) {
    return prepared.chapters
        .map((chapter) => (int bookId) => ChaptersCompanion(
              bookId: Value(bookId),
              title: Value(chapter.title),
              content: prepared.format == 'pdf'
                  ? const Value.absent()
                  : Value(chapter.content),
              contentIndex: Value(chapter.sortOrder),
              sortOrder: Value(chapter.sortOrder),
            ))
        .toList(growable: false);
  }

  Future<void> _deleteFileBestEffort(String path) async {
    try {
      final file = File(path);
      if (await file.exists()) await file.delete();
    } on FileSystemException {
      // Database state remains authoritative when external storage changed.
    }
  }

  /// Update book metadata (title, author, cover)
  Future<void> updateBookMetadata(
    int bookId, {
    String? title,
    String? author,
    String? coverPath,
    required String? seriesName,
    required double? seriesIndex,
  }) async {
    final existing = await _bookDao.getBookById(bookId);
    if (existing == null) return;
    var storedCoverPath = coverPath;
    String? oldOwnedCover;
    if (coverPath != null && coverPath != existing.coverPath) {
      final appDir = await _appDirectoryProvider();
      final coversDir = Directory(p.join(appDir.path, 'covers'));
      await coversDir.create(recursive: true);
      final source = File(coverPath);
      if (await source.exists()) {
        storedCoverPath = p.join(
          coversDir.path,
          '${_uuid.v4()}${p.extension(coverPath).toLowerCase()}',
        );
        await source.copy(storedCoverPath);
      }
      if (existing.coverPath != null &&
          p.isWithin(coversDir.path, existing.coverPath!)) {
        oldOwnedCover = existing.coverPath;
      }
    }
    await _bookDao.updateBook(existing.toCompanion(false).copyWith(
          title: title != null ? Value(title) : const Value.absent(),
          author: author != null ? Value(author) : const Value.absent(),
          coverPath: storedCoverPath != null
              ? Value(storedCoverPath)
              : const Value.absent(),
          seriesName: Value(seriesName),
          seriesIndex: Value(seriesName == null ? null : seriesIndex),
        ));
    if (oldOwnedCover != null) {
      final oldFile = File(oldOwnedCover);
      if (await oldFile.exists()) await oldFile.delete();
    }
  }

  /// Get all books from the database.
  Future<List<Book>> getAllBooks() => _bookDao.getAllBooks();

  /// Get books by IDs as a map (id -> Book).
  Future<Map<int, Book>> getBooksByIds(List<int> ids) =>
      _bookDao.getBooksByIds(ids);

  Future<void> updateBookReadingStatus(
    int bookId,
    BookReadingStatus? status,
  ) async {
    final updated = await _bookDao.updateBookReadingStatus(
      bookId,
      status?.storageValue,
    );
    if (updated == 0) {
      throw StateError('书籍不存在');
    }
  }

  Future<void> updateBooksReadingStatus(
    Set<int> bookIds,
    BookReadingStatus? status,
  ) async {
    final updated = await _bookDao.updateBooksReadingStatus(
      bookIds,
      status?.storageValue,
    );
    if (updated != bookIds.length) {
      throw StateError('部分书籍不存在');
    }
  }

  /// Create a placeholder book entry (e.g. for imported notes with no source file).
  Future<int> createPlaceholderBook(String title) async {
    return _bookDao.insertBook(BooksCompanion(
      title: Value(title),
      author: const Value(''),
      filePath: const Value(''),
      format: const Value('imported'),
      fileSize: const Value(0),
    ));
  }

  /// Delete a book, its cover image, and the stored file.
  ///
  /// The books_ad trigger will clean up the books_fts index.
  /// Chapters are cascade-deleted by the foreign key constraint.
  Future<void> deleteBook(int bookId) async {
    final book = await _bookDao.getBookById(bookId);
    if (book == null) return;

    final freedChars = await _bookDao.cachedContentLength([bookId]);
    await _bookDao.deleteBook(bookId);
    await _compactIfWorthIt(freedChars);

    // Delete files after the database transaction has succeeded.
    final file = File(book.filePath);
    if (await file.exists()) {
      await file.delete();
    }

    // Delete cover image if it exists
    if (book.coverPath != null) {
      final cover = File(book.coverPath!);
      if (await cover.exists()) {
        await cover.delete();
      }
    }
  }

  Future<void> deleteBooks(Set<int> bookIds) async {
    if (bookIds.isEmpty) return;
    final books = await _bookDao.getBooksByIds(bookIds.toList());
    if (books.length != bookIds.length) {
      throw StateError('部分书籍不存在');
    }
    final freedChars = await _bookDao.cachedContentLength(bookIds);
    await _bookDao.deleteBooks(bookIds);
    await _compactIfWorthIt(freedChars);

    for (final book in books.values) {
      try {
        final file = File(book.filePath);
        if (await file.exists()) await file.delete();
        if (book.coverPath != null) {
          final cover = File(book.coverPath!);
          if (await cover.exists()) await cover.delete();
        }
      } on FileSystemException {
        // The database is authoritative. A stale or externally removed file
        // must not leave a deleted book visible in the library.
      }
    }
  }

  /// 删掉的正文够多就回收一次磁盘空间。
  ///
  /// 不删完就跑：压缩的开销几乎全在 FTS5 的 optimize 上，而它跟**索引规模**
  /// 走，不跟这次删了多少走。删一本没缓存正文的小书也去跑一遍，等于每次都
  /// 付全额。50 万字这个门槛大约对应一本长篇。
  ///
  /// 失败不往上抛：书已经删掉了，空间没回收只是磁盘占用没降，不该让删除
  /// 操作报错。
  Future<void> _compactIfWorthIt(int freedChars) async {
    if (freedChars < _compactThresholdChars) return;
    try {
      await _bookDao.attachedDatabase.compact();
    } catch (_) {
      // 压缩是尽力而为。VACUUM 需要独占访问和额外磁盘，拿不到就算了，
      // 下次删书还有机会。
    }
  }

  /// 触发压缩的门槛：删掉的缓存正文字符数。
  static const _compactThresholdChars = 500000;
}

Future<String> _hashFile(String path) async {
  final digest = await sha256.bind(File(path).openRead()).first;
  return digest.toString();
}

List<String> _findSupportedBookFiles(String directoryPath) {
  final directory = Directory(directoryPath);
  if (!directory.existsSync()) {
    throw FileSystemException('文件夹不存在', directoryPath);
  }
  final paths = <String>[];
  for (final entity in directory.listSync(
    recursive: true,
    followLinks: false,
  )) {
    if (entity is! File) continue;
    final extension =
        p.extension(entity.path).toLowerCase().replaceFirst('.', '');
    if (supportedBookExtensions.contains(extension)) {
      paths.add(entity.path);
      if (paths.length > 5000) {
        throw StateError('文件夹中的支持格式书籍超过 5000 本，请缩小导入范围');
      }
    }
  }
  paths.sort();
  return paths;
}
