import 'package:drift/drift.dart';
import 'ai_conversations.dart';

class AiMessages extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get conversationId =>
      integer().references(AiConversations, #id, onDelete: KeyAction.cascade)();
  TextColumn get role =>
      text().withLength(min: 1, max: 20)(); // user, assistant, system
  TextColumn get content => text()();
  TextColumn get metadataJson => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}
