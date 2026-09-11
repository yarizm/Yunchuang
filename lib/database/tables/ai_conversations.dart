import 'package:drift/drift.dart';
import 'books.dart';

class AiConversations extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get bookId => integer()
      .nullable()
      .references(Books, #id, onDelete: KeyAction.setNull)();
  TextColumn get title => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}
