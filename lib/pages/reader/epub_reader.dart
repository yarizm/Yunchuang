import '../../models/reading_defaults.dart';
import 'dart:developer' as developer;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import '../../models/html_text_document.dart';
import '../../models/tts_highlight.dart';
import '../../utils/html_to_textspan.dart';
import '../../widgets/reader_context_menu.dart';
import '../../utils/font_utils.dart';
import 'format_reader.dart';
import 'paragraph_layout.dart';
import 'reader_highlights.dart';
import 'reader_scroll_controller.dart';

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
  final TtsHighlight? ttsHighlight;
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

  const EpubReader({
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
    this.ttsHighlight,
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
  bool get supportsSelection => true;

  @override
  bool get supportsPagedMode => true;

  @override
  State<EpubReader> createState() => _EpubReaderState();
}

class _EpubReaderState extends State<EpubReader> {
  static const _targetChunkSize = 1200;

  ScrollController? _internalController;

  List<_EpubChunk> _chunks = const [];
  List<ReaderTextRange> _chunkRanges = const [];
  List<TextHighlightLayer> _highlightLayers = const [];
  String _plainText = '';
  List<GestureRecognizer> _linkRecognizers = [];

  /// Extract the plain text from rendered spans (for highlight alignment).
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

  List<InlineSpan> _highlightedSpans(_EpubChunk chunk) {
    return applyHighlightLayers(
      chunk.spans,
      chunk.startOffset,
      _highlightLayers,
    );
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
      _chunks = _splitSpansIntoChunks(spans);
      _chunkRanges = [
        for (final chunk in _chunks)
          (start: chunk.startOffset, end: chunk.endOffset),
      ];
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
    _highlightLayers = readerHighlightLayers(
      theme.colorScheme,
      tts: widget.ttsHighlight,
      locatorStart: widget.locatorHighlightStart,
      locatorEnd: widget.locatorHighlightEnd,
    );
    if (controller is ReaderScrollController) {
      controller.updateLayout(
        textLength: _plainText.length,
        ranges: _chunkRanges,
        leadingItemCount: showTitle ? 1 : 0,
        topInset: topPadding,
      );
    }

    final list = ListView.builder(
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
    return controller is ReaderScrollController
        ? HiddenWhileRestoring(controller: controller, child: list)
        : list;
  }

  @override
  void dispose() {
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
