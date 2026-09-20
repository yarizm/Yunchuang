import '../../models/reading_defaults.dart';
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import '../../widgets/reader_context_menu.dart';
import '../../utils/font_utils.dart';
import '../../utils/sentence_splitter.dart';
import '../../typography/typesetter.dart';
import 'format_reader.dart';
import 'paragraph_layout.dart';

class PagedReader extends FormatReader {
  final String content;
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
  final String? chapterTitle;
  final ValueChanged<String>? onAiAction;
  final ValueChanged<String>? onTranslateAction;
  final void Function(String text, int start, int end)? onTtsAction;
  final void Function(String text, int start, int end)? onVocabularyAction;
  final void Function(String text, int start, int end)? onHighlightAction;
  final void Function(String text, int start, int end)? onNoteAction;
  final double initialPosition;
  final ValueChanged<double>? onPositionChanged;
  final ValueChanged<int>? onPageChanged;
  final VoidCallback? onAdvanceBeyondLast;
  final VoidCallback? onRetreatBeforeFirst;
  final String pageTurnEffect;
  final int? locatorHighlightStart;
  final int? locatorHighlightEnd;
  final int? activeSentenceIndex;

  PagedReader({
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
    this.onAiAction,
    this.onTranslateAction,
    this.onTtsAction,
    this.onVocabularyAction,
    this.onHighlightAction,
    this.onNoteAction,
    this.initialPosition = 0.0,
    this.onPositionChanged,
    this.onPageChanged,
    this.onAdvanceBeyondLast,
    this.onRetreatBeforeFirst,
    this.pageTurnEffect = 'curl',
    this.locatorHighlightStart,
    this.locatorHighlightEnd,
    this.activeSentenceIndex,
  });

  final GlobalKey<_PagedReaderState> _readerKey =
      GlobalKey<_PagedReaderState>();

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
  State<PagedReader> createState() => _PagedReaderState();
}

class _PagedReaderState extends State<PagedReader> {
  static const _pageIndicatorReserve = 24.0;
  static const _pageBottomPadding = 16.0;
  static const _titleBottomSpacing = 24.0;
  static const _chapterBoundaryDelay = Duration(milliseconds: 180);

  late PageController _pageController;
  List<int> _pageOffsets = [];
  int _currentPage = 0;
  double _pageHeight = 0;
  double _pageWidth = 0;
  double _lastPageTopPadding = -1;
  DateTime? _lastAdvanceBeyondLastAt;
  DateTime? _lastRetreatBeforeFirstAt;
  Timer? _chapterBoundaryTimer;
  bool _chapterBoundaryRequestPending = false;
  Offset? _pagePointerDownLocal;
  int? _pageTurnOrigin;
  int? _localActiveSentenceIndex;
  List<SentenceSpan> _sentences = const [];

  bool _isComputingPages = false;
  int _paginationRevision = 0;
  int _activePaginationRevision = 0;
  ({double width, double height})? _pendingPageCompute;

  /// 段落文本（含缩进前缀）→ 行盒。宽度或排版样式变化时清空。
  final Map<String, List<LineBox>> _paragraphLineCache = {};

  double get currentPosition {
    if (_pageOffsets.isEmpty || widget.content.isEmpty) return 0.0;
    return (_pageOffsets[_currentPage] / widget.content.length).clamp(
      0.0,
      1.0,
    );
  }

  void jumpToPosition(double pos) {
    if (_pageOffsets.isEmpty) return;
    final page = _pageForPosition(pos);
    if (_pageController.hasClients) {
      _pageController.jumpToPage(page);
    }
  }

  Stream<TextSelectionData> get onSelection => const Stream.empty();

  void highlightSentence(int index) {
    setState(() => _localActiveSentenceIndex = index);
    _scheduleActiveSentencePageJump();
  }

  void clearHighlight() {
    setState(() => _localActiveSentenceIndex = null);
  }

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _sentences = SentenceSplitter.split(widget.content);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _paginationRevision++;
    _pageHeight = 0;
    _pageWidth = 0;
    _pageOffsets = [];
    _paragraphLineCache.clear();
  }

  double get _effectiveTopPadding =>
      MediaQuery.paddingOf(context).top + widget.topContentPadding;

  bool _needsPageCompute(double width, double height) {
    return width != _pageWidth ||
        height != _pageHeight ||
        _effectiveTopPadding != _lastPageTopPadding ||
        _pageOffsets.isEmpty;
  }

  void _scheduleComputePages(double width, double height) {
    if (_isComputingPages) {
      if (width != _pageWidth ||
          height != _pageHeight ||
          _effectiveTopPadding != _lastPageTopPadding ||
          _activePaginationRevision != _paginationRevision) {
        _pendingPageCompute = (width: width, height: height);
      }
      return;
    }
    unawaited(_computePagesAsync(width, height));
  }

  Future<void> _computePagesAsync(double width, double height) async {
    if (!mounted) return;
    if (!_needsPageCompute(width, height)) {
      return;
    }

    final revision = _paginationRevision;
    final topPadding = _effectiveTopPadding;
    _activePaginationRevision = revision;
    _isComputingPages = true;

    try {
      if (_pageWidth != width) {
        _paragraphLineCache.clear();
      }

      _pageHeight = height;
      _pageWidth = width;
      _lastPageTopPadding = topPadding;

      final anchor =
          _pageOffsets.isEmpty ? widget.initialPosition : currentPosition;
      final nextOffsets = await _paginateContentAsync(
        _pageWidth,
        _pageHeight,
        revision,
      );

      if (!mounted ||
          nextOffsets == null ||
          revision != _paginationRevision ||
          _pendingPageCompute != null ||
          _pageWidth != width ||
          _pageHeight != height ||
          _effectiveTopPadding != topPadding) {
        return;
      }

      _pageOffsets = nextOffsets;
      final startPage =
          anchor >= 1.0 ? _pageOffsets.length - 1 : _pageForPosition(anchor);
      _currentPage = startPage;

      setState(() {});
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _pageController.hasClients) {
          _pageController.jumpToPage(startPage);
          _jumpToActiveSentencePage();
        }
      });
    } finally {
      _isComputingPages = false;
      if (mounted) {
        final pending = _pendingPageCompute;
        _pendingPageCompute = null;
        if (pending != null) {
          _scheduleComputePages(pending.width, pending.height);
        }
      }
    }
  }

  bool get _hasChapterTitle {
    final title = widget.chapterTitle?.trim();
    return title != null && title.isNotEmpty && title != '全文';
  }

  TextStyle get _bodyStyle {
    return TextStyle(
      fontSize: widget.fontSize,
      height: widget.lineHeight,
      fontFamily: FontUtils.resolveFontFamily(widget.fontFamily),
      fontFamilyFallback:
          FontUtils.resolveFontFamilyFallback(widget.fontFamily),
      letterSpacing: widget.letterSpacing,
      wordSpacing: widget.wordSpacing,
      fontWeight: widget.boldText ? FontWeight.w600 : FontWeight.normal,
    );
  }

  TextStyle get _titleStyle {
    return TextStyle(
      fontSize: widget.fontSize * 1.5,
      fontWeight: FontWeight.bold,
      height: 1.3,
      fontFamily: FontUtils.resolveFontFamily(widget.fontFamily),
      fontFamilyFallback:
          FontUtils.resolveFontFamilyFallback(widget.fontFamily),
    );
  }

  Future<List<int>?> _paginateContentAsync(
    double pageWidth,
    double pageHeight,
    int revision,
  ) async {
    if (widget.content.isEmpty) return const [0];

    final textDirection = Directionality.maybeOf(context) ?? TextDirection.ltr;
    final contentWidth = math.max(1.0, pageWidth - widget.margin * 2);
    // 行盒高度与渲染端精确一致（见 test/typography/
    // selectable_text_parity_test.dart），但渲染端对「页文本切片」独立
    // 断行时，与整章断行存在不可归因的宽度边界微差：中文长页比度量
    // 多断一行（693 字符：度量 17 行，渲染 18 行），西文按词断行加
    // 句级 span 拆分时可差两行（500 句拉丁文本实测溢出一行）。该余量
    // 与旧 layoutSlack 相同，待接管渲染（按行盒渲染、关闭自动换行）
    // 后可移除。
    final pageBodyHeight = math.max(
      1.0,
      pageHeight -
          _effectiveTopPadding -
          _pageBottomPadding -
          widget.fontSize * widget.lineHeight * 2,
    );
    final firstPageBodyHeight = math.max(
      1.0,
      pageBodyHeight - _titleBlockHeight(contentWidth, textDirection),
    );
    final paragraphs = RegExp(r'[^\n]+').allMatches(widget.content).toList();
    if (paragraphs.isEmpty) return const [0];

    // 与渲染端一致：每个段落独立断行，段首带缩进前缀。行盒偏移在度量
    // 文本（缩进 + 段文本）坐标系下产生，这里换算回原文章节坐标。
    const measurer = FlutterTextMeasurer();
    final stopwatch = Stopwatch()..start();
    final allLines = <LineBox>[];

    for (var paragraphIndex = 0;
        paragraphIndex < paragraphs.length;
        paragraphIndex++) {
      if (stopwatch.elapsedMilliseconds > 12) {
        await Future.delayed(Duration.zero);
        if (!mounted || revision != _paginationRevision) return null;
        stopwatch.reset();
      }

      final paragraph = paragraphs[paragraphIndex];
      final paragraphText = paragraph.group(0)!;
      final indentPrefix = paragraphIndentPrefix(
        indentCount: widget.paragraphIndent,
        startsParagraph:
            isLogicalParagraphStart(widget.content, paragraph.start),
      );
      final measureKey = '$indentPrefix$paragraphText';
      var paragraphLines = _paragraphLineCache[measureKey];
      if (paragraphLines == null) {
        final measured = measurer.layout(
          text: measureKey,
          style: _bodyStyle,
          maxWidth: contentWidth,
          direction: textDirection,
        );
        final indentLength = indentPrefix.length;
        paragraphLines = [
          for (final line in measured)
            LineBox(
              start: paragraph.start + math.max(0, line.start - indentLength),
              end: paragraph.start + math.max(0, line.end - indentLength),
              height: line.height,
            ),
        ];
        _paragraphLineCache[measureKey] = paragraphLines;
      }
      if (paragraphLines.isEmpty) continue;

      // 段落之间由原文中的 \n 分隔；paginate 依据段末行的 hardBreak
      // 计入段间距。度量文本不含换行符，故末行在此补标。
      final last = paragraphLines.last;
      allLines.addAll(paragraphLines.sublist(0, paragraphLines.length - 1));
      allLines.add(
        LineBox(
          start: last.start,
          end: last.end,
          height: last.height,
          hardBreak: true,
        ),
      );
    }

    final pages = paginate(
      lines: allLines,
      firstPageHeight: firstPageBodyHeight,
      pageHeight: pageBodyHeight,
      paragraphSpacing: widget.paragraphSpacing,
    );
    return revision == _paginationRevision
        ? [for (final page in pages) page.startOffset]
        : null;
  }

  double _titleBlockHeight(double maxWidth, TextDirection textDirection) {
    if (!_hasChapterTitle) return 0;
    return _measureTextHeight(
          widget.chapterTitle!,
          _titleStyle,
          maxWidth,
          textDirection,
        ) +
        _titleBottomSpacing;
  }

  double _measureTextHeight(
    String text,
    TextStyle style,
    double maxWidth,
    TextDirection textDirection,
  ) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: textDirection,
      textAlign: widget.textAlign,
    )..layout(maxWidth: maxWidth);
    return painter.height;
  }

  int _pageForPosition(double position) {
    if (_pageOffsets.length <= 1 || widget.content.isEmpty) return 0;
    final target = (position.clamp(0.0, 1.0) * widget.content.length).round();
    var low = 0;
    var high = _pageOffsets.length - 1;
    while (low <= high) {
      final middle = (low + high) >> 1;
      if (_pageOffsets[middle] <= target) {
        low = middle + 1;
      } else {
        high = middle - 1;
      }
    }
    return high.clamp(0, _pageOffsets.length - 1);
  }

  double _positionForPage(int page) {
    if (_pageOffsets.isEmpty || widget.content.isEmpty) return 0.0;
    return (_pageOffsets[page] / widget.content.length).clamp(0.0, 1.0);
  }

  void _scheduleActiveSentencePageJump() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _jumpToActiveSentencePage();
    });
  }

  void _jumpToActiveSentencePage() {
    final activeIndex = _localActiveSentenceIndex ?? widget.activeSentenceIndex;
    if (activeIndex == null ||
        activeIndex < 0 ||
        activeIndex >= _sentences.length ||
        _pageOffsets.isEmpty ||
        widget.content.isEmpty ||
        !_pageController.hasClients) {
      return;
    }
    final sentence = _sentences[activeIndex];
    final targetPage = _pageForPosition(
      sentence.startOffset / widget.content.length,
    );
    if (targetPage == _currentPage) return;
    unawaited(
      _pageController.animateToPage(
        targetPage,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
      ),
    );
  }

  @override
  void didUpdateWidget(PagedReader oldWidget) {
    super.didUpdateWidget(oldWidget);
    final layoutChanged = oldWidget.fontSize != widget.fontSize ||
        oldWidget.lineHeight != widget.lineHeight ||
        oldWidget.margin != widget.margin ||
        oldWidget.fontFamily != widget.fontFamily ||
        oldWidget.paragraphSpacing != widget.paragraphSpacing ||
        oldWidget.letterSpacing != widget.letterSpacing ||
        oldWidget.wordSpacing != widget.wordSpacing ||
        oldWidget.boldText != widget.boldText ||
        oldWidget.textAlign != widget.textAlign ||
        oldWidget.paragraphIndent != widget.paragraphIndent ||
        oldWidget.topContentPadding != widget.topContentPadding ||
        oldWidget.chapterTitle != widget.chapterTitle ||
        oldWidget.content != widget.content;
    if (layoutChanged) {
      if (oldWidget.content != widget.content) {
        _sentences = SentenceSplitter.split(widget.content);
        _localActiveSentenceIndex = null;
      }
      _paginationRevision++;
      _pageHeight = 0; // force recompute
      _pageWidth = 0;
      _pageOffsets = [];
      _currentPage = 0;
      _paragraphLineCache.clear();
      _cancelChapterBoundaryRequest();
    } else if (oldWidget.initialPosition != widget.initialPosition &&
        _pageOffsets.isNotEmpty) {
      final targetPage = _pageForPosition(widget.initialPosition);
      if (targetPage != _currentPage) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted || !_pageController.hasClients) return;
          _pageController.jumpToPage(targetPage);
        });
      }
    }
    if (oldWidget.activeSentenceIndex != widget.activeSentenceIndex) {
      _scheduleActiveSentencePageJump();
    }
  }

  @override
  void dispose() {
    _cancelChapterBoundaryRequest();
    _pageController.dispose();
    super.dispose();
  }

  void _cancelChapterBoundaryRequest() {
    _chapterBoundaryTimer?.cancel();
    _chapterBoundaryTimer = null;
    _chapterBoundaryRequestPending = false;
  }

  bool _scheduleChapterBoundaryRequest(VoidCallback callback) {
    if (_chapterBoundaryRequestPending) {
      return false;
    }
    _chapterBoundaryRequestPending = true;
    _chapterBoundaryTimer?.cancel();
    _chapterBoundaryTimer = Timer(_chapterBoundaryDelay, () {
      _chapterBoundaryTimer = null;
      if (!mounted) return;
      callback();
      _chapterBoundaryRequestPending = false;
    });
    return true;
  }

  bool _requestAdvanceBeyondLast() {
    if (_currentPage < _pageOffsets.length - 1 ||
        widget.onAdvanceBeyondLast == null) {
      return false;
    }
    final now = DateTime.now();
    final last = _lastAdvanceBeyondLastAt;
    if (last != null &&
        now.difference(last) < const Duration(milliseconds: 800)) {
      return false;
    }
    _lastAdvanceBeyondLastAt = now;
    return _scheduleChapterBoundaryRequest(widget.onAdvanceBeyondLast!);
  }

  bool _requestRetreatBeforeFirst() {
    if (_currentPage > 0 || widget.onRetreatBeforeFirst == null) {
      return false;
    }
    final now = DateTime.now();
    final last = _lastRetreatBeforeFirstAt;
    if (last != null &&
        now.difference(last) < const Duration(milliseconds: 800)) {
      return false;
    }
    _lastRetreatBeforeFirstAt = now;
    return _scheduleChapterBoundaryRequest(widget.onRetreatBeforeFirst!);
  }

  bool _handleScrollNotification(ScrollNotification notification) {
    if (notification is ScrollStartNotification && _pageTurnOrigin == null) {
      _pageTurnOrigin = _currentPage;
    } else if (notification is ScrollEndNotification &&
        _pageTurnOrigin != null) {
      setState(() => _pageTurnOrigin = null);
    }
    return false;
  }

  void _handlePagePointerDown(PointerDownEvent event) {
    _pagePointerDownLocal = event.localPosition;
    _pageTurnOrigin = _currentPage;
  }

  void _handlePagePointerCancel(PointerCancelEvent event) {
    _pagePointerDownLocal = null;
  }

  void _handlePagePointerUp(PointerUpEvent event) {
    final start = _pagePointerDownLocal;
    _pagePointerDownLocal = null;
    if (start == null) return;
    final delta = event.localPosition - start;
    final isForwardDrag =
        delta.dx < -kTouchSlop && delta.dx.abs() > delta.dy.abs();
    final isBackwardDrag =
        delta.dx > kTouchSlop && delta.dx.abs() > delta.dy.abs();

    if (isForwardDrag) {
      _requestAdvanceBeyondLast();
    } else if (isBackwardDrag) {
      _requestRetreatBeforeFirst();
    }
  }

  Widget _buildPage(int index, int pageCount) {
    final start = _pageOffsets[index];
    final end =
        index < pageCount - 1 ? _pageOffsets[index + 1] : widget.content.length;
    final pageText = widget.content.substring(start, end);

    return Padding(
      padding: EdgeInsets.fromLTRB(
        widget.margin,
        _effectiveTopPadding,
        widget.margin,
        _pageBottomPadding,
      ),
      child: index == 0 && _hasChapterTitle
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: _titleBottomSpacing),
                  child: Text(
                    widget.chapterTitle!,
                    style: _titleStyle,
                  ),
                ),
                _buildParagraphs(pageText, start),
              ],
            )
          : _buildParagraphs(pageText, start),
    );
  }

  Widget _buildParagraphs(String pageText, int pageStart) {
    final matches = RegExp(r'[^\n]+').allMatches(pageText).toList();
    final style = _bodyStyle;
    if (matches.isEmpty) {
      return SelectableText('', style: style);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < matches.length; i++)
          Builder(
            builder: (context) {
              final paragraphStart = pageStart + matches[i].start;
              final indentPrefix = paragraphIndentPrefix(
                indentCount: widget.paragraphIndent,
                startsParagraph: isLogicalParagraphStart(
                  widget.content,
                  paragraphStart,
                ),
              );
              return Padding(
                padding: EdgeInsets.only(
                  bottom: i == matches.length - 1 ? 0 : widget.paragraphSpacing,
                ),
                child: SelectableText.rich(
                  TextSpan(
                    children: [
                      if (indentPrefix.isNotEmpty) TextSpan(text: indentPrefix),
                      ..._locatorSpans(
                        matches[i].group(0)!,
                        paragraphStart,
                      ),
                    ],
                  ),
                  textAlign: widget.textAlign,
                  scrollPhysics: const NeverScrollableScrollPhysics(),
                  style: style,
                  contextMenuBuilder: (context, editableTextState) {
                    return AdaptiveTextSelectionToolbar.buttonItems(
                      anchors: editableTextState.contextMenuAnchors,
                      buttonItems: buildReaderContextMenuItems(
                        editableTextState: editableTextState,
                        leadingTextLength: indentPrefix.length,
                        onHighlight: (t, s, e) =>
                            widget.onHighlightAction?.call(
                          t,
                          paragraphStart + s,
                          paragraphStart + e,
                        ),
                        onNote: (t, s, e) => widget.onNoteAction?.call(
                          t,
                          paragraphStart + s,
                          paragraphStart + e,
                        ),
                        onReadAloud: widget.onTtsAction == null
                            ? null
                            : (t, s, e) => widget.onTtsAction!(
                                  t,
                                  paragraphStart + s,
                                  paragraphStart + e,
                                ),
                        onVocabulary: widget.onVocabularyAction == null
                            ? null
                            : (t, s, e) => widget.onVocabularyAction!(
                                  t,
                                  paragraphStart + s,
                                  paragraphStart + e,
                                ),
                        onTranslate: widget.onTranslateAction,
                        onAi: (t) => widget.onAiAction?.call(t),
                      ),
                    );
                  },
                ),
              );
            },
          ),
      ],
    );
  }

  List<InlineSpan> _locatorSpans(String text, int globalStart) {
    final locatorStart = widget.locatorHighlightStart;
    final locatorEnd = widget.locatorHighlightEnd;
    final activeIndex = _localActiveSentenceIndex ?? widget.activeSentenceIndex;
    final activeSentence = activeIndex != null &&
            activeIndex >= 0 &&
            activeIndex < _sentences.length
        ? _sentences[activeIndex]
        : null;
    final useLocator = locatorStart != null && locatorEnd != null;
    final highlightStart =
        useLocator ? locatorStart : activeSentence?.startOffset;
    final highlightEnd = useLocator ? locatorEnd : activeSentence?.endOffset;
    final globalEnd = globalStart + text.length;
    if (highlightStart == null ||
        highlightEnd == null ||
        highlightStart >= globalEnd ||
        highlightEnd <= globalStart) {
      return [TextSpan(text: text)];
    }

    final localStart =
        (highlightStart - globalStart).clamp(0, text.length).toInt();
    final localEnd =
        (highlightEnd - globalStart).clamp(localStart, text.length).toInt();
    return [
      if (localStart > 0) TextSpan(text: text.substring(0, localStart)),
      TextSpan(
        text: text.substring(localStart, localEnd),
        style: TextStyle(
          backgroundColor: Theme.of(context)
              .colorScheme
              .primary
              .withValues(alpha: useLocator ? 0.22 : 0.15),
        ),
      ),
      if (localEnd < text.length) TextSpan(text: text.substring(localEnd)),
    ];
  }

  Widget _wrapPageTurnEffect(int index, Widget child) {
    if (widget.pageTurnEffect == 'slide') {
      return AnimatedBuilder(
        animation: _pageController,
        child: child,
        builder: (context, child) {
          var page = _currentPage.toDouble();
          if (_pageController.hasClients && _pageController.page != null) {
            page = _pageController.page!;
          }
          final delta = (page - index).clamp(-1.0, 1.0).toDouble();
          final progress = (1.0 - delta.abs()).clamp(0.0, 1.0);

          return Transform.translate(
            offset: Offset(-delta * 24, 0),
            child: DecoratedBox(
              decoration: BoxDecoration(
                boxShadow: progress <= 0
                    ? null
                    : [
                        BoxShadow(
                          color:
                              Colors.black.withValues(alpha: 0.10 * progress),
                          blurRadius: 10,
                          offset: Offset(delta > 0 ? -4 : 4, 0),
                        ),
                      ],
              ),
              child: child!,
            ),
          );
        },
      );
    }

    if (widget.pageTurnEffect == 'plain') {
      return child;
    }

    if (widget.pageTurnEffect != 'curl') {
      return child;
    }

    return AnimatedBuilder(
      animation: _pageController,
      child: child,
      builder: (context, child) {
        var page = _currentPage.toDouble();
        if (_pageController.hasClients && _pageController.page != null) {
          page = _pageController.page!;
        }
        final origin = _pageTurnOrigin ?? _currentPage;
        if (index != origin) return child!;
        final delta = (page - origin).clamp(-1.0, 1.0).toDouble();
        final progress = delta.abs();
        if (progress <= 0.001) return child!;
        final easedProgress = Curves.easeInOutCubic.transform(progress);
        final direction = delta.sign;
        final angle = -direction * easedProgress * math.pi * 0.46;
        final transform = Matrix4.identity()
          ..setEntry(3, 2, 0.0018)
          ..rotateY(angle);

        // PageView 会平移整个 item。反向抵消这段平移，让纸张的
        // 书脊边留在原地，再围绕书脊做透视旋转，而不是整页滑走。
        return LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth.isFinite
                ? constraints.maxWidth
                : MediaQuery.sizeOf(context).width;
            return Transform.translate(
              offset: Offset(delta * width, 0),
              child: Transform(
                key: ValueKey('page_curl_transform-$index'),
                alignment: direction > 0
                    ? Alignment.centerLeft
                    : Alignment.centerRight,
                transform: transform,
                filterQuality: FilterQuality.medium,
                child: _PageCurlSurface(
                  progress: easedProgress,
                  direction: direction,
                  child: child!,
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final mediaSize = MediaQuery.sizeOf(context);
        final width = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : mediaSize.width;
        final height = constraints.maxHeight.isFinite
            ? constraints.maxHeight
            : mediaSize.height;
        final pageHeight = math.max(1.0, height - _pageIndicatorReserve);

        if (_needsPageCompute(width, pageHeight)) {
          _scheduleComputePages(width, pageHeight);
        }

        if (_pageOffsets.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }

        final pageCount = _pageOffsets.length;
        return Column(
          children: [
            SizedBox(
              height: pageHeight,
              child: Listener(
                behavior: HitTestBehavior.translucent,
                onPointerDown: _handlePagePointerDown,
                onPointerCancel: _handlePagePointerCancel,
                onPointerUp: _handlePagePointerUp,
                child: NotificationListener<ScrollNotification>(
                  onNotification: _handleScrollNotification,
                  child: PageView.builder(
                    controller: _pageController,
                    itemCount: pageCount,
                    scrollDirection: Axis.horizontal,
                    physics: const PageScrollPhysics(),
                    onPageChanged: (page) {
                      if (mounted) {
                        setState(() => _currentPage = page);
                      } else {
                        _currentPage = page;
                      }
                      widget.onPageChanged?.call(page);
                      widget.onPositionChanged?.call(_positionForPage(page));
                    },
                    itemBuilder: (context, index) {
                      return _wrapPageTurnEffect(
                        index,
                        _buildPage(index, pageCount),
                      );
                    },
                  ),
                ),
              ),
            ),
            SizedBox(
              height: _pageIndicatorReserve,
              child: Center(
                child: pageCount > 1
                    ? Text(
                        '${_currentPage + 1} / $pageCount',
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.4),
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _PageCurlSurface extends StatelessWidget {
  final double progress;
  final double direction;
  final Widget child;

  const _PageCurlSurface({
    required this.progress,
    required this.direction,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final active = progress > 0.001;

    // 页面本身不铺底色：纸张色和背景装饰由阅读器外层的 AppBackground 画，
    // 这里再铺一层不透明的 surface 就把它们全盖掉了。相邻两页在 PageView
    // 里是并排滑动、不重叠的，透明也不会串页。
    return Stack(
      fit: StackFit.expand,
      children: [
        RepaintBoundary(child: child),
        if (active)
          IgnorePointer(
            child: CustomPaint(
              key: const ValueKey('page_curl_overlay'),
              painter: _PageCurlPainter(
                progress: progress,
                direction: direction,
                surface: colorScheme.surface,
                shadow: colorScheme.shadow,
                highlight: colorScheme.onSurface,
              ),
            ),
          ),
      ],
    );
  }
}

class _PageCurlPainter extends CustomPainter {
  final double progress;
  final double direction;
  final Color surface;
  final Color shadow;
  final Color highlight;

  const _PageCurlPainter({
    required this.progress,
    required this.direction,
    required this.surface,
    required this.shadow,
    required this.highlight,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final p = progress.clamp(0.0, 1.0);
    if (p <= 0) return;

    final rightEdge = direction >= 0;
    final foldWidth = math.max(18.0, size.width * (0.08 + 0.18 * p));
    final edgeX = rightEdge ? size.width : 0.0;
    final innerX = rightEdge ? size.width - foldWidth : foldWidth;
    final foldRect = Rect.fromLTRB(
      rightEdge ? innerX : 0,
      0,
      rightEdge ? size.width : innerX,
      size.height,
    );

    final castShadowRect = Rect.fromLTRB(
      rightEdge ? innerX - foldWidth * 0.34 : innerX - foldWidth * 0.06,
      0,
      rightEdge ? innerX + foldWidth * 0.18 : innerX + foldWidth * 0.34,
      size.height,
    );
    canvas.drawRect(
      castShadowRect,
      Paint()
        ..shader = LinearGradient(
          begin: rightEdge ? Alignment.centerRight : Alignment.centerLeft,
          end: rightEdge ? Alignment.centerLeft : Alignment.centerRight,
          colors: [
            shadow.withValues(alpha: 0.18 * p),
            shadow.withValues(alpha: 0.07 * p),
            Colors.transparent,
          ],
          stops: const [0, 0.48, 1],
        ).createShader(castShadowRect),
    );

    final foldPath = Path();
    if (rightEdge) {
      foldPath
        ..moveTo(edgeX, 0)
        ..cubicTo(
          edgeX - foldWidth * 0.24,
          size.height * 0.22,
          edgeX - foldWidth * 0.10,
          size.height * 0.64,
          innerX,
          size.height,
        )
        ..lineTo(edgeX, size.height)
        ..close();
    } else {
      foldPath
        ..moveTo(edgeX, 0)
        ..cubicTo(
          edgeX + foldWidth * 0.24,
          size.height * 0.22,
          edgeX + foldWidth * 0.10,
          size.height * 0.64,
          innerX,
          size.height,
        )
        ..lineTo(edgeX, size.height)
        ..close();
    }

    canvas.drawPath(
      foldPath,
      Paint()
        ..shader = LinearGradient(
          begin: rightEdge ? Alignment.centerRight : Alignment.centerLeft,
          end: rightEdge ? Alignment.centerLeft : Alignment.centerRight,
          colors: [
            Colors.white.withValues(alpha: 0.18 * p),
            surface.withValues(alpha: 0.10),
            shadow.withValues(alpha: 0.10 * p),
          ],
          stops: const [0, 0.58, 1],
        ).createShader(foldRect),
    );

    final ridgePath = Path();
    if (rightEdge) {
      ridgePath
        ..moveTo(innerX, 0)
        ..cubicTo(
          innerX + foldWidth * 0.34,
          size.height * 0.26,
          innerX + foldWidth * 0.04,
          size.height * 0.68,
          innerX,
          size.height,
        );
    } else {
      ridgePath
        ..moveTo(innerX, 0)
        ..cubicTo(
          innerX - foldWidth * 0.34,
          size.height * 0.26,
          innerX - foldWidth * 0.04,
          size.height * 0.68,
          innerX,
          size.height,
        );
    }
    canvas.drawPath(
      ridgePath,
      Paint()
        ..color = highlight.withValues(alpha: 0.16 * p)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );

    final edgeRect = Rect.fromLTRB(
      rightEdge ? size.width - 8 : 0,
      0,
      rightEdge ? size.width : 8,
      size.height,
    );
    canvas.drawRect(
      edgeRect,
      Paint()
        ..shader = LinearGradient(
          begin: rightEdge ? Alignment.centerRight : Alignment.centerLeft,
          end: rightEdge ? Alignment.centerLeft : Alignment.centerRight,
          colors: [
            shadow.withValues(alpha: 0.22 * p),
            Colors.transparent,
          ],
        ).createShader(edgeRect),
    );
  }

  @override
  bool shouldRepaint(covariant _PageCurlPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.direction != direction ||
        oldDelegate.surface != surface ||
        oldDelegate.shadow != shadow ||
        oldDelegate.highlight != highlight;
  }
}
