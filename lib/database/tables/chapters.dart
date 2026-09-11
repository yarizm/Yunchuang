import 'package:drift/drift.dart';
import 'books.dart';

@DataClassName('Chapter')
class Chapters extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get bookId =>
      integer().references(Books, #id, onDelete: KeyAction.cascade)();
  TextColumn get title => text().withLength(max: 500)();
  TextColumn get content => text().nullable()();
  IntColumn get contentIndex => integer()();
  IntColumn get sortOrder => integer()();
}
