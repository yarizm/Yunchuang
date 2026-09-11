import 'package:drift/drift.dart';
import 'books.dart';

class AiPersonas extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 100)();
  TextColumn get type => text().withLength(min: 1, max: 20)();
  IntColumn get bookId => integer()
      .nullable()
      .references(Books, #id, onDelete: KeyAction.setNull)();
  TextColumn get characterName => text().nullable()();
  TextColumn get systemPrompt => text().withDefault(const Constant(''))();
  TextColumn get documentMarkdown => text().withDefault(const Constant(''))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}
