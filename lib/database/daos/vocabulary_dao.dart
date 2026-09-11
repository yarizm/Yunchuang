import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/books.dart';
import '../tables/chapters.dart';
import '../tables/vocabulary_entries.dart';

part 'vocabulary_dao.g.dart';

class VocabularyEntryDetails {
  final VocabularyEntry entry;
  final String bookTitle;
  final String? chapterTitle;

  const VocabularyEntryDetails({
    required this.entry,
    required this.bookTitle,
    required this.chapterTitle,
  });
}

@DriftAccessor(tables: [VocabularyEntries, Books, Chapters])
class VocabularyDao extends DatabaseAccessor<AppDatabase>
    with _$VocabularyDaoMixin {
  VocabularyDao(super.db);

  Stream<List<VocabularyEntryDetails>> watchAllDetails() {
    final query = select(vocabularyEntries).join([
      innerJoin(books, books.id.equalsExp(vocabularyEntries.bookId)),
      leftOuterJoin(
        chapters,
        chapters.id.equalsExp(vocabularyEntries.chapterId),
      ),
    ])
      ..orderBy([
        OrderingTerm.desc(vocabularyEntries.updatedAt),
        OrderingTerm.desc(vocabularyEntries.id),
      ]);
    return query.watch().map(
          (rows) => rows
              .map(
                (row) => VocabularyEntryDetails(
                  entry: row.readTable(vocabularyEntries),
                  bookTitle: row.readTable(books).title,
                  chapterTitle: row.readTableOrNull(chapters)?.title,
                ),
              )
              .toList(growable: false),
        );
  }

  Future<List<VocabularyEntry>> getForBook(int bookId) {
    return (select(vocabularyEntries)
          ..where((entry) => entry.bookId.equals(bookId))
          ..orderBy([
            (entry) => OrderingTerm.desc(entry.updatedAt),
            (entry) => OrderingTerm.desc(entry.id),
          ]))
        .get();
  }

  Future<VocabularyEntry?> findForBook(int bookId, String term) {
    final normalized = normalizeTerm(term);
    if (normalized.isEmpty) return Future.value(null);
    return (select(vocabularyEntries)
          ..where(
            (entry) =>
                entry.bookId.equals(bookId) &
                entry.normalizedTerm.equals(normalized),
          ))
        .getSingleOrNull();
  }

  Future<VocabularyEntry> save({
    required int bookId,
    required int? chapterId,
    required String term,
    String? definition,
    String? contextText,
    int? positionStart,
    int? positionEnd,
  }) async {
    final normalizedTerm = normalizeTerm(term);
    final displayTerm = term.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (displayTerm.isEmpty || displayTerm.length > 200) {
      throw ArgumentError.value(term, 'term', '词条长度必须为 1 到 200 个字符');
    }
    if (positionStart != null && positionStart < 0) {
      throw ArgumentError.value(positionStart, 'positionStart', '位置不能小于 0');
    }
    if (positionEnd != null &&
        (positionEnd < 0 ||
            (positionStart != null && positionEnd < positionStart))) {
      throw ArgumentError.value(positionEnd, 'positionEnd', '结束位置无效');
    }
    final normalizedDefinition = _normalizeOptional(definition);
    final normalizedContext = _normalizeOptional(contextText);
    if (normalizedContext != null && normalizedContext.length > 2000) {
      throw ArgumentError.value(contextText, 'contextText', '来源原句不能超过 2000 字符');
    }
    if (chapterId != null) {
      final chapter = await (select(chapters)
            ..where(
              (chapter) =>
                  chapter.id.equals(chapterId) & chapter.bookId.equals(bookId),
            ))
          .getSingleOrNull();
      if (chapter == null) {
        throw ArgumentError.value(chapterId, 'chapterId', '章节不属于当前书籍');
      }
    }

    final existing = await findForBook(bookId, normalizedTerm);
    final now = DateTime.now();
    if (existing == null) {
      final id = await into(vocabularyEntries).insert(
        VocabularyEntriesCompanion.insert(
          bookId: bookId,
          chapterId: Value(chapterId),
          term: displayTerm,
          normalizedTerm: normalizedTerm,
          definition: Value(normalizedDefinition),
          contextText: Value(normalizedContext),
          positionStart: Value(positionStart),
          positionEnd: Value(positionEnd),
          updatedAt: Value(now),
        ),
      );
      return (select(vocabularyEntries)..where((entry) => entry.id.equals(id)))
          .getSingle();
    }

    await (update(vocabularyEntries)
          ..where((entry) => entry.id.equals(existing.id)))
        .write(
      VocabularyEntriesCompanion(
        chapterId: Value(chapterId),
        term: Value(displayTerm),
        definition: Value(normalizedDefinition),
        contextText: Value(normalizedContext),
        positionStart: Value(positionStart),
        positionEnd: Value(positionEnd),
        updatedAt: Value(now),
      ),
    );
    return (select(vocabularyEntries)
          ..where((entry) => entry.id.equals(existing.id)))
        .getSingle();
  }

  Future<void> updateDefinition(int id, String? definition) async {
    await (update(vocabularyEntries)..where((entry) => entry.id.equals(id)))
        .write(
      VocabularyEntriesCompanion(
        definition: Value(_normalizeOptional(definition)),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<int> deleteEntry(int id) {
    return (delete(vocabularyEntries)..where((entry) => entry.id.equals(id)))
        .go();
  }

  static String normalizeTerm(String term) {
    return term.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();
  }

  static String? _normalizeOptional(String? value) {
    final normalized = value?.trim();
    return normalized == null || normalized.isEmpty ? null : normalized;
  }
}
