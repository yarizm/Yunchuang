import 'package:drift/drift.dart';
import '../app_database.dart';
import '../tables/notes.dart';
import '../tables/tags.dart';
import '../tables/note_tags.dart';
import '../tables/note_relations.dart';

part 'note_dao.g.dart';

@DriftAccessor(tables: [Notes, Tags, NoteTags, NoteRelations])
class NoteDao extends DatabaseAccessor<AppDatabase> with _$NoteDaoMixin {
  NoteDao(super.db);

  Future<List<Note>> getNotesForBook(int bookId) => (select(notes)
        ..where((n) => n.bookId.equals(bookId))
        ..orderBy([(n) => OrderingTerm.desc(n.createdAt)]))
      .get();

  Future<List<Note>> getAllNotes() =>
      (select(notes)..orderBy([(n) => OrderingTerm.desc(n.createdAt)])).get();

  Future<Note?> getNoteById(int id) =>
      (select(notes)..where((n) => n.id.equals(id))).getSingleOrNull();

  Future<int> insertNote(NotesCompanion entry) => into(notes).insert(entry);

  Future<bool> updateNote(NotesCompanion entry) => update(notes).replace(entry);

  Future<int> deleteNote(int id) =>
      (delete(notes)..where((n) => n.id.equals(id))).go();

  // Bookmarks (stored as Notes with type='bookmark')

  Future<int> addBookmark({
    required int bookId,
    required int? chapterId,
    required double position,
  }) {
    return into(notes).insert(NotesCompanion.insert(
      bookId: bookId,
      chapterId: Value(chapterId),
      type: const Value('bookmark'),
      positionStart: Value((position * 10000).round()),
    ));
  }

  Future<List<Note>> bookmarksForBook(int bookId) => (select(notes)
        ..where((n) => n.bookId.equals(bookId) & n.type.equals('bookmark'))
        ..orderBy([(n) => OrderingTerm.desc(n.createdAt)]))
      .get();

  Future<Note?> bookmarkFor(int bookId, int? chapterId) {
    final q = select(notes)
      ..where((n) => n.bookId.equals(bookId) & n.type.equals('bookmark'));
    if (chapterId != null) {
      q.where((n) => n.chapterId.equals(chapterId));
    } else {
      q.where((n) => n.chapterId.isNull());
    }
    return (q..limit(1)).getSingleOrNull();
  }

  // Tags
  Future<List<Tag>> getAllTags() => select(tags).get();

  Future<int> insertTag(TagsCompanion entry) => into(tags).insert(entry);

  Future<Tag?> findTagByName(String name) =>
      (select(tags)..where((t) => t.name.equals(name))).getSingleOrNull();

  /// 删掉标签本身；note_tags 上的引用靠外键 cascade 一起清掉。
  Future<void> deleteTag(int tagId) =>
      (delete(tags)..where((t) => t.id.equals(tagId))).go();

  Future<List<Tag>> getTagsForNote(int noteId) async {
    final tagIds = await (select(noteTags)
          ..where((nt) => nt.noteId.equals(noteId)))
        .get()
        .then((rows) => rows.map((r) => r.tagId).toList());
    if (tagIds.isEmpty) return [];
    return (select(tags)..where((t) => t.id.isIn(tagIds))).get();
  }

  Future<Map<int, List<Tag>>> getTagsForNotes(List<int> noteIds) async {
    if (noteIds.isEmpty) return {};
    final rows =
        await (select(noteTags)..where((nt) => nt.noteId.isIn(noteIds))).get();
    if (rows.isEmpty) return {for (final id in noteIds) id: []};
    final allTagIds = rows.map((r) => r.tagId).toSet().toList();
    final allTags =
        await (select(tags)..where((t) => t.id.isIn(allTagIds))).get();
    final tagMap = {for (final t in allTags) t.id: t};
    final result = <int, List<Tag>>{};
    for (final id in noteIds) {
      result[id] = [];
    }
    for (final row in rows) {
      final tag = tagMap[row.tagId];
      if (tag != null) {
        result[row.noteId]!.add(tag);
      }
    }
    return result;
  }

  /// 整体替换一条笔记的标签。先删后插放在一个事务里：插到一半失败时
  /// 回滚到原来的标签，而不是留下一条什么标签都没有的笔记。
  Future<void> setTagsForNote(int noteId, List<int> tagIds) {
    return transaction(() async {
      await (delete(noteTags)..where((nt) => nt.noteId.equals(noteId))).go();
      for (final tagId in tagIds) {
        await into(noteTags).insert(NoteTagsCompanion.insert(
          noteId: noteId,
          tagId: tagId,
        ));
      }
    });
  }

  // Note relations
  Future<List<NoteRelation>> getRelationsForNote(int noteId) =>
      (select(noteRelations)
            ..where((r) => r.noteId1.equals(noteId) | r.noteId2.equals(noteId)))
          .get();

  Future<void> createRelation(int noteId1, int noteId2) async {
    final smaller = noteId1 < noteId2 ? noteId1 : noteId2;
    final larger = noteId1 < noteId2 ? noteId2 : noteId1;
    await into(noteRelations).insert(
      NoteRelation(noteId1: smaller, noteId2: larger),
      mode: InsertMode.insertOrIgnore,
    );
  }
}
