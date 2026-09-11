import 'package:drift/drift.dart';

import 'books.dart';

class BookTtsSettings extends Table {
  IntColumn get bookId =>
      integer().references(Books, #id, onDelete: KeyAction.cascade)();
  TextColumn get language => text().withLength(max: 100).nullable()();
  TextColumn get voiceName => text().withLength(max: 300).nullable()();
  TextColumn get voiceLocale => text().withLength(max: 100).nullable()();
  RealColumn get speechRate => real().customConstraint(
        'NOT NULL DEFAULT 0.5 CHECK (speech_rate >= 0.1 AND speech_rate <= 1.0)',
      )();
  TextColumn get sleepTimerOption => text().customConstraint(
        "NOT NULL DEFAULT 'off' CHECK (sleep_timer_option IN "
        "('off', 'minutes15', 'minutes30', 'minutes60', 'endOfChapter'))",
      )();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {bookId};
}
