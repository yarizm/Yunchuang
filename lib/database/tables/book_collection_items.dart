import 'package:drift/drift.dart';

import 'book_collections.dart';
import 'books.dart';

class BookCollectionItems extends Table {
  IntColumn get collectionId =>
      integer().references(BookCollections, #id, onDelete: KeyAction.cascade)();
  IntColumn get bookId =>
      integer().references(Books, #id, onDelete: KeyAction.cascade)();
  DateTimeColumn get addedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {collectionId, bookId};
}
