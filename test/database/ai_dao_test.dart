import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yunchuang/database/app_database.dart';
import 'package:yunchuang/database/daos/ai_dao.dart';
import 'package:yunchuang/providers/ai/ai_service.dart';

void main() {
  late AppDatabase database;
  late AiDao dao;

  setUp(() {
    database = AppDatabase.connect(NativeDatabase.memory());
    dao = AiDao(database);
  });

  tearDown(() async {
    await database.close();
  });

  test('default provider query tolerates multiple legacy defaults', () async {
    await _insertProvider(database, name: 'older', isDefault: true);
    final newerId = await _insertProvider(
      database,
      name: 'newer',
      isDefault: true,
    );

    final provider = await dao.getDefaultProvider();

    expect(provider, isNotNull);
    expect(provider!.id, newerId);
    expect(provider.name, 'newer');
  });

  test('setDefault clears previous defaults in one DAO operation', () async {
    final firstId = await _insertProvider(
      database,
      name: 'first',
      isDefault: true,
    );
    final secondId = await _insertProvider(database, name: 'second');

    await dao.setDefault(secondId);

    final providers = await dao.getAllProviders();
    final first = providers.singleWhere((provider) => provider.id == firstId);
    final second = providers.singleWhere((provider) => provider.id == secondId);
    expect(first.isDefault, isFalse);
    expect(second.isDefault, isTrue);
  });

  test('AIService always keeps a default provider while providers exist',
      () async {
    final service = AIService(dao);
    final firstId = await service.saveProvider(_provider('first'));

    expect((await dao.getDefaultProvider())?.id, firstId);

    await service.saveProvider(
      _provider('first edited'),
      providerId: firstId,
      makeDefault: false,
    );
    expect((await dao.getDefaultProvider())?.id, firstId);

    final secondId = await service.saveProvider(_provider('second'));
    expect((await dao.getDefaultProvider())?.id, firstId);

    await service.deleteProvider(firstId);
    expect((await dao.getDefaultProvider())?.id, secondId);
  });

  test('provider save rolls back when changing the default fails', () async {
    final service = AIService(dao);
    final firstId = await service.saveProvider(_provider('first'));
    final secondId = await service.saveProvider(_provider('second'));
    await database.customStatement('''
      CREATE TRIGGER fail_provider_default_update
      BEFORE UPDATE OF is_default ON ai_providers
      WHEN NEW.id = $secondId AND NEW.is_default = 1
      BEGIN
        SELECT RAISE(FAIL, 'default update unavailable');
      END
    ''');

    await expectLater(
      service.saveProvider(
        _provider('second edited'),
        providerId: secondId,
        makeDefault: true,
      ),
      throwsA(isA<Exception>()),
    );

    final providers = await dao.getAllProviders();
    expect(
      providers.singleWhere((provider) => provider.id == secondId).name,
      'second',
    );
    expect((await dao.getDefaultProvider())?.id, firstId);
  });

  test('provider deletion rolls back when replacement default fails', () async {
    final service = AIService(dao);
    final firstId = await service.saveProvider(_provider('first'));
    final secondId = await service.saveProvider(_provider('second'));
    await database.customStatement('''
      CREATE TRIGGER fail_replacement_default_update
      BEFORE UPDATE OF is_default ON ai_providers
      WHEN NEW.id = $secondId AND NEW.is_default = 1
      BEGIN
        SELECT RAISE(FAIL, 'replacement update unavailable');
      END
    ''');

    await expectLater(
      service.deleteProvider(firstId),
      throwsA(isA<Exception>()),
    );

    expect((await dao.getAllProviders()).map((provider) => provider.id),
        containsAll([firstId, secondId]));
    expect((await dao.getDefaultProvider())?.id, firstId);
  });

  test('global and book conversations are isolated', () async {
    final firstBookId = await _insertBook(database, 'First book');
    final secondBookId = await _insertBook(database, 'Second book');
    final globalId = await dao.createConversation(
      AiConversationsCompanion.insert(title: const Value('Global')),
    );
    final firstBookConversationId = await dao.createConversation(
      AiConversationsCompanion.insert(
        title: const Value('First'),
        bookId: Value(firstBookId),
      ),
    );
    await dao.createConversation(
      AiConversationsCompanion.insert(
        title: const Value('Second'),
        bookId: Value(secondBookId),
      ),
    );
    final service = AIService(dao);

    expect(
      (await service.getConversations()).map((item) => item.id),
      [globalId],
    );
    expect(
      (await service.getConversations(bookId: firstBookId))
          .map((item) => item.id),
      [firstBookConversationId],
    );
  });

  test('orders same-timestamp conversations and messages by insertion id',
      () async {
    final timestamp = DateTime.utc(2026, 7, 15, 12);
    final olderConversationId = await dao.createConversation(
      AiConversationsCompanion.insert(
        title: const Value('Older'),
        createdAt: Value(timestamp),
      ),
    );
    final newerConversationId = await dao.createConversation(
      AiConversationsCompanion.insert(
        title: const Value('Newer'),
        createdAt: Value(timestamp),
      ),
    );

    expect(
      (await dao.getGlobalConversations()).map((item) => item.id),
      [newerConversationId, olderConversationId],
    );

    final firstUserId = await dao.insertMessage(
      AiMessagesCompanion.insert(
        conversationId: olderConversationId,
        role: 'user',
        content: 'first user',
        createdAt: Value(timestamp),
      ),
    );
    final assistantId = await dao.insertMessage(
      AiMessagesCompanion.insert(
        conversationId: olderConversationId,
        role: 'assistant',
        content: 'assistant',
        createdAt: Value(timestamp),
      ),
    );
    final secondUserId = await dao.insertMessage(
      AiMessagesCompanion.insert(
        conversationId: olderConversationId,
        role: 'user',
        content: 'second user',
        createdAt: Value(timestamp),
      ),
    );

    expect(
      (await dao.getMessagesForConversation(olderConversationId))
          .map((item) => item.id),
      [firstUserId, assistantId, secondUserId],
    );
    expect(
      (await dao.getFirstUserMessage(olderConversationId))?.id,
      firstUserId,
    );
  });

  test('orders same-timestamp skills and personas by newest id', () async {
    final timestamp = DateTime.utc(2026, 7, 15, 12);
    final olderSkillId = await dao.insertSkill(
      AiSkillsCompanion.insert(
        name: 'Older skill',
        contentMarkdown: 'older',
        updatedAt: Value(timestamp),
      ),
    );
    final newerSkillId = await dao.insertSkill(
      AiSkillsCompanion.insert(
        name: 'Newer skill',
        contentMarkdown: 'newer',
        updatedAt: Value(timestamp),
      ),
    );
    final olderPersonaId = await dao.insertPersona(
      AiPersonasCompanion.insert(
        name: 'Older persona',
        type: 'custom',
        updatedAt: Value(timestamp),
      ),
    );
    final newerPersonaId = await dao.insertPersona(
      AiPersonasCompanion.insert(
        name: 'Newer persona',
        type: 'custom',
        updatedAt: Value(timestamp),
      ),
    );

    expect(
      (await dao.getSkills()).map((item) => item.id),
      [newerSkillId, olderSkillId],
    );
    expect(
      (await dao.getEnabledSkills()).map((item) => item.id),
      [newerSkillId, olderSkillId],
    );
    expect(
      (await dao.getPersonas()).map((item) => item.id),
      [newerPersonaId, olderPersonaId],
    );
  });

  test('keeps a saved user message when automatic title update fails',
      () async {
    final service = AIService(dao);
    final conversationId = await service.createConversation('新对话');
    await database.customStatement('''
      CREATE TRIGGER fail_ai_conversation_title
      BEFORE UPDATE OF title ON ai_conversations
      BEGIN
        SELECT RAISE(FAIL, 'title update unavailable');
      END
    ''');

    await service.appendMessage(
      conversationId,
      'user',
      '这条消息必须保留',
    );

    final messages = await service.getMessages(conversationId);
    expect(messages, hasLength(1));
    expect(messages.single.content, '这条消息必须保留');
    expect(await service.conversationTitle(conversationId), '新对话');
  });

  test('manages AI skills enabled state', () async {
    final skillId = await dao.insertSkill(
      AiSkillsCompanion.insert(
        name: 'Search first',
        contentMarkdown: 'Use search_current_book before answering.',
      ),
    );

    expect((await dao.getSkills()).single.id, skillId);
    expect((await dao.getEnabledSkills()).single.id, skillId);

    await dao.setSkillEnabled(skillId, false);
    expect(await dao.getEnabledSkills(), isEmpty);

    await dao.deleteSkill(skillId);
    expect(await dao.getSkills(), isEmpty);
  });

  test('manages custom and book-scoped personas', () async {
    final bookId = await database.into(database.books).insert(
          BooksCompanion.insert(
            title: 'Book',
            filePath: 'book.txt',
            format: 'txt',
            fileSize: 1,
          ),
        );
    final globalId = await dao.insertPersona(
      AiPersonasCompanion.insert(
        name: 'Global',
        type: 'custom',
      ),
    );
    final bookPersonaId = await dao.insertPersona(
      AiPersonasCompanion.insert(
        name: 'Book Persona',
        type: 'character',
        bookId: Value(bookId),
      ),
    );

    final available = await dao.getPersonas(bookId: bookId);
    expect(available.map((persona) => persona.id),
        containsAll([globalId, bookPersonaId]));

    await dao.deletePersona(globalId);
    expect((await dao.getPersonas()).map((persona) => persona.id),
        isNot(contains(globalId)));
  });
}

AiProvidersCompanion _provider(String name) {
  return AiProvidersCompanion.insert(
    name: name,
    type: 'openai',
    baseUrl: 'https://example.test/v1',
    modelName: 'test-model',
  );
}

Future<int> _insertBook(AppDatabase database, String title) {
  return database.into(database.books).insert(
        BooksCompanion.insert(
          title: title,
          filePath: '$title.txt',
          format: 'txt',
          fileSize: 1,
        ),
      );
}

Future<int> _insertProvider(
  AppDatabase database, {
  required String name,
  bool isDefault = false,
}) {
  return database.into(database.aiProviders).insert(
        AiProvidersCompanion.insert(
          name: name,
          type: 'openai',
          baseUrl: 'https://example.test/v1',
          modelName: 'test-model',
          isDefault: Value(isDefault),
        ),
      );
}
