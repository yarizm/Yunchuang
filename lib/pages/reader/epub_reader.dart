import '../../models/reading_defaults.dart';
import 'dart:async';
import 'dart:developer' as developer;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import '../../models/html_text_document.dart';
import '../../utils/html_to_textspan.dart';
import '../../utils/sentence_splitter.dart';
import '../../widgets/reader_context_menu.dart';
import '../../utils/font_utils.dart';
import 'format_reader.dart';
import 'paragraph_layout.dart';

class EpubReader extends FormatReader {
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
  final int? activeSentenceIndex;
  final ValueChanged<String>? onAiAction;
  final ValueChanged<String>? onTranslateAction;
  final void Function(String text, int start, int end)? onTtsAction;
  final void Function(String text, int start, int end)? onVocabularyAction;
  final void Function(String text, int start, int end)? onHighlightAction;
  final void Function(String text, int start, int end)? onNoteAction;
  final ScrollController? scrollController;
  final int? locatorHighlightStart;
  final int? locatorHighlightEnd;
  final ValueChanged<HtmlTextLink>? onLinkTap;

  final GlobalKey<_EpubReaderState> _readerKey = GlobalKey<_EpubReaderState>();

  EpubReader({
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
    this.activeSentenceIndex,
    this.onAiAction,
    this.onTranslateAction,
    this.onTtsAction,
    this.onVocabularyAction,
    this.onHighlightAction,
    this.onNoteAction,
    this.scrollController,
    this.locatorHighlightStart,
    this.locatorHighlightEnd,
    this.onLinkTap,
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
  State<EpubReader> createState() => _EpubReaderState();
}

class _EpubReaderState extends State<EpubReader> {
  static const _targetChunkSize = 1200;

  final _selectionController = StreamController<TextSelectionData>.broadcast();
  ScrollController? _internalController;

  List<_EpubChunk> _chunks = const [];
  List<SentenceSpan> _sentences = [];
  String _plainText = '';
  int? _localActiveIndex;
  String _selectedText = '';
  int _selectionStart = -1;
  int _selectionEnd = -1;
  List<GestureRecognizer> _linkRecognizers = [];

  double get currentPosition {
    final ctrl = widget.scrollController ?? _internalController;
    if (ctrl == null || !ctrl.hasClients) return 0.0;
    final max = ctrl.position.maxScrollExtent;
    return max > 0 ? (ctrl.offset / max).clamp(0.0, 1.0) : 0.0;
  }

  void jumpToPosition(double pos) {
    final ctrl = widget.scrollController ?? _internalController;
    if (ctrl == null || !ctrl.hasClients) return;
    final max = ctrl.position.maxScrollExtent;
    ctrl.jumpTo(max * pos.clamp(0.0, 1.0));
  }

  Stream<TextSelectionData> get onSelection => _selectionController.stream;

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

  /// Extract the plain text from rendered spans (for sentence split alignment).
  String _spansToPlainText(List<InlineSpan> spans) {
    final buf = StringBuffer();
    for (final span in spans) {
      if (span is TextSpan) {
        buf.write(span.text ?? '');
        if (span.children != null) {
          buf.write(_spansToPlainText(span.children!));
        }
      }
    }
    return buf.toString();
  }

  /// Rebuild spans with background highlight applied to spans that overlap
  /// with the active sentence's character range in the plain text.
  List<InlineSpan> _highlightedSpans(_EpubChunk chunk) {
    final locatorStart = widget.locatorHighlightStart;
    final locatorEnd = widget.locatorHighlightEnd;
    if (locatorStart != null &&
        locatorEnd != null &&
        locatorStart < chunk.endOffset &&
        locatorEnd > chunk.startOffset) {
      return _applyHighlight(
        chunk.spans,
        locatorStart - chunk.startOffset,
        locatorEnd - chunk.startOffset,
        alpha: 0.22,
      );
    }
    final activeIdx = _localActiveIndex ?? widget.activeSentenceIndex;
    if (activeIdx == null || activeIdx < 0 || activeIdx >= _sentences.length) {
      return chunk.spans;
    }
    final sentence = _sentences[activeIdx];
    if (sentence.startOffset >= chunk.endOffset ||
        sentence.endOffset <= chunk.startOffset) {
      return chunk.spans;
    }
    return _applyHighlight(
      chunk.spans,
      sentence.startOffset - chunk.startOffset,
      sentence.endOffset - chunk.startOffset,
    );
  }

  List<InlineSpan> _applyHighlight(
    List<InlineSpan> spans,
    int highlightStart,
    int highlightEnd, {
    double alpha = 0.15,
  }) {
    final highlightColor =
        Theme.of(context).colorScheme.primary.withValues(alpha: alpha);
    int charPos = 0;
    final result = <InlineSpan>[];

    for (final span in spans) {
      if (span is TextSpan) {
        final text = span.text ?? '';
        final spanStart = charPos;
        final spanEnd = charPos + text.length;
        charPos = spanEnd;

        if (text.isEmpty ||
            spanEnd <= highlightStart ||
            spanStart >= highlightEnd) {
          result.add(span);
          continue;
        }

        final localStart = (highlightStart - spanStart).clamp(0, text.length);
        final localEnd = (highlightEnd - spanStart).clamp(0, text.length);
        if (localStart > 0) {
          result.add(TextSpan(
            text: text.substring(0, localStart),
            style: span.style,
            recognizer: span.recognizer,
          ));
        }
        result.add(TextSpan(
          text: text.substring(localStart, localEnd),
          style: (span.style ?? const TextStyle()).copyWith(
            backgroundColor: highlightColor,
          ),
          recognizer: span.recognizer,
        ));
        if (localEnd < text.length) {
          result.add(TextSpan(
            text: text.substring(localEnd),
            style: span.style,
            recognizer: span.recognizer,
          ));
        }
      } else {
        result.add(span);
      }
    }
    return result;
  }

  @override
  void initState() {
    super.initState();
    _rebuildSpans();
  }

  void _rebuildSpans() {
    developer.Timeline.startSync('html_to_spans');
    try {
      final previousRecognizers = _linkRecognizers;
      _linkRecognizers = [];
      final spans = htmlToTextSpans(
        widget.content,
        baseFontSize: widget.fontSize,
        paragraphSpacing: 0,
        onLinkTap: widget.onLinkTap == null
            ? null
            : (link) => widget.onLinkTap?.call(link),
        recognizers: _linkRecognizers,
      );
      _plainText = _spansToPlainText(spans);
      _sentences = SentenceSplitter.split(_plainText);
      _chunks = _splitSpansIntoChunks(spans);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        for (final recognizer in previousRecognizers) {
          recognizer.dispose();
        }
      });
    } finally {
      developer.Timeline.finishSync();
    }
  }

  List<_EpubChunk> _splitSpansIntoChunks(List<InlineSpan> spans) {
    final pieces = <_StyledTextPiece>[];
    _collectTextPieces(spans, pieces);
    if (pieces.isEmpty) {
      return const [
        _EpubChunk(0, [TextSpan(text: '')], '')
      ];
    }

    final chunks = <_EpubChunk>[];
    final chunkSpans = <InlineSpan>[];
    final chunkText = StringBuffer();
    var chunkStartOffset = 0;
    var offset = 0;
    var chunkStarted = false;
    var chunkStartsParagraph = false;
    var nextChunkStartsParagraph = true;

    void ensureChunkStarted() {
      if (chunkStarted) return;
      chunkStartOffset = offset;
      chunkStartsParagraph = nextChunkStartsParagraph;
      nextChunkStartsParagraph = false;
      chunkStarted = true;
    }

    void flush({bool paragraphBreakAfter = false}) {
      if (!chunkStarted) {
        if (paragraphBreakAfter) nextChunkStartsParagraph = true;
        return;
      }
      if (chunkSpans.isNotEmpty || chunkText.isNotEmpty) {
        chunks.add(_EpubChunk(
          chunkStartOffset,
          List<InlineSpan>.unmodifiable(chunkSpans),
          chunkText.toString(),
          startsParagraph: chunkStartsParagraph,
          paragraphBreakAfter: paragraphBreakAfter,
        ));
      }
      chunkSpans.clear();
      chunkText.clear();
      chunkStarted = false;
      if (paragraphBreakAfter) nextChunkStartsParagraph = true;
    }

    void addText(
      String text,
      TextStyle? style,
      GestureRecognizer? recognizer,
    ) {
      var remaining = text;
      while (remaining.isNotEmpty) {
        if (chunkText.length >= _targetChunkSize) {
          flush();
        }
        ensureChunkStarted();
        final available = _targetChunkSize - chunkText.length;
        final take = available <= 0
            ? remaining.length
            : (remaining.length < available ? remaining.length : available);
        final part = remaining.substring(0, take);
        chunkSpans.add(
          TextSpan(text: part, style: style, recognizer: recognizer),
        );
        chunkText.write(part);
        offset += part.length;
        remaining = remaining.substring(take);

        if (chunkText.length >= _targetChunkSize && remaining.isNotEmpty) {
          flush();
        }
      }
    }

    for (final piece in pieces) {
      var segmentStart = 0;
      for (var index = 0; index < piece.text.length; index++) {
        if (piece.text.codeUnitAt(index) != 0x0A) continue;
        if (index > segmentStart) {
          addText(
            piece.text.substring(segmentStart, index),
            piece.style,
            piece.recognizer,
          );
        }
        flush(paragraphBreakAfter: true);
        offset += 1;
        segmentStart = index + 1;
      }
      if (segmentStart < piece.text.length) {
        addText(
          piece.text.substring(segmentStart),
          piece.style,
          piece.recognizer,
        );
      }
    }
    flush();
    return chunks.isEmpty
        ? const [
            _EpubChunk(0, [TextSpan(text: '')], '')
          ]
        : chunks;
  }

  void _collectTextPieces(
    List<InlineSpan> spans,
    List<_StyledTextPiece> pieces,
  ) {
    for (final span in spans) {
      if (span is! TextSpan) continue;
      final text = span.text ?? '';
      if (text.isNotEmpty) {
        pieces.add(
          _StyledTextPiece(text, span.style, span.recognizer),
        );
      }
      if (span.children != null) {
        _collectTextPieces(span.children!, pieces);
      }
    }
  }

  @override
  void didUpdateWidget(EpubReader oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.content != widget.content ||
        oldWidget.fontSize != widget.fontSize) {
      _rebuildSpans();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final controller =
        widget.scrollController ?? (_internalController ??= ScrollController());
    final showTitle = widget.chapterTitle != null &&
        widget.chapterTitle!.isNotEmpty &&
        widget.chapterTitle != '全文';
    final baseStyle = TextStyle(
      fontSize: widget.fontSize,
      height: widget.lineHeight,
      fontFamily: FontUtils.resolveFontFamily(widget.fontFamily),
      fontFamilyFallback:
          FontUtils.resolveFontFamilyFallback(widget.fontFamily),
      letterSpacing: widget.letterSpacing,
      wordSpacing: widget.wordSpacing,
      fontWeight: widget.boldText ? FontWeight.w600 : FontWeight.normal,
      color: theme.colorScheme.onSurface,
    );
    final topPadding =
        MediaQuery.paddingOf(context).top + widget.topContentPadding;

    return ListView.builder(
      controller: controller,
      padding:
          EdgeInsets.fromLTRB(widget.margin, topPadding, widget.margin, 80),
      itemCount: _chunks.length + (showTitle ? 1 : 0),
      itemBuilder: (context, index) {
        if (showTitle && index == 0) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 32),
            child: Text(
              widget.chapterTitle!,
              style: TextStyle(
                fontSize: widget.fontSize * 1.6,
                fontWeight: FontWeight.bold,
                height: 1.3,
                letterSpacing: 1.0,
                fontFamily: FontUtils.resolveFontFamily(widget.fontFamily),
                fontFamilyFallback:
                    FontUtils.resolveFontFamilyFallback(widget.fontFamily),
                color: theme.colorScheme.onSurface,
              ),
            ),
          );
        }

        final chunk = _chunks[index - (showTitle ? 1 : 0)];
        final indentPrefix = paragraphIndentPrefix(
          indentCount: widget.paragraphIndent,
          startsParagraph: chunk.startsParagraph,
        );
        final renderedText = '$indentPrefix${chunk.plainText}';
        return RepaintBoundary(
          child: Padding(
            padding: EdgeInsets.only(
              bottom: chunk.paragraphBreakAfter ? widget.paragraphSpacing : 0,
            ),
            child: SelectableText.rich(
              TextSpan(
                style: baseStyle,
                children: [
                  if (indentPrefix.isNotEmpty) TextSpan(text: indentPrefix),
                  ..._highlightedSpans(chunk),
                ],
              ),
              textAlign: widget.textAlign,
              onSelectionChanged: (selection, cause) => _handleSelection(
                selection,
                chunk,
                renderedText,
                indentPrefix.length,
              ),
              contextMenuBuilder: (context, editableTextState) {
                return AdaptiveTextSelectionToolbar.buttonItems(
                  anchors: editableTextState.contextMenuAnchors,
                  buttonItems: buildReaderContextMenuItems(
                    editableTextState: editableTextState,
                    leadingTextLength: indentPrefix.length,
                    onHighlight: (text, start, end) =>
                        widget.onHighlightAction?.call(
                      text,
                      chunk.startOffset + start,
                      chunk.startOffset + end,
                    ),
                    onNote: (text, start, end) => widget.onNoteAction?.call(
                      text,
                      chunk.startOffset + start,
                      chunk.startOffset + end,
                    ),
                    onReadAloud: widget.onTtsAction == null
                        ? null
                        : (text, start, end) => widget.onTtsAction!(
                              text,
                              chunk.startOffset + start,
                              chunk.startOffset + end,
                            ),
                    onVocabulary: widget.onVocabularyAction == null
                        ? null
                        : (text, start, end) => widget.onVocabularyAction!(
                              text,
                              chunk.startOffset + start,
                              chunk.startOffset + end,
                            ),
                    onTranslate: widget.onTranslateAction,
                    onAi: (text) => widget.onAiAction?.call(text),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  void _handleSelection(
    TextSelection selection,
    _EpubChunk chunk,
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
      _selectedText = selected.text;
      _selectionStart = chunk.startOffset + selected.start;
      _selectionEnd = chunk.startOffset + selected.end;
      _selectionController.add(TextSelectionData(
        text: _selectedText,
        startOffset: _selectionStart,
        endOffset: _selectionEnd,
      ));
    }
  }

  @override
  void dispose() {
    _selectionController.close();
    _internalController?.dispose();
    for (final recognizer in _linkRecognizers) {
      recognizer.dispose();
    }
    super.dispose();
  }
}

class _EpubChunk {
  final int startOffset;
  final List<InlineSpan> spans;
  final String plainText;
  final bool startsParagraph;
  final bool paragraphBreakAfter;

  const _EpubChunk(
    this.startOffset,
    this.spans,
    this.plainText, {
    this.startsParagraph = false,
    this.paragraphBreakAfter = false,
  });

  int get endOffset => startOffset + plainText.length;
}

class _StyledTextPiece {
  final String text;
  final TextStyle? style;
  final GestureRecognizer? recognizer;

  const _StyledTextPiece(this.text, this.style, this.recognizer);
}
