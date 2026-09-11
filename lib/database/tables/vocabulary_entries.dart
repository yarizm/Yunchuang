import 'package:drift/drift.dart';

import 'books.dart';
import 'chapters.dart';

class VocabularyEntries extends Table {
  IntColumn get id => integer().autoIncrement()();

  IntColumn get bookId =>
      integer().references(Books, #id, onDelete: KeyAction.cascade)();

  IntColumn get chapterId => integer()
      .nullable()
      .references(Chapters, #id, onDelete: KeyAction.setNull)();

  TextColumn get term => text().withLength(min: 1, max: 200)();

  TextColumn get normalizedTerm => text().withLength(min: 1, max: 200)();

  TextColumn get definition => text().nullable()();

  TextColumn get contextText => text().nullable()();

  IntColumn get positionStart => integer().nullable()();

  IntColumn get positionEnd => integer().nullable()();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  List<Set<Column<Object>>> get uniqueKeys => [
        {bookId, normalizedTerm},
      ];
}
