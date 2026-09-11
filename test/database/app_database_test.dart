import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yunchuang/database/app_database.dart';
import 'package:yunchuang/database/daos/book_dao.dart';
import 'package:yunchuang/database/daos/book_tts_settings_dao.dart';
import 'package:yunchuang/database/daos/progress_dao.dart';
import 'package:yunchuang/services/search_service.dart';

void main() {
  group('AppDatabase schema v18', () {
    late AppDatabase database;

    setUp(() {
      database = AppDatabase.connect(NativeDatabase.memory());
    });

    tearDown(() => database.close());

    test('enables foreign keys and cascades book children', () async {
      final foreignKeys = await database
          .customSelect('PRAGMA foreign_keys')
          .map((row) => row.read<int>('foreign_keys'))
          .getSingle();
      expect(foreignKeys, 1);

      final bookId = await database.into(database.books).insert(
            BooksCompanion.insert(
              title: 'Book',
              filePath: 'book.txt',
              format: 'txt',
              fileSize: 1,
            ),
          );
      final chapterId = await database.into(database.chapters).insert(
            ChaptersCompanion.insert(
              bookId: bookId,
              title: 'Chapter',
              content: const Value('cached chapter'),
              contentIndex: 0,
              sortOrder: 0,
            ),
          );
      await database.into(database.notes).insert(
            NotesCompanion.insert(
              bookId: bookId,
              chapterId: Value(chapterId),
              content: const Value('note'),
            ),
          );
      await database.into(database.readingProgress).insert(
            ReadingProgressCompanion.insert(
              bookId: Value(bookId),
              chapterId: Value(chapterId),
            ),
          );
      await BookTtsSettingsDao(database).save(
        bookId: bookId,
        language: 'zh-CN',
        speechRate: 0.7,
        sleepTimerOption: 'minutes30',
      );
      await database.into(database.vocabularyEntries).insert(
            VocabularyEntriesCompanion.insert(
              bookId: bookId,
              chapterId: Value(chapterId),
              term: '词条',
              normalizedTerm: '词条',
            ),
          );

      await (database.delete(database.books)
            ..where((book) => book.id.equals(bookId)))
          .go();

      expect(await database.select(database.chapters).get(), isEmpty);
      expect(await database.select(database.notes).get(), isEmpty);
      expect(await database.select(database.readingProgress).get(), isEmpty);
      expect(await database.select(database.bookTtsSettings).get(), isEmpty);
      expect(await database.select(database.vocabularyEntries).get(), isEmpty);
    });

    test('persists parsed chapter content for subsequent opens', () async {
      final bookId = await database.into(database.books).insert(
            BooksCompanion.insert(
              title: 'Cached',
              filePath: 'cached.txt',
              format: 'txt',
              fileSize: 1,
            ),
          );
      await database.into(database.chapters).insert(
            ChaptersCompanion.insert(
              bookId: bookId,
              title: 'Chapter',
              content: const Value('already parsed'),
              contentIndex: 0,
              sortOrder: 0,
            ),
          );

      final chapter = await database.select(database.chapters).getSingle();
      expect(chapter.content, 'already parsed');

      final summaries =
          await BookDao(database).getChapterSummariesForBook(bookId);
      expect(summaries.single.content, isNull);
      expect(
        await BookDao(database).getChapterContent(chapter.id),
        'already parsed',
      );
    });

    test('replaceChapters swaps chapters and nulls progress chapterId',
        () async {
      final dao = BookDao(database);
      final bookId = await database.into(database.books).insert(
            BooksCompanion.insert(
              title: 'Migrated',
              filePath: 'migrated.txt',
              format: 'txt',
              fileSize: 1,
            ),
          );
      final oldChapterId = await database.into(database.chapters).insert(
            ChaptersCompanion.insert(
              bookId: bookId,
              title: 'Old misaligned chapter',
              contentIndex: 0,
              sortOrder: 0,
            ),
          );
      await database.into(database.readingProgress).insert(
            ReadingProgressCompanion.insert(
              bookId: Value(bookId),
              chapterId: Value(oldChapterId),
              positionInChapter: const Value(0.4),
              percentage: const Value(0.6),
              totalReadingSeconds: const Value(30),
            ),
          );

      await dao.replaceChapters(bookId, [
        (id) => ChaptersCompanion(
              bookId: Value(id),
              title: const Value('Rebuilt 1'),
              content: const Value('body 1'),
              contentIndex: const Value(0),
              sortOrder: const Value(0),
            ),
        (id) => ChaptersCompanion(
              bookId: Value(id),
              title: const Value('Rebuilt 2'),
              content: const Value('body 2'),
              contentIndex: const Value(1),
              sortOrder: const Value(1),
            ),
      ]);

      final chapters = await dao.getChaptersForBook(bookId);
      expect(chapters.map((c) => c.title).toList(), ['Rebuilt 1', 'Rebuilt 2']);
      expect(chapters.map((c) => c.content).toList(), ['body 1', 'body 2']);
      expect(chapters.any((c) => c.id == oldChapterId), isFalse);

      // Foreign key onDelete:setNull keeps the progress row but drops the stale
      // chapter pointer; position/percentage/duration must survive the rebuild.
      final progress = await dao.getProgress(bookId);
      expect(progress, isNotNull);
      expect(progress!.chapterId, isNull);
      expect(progress.positionInChapter, 0.4);
      expect(progress.percentage, 0.6);
      expect(progress.totalReadingSeconds, 30);
    });

    test('session progress inserts missing row and preserves percentage',
        () async {
      final bookId = await database.into(database.books).insert(
            BooksCompanion.insert(
              title: 'Book',
              filePath: 'book.txt',
              format: 'txt',
              fileSize: 1,
            ),
          );
      final chapterId = await database.into(database.chapters).insert(
            ChaptersCompanion.insert(
              bookId: bookId,
              title: 'Chapter',
              contentIndex: 0,
              sortOrder: 0,
            ),
          );
      final dao = ProgressDao(database);

      await dao.saveSessionProgress(
        bookId: bookId,
        chapterId: chapterId,
        positionInChapter: 0.25,
        totalReadingSeconds: 5,
      );
      await dao.saveProgress(
        bookId: bookId,
        chapterId: chapterId,
        positionInChapter: 0.5,
        percentage: 0.8,
        totalReadingSeconds: 10,
      );
      await dao.saveSessionProgress(
        bookId: bookId,
        chapterId: chapterId,
        positionInChapter: 0.75,
        totalReadingSeconds: 15,
      );

      final progress = await dao.getProgress(bookId);
      expect(progress, isNotNull);
      expect(progress!.positionInChapter, 0.75);
      expect(progress.percentage, 0.8);
      expect(progress.totalReadingSeconds, 15);
    });

    test('FTS treats user punctuation as literal search text', () async {
      await database.into(database.books).insert(
            BooksCompanion.insert(
              title: 'Dart "Guide"',
              filePath: 'guide.txt',
              format: 'txt',
              fileSize: 1,
            ),
          );

      final results = await SearchService(database).search('Dart "Guide"');

      expect(results, hasLength(1));
      expect(results.single.title, 'Dart "Guide"');
    });

    test('FTS note search ranks denser matches before weaker matches',
        () async {
      final bookId = await database.into(database.books).insert(
            BooksCompanion.insert(
              title: 'Search Ranking',
              filePath: 'ranking.txt',
              format: 'txt',
              fileSize: 1,
            ),
          );
      await database.into(database.notes).insert(
            NotesCompanion.insert(
              bookId: bookId,
              content: const Value('needle'),
            ),
          );
      await database.into(database.notes).insert(
            NotesCompanion.insert(
              bookId: bookId,
              content: const Value('needle needle needle needle'),
            ),
          );

      final notes = await database.searchNotes('"needle"', limit: 1);

      expect(notes, hasLength(1));
      expect(notes.single.content, 'needle needle needle needle');
    });

    test('global note search returns a reader locator', () async {
      final bookId = await database.into(database.books).insert(
            BooksCompanion.insert(
              title: 'Locator Notes',
              filePath: 'locator.txt',
              format: 'txt',
              fileSize: 1,
            ),
          );
      final chapterId = await database.into(database.chapters).insert(
            ChaptersCompanion.insert(
              bookId: bookId,
              title: 'Chapter 1',
              content: const Value('before 方源 after'),
              contentIndex: 0,
              sortOrder: 0,
            ),
          );
      await database.into(database.notes).insert(
            NotesCompanion.insert(
              bookId: bookId,
              chapterId: Value(chapterId),
              selectedText: const Value('方源'),
              content: const Value('人物笔记'),
              positionStart: const Value(7),
              positionEnd: const Value(9),
            ),
          );

      final results = await SearchService(database).search('方源');
      final note = results.singleWhere((result) => result.type == 'note');

      expect(note.locator?.bookId, bookId);
      expect(note.locator?.chapterId, chapterId);
      expect(note.locator?.textOffsetStart, 7);
      expect(note.locator?.textOffsetEnd, 9);
      expect(note.locator?.selectedText, '方源');
    });

    test('FTS chapter search respects caller limits', () async {
      final bookId = await database.into(database.books).insert(
            BooksCompanion.insert(
              title: 'Chapter Search',
              filePath: 'chapter-search.txt',
              format: 'txt',
              fileSize: 1,
            ),
          );
      for (var index = 0; index < 4; index++) {
        await database.into(database.chapters).insert(
              ChaptersCompanion.insert(
                bookId: bookId,
                title: 'Chapter $index',
                content: Value('galaxy term in chapter $index'),
                contentIndex: index,
                sortOrder: index,
              ),
            );
      }

      final chapters = await database.searchChapters('"galaxy"', limit: 2);

      expect(chapters, hasLength(2));
      expect(chapters.map((chapter) => chapter.chapterTitle), [
        'Chapter 0',
        'Chapter 1',
      ]);
    });

    test('creates performance indexes for common app queries', () async {
      final indexes = await _indexNames(database);

      expect(
        indexes,
        containsAll({
          'idx_books_reading_status',
          'idx_books_created_at',
          'idx_books_title',
          'idx_books_author_title',
          'idx_books_file_hash',
          'idx_books_series',
          'idx_book_collections_sort',
          'idx_book_collection_items_book',
          'idx_reading_progress_duration',
          'idx_chapters_book_sort',
          'idx_chapters_book_content_index',
          'idx_notes_book_created',
          'idx_notes_book_type_created',
          'idx_note_tags_tag_note',
          'idx_note_relations_note2_note1',
          'idx_ai_messages_conversation_created',
          'idx_ai_conversations_created',
          'idx_ai_providers_default',
          'idx_ai_skills_enabled',
          'idx_ai_personas_book',
          'idx_vocabulary_updated',
          'idx_vocabulary_chapter',
          'idx_dictionary_sources_ready',
          'idx_dictionary_entries_lookup',
          'idx_dictionary_entries_source',
          'idx_dictionary_aliases_lookup',
        }),
      );
    });

    test('creates custom collection tables', () async {
      final tables = await _tableNames(database);
      expect(
        tables,
        containsAll({
          'book_collections',
          'book_collection_items',
          'vocabulary_entries',
          'dictionary_sources',
          'dictionary_entries',
          'dictionary_aliases',
          'book_reading_settings',
        }),
      );
    });

    test('cascades dictionary index data when a source is deleted', () async {
      final sourceId = await database.into(database.dictionarySources).insert(
            DictionarySourcesCompanion.insert(
              name: 'Dictionary',
              formatVersion: '2.4.2',
              dataFilePath: 'dictionary.dict',
            ),
          );
      await database.into(database.dictionaryEntries).insert(
            DictionaryEntriesCompanion.insert(
              sourceId: sourceId,
              entryIndex: 0,
              headword: 'word',
              normalizedHeadword: 'word',
              dataOffset: 0,
              dataSize: 4,
            ),
          );
      await database.into(database.dictionaryAliases).insert(
            DictionaryAliasesCompanion.insert(
              sourceId: sourceId,
              alias: 'alias',
              normalizedAlias: 'alias',
              targetEntryIndex: 0,
            ),
          );

      await (database.delete(database.dictionarySources)
            ..where((source) => source.id.equals(sourceId)))
          .go();

      expect(await database.select(database.dictionaryEntries).get(), isEmpty);
      expect(await database.select(database.dictionaryAliases).get(), isEmpty);
    });

    test('creates AI agent metadata tables and message metadata column',
        () async {
      final tables = await _tableNames(database);
      expect(tables, containsAll({'ai_skills', 'ai_personas'}));

      final aiMessageColumns = await _columnNames(database, 'ai_messages');
      expect(aiMessageColumns, contains('metadata_json'));

      final skillId = await database.into(database.aiSkills).insert(
            AiSkillsCompanion.insert(
              name: 'Skill',
              contentMarkdown: 'Use tools.',
            ),
          );
      final personaId = await database.into(database.aiPersonas).insert(
            AiPersonasCompanion.insert(
              name: 'Persona',
              type: 'custom',
            ),
          );

      expect(skillId, greaterThan(0));
      expect(personaId, greaterThan(0));
    });

    test('stores only supported manual reading status values', () async {
      final bookId = await database.into(database.books).insert(
            BooksCompanion.insert(
              title: 'Status',
              filePath: 'status.txt',
              format: 'txt',
              fileSize: 1,
            ),
          );
      final dao = BookDao(database);

      expect((await dao.getBookById(bookId))?.readingStatus, isNull);
      expect(
        await dao.updateBookReadingStatus(bookId, 'paused'),
        1,
      );
      expect((await dao.getBookById(bookId))?.readingStatus, 'paused');
      expect(
        () => dao.updateBookReadingStatus(bookId, 'invalid'),
        throwsA(isA<SqliteException>()),
      );
      await dao.updateBookReadingStatus(bookId, null);
      expect((await dao.getBookById(bookId))?.readingStatus, isNull);
    });
  });

  test('migrates v8 books to nullable manual reading status', () async {
    final executor = NativeDatabase.memory(setup: (raw) {
      raw.execute(_v2Schema.first);
      raw.execute(
        "INSERT INTO books "
        "(id, title, author, file_path, format, file_size) "
        "VALUES (7, '旧书', '', 'legacy.txt', 'txt', 12)",
      );
      raw.execute('PRAGMA user_version = 8');
    });
    final database = AppDatabase.connect(executor);
    addTearDown(database.close);

    final migrated = await (database.select(database.books)
          ..where((book) => book.id.equals(7)))
        .getSingle();
    expect(migrated.title, '旧书');
    expect(migrated.readingStatus, isNull);
    expect(
      await _columnNames(database, 'books'),
      contains('reading_status'),
    );
    expect(
      await _indexNames(database),
      contains('idx_books_reading_status'),
    );
  });

  test('migrates v9 books to custom collection tables', () async {
    final executor = NativeDatabase.memory(setup: (raw) {
      raw.execute(_v2Schema.first);
      raw.execute('ALTER TABLE books ADD COLUMN reading_status TEXT NULL');
      raw.execute(
        "INSERT INTO books "
        "(id, title, author, file_path, format, file_size, reading_status) "
        "VALUES (9, '迁移前的书', '', 'legacy.txt', 'txt', 12, 'reading')",
      );
      raw.execute('PRAGMA user_version = 9');
    });
    final database = AppDatabase.connect(executor);
    addTearDown(database.close);

    final migratedBook = await database.select(database.books).getSingle();
    expect(migratedBook.id, 9);
    expect(migratedBook.readingStatus, 'reading');
    expect(
      await _tableNames(database),
      containsAll({'book_collections', 'book_collection_items'}),
    );
    expect(
      await _indexNames(database),
      containsAll({
        'idx_book_collections_sort',
        'idx_book_collection_items_book',
      }),
    );
  });

  test('migrates v10 books to nullable content hash', () async {
    final executor = NativeDatabase.memory(setup: (raw) {
      raw.execute(_v2Schema.first);
      raw.execute('ALTER TABLE books ADD COLUMN reading_status TEXT NULL');
      raw.execute(
        "INSERT INTO books "
        "(id, title, author, file_path, format, file_size, reading_status) "
        "VALUES (10, '未建哈希的书', '', 'legacy.txt', 'txt', 12, NULL)",
      );
      raw.execute('PRAGMA user_version = 10');
    });
    final database = AppDatabase.connect(executor);
    addTearDown(database.close);

    final migrated = await database.select(database.books).getSingle();
    expect(migrated.id, 10);
    expect(migrated.fileHash, isNull);
    expect(await _columnNames(database, 'books'), contains('file_hash'));
    expect(await _indexNames(database), contains('idx_books_file_hash'));
  });

  test('migrates v11 books to nullable series metadata', () async {
    final executor = NativeDatabase.memory(setup: (raw) {
      raw.execute(_v2Schema.first);
      raw.execute('ALTER TABLE books ADD COLUMN reading_status TEXT NULL');
      raw.execute('ALTER TABLE books ADD COLUMN file_hash TEXT NULL');
      raw.execute(
        "INSERT INTO books "
        "(id, title, author, file_path, format, file_size, file_hash) "
        "VALUES (11, '系列迁移', '', 'legacy.txt', 'txt', 12, NULL)",
      );
      raw.execute('PRAGMA user_version = 11');
    });
    final database = AppDatabase.connect(executor);
    addTearDown(database.close);

    final migrated = await database.select(database.books).getSingle();
    expect(migrated.id, 11);
    expect(migrated.seriesName, isNull);
    expect(migrated.seriesIndex, isNull);
    expect(
      await _columnNames(database, 'books'),
      containsAll({'series_name', 'series_index'}),
    );
    expect(await _indexNames(database), contains('idx_books_series'));
  });

  test('migrates v12 books to per-book TTS settings', () async {
    final executor = NativeDatabase.memory(setup: (raw) {
      raw.execute(_v2Schema.first);
      raw.execute('PRAGMA user_version = 12');
    });
    final database = AppDatabase.connect(executor);
    addTearDown(database.close);

    expect(await _tableNames(database), contains('book_tts_settings'));
    final bookId = await database.into(database.books).insert(
          BooksCompanion.insert(
            title: 'TTS 迁移',
            filePath: 'tts.txt',
            format: 'txt',
            fileSize: 12,
          ),
        );
    await BookTtsSettingsDao(database).save(
      bookId: bookId,
      language: 'zh-TW',
      voiceName: '测试声音',
      voiceLocale: 'zh-TW',
      speechRate: 0.8,
      sleepTimerOption: 'endOfChapter',
    );

    final settings =
        await database.select(database.bookTtsSettings).getSingle();
    expect(settings.bookId, bookId);
    expect(settings.voiceName, '测试声音');
  });

  test('migrates v13 databases to vocabulary schema', () async {
    final executor = NativeDatabase.memory(setup: (raw) {
      raw.execute(_v2Schema[0]);
      raw.execute(_v2Schema[1]);
      raw.execute('PRAGMA user_version = 13');
    });
    final database = AppDatabase.connect(executor);
    addTearDown(database.close);

    expect(await _tableNames(database), contains('vocabulary_entries'));
    expect(
      await _columnNames(database, 'vocabulary_entries'),
      containsAll({
        'book_id',
        'chapter_id',
        'term',
        'normalized_term',
        'definition',
        'context_text',
        'position_start',
        'position_end',
        'created_at',
        'updated_at',
      }),
    );
    expect(
      await _indexNames(database),
      containsAll({'idx_vocabulary_updated', 'idx_vocabulary_chapter'}),
    );

    final bookId = await database.into(database.books).insert(
          BooksCompanion.insert(
            title: '迁移生词本',
            filePath: 'legacy.txt',
            format: 'txt',
            fileSize: 1,
          ),
        );
    await database.into(database.vocabularyEntries).insert(
          VocabularyEntriesCompanion.insert(
            bookId: bookId,
            term: '迁移',
            normalizedTerm: '迁移',
          ),
        );
    expect(
      (await database.select(database.vocabularyEntries).getSingle()).term,
      '迁移',
    );
  });

  test('migrates v14 databases to offline dictionary schema', () async {
    final executor = NativeDatabase.memory(setup: (raw) {
      raw.execute(_v2Schema[0]);
      raw.execute('PRAGMA user_version = 14');
    });
    final database = AppDatabase.connect(executor);
    addTearDown(database.close);

    expect(
      await _tableNames(database),
      containsAll({
        'dictionary_sources',
        'dictionary_entries',
        'dictionary_aliases',
      }),
    );
    expect(
      await _indexNames(database),
      containsAll({
        'idx_dictionary_sources_ready',
        'idx_dictionary_entries_lookup',
        'idx_dictionary_entries_source',
        'idx_dictionary_aliases_lookup',
      }),
    );

    final sourceId = await database.into(database.dictionarySources).insert(
          DictionarySourcesCompanion.insert(
            name: '迁移词典',
            formatVersion: '2.4.2',
            dataFilePath: 'migrated.dict',
          ),
        );
    expect(sourceId, greaterThan(0));
  });

  test('migrates v15 databases to per-book reading settings', () async {
    final executor = NativeDatabase.memory(setup: (raw) {
      raw.execute(_v2Schema[0]);
      raw.execute('PRAGMA user_version = 15');
    });
    final database = AppDatabase.connect(executor);
    addTearDown(database.close);

    expect(await _tableNames(database), contains('book_reading_settings'));
    expect(
      await _columnNames(database, 'book_reading_settings'),
      containsAll({
        'book_id',
        'font_size',
        'line_height',
        'margin',
        'font_family',
        'paragraph_spacing',
        'letter_spacing',
        'word_spacing',
        'bold_text',
        'text_alignment',
        'paragraph_indent',
        'pdf_crop_amount',
        'pdf_contrast',
        'pdf_page_layout',
        'top_content_padding',
        'page_turn_effect',
        'updated_at',
      }),
    );

    final bookId = await database.into(database.books).insert(
          BooksCompanion.insert(
            title: '迁移排版',
            filePath: 'layout.txt',
            format: 'txt',
            fileSize: 1,
          ),
        );
    await database.into(database.bookReadingSettings).insert(
          BookReadingSettingsCompanion.insert(
            bookId: Value(bookId),
            fontSize: 20,
            lineHeight: 1.8,
            margin: 20,
            paragraphSpacing: 12,
            letterSpacing: 0.5,
            topContentPadding: 16,
            pageTurnEffect: 'curl',
          ),
        );
    expect(
      (await database.select(database.bookReadingSettings).getSingle()).bookId,
      bookId,
    );
  });

  test('migrates v16 reading settings to advanced typography fields', () async {
    final executor = NativeDatabase.memory(setup: (raw) {
      raw.execute(_v2Schema[0]);
      raw.execute('''
        CREATE TABLE book_reading_settings (
          book_id INTEGER NOT NULL PRIMARY KEY
            REFERENCES books(id) ON DELETE CASCADE,
          font_size REAL NOT NULL,
          line_height REAL NOT NULL,
          margin REAL NOT NULL,
          font_family TEXT NULL,
          paragraph_spacing REAL NOT NULL,
          letter_spacing REAL NOT NULL,
          top_content_padding REAL NOT NULL,
          page_turn_effect TEXT NOT NULL,
          updated_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now'))
        )
      ''');
      raw.execute(
        "INSERT INTO books "
        "(id, title, author, file_path, format, file_size) "
        "VALUES (16, '旧排版', '', 'layout.txt', 'txt', 1)",
      );
      raw.execute('''
        INSERT INTO book_reading_settings (
          book_id, font_size, line_height, margin, font_family,
          paragraph_spacing, letter_spacing, top_content_padding,
          page_turn_effect
        ) VALUES (16, 20, 1.8, 20, NULL, 12, 0.5, 16, 'curl')
      ''');
      raw.execute('PRAGMA user_version = 16');
    });
    final database = AppDatabase.connect(executor);
    addTearDown(database.close);

    final settings =
        await database.select(database.bookReadingSettings).getSingle();
    expect(settings.bookId, 16);
    expect(settings.wordSpacing, 0);
    expect(settings.boldText, isFalse);
    expect(settings.textAlignment, 'start');
    expect(settings.paragraphIndent, 0);
    expect(
      await _columnNames(database, 'book_reading_settings'),
      containsAll({
        'word_spacing',
        'bold_text',
        'text_alignment',
        'paragraph_indent',
      }),
    );
  });

  test('migrates v17 reading settings to PDF display fields', () async {
    final executor = NativeDatabase.memory(setup: (raw) {
      raw.execute(_v2Schema[0]);
      raw.execute('''
        CREATE TABLE book_reading_settings (
          book_id INTEGER NOT NULL PRIMARY KEY
            REFERENCES books(id) ON DELETE CASCADE,
          font_size REAL NOT NULL,
          line_height REAL NOT NULL,
          margin REAL NOT NULL,
          font_family TEXT NULL,
          paragraph_spacing REAL NOT NULL,
          letter_spacing REAL NOT NULL,
          word_spacing REAL NOT NULL DEFAULT 0,
          bold_text INTEGER NOT NULL DEFAULT 0,
          text_alignment TEXT NOT NULL DEFAULT 'start',
          paragraph_indent INTEGER NOT NULL DEFAULT 0,
          top_content_padding REAL NOT NULL,
          page_turn_effect TEXT NOT NULL,
          updated_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now'))
        )
      ''');
      raw.execute(
        "INSERT INTO books "
        "(id, title, author, file_path, format, file_size) "
        "VALUES (17, '旧 PDF', '', 'legacy.pdf', 'pdf', 1)",
      );
      raw.execute('''
        INSERT INTO book_reading_settings (
          book_id, font_size, line_height, margin, font_family,
          paragraph_spacing, letter_spacing, word_spacing, bold_text,
          text_alignment, paragraph_indent, top_content_padding,
          page_turn_effect
        ) VALUES (
          17, 21, 1.9, 24, NULL, 14, 0.6, 1.2, 1,
          'justify', 2, 20, 'slide'
        )
      ''');
      raw.execute('PRAGMA user_version = 17');
    });
    final database = AppDatabase.connect(executor);
    addTearDown(database.close);

    final settings =
        await database.select(database.bookReadingSettings).getSingle();
    expect(settings.bookId, 17);
    expect(settings.fontSize, 21);
    expect(settings.wordSpacing, 1.2);
    expect(settings.boldText, isTrue);
    expect(settings.pdfCropAmount, 0);
    expect(settings.pdfContrast, 1);
    expect(settings.pdfPageLayout, 'single');
    expect(
      await _columnNames(database, 'book_reading_settings'),
      containsAll({
        'pdf_crop_amount',
        'pdf_contrast',
        'pdf_page_layout',
      }),
    );
  });

  test('migrates v7 AI tables to current schema', () async {
    final executor = NativeDatabase.memory(setup: (raw) {
      for (final statement in _v2Schema) {
        raw.execute(statement);
      }
      raw.execute('ALTER TABLE chapters ADD COLUMN content TEXT NULL');
      raw.execute(
          "ALTER TABLE notes ADD COLUMN type TEXT NOT NULL DEFAULT 'note'");
      raw.execute(
        "INSERT INTO ai_conversations (id, title) VALUES (12, '旧会话')",
      );
      raw.execute(
        "INSERT INTO ai_messages "
        "(id, conversation_id, role, content) "
        "VALUES (34, 12, 'assistant', '迁移前的回答')",
      );
      raw.execute('PRAGMA user_version = 7');
    });
    final database = AppDatabase.connect(executor);
    addTearDown(database.close);

    expect(
        await _columnNames(database, 'ai_messages'), contains('metadata_json'));
    expect(
        await _tableNames(database), containsAll({'ai_skills', 'ai_personas'}));

    final migratedMessage = await (database.select(database.aiMessages)
          ..where((message) => message.id.equals(34)))
        .getSingle();
    expect(migratedMessage.conversationId, 12);
    expect(migratedMessage.content, '迁移前的回答');
    expect(migratedMessage.metadataJson, isNull);

    final indexes = await _indexNames(database);
    expect(indexes, contains('idx_ai_skills_enabled'));
    expect(indexes, contains('idx_ai_personas_book'));
  });

  test('migrates v2 orphaned data without dropping user records', () async {
    final executor = NativeDatabase.memory(setup: (raw) {
      for (final statement in _v2Schema) {
        raw.execute(statement);
      }
      raw.execute('PRAGMA user_version = 2');
      raw.execute(
        "INSERT INTO chapters "
        "(id, book_id, title, content_index, sort_order) "
        "VALUES (7, 42, 'Recovered', 0, 0)",
      );
      raw.execute(
        "INSERT INTO notes "
        "(id, book_id, chapter_id, content) "
        "VALUES (9, 42, 999, 'Keep me')",
      );
      raw.execute(
        'INSERT INTO reading_progress '
        '(book_id, chapter_id, percentage, total_reading_seconds) '
        'VALUES (42, 999, 0.5, 12)',
      );
    });
    final database = AppDatabase.connect(executor);
    addTearDown(database.close);

    final books = await database.select(database.books).get();
    final notes = await database.select(database.notes).get();
    final progress = await database.select(database.readingProgress).get();

    expect(books.single.id, 42);
    expect(books.single.title, '恢复的书籍 #42');
    expect(notes.single.content, 'Keep me');
    expect(notes.single.chapterId, isNull);
    expect(progress.single.percentage, 0.5);
    expect(progress.single.totalReadingSeconds, 12);
    expect(progress.single.chapterId, isNull);

    final indexes = await _indexNames(database);
    expect(indexes, contains('idx_chapters_book_sort'));
    expect(indexes, contains('idx_notes_book_type_created'));
    expect(indexes, contains('idx_ai_messages_conversation_created'));
  });

  test('migrates v3 chapters to the persistent content cache', () async {
    final executor = NativeDatabase.memory(setup: (raw) {
      raw.execute(_v2Schema[0]);
      raw.execute(_v2Schema[1]);
      raw.execute('PRAGMA user_version = 3');
      raw.execute(
        "INSERT INTO books "
        "(id, title, author, file_path, format, file_size) "
        "VALUES (1, 'Book', '', 'book.txt', 'txt', 1)",
      );
      raw.execute(
        "INSERT INTO chapters "
        "(id, book_id, title, content_index, sort_order) "
        "VALUES (1, 1, 'Chapter', 0, 0)",
      );
    });
    final database = AppDatabase.connect(executor);
    addTearDown(database.close);

    final chapter = await database.select(database.chapters).getSingle();
    expect(chapter.content, isNull);

    await BookDao(database).cacheChapterContents({chapter.id: 'cached'});
    final cached = await database.select(database.chapters).getSingle();
    expect(cached.content, 'cached');
  });

  test('migrates v18 databases to the reading_sessions table', () async {
    final executor = NativeDatabase.memory(setup: (raw) {
      raw.execute(_v2Schema[0]);
      raw.execute('PRAGMA user_version = 18');
      raw.execute(
        "INSERT INTO books "
        "(id, title, author, file_path, format, file_size) "
        "VALUES (1, '旧书', '', 'legacy.txt', 'txt', 1)",
      );
    });
    final database = AppDatabase.connect(executor);
    addTearDown(database.close);

    // 老库里的书要留下，新表要建出来并且可写。
    expect(await database.select(database.books).getSingle(), isNotNull);
    expect(await _indexNames(database), containsAll(
      ['idx_reading_sessions_date', 'idx_reading_sessions_book_date'],
    ));

    final dao = ProgressDao(database);
    await dao.addSessionSeconds(bookId: 1, date: '2026-09-05', seconds: 42);
    expect(await dao.secondsOnDate('2026-09-05'), 42);
  });

  test('migrates v19 databases to the chapters_trigram index', () async {
    final executor = NativeDatabase.memory(setup: (raw) {
      raw.execute(_v2Schema[0]);
      raw.execute(_v19ChaptersSchema);
      raw.execute('PRAGMA user_version = 19');
      raw.execute(
        "INSERT INTO books "
        "(id, title, author, file_path, format, file_size) "
        "VALUES (1, '旧书', '', 'legacy.txt', 'txt', 1)",
      );
      raw.execute(
        "INSERT INTO chapters (id, book_id, title, content, "
        "content_index, sort_order) "
        "VALUES (1, 1, '第一章', '这段正文讨论流水线技术。', 0, 0)",
      );
    });
    final database = AppDatabase.connect(executor);
    addTearDown(database.close);

    expect(await _tableNames(database), contains('chapters_trigram'));

    // 关键：rebuild 要把升级前就存在的正文灌进索引。只建表不灌数据的话，
    // 老书永远搜不到，而且不会报任何错。
    final hits = await database
        .customSelect(
          'SELECT count(*) AS n FROM chapters_trigram '
          "WHERE chapters_trigram MATCH '\"流水线\"'",
        )
        .getSingle();
    expect(hits.read<int>('n'), 1);
  });

  test('chapters_trigram migration is idempotent on rerun', () async {
    final executor = NativeDatabase.memory(setup: (raw) {
      raw.execute(_v2Schema[0]);
      raw.execute(_v19ChaptersSchema);
      // 表已经在但版本号仍停在 19，模拟迁移中断后重跑。
      raw.execute(
        'CREATE VIRTUAL TABLE chapters_trigram USING fts5('
        "content, content='chapters', content_rowid='id', "
        "tokenize='trigram')",
      );
      raw.execute('PRAGMA user_version = 19');
    });
    final database = AppDatabase.connect(executor);
    addTearDown(database.close);

    expect(await _tableNames(database), contains('chapters_trigram'));
  });

  test('reading_sessions migration is idempotent on rerun', () async {
    final executor = NativeDatabase.memory(setup: (raw) {
      raw.execute(_v2Schema[0]);
      // 已经有表但版本号还停在 18，模拟中断后重跑迁移。
      raw.execute('''
        CREATE TABLE reading_sessions (
          id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
          book_id INTEGER NULL REFERENCES books (id) ON DELETE SET NULL,
          date TEXT NOT NULL,
          seconds INTEGER NOT NULL DEFAULT 0
        )
      ''');
      raw.execute(
        "INSERT INTO reading_sessions (book_id, date, seconds) "
        "VALUES (NULL, '2026-09-01', 77)",
      );
      raw.execute('PRAGMA user_version = 18');
    });
    final database = AppDatabase.connect(executor);
    addTearDown(database.close);

    // 迁移不能把已有记录冲掉。
    expect(await ProgressDao(database).secondsOnDate('2026-09-01'), 77);
  });
}

Future<Set<String>> _indexNames(AppDatabase database) async {
  final rows = await database
      .customSelect("SELECT name FROM sqlite_master WHERE type = 'index'")
      .get();
  return rows.map((row) => row.read<String>('name')).toSet();
}

Future<Set<String>> _tableNames(AppDatabase database) async {
  final rows = await database
      .customSelect("SELECT name FROM sqlite_master WHERE type = 'table'")
      .get();
  return rows.map((row) => row.read<String>('name')).toSet();
}

Future<Set<String>> _columnNames(AppDatabase database, String table) async {
  final rows = await database.customSelect('PRAGMA table_info($table)').get();
  return rows.map((row) => row.read<String>('name')).toSet();
}

const _v19ChaptersSchema = '''
  CREATE TABLE chapters (
    id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    book_id INTEGER NOT NULL,
    title TEXT NOT NULL,
    content TEXT NULL,
    content_index INTEGER NOT NULL,
    sort_order INTEGER NOT NULL
  )
''';

const _v2Schema = [
  '''
  CREATE TABLE books (
    id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    title TEXT NOT NULL,
    author TEXT NOT NULL DEFAULT '',
    cover_path TEXT NULL,
    file_path TEXT NOT NULL,
    format TEXT NOT NULL,
    file_size INTEGER NOT NULL,
    description TEXT NULL,
    created_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now')),
    updated_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now'))
  )
  ''',
  '''
  CREATE TABLE chapters (
    id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    book_id INTEGER NOT NULL,
    title TEXT NOT NULL,
    content_index INTEGER NOT NULL,
    sort_order INTEGER NOT NULL
  )
  ''',
  '''
  CREATE TABLE reading_progress (
    book_id INTEGER NOT NULL PRIMARY KEY,
    chapter_id INTEGER NOT NULL,
    position_in_chapter REAL NOT NULL DEFAULT 0.0,
    percentage REAL NOT NULL DEFAULT 0.0,
    total_reading_seconds INTEGER NOT NULL DEFAULT 0,
    last_read_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now'))
  )
  ''',
  '''
  CREATE TABLE notes (
    id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    book_id INTEGER NOT NULL,
    chapter_id INTEGER NULL,
    selected_text TEXT NULL,
    content TEXT NULL,
    page_number INTEGER NULL,
    position_start INTEGER NULL,
    position_end INTEGER NULL,
    created_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now')),
    updated_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now'))
  )
  ''',
  '''
  CREATE TABLE tags (
    id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL UNIQUE,
    color TEXT NULL,
    created_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now'))
  )
  ''',
  'CREATE TABLE note_tags (note_id INTEGER NOT NULL, tag_id INTEGER NOT NULL, PRIMARY KEY (note_id, tag_id))',
  'CREATE TABLE note_relations (note_id1 INTEGER NOT NULL, note_id2 INTEGER NOT NULL, PRIMARY KEY (note_id1, note_id2))',
  '''
  CREATE TABLE ai_providers (
    id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL,
    type TEXT NOT NULL,
    base_url TEXT NOT NULL,
    api_key TEXT NULL,
    model_name TEXT NOT NULL,
    is_default INTEGER NOT NULL DEFAULT 0,
    extra_config TEXT NULL
  )
  ''',
  '''
  CREATE TABLE ai_conversations (
    id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    book_id INTEGER NULL,
    title TEXT NULL,
    created_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now'))
  )
  ''',
  '''
  CREATE TABLE ai_messages (
    id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    conversation_id INTEGER NOT NULL,
    role TEXT NOT NULL,
    content TEXT NOT NULL,
    created_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now'))
  )
  ''',
];
