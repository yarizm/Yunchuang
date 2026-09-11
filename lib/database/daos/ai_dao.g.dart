// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'ai_dao.dart';

// ignore_for_file: type=lint
mixin _$AiDaoMixin on DatabaseAccessor<AppDatabase> {
  $AiProvidersTable get aiProviders => attachedDatabase.aiProviders;
  $BooksTable get books => attachedDatabase.books;
  $AiConversationsTable get aiConversations => attachedDatabase.aiConversations;
  $AiMessagesTable get aiMessages => attachedDatabase.aiMessages;
  $AiSkillsTable get aiSkills => attachedDatabase.aiSkills;
  $AiPersonasTable get aiPersonas => attachedDatabase.aiPersonas;
  AiDaoManager get managers => AiDaoManager(this);
}

class AiDaoManager {
  final _$AiDaoMixin _db;
  AiDaoManager(this._db);
  $$AiProvidersTableTableManager get aiProviders =>
      $$AiProvidersTableTableManager(_db.attachedDatabase, _db.aiProviders);
  $$BooksTableTableManager get books =>
      $$BooksTableTableManager(_db.attachedDatabase, _db.books);
  $$AiConversationsTableTableManager get aiConversations =>
      $$AiConversationsTableTableManager(
          _db.attachedDatabase, _db.aiConversations);
  $$AiMessagesTableTableManager get aiMessages =>
      $$AiMessagesTableTableManager(_db.attachedDatabase, _db.aiMessages);
  $$AiSkillsTableTableManager get aiSkills =>
      $$AiSkillsTableTableManager(_db.attachedDatabase, _db.aiSkills);
  $$AiPersonasTableTableManager get aiPersonas =>
      $$AiPersonasTableTableManager(_db.attachedDatabase, _db.aiPersonas);
}
