// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'vocabulary_dao.dart';

// ignore_for_file: type=lint
mixin _$VocabularyDaoMixin on DatabaseAccessor<AppDatabase> {
  $BooksTable get books => attachedDatabase.books;
  $ChaptersTable get chapters => attachedDatabase.chapters;
  $VocabularyEntriesTable get vocabularyEntries =>
      attachedDatabase.vocabularyEntries;
  VocabularyDaoManager get managers => VocabularyDaoManager(this);
}

class VocabularyDaoManager {
  final _$VocabularyDaoMixin _db;
  VocabularyDaoManager(this._db);
  $$BooksTableTableManager get books =>
      $$BooksTableTableManager(_db.attachedDatabase, _db.books);
  $$ChaptersTableTableManager get chapters =>
      $$ChaptersTableTableManager(_db.attachedDatabase, _db.chapters);
  $$VocabularyEntriesTableTableManager get vocabularyEntries =>
      $$VocabularyEntriesTableTableManager(
          _db.attachedDatabase, _db.vocabularyEntries);
}
