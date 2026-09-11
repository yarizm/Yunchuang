import 'package:drift/drift.dart';

class Books extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get title => text().withLength(min: 1, max: 500)();
  TextColumn get author =>
      text().withLength(max: 200).withDefault(const Constant(''))();
  TextColumn get coverPath => text().nullable()();
  TextColumn get filePath => text()();
  TextColumn get format =>
      text().withLength(min: 1, max: 10)(); // epub, pdf, txt
  IntColumn get fileSize => integer()();
  TextColumn get description => text().nullable()();
  TextColumn get fileHash => text().withLength(min: 64, max: 64).nullable()();
  TextColumn get seriesName => text().withLength(max: 200).nullable()();
  RealColumn get seriesIndex => real().nullable()();
  TextColumn get readingStatus => text().nullable().customConstraint(
        "CHECK (reading_status IS NULL OR reading_status IN "
        "('unread', 'reading', 'finished', 'paused'))",
      )();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}
