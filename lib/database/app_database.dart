import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;

import 'tables/books.dart';
import 'tables/book_collections.dart';
import 'tables/book_collection_items.dart';
import 'tables/book_tts_settings.dart';
import 'tables/book_reading_settings.dart';
import 'tables/vocabulary_entries.dart';
import 'tables/dictionary_sources.dart';
import 'tables/dictionary_entries.dart';
import 'tables/dictionary_aliases.dart';
import 'tables/chapters.dart';
import 'tables/reading_progress.dart';
import 'tables/reading_sessions.dart';
import 'tables/notes.dart';
import 'tables/tags.dart';
import 'tables/note_tags.dart';
import 'tables/note_relations.dart';
import 'tables/ai_providers.dart';
import 'tables/ai_conversations.dart';
import 'tables/ai_messages.dart';
import 'tables/ai_skills.dart';
import 'tables/ai_personas.dart';
import '../utils/app_data_directory.dart';

part 'app_database.g.dart';

class ChapterSearchResult {
  final int bookId;
  final String bookTitle;
  final int chapterId;
  final String chapterTitle;
  final String snippet;

  const ChapterSearchResult({
    required this.bookId,
    required this.bookTitle,
    required this.chapterId,
    required this.chapterTitle,
    required this.snippet,
  });
}

@DriftDatabase(tables: [
  Books,
  BookCollections,
  BookCollectionItems,
  BookTtsSettings,
  BookReadingSettings,
  VocabularyEntries,
  DictionarySources,
  DictionaryEntries,
  DictionaryAliases,
  Chapters,
  ReadingProgress,
  ReadingSessions,
  Notes,
  Tags,
  NoteTags,
  NoteRelations,
  AiProviders,
  AiConversations,
  AiMessages,
  AiSkills,
  AiPersonas,
])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());
  AppDatabase.connect(super.executor);
  AppDatabase.forFile(File file)
      : super(NativeDatabase.createInBackground(file));

  @override
  int get schemaVersion => 20;

  /// Create FTS5 virtual tables for full-text search.
  /// FTS5 tables cannot be declared in @DriftDatabase, so they are created
  /// manually via customStatement in the onCreate migration.
  Future<void> createFtsTables() async {
    if (await _tableExists('books')) {
      await customStatement('''
        CREATE VIRTUAL TABLE IF NOT EXISTS books_fts USING fts5(
          title, author, description,
          content='books',
          content_rowid='id'
        )
      ''');
      await customStatement(
          "INSERT INTO books_fts(books_fts) VALUES('rebuild')");
      await customStatement('''
        CREATE TRIGGER IF NOT EXISTS books_ai AFTER INSERT ON books BEGIN
          INSERT INTO books_fts(rowid, title, author, description)
            VALUES (new.id, new.title, new.author, new.description);
        END
      ''');
      await customStatement('''
        CREATE TRIGGER IF NOT EXISTS books_ad AFTER DELETE ON books BEGIN
          INSERT INTO books_fts(books_fts, rowid, title, author, description)
            VALUES('delete', old.id, old.title, old.author, old.description);
        END
      ''');
      await customStatement('''
        CREATE TRIGGER IF NOT EXISTS books_au AFTER UPDATE ON books BEGIN
          INSERT INTO books_fts(books_fts, rowid, title, author, description)
            VALUES('delete', old.id, old.title, old.author, old.description);
          INSERT INTO books_fts(rowid, title, author, description)
            VALUES (new.id, new.title, new.author, new.description);
        END
      ''');
    }

    if (await _tableExists('notes')) {
      await customStatement('''
        CREATE VIRTUAL TABLE IF NOT EXISTS notes_fts USING fts5(
          selected_text, content,
          content='notes',
          content_rowid='id'
        )
      ''');
      await customStatement(
          "INSERT INTO notes_fts(notes_fts) VALUES('rebuild')");
      await customStatement('''
        CREATE TRIGGER IF NOT EXISTS notes_ai AFTER INSERT ON notes BEGIN
          INSERT INTO notes_fts(rowid, selected_text, content)
            VALUES (new.id, new.selected_text, new.content);
        END
      ''');
      await customStatement('''
        CREATE TRIGGER IF NOT EXISTS notes_ad AFTER DELETE ON notes BEGIN
          INSERT INTO notes_fts(notes_fts, rowid, selected_text, content)
            VALUES('delete', old.id, old.selected_text, old.content);
        END
      ''');
      await customStatement('''
        CREATE TRIGGER IF NOT EXISTS notes_au AFTER UPDATE ON notes BEGIN
          INSERT INTO notes_fts(notes_fts, rowid, selected_text, content)
            VALUES('delete', old.id, old.selected_text, old.content);
          INSERT INTO notes_fts(rowid, selected_text, content)
            VALUES (new.id, new.selected_text, new.content);
        END
      ''');
    }

    if (await _tableExists('chapters')) {
      await customStatement('''
        CREATE VIRTUAL TABLE IF NOT EXISTS chapters_fts USING fts5(
          content, content='chapters', content_rowid='id'
        );
      ''');
      await customStatement(
          "INSERT INTO chapters_fts(chapters_fts) VALUES('rebuild')");
      await customStatement('''
        CREATE TRIGGER IF NOT EXISTS chapters_ai AFTER INSERT ON chapters BEGIN
          INSERT INTO chapters_fts(rowid, content)
          VALUES (new.id, new.content);
        END;
      ''');
      await customStatement('''
        CREATE TRIGGER IF NOT EXISTS chapters_ad AFTER DELETE ON chapters BEGIN
          INSERT INTO chapters_fts(chapters_fts, rowid, content)
          VALUES ('delete', old.id, old.content);
        END;
      ''');
      await customStatement('''
        CREATE TRIGGER IF NOT EXISTS chapters_au AFTER UPDATE ON chapters BEGIN
          INSERT INTO chapters_fts(chapters_fts, rowid, content)
          VALUES ('delete', old.id, old.content);
          INSERT INTO chapters_fts(rowid, content)
          VALUES (new.id, new.content);
        END;
      ''');

      await createChaptersTrigram();
    }
  }

  /// 建立中日韩子串搜索用的 trigram 正文索引。
  ///
  /// 与 [createFtsTables] 分开，因为迁移到 20 时只需要补这一张表——顺手
  /// 重建其他 FTS 表会在老库上炸：v13 之前的 chapters 还没有 content 列，
  /// 那时 chapters_fts 的 rebuild 找不到列。
  Future<void> createChaptersTrigram() async {
    if (!await _tableExists('chapters')) return;
    // 老库的 chapters 可能还没有 content 列（正文缓存是 v4 才加的）。外部
    // 内容表的 rebuild 会直接去读这一列，缺列就是硬报错，所以先确认。
    if (!await _columnExists('chapters', 'content')) return;
      // 第二张正文索引，只为中日韩子串搜索存在。
      //
      // chapters_fts 用默认的 unicode61 分词器，把连续汉字整段当成一个
      // token，MATCH 永远匹配不到词中间的片段；trigram 分词器按三字滑窗
      // 建索引，能把子串搜索变成索引查找，代价是索引体积可观。
      //
      // 它只做前置过滤，最终判定仍由 LIKE 负责：trigram 命中集是包含
      // 子串的行的超集，交给 LIKE 收口就不会因为分词器的边界行为出错。
      //
      // 三字以下的查询用不了它（trigram 顾名思义要三个字符起），那种情况
      // 退回全表扫描——两字中文词很常见，这个短板消不掉。
      await customStatement('''
        CREATE VIRTUAL TABLE IF NOT EXISTS chapters_trigram USING fts5(
          content, content='chapters', content_rowid='id',
          tokenize='trigram'
        );
      ''');
      await customStatement(
          "INSERT INTO chapters_trigram(chapters_trigram) VALUES('rebuild')");
      await customStatement('''
        CREATE TRIGGER IF NOT EXISTS chapters_tri_ai
        AFTER INSERT ON chapters BEGIN
          INSERT INTO chapters_trigram(rowid, content)
          VALUES (new.id, new.content);
        END;
      ''');
      await customStatement('''
        CREATE TRIGGER IF NOT EXISTS chapters_tri_ad
        AFTER DELETE ON chapters BEGIN
          INSERT INTO chapters_trigram(chapters_trigram, rowid, content)
          VALUES ('delete', old.id, old.content);
        END;
      ''');
      await customStatement('''
        CREATE TRIGGER IF NOT EXISTS chapters_tri_au
        AFTER UPDATE ON chapters BEGIN
          INSERT INTO chapters_trigram(chapters_trigram, rowid, content)
          VALUES ('delete', old.id, old.content);
          INSERT INTO chapters_trigram(rowid, content)
          VALUES (new.id, new.content);
        END;
      ''');
  }

  /// 四张 FTS5 虚拟表。顺序无关，但删表和压缩都要走全。
  static const _ftsTableNames = [
    'books_fts',
    'notes_fts',
    'chapters_fts',
    'chapters_trigram',
  ];

  /// 删掉大量内容之后回收磁盘空间。
  ///
  /// **删书会让数据库变大，而且不会自己缩回去。** FTS5 的外部内容表删行时不是
  /// 就地移除，而是往索引里**追加**一条删除标记。实测一本 1500 章、300 万字
  /// 的书，删掉之后库从 57MB 涨到 90MB，删除标记就是那多出来的 33MB。
  ///
  /// 两步缺一不可（同一个库，各自单独跑）：
  ///
  /// | 做法               | 90MB 之后 |
  /// |--------------------|-----------|
  /// | 只 VACUUM          | 88MB      |
  /// | 只 optimize        | 90MB      |
  /// | optimize + VACUUM  | 0.34MB    |
  ///
  /// 只 VACUUM 没用，因为删除标记是**活数据**，搬到新文件里还是那么多；
  /// 只 optimize 也没用，它把标记合并掉了（freelist 涨到 22389 页），但腾出
  /// 来的页还留在文件里，不还给系统。必须先合并再重写。
  ///
  /// 加了 `chapters_trigram` 之后这件事更严重：trigram 索引的条目数是普通
  /// FTS 的三倍（实测 17278 对 5693），删除标记也就是三倍。
  ///
  /// 耗时：上面那个库 optimize 695ms + VACUUM 22ms。开销几乎全在 optimize，
  /// 且随索引规模走而不是随删了多少走——所以调用方要挑时候，不要每删一本
  /// 小书都跑一遍。
  ///
  /// VACUUM 不能在事务里跑，也需要独占访问，因此这里不包 transaction。
  Future<void> compact() async {
    for (final table in _ftsTableNames) {
      if (!await _tableExists(table)) continue;
      await customStatement("INSERT INTO $table($table) VALUES('optimize')");
    }
    await customStatement('VACUUM');
  }

  Future<bool> _tableExists(String tableName) async {
    final rows = await customSelect(
      "SELECT 1 FROM sqlite_master WHERE type IN ('table', 'view') AND name = ?",
      variables: [Variable.withString(tableName)],
    ).get();
    return rows.isNotEmpty;
  }

  /// Adds indexes for common list, lookup, and relationship queries.
  ///
  /// Drift table primary keys and FTS indexes cover exact row lookups and text
  /// search. These indexes cover the app's non-FTS access patterns: chapter
  /// loading, note lists, tag filters, AI conversation history, and stats.
  Future<void> createPerformanceIndexes() async {
    if (await _tableExists('books')) {
      await customStatement('''
        CREATE INDEX IF NOT EXISTS idx_books_updated_at
        ON books(updated_at DESC)
      ''');
      await customStatement('''
        CREATE INDEX IF NOT EXISTS idx_books_created_at
        ON books(created_at DESC, id DESC)
      ''');
      await customStatement('''
        CREATE INDEX IF NOT EXISTS idx_books_title
        ON books(title, id)
      ''');
      await customStatement('''
        CREATE INDEX IF NOT EXISTS idx_books_author_title
        ON books(author, title, id)
      ''');
      if (await _columnExists('books', 'file_hash')) {
        await customStatement('''
          CREATE INDEX IF NOT EXISTS idx_books_file_hash
          ON books(file_hash)
          WHERE file_hash IS NOT NULL
        ''');
      }
      if (await _columnExists('books', 'series_name')) {
        await customStatement('''
          CREATE INDEX IF NOT EXISTS idx_books_series
          ON books(series_name, series_index, title)
          WHERE series_name IS NOT NULL
        ''');
      }
      if (await _columnExists('books', 'reading_status')) {
        await customStatement('''
          CREATE INDEX IF NOT EXISTS idx_books_reading_status
          ON books(reading_status, updated_at DESC)
        ''');
      }
    }
    if (await _tableExists('book_collections')) {
      await customStatement('''
        CREATE INDEX IF NOT EXISTS idx_book_collections_sort
        ON book_collections(sort_order, id)
      ''');
    }
    if (await _tableExists('book_collection_items')) {
      await customStatement('''
        CREATE INDEX IF NOT EXISTS idx_book_collection_items_book
        ON book_collection_items(book_id, collection_id)
      ''');
    }
    if (await _tableExists('chapters')) {
      await customStatement('''
        CREATE INDEX IF NOT EXISTS idx_chapters_book_sort
        ON chapters(book_id, sort_order)
      ''');
      await customStatement('''
        CREATE INDEX IF NOT EXISTS idx_chapters_book_content_index
        ON chapters(book_id, content_index)
      ''');
    }
    if (await _tableExists('reading_progress')) {
      await customStatement('''
        CREATE INDEX IF NOT EXISTS idx_reading_progress_last_read
        ON reading_progress(last_read_at DESC)
      ''');
      await customStatement('''
        CREATE INDEX IF NOT EXISTS idx_reading_progress_duration
        ON reading_progress(total_reading_seconds DESC, last_read_at DESC)
      ''');
    }
    if (await _tableExists('notes')) {
      await customStatement('''
        CREATE INDEX IF NOT EXISTS idx_notes_book_created
        ON notes(book_id, created_at DESC)
      ''');
      await customStatement('''
        CREATE INDEX IF NOT EXISTS idx_notes_book_type_created
        ON notes(book_id, type, created_at DESC)
      ''');
      await customStatement('''
        CREATE INDEX IF NOT EXISTS idx_notes_chapter
        ON notes(chapter_id)
      ''');
      await customStatement('''
        CREATE INDEX IF NOT EXISTS idx_notes_type_created
        ON notes(type, created_at DESC)
      ''');
    }
    if (await _tableExists('note_tags')) {
      await customStatement('''
        CREATE INDEX IF NOT EXISTS idx_note_tags_tag_note
        ON note_tags(tag_id, note_id)
      ''');
    }
    if (await _tableExists('note_relations')) {
      await customStatement('''
        CREATE INDEX IF NOT EXISTS idx_note_relations_note2_note1
        ON note_relations(note_id2, note_id1)
      ''');
    }
    if (await _tableExists('ai_providers')) {
      await customStatement('''
        CREATE INDEX IF NOT EXISTS idx_ai_providers_default
        ON ai_providers(is_default)
        WHERE is_default = 1
      ''');
    }
    if (await _tableExists('ai_conversations')) {
      await customStatement('''
        CREATE INDEX IF NOT EXISTS idx_ai_conversations_created
        ON ai_conversations(created_at DESC)
      ''');
      await customStatement('''
        CREATE INDEX IF NOT EXISTS idx_ai_conversations_book_created
        ON ai_conversations(book_id, created_at DESC)
      ''');
    }
    if (await _tableExists('ai_messages')) {
      await customStatement('''
        CREATE INDEX IF NOT EXISTS idx_ai_messages_conversation_created
        ON ai_messages(conversation_id, created_at)
      ''');
    }
    if (await _tableExists('ai_skills')) {
      await customStatement('''
        CREATE INDEX IF NOT EXISTS idx_ai_skills_enabled
        ON ai_skills(enabled, updated_at DESC)
      ''');
    }
    if (await _tableExists('ai_personas')) {
      await customStatement('''
        CREATE INDEX IF NOT EXISTS idx_ai_personas_book
        ON ai_personas(book_id, updated_at DESC)
      ''');
    }
    if (await _tableExists('vocabulary_entries')) {
      await customStatement('''
        CREATE INDEX IF NOT EXISTS idx_vocabulary_updated
        ON vocabulary_entries(updated_at DESC, id DESC)
      ''');
      await customStatement('''
        CREATE INDEX IF NOT EXISTS idx_vocabulary_chapter
        ON vocabulary_entries(chapter_id)
      ''');
    }
    if (await _tableExists('dictionary_sources')) {
      await customStatement('''
        CREATE INDEX IF NOT EXISTS idx_dictionary_sources_ready
        ON dictionary_sources(is_ready, enabled, name)
      ''');
    }
    if (await _tableExists('dictionary_entries')) {
      await customStatement('''
        CREATE INDEX IF NOT EXISTS idx_dictionary_entries_lookup
        ON dictionary_entries(normalized_headword, source_id)
      ''');
      await customStatement('''
        CREATE INDEX IF NOT EXISTS idx_dictionary_entries_source
        ON dictionary_entries(source_id, entry_index)
      ''');
    }
    if (await _tableExists('dictionary_aliases')) {
      await customStatement('''
        CREATE INDEX IF NOT EXISTS idx_dictionary_aliases_lookup
        ON dictionary_aliases(normalized_alias, source_id)
      ''');
    }
    if (await _tableExists('reading_sessions')) {
      // 按天汇总（统计页、热力图）走这条。
      await customStatement('''
        CREATE INDEX IF NOT EXISTS idx_reading_sessions_date
        ON reading_sessions(date)
      ''');
      // 累加写入前要先查 (书, 日) 那一行，读得比写频繁得多。
      await customStatement('''
        CREATE INDEX IF NOT EXISTS idx_reading_sessions_book_date
        ON reading_sessions(book_id, date)
      ''');
    }
  }

  Future<bool> _columnExists(String tableName, String columnName) async {
    final rows = await customSelect(
      'PRAGMA table_info(${_quoteIdentifier(tableName)})',
    ).get();
    return rows.any((row) => row.read<String>('name') == columnName);
  }

  String _quoteIdentifier(String identifier) {
    return '"${identifier.replaceAll('"', '""')}"';
  }

  Future<void> _dropFtsObjects() async {
    for (final trigger in [
      'books_ai',
      'books_ad',
      'books_au',
      'notes_ai',
      'notes_ad',
      'notes_au',
      'chapters_ai',
      'chapters_ad',
      'chapters_au',
      'chapters_tri_ai',
      'chapters_tri_ad',
      'chapters_tri_au',
    ]) {
      await customStatement('DROP TRIGGER IF EXISTS $trigger');
    }
    for (final table in _ftsTableNames) {
      await customStatement('DROP TABLE IF EXISTS $table');
    }
  }

  /// Repairs relationships created before foreign keys were enabled.
  ///
  /// Missing book rows are recreated as placeholders so no child rows are
  /// discarded. Invalid optional chapter references are cleared.
  Future<void> _repairLegacyRelationships() async {
    await customStatement('''
      INSERT INTO books (title, author, file_path, format, file_size)
      SELECT '恢复的数据', '', '__recovered_relations__', 'imported', 0
      WHERE (
        EXISTS (
          SELECT 1 FROM note_tags nt
          WHERE nt.note_id NOT IN (SELECT id FROM notes)
        )
        OR EXISTS (
          SELECT 1 FROM note_relations nr
          WHERE nr.note_id1 NOT IN (SELECT id FROM notes)
             OR nr.note_id2 NOT IN (SELECT id FROM notes)
        )
      )
      AND NOT EXISTS (
        SELECT 1 FROM books WHERE file_path = '__recovered_relations__'
      )
    ''');
    await customStatement('''
      INSERT OR IGNORE INTO notes (id, book_id, content)
      SELECT missing_id,
             (SELECT id FROM books
              WHERE file_path = '__recovered_relations__' LIMIT 1),
             '恢复的关联笔记 #' || missing_id
      FROM (
        SELECT note_id AS missing_id FROM note_tags
        UNION SELECT note_id1 FROM note_relations
        UNION SELECT note_id2 FROM note_relations
      )
      WHERE missing_id NOT IN (SELECT id FROM notes)
    ''');
    await customStatement('''
      INSERT OR IGNORE INTO tags (id, name)
      SELECT tag_id, '恢复的标签 #' || tag_id
      FROM note_tags
      WHERE tag_id NOT IN (SELECT id FROM tags)
    ''');
    await customStatement('''
      INSERT OR IGNORE INTO ai_conversations (id, title)
      SELECT conversation_id, '恢复的 AI 会话 #' || conversation_id
      FROM ai_messages
      WHERE conversation_id NOT IN (SELECT id FROM ai_conversations)
    ''');
    await customStatement('''
      INSERT OR IGNORE INTO books
        (id, title, author, file_path, format, file_size)
      SELECT missing_id, '恢复的书籍 #' || missing_id, '', '', 'imported', 0
      FROM (
        SELECT book_id AS missing_id FROM chapters
        UNION SELECT book_id FROM notes
        UNION SELECT book_id FROM reading_progress
        UNION SELECT book_id FROM ai_conversations WHERE book_id IS NOT NULL
      )
      WHERE missing_id NOT IN (SELECT id FROM books)
    ''');
    await customStatement('''
      UPDATE notes
      SET chapter_id = NULL
      WHERE chapter_id IS NOT NULL
        AND chapter_id NOT IN (SELECT id FROM chapters)
    ''');
  }

  static const _bookColumns = 'SELECT b.id, b.title, b.author, b.cover_path,'
      ' b.file_path, b.format, b.file_size, b.description, b.file_hash,'
      ' b.series_name, b.series_index, b.reading_status,'
      ' b.created_at, b.updated_at';

  static const _noteColumns =
      'SELECT n.id, n.book_id, n.chapter_id, n.selected_text, n.content,'
      ' n.page_number, n.position_start, n.position_end,'
      ' n.created_at, n.updated_at, n.type';

  static Book _mapBook(QueryRow row) => Book(
        id: row.read<int>('id'),
        title: row.read<String>('title'),
        author: row.read<String>('author'),
        coverPath: row.read<String?>('cover_path'),
        filePath: row.read<String>('file_path'),
        format: row.read<String>('format'),
        fileSize: row.read<int>('file_size'),
        description: row.read<String?>('description'),
        fileHash: row.read<String?>('file_hash'),
        seriesName: row.read<String?>('series_name'),
        seriesIndex: row.read<double?>('series_index'),
        readingStatus: row.read<String?>('reading_status'),
        createdAt: row.read<DateTime>('created_at'),
        updatedAt: row.read<DateTime>('updated_at'),
      );

  static Note _mapNote(QueryRow row) => Note(
        id: row.read<int>('id'),
        bookId: row.read<int>('book_id'),
        chapterId: row.read<int?>('chapter_id'),
        selectedText: row.read<String?>('selected_text'),
        content: row.read<String?>('content'),
        pageNumber: row.read<int?>('page_number'),
        positionStart: row.read<int?>('position_start'),
        positionEnd: row.read<int?>('position_end'),
        createdAt: row.read<DateTime>('created_at'),
        updatedAt: row.read<DateTime>('updated_at'),
        type: row.read<String>('type'),
      );

  static ChapterSearchResult _mapChapterResult(QueryRow row) =>
      ChapterSearchResult(
        bookId: row.read<int>('book_id'),
        bookTitle: row.read<String>('book_title'),
        chapterId: row.read<int>('chapter_id'),
        chapterTitle: row.read<String>('chapter_title'),
        snippet: row.read<String>('snip'),
      );

  /// Search books by full-text keyword.
  Future<List<Book>> searchBooks(String query, {int limit = 20}) async {
    final results = await customSelect(
      '$_bookColumns'
      ' FROM books_fts fts JOIN books b ON fts.rowid = b.id '
      'WHERE books_fts MATCH ? '
      'ORDER BY bm25(books_fts) '
      'LIMIT ?',
      variables: [
        Variable.withString(query),
        Variable.withInt(limit),
      ],
      readsFrom: {books},
    ).get();
    return results.map(_mapBook).toList();
  }

  /// Search notes by full-text keyword.
  Future<List<Note>> searchNotes(String query, {int limit = 30}) async {
    final results = await customSelect(
      '$_noteColumns'
      ' FROM notes_fts fts JOIN notes n ON fts.rowid = n.id '
      'WHERE notes_fts MATCH ? '
      'ORDER BY bm25(notes_fts) '
      'LIMIT ?',
      variables: [
        Variable.withString(query),
        Variable.withInt(limit),
      ],
      readsFrom: {notes},
    ).get();
    return results.map(_mapNote).toList();
  }

  /// Search chapter contents by full-text keyword. Returns up to 50 matches
  /// with a snippet for preview. PDF chapters (empty content) are not indexed.
  Future<List<ChapterSearchResult>> searchChapters(
    String query, {
    int limit = 50,
  }) async {
    final results = await customSelect(
      'SELECT c.id AS chapter_id, c.title AS chapter_title, c.book_id AS book_id, '
      'b.title AS book_title, '
      "snippet(chapters_fts, 0, '»', '«', '…', 12) AS snip "
      'FROM chapters_fts fts '
      'JOIN chapters c ON fts.rowid = c.id '
      'JOIN books b ON c.book_id = b.id '
      'WHERE chapters_fts MATCH ? '
      'ORDER BY bm25(chapters_fts), c.sort_order '
      'LIMIT ?',
      variables: [
        Variable.withString(query),
        Variable.withInt(limit),
      ],
      readsFrom: {chapters, books},
    ).get();
    return results.map(_mapChapterResult).toList();
  }

  // ---------------------------------------------------------------------
  // Substring (LIKE) search.
  //
  // FTS5's `unicode61` tokenizer classifies Han/Kana/Hangul as token
  // characters, so an unbroken run of them becomes ONE token: `MATCH "计算机"`
  // does not match a book titled `深入理解计算机系统`, and no amount of query
  // rewriting fixes that. [SearchService] detects such queries and routes them
  // to the methods below, which do a plain substring scan instead.
  //
  // These are table scans with no index behind them, which is exactly why the
  // FTS path above is kept for space-delimited scripts where it works.
  // ---------------------------------------------------------------------

  /// Builds `(colA LIKE ? OR colB LIKE ?) AND (…)` — every term must appear in
  /// at least one column, matching the `AND` semantics of the FTS query
  /// builder. Binds [columns] × [termCount] variables, in that nesting order.
  static String _likeClause(List<String> columns, int termCount) {
    final perTerm =
        '(${columns.map((column) => "$column LIKE ? ESCAPE '\\'").join(' OR ')})';
    return List.filled(termCount, perTerm).join(' AND ');
  }

  static List<Variable> _likeVariables(List<String> terms, int columnCount) {
    return [
      for (final term in terms)
        for (var index = 0; index < columnCount; index++)
          Variable.withString(_likePattern(term)),
    ];
  }

  static String _likePattern(String term) => '%${_escapeLike(term)}%';

  static String _escapeLike(String value) => value
      .replaceAll(r'\', r'\\')
      .replaceAll('%', r'\%')
      .replaceAll('_', r'\_');

  /// 查询词里是否有需要 SQL 折叠大小写的字符。
  ///
  /// SQLite 内置的 lower() 只折叠 ASCII A-Z。查询词一个大小写字母都没有时
  /// （纯中日韩查询就是这种情况），对正文调用 lower() 不会改变任何一条匹配
  /// 结果，却要为每一行物化一份整章正文的副本。
  static bool _needsCaseFolding(List<String> terms) =>
      terms.any((term) => term.contains(RegExp('[A-Za-z]')));

  /// 用于 trigram 前置过滤的词，没有合适的就返回 null。
  ///
  /// trigram 索引按三字滑窗建立，短于三个字符的词在里面查不到（会返回空集
  /// 而不是报错），所以只能挑长度够的。挑最长的那个：词越长越少见，前置
  /// 过滤后剩下的候选行越少。
  static String? _trigramProbe(List<String> terms) {
    String? best;
    for (final term in terms) {
      if (term.length < 3) continue;
      if (best == null || term.length > best.length) best = term;
    }
    return best;
  }

  /// Substring counterpart of [searchBooks]. Title matches sort first.
  Future<List<Book>> searchBooksLike(
    List<String> terms, {
    int limit = 20,
  }) async {
    if (terms.isEmpty) return const [];
    const columns = ['b.title', 'b.author', "COALESCE(b.description, '')"];
    final results = await customSelect(
      '$_bookColumns FROM books b '
      'WHERE ${_likeClause(columns, terms.length)} '
      "ORDER BY CASE WHEN b.title LIKE ? ESCAPE '\\' THEN 0 ELSE 1 END, "
      'b.updated_at DESC '
      'LIMIT ?',
      variables: [
        ..._likeVariables(terms, columns.length),
        Variable.withString(_likePattern(terms.first)),
        Variable.withInt(limit),
      ],
      readsFrom: {books},
    ).get();
    return results.map(_mapBook).toList();
  }

  /// Substring counterpart of [searchNotes], newest first.
  Future<List<Note>> searchNotesLike(
    List<String> terms, {
    int limit = 30,
  }) async {
    if (terms.isEmpty) return const [];
    const columns = [
      "COALESCE(n.selected_text, '')",
      "COALESCE(n.content, '')",
    ];
    final results = await customSelect(
      '$_noteColumns FROM notes n '
      'WHERE ${_likeClause(columns, terms.length)} '
      'ORDER BY n.created_at DESC '
      'LIMIT ?',
      variables: [
        ..._likeVariables(terms, columns.length),
        Variable.withInt(limit),
      ],
      readsFrom: {notes},
    ).get();
    return results.map(_mapNote).toList();
  }

  /// Substring counterpart of [searchChapters].
  ///
  /// Ranks by occurrence count of the first term and cuts the preview snippet
  /// in SQL, so full chapter bodies never cross into Dart.
  Future<List<ChapterSearchResult>> searchChaptersLike(
    List<String> terms, {
    int limit = 50,
  }) async {
    if (terms.isEmpty) return const [];
    const columns = ['c.content'];
    // Present in every row by construction: it is one of the ANDed terms, so
    // instr() is always > 0 and length() is always > 0.
    final anchor = terms.first;
    // lower() 每出现一次就复制一份整章正文，而 ORDER BY hit_count 要求所有
    // 命中行都算完才能 LIMIT——一次搜索的分配量是「命中章节数 x 正文长度」
    // 的数倍。纯中日韩查询下这些折叠是空操作，直接省掉。
    //
    // length(lower(x)) 无条件写成 length(x)：ASCII 折叠不改变字符串长度。
    final fold = _needsCaseFolding(terms);
    final content = fold ? 'lower(c.content)' : 'c.content';
    final needle = fold ? 'lower(?)' : '?';
    // trigram 只做前置过滤，把全表扫描收窄成索引查找；命中集是含该子串的
    // 行的超集，最终判定仍交给下面的 LIKE，所以分词器的边界行为不影响
    // 结果正确性。没有够长的词时这里为空，退回原来的全表扫描。
    final probe = _trigramProbe(terms);
    final trigramFilter = probe == null
        ? ''
        : 'AND c.id IN (SELECT rowid FROM chapters_trigram '
            'WHERE chapters_trigram MATCH ?) ';
    final results = await customSelect(
      'SELECT c.id AS chapter_id, c.title AS chapter_title, '
      'c.book_id AS book_id, b.title AS book_title, '
      'substr(c.content, MAX(1, instr($content, $needle) - 24), 72) '
      'AS snip, '
      '(length(c.content) - '
      "length(replace($content, $needle, ''))) / length(?) "
      'AS hit_count '
      'FROM chapters c JOIN books b ON c.book_id = b.id '
      "WHERE c.content IS NOT NULL AND c.content <> '' "
      '$trigramFilter'
      'AND ${_likeClause(columns, terms.length)} '
      'ORDER BY hit_count DESC, c.sort_order '
      'LIMIT ?',
      variables: [
        Variable.withString(anchor),
        Variable.withString(anchor),
        Variable.withString(anchor),
        if (probe != null) Variable.withString('"${probe.replaceAll('"', '""')}"'),
        ..._likeVariables(terms, columns.length),
        Variable.withInt(limit),
      ],
      readsFrom: {chapters, books},
    ).get();
    return results.map(_mapChapterResult).toList();
  }

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (Migrator m) async {
          await m.createAll();
          await createFtsTables();
          await createPerformanceIndexes();
        },
        onUpgrade: (m, from, to) async {
          if (from < 2) {
            await m.addColumn(
                readingProgress, readingProgress.totalReadingSeconds);
          }
          if (from < 3) {
            await _dropFtsObjects();
            await _repairLegacyRelationships();
            await m.alterTable(TableMigration(
              chapters,
              newColumns: [chapters.content],
            ));
            await m.alterTable(TableMigration(
              readingProgress,
              columnTransformer: {
                readingProgress.chapterId: const CustomExpression<int>(
                  'CASE WHEN chapter_id IN (SELECT id FROM chapters) '
                  'THEN chapter_id ELSE NULL END',
                ),
              },
            ));
            await m.alterTable(TableMigration(
              notes,
              newColumns: [notes.type],
            ));
            await m.alterTable(TableMigration(noteTags));
            await m.alterTable(TableMigration(noteRelations));
            await m.alterTable(TableMigration(aiConversations));
            await m.alterTable(TableMigration(
              aiMessages,
              newColumns: [aiMessages.metadataJson],
            ));
            await createFtsTables();
          }
          if (from >= 3 && from < 4) {
            await m.addColumn(chapters, chapters.content);
          }
          if (from >= 3 &&
              from < 5 &&
              await _tableExists('notes') &&
              !await _columnExists('notes', 'type')) {
            await m.addColumn(notes, notes.type);
          }
          // Backfills rows that predate `notes.type`. Everything inserted since
          // v5 gets the column default, so this is scoped to upgrades that
          // cross v5 rather than run on every version bump.
          if (from < 5 &&
              await _tableExists('notes') &&
              await _columnExists('notes', 'type')) {
            await customStatement(
              "UPDATE notes SET type='highlight' "
              "WHERE (type IS NULL OR type='') "
              "AND content IS NULL AND selected_text IS NOT NULL",
            );
            await customStatement(
              "UPDATE notes SET type='note' "
              "WHERE (type IS NULL OR type='')",
            );
          }
          if (from >= 3 && from < 6) {
            await createFtsTables();
          }
          if (from < 7) {
            await createPerformanceIndexes();
          }
          if (from < 8) {
            if (await _tableExists('ai_messages') &&
                !await _columnExists('ai_messages', 'metadata_json')) {
              await m.addColumn(aiMessages, aiMessages.metadataJson);
            }
            if (!await _tableExists('ai_skills')) {
              await m.createTable(aiSkills);
            }
            if (!await _tableExists('ai_personas')) {
              await m.createTable(aiPersonas);
            }
            await createPerformanceIndexes();
          }
          if (from < 9) {
            if (await _tableExists('books') &&
                !await _columnExists('books', 'reading_status')) {
              await m.addColumn(books, books.readingStatus);
            }
            await createPerformanceIndexes();
          }
          if (from < 10) {
            if (!await _tableExists('book_collections')) {
              await m.createTable(bookCollections);
            }
            if (!await _tableExists('book_collection_items')) {
              await m.createTable(bookCollectionItems);
            }
            await createPerformanceIndexes();
          }
          if (from < 11) {
            if (await _tableExists('books') &&
                !await _columnExists('books', 'file_hash')) {
              await m.addColumn(books, books.fileHash);
            }
            await createPerformanceIndexes();
          }
          if (from < 12) {
            if (await _tableExists('books') &&
                !await _columnExists('books', 'series_name')) {
              await m.addColumn(books, books.seriesName);
            }
            if (await _tableExists('books') &&
                !await _columnExists('books', 'series_index')) {
              await m.addColumn(books, books.seriesIndex);
            }
            await createPerformanceIndexes();
          }
          if (from < 13 && !await _tableExists('book_tts_settings')) {
            await m.createTable(bookTtsSettings);
          }
          if (from < 14 && !await _tableExists('vocabulary_entries')) {
            await m.createTable(vocabularyEntries);
            await createPerformanceIndexes();
          }
          if (from < 15 && !await _tableExists('dictionary_sources')) {
            await m.createTable(dictionarySources);
            await m.createTable(dictionaryEntries);
            await m.createTable(dictionaryAliases);
            await createPerformanceIndexes();
          }
          if (from < 16 && !await _tableExists('book_reading_settings')) {
            await m.createTable(bookReadingSettings);
          }
          if (from < 17 && await _tableExists('book_reading_settings')) {
            if (!await _columnExists(
              'book_reading_settings',
              'word_spacing',
            )) {
              await m.addColumn(
                bookReadingSettings,
                bookReadingSettings.wordSpacing,
              );
            }
            if (!await _columnExists('book_reading_settings', 'bold_text')) {
              await m.addColumn(
                bookReadingSettings,
                bookReadingSettings.boldText,
              );
            }
            if (!await _columnExists(
              'book_reading_settings',
              'text_alignment',
            )) {
              await m.addColumn(
                bookReadingSettings,
                bookReadingSettings.textAlignment,
              );
            }
            if (!await _columnExists(
              'book_reading_settings',
              'paragraph_indent',
            )) {
              await m.addColumn(
                bookReadingSettings,
                bookReadingSettings.paragraphIndent,
              );
            }
          }
          if (from < 18 && await _tableExists('book_reading_settings')) {
            if (!await _columnExists(
              'book_reading_settings',
              'pdf_crop_amount',
            )) {
              await m.addColumn(
                bookReadingSettings,
                bookReadingSettings.pdfCropAmount,
              );
            }
            if (!await _columnExists(
              'book_reading_settings',
              'pdf_contrast',
            )) {
              await m.addColumn(
                bookReadingSettings,
                bookReadingSettings.pdfContrast,
              );
            }
            if (!await _columnExists(
              'book_reading_settings',
              'pdf_page_layout',
            )) {
              await m.addColumn(
                bookReadingSettings,
                bookReadingSettings.pdfPageLayout,
              );
            }
          }
          if (from < 19 && !await _tableExists('reading_sessions')) {
            await m.createTable(readingSessions);
            await createPerformanceIndexes();
          }
          // 中日韩子串搜索的 trigram 索引。createFtsTables 里全是
          // IF NOT EXISTS，重复执行安全；rebuild 会按现有正文重新灌一遍，
          // 书多时这一步不快，但只在升级到 20 时跑一次。
          if (from < 20 && !await _tableExists('chapters_trigram')) {
            await createChaptersTrigram();
          }
        },
        beforeOpen: (details) async {
          await customStatement('PRAGMA foreign_keys = ON');
        },
      );
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dir = await appDataDirectory();
    // 沿用旧名，不随项目更名为 yunchuang：改了旧安装会找不到自己的库。
    // 理由详见 BackupService._databaseName。
    final file = File(p.join(dir.path, 'reading_offline.db'));
    return NativeDatabase.createInBackground(file);
  });
}
