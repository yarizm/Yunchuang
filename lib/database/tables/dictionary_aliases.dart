import 'package:drift/drift.dart';

import 'dictionary_sources.dart';

class DictionaryAliases extends Table {
  IntColumn get id => integer().autoIncrement()();

  IntColumn get sourceId => integer()
      .references(DictionarySources, #id, onDelete: KeyAction.cascade)();

  TextColumn get alias => text().withLength(min: 1, max: 500)();

  TextColumn get normalizedAlias => text().withLength(min: 1, max: 500)();

  IntColumn get targetEntryIndex => integer()();

  @override
  List<Set<Column<Object>>> get uniqueKeys => [
        {sourceId, normalizedAlias, targetEntryIndex},
      ];
}
