import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yunchuang/database/app_database.dart';
import 'package:yunchuang/database/daos/collection_dao.dart';

void main() {
  late AppDatabase database;
  late CollectionDao dao;

  setUp(() {
    database = AppDatabase.connect(NativeDatabase.memory());
    dao = CollectionDao(database);
  });

  tearDown(() => database.close());

  test('assigns one book to multiple collections and replaces membership',
      () async {
    final bookId = await _insertBook(database, 'Book');
    final favoritesId = await dao.createCollection('Favorites');
    final laterId = await dao.createCollection('Read later');

    await dao.setBookCollections(bookId, {favoritesId, laterId});

    expect(
      await dao.getCollectionIdsForBook(bookId),
      {favoritesId, laterId},
    );
    expect(
      await dao.watchBookIdsForCollection(favoritesId).first,
      {bookId},
    );

    await dao.setBookCollections(bookId, {laterId});

    expect(await dao.watchBookIdsForCollection(favoritesId).first, isEmpty);
    expect(await dao.getCollectionIdsForBook(bookId), {laterId});
  });

  test('renames and reorders collections', () async {
    final firstId = await dao.createCollection('First');
    final secondId = await dao.createCollection('Second');

    await dao.renameCollection(firstId, '  Renamed  ');
    await dao.reorderCollections([secondId, firstId]);

    final collections = await dao.getCollections();
    expect(
      collections.map((collection) => collection.name),
      ['Second', 'Renamed'],
    );
    expect(
      collections.map((collection) => collection.sortOrder),
      [0, 1],
    );
  });

  test('deleting a collection keeps books and removes memberships', () async {
    final bookId = await _insertBook(database, 'Keep me');
    final collectionId = await dao.createCollection('Temporary');
    await dao.setBookCollections(bookId, {collectionId});

    await dao.deleteCollection(collectionId);

    expect(await database.select(database.books).get(), hasLength(1));
    expect(await dao.getCollectionIdsForBook(bookId), isEmpty);
    expect(await database.select(database.bookCollectionItems).get(), isEmpty);
  });

  test('deleting a book cascades collection memberships', () async {
    final bookId = await _insertBook(database, 'Delete me');
    final collectionId = await dao.createCollection('Shelf');
    await dao.setBookCollections(bookId, {collectionId});

    await (database.delete(database.books)
          ..where((book) => book.id.equals(bookId)))
        .go();

    expect(await database.select(database.bookCollectionItems).get(), isEmpty);
    expect(await database.select(database.bookCollections).get(), hasLength(1));
  });

  test('validates names, reorder input, and collection ids', () async {
    final bookId = await _insertBook(database, 'Book');
    final collectionId = await dao.createCollection('Shelf');
    await dao.setBookCollections(bookId, {collectionId});

    expect(() => dao.createCollection('   '), throwsArgumentError);
    expect(
      () => dao.createCollection('Shelf'),
      throwsA(isA<SqliteException>()),
    );
    expect(
      () => dao.reorderCollections(const []),
      throwsArgumentError,
    );
    expect(
      () => dao.setBookCollections(bookId, {9999}),
      throwsArgumentError,
    );
    expect(await dao.getCollectionIdsForBook(bookId), {collectionId});
  });

  test('bulk collection updates preserve unrelated memberships', () async {
    final firstBookId = await _insertBook(database, 'First');
    final secondBookId = await _insertBook(database, 'Second');
    final targetId = await dao.createCollection('Target');
    final retainedId = await dao.createCollection('Retained');
    await dao.setBookCollections(firstBookId, {retainedId});

    await dao.updateBooksInCollections(
      bookIds: {firstBookId, secondBookId},
      collectionIds: {targetId},
      include: true,
    );

    expect(
      await dao.getCollectionIdsForBook(firstBookId),
      {targetId, retainedId},
    );
    expect(await dao.getCollectionIdsForBook(secondBookId), {targetId});

    await dao.updateBooksInCollections(
      bookIds: {firstBookId, secondBookId},
      collectionIds: {targetId},
      include: false,
    );

    expect(await dao.getCollectionIdsForBook(firstBookId), {retainedId});
    expect(await dao.getCollectionIdsForBook(secondBookId), isEmpty);
  });
}

Future<int> _insertBook(AppDatabase database, String title) {
  return database.into(database.books).insert(
        BooksCompanion.insert(
          title: title,
          filePath: '$title.txt',
          format: 'txt',
          fileSize: 1,
        ),
      );
}
