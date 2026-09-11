// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'book_dao.dart';

// ignore_for_file: type=lint
mixin _$BookDaoMixin on DatabaseAccessor<AppDatabase> {
  $BooksTable get books => attachedDatabase.books;
  $BookCollectionsTable get bookCollections => attachedDatabase.bookCollections;
  $BookCollectionItemsTable get bookCollectionItems =>
      attachedDatabase.bookCollectionItems;
  $ChaptersTable get chapters => attachedDatabase.chapters;
  $ReadingProgressTable get readingProgress => attachedDatabase.readingProgress;
  BookDaoManager get managers => BookDaoManager(this);
}

class BookDaoManager {
  final _$BookDaoMixin _db;
  BookDaoManager(this._db);
  $$BooksTableTableManager get books =>
      $$BooksTableTableManager(_db.attachedDatabase, _db.books);
  $$BookCollectionsTableTableManager get bookCollections =>
      $$BookCollectionsTableTableManager(
          _db.attachedDatabase, _db.bookCollections);
  $$BookCollectionItemsTableTableManager get bookCollectionItems =>
      $$BookCollectionItemsTableTableManager(
          _db.attachedDatabase, _db.bookCollectionItems);
  $$ChaptersTableTableManager get chapters =>
      $$ChaptersTableTableManager(_db.attachedDatabase, _db.chapters);
  $$ReadingProgressTableTableManager get readingProgress =>
      $$ReadingProgressTableTableManager(
          _db.attachedDatabase, _db.readingProgress);
}
