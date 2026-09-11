import 'package:flutter/material.dart';

import '../../database/app_database.dart';
import '../../providers/ai/agent_models.dart';
import '../../services/tts_service.dart';
import '../../widgets/ai_chat_panel.dart';
import '../../widgets/glass_container.dart';
import '../../widgets/tts_control_panel.dart';
import '../notes/note_editor.dart';
import 'reader_controller.dart';
import '../../theme/glass_page_route.dart';

class ReaderOverlays {
  static void showTtsPanel(
    BuildContext context,
    String content, {
    Listenable? chapterListenable,
    int Function()? currentChapterIndex,
    int chapterCount = 0,
    Future<void> Function()? onPreviousChapter,
    Future<void> Function()? onNextChapter,
    Future<void> Function()? onBeforePlay,
    Future<void> Function(double rate)? onSpeechRateChanged,
    Future<void> Function(String language)? onLanguageChanged,
    Future<void> Function(TTSVoice? voice)? onVoiceChanged,
    Future<void> Function(TTSSleepTimerOption option)? onSleepTimerChanged,
    Future<void> Function()? onResetBookSettings,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return SafeArea(
          top: false,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * 0.8,
            ),
            child: GlassContainer.stable(
              borderRadius: 24,
              color: Theme.of(context).colorScheme.surface,
              child: TtsControlPanel(
                content: content,
                chapterListenable: chapterListenable,
                currentChapterIndex: currentChapterIndex,
                chapterCount: chapterCount,
                onPreviousChapter: onPreviousChapter,
                onNextChapter: onNextChapter,
                onBeforePlay: onBeforePlay,
                onSpeechRateChanged: onSpeechRateChanged,
                onLanguageChanged: onLanguageChanged,
                onVoiceChanged: onVoiceChanged,
                onSleepTimerChanged: onSleepTimerChanged,
                onResetBookSettings: onResetBookSettings,
              ),
            ),
          ),
        );
      },
    );
  }

  static Future<bool> showEpubFootnote(
    BuildContext context, {
    required String text,
    String? label,
  }) async {
    final openInText = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) {
        final theme = Theme.of(sheetContext);
        return SafeArea(
          top: false,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.65,
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 4, 24, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          label?.trim().isNotEmpty == true ? label! : '脚注',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: '关闭脚注',
                        onPressed: () => Navigator.of(sheetContext).pop(false),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Flexible(
                    child: SingleChildScrollView(
                      child: SelectableText(
                        text,
                        style: theme.textTheme.bodyLarge?.copyWith(height: 1.7),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: () => Navigator.of(sheetContext).pop(true),
                      icon: const Icon(Icons.open_in_new_rounded, size: 18),
                      label: const Text('在正文中打开'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
    return openInText ?? false;
  }

  static void showAiPanel(
    BuildContext context, {
    required int bookId,
    Book? book,
    Chapter? chapter,
    required ReaderController controller,
    String? chapterContent,
    String? initialPrompt,
    AiPromptDraft? initialDraft,
    String? selectedText,
    String? surroundingText,
    SpoilerProtectionLevel spoilerProtectionLevel =
        SpoilerProtectionLevel.strict,
    ValueChanged<AiSourceReference>? onOpenReference,
  }) {
    // 构造 system context
    String? systemContext;
    if (book?.title != null ||
        chapter?.title != null ||
        surroundingText != null) {
      final parts = <String>[];
      if (book?.title != null) parts.add('书名：《${book!.title}》');
      if (chapter?.title != null) parts.add('章节：${chapter!.title}');
      if (surroundingText != null) {
        parts.add(
            '前后文：${surroundingText.length > 1000 ? '${surroundingText.substring(0, 1000)}…' : surroundingText}');
      }
      final contextInstruction = selectedText?.trim().isNotEmpty == true
          ? '请就用户选中的文本进行解答。'
          : '请结合当前阅读上下文回答。';
      systemContext = '用户正在阅读，${parts.join('；')}。$contextInstruction';
    }

    final effectiveDraft = resolveInitialDraft(
      initialDraft: initialDraft,
      initialPrompt: initialPrompt,
      selectedText: selectedText,
    );
    final effectiveInitialPrompt =
        effectiveDraft == null ? initialPrompt : null;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return FractionallySizedBox(
          heightFactor: 0.85,
          child: GlassContainer.stable(
            borderRadius: 24,
            color:
                Theme.of(context).colorScheme.surface.withValues(alpha: 0.98),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Theme.of(context).dividerColor,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Expanded(
                  child: AiChatPanel(
                    initialPrompt: effectiveInitialPrompt,
                    initialDraft: effectiveDraft,
                    chapterContent: chapterContent,
                    systemContext: systemContext,
                    agentContext: AgentContext(
                      bookId: bookId,
                      bookTitle: book?.title,
                      currentChapterId: chapter?.id,
                      currentChapterTitle: chapter?.title,
                      currentChapterOrder: controller.currentChapterIndex,
                      currentPosition: controller.scrollPosition,
                      selectedText: selectedText,
                      surroundingText: surroundingText,
                      spoilerProtectionLevel: spoilerProtectionLevel,
                    ),
                    onOpenReference: onOpenReference == null
                        ? null
                        : (reference) {
                            Navigator.of(context).pop();
                            onOpenReference(reference);
                          },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  static AiPromptDraft? draftFromLegacyPrompt(String? prompt) {
    if (prompt == null) return null;
    final split = prompt.indexOf('\n\n');
    if (split <= 0 || split >= prompt.length - 2) return null;
    final attachmentContent = prompt.substring(split + 2).trim();
    if (attachmentContent.length < 40) return null;
    return AiPromptDraft(
      instruction: prompt.substring(0, split).trim(),
      attachments: [
        AiAttachment(
          id: 'legacy-${DateTime.now().microsecondsSinceEpoch}',
          title: '长文本内容',
          content: attachmentContent,
        ),
      ],
    );
  }

  static AiPromptDraft selectionPromptDraft(String text) {
    return AiPromptDraft(
      instruction: '请解释这段选中文本，并结合上下文说明它在当前章节中的含义。',
      attachments: [
        AiAttachment(
          id: 'selection-${DateTime.now().microsecondsSinceEpoch}',
          title: '选中文本',
          content: text,
        ),
      ],
    );
  }

  static AiPromptDraft? resolveInitialDraft({
    AiPromptDraft? initialDraft,
    String? initialPrompt,
    String? selectedText,
  }) {
    if (initialDraft != null) return initialDraft;
    final legacyDraft = draftFromLegacyPrompt(initialPrompt);
    if (legacyDraft != null) return legacyDraft;
    if (initialPrompt != null) return null;
    final normalizedSelection = selectedText?.trim();
    if (normalizedSelection == null || normalizedSelection.isEmpty) return null;
    return selectionPromptDraft(normalizedSelection);
  }

  static String? surroundingTextAtPosition(
    String content,
    double position, {
    int maxChars = 1200,
  }) {
    final text = content.trim();
    if (text.isEmpty || maxChars <= 0) return null;
    if (text.length <= maxChars) return text;

    final normalizedPosition =
        position.isFinite ? position.clamp(0.0, 1.0).toDouble() : 0.0;
    final anchor = (normalizedPosition * (text.length - 1)).round();
    final maxStart = text.length - maxChars;
    final start = (anchor - maxChars ~/ 2).clamp(0, maxStart).toInt();
    return text.substring(start, start + maxChars);
  }

  static double? positionForSearchQuery(String content, String query) {
    final normalizedContent = content.toLowerCase();
    if (normalizedContent.isEmpty) return null;

    final candidates = <String>[
      query.trim(),
      ...query
          .trim()
          .split(RegExp(r'\s+'))
          .map((term) => term.replaceAll(RegExp(r'["“”‘’»«]+'), '').trim())
          .where((term) => term.isNotEmpty),
    ];

    int? bestIndex;
    for (final candidate in candidates) {
      if (candidate.isEmpty) continue;
      final index = normalizedContent.indexOf(candidate.toLowerCase());
      if (index >= 0 && (bestIndex == null || index < bestIndex)) {
        bestIndex = index;
      }
    }
    if (bestIndex == null) return null;
    return (bestIndex / content.length).clamp(0.0, 1.0).toDouble();
  }

  static void handleNote(
    BuildContext context, {
    required int bookId,
    required Chapter chapter,
    required String text,
    required int start,
    required int end,
    required dynamic noteService, // Passed from provider
  }) async {
    final noteId = await noteService.createNote(
      bookId: bookId,
      chapterId: chapter.id,
      selectedText: text,
      content: '',
      positionStart: start,
      positionEnd: end,
    );

    if (context.mounted) {
      Navigator.of(context, rootNavigator: true).push(
        GlassPageRoute(builder: (_) => NoteEditor(noteId: noteId)),
      );
    }
  }

  static void handleHighlight(
    BuildContext context, {
    required int bookId,
    required Chapter chapter,
    required String text,
    required int start,
    required int end,
    required dynamic noteService,
  }) async {
    await noteService.createNote(
      bookId: bookId,
      chapterId: chapter.id,
      selectedText: text,
      content: '', // highlight without note content
      positionStart: start,
      positionEnd: end,
    );

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('已添加高亮'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }
}
