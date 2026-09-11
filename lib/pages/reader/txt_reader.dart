import '../../models/reading_defaults.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import '../../utils/sentence_splitter.dart';
import '../../widgets/reader_context_menu.dart';
import '../../utils/font_utils.dart';
import 'format_reader.dart';
import 'paragraph_layout.dart';

class TxtReader extends FormatReader {
  final String content;
  final String? chapterTitle;
  final double fontSize;
  final double lineHeight;
  final double margin;
  final String? fontFamily;
  final double paragraphSpacing;
  final double letterSpacing;
  final double wordSpacing;
  final bool boldText;
  final TextAlign textAlign;
  final int paragraphIndent;
  final double topContentPadding;
  final ScrollController? scrollController;
  final int? activeSentenceIndex;
  final ValueChanged<String>? onAiAction;
  final ValueChanged<String>? onTranslateAction;
  final void Function(String text, int start, int end)? onTtsAction;
  final void Function(String text, int start, int end)? onVocabularyAction;
  final void Function(String text, int start, int end)? onHighlightAction;
  final void Function(String text, int start, int end)? onNoteAction;
  final int? locatorHighlightStart;
  final int? locatorHighlightEnd;

  final GlobalKey<_TxtReaderState> _readerKey = GlobalKey<_TxtReaderState>();

  TxtReader({
    super.key,
    required this.content,
    this.chapterTitle,
    this.fontSize = ReadingDefaults.fontSize,
    this.lineHeight = ReadingDefaults.lineHeight,
    this.margin = ReadingDefaults.margin,
    this.fontFamily,
    this.paragraphSpacing = ReadingDefaults.paragraphSpacing,
    this.letterSpacing = ReadingDefaults.letterSpacing,
    this.wordSpacing = ReadingDefaults.wordSpacing,
    this.boldText = ReadingDefaults.boldText,
    this.textAlign = TextAlign.start,
    this.paragraphIndent = ReadingDefaults.paragraphIndent,
    this.topContentPadding = ReadingDefaults.topContentPadding,
    this.scrollController,
    this.activeSentenceIndex,
    this.onAiAction,
    this.onTranslateAction,
    this.onTtsAction,
    this.onVocabularyAction,
    this.onHighlightAction,
    this.onNoteAction,
    this.locatorHighlightStart,
    this.locatorHighlightEnd,
  });

  @override
  double get currentPosition => _readerKey.currentState?.currentPosition ?? 0.0;

  @override
  void jumpToPosition(double pos) =>
      _readerKey.currentState?.jumpToPosition(pos);

  @override
  Stream<TextSelectionData> get onSelection =>
      _readerKey.currentState?.onSelection ?? const Stream.empty();

  @override
  void highlightSentence(int index) =>
      _readerKey.currentState?.highlightSentence(index);

  @override
  void clearHighlight() => _readerKey.currentState?.clearHighlight();

  @override
  bool get supportsSelection => true;

  @override
  bool get supportsPagedMode => true;

  @override
  State<TxtReader> createState() => _TxtReaderState();
}

class _TxtReaderState extends State<TxtReader> {
  static const _targetChunkSize = 1200;
  final _selectionController = StreamController<TextSelectionData>.broadcast();
  List<_TextChunk> _chunks = const [];
  List<SentenceSpan> _sentences = const [];
  String _selectedText = '';
  int _selectionStart = -1;
  int _selectionEnd = -1;

  double get currentPosition {
    final ctrl = widget.scrollController;
    if (ctrl == null || !ctrl.hasClients) return 0.0;
    final max = ctrl.position.maxScrollExtent;
    return max > 0 ? (ctrl.offset / max).clamp(0.0, 1.0) : 0.0;
  }

  void jumpToPosition(double pos) {
    final ctrl = widget.scrollController;
    if (ctrl == null || !ctrl.hasClients) return;
    ctrl.jumpTo(ctrl.position.maxScrollExtent * pos.clamp(0.0, 1.0));
  }

  Stream<TextSelectionData> get onSelection => _selectionController.stream;

  int? _localActiveIndex;

  @override
  void initState() {
    super.initState();
    _chunks = _splitIntoChunks(widget.content);
  }

  @override
  void didUpdateWidget(TxtReader oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.content != widget.content) {
      _chunks = _splitIntoChunks(widget.content);
      _sentences = const [];
    }
  }

  List<_TextChunk> _splitIntoChunks(String text) {
    if (text.isEmpty) return const [_TextChunk(0, '')];
    final chunks = <_TextChunk>[];
    final paragraphs = RegExp(r'[^\n]+').allMatches(text).toList();
    if (paragraphs.isEmpty) return const [_TextChunk(0, '')];

    for (var paragraphIndex = 0;
        paragraphIndex < paragraphs.length;
        paragraphIndex++) {
      final paragraph = paragraphs[paragraphIndex];
      final paragraphText = paragraph.group(0)!;
      final isLastParagraph = paragraphIndex == paragraphs.length - 1;
      var localStart = 0;

      while (localStart < paragraphText.length) {
        var localEnd = (localStart + _targetChunkSize).clamp(
          0,
          paragraphText.length,
        );
        if (localEnd < paragraphText.length) {
          final sentenceBreak = paragraphText.lastIndexOf(
            RegExp(r'[。！？.!?]'),
            localEnd,
          );
          if (sentenceBreak > localStart + (_targetChunkSize ~/ 2)) {
            localEnd = sentenceBreak + 1;
          }
        }
        if (localEnd <= localStart) {
          localEnd = (localStart + _targetChunkSize).clamp(
            0,
            paragraphText.length,
          );
        }

        final isParagraphEnd = localEnd >= paragraphText.length;
        chunks.add(
          _TextChunk(
            paragraph.start + localStart,
            paragraphText.substring(localStart, localEnd),
            startsParagraph: localStart == 0,
            paragraphBreakAfter: isParagraphEnd && !isLastParagraph,
          ),
        );
        localStart = localEnd;
      }
    }
    return chunks;
  }

  SentenceSpan? _activeSentence() {
    final activeIndex = _localActiveIndex ?? widget.activeSentenceIndex;
    if (activeIndex == null) return null;
    if (_sentences.isEmpty) {
      _sentences = SentenceSplitter.split(widget.content);
    }
    if (activeIndex < 0 || activeIndex >= _sentences.length) return null;
    return _sentences[activeIndex];
  }

  void highlightSentence(int index) {
    setState(() {
      _localActiveIndex = index;
    });
  }

  void clearHighlight() {
    setState(() {
      _localActiveIndex = null;
    });
  }

  /// Build each paragraph as a separate selectable block so paragraph spacing
  /// affects scroll mode consistently instead of relying on newline metrics.
  Widget _buildTextContent(_TextChunk chunk) {
    final baseStyle = TextStyle(
      fontSize: widget.fontSize,
      height: widget.lineHeight,
      fontFamily: FontUtils.resolveFontFamily(widget.fontFamily),
      fontFamilyFallback:
          FontUtils.resolveFontFamilyFallback(widget.fontFamily),
      letterSpacing: widget.letterSpacing,
      wordSpacing: widget.wordSpacing,
      fontWeight: widget.boldText ? FontWeight.w600 : FontWeight.normal,
    );

    return Padding(
      padding: EdgeInsets.only(
        bottom: chunk.paragraphBreakAfter ? widget.paragraphSpacing : 0,
      ),
      child: SizedBox(
        width: double.infinity,
        child: _buildSelectableParagraph(
          _TextParagraph(
            chunk.startOffset,
            chunk.text,
            startsParagraph: chunk.startsParagraph,
          ),
          baseStyle,
        ),
      ),
    );
  }

  Widget _buildSelectableParagraph(
    _TextParagraph paragraph,
    TextStyle baseStyle,
  ) {
    final spans = _buildParagraphSpans(paragraph);
    final indentPrefix = paragraphIndentPrefix(
      indentCount: widget.paragraphIndent,
      startsParagraph: paragraph.startsParagraph,
    );
    final renderedText = '$indentPrefix${paragraph.text}';

    return SelectableText.rich(
      TextSpan(
        style: baseStyle,
        children: [
          if (indentPrefix.isNotEmpty) TextSpan(text: indentPrefix),
          ...spans,
        ],
      ),
      textAlign: widget.textAlign,
      onSelectionChanged: (selection, cause) => _handleSelection(
        selection,
        _TextChunk(paragraph.startOffset, paragraph.text),
        renderedText,
        indentPrefix.length,
      ),
      contextMenuBuilder: (context, editableTextState) {
        return AdaptiveTextSelectionToolbar.buttonItems(
          anchors: editableTextState.contextMenuAnchors,
          buttonItems: buildReaderContextMenuItems(
            editableTextState: editableTextState,
            leadingTextLength: indentPrefix.length,
            onHighlight: widget.onHighlightAction == null
                ? null
                : (text, start, end) => widget.onHighlightAction!(
                      text,
                      paragraph.startOffset + start,
                      paragraph.startOffset + end,
                    ),
            onNote: widget.onNoteAction == null
                ? null
                : (text, start, end) => widget.onNoteAction!(
                      text,
                      paragraph.startOffset + start,
                      paragraph.startOffset + end,
                    ),
            onReadAloud: widget.onTtsAction == null
                ? null
                : (text, start, end) => widget.onTtsAction!(
                      text,
                      paragraph.startOffset + start,
                      paragraph.startOffset + end,
                    ),
            onVocabulary: widget.onVocabularyAction == null
                ? null
                : (text, start, end) => widget.onVocabularyAction!(
                      text,
                      paragraph.startOffset + start,
                      paragraph.startOffset + end,
                    ),
            onTranslate: widget.onTranslateAction,
            onAi: widget.onAiAction,
          ),
        );
      },
    );
  }

  List<InlineSpan> _buildParagraphSpans(_TextParagraph paragraph) {
    final activeSentence = _activeSentence();
    final paragraphEnd = paragraph.startOffset + paragraph.text.length;
    final children = <InlineSpan>[];
    final locatorStart = widget.locatorHighlightStart;
    final locatorEnd = widget.locatorHighlightEnd;
    final useLocator = locatorStart != null &&
        locatorEnd != null &&
        locatorStart < paragraphEnd &&
        locatorEnd > paragraph.startOffset;
    final globalHighlightStart =
        useLocator ? locatorStart : activeSentence?.startOffset;
    final globalHighlightEnd =
        useLocator ? locatorEnd : activeSentence?.endOffset;
    if (globalHighlightStart != null &&
        globalHighlightEnd != null &&
        globalHighlightStart < paragraphEnd &&
        globalHighlightEnd > paragraph.startOffset) {
      final highlightStart = (globalHighlightStart - paragraph.startOffset)
          .clamp(
            0,
            paragraph.text.length,
          )
          .toInt();
      final highlightEnd = (globalHighlightEnd - paragraph.startOffset)
          .clamp(
            0,
            paragraph.text.length,
          )
          .toInt();
      if (highlightStart > 0) {
        children
            .add(TextSpan(text: paragraph.text.substring(0, highlightStart)));
      }
      children.add(
        TextSpan(
          text: paragraph.text.substring(highlightStart, highlightEnd),
          style: TextStyle(
            backgroundColor: Theme.of(context)
                .colorScheme
                .primary
                .withValues(alpha: useLocator ? 0.22 : 0.15),
          ),
        ),
      );
      if (highlightEnd < paragraph.text.length) {
        children.add(
          TextSpan(text: paragraph.text.substring(highlightEnd)),
        );
      }
    } else {
      children.add(TextSpan(text: paragraph.text));
    }
    return children;
  }

  void _handleSelection(
    TextSelection selection,
    _TextChunk chunk,
    String renderedText,
    int leadingTextLength,
  ) {
    if (!selection.isCollapsed) {
      final selected = readerSelectedRange(
        renderedText: renderedText,
        selection: selection,
        leadingTextLength: leadingTextLength,
      );
      if (selected.text.isEmpty) return;
      setState(() {
        _selectedText = selected.text;
        _selectionStart = chunk.startOffset + selected.start;
        _selectionEnd = chunk.startOffset + selected.end;
      });
      _selectionController.add(TextSelectionData(
        text: _selectedText,
        startOffset: _selectionStart,
        endOffset: _selectionEnd,
      ));
    } else if (_selectedText.isNotEmpty) {
      setState(() => _selectedText = '');
    }
  }

  @override
  void dispose() {
    _selectionController.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final showTitle = widget.chapterTitle != null &&
        widget.chapterTitle!.isNotEmpty &&
        widget.chapterTitle != '全文';
    final topPadding =
        MediaQuery.paddingOf(context).top + widget.topContentPadding;
    final scrollable = ListView.builder(
      controller: widget.scrollController,
      padding:
          EdgeInsets.fromLTRB(widget.margin, topPadding, widget.margin, 80),
      itemCount: _chunks.length + (showTitle ? 1 : 0),
      itemBuilder: (context, index) {
        if (showTitle && index == 0) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 32),
            child: SelectableText(
              widget.chapterTitle!,
              style: TextStyle(
                fontSize: widget.fontSize * 1.6,
                fontWeight: FontWeight.bold,
                height: 1.3,
                letterSpacing: 1.0,
                fontFamily: FontUtils.resolveFontFamily(widget.fontFamily),
                fontFamilyFallback:
                    FontUtils.resolveFontFamilyFallback(widget.fontFamily),
              ),
            ),
          );
        }
        final chunkIndex = index - (showTitle ? 1 : 0);
        return RepaintBoundary(
          child: _buildTextContent(_chunks[chunkIndex]),
        );
      },
    );

    return Stack(
      children: [
        scrollable,
        if (_selectedText.isNotEmpty)
          Positioned(
            bottom: 32,
            left: 0,
            right: 0,
            child: Center(
              child: _buildFloatingToolbar(context),
            ),
          ),
      ],
    );
  }

  Widget _buildFloatingToolbar(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context)
            .colorScheme
            .surfaceContainerHighest
            .withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      constraints: BoxConstraints(
        maxWidth: MediaQuery.sizeOf(context).width - 24,
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.onTtsAction != null)
              IconButton(
                icon: const Icon(Icons.volume_up_outlined, size: 22),
                tooltip: '从此处朗读',
                onPressed: () {
                  widget.onTtsAction!(
                    _selectedText,
                    _selectionStart,
                    _selectionEnd,
                  );
                  setState(() => _selectedText = '');
                },
              ),
            if (widget.onVocabularyAction != null)
              IconButton(
                icon: const Icon(Icons.menu_book_outlined, size: 22),
                tooltip: '查词与加入生词本',
                onPressed: () {
                  widget.onVocabularyAction!(
                    _selectedText,
                    _selectionStart,
                    _selectionEnd,
                  );
                  setState(() => _selectedText = '');
                },
              ),
            if (widget.onHighlightAction != null)
              IconButton(
                icon: const Icon(Icons.format_paint_rounded, size: 22),
                tooltip: '高亮',
                onPressed: () {
                  widget.onHighlightAction!(
                      _selectedText, _selectionStart, _selectionEnd);
                  setState(() => _selectedText = '');
                },
              ),
            if (widget.onNoteAction != null)
              IconButton(
                icon: const Icon(Icons.edit_note_rounded, size: 22),
                tooltip: '写笔记',
                onPressed: () {
                  widget.onNoteAction!(
                      _selectedText, _selectionStart, _selectionEnd);
                  setState(() => _selectedText = '');
                },
              ),
            if (widget.onAiAction != null)
              IconButton(
                icon: const Icon(Icons.auto_awesome, size: 22),
                tooltip: 'AI 解释',
                onPressed: () {
                  widget.onAiAction!(_selectedText);
                  setState(() => _selectedText = '');
                },
              ),
            const SizedBox(width: 8),
            Container(
                width: 1, height: 24, color: Theme.of(context).dividerColor),
            IconButton(
              icon: const Icon(Icons.close, size: 20),
              tooltip: '关闭',
              onPressed: () => setState(() => _selectedText = ''),
            ),
          ],
        ),
      ),
    );
  }
}

class _TextChunk {
  final int startOffset;
  final String text;
  final bool startsParagraph;
  final bool paragraphBreakAfter;

  const _TextChunk(
    this.startOffset,
    this.text, {
    this.startsParagraph = false,
    this.paragraphBreakAfter = false,
  });
}

class _TextParagraph {
  final int startOffset;
  final String text;
  final bool startsParagraph;

  const _TextParagraph(
    this.startOffset,
    this.text, {
    required this.startsParagraph,
  });
}
