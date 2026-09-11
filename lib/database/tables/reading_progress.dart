import 'package:drift/drift.dart';
import 'books.dart';
import 'chapters.dart';

class ReadingProgress extends Table {
  IntColumn get bookId =>
      integer().references(Books, #id, onDelete: KeyAction.cascade)();
  IntColumn get chapterId => integer()
      .nullable()
      .references(Chapters, #id, onDelete: KeyAction.setNull)();
  RealColumn get positionInChapter => real().withDefault(const Constant(0.0))();
  RealColumn get percentage => real().withDefault(const Constant(0.0))();
  IntColumn get totalReadingSeconds =>
      integer().withDefault(const Constant(0))();
  DateTimeColumn get lastReadAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {bookId};
}
