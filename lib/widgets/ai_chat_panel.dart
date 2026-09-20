import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../database/app_database.dart';
import '../providers/ai/agent_models.dart';
import '../providers/ai/ai_agent_service.dart';
import '../providers/ai/ai_asset_service.dart';
import '../providers/ai/ai_http.dart';
import '../providers/ai/ai_provider.dart';
import '../providers/ai/spoiler_protection_provider.dart';
import '../providers/database_provider.dart';
import '../pages/settings/ai_provider_list.dart';
import '../theme/glass_page_route.dart';
import 'ai_chat/agent_source_parsing.dart';
import 'ai_chat/ai_markdown_style.dart';
import 'ai_chat/source_reference_list.dart';
import 'ai_chat/attachment_viewer.dart';
import 'ai_chat/character_name_dialog.dart';
import 'ai_chat/chat_message.dart';
import 'ai_chat/persona_editor_dialog.dart';
import 'empty_state.dart';

class AiChatPanel extends ConsumerStatefulWidget {
  final String? initialPrompt;
  final AiPromptDraft? initialDraft;
  final String? chapterContent;
  final String? systemContext;
  final AgentContext? agentContext;
  final ValueChanged<AiSourceReference>? onOpenReference;

  const AiChatPanel({
    super.key,
    this.initialPrompt,
    this.initialDraft,
    this.chapterContent,
    this.systemContext,
    this.agentContext,
    this.onOpenReference,
  });

  @override
  ConsumerState<AiChatPanel> createState() => _AiChatPanelState();
}

class _AiChatPanelState extends ConsumerState<AiChatPanel> {
  static const _streamRenderInterval = Duration(milliseconds: 50);
  static const _autoScrollThreshold = 120.0;
  static const _inlineAttachmentCharLimit = 4000;

  final _inputCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  final _messages = <ChatMsg>[];
  final _expandedAttachments = <String>{};
  final _toolEvents = <String>[];
  final _sourceReferences = <AiSourceReference>[];
  bool _initializing = true;
  String? _initializationError;

  /// 有没有配好默认 AI Provider。没有的话发什么都只会得到一句「请先配置」，
  /// 那句话还会作为回复存进会话——所以在发之前就拦住，并给一条能直接
  /// 走到设置页的路。
  bool _hasProvider = true;
  bool _initialDraftConsumed = false;
  bool _loading = false;
  bool _switchingConversation = false;
  bool _persistingPendingMessages = false;
  int? _conversationId;
  List<AiConversation> _conversations = [];
  List<AiPersona> _personas = [];
  AiPersona? _selectedPersona;
  CharacterPersonaGenerationCheckpoint? _characterPersonaCheckpoint;
  AIRequestCancellation? _activeCancellation;
  AIRequestCancellation? _activePersonaCancellation;
  int _sendRequestId = 0;
  int _conversationLoadRequestId = 0;
  int _initializationRequestId = 0;
  late SpoilerProtectionLevel _spoilerProtectionLevel;

  bool get _canStartSend =>
      !_initializing &&
      _initializationError == null &&
      !_loading &&
      !_switchingConversation &&
      !_persistingPendingMessages &&
      !_messages.any((message) => message.isPersisting);

  bool get _hasUnsavedAssistantMessages =>
      _messages.any((message) => message.isUnsaved);

  AgentContext get _agentContext {
    final fallback = widget.agentContext ?? const AgentContext();
    if (widget.systemContext == null || widget.systemContext!.isEmpty) {
      return fallback;
    }
    return AgentContext(
      bookId: fallback.bookId,
      bookTitle: fallback.bookTitle,
      currentChapterId: fallback.currentChapterId,
      currentChapterTitle: fallback.currentChapterTitle,
      currentChapterOrder: fallback.currentChapterOrder,
      currentPosition: fallback.currentPosition,
      selectedText: fallback.selectedText,
      surroundingText: fallback.surroundingText ?? widget.systemContext,
      spoilerProtectionLevel: _spoilerProtectionLevel,
      unreadContentAuthorized: fallback.unreadContentAuthorized,
    );
  }

  @override
  void initState() {
    super.initState();
    _spoilerProtectionLevel = widget.agentContext?.spoilerProtectionLevel ??
        SpoilerProtectionLevel.strict;
    unawaited(_initConversation());
  }

  Future<void> _initConversation() async {
    final requestId = ++_initializationRequestId;
    if (mounted) {
      setState(() {
        _initializing = true;
        _initializationError = null;
      });
    }

    try {
      final service = ref.read(aiServiceProvider);
      final bookId = _agentContext.bookId;
      final selectionStore = ref.read(aiPersonaSelectionStoreProvider);
      final preferredPersonaId = selectionStore.read(bookId);
      final results = await Future.wait<Object?>([
        service.getConversations(bookId: bookId),
        service.getPersonas(bookId: bookId),
        bookId == null
            ? Future<CharacterPersonaGenerationCheckpoint?>.value()
            : ref
                .read(aiAssetServiceProvider)
                .loadCharacterPersonaCheckpoint(bookId),
        service.getDefaultProvider(),
      ]);
      final conversations = results[0] as List<AiConversation>;
      final personas = results[1] as List<AiPersona>;
      final checkpoint = results[2] as CharacterPersonaGenerationCheckpoint?;
      final hasProvider = results[3] != null;
      final selectedPersona = _findPersona(personas, preferredPersonaId);
      if (preferredPersonaId != null && selectedPersona == null) {
        try {
          await selectionStore.write(bookId, null);
        } catch (_) {
          // A stale preference must not prevent the chat panel from opening.
        }
      }
      final conversationId =
          conversations.isEmpty ? null : conversations.first.id;
      final messages = conversationId == null
          ? const <AiMessage>[]
          : await service.getMessages(conversationId);
      if (!mounted || requestId != _initializationRequestId) return;
      setState(() {
        _conversations = conversations;
        _personas = personas;
        _selectedPersona = selectedPersona;
        _conversationId = conversationId;
        _characterPersonaCheckpoint = checkpoint;
        _hasProvider = hasProvider;
        _messages
          ..clear()
          ..addAll(messages.map(_fromDbMessage));
        _initializing = false;
        _initializationError = null;
      });
      _sendInitialDraftOnce();
    } catch (error) {
      if (!mounted || requestId != _initializationRequestId) return;
      setState(() {
        _initializing = false;
        _initializationError = describeAIError(error);
      });
    }
  }

  /// 发送前确认默认 Provider 还在。每次都查一遍数据库而不信 [_hasProvider]
  /// 缓存：用户可能刚从设置页配好回来，也可能刚把它删了。
  Future<bool> _ensureProviderConfigured() async {
    final bool hasProvider;
    try {
      hasProvider =
          await ref.read(aiServiceProvider).getDefaultProvider() != null;
    } catch (_) {
      // 查不到就放行，让真正的请求去报错，错误信息更具体。
      return true;
    }
    if (!mounted) return false;
    if (hasProvider != _hasProvider) setState(() => _hasProvider = hasProvider);
    if (hasProvider) return true;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('还没有配置 AI 服务，无法发送。'),
        action: SnackBarAction(label: '去配置', onPressed: _openProviderSettings),
      ),
    );
    return false;
  }

  Future<void> _openProviderSettings() async {
    await Navigator.of(context, rootNavigator: true).push(
      GlassPageRoute<void>(builder: (_) => const AiProviderListPage()),
    );
    if (!mounted) return;
    // 回来之后重新看一眼，配好了就把空状态换掉。
    try {
      final hasProvider =
          await ref.read(aiServiceProvider).getDefaultProvider() != null;
      if (mounted && hasProvider != _hasProvider) {
        setState(() => _hasProvider = hasProvider);
      }
    } catch (_) {
      // 留着当前状态，发送时还会再查一次。
    }
  }

  void _sendInitialDraftOnce() {
    if (_initialDraftConsumed) return;
    _initialDraftConsumed = true;
    final initial = widget.initialDraft ??
        (widget.initialPrompt == null || widget.initialPrompt!.isEmpty
            ? null
            : AiPromptDraft(instruction: widget.initialPrompt!));
    if (initial != null) unawaited(_sendDraft(initial));
  }

  ChatMsg _fromDbMessage(AiMessage message) {
    return ChatMsg(
      role: message.role,
      content: message.content,
      attachments: AiPromptDraft.attachmentsFromMetadata(message.metadataJson),
      toolEvents: toolEventsFromMetadata(message.metadataJson),
      sourceReferences: AiSourceReference.fromMetadata(message.metadataJson),
    );
  }

  Future<void> _refreshConversations() async {
    final service = ref.read(aiServiceProvider);
    final conversations =
        await service.getConversations(bookId: _agentContext.bookId);
    if (!mounted) return;
    setState(() => _conversations = conversations);
  }

  Future<void> _refreshPersonas() async {
    final personas = await ref
        .read(aiServiceProvider)
        .getPersonas(bookId: _agentContext.bookId);
    final selectedPersona = _findPersona(personas, _selectedPersona?.id);
    if (_selectedPersona != null && selectedPersona == null) {
      try {
        await ref
            .read(aiPersonaSelectionStoreProvider)
            .write(_agentContext.bookId, null);
      } catch (_) {
        // Keep the refreshed list usable even if preference cleanup fails.
      }
    }
    if (!mounted) return;
    setState(() {
      _personas = personas;
      _selectedPersona = selectedPersona;
    });
  }

  AiPersona? _findPersona(List<AiPersona> personas, int? id) {
    if (id == null) return null;
    return personas.where((persona) => persona.id == id).firstOrNull;
  }

  Future<void> _selectPersona(
    AiPersona? persona,
    BuildContext sheetContext,
  ) async {
    setState(() => _selectedPersona = persona);
    Navigator.pop(sheetContext);
    try {
      await ref
          .read(aiPersonaSelectionStoreProvider)
          .write(_agentContext.bookId, persona?.id);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('人格选择已生效，但保存失败：${describeAIError(error)}'),
        ),
      );
    }
  }

  Future<void> _send([String? textOverride]) async {
    final text = textOverride ?? _inputCtrl.text.trim();
    if (text.isEmpty || !_canStartSend) return;
    if (_hasUnsavedAssistantMessages &&
        !await _persistPendingAssistantMessages()) {
      return;
    }
    if (!_canStartSend) return;
    // 没配 Provider 时发不出去；输入框里的话留着，别让人再打一遍。
    if (!await _ensureProviderConfigured()) return;
    if (!mounted || !_canStartSend) return;
    if (textOverride == null) _inputCtrl.clear();
    await _sendDraft(
      AiPromptDraft(instruction: text),
      pendingPersistenceChecked: true,
    );
  }

  Future<void> _sendDraft(
    AiPromptDraft draft, {
    ChatMsg? existingUserMessage,
    bool userAlreadyPersisted = false,
    bool pendingPersistenceChecked = false,
    bool unreadContentAuthorized = false,
  }) async {
    if (draft.instruction.trim().isEmpty || !_canStartSend) {
      return;
    }
    if (!pendingPersistenceChecked &&
        _hasUnsavedAssistantMessages &&
        !await _persistPendingAssistantMessages()) {
      return;
    }
    if (!_canStartSend) return;
    if (!await _ensureProviderConfigured()) return;
    if (!mounted || !_canStartSend) return;
    final requestId = ++_sendRequestId;
    final cancellation = AIRequestCancellation();
    _activeCancellation = cancellation;
    final userMessage = existingUserMessage ??
        ChatMsg(
          role: 'user',
          content: draft.instruction.trim(),
          attachments: draft.attachments,
        );
    setState(() {
      if (existingUserMessage == null) _messages.add(userMessage);
      _loading = true;
      _toolEvents.clear();
      _sourceReferences.clear();
    });
    _scrollToBottom(force: true);

    final service = ref.read(aiServiceProvider);
    final requestContext = _agentContext.copyWith(
      unreadContentAuthorized: unreadContentAuthorized,
    );
    final buffer = StringBuffer();
    var assistantAdded = false;
    var retryWithUnreadAccess = false;
    Timer? streamRenderTimer;
    Timer? answerStartPulseTimer;

    void flushStreamBuffer() {
      streamRenderTimer?.cancel();
      streamRenderTimer = null;
      if (!_isActiveSend(requestId) || !assistantAdded || _messages.isEmpty) {
        return;
      }
      final content = buffer.toString();
      if (_messages.last.content == content) return;
      setState(() {
        _messages.last = _messages.last.copyWith(content: content);
      });
      _scrollToBottom(animated: false);
    }

    void scheduleStreamRender() {
      if (streamRenderTimer?.isActive == true) return;
      streamRenderTimer = Timer(_streamRenderInterval, flushStreamBuffer);
    }

    void showTerminalStatus(String content, {bool canRetry = false}) {
      final status = ChatMsg(
        role: 'status',
        content: content,
        toolEvents: List.of(_toolEvents),
        sourceReferences: List.of(_sourceReferences),
        retryDraft: canRetry ? draft : null,
        retryUserMessage: canRetry ? userMessage : null,
        retryUserPersisted: userAlreadyPersisted,
      );
      setState(() {
        if (assistantAdded && _messages.isNotEmpty) {
          _messages.last = status;
        } else {
          _messages.add(status);
          assistantAdded = true;
        }
      });
    }

    try {
      _conversationId ??= await service.createConversation(
        '新对话',
        bookId: _agentContext.bookId,
      );
      if (!_isActiveSend(requestId)) return;
      if (!userAlreadyPersisted) {
        final metadataJson = await draft.toPersistedMetadataJson();
        if (!_isActiveSend(requestId)) return;
        await service.appendMessage(
          _conversationId!,
          'user',
          userMessage.content,
          metadataJson: metadataJson,
        );
        userAlreadyPersisted = true;
      }
      if (!_isActiveSend(requestId)) return;

      final history = _buildModelHistory(userMessage);

      setState(() {
        _messages.add(
            const ChatMsg(role: 'assistant', content: '', isStreaming: true));
        assistantAdded = true;
      });

      await for (final event in ref.read(aiAgentServiceProvider).send(
            draft,
            context: requestContext,
            history: history,
            persona: _selectedPersona,
            cancellation: cancellation,
          )) {
        if (!_isActiveSend(requestId)) return;
        if (event.type == AgentEventType.keepAlive) {
          // Paint the transition from tool planning to the real streaming
          // answer request even when the provider has not emitted text yet.
          setState(() {});
          var remainingPulses = 4;
          answerStartPulseTimer?.cancel();
          answerStartPulseTimer = Timer.periodic(
            const Duration(milliseconds: 16),
            (timer) {
              if (!_isActiveSend(requestId) || --remainingPulses <= 0) {
                timer.cancel();
              }
              if (_isActiveSend(requestId)) setState(() {});
            },
          );
          continue;
        } else if (event.type == AgentEventType.status) {
          if (_requiresUnreadConfirmation(event)) {
            final approved = await _confirmUnreadAccess();
            if (!_isActiveSend(requestId)) return;
            if (approved) {
              retryWithUnreadAccess = true;
              cancellation.cancel('用户已授权本次访问未读内容。');
              if (assistantAdded &&
                  _messages.isNotEmpty &&
                  _messages.last.isStreaming) {
                setState(() => _messages.removeLast());
                assistantAdded = false;
              }
              break;
            }
          }
          _toolEvents.add(event.content);
          _addSourceReferences(sourceReferencesFromStatus(
            event,
            fallbackBookId: widget.agentContext?.bookId,
          ));
          setState(() {
            _messages.last = _messages.last.copyWith(
              toolEvents: List.of(_toolEvents),
              sourceReferences: List.of(_sourceReferences),
            );
          });
        } else if (event.type == AgentEventType.delta) {
          buffer.write(event.content);
          scheduleStreamRender();
          continue;
        } else {
          streamRenderTimer?.cancel();
          streamRenderTimer = null;
          final finalText = buffer.isEmpty ? event.content : buffer.toString();
          late final ChatMsg completedMessage;
          setState(() {
            completedMessage = _messages.last.copyWith(
              content: finalText,
              isStreaming: false,
              toolEvents: List.of(_toolEvents),
              sourceReferences: List.of(_sourceReferences),
            );
            _messages.last = completedMessage;
          });
          try {
            await service.appendMessage(
              _conversationId!,
              'assistant',
              finalText,
              metadataJson: _assistantMetadataJson(completedMessage),
            );
          } catch (error) {
            if (!mounted || !_isActiveSend(requestId)) return;
            final index = _messages.indexOf(completedMessage);
            if (index >= 0) {
              setState(() {
                _messages[index] = completedMessage.copyWith(isUnsaved: true);
              });
            }
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  '回答已生成，但保存失败：${describeAIError(error)}',
                ),
              ),
            );
          }
        }
        _scrollToBottom();
      }
      if (!retryWithUnreadAccess) cancellation.throwIfCancelled();
    } on AIRequestCancelledException {
      streamRenderTimer?.cancel();
      streamRenderTimer = null;
      if (!_isActiveSend(requestId)) return;
      if (!retryWithUnreadAccess) {
        final partial = buffer.toString().trim();
        showTerminalStatus(
          partial.isEmpty ? '已停止生成' : '$partial\n\n*已停止生成*',
        );
        _scrollToBottom();
      }
    } catch (error) {
      streamRenderTimer?.cancel();
      streamRenderTimer = null;
      if (!_isActiveSend(requestId)) return;
      showTerminalStatus(
        '请求失败：${describeAIError(error)}',
        canRetry: true,
      );
      _scrollToBottom();
    } finally {
      streamRenderTimer?.cancel();
      answerStartPulseTimer?.cancel();
      if (_isActiveSend(requestId)) {
        setState(() {
          _loading = false;
          if (identical(_activeCancellation, cancellation)) {
            _activeCancellation = null;
          }
        });
      }
    }
    if (retryWithUnreadAccess && mounted && requestId == _sendRequestId) {
      await _sendDraft(
        draft,
        existingUserMessage: userMessage,
        userAlreadyPersisted: true,
        pendingPersistenceChecked: true,
        unreadContentAuthorized: true,
      );
    }
  }

  bool _requiresUnreadConfirmation(AgentEvent event) {
    final result = event.metadata?['result'];
    return result is Map &&
        result['spoilerBlocked'] == true &&
        result['requiresConfirmation'] == true;
  }

  Future<bool> _confirmUnreadAccess() async {
    if (!mounted) return false;
    return await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('可能包含剧透'),
            content: const Text('AI 需要检索当前阅读位置之后的内容。本次问题是否允许访问？'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('仅使用已读内容'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('本次允许'),
              ),
            ],
          ),
        ) ??
        false;
  }

  bool _isActiveSend(int requestId) => mounted && requestId == _sendRequestId;

  List<ChatMessage> _buildModelHistory(ChatMsg currentUserMessage) {
    final recent = <ChatMessage>[];
    var remainingChars = AIAgentService.maxHistoryChars;

    for (var index = _messages.length - 1; index >= 0; index--) {
      final message = _messages[index];
      if (identical(message, currentUserMessage) ||
          message.isStreaming ||
          message.role != 'user' && message.role != 'assistant') {
        continue;
      }

      final estimatedLength = message.modelHistoryContentLength;
      if (estimatedLength == 0) continue;
      if (estimatedLength > remainingChars) break;

      final content = message.toModelHistoryContent().trim();
      if (content.isEmpty) continue;
      if (content.length > remainingChars) break;
      recent.add(ChatMessage(role: message.role, content: content));
      remainingChars -= content.length;
    }

    return recent.reversed.toList(growable: false);
  }

  void _stopGeneration() {
    _activeCancellation?.cancel();
  }

  void _retryMessage(ChatMsg message) {
    final draft = message.retryDraft;
    final userMessage = message.retryUserMessage;
    if (_loading || draft == null || userMessage == null) return;
    final index = _messages.indexOf(message);
    if (index < 0) return;
    setState(() => _messages.removeAt(index));
    _sendDraft(
      draft,
      existingUserMessage: userMessage,
      userAlreadyPersisted: message.retryUserPersisted,
    );
  }

  Future<void> _retryAssistantPersistence(ChatMsg message) async {
    if (_loading || message.isPersisting || !message.isUnsaved) return;
    await _persistAssistantMessage(message);
  }

  Future<bool> _persistPendingAssistantMessages() async {
    final pending =
        _messages.where((message) => message.isUnsaved).toList(growable: false);
    if (pending.isEmpty) return true;
    if (_persistingPendingMessages) return false;

    setState(() => _persistingPendingMessages = true);
    var allSaved = true;
    try {
      for (final message in pending) {
        if (!await _persistAssistantMessage(message, showSuccess: false)) {
          allSaved = false;
          break;
        }
      }
    } finally {
      if (mounted) setState(() => _persistingPendingMessages = false);
    }

    if (allSaved && mounted) {
      final messenger = ScaffoldMessenger.of(context);
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        const SnackBar(content: Text('未保存的回答已自动补存')),
      );
    }
    return allSaved;
  }

  Future<bool> _persistAssistantMessage(
    ChatMsg message, {
    bool showSuccess = true,
  }) async {
    final conversationId = _conversationId;
    final index = _messages.indexOf(message);
    if (conversationId == null || index < 0) return false;
    final persistingMessage = message.copyWith(isPersisting: true);
    setState(() => _messages[index] = persistingMessage);

    try {
      await ref.read(aiServiceProvider).appendMessage(
            conversationId,
            'assistant',
            message.content,
            metadataJson: _assistantMetadataJson(message),
          );
      if (!mounted) return false;
      final currentIndex = _messages.indexOf(persistingMessage);
      if (currentIndex >= 0) {
        setState(() {
          _messages[currentIndex] = persistingMessage.copyWith(
            isUnsaved: false,
            isPersisting: false,
          );
        });
      }
      if (showSuccess) {
        final messenger = ScaffoldMessenger.of(context);
        messenger.hideCurrentSnackBar();
        messenger.showSnackBar(
          const SnackBar(content: Text('回答已保存')),
        );
      }
      return true;
    } catch (error) {
      if (!mounted) return false;
      final currentIndex = _messages.indexOf(persistingMessage);
      if (currentIndex >= 0) {
        setState(() {
          _messages[currentIndex] = persistingMessage.copyWith(
            isPersisting: false,
          );
        });
      }
      final messenger = ScaffoldMessenger.of(context);
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        SnackBar(content: Text('保存仍然失败：${describeAIError(error)}')),
      );
      return false;
    }
  }

  String _assistantMetadataJson(ChatMsg message) {
    return jsonEncode({
      'toolEvents': message.toolEvents,
      'references':
          message.sourceReferences.map((item) => item.toJson()).toList(),
    });
  }

  void _invalidateActiveSend(String reason) {
    _activeCancellation?.cancel(reason);
    _activeCancellation = null;
    _sendRequestId++;
  }

  Future<void> _switchConversation(int id) async {
    if (id == _conversationId) return;
    if (_hasUnsavedAssistantMessages &&
        !await _persistPendingAssistantMessages()) {
      return;
    }
    if (!mounted || id == _conversationId) return;
    final loadRequestId = ++_conversationLoadRequestId;
    _invalidateActiveSend('会话已切换。');
    setState(() {
      _loading = false;
      _switchingConversation = true;
    });
    try {
      final service = ref.read(aiServiceProvider);
      final msgs = await service.getMessages(id);
      if (!mounted || loadRequestId != _conversationLoadRequestId) return;
      setState(() {
        _conversationId = id;
        _switchingConversation = false;
        _messages
          ..clear()
          ..addAll(msgs.map(_fromDbMessage));
      });
    } catch (error) {
      if (!mounted || loadRequestId != _conversationLoadRequestId) return;
      setState(() => _switchingConversation = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('加载会话失败：$error')),
      );
    }
  }

  Future<void> _newConversation() async {
    if (_hasUnsavedAssistantMessages &&
        !await _persistPendingAssistantMessages()) {
      return;
    }
    if (!mounted) return;
    _conversationLoadRequestId++;
    _invalidateActiveSend('正在新建会话。');
    setState(() {
      _loading = false;
      _switchingConversation = true;
    });
    final service = ref.read(aiServiceProvider);
    late final int id;
    try {
      id = await service.createConversation(
        '新对话',
        bookId: _agentContext.bookId,
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _switchingConversation = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('新建会话失败：${describeAIError(error)}')),
      );
      return;
    }
    if (!mounted) return;
    try {
      await _refreshConversations();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _conversationId = id;
        _switchingConversation = false;
        _messages.clear();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '新会话已创建，但刷新列表失败：${describeAIError(error)}',
          ),
        ),
      );
      return;
    }
    if (!mounted) return;
    setState(() => _switchingConversation = false);
    await _switchConversation(id);
  }

  Future<void> _renameConversation(int id) async {
    final controller = TextEditingController(
      text: _conversations.firstWhere((c) => c.id == id).title ?? '',
    );
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('重命名会话'),
        content: TextField(controller: controller, autofocus: true),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('确定'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (result != null && result.isNotEmpty) {
      try {
        await ref.read(aiServiceProvider).renameConversation(id, result);
      } catch (error) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('重命名会话失败：${describeAIError(error)}'),
          ),
        );
        return;
      }
      if (!mounted) return;
      try {
        await _refreshConversations();
      } catch (error) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '会话已重命名，但刷新列表失败：${describeAIError(error)}',
            ),
          ),
        );
      }
    }
  }

  Future<void> _deleteConversation(int id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除会话'),
        content: const Text('确定删除该会话及所有消息？此操作不可撤销。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final service = ref.read(aiServiceProvider);
    final deletingCurrentConversation = id == _conversationId;
    if (deletingCurrentConversation) {
      _conversationLoadRequestId++;
      _invalidateActiveSend('当前会话已删除。');
      setState(() {
        _loading = false;
        _switchingConversation = true;
      });
    }
    try {
      await service.deleteConversation(id);
    } catch (error) {
      if (!mounted) return;
      setState(() => _switchingConversation = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('删除会话失败：${describeAIError(error)}')),
      );
      return;
    }
    if (!mounted) return;
    setState(() {
      _conversations = _conversations
          .where((conversation) => conversation.id != id)
          .toList(growable: false);
      if (deletingCurrentConversation) {
        _conversationId = null;
        _messages.clear();
      }
    });
    try {
      await _refreshConversations();
    } catch (error) {
      if (!mounted) return;
      setState(() => _switchingConversation = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '会话已删除，但刷新列表失败：${describeAIError(error)}',
          ),
        ),
      );
      return;
    }
    if (!mounted || !deletingCurrentConversation) return;
    if (_conversations.isNotEmpty) {
      setState(() => _switchingConversation = false);
      await _switchConversation(_conversations.first.id);
    } else {
      setState(() {
        _conversationId = null;
        _loading = false;
        _switchingConversation = false;
        _messages.clear();
      });
    }
  }

  Future<void> _showConversationList() async {
    try {
      await _refreshConversations();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('加载会话列表失败：${describeAIError(error)}'),
        ),
      );
      return;
    }
    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetCtx) => SizedBox(
        height: MediaQuery.sizeOf(sheetCtx).height * 0.7,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Text('会话', style: Theme.of(sheetCtx).textTheme.titleLarge),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.add),
                    tooltip: '新会话',
                    onPressed: () {
                      Navigator.pop(sheetCtx);
                      _newConversation();
                    },
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: _conversations.isEmpty
                  ? const Center(child: Text('暂无会话'))
                  : ListView.builder(
                      itemCount: _conversations.length,
                      itemBuilder: (ctx, index) {
                        final c = _conversations[index];
                        final active = c.id == _conversationId;
                        return ListTile(
                          selected: active,
                          leading: const Icon(Icons.chat_bubble_outline),
                          title: Text(
                            c.title ?? '新对话',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          onTap: () {
                            Navigator.pop(ctx);
                            _switchConversation(c.id);
                          },
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit, size: 20),
                                tooltip: '重命名会话',
                                onPressed: () {
                                  Navigator.pop(ctx);
                                  _renameConversation(c.id);
                                },
                              ),
                              IconButton(
                                icon:
                                    const Icon(Icons.delete_outline, size: 20),
                                tooltip: '删除会话',
                                onPressed: () {
                                  Navigator.pop(ctx);
                                  _deleteConversation(c.id);
                                },
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showPersonaSheet() async {
    try {
      await _refreshPersonas();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('加载人格列表失败：${describeAIError(error)}'),
        ),
      );
      return;
    }
    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(ctx).height * 0.72,
          child: Column(
            children: [
              ListTile(
                title: const Text('AI 人格'),
                subtitle: Text(_selectedPersona?.name ?? '未启用人格'),
                trailing: IconButton(
                  icon: const Icon(Icons.add),
                  tooltip: '新建自定义人格',
                  onPressed: () {
                    Navigator.pop(ctx);
                    _createCustomPersona();
                  },
                ),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.block),
                title: const Text('不使用人格'),
                selected: _selectedPersona == null,
                onTap: () => _selectPersona(null, ctx),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: _personas.length,
                  itemBuilder: (context, index) {
                    final persona = _personas[index];
                    return ListTile(
                      leading: Icon(persona.type == 'character'
                          ? Icons.theater_comedy
                          : Icons.person_outline),
                      title: Text(persona.name),
                      subtitle: Text(persona.characterName ?? persona.type),
                      selected: _selectedPersona?.id == persona.id,
                      onTap: () => _selectPersona(persona, ctx),
                      trailing: IconButton(
                        tooltip: '查看和编辑人格',
                        icon: const Icon(Icons.edit_outlined, size: 20),
                        onPressed: () {
                          Navigator.pop(ctx);
                          unawaited(_editPersona(persona));
                        },
                      ),
                    );
                  },
                ),
              ),
              if (_characterPersonaCheckpoint != null &&
                  _characterPersonaCheckpoint!.bookId == _agentContext.bookId)
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            final checkpoint = _characterPersonaCheckpoint!;
                            Navigator.pop(ctx);
                            _generateCharacterPersona(resumeFrom: checkpoint);
                          },
                          icon: const Icon(Icons.play_arrow),
                          label: Text(
                            '继续生成“${_characterPersonaCheckpoint!.characterName}”人格',
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        onPressed: () {
                          Navigator.pop(ctx);
                          _discardCharacterPersonaCheckpoint();
                        },
                        icon: const Icon(Icons.delete_outline),
                        tooltip: '放弃未完成生成',
                      ),
                    ],
                  ),
                ),
              if (_agentContext.bookId != null)
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: FilledButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      _generateCharacterPersona();
                    },
                    icon: const Icon(Icons.auto_awesome),
                    label: const Text('从当前书生成角色人格'),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _createCustomPersona() async {
    final nameCtrl = TextEditingController();
    final promptCtrl = TextEditingController();
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('新建自定义人格'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              maxLength: 100,
              decoration: const InputDecoration(labelText: '名称'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: promptCtrl,
              minLines: 4,
              maxLines: 8,
              decoration: const InputDecoration(labelText: '系统提示词'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('保存'),
          ),
        ],
      ),
    );
    final name = nameCtrl.text.trim();
    final prompt = promptCtrl.text.trim();
    nameCtrl.dispose();
    promptCtrl.dispose();
    if (result != true || name.isEmpty || prompt.isEmpty) return;
    try {
      await ref.read(aiAssetServiceProvider).createCustomPersona(
            name: name,
            systemPrompt: prompt,
            bookId: _agentContext.bookId,
          );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('创建人格失败：${describeAIError(error)}')),
      );
      return;
    }
    if (!mounted) return;
    try {
      await _refreshPersonas();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '人格已创建，但刷新列表失败：${describeAIError(error)}',
          ),
        ),
      );
    }
  }

  Future<void> _editPersona(
    AiPersona persona, {
    bool startInEditMode = false,
  }) async {
    final draft = await showPersonaEditorDialog(
      context,
      persona: persona,
      startInEditMode: startInEditMode,
    );
    if (draft == null || !mounted) return;
    try {
      await ref.read(aiServiceProvider).savePersona(
            AiPersonasCompanion(
              name: Value(draft.name),
              systemPrompt: Value(draft.systemPrompt),
              documentMarkdown: Value(draft.documentMarkdown),
              updatedAt: Value(DateTime.now()),
            ),
            personaId: persona.id,
          );
      if (!mounted) return;
      await _refreshPersonas();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('人格已保存')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('保存人格失败：${describeAIError(error)}')),
      );
    }
  }

  Future<void> _generateCharacterPersona({
    CharacterPersonaGenerationCheckpoint? resumeFrom,
  }) async {
    final isResuming = resumeFrom != null;
    final characterName =
        resumeFrom?.characterName ?? await _askCharacterName();
    if (characterName == null || characterName.isEmpty || !mounted) return;

    late final CharacterPersonaGenerationEstimate estimate;
    try {
      final assetService = ref.read(aiAssetServiceProvider);
      final pendingPages =
          await assetService.pendingLocalContentPreparationPages(
        _agentContext.bookId!,
      );
      if (!mounted) return;
      if (pendingPages > 0) {
        final prepareConfirmed = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('准备 PDF 正文'),
            content: Text(
              '当前 PDF 还有 $pendingPages 页尚未提取正文。为了完整搜索角色证据，'
              '需要先在本地读取并缓存这些页面。\n\n'
              '此步骤不会调用 AI、不消耗 token，也不会向 AI Provider 发送正文。',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('取消'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('开始准备'),
              ),
            ],
          ),
        );
        if (prepareConfirmed != true || !mounted) return;
        estimate = await _estimateCharacterPersonaWithProgress(
          assetService,
          bookId: _agentContext.bookId!,
          characterName: characterName,
          pendingPages: pendingPages,
          resumeFrom: resumeFrom,
        );
      } else {
        estimate = await assetService.estimateCharacterPersonaGeneration(
          bookId: _agentContext.bookId!,
          characterName: characterName,
          resumeFrom: resumeFrom,
        );
      }
    } on AIRequestCancelledException {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已取消 PDF 正文准备')),
      );
      return;
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('无法开始生成：${describeAIError(error)}')),
      );
      return;
    }
    if (!mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isResuming ? '继续生成角色人格' : '生成角色人格'),
        content: Text(_characterPersonaEstimateText(estimate, isResuming)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('继续'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final progress = ValueNotifier<String>(
      isResuming ? '准备从检查点继续...' : '准备生成角色人格...',
    );
    var latestCheckpoint = resumeFrom;
    var cancelled = false;
    final generationCancellation = AIRequestCancellation();
    _activePersonaCancellation = generationCancellation;
    BuildContext? progressContext;
    final dialogReady = Completer<void>();
    final progressDialog = showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        progressContext = ctx;
        if (!dialogReady.isCompleted) dialogReady.complete();
        return PopScope<void>(
          // Android 返回键原本会直接把进度框弹掉，再按一次就
          // 销毁 AI 面板并触发 dispose 中的取消。长任务只能通过
          // 明确的“取消”按钮中断，避免误操作丢掉最后一步。
          canPop: false,
          child: AlertDialog(
            title: const Text('生成角色人格'),
            content: ValueListenableBuilder<String>(
              valueListenable: progress,
              builder: (context, value, _) => Text(value),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  cancelled = true;
                  generationCancellation.cancel('已取消角色人格生成。');
                  progress.value = '正在取消...';
                },
                child: const Text('取消'),
              ),
            ],
          ),
        );
      },
    );
    await dialogReady.future;

    AiPersona? generatedPersona;
    var generationSucceeded = false;
    String? terminalMessage;
    SnackBarAction? terminalAction;
    try {
      final personaId =
          await ref.read(aiAssetServiceProvider).generateCharacterPersona(
                bookId: _agentContext.bookId!,
                characterName: characterName,
                onProgress: (status) => progress.value = status,
                shouldCancel: () => cancelled,
                cancellation: generationCancellation,
                estimate: estimate,
                resumeFrom: resumeFrom,
                onCheckpoint: (checkpoint) {
                  latestCheckpoint = checkpoint;
                  _characterPersonaCheckpoint = checkpoint;
                },
              );
      generationSucceeded = true;
      _characterPersonaCheckpoint = null;
      try {
        await _refreshPersonas();
      } catch (error) {
        terminalMessage = '角色人格已生成，但刷新列表失败：${describeAIError(error)}';
      }
      generatedPersona = _findPersona(_personas, personaId);
    } on AIAssetCancelledException {
      if (mounted) {
        setState(() {
          _characterPersonaCheckpoint = latestCheckpoint;
        });
      }
      terminalMessage = '已取消角色人格生成，可稍后从检查点继续';
      terminalAction = _resumeGenerationAction(latestCheckpoint);
    } catch (error) {
      if (mounted) {
        setState(() {
          _characterPersonaCheckpoint = latestCheckpoint;
        });
      }
      terminalMessage = '生成失败：${describeAIError(error)}';
      terminalAction = _resumeGenerationAction(latestCheckpoint);
    } finally {
      if (identical(_activePersonaCancellation, generationCancellation)) {
        _activePersonaCancellation = null;
      }
      final activeProgressContext = progressContext;
      if (activeProgressContext != null && activeProgressContext.mounted) {
        Navigator.of(activeProgressContext).pop();
      }
      await progressDialog;
      progress.dispose();
    }
    if (!mounted) return;
    if (terminalMessage != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(terminalMessage), action: terminalAction),
      );
      return;
    }
    if (generationSucceeded) {
      await _showGeneratedPersonaSuccess(
        generatedPersona,
        fallbackName: '$characterName 人格',
      );
    }
  }

  Future<CharacterPersonaGenerationEstimate>
      _estimateCharacterPersonaWithProgress(
    AIAssetService assetService, {
    required int bookId,
    required String characterName,
    required int pendingPages,
    CharacterPersonaGenerationCheckpoint? resumeFrom,
  }) async {
    final cancellation = AIRequestCancellation();
    _activePersonaCancellation = cancellation;
    final progress = ValueNotifier<String>(
      '正在准备 PDF 正文（0/$pendingPages 页）...',
    );
    BuildContext? progressContext;
    final dialogReady = Completer<void>();
    final progressDialog = showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        progressContext = ctx;
        if (!dialogReady.isCompleted) dialogReady.complete();
        return PopScope<void>(
          canPop: false,
          child: AlertDialog(
            title: const Text('准备 PDF 正文'),
            content: ValueListenableBuilder<String>(
              valueListenable: progress,
              builder: (context, value, _) => Text(value),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  cancellation.cancel('已取消 PDF 正文准备。');
                  progress.value = '正在取消...';
                },
                child: const Text('取消'),
              ),
            ],
          ),
        );
      },
    );
    await dialogReady.future;

    try {
      return await assetService.estimateCharacterPersonaGeneration(
        bookId: bookId,
        characterName: characterName,
        resumeFrom: resumeFrom,
        cancellation: cancellation,
        onProgress: (status) => progress.value = status,
      );
    } finally {
      if (identical(_activePersonaCancellation, cancellation)) {
        _activePersonaCancellation = null;
      }
      final activeProgressContext = progressContext;
      if (activeProgressContext != null && activeProgressContext.mounted) {
        Navigator.of(activeProgressContext).pop();
      }
      await progressDialog;
      progress.dispose();
    }
  }

  String _characterPersonaEstimateText(
    CharacterPersonaGenerationEstimate estimate,
    bool isResuming,
  ) {
    final scope = isResuming
        ? '已完成 ${estimate.completedEvidenceTasks}/${estimate.totalEvidenceTasks} 个正文片段，'
            '剩余 ${estimate.remainingEvidenceTasks} 个片段、约 ${_formatCharacterCount(estimate.remainingInputCharacters)}。'
        : '将在全书 ${estimate.totalChapters} 个章节中分析 '
            '${estimate.totalEvidenceTasks} 个片段，约 ${_formatCharacterCount(estimate.totalInputCharacters)}。'
            '其中 ${estimate.matchingChapters} 个章节直接出现角色名。';
    return '$scope\n\n正文片段及后续提炼结果会发送给 AI Provider，合并过程还会额外消耗 token。确定继续吗？';
  }

  String _formatCharacterCount(int count) {
    if (count < 10000) return '$count 字正文';
    return '${(count / 10000).toStringAsFixed(1)} 万字正文';
  }

  Future<void> _showGeneratedPersonaSuccess(
    AiPersona? persona, {
    required String fallbackName,
  }) async {
    final action = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        final theme = Theme.of(dialogContext);
        return AlertDialog(
          icon: Icon(
            Icons.check_circle_rounded,
            size: 52,
            color: theme.colorScheme.primary,
          ),
          title: const Text('角色人格已生成'),
          content: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer.withValues(alpha: 0.72),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                const Icon(Icons.theater_comedy_rounded),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        persona?.name ?? fallbackName,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 3),
                      const Text('已保存，可立即查看、编辑或启用'),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('稍后再说'),
            ),
            if (persona != null) ...[
              OutlinedButton.icon(
                key: const Key('persona-generation-view'),
                onPressed: () => Navigator.pop(dialogContext, 'view'),
                icon: const Icon(Icons.edit_outlined, size: 18),
                label: const Text('查看并编辑'),
              ),
              FilledButton.icon(
                onPressed: () => Navigator.pop(dialogContext, 'use'),
                icon: const Icon(Icons.check, size: 18),
                label: const Text('立即启用'),
              ),
            ],
          ],
        );
      },
    );
    if (!mounted) return;
    if (action == 'view' && persona != null) {
      await _editPersona(persona);
    } else if (action == 'use' && persona != null) {
      setState(() => _selectedPersona = persona);
      try {
        await ref
            .read(aiPersonaSelectionStoreProvider)
            .write(_agentContext.bookId, persona.id);
      } catch (error) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('人格已启用，但保存选择失败：$error')),
        );
      }
    }
  }

  SnackBarAction? _resumeGenerationAction(
    CharacterPersonaGenerationCheckpoint? checkpoint,
  ) {
    if (checkpoint == null) return null;
    return SnackBarAction(
      label: '继续',
      onPressed: () => _generateCharacterPersona(resumeFrom: checkpoint),
    );
  }

  Future<void> _discardCharacterPersonaCheckpoint() async {
    final checkpoint = _characterPersonaCheckpoint;
    if (checkpoint == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('放弃未完成生成'),
        content: Text('将删除“${checkpoint.characterName}”人格的已保存进度。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('放弃'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await ref
          .read(aiAssetServiceProvider)
          .deleteCharacterPersonaCheckpoint(checkpoint.bookId);
      if (!mounted) return;
      setState(() => _characterPersonaCheckpoint = null);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已删除未完成的角色人格进度')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('删除失败：$error')),
      );
    }
  }

  Future<String?> _askCharacterName() {
    return showDialog<String>(
      context: context,
      builder: (ctx) => CharacterNameDialog(
        discoverCharacters: (cancellation) =>
            ref.read(aiAssetServiceProvider).discoverMajorCharacters(
                  bookId: _agentContext.bookId!,
                  cancellation: cancellation,
                ),
      ),
    );
  }

  void _scrollToBottom({bool animated = true, bool force = false}) {
    final shouldFollow = force ||
        !_scrollCtrl.hasClients ||
        _scrollCtrl.position.extentAfter <= _autoScrollThreshold;
    if (!shouldFollow) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollCtrl.hasClients) return;
      final target = _scrollCtrl.position.maxScrollExtent;
      if (animated) {
        _scrollCtrl.animateTo(
          target,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      } else {
        _scrollCtrl.jumpTo(target);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: _buildConversationBody(),
        ),
        _buildShortcuts(),
        _buildInputBar(),
      ],
    );
  }

  Widget _buildConversationBody() {
    if (_initializing) {
      return const Center(child: CircularProgressIndicator());
    }
    final initializationError = _initializationError;
    if (initializationError != null) {
      return EmptyState(
        icon: Icons.error_outline,
        title: '无法加载 AI 会话',
        subtitle: initializationError,
        action: FilledButton.icon(
          onPressed: _initConversation,
          icon: const Icon(Icons.refresh),
          label: const Text('重试'),
        ),
      );
    }
    if (_messages.isEmpty) {
      if (!_hasProvider) {
        return EmptyState(
          icon: Icons.smart_toy_outlined,
          title: '还没有配置 AI 服务',
          subtitle: '添加一个 AI Provider 后就可以在这里提问。',
          action: FilledButton.icon(
            key: const Key('ai-chat-configure-provider'),
            onPressed: _openProviderSettings,
            icon: const Icon(Icons.settings_outlined),
            label: const Text('去配置'),
          ),
        );
      }
      return const EmptyState(
        icon: Icons.auto_awesome,
        title: '开始对话',
        subtitle: '输入问题，AI 会按需搜索当前书籍和阅读上下文。',
      );
    }
    return ListView.builder(
      controller: _scrollCtrl,
      padding: const EdgeInsets.all(16),
      itemCount: _messages.length,
      itemBuilder: (context, index) => _buildMessageBubble(_messages[index]),
    );
  }

  Widget _buildShortcuts() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          _buildShortcutChip(
            '总结本章',
            '请只根据随附的“本章内容”总结本章的核心内容与主要情节。'
                '不要转而回答历史对话中的问题，不要引入未在附件中出现的后续情节。',
          ),
          const SizedBox(width: 8),
          _buildShortcutChip(
            '本章提纲',
            '请只根据随附的“本章内容”，用层次化要点列出本章提纲。'
                '忽略旧对话的未完成话题，不要分析其他章节。',
          ),
          const SizedBox(width: 8),
          _buildShortcutChip(
            '续写本章',
            '请只以随附的“本章内容”为上文，延续其故事发展、叙事视角和文风合理续写。'
                '不要回答旧问题，也不要声称已知道原作后续。',
          ),
        ],
      ),
    );
  }

  Widget _buildShortcutChip(String label, String instruction) {
    return ActionChip(
      label: Text(label),
      onPressed: !_canStartSend
          ? null
          : () {
              final content = widget.chapterContent;
              _sendDraft(AiPromptDraft(
                instruction: instruction,
                attachments: content == null || content.isEmpty
                    ? const []
                    : [
                        AiAttachment(
                          id: 'chapter-${DateTime.now().microsecondsSinceEpoch}',
                          title: '本章内容',
                          content: content,
                        ),
                      ],
              ));
            },
    );
  }

  Widget _buildMessageBubble(ChatMsg msg) {
    final isUser = msg.role == 'user';
    final theme = Theme.of(context);
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        constraints: const BoxConstraints(maxWidth: 340),
        decoration: BoxDecoration(
          color: isUser
              ? theme.colorScheme.primary
              : theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (msg.toolEvents.isNotEmpty) ...[
              for (final event in msg.toolEvents)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.manage_search,
                        size: 14,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          event,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: isUser
                                ? theme.colorScheme.onPrimary
                                : theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 4),
            ],
            if (isUser)
              Text(
                msg.content,
                style: TextStyle(color: theme.colorScheme.onPrimary),
              )
            else if (msg.content.isEmpty && msg.isStreaming)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.auto_awesome_rounded,
                    size: 16,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 9),
                  Text(
                    '正在生成回答…',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              )
            else
              MarkdownBody(
                data: msg.content,
                styleSheet: aiMarkdownStyleSheet(theme),
              ),
            for (final attachment in msg.attachments)
              _buildAttachmentCard(attachment, isUser),
            if (!isUser && msg.sourceReferences.isNotEmpty)
              AiSourceReferenceList(
                references: msg.sourceReferences,
                onOpen: widget.onOpenReference,
              ),
            if (!isUser && msg.isUnsaved) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    Icons.cloud_off_outlined,
                    size: 16,
                    color: theme.colorScheme.error,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '回答未保存',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.error,
                      ),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: _loading || msg.isPersisting
                        ? null
                        : () => _retryAssistantPersistence(msg),
                    icon: msg.isPersisting
                        ? const SizedBox.square(
                            dimension: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.save_outlined, size: 16),
                    label: Text(msg.isPersisting ? '保存中' : '重新保存'),
                  ),
                ],
              ),
            ],
            if (msg.retryDraft != null) ...[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: _loading ? null : () => _retryMessage(msg),
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const Text('重试'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAttachmentCard(AiAttachment attachment, bool isUser) {
    final expanded = _expandedAttachments.contains(attachment.id);
    final useViewer = attachment.length > _inlineAttachmentCharLimit;
    final theme = Theme.of(context);
    final foreground = isUser
        ? theme.colorScheme.onPrimaryContainer
        : theme.colorScheme.onSurface;
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Semantics(
        button: true,
        label: useViewer ? '查看完整附件' : (expanded ? '收起附件' : '展开附件'),
        child: Material(
          color: isUser
              ? theme.colorScheme.primaryContainer
              : theme.colorScheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: useViewer
                ? () => unawaited(showAiAttachmentViewer(context, attachment))
                : () {
                    setState(() {
                      if (expanded) {
                        _expandedAttachments.remove(attachment.id);
                      } else {
                        _expandedAttachments.add(attachment.id);
                      }
                    });
                  },
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.notes,
                        size: 16,
                        color: foreground,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          attachment.summary,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: foreground,
                          ),
                        ),
                      ),
                      Icon(
                        useViewer
                            ? Icons.open_in_full
                            : (expanded
                                ? Icons.expand_less
                                : Icons.expand_more),
                        size: 20,
                        color: foreground,
                      ),
                    ],
                  ),
                  if (!useViewer && expanded) ...[
                    const SizedBox(height: 8),
                    Text(
                      attachment.content,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: foreground,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _spoilerProtectionLabel(SpoilerProtectionLevel level) {
    return switch (level) {
      SpoilerProtectionLevel.strict => '严格防剧透',
      SpoilerProtectionLevel.ask => '访问前询问',
      SpoilerProtectionLevel.fullBook => '允许全书',
    };
  }

  Future<void> _showSpoilerProtectionSheet() async {
    final bookId = _agentContext.bookId;
    if (bookId == null || _loading) return;
    final settings = ref.read(spoilerProtectionProvider);
    final currentOverride = settings.overrideFor(bookId);
    final choice = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: SizedBox(
          height: (MediaQuery.sizeOf(sheetContext).height * 0.68)
              .clamp(300.0, 480.0)
              .toDouble(),
          child: Column(
            children: [
              ListTile(
                title: const Text('本书防剧透范围'),
                subtitle: Text(
                  currentOverride == null
                      ? '跟随全局 · ${_spoilerProtectionLabel(settings.defaultLevel)}'
                      : _spoilerProtectionLabel(currentOverride),
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  children: [
                    _buildSpoilerChoiceTile(
                      sheetContext,
                      selected: currentOverride == null,
                      icon: currentOverride == null
                          ? Icons.check
                          : Icons.settings,
                      title: '跟随全局设置',
                      subtitle: _spoilerProtectionLabel(settings.defaultLevel),
                      onTap: () => Navigator.pop(sheetContext, 'inherit'),
                    ),
                    for (final level in SpoilerProtectionLevel.values)
                      _buildSpoilerChoiceTile(
                        sheetContext,
                        selected: currentOverride == level,
                        icon: currentOverride == level
                            ? Icons.check
                            : level == SpoilerProtectionLevel.fullBook
                                ? Icons.warning_amber
                                : Icons.shield_outlined,
                        title: _spoilerProtectionLabel(level),
                        onTap: () =>
                            Navigator.pop(sheetContext, level.wireName),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (choice == null || !mounted) return;
    final override = choice == 'inherit'
        ? null
        : SpoilerProtectionLevel.fromWireName(choice);
    ref
        .read(spoilerProtectionProvider.notifier)
        .updateBookLevel(bookId, override);
    if (!mounted) return;
    setState(() {
      _spoilerProtectionLevel =
          override ?? ref.read(spoilerProtectionProvider).defaultLevel;
    });
  }

  Widget _buildSpoilerChoiceTile(
    BuildContext context, {
    required bool selected,
    required IconData icon,
    required String title,
    String? subtitle,
    required VoidCallback onTap,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      decoration: BoxDecoration(
        color: selected
            ? scheme.primaryContainer.withValues(alpha: 0.88)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: selected
              ? scheme.primary.withValues(alpha: 0.4)
              : Colors.transparent,
        ),
      ),
      child: Material(
        type: MaterialType.transparency,
        borderRadius: BorderRadius.circular(14),
        child: ListTile(
          selected: selected,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          leading: Icon(icon),
          title: Text(
            title,
            style: TextStyle(
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
          subtitle: subtitle == null ? null : Text(subtitle),
          trailing: selected
              ? Icon(Icons.check_circle_rounded, color: scheme.primary)
              : null,
          onTap: onTap,
        ),
      ),
    );
  }

  Widget _buildInputBar() {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(top: BorderSide(color: Theme.of(context).dividerColor)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.list_alt),
              tooltip: '会话列表',
              onPressed: _initializing || _initializationError != null
                  ? null
                  : _showConversationList,
            ),
            IconButton(
              icon: Icon(
                _selectedPersona == null ? Icons.person_outline : Icons.person,
              ),
              tooltip: 'AI 人格',
              onPressed: _initializing || _initializationError != null
                  ? null
                  : _showPersonaSheet,
            ),
            if (_agentContext.bookId != null)
              IconButton(
                icon: Icon(
                  _spoilerProtectionLevel == SpoilerProtectionLevel.fullBook
                      ? Icons.gpp_maybe_outlined
                      : Icons.shield_outlined,
                ),
                tooltip:
                    '防剧透：${_spoilerProtectionLabel(_spoilerProtectionLevel)}',
                onPressed: _initializing || _initializationError != null
                    ? null
                    : _showSpoilerProtectionSheet,
              ),
            Expanded(
              child: TextField(
                controller: _inputCtrl,
                enabled: !_initializing &&
                    _initializationError == null &&
                    !_switchingConversation &&
                    !_persistingPendingMessages,
                decoration: InputDecoration(
                  hintText: _selectedPersona == null
                      ? '输入消息...'
                      : '以 ${_selectedPersona!.name} 对话...',
                  filled: true,
                  fillColor:
                      Theme.of(context).colorScheme.surfaceContainerHighest,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                ),
                onSubmitted: (_) => _send(),
                textInputAction: TextInputAction.send,
              ),
            ),
            const SizedBox(width: 8),
            SizedBox.square(
              dimension: 48,
              child: _switchingConversation || _persistingPendingMessages
                  ? const Center(
                      child: SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : IconButton(
                      icon: Icon(_loading ? Icons.stop_rounded : Icons.send),
                      tooltip: _loading ? '停止生成' : '发送',
                      color: Theme.of(context).colorScheme.primary,
                      onPressed: _initializing || _initializationError != null
                          ? null
                          : (_loading
                              ? _stopGeneration
                              : (_canStartSend ? _send : null)),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  void _addSourceReferences(List<AiSourceReference> references) {
    if (references.isEmpty) return;
    final existingKeys = {
      for (final reference in _sourceReferences) sourceReferenceKey(reference),
    };
    for (final reference in references) {
      if (reference.snippet.trim().isEmpty) continue;
      final key = sourceReferenceKey(reference);
      if (existingKeys.add(key)) {
        _sourceReferences.add(reference);
      }
      if (_sourceReferences.length >= 8) break;
    }
  }

  @override
  void dispose() {
    _activeCancellation?.cancel('AI 面板已关闭。');
    _activePersonaCancellation?.cancel('AI 面板已关闭。');
    _initializationRequestId++;
    _sendRequestId++;
    _inputCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }
}
