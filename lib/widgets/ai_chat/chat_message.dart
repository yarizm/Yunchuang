import '../../providers/ai/agent_models.dart';
import '../../providers/ai/ai_agent_service.dart';

/// 聊天面板里的一条消息。
///
/// 从 `AiChatPanel` 拆出来：它是面板的核心数据结构，历史裁剪、重试、
/// 未落库标记都挂在它身上，值得单独看。
class ChatMsg {
  final String role;
  final String content;
  final bool isStreaming;
  final List<AiAttachment> attachments;
  final List<String> toolEvents;
  final List<AiSourceReference> sourceReferences;
  final AiPromptDraft? retryDraft;
  final ChatMsg? retryUserMessage;
  final bool retryUserPersisted;
  final bool isUnsaved;
  final bool isPersisting;

  const ChatMsg({
    required this.role,
    required this.content,
    this.isStreaming = false,
    this.attachments = const [],
    this.toolEvents = const [],
    this.sourceReferences = const [],
    this.retryDraft,
    this.retryUserMessage,
    this.retryUserPersisted = false,
    this.isUnsaved = false,
    this.isPersisting = false,
  });

  ChatMsg copyWith({
    String? content,
    bool? isStreaming,
    List<AiAttachment>? attachments,
    List<String>? toolEvents,
    List<AiSourceReference>? sourceReferences,
    bool? isUnsaved,
    bool? isPersisting,
  }) {
    return ChatMsg(
      role: role,
      content: content ?? this.content,
      isStreaming: isStreaming ?? this.isStreaming,
      attachments: attachments ?? this.attachments,
      toolEvents: toolEvents ?? this.toolEvents,
      sourceReferences: sourceReferences ?? this.sourceReferences,
      retryDraft: retryDraft,
      retryUserMessage: retryUserMessage,
      retryUserPersisted: retryUserPersisted,
      isUnsaved: isUnsaved ?? this.isUnsaved,
      isPersisting: isPersisting ?? this.isPersisting,
    );
  }

  String toModelHistoryContent() {
    if (role != 'user' || attachments.isEmpty) return content;
    return AiPromptDraft(
      instruction: content,
      attachments: attachments,
    ).toModelContent(maxChars: AIAgentService.maxHistoryMessageChars);
  }

  int get modelHistoryContentLength {
    final length = role == 'user' && attachments.isNotEmpty
        ? AiPromptDraft(
            instruction: content,
            attachments: attachments,
          ).modelContentLength
        : content.trim().length;
    return length > AIAgentService.maxHistoryMessageChars
        ? AIAgentService.maxHistoryMessageChars
        : length;
  }
}
