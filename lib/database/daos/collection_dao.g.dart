// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'collection_dao.dart';

// ignore_for_file: type=lint
mixin _$CollectionDaoMixin on DatabaseAccessor<AppDatabase> {
  $BookCollectionsTable get bookCollections => attachedDatabase.bookCollections;
  $BooksTable get books => attachedDatabase.books;
  $BookCollectionItemsTable get bookCollectionItems =>
      attachedDatabase.bookCollectionItems;
  CollectionDaoManager get managers => CollectionDaoManager(this);
}

class CollectionDaoManager {
  final _$CollectionDaoMixin _db;
  CollectionDaoManager(this._db);
  $$BookCollectionsTableTableManager get bookCollections =>
      $$BookCollectionsTableTableManager(
          _db.attachedDatabase, _db.bookCollections);
  $$BooksTableTableManager get books =>
      $$BooksTableTableManager(_db.attachedDatabase, _db.books);
  $$BookCollectionItemsTableTableManager get bookCollectionItems =>
      $$BookCollectionItemsTableTableManager(
          _db.attachedDatabase, _db.bookCollectionItems);
}
