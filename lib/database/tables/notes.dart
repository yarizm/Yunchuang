import 'package:drift/drift.dart';
import 'books.dart';
import 'chapters.dart';

class Notes extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get bookId =>
      integer().references(Books, #id, onDelete: KeyAction.cascade)();
  IntColumn get chapterId => integer()
      .nullable()
      .references(Chapters, #id, onDelete: KeyAction.setNull)();
  TextColumn get selectedText => text().nullable()();
  TextColumn get content => text().nullable()();
  IntColumn get pageNumber => integer().nullable()();
  IntColumn get positionStart => integer().nullable()();
  IntColumn get positionEnd => integer().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  TextColumn get type =>
      text().withDefault(const Constant('note'))(); // note / bookmark / highlight
}
