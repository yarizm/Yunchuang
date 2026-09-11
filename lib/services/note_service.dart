import 'package:csv/csv.dart';
import 'package:drift/drift.dart';
import '../database/app_database.dart';
import '../database/daos/note_dao.dart';
import '../parsers/csv_importer.dart';

/// 导出用的一条笔记及其上下文。
///
/// 笔记表里只有 bookId / chapterId，导出的文件要给人读，必须带上书名与
/// 章节名——脱离这两者的划线原文没有意义。
class NoteExportRow {
  final Note note;
  final String bookTitle;
  final String? chapterTitle;
  final List<Tag> tags;

  const NoteExportRow({
    required this.note,
    required this.bookTitle,
    this.chapterTitle,
    this.tags = const [],
  });
}

/// 笔记类型的中文名。数据库里存的是 note / bookmark / highlight。
String noteTypeLabel(String type) => switch (type) {
      'bookmark' => '书签',
      'highlight' => '划线',
      _ => '笔记',
    };

class NoteService {
  final NoteDao _noteDao;
  final AppDatabase _database;

  NoteService(this._noteDao, this._database);

  Future<List<Note>> getNotesForBook(int bookId) =>
      _noteDao.getNotesForBook(bookId);

  Future<List<Note>> getAllNotes() => _noteDao.getAllNotes();

  Future<Note?> getNoteById(int id) => _noteDao.getNoteById(id);

  Future<int> createNote({
    required int bookId,
    int? chapterId,
    String? selectedText,
    String? content,
    int? pageNumber,
    int? positionStart,
    int? positionEnd,
  }) async {
    return _noteDao.insertNote(NotesCompanion(
      bookId: Value(bookId),
      chapterId: Value(chapterId),
      selectedText: Value(selectedText),
      content: Value(content),
      pageNumber: Value(pageNumber),
      positionStart: Value(positionStart),
      positionEnd: Value(positionEnd),
    ));
  }

  Future<void> updateNote({
    required int noteId,
    String? content,
  }) async {
    final existing = await _noteDao.getNoteById(noteId);
    if (existing == null) return;
    await _noteDao.updateNote(NotesCompanion(
      id: Value(noteId),
      bookId: Value(existing.bookId),
      chapterId: Value(existing.chapterId),
      selectedText: Value(existing.selectedText),
      content: Value(content ?? existing.content),
      pageNumber: Value(existing.pageNumber),
      positionStart: Value(existing.positionStart),
      positionEnd: Value(existing.positionEnd),
      createdAt: Value(existing.createdAt),
      updatedAt: Value(DateTime.now()),
    ));
  }

  Future<void> deleteNote(int noteId) => _noteDao.deleteNote(noteId);

  // Tags
  Future<List<Tag>> getAllTags() => _noteDao.getAllTags();

  Future<int> createTag(String name, {String? color}) =>
      _noteDao.insertTag(TagsCompanion(
        name: Value(name),
        color: Value(color),
      ));

  /// 标签名的长度上限，和 `Tags.name` 的列约束一致。
  static const maxTagNameLength = 50;

  /// 按名字拿标签，没有就建一个。
  ///
  /// 标签名是唯一键，用户在编辑器里手打一个已经存在的名字是常态——直接
  /// `createTag` 会撞 UNIQUE 约束抛错，这里改为复用已有的那条。
  Future<Tag> ensureTag(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError.value(name, 'name', '标签名不能为空');
    }
    if (trimmed.length > maxTagNameLength) {
      throw ArgumentError.value(
        name,
        'name',
        '标签名不能超过 $maxTagNameLength 个字符',
      );
    }
    final existing = await _noteDao.findTagByName(trimmed);
    if (existing != null) return existing;
    await createTag(trimmed);
    // 回读一次，拿到数据库填好的 createdAt 等默认值。
    return (await _noteDao.findTagByName(trimmed))!;
  }

  /// 删掉标签，同时从所有笔记上摘掉它。
  Future<void> deleteTag(int tagId) => _noteDao.deleteTag(tagId);

  Future<List<Tag>> getTagsForNote(int noteId) =>
      _noteDao.getTagsForNote(noteId);

  Future<Map<int, List<Tag>>> getTagsForNotes(List<int> noteIds) =>
      _noteDao.getTagsForNotes(noteIds);

  Future<void> setTagsForNote(int noteId, List<int> tagIds) =>
      _noteDao.setTagsForNote(noteId, tagIds);

  // Relations
  Future<void> createRelation(int noteId1, int noteId2) =>
      _noteDao.createRelation(noteId1, noteId2);

  Future<List<NoteRelation>> getRelationsForNote(int noteId) =>
      _noteDao.getRelationsForNote(noteId);

  /// Imports one file atomically, including its placeholder book and tags.
  Future<int> importNotes(
    List<ImportedNote> importedNotes, {
    String bookTitle = '导入的笔记',
  }) {
    if (importedNotes.isEmpty) return Future.value(0);

    return _database.transaction(() async {
      final normalizedTagsByNote = importedNotes
          .map(
            (note) => note.tags
                .map((tag) => tag.trim())
                .where((tag) => tag.isNotEmpty)
                .toSet(),
          )
          .toList();
      final tagNames = normalizedTagsByNote.expand((tags) => tags).toSet();
      final bookId = await _database.into(_database.books).insert(
            BooksCompanion.insert(
              title: bookTitle,
              filePath: '',
              format: 'imported',
              fileSize: 0,
            ),
          );

      final existingTags = <String, int>{};
      if (tagNames.isNotEmpty) {
        final tagsQuery = _database.select(_database.tags)
          ..where((tag) => tag.name.isIn(tagNames));
        existingTags.addEntries(
          (await tagsQuery.get()).map((tag) => MapEntry(tag.name, tag.id)),
        );
      }

      for (final name in tagNames) {
        if (existingTags.containsKey(name)) continue;
        existingTags[name] = await _database.into(_database.tags).insert(
              TagsCompanion.insert(name: name),
            );
      }

      final noteTagEntries = <NoteTagsCompanion>[];
      for (var index = 0; index < importedNotes.length; index++) {
        final imported = importedNotes[index];
        final noteId = await _database.into(_database.notes).insert(
              NotesCompanion.insert(
                bookId: bookId,
                selectedText: Value(imported.selectedText),
                content: Value(imported.content),
              ),
            );
        for (final name in normalizedTagsByNote[index]) {
          final tagId = existingTags[name];
          if (tagId != null) {
            noteTagEntries.add(
              NoteTagsCompanion.insert(noteId: noteId, tagId: tagId),
            );
          }
        }
      }
      if (noteTagEntries.isNotEmpty) {
        await _database.batch((batch) {
          batch.insertAll(
            _database.noteTags,
            noteTagEntries,
            mode: InsertMode.insertOrIgnore,
          );
        });
      }
      return importedNotes.length;
    });
  }

  /// 给 [notes] 补上书名、章节名与标签。
  ///
  /// 三次批量查询，不按条 N+1。调用方（导出）是一次性动作，不在热路径上。
  Future<List<NoteExportRow>> buildExportRows(List<Note> notes) async {
    if (notes.isEmpty) return const [];

    final bookIds = notes.map((n) => n.bookId).toSet().toList();
    final bookRows = await (_database.select(_database.books)
          ..where((b) => b.id.isIn(bookIds)))
        .get();
    final titlesByBook = {for (final b in bookRows) b.id: b.title};

    final chapterIds =
        notes.map((n) => n.chapterId).whereType<int>().toSet().toList();
    final titlesByChapter = <int, String>{};
    if (chapterIds.isNotEmpty) {
      final chapterRows = await (_database.select(_database.chapters)
            ..where((c) => c.id.isIn(chapterIds)))
          .get();
      for (final c in chapterRows) {
        titlesByChapter[c.id] = c.title;
      }
    }

    final tagsByNote =
        await _noteDao.getTagsForNotes(notes.map((n) => n.id).toList());

    return [
      for (final note in notes)
        NoteExportRow(
          note: note,
          // 书被删掉时笔记会级联删除，理论上取不到 null；兜底避免导出中断。
          bookTitle: titlesByBook[note.bookId] ?? '未知书籍',
          chapterTitle:
              note.chapterId == null ? null : titlesByChapter[note.chapterId],
          tags: tagsByNote[note.id] ?? const [],
        ),
    ];
  }

  /// 按书分组的 Markdown。
  ///
  /// 分组而不是平铺：导出的笔记多半是拿去整理或归档的，按书聚在一起才好读。
  String exportMarkdown(List<NoteExportRow> rows) {
    final buffer = StringBuffer('# 笔记\n\n');
    if (rows.isEmpty) {
      buffer.writeln('_没有笔记_');
      return buffer.toString();
    }
    buffer
      ..writeln('共 ${rows.length} 条')
      ..writeln();

    final byBook = <String, List<NoteExportRow>>{};
    for (final row in rows) {
      byBook.putIfAbsent(row.bookTitle, () => []).add(row);
    }

    for (final entry in byBook.entries) {
      buffer
        ..writeln('## ${entry.key}')
        ..writeln();
      for (final row in entry.value) {
        final note = row.note;
        final date =
            note.createdAt.toLocal().toIso8601String().substring(0, 10);
        final heading = [
          date,
          noteTypeLabel(note.type),
          if (row.chapterTitle != null) row.chapterTitle!,
        ].join(' · ');
        buffer
          ..writeln('### $heading')
          ..writeln();

        final selected = note.selectedText?.trim();
        if (selected != null && selected.isNotEmpty) {
          // 原文按行加引用前缀，多行划线不会塌成一行。
          for (final line in selected.split('\n')) {
            buffer.writeln('> $line');
          }
          buffer.writeln();
        }

        final content = note.content?.trim();
        if (content != null && content.isNotEmpty) {
          buffer
            ..writeln(content)
            ..writeln();
        }

        if (row.tags.isNotEmpty) {
          buffer
            ..writeln(row.tags.map((t) => '#${t.name}').join(' '))
            ..writeln();
        }
      }
    }
    return buffer.toString();
  }

  String exportCsv(List<NoteExportRow> rows) {
    final table = <List<dynamic>>[
      ['书籍', '章节', '类型', '划线原文', '笔记', '标签', '页码', '创建时间', '更新时间'],
      for (final row in rows)
        [
          row.bookTitle,
          row.chapterTitle ?? '',
          noteTypeLabel(row.note.type),
          row.note.selectedText ?? '',
          row.note.content ?? '',
          row.tags.map((t) => t.name).join(' '),
          row.note.pageNumber?.toString() ?? '',
          row.note.createdAt.toUtc().toIso8601String(),
          row.note.updatedAt.toUtc().toIso8601String(),
        ],
    ];
    return const ListToCsvConverter().convert(table);
  }
}
