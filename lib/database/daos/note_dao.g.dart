// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'note_dao.dart';

// ignore_for_file: type=lint
mixin _$NoteDaoMixin on DatabaseAccessor<AppDatabase> {
  $BooksTable get books => attachedDatabase.books;
  $ChaptersTable get chapters => attachedDatabase.chapters;
  $NotesTable get notes => attachedDatabase.notes;
  $TagsTable get tags => attachedDatabase.tags;
  $NoteTagsTable get noteTags => attachedDatabase.noteTags;
  $NoteRelationsTable get noteRelations => attachedDatabase.noteRelations;
  NoteDaoManager get managers => NoteDaoManager(this);
}

class NoteDaoManager {
  final _$NoteDaoMixin _db;
  NoteDaoManager(this._db);
  $$BooksTableTableManager get books =>
      $$BooksTableTableManager(_db.attachedDatabase, _db.books);
  $$ChaptersTableTableManager get chapters =>
      $$ChaptersTableTableManager(_db.attachedDatabase, _db.chapters);
  $$NotesTableTableManager get notes =>
      $$NotesTableTableManager(_db.attachedDatabase, _db.notes);
  $$TagsTableTableManager get tags =>
      $$TagsTableTableManager(_db.attachedDatabase, _db.tags);
  $$NoteTagsTableTableManager get noteTags =>
      $$NoteTagsTableTableManager(_db.attachedDatabase, _db.noteTags);
  $$NoteRelationsTableTableManager get noteRelations =>
      $$NoteRelationsTableTableManager(_db.attachedDatabase, _db.noteRelations);
}
