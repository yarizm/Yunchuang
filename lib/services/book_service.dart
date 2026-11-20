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
import 'chapter_relocation.dart';

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

/// 换章节时要挂回去的一样东西：它在旧章节上的位置，和挂回去的写法
/// （拿到新章节 id、新位置、新章节正文长度）。
class _ChapterMove {
  const _ChapterMove(this.position, this.apply);

  final ChapterPosition position;
  final Future<void> Function(
    int chapterId,
    ChapterPosition moved,
    int newLength,
  ) apply;
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
        await _replaceChapters(
          existing.id,
          BooksCompanion(
            filePath: Value(prepared.storedPath),
            format: Value(prepared.format),
            fileSize: Value(prepared.storedFileSize),
            fileHash: Value(resolved.fileHash),
            updatedAt: Value(DateTime.now()),
          ),
          prepared.chapters,
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
          // 开头猜不出书名时用文件名，比把章节标题或分隔线当书名强。
          final fallbackTitle = p.basenameWithoutExtension(analysis.sourcePath);
          final result = await Isolate.run(() {
            return (
              metadata: TxtParser.parseMetadata(
                content,
                fallbackTitle: fallbackTitle,
              ),
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

  /// 按现在的分章规则重新切一本 TXT，用应用里存的那份文件，不用再找原文件。
  ///
  /// 章节是导入时切好存进数据库的，分章规则改进以后，已经导入的书不会自己
  /// 变。返回切之前和切之后的章数。
  Future<({int before, int after})> resplitBook(int bookId) async {
    final book = await _bookDao.getBookById(bookId);
    if (book == null) throw StateError('书籍不存在');
    if (book.format != 'txt') {
      throw UnsupportedError('只有 TXT 是按规则分章的');
    }
    if (!await File(book.filePath).exists()) {
      throw FileSystemException('书籍文件不存在', book.filePath);
    }
    final content = await TextFileDecoder.readAsString(
      book.filePath,
      normalizeToUtf8: true,
    );
    final chapters = await Isolate.run(() => TxtParser.parseChapters(content));
    final before = (await _bookDao.getChapterSummariesForBook(bookId)).length;
    await _replaceChapters(
      bookId,
      BooksCompanion(updatedAt: Value(DateTime.now())),
      chapters,
      _chapterFactoriesFor(chapters, format: book.format),
    );
    return (before: before, after: chapters.length);
  }

  /// 换掉一本书的全部章节，阅读进度、书签、笔记、生词跟着挂到新章节上。
  ///
  /// 删旧章节时外键会把它们的章节号置空。之前「替换文件」就停在那一步：
  /// 再打开书回到第一章，笔记、高亮全都没了位置。现在按原文把位置找回来，
  /// 见 [relocateChapterPositions]。
  Future<void> _replaceChapters(
    int bookId,
    BooksCompanion bookChanges,
    List<ParsedChapter> parsedChapters,
    List<ChaptersCompanion Function(int bookId)> chapterFactories,
  ) async {
    final oldChapters = await _bookDao.getChapterSummariesForBook(bookId);
    final oldIndexById = {
      for (var index = 0; index < oldChapters.length; index++)
        oldChapters[index].id: index,
    };
    final progress = await _bookDao.getProgress(bookId);
    final notes = await _bookDao.notesOnChapters(bookId);
    final words = await _bookDao.vocabularyOnChapters(bookId);

    // 只读被挂着的那几章正文。
    final contents = <int, String>{};
    for (final chapterId in {
      if (progress?.chapterId != null) progress!.chapterId!,
      for (final note in notes) note.chapterId!,
      for (final word in words) word.chapterId!,
    }) {
      contents[chapterId] = await _bookDao.getChapterContent(chapterId) ?? '';
    }
    int lengthOf(int chapterId) => contents[chapterId]?.length ?? 0;

    final moves = <_ChapterMove>[];
    final progressChapter = oldIndexById[progress?.chapterId];
    if (progress != null && progressChapter != null) {
      final length = lengthOf(progress.chapterId!);
      final ratio = progress.positionInChapter.clamp(0.0, 1.0);
      moves.add(
        _ChapterMove(
          ChapterPosition(
            chapterIndex: progressChapter,
            start: (ratio * length).round(),
            approximate: true,
          ),
          (chapterId, moved, newLength) => _bookDao.moveProgress(
            bookId,
            chapterId,
            length == 0 || newLength == 0
                ? progress.positionInChapter
                : moved.start / newLength,
          ),
        ),
      );
    }
    for (final note in notes) {
      final index = oldIndexById[note.chapterId];
      if (index == null) continue;
      final start = note.positionStart;
      if (note.type == 'bookmark') {
        // 书签的 positionStart 是章内比例乘 10000，不是字符偏移。
        final length = lengthOf(note.chapterId!);
        final ratio = ((start ?? 0) / 10000).clamp(0.0, 1.0);
        moves.add(
          _ChapterMove(
            ChapterPosition(
              chapterIndex: index,
              start: (ratio * length).round(),
              approximate: true,
            ),
            (chapterId, moved, newLength) => _bookDao.moveNote(
              note.id,
              chapterId,
              positionStart: Value(
                length == 0 || newLength == 0
                    ? start
                    : (moved.start / newLength * 10000).round(),
              ),
            ),
          ),
        );
      } else if (start != null) {
        moves.add(
          _ChapterMove(
            ChapterPosition(
              chapterIndex: index,
              start: start,
              end: note.positionEnd,
              text: note.selectedText,
            ),
            (chapterId, moved, _) => _bookDao.moveNote(
              note.id,
              chapterId,
              positionStart: Value(moved.start),
              positionEnd: Value(moved.end),
            ),
          ),
        );
      } else {
        // 只挂在章上、没有位置的笔记：找到原文所在的那章就行。
        moves.add(
          _ChapterMove(
            ChapterPosition(
              chapterIndex: index,
              start: 0,
              text: note.selectedText,
              approximate: true,
            ),
            (chapterId, _, __) => _bookDao.moveNote(note.id, chapterId),
          ),
        );
      }
    }
    for (final word in words) {
      final index = oldIndexById[word.chapterId];
      if (index == null) continue;
      final start = word.positionStart;
      moves.add(
        _ChapterMove(
          start == null
              ? ChapterPosition(
                  chapterIndex: index,
                  start: 0,
                  text: word.contextText,
                  approximate: true,
                )
              : ChapterPosition(
                  chapterIndex: index,
                  start: start,
                  end: word.positionEnd,
                  text: word.term,
                ),
          (chapterId, moved, _) => start == null
              ? _bookDao.moveVocabularyEntry(word.id, chapterId)
              : _bookDao.moveVocabularyEntry(
                  word.id,
                  chapterId,
                  positionStart: Value(moved.start),
                  positionEnd: Value(moved.end),
                ),
        ),
      );
    }

    final oldText = [
      for (final chapter in oldChapters)
        (title: chapter.title, content: contents[chapter.id] ?? ''),
    ];
    final newText = [
      for (final chapter in parsedChapters)
        (title: chapter.title, content: chapter.content),
    ];
    final moved = moves.isEmpty
        ? const <ChapterPosition?>[]
        : await _relocateInBackground(
            oldText,
            newText,
            [for (final move in moves) move.position],
          );

    final freedChars = await _bookDao.cachedContentLength([bookId]);
    await _bookDao.replaceBookContent(
      bookId,
      bookChanges,
      chapterFactories,
      afterInsert: (chapterIds) async {
        for (var index = 0; index < moves.length; index++) {
          final target = moved[index];
          if (target == null || target.chapterIndex >= chapterIds.length) {
            continue;
          }
          await moves[index].apply(
            chapterIds[target.chapterIndex],
            target,
            newText[target.chapterIndex].content.length,
          );
        }
      },
    );
    // 旧章节的正文删掉了，和删书一样要回收空间。
    await _compactIfWorthIt(freedChars);
  }

  List<ChaptersCompanion Function(int bookId)> _chapterFactories(
    _PreparedImport prepared,
  ) =>
      _chapterFactoriesFor(prepared.chapters, format: prepared.format);

  List<ChaptersCompanion Function(int bookId)> _chapterFactoriesFor(
    List<ParsedChapter> chapters, {
    required String format,
  }) {
    return chapters
        .map((chapter) => (int bookId) => ChaptersCompanion(
              bookId: Value(bookId),
              title: Value(chapter.title),
              content: format == 'pdf'
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

/// 在后台 isolate 里找位置：几百万字的书要搜一阵。写成顶层函数，闭包只
/// 带这三个参数——在 [BookService] 的方法里直接写，闭包会连带捕获服务
/// 本身，发不到别的 isolate。
Future<List<ChapterPosition?>> _relocateInBackground(
  List<RelocatableChapter> oldChapters,
  List<RelocatableChapter> newChapters,
  List<ChapterPosition> positions,
) {
  return Isolate.run(
    () => relocateChapterPositions(
      oldChapters: oldChapters,
      newChapters: newChapters,
      positions: positions,
    ),
  );
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
