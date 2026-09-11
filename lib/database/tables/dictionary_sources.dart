import 'package:drift/drift.dart';

class DictionarySources extends Table {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get name => text().withLength(min: 1, max: 500)();

  TextColumn get description => text().nullable()();

  TextColumn get formatVersion => text().withLength(min: 1, max: 20)();

  TextColumn get sameTypeSequence => text().withLength(max: 64).nullable()();

  TextColumn get dataFilePath => text()();

  IntColumn get entryCount => integer().withDefault(const Constant(0))();

  BoolColumn get enabled => boolean().withDefault(const Constant(false))();

  BoolColumn get isReady => boolean().withDefault(const Constant(false))();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}
