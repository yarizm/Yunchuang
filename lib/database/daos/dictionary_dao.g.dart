// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'dictionary_dao.dart';

// ignore_for_file: type=lint
mixin _$DictionaryDaoMixin on DatabaseAccessor<AppDatabase> {
  $DictionarySourcesTable get dictionarySources =>
      attachedDatabase.dictionarySources;
  $DictionaryEntriesTable get dictionaryEntries =>
      attachedDatabase.dictionaryEntries;
  $DictionaryAliasesTable get dictionaryAliases =>
      attachedDatabase.dictionaryAliases;
  DictionaryDaoManager get managers => DictionaryDaoManager(this);
}

class DictionaryDaoManager {
  final _$DictionaryDaoMixin _db;
  DictionaryDaoManager(this._db);
  $$DictionarySourcesTableTableManager get dictionarySources =>
      $$DictionarySourcesTableTableManager(
          _db.attachedDatabase, _db.dictionarySources);
  $$DictionaryEntriesTableTableManager get dictionaryEntries =>
      $$DictionaryEntriesTableTableManager(
          _db.attachedDatabase, _db.dictionaryEntries);
  $$DictionaryAliasesTableTableManager get dictionaryAliases =>
      $$DictionaryAliasesTableTableManager(
          _db.attachedDatabase, _db.dictionaryAliases);
}
