import '../../database/app_database.dart';
import '../../database/daos/ai_dao.dart';
import 'package:drift/drift.dart';
import 'ai_provider.dart';
import 'openai_provider.dart';
import 'ollama_provider.dart';
import 'dify_provider.dart';

class AIService {
  final AiDao _aiDao;
  AIProvider? _cachedProvider;

  AIService(this._aiDao);

  /// Get the default AI provider, or null if none configured
  Future<AIProvider?> getDefaultProvider() async {
    if (_cachedProvider != null) return _cachedProvider;

    final providerRow = await _aiDao.getDefaultProvider();
    if (providerRow == null) return null;

    _cachedProvider = _createProvider(providerRow);
    return _cachedProvider;
  }

  /// Create provider instance from database row
  AIProvider _createProvider(AiProvider row) {
    switch (row.type) {
      case 'openai':
        return OpenAIProvider(
          baseUrl: row.baseUrl,
          apiKey: row.apiKey,
          model: row.modelName,
        );
      case 'ollama':
        return OllamaProvider(
          baseUrl: row.baseUrl,
          model: row.modelName,
        );
      case 'dify':
        return DifyProvider(
          baseUrl: row.baseUrl,
          apiKey: row.apiKey ?? '',
        );
      default:
        return OpenAIProvider(
          baseUrl: row.baseUrl,
          apiKey: row.apiKey,
          model: row.modelName,
        );
    }
  }

  /// Clear cached provider (e.g., after settings change).
  ///
  /// Releases the discarded provider's HTTP client so its connection pool does
  /// not outlive it; in-flight requests are still allowed to finish.
  void clearCache() {
    final discarded = _cachedProvider;
    _cachedProvider = null;
    _releaseProvider(discarded);
  }

  /// [DisposableAIProvider] is not a subtype of [AIProvider], so `is` does not
  /// promote here — the cast matches how [CancellableAIProvider] is handled.
  static void _releaseProvider(AIProvider? provider) {
    if (provider is DisposableAIProvider) {
      (provider as DisposableAIProvider).dispose();
    }
  }

  /// Release the cached provider. The service is unusable afterwards.
  void dispose() => clearCache();

  /// Test a provider configuration
  Future<bool> testProvider(AiProvider config) async {
    final provider = _createProvider(config);
    try {
      return await provider.testConnection();
    } finally {
      _releaseProvider(provider);
    }
  }

  Future<List<AiProvider>> getProviders() => _aiDao.getAllProviders();

  Future<int> saveProvider(
    AiProvidersCompanion provider, {
    int? providerId,
    bool makeDefault = false,
  }) async {
    final id = await _aiDao.saveProviderKeepingDefault(
      provider,
      providerId: providerId,
      makeDefault: makeDefault,
    );
    clearCache();
    return id;
  }

  Future<void> deleteProvider(int providerId) async {
    await _aiDao.deleteProviderKeepingDefault(providerId);
    clearCache();
  }

  Future<List<AiConversation>> getConversations({int? bookId}) => bookId == null
      ? _aiDao.getGlobalConversations()
      : _aiDao.getConversationsForBook(bookId);

  Future<List<AiMessage>> getMessages(int conversationId) =>
      _aiDao.getMessagesForConversation(conversationId);

  Future<int> createConversation(String title, {int? bookId}) {
    return _aiDao.createConversation(
      AiConversationsCompanion.insert(
        title: Value(title),
        bookId: Value(bookId),
      ),
    );
  }

  Future<void> renameConversation(int id, String title) =>
      _aiDao.renameConversation(id, title);

  Future<void> deleteConversation(int id) => _aiDao.deleteConversation(id);

  Future<String> conversationTitle(int id) async {
    final conversation = await _aiDao.getConversationById(id);
    return conversation?.title ?? '新对话';
  }

  Future<void> appendMessage(int conversationId, String role, String content,
      {String? metadataJson}) async {
    await _aiDao.insertMessage(AiMessagesCompanion.insert(
      conversationId: conversationId,
      role: role,
      content: content,
      metadataJson: Value(metadataJson),
    ));

    // 首条 user 消息驱动标题
    if (role == 'user') {
      try {
        final titleNow = await conversationTitle(conversationId);
        if (titleNow == '新对话' || titleNow.isEmpty) {
          final first = await _aiDao.getFirstUserMessage(conversationId);
          if (first != null) {
            final newTitle =
                first.content.replaceAll(RegExp(r'\s+'), ' ').trim();
            await _aiDao.updateConversationTitle(
              conversationId,
              newTitle.isEmpty
                  ? '新对话'
                  : (newTitle.length > 16
                      ? '${newTitle.substring(0, 16)}…'
                      : newTitle),
            );
          }
        }
      } catch (_) {
        // The message is already persisted; title generation is best-effort.
      }
    }
  }

  Future<List<AiSkill>> getSkills() => _aiDao.getSkills();

  Future<List<AiSkill>> getEnabledSkills() => _aiDao.getEnabledSkills();

  Future<int> saveSkill(
    AiSkillsCompanion skill, {
    int? skillId,
  }) async {
    if (skillId == null) return _aiDao.insertSkill(skill);
    await _aiDao.updateSkill(skill.copyWith(id: Value(skillId)));
    return skillId;
  }

  Future<void> setSkillEnabled(int id, bool enabled) =>
      _aiDao.setSkillEnabled(id, enabled);

  Future<void> deleteSkill(int id) async {
    await _aiDao.deleteSkill(id);
  }

  Future<List<AiPersona>> getPersonas({int? bookId}) =>
      _aiDao.getPersonas(bookId: bookId);

  Future<int> savePersona(
    AiPersonasCompanion persona, {
    int? personaId,
  }) async {
    if (personaId == null) return _aiDao.insertPersona(persona);
    await _aiDao.updatePersona(persona.copyWith(id: Value(personaId)));
    return personaId;
  }

  Future<void> deletePersona(int id) async {
    await _aiDao.deletePersona(id);
  }
}
