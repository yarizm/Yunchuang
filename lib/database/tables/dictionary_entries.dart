import 'package:drift/drift.dart';

import 'dictionary_sources.dart';

class DictionaryEntries extends Table {
  IntColumn get id => integer().autoIncrement()();

  IntColumn get sourceId => integer()
      .references(DictionarySources, #id, onDelete: KeyAction.cascade)();

  IntColumn get entryIndex => integer()();

  TextColumn get headword => text().withLength(min: 1, max: 500)();

  TextColumn get normalizedHeadword => text().withLength(min: 1, max: 500)();

  IntColumn get dataOffset => integer()();

  IntColumn get dataSize => integer()();

  @override
  List<Set<Column<Object>>> get uniqueKeys => [
        {sourceId, entryIndex},
      ];
}
