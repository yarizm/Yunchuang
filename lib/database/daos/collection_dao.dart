import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/book_collection_items.dart';
import '../tables/book_collections.dart';
import '../tables/books.dart';

part 'collection_dao.g.dart';

@DriftAccessor(tables: [BookCollections, BookCollectionItems, Books])
class CollectionDao extends DatabaseAccessor<AppDatabase>
    with _$CollectionDaoMixin {
  CollectionDao(super.db);

  Stream<List<BookCollection>> watchCollections() {
    return (select(bookCollections)
          ..orderBy([
            (collection) => OrderingTerm.asc(collection.sortOrder),
            (collection) => OrderingTerm.asc(collection.id),
          ]))
        .watch();
  }

  Future<List<BookCollection>> getCollections() {
    return (select(bookCollections)
          ..orderBy([
            (collection) => OrderingTerm.asc(collection.sortOrder),
            (collection) => OrderingTerm.asc(collection.id),
          ]))
        .get();
  }

  Future<int> createCollection(String name) {
    final normalizedName = _normalizeName(name);
    return transaction(() async {
      final maxOrder = bookCollections.sortOrder.max();
      final row = await (selectOnly(bookCollections)..addColumns([maxOrder]))
          .getSingle();
      final nextOrder = (row.read(maxOrder) ?? -1) + 1;
      return into(bookCollections).insert(
        BookCollectionsCompanion.insert(
          name: normalizedName,
          sortOrder: Value(nextOrder),
        ),
      );
    });
  }

  Future<void> renameCollection(int collectionId, String name) async {
    final normalizedName = _normalizeName(name);
    final updated = await (update(bookCollections)
          ..where((collection) => collection.id.equals(collectionId)))
        .write(
      BookCollectionsCompanion(
        name: Value(normalizedName),
        updatedAt: Value(DateTime.now()),
      ),
    );
    if (updated == 0) throw StateError('书架不存在');
  }

  Future<void> deleteCollection(int collectionId) async {
    await (delete(bookCollections)
          ..where((collection) => collection.id.equals(collectionId)))
        .go();
  }

  Future<void> reorderCollections(List<int> orderedIds) {
    return transaction(() async {
      final current = await getCollections();
      final currentIds = current.map((collection) => collection.id).toSet();
      if (orderedIds.length != current.length ||
          orderedIds.toSet().length != orderedIds.length ||
          !orderedIds.toSet().containsAll(currentIds)) {
        throw ArgumentError('书架排序列表不完整');
      }
      for (var index = 0; index < orderedIds.length; index++) {
        await (update(bookCollections)
              ..where((collection) => collection.id.equals(orderedIds[index])))
            .write(
          BookCollectionsCompanion(
            sortOrder: Value(index),
            updatedAt: Value(DateTime.now()),
          ),
        );
      }
    });
  }

  Stream<Set<int>> watchCollectionIdsForBook(int bookId) {
    final query = selectOnly(bookCollectionItems)
      ..addColumns([bookCollectionItems.collectionId])
      ..where(bookCollectionItems.bookId.equals(bookId));
    return query.watch().map(
          (rows) => rows
              .map((row) => row.read(bookCollectionItems.collectionId)!)
              .toSet(),
        );
  }

  Stream<Set<int>> watchBookIdsForCollection(int collectionId) {
    final query = selectOnly(bookCollectionItems)
      ..addColumns([bookCollectionItems.bookId])
      ..where(bookCollectionItems.collectionId.equals(collectionId));
    return query.watch().map(
          (rows) =>
              rows.map((row) => row.read(bookCollectionItems.bookId)!).toSet(),
        );
  }

  Future<Set<int>> getCollectionIdsForBook(int bookId) async {
    final query = selectOnly(bookCollectionItems)
      ..addColumns([bookCollectionItems.collectionId])
      ..where(bookCollectionItems.bookId.equals(bookId));
    final rows = await query.get();
    return rows
        .map((row) => row.read(bookCollectionItems.collectionId)!)
        .toSet();
  }

  Future<void> setBookCollections(
    int bookId,
    Set<int> collectionIds,
  ) {
    return transaction(() async {
      final bookExists = await (selectOnly(books)
            ..addColumns([books.id])
            ..where(books.id.equals(bookId)))
          .getSingleOrNull();
      if (bookExists == null) throw StateError('书籍不存在');

      if (collectionIds.isNotEmpty) {
        final validRows = await (selectOnly(bookCollections)
              ..addColumns([bookCollections.id])
              ..where(bookCollections.id.isIn(collectionIds)))
            .get();
        final validIds =
            validRows.map((row) => row.read(bookCollections.id)!).toSet();
        if (validIds.length != collectionIds.length) {
          throw ArgumentError('包含不存在的书架');
        }
      }

      await (delete(bookCollectionItems)
            ..where((item) => item.bookId.equals(bookId)))
          .go();
      if (collectionIds.isNotEmpty) {
        await batch((batch) {
          batch.insertAll(
            bookCollectionItems,
            [
              for (final collectionId in collectionIds)
                BookCollectionItemsCompanion.insert(
                  collectionId: collectionId,
                  bookId: bookId,
                ),
            ],
          );
        });
      }
    });
  }

  Future<void> updateBooksInCollections({
    required Set<int> bookIds,
    required Set<int> collectionIds,
    required bool include,
  }) {
    if (bookIds.isEmpty || collectionIds.isEmpty) return Future.value();
    return transaction(() async {
      await _validateIds(bookIds, collectionIds);
      if (include) {
        await batch((batch) {
          batch.insertAll(
            bookCollectionItems,
            [
              for (final bookId in bookIds)
                for (final collectionId in collectionIds)
                  BookCollectionItemsCompanion.insert(
                    collectionId: collectionId,
                    bookId: bookId,
                  ),
            ],
            mode: InsertMode.insertOrIgnore,
          );
        });
      } else {
        await (delete(bookCollectionItems)
              ..where(
                (item) =>
                    item.bookId.isIn(bookIds) &
                    item.collectionId.isIn(collectionIds),
              ))
            .go();
      }
    });
  }

  Future<void> _validateIds(
    Set<int> bookIds,
    Set<int> collectionIds,
  ) async {
    final validBookRows = await (selectOnly(books)
          ..addColumns([books.id])
          ..where(books.id.isIn(bookIds)))
        .get();
    if (validBookRows.length != bookIds.length) {
      throw ArgumentError('包含不存在的书籍');
    }
    final validCollectionRows = await (selectOnly(bookCollections)
          ..addColumns([bookCollections.id])
          ..where(bookCollections.id.isIn(collectionIds)))
        .get();
    if (validCollectionRows.length != collectionIds.length) {
      throw ArgumentError('包含不存在的书架');
    }
  }

  String _normalizeName(String name) {
    final normalized = name.trim();
    if (normalized.isEmpty) throw ArgumentError('书架名称不能为空');
    if (normalized.length > 100) throw ArgumentError('书架名称不能超过 100 个字符');
    return normalized;
  }
}
