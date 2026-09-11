import 'package:drift/drift.dart';
import '../app_database.dart';
import '../tables/ai_providers.dart';
import '../tables/ai_conversations.dart';
import '../tables/ai_messages.dart';
import '../tables/ai_skills.dart';
import '../tables/ai_personas.dart';

part 'ai_dao.g.dart';

@DriftAccessor(
  tables: [AiProviders, AiConversations, AiMessages, AiSkills, AiPersonas],
)
class AiDao extends DatabaseAccessor<AppDatabase> with _$AiDaoMixin {
  AiDao(super.db);

  // Providers
  Future<List<AiProvider>> getAllProviders() => select(aiProviders).get();

  Future<AiProvider?> getDefaultProvider() => (select(aiProviders)
        ..where((p) => p.isDefault.equals(true))
        ..orderBy([(p) => OrderingTerm.desc(p.id)])
        ..limit(1))
      .getSingleOrNull();

  Future<int> insertProvider(AiProvidersCompanion entry) =>
      into(aiProviders).insert(entry);

  Future<bool> updateProvider(AiProvidersCompanion entry) =>
      update(aiProviders).replace(entry);

  Future<int> deleteProvider(int id) =>
      (delete(aiProviders)..where((p) => p.id.equals(id))).go();

  Future<int> saveProviderKeepingDefault(
    AiProvidersCompanion entry, {
    int? providerId,
    bool makeDefault = false,
  }) {
    return transaction(() async {
      final normalized = entry.copyWith(isDefault: const Value(false));
      final id = providerId ?? await insertProvider(normalized);
      if (providerId != null) {
        final updated = await updateProvider(
          normalized.copyWith(id: Value(providerId)),
        );
        if (!updated) {
          throw StateError('Provider $providerId does not exist');
        }
      }

      final currentDefault = await getDefaultProvider();
      if (makeDefault || currentDefault == null) {
        await _setDefault(id);
      }
      return id;
    });
  }

  Future<void> deleteProviderKeepingDefault(int id) {
    return transaction(() async {
      await deleteProvider(id);
      if (await getDefaultProvider() != null) return;

      final replacement = await (select(aiProviders)
            ..orderBy([(provider) => OrderingTerm.desc(provider.id)])
            ..limit(1))
          .getSingleOrNull();
      if (replacement != null) {
        await _setDefault(replacement.id);
      }
    });
  }

  Future<void> setDefault(int id) async {
    await transaction(() => _setDefault(id));
  }

  Future<void> _setDefault(int id) async {
    await update(aiProviders)
        .write(const AiProvidersCompanion(isDefault: Value(false)));
    await (update(aiProviders)..where((p) => p.id.equals(id)))
        .write(const AiProvidersCompanion(isDefault: Value(true)));
  }

  // Conversations
  Future<List<AiConversation>> getConversations() => (select(aiConversations)
        ..orderBy([
          (c) => OrderingTerm.desc(c.createdAt),
          (c) => OrderingTerm.desc(c.id),
        ]))
      .get();

  Future<List<AiConversation>> getGlobalConversations() =>
      (select(aiConversations)
            ..where((c) => c.bookId.isNull())
            ..orderBy([
              (c) => OrderingTerm.desc(c.createdAt),
              (c) => OrderingTerm.desc(c.id),
            ]))
          .get();

  Future<List<AiConversation>> getConversationsForBook(int bookId) =>
      (select(aiConversations)
            ..where((c) => c.bookId.equals(bookId))
            ..orderBy([
              (c) => OrderingTerm.desc(c.createdAt),
              (c) => OrderingTerm.desc(c.id),
            ]))
          .get();

  Future<AiConversation?> getConversationById(int id) =>
      (select(aiConversations)..where((c) => c.id.equals(id)))
          .getSingleOrNull();

  Future<int> createConversation(AiConversationsCompanion entry) =>
      into(aiConversations).insert(entry);

  // Messages
  Future<List<AiMessage>> getMessagesForConversation(int conversationId) =>
      (select(aiMessages)
            ..where((m) => m.conversationId.equals(conversationId))
            ..orderBy([
              (m) => OrderingTerm.asc(m.createdAt),
              (m) => OrderingTerm.asc(m.id),
            ]))
          .get();

  Future<int> insertMessage(AiMessagesCompanion entry) =>
      into(aiMessages).insert(entry);

  Future<void> renameConversation(int id, String title) async {
    await (update(aiConversations)..where((c) => c.id.equals(id)))
        .write(AiConversationsCompanion(title: Value(title)));
  }

  Future<void> deleteConversation(int id) async {
    await (delete(aiConversations)..where((c) => c.id.equals(id))).go();
  }

  /// 别名，语义清晰
  Future<void> updateConversationTitle(int id, String title) =>
      renameConversation(id, title);

  /// 返回该会话首条 user 消息，用于自动生成标题
  Future<AiMessage?> getFirstUserMessage(int conversationId) =>
      (select(aiMessages)
            ..where((m) =>
                m.conversationId.equals(conversationId) & m.role.equals('user'))
            ..orderBy([
              (m) => OrderingTerm.asc(m.createdAt),
              (m) => OrderingTerm.asc(m.id),
            ])
            ..limit(1))
          .getSingleOrNull();

  Future<List<AiSkill>> getSkills() => (select(aiSkills)
        ..orderBy([
          (s) => OrderingTerm.desc(s.updatedAt),
          (s) => OrderingTerm.desc(s.id),
        ]))
      .get();

  Future<List<AiSkill>> getEnabledSkills() => (select(aiSkills)
        ..where((s) => s.enabled.equals(true))
        ..orderBy([
          (s) => OrderingTerm.desc(s.updatedAt),
          (s) => OrderingTerm.desc(s.id),
        ]))
      .get();

  Future<int> insertSkill(AiSkillsCompanion entry) =>
      into(aiSkills).insert(entry);

  Future<bool> updateSkill(AiSkillsCompanion entry) =>
      update(aiSkills).replace(entry);

  Future<void> setSkillEnabled(int id, bool enabled) =>
      (update(aiSkills)..where((s) => s.id.equals(id))).write(
        AiSkillsCompanion(
          enabled: Value(enabled),
          updatedAt: Value(DateTime.now()),
        ),
      );

  Future<int> deleteSkill(int id) =>
      (delete(aiSkills)..where((s) => s.id.equals(id))).go();

  Future<List<AiPersona>> getPersonas({int? bookId}) {
    final query = select(aiPersonas)
      ..orderBy([
        (p) => OrderingTerm.desc(p.updatedAt),
        (p) => OrderingTerm.desc(p.id),
      ]);
    if (bookId != null) {
      query.where((p) => p.bookId.equals(bookId) | p.bookId.isNull());
    }
    return query.get();
  }

  Future<int> insertPersona(AiPersonasCompanion entry) =>
      into(aiPersonas).insert(entry);

  Future<bool> updatePersona(AiPersonasCompanion entry) =>
      update(aiPersonas).replace(entry);

  Future<int> deletePersona(int id) =>
      (delete(aiPersonas)..where((p) => p.id.equals(id))).go();
}
