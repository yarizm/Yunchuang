import 'dart:async';
import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../database/app_database.dart';
import '../../database/daos/progress_dao.dart';
import '../../models/html_text_document.dart';
import '../../models/reader_locator.dart';
import '../../providers/ai/agent_models.dart';
import '../../providers/ai/spoiler_protection_provider.dart';
import '../../providers/book_reading_settings_provider.dart';
import '../../providers/database_provider.dart';
import '../../providers/note_provider.dart';
import '../../providers/preferences_provider.dart';
import '../../providers/translation_provider.dart';
import '../../utils/sentence_splitter.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/glass_container.dart';
import '../../providers/ui_provider.dart';
import '../../services/tts_media_session.dart';
import '../../services/tts_playback_checkpoint_store.dart';
import '../../services/tts_service.dart';
import '../../services/translation_service.dart';
import '../../services/vocabulary_service.dart';
import '../../theme/glass_page_route.dart';
import '../../theme/reader_theme.dart';
import 'immersive_reader_shell.dart';
import 'reader_toolbar.dart';
import 'quick_settings_panel.dart';
import 'format_reader.dart';
import '../settings/translation_settings_page.dart';
import '../../widgets/tts_mini_player.dart';
import '../../widgets/translation_sheet.dart';
import '../../widgets/vocabulary_lookup_sheet.dart';
import '../../utils/local_date.dart';
import '../../parsers/epub_parser.dart';
import 'epub_reader.dart';
import 'paged_reader.dart';
import 'pdf_reader.dart';
import 'reader_controller.dart';
import 'reader_data_loader.dart';
import 'reader_navigation_history.dart';
import 'reader_overlays.dart';
import 'reader_toc_sheet.dart';
import 'txt_reader.dart';

class ReaderPage extends ConsumerStatefulWidget {
  final int bookId;
  final int? targetChapterId;
  final String? targetQuery;
  final ReaderLocator? initialLocator;

  const ReaderPage({
    super.key,
    required this.bookId,
    this.targetChapterId,
    this.targetQuery,
    this.initialLocator,
  });

  @override
  ConsumerState<ReaderPage> createState() => _ReaderPageState();
}

class _ReaderPageState extends ConsumerState<ReaderPage>
    with WidgetsBindingObserver {
  Book? _book;
  List<Chapter> _chapters = [];
  List<String> _chapterContents = [];
  bool _loading = true;
  String? _error;
  bool _isBookmarked = false;
  final Set<int> _loadedPdfTextPages = {};
  int _lastTrackedChapterIndex = -1;
  int _positionRestoreRequest = 0;
  bool _restoringScrollPosition = false;
  bool _exitInProgress = false;
  bool _allowPop = false;
  int _chapterTransitionDirection = 1;
  final GlobalKey _nextChapterButtonKey = GlobalKey();

  final GlobalKey<PdfReaderState> _pdfReaderKey = GlobalKey();
  final Map<int, ScrollController> _scrollControllers = {};
  Timer? _scrollDebounce;
  int _todaySecondsBuffer = 0;
  Timer? _todaySecondsFlush;
  Timer? _locatorHighlightTimer;
  int? _locatorHighlightStart;
  int? _locatorHighlightEnd;
  final ReaderNavigationHistory _navigationHistory = ReaderNavigationHistory();
  bool _ttsChapterTransitionInProgress = false;
  int _ttsChapterTransitionRevision = 0;
  Future<void>? _bookTtsSettingsLoad;
  TTSSleepTimerOption _bookSleepTimerOption = TTSSleepTimerOption.off;
  Timer? _ttsCheckpointTimer;
  bool _ttsCheckpointPromptShown = false;
  Future<List<String?>>? _epubChapterFileNames;
  late final ReaderController _readerController;
  late final ProgressDao _progressDao;
  late final TtsMediaSession? _ttsMediaSession;
  late final TtsPlaybackCheckpointStore _ttsCheckpointStore;
  late final TTSService _ttsService;
  late final StateController<bool> _backgroundAnimationController;

  ReaderController get _controller => _readerController;

  ReaderLocator? get _initialLocator {
    if (widget.initialLocator != null) return widget.initialLocator;
    if (widget.targetChapterId == null && widget.targetQuery == null) {
      return null;
    }
    return ReaderLocator(
      bookId: widget.bookId,
      chapterId: widget.targetChapterId,
      chapterPosition: widget.targetQuery == null ? 0 : null,
      query: widget.targetQuery,
    );
  }

  @override
  void initState() {
    super.initState();
    _readerController = ref.read(readerControllerProvider(widget.bookId));
    _progressDao = ref.read(progressDaoProvider);
    _ttsService = ref.read(ttsServiceProvider);
    _ttsCheckpointStore = ref.read(ttsPlaybackCheckpointStoreProvider);
    _ttsService.addListener(_handleTtsCheckpointStateChanged);
    _ttsMediaSession = ref.read(ttsMediaSessionProvider)
      ?..attach(
        tts: _ttsService,
        onPreviousChapter: _playPreviousTtsChapter,
        onNextChapter: _playNextTtsChapter,
      );
    _backgroundAnimationController =
        ref.read(backgroundAnimationEnabledProvider.notifier);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(backgroundAnimationEnabledProvider.notifier).state = false;
      }
    });
    WidgetsBinding.instance.addObserver(this);
    _controller.startReadingTimer();
    if (ref.read(preferencesProvider).keepScreenOn) {
      WakelockPlus.enable();
    }
    _controller.onTick = (_) {
      _todaySecondsBuffer += 1;
      // 这里原本每个 tick 都 cancel 再重建定时器，等于 debounce：连续阅读时
      // tick 每秒一次，定时器永远等不到 5 秒空档，缓冲会一直攒到退出阅读页
      // 才落盘，中途被系统杀掉整段时长就没了。改成"没有待触发的定时器才排
      // 一个"，连续阅读时每 30 秒真正写一次。
      _todaySecondsFlush ??= Timer(const Duration(seconds: 30), () {
        _todaySecondsFlush = null;
        _flushReadingSeconds();
      });
    };
    _loadData();
  }

  Future<void> _loadData() async {
    final initialLocator = _initialLocator;
    final timeline = developer.TimelineTask()
      ..start('book_open', arguments: {'book_id': widget.bookId});
    final stopwatch = Stopwatch()..start();
    try {
      timeline.instant('book_open_start');
      final dataLoader = ref.read(readerDataLoaderProvider);
      final bookReadingSettingsReady =
          ref.read(bookReadingSettingsProvider(widget.bookId).future);
      final readerData = await dataLoader.loadBook(
        widget.bookId,
        targetChapterId: initialLocator?.chapterId ?? widget.targetChapterId,
      );

      if (readerData == null) {
        timeline.finish(arguments: {
          'error': 'book_not_found',
          'elapsed_ms': stopwatch.elapsedMilliseconds,
        });
        if (mounted) {
          setState(() {
            _error = '书籍不存在';
            _loading = false;
          });
        }
        return;
      }
      await bookReadingSettingsReady;

      timeline.instant('chapter_decode');

      if (mounted) {
        setState(() {
          _book = readerData.book;
          _chapters = readerData.chapters;
          _chapterContents = readerData.chapterContents;
          _loading = false;
        });
        _controller.chapterCount = _chapters.length;
        _bookTtsSettingsLoad = _loadBookTtsSettings();
        _controller.setCurrentChapterIndex(readerData.initialChapterIndex);
        if (_chapters.isNotEmpty) {
          _controller.setCurrentChapterId(
              _chapters[readerData.initialChapterIndex].id);
          _syncTtsMediaSessionChapter();
        }
        unawaited(_refreshBookmarkState());

        if (readerData.savedProgress != null && initialLocator == null) {
          _controller
              .setScrollPosition(readerData.savedProgress!.positionInChapter);
        }
        if (readerData.savedProgress != null) {
          _controller.setTotalReadingSeconds(
              readerData.savedProgress!.totalReadingSeconds);
          final savedChapterId = readerData.savedProgress!.chapterId;
          if (initialLocator != null &&
              initialLocator.bookId == widget.bookId &&
              savedChapterId != null) {
            _navigationHistory.seedBackLocation(
              ReaderLocator(
                bookId: widget.bookId,
                chapterId: savedChapterId,
                format: readerData.book.format,
                chapterPosition: readerData.savedProgress!.positionInChapter,
              ),
            );
          }
        }
        unawaited(_preloadAdjacentChapters(readerData.initialChapterIndex));
        timeline.instant('page_render');
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (readerData.savedProgress != null && initialLocator == null) {
            unawaited(
              _restoreChapterPosition(
                readerData.initialChapterIndex,
                readerData.savedProgress!.positionInChapter,
              ),
            );
          }
          timeline
            ..instant('first_readable_frame', arguments: {
              'elapsed_ms': stopwatch.elapsedMilliseconds,
            })
            ..finish(arguments: {
              'elapsed_ms': stopwatch.elapsedMilliseconds,
            });
          developer.log(
            'book_open first_readable_frame=${stopwatch.elapsedMilliseconds}ms '
            'book=${widget.bookId} format=${readerData.book.format}',
            name: 'reader.performance',
          );
          if (initialLocator != null) {
            unawaited(_applyLocator(initialLocator));
          } else {
            unawaited(_offerTtsResumeCheckpoint());
          }
        });
      } else {
        timeline.finish(arguments: {'cancelled': true});
      }
    } catch (e) {
      timeline.finish(arguments: {
        'error': e.runtimeType.toString(),
        'elapsed_ms': stopwatch.elapsedMilliseconds,
      });
      if (mounted) {
        setState(() {
          _error = '加载失败: $e';
          _loading = false;
        });
      }
    }
  }

  Future<void> _preloadAdjacentChapters(int centerIndex) async {
    if (_book == null) return;

    // We already have contents loaded for the initial index from loadBook.
    // Use dataLoader to handle prefetching the rest.
    final dataLoader = ref.read(readerDataLoaderProvider);
    if (_book!.format == 'pdf') {
      final loaded = await dataLoader.loadPdfPageTexts(
          _book!, _chapters, [centerIndex - 1, centerIndex, centerIndex + 1],
          ignoreIndexes: _loadedPdfTextPages);
      if (loaded.isEmpty) return;
      for (final entry in loaded.entries) {
        _chapterContents[entry.key] = entry.value;
        _loadedPdfTextPages.add(entry.key);
      }
      if (mounted) setState(() {});
      return;
    }

    final indexes = [centerIndex - 1, centerIndex, centerIndex + 1]
        .where((index) => index >= 0 && index < _chapters.length);
    var changed = false;
    final dao = ref.read(bookDaoProvider);
    for (final index in indexes) {
      if (_chapterContents[index].isNotEmpty) continue;
      final cached = await dao.getChapterContent(_chapters[index].id);
      if (cached != null) {
        _chapterContents[index] = cached;
        changed = true;
      }
    }
    if (changed && mounted) setState(() {});
  }

  void _trimChapterMemory(int centerIndex) {
    if (_book?.format == 'pdf') return;
    for (var index = 0; index < _chapterContents.length; index++) {
      if ((index - centerIndex).abs() > 1) {
        _chapterContents[index] = '';
      }
    }
  }

  Future<void> _saveProgress() async {
    if (_chapters.isEmpty) return;
    final chapter = _chapters[_controller.currentChapterIndex];
    final percentage = _controller.bookProgress;

    await ref.read(progressDaoProvider).saveProgress(
          bookId: widget.bookId,
          chapterId: chapter.id,
          positionInChapter: _controller.scrollPosition,
          percentage: percentage,
          totalReadingSeconds: _controller.totalReadingSeconds,
        );
  }

  Future<void> _restoreChapterPosition(
    int chapterIndex,
    double position,
  ) async {
    if (!mounted ||
        _book?.format == 'pdf' ||
        _controller.readingMode == ReadingMode.page) {
      return;
    }

    final request = ++_positionRestoreRequest;
    _restoringScrollPosition = true;
    _controller.setScrollPosition(position);
    final scrollController = _getScrollController(chapterIndex);
    var previousMaxExtent = -1.0;
    var stableFrames = 0;

    try {
      // ListView.builder only knows an estimated extent on its first frame.
      // Re-apply the saved ratio until lazy layout has converged.
      for (var attempt = 0; attempt < 16; attempt++) {
        await WidgetsBinding.instance.endOfFrame;
        if (!mounted ||
            request != _positionRestoreRequest ||
            chapterIndex != _controller.currentChapterIndex) {
          return;
        }
        if (!scrollController.hasClients ||
            !scrollController.position.hasContentDimensions) {
          continue;
        }

        final maxExtent = scrollController.position.maxScrollExtent;
        if (maxExtent <= 0) {
          continue;
        }
        final target =
            (maxExtent * position.clamp(0.0, 1.0)).clamp(0.0, maxExtent);
        if ((scrollController.offset - target).abs() >= 1) {
          scrollController.jumpTo(target);
        }

        await WidgetsBinding.instance.endOfFrame;
        if (!mounted ||
            request != _positionRestoreRequest ||
            !scrollController.hasClients) {
          return;
        }

        final updatedMaxExtent = scrollController.position.maxScrollExtent;
        final currentRatio = updatedMaxExtent > 0
            ? scrollController.offset / updatedMaxExtent
            : 0.0;
        final extentStable = (updatedMaxExtent - previousMaxExtent).abs() < 1.0;
        final positionReached = (currentRatio - position).abs() < 0.005;
        stableFrames = extentStable && positionReached ? stableFrames + 1 : 0;
        previousMaxExtent = updatedMaxExtent;
        if (stableFrames >= 2) {
          break;
        }
      }
    } finally {
      if (request == _positionRestoreRequest) {
        _restoringScrollPosition = false;
        if (mounted && scrollController.hasClients) {
          final maxExtent = scrollController.position.maxScrollExtent;
          final actualPosition =
              maxExtent > 0 ? scrollController.offset / maxExtent : position;
          _controller.setScrollPosition(actualPosition);
        }
      }
    }
  }

  void _cancelPositionRestore() {
    _positionRestoreRequest++;
    _restoringScrollPosition = false;
  }

  void _goToPrevious() {
    if (_controller.currentChapterIndex > 0) {
      _stopTtsForManualChapterNavigation();
      _cancelPositionRestore();
      unawaited(_saveProgress());
      _chapterTransitionDirection = -1;
      _controller.setCurrentChapterIndex(_controller.currentChapterIndex - 1);
      _trimChapterMemory(_controller.currentChapterIndex);
      unawaited(_preloadAdjacentChapters(_controller.currentChapterIndex));
      _controller
          .setCurrentChapterId(_chapters[_controller.currentChapterIndex].id);
      unawaited(_refreshBookmarkState());
      if (_book?.format == 'pdf') {
        unawaited(
          _loadPdfPageContent(_controller.currentChapterIndex),
        );
        _pdfReaderKey.currentState?.goToPage(_controller.currentChapterIndex);
      }
    }
  }

  void _goToPreviousAtEnd() {
    if (_controller.currentChapterIndex > 0) {
      _stopTtsForManualChapterNavigation();
      _cancelPositionRestore();
      unawaited(_saveProgress());
      _chapterTransitionDirection = -1;
      _controller
          .setCurrentChapterIndexAtEnd(_controller.currentChapterIndex - 1);
      _trimChapterMemory(_controller.currentChapterIndex);
      unawaited(_preloadAdjacentChapters(_controller.currentChapterIndex));
      _controller
          .setCurrentChapterId(_chapters[_controller.currentChapterIndex].id);
      unawaited(_refreshBookmarkState());
    }
  }

  void _goToNext() {
    if (_controller.currentChapterIndex < _chapters.length - 1) {
      _stopTtsForManualChapterNavigation();
      _cancelPositionRestore();
      unawaited(_saveProgress());
      _chapterTransitionDirection = 1;
      _controller.setCurrentChapterIndex(_controller.currentChapterIndex + 1);
      _trimChapterMemory(_controller.currentChapterIndex);
      unawaited(_preloadAdjacentChapters(_controller.currentChapterIndex));
      _controller
          .setCurrentChapterId(_chapters[_controller.currentChapterIndex].id);
      unawaited(_refreshBookmarkState());
      if (_book?.format == 'pdf') {
        unawaited(
          _loadPdfPageContent(_controller.currentChapterIndex),
        );
        _pdfReaderKey.currentState?.goToPage(_controller.currentChapterIndex);
      }
    }
  }

  Future<void> _loadPdfPageContent(int chapterIndex) async {
    final book = _book;
    if (book == null ||
        book.format != 'pdf' ||
        chapterIndex < 0 ||
        chapterIndex >= _chapters.length ||
        _loadedPdfTextPages.contains(chapterIndex)) {
      return;
    }
    final loaded = await ref.read(readerDataLoaderProvider).loadPdfPageTexts(
        book, _chapters, [chapterIndex - 1, chapterIndex, chapterIndex + 1],
        ignoreIndexes: _loadedPdfTextPages);
    if (loaded.isEmpty) return;
    if (!mounted) return;
    setState(() {
      for (final entry in loaded.entries) {
        _chapterContents[entry.key] = entry.value;
        _loadedPdfTextPages.add(entry.key);
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scrollDebounce?.cancel();
    _locatorHighlightTimer?.cancel();
    _ttsCheckpointTimer?.cancel();
    _controller.pauseReadingTimer();
    WakelockPlus.disable();
    _todaySecondsFlush?.cancel();
    _todaySecondsFlush = null;
    _flushReadingSeconds();
    unawaited(_controller.flushProgress(_progressDao));
    for (final sc in _scrollControllers.values) {
      sc.dispose();
    }
    _ttsService.removeListener(_handleTtsCheckpointStateChanged);
    _ttsMediaSession?.detach(_ttsService);
    _ttsService.onSentenceChanged = null;
    _ttsService.onContentCompleted = null;
    unawaited(_ttsService.stop());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _backgroundAnimationController.state = true;
    });
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _controller.pauseReadingTimer();
      // 退到后台后进程随时可能被系统回收，缓冲里的秒数必须立刻落盘。
      _todaySecondsFlush?.cancel();
      _todaySecondsFlush = null;
      _flushReadingSeconds();
      if (_ttsService.isPlaying || _ttsService.isPaused) {
        _ttsCheckpointTimer?.cancel();
        unawaited(_saveTtsPlaybackCheckpoint());
      }
      unawaited(_saveProgress());
    } else if (state == AppLifecycleState.resumed) {
      _controller.startReadingTimer();
    }
  }

  /// 把缓冲的阅读秒数落盘到 `reading_sessions`。
  ///
  /// 跨零点时最多有 30 秒被算进后一天，可以接受。
  void _flushReadingSeconds() {
    final pending = _todaySecondsBuffer;
    if (pending <= 0) return;
    _todaySecondsBuffer = 0;
    unawaited(_progressDao.addSessionSeconds(
      bookId: widget.bookId,
      date: localDateString(),
      seconds: pending,
    ));
  }

  void _onScrollUpdate(double position) {
    if (_restoringScrollPosition) {
      return;
    }
    _controller.setScrollPosition(position);
    _scheduleProgressSave(const Duration(milliseconds: 750));
  }

  void _onPagePositionChanged(double position) {
    _controller.setScrollPosition(position);
    _scheduleProgressSave(const Duration(milliseconds: 200));
  }

  void _scheduleProgressSave(Duration delay) {
    _scrollDebounce?.cancel();
    _scrollDebounce = Timer(
      delay,
      () {
        _scrollDebounce = null;
        unawaited(_saveProgress());
      },
    );
  }

  Future<void> _applyLocator(
    ReaderLocator locator, {
    bool recordHistory = false,
  }) async {
    if (locator.bookId != widget.bookId || _chapters.isEmpty) return;

    var chapterIndex = locator.chapterId == null
        ? _controller.currentChapterIndex
        : _chapters.indexWhere((chapter) => chapter.id == locator.chapterId);
    if (_book?.format == 'pdf' && locator.pageNumber != null) {
      chapterIndex = locator.pageNumber!.clamp(0, _chapters.length - 1).toInt();
    }
    if (chapterIndex < 0 || chapterIndex >= _chapters.length) return;

    if (_book?.format == 'pdf') {
      if (recordHistory) {
        _recordNavigationJump(
          ReaderLocator(
            bookId: widget.bookId,
            chapterId: _chapters[chapterIndex].id,
            format: 'pdf',
            pageNumber: chapterIndex,
            chapterPosition: locator.chapterPosition,
          ),
        );
      }
      _clearLocatorHighlight();
      _goToChapter(chapterIndex, position: locator.chapterPosition);
      return;
    }

    var content = _chapterContents[chapterIndex];
    if (content.isEmpty) {
      content = await ref
              .read(bookDaoProvider)
              .getChapterContent(_chapters[chapterIndex].id) ??
          '';
      if (!mounted) return;
      if (content.isNotEmpty) {
        _chapterContents[chapterIndex] = content;
      }
    }

    final resolution = locator.resolveIn(_readableText(content));
    final targetPosition =
        resolution?.position ?? locator.chapterPosition ?? 0.0;
    if (recordHistory) {
      _recordNavigationJump(
        ReaderLocator(
          bookId: widget.bookId,
          chapterId: _chapters[chapterIndex].id,
          format: _book?.format,
          textOffsetStart: resolution?.textOffsetStart,
          textOffsetEnd: resolution?.textOffsetEnd,
          chapterPosition: targetPosition,
          query: locator.query,
          selectedText: locator.selectedText,
          contextBefore: locator.contextBefore,
          contextAfter: locator.contextAfter,
          contextHash: locator.contextHash,
        ),
      );
    }
    _goToChapter(chapterIndex, position: targetPosition);
    if (!mounted) return;

    _locatorHighlightTimer?.cancel();
    setState(() {
      _locatorHighlightStart = resolution?.textOffsetStart;
      _locatorHighlightEnd = resolution?.textOffsetEnd;
    });
    if (_locatorHighlightStart != null && _locatorHighlightEnd != null) {
      _locatorHighlightTimer = Timer(const Duration(seconds: 3), () {
        if (mounted) _clearLocatorHighlight();
      });
    }
    _scheduleProgressSave(const Duration(milliseconds: 200));
  }

  Future<void> _handleEpubLink(HtmlTextLink link) async {
    if (_book?.format != 'epub' || _chapters.isEmpty) return;
    final sourceIndex = _controller.currentChapterIndex;
    EpubLinkTarget? target;
    final href = link.href.trim();

    try {
      final uri = Uri.parse(href);
      if (uri.hasScheme || href.startsWith('//')) {
        _showReaderMessage('离线阅读模式暂不打开外部链接。');
        return;
      }
      if (uri.path.isEmpty) {
        target = EpubLinkTarget(
          chapterIndex: sourceIndex,
          anchor:
              uri.fragment.isEmpty ? null : Uri.decodeComponent(uri.fragment),
        );
      } else {
        _epubChapterFileNames ??=
            EpubParser.readChapterFileNames(_book!.filePath);
        final chapterFileNames = await _epubChapterFileNames!;
        if (!mounted) return;
        target = EpubParser.resolveChapterHref(
          chapterFileNames,
          sourceIndex,
          href,
        );
      }
    } on FormatException {
      target = null;
    } catch (error, stackTrace) {
      developer.log(
        'Failed to resolve EPUB link',
        name: 'reader.epub_link',
        error: error,
        stackTrace: stackTrace,
      );
      if (mounted) _showReaderMessage('无法读取这个 EPUB 链接。');
      return;
    }

    if (target == null ||
        target.chapterIndex < 0 ||
        target.chapterIndex >= _chapters.length) {
      _showReaderMessage('无法定位这个 EPUB 链接。');
      return;
    }

    final targetHtml = await _loadChapterContentForLink(target.chapterIndex);
    if (!mounted) return;
    final anchorTarget = target.anchor == null
        ? null
        : extractHtmlAnchorTarget(targetHtml, target.anchor!);
    if (target.anchor != null && anchorTarget == null) {
      _showReaderMessage('链接指向的正文位置不存在。');
      return;
    }

    if (link.isFootnote) {
      if (anchorTarget == null) {
        _showReaderMessage('无法解析这条脚注。');
        return;
      }
      final openInText = await ReaderOverlays.showEpubFootnote(
        context,
        text: anchorTarget.text,
        label: link.label.isEmpty ? null : '脚注 ${link.label}',
      );
      if (!mounted || !openInText) return;
    }

    final readableText = EpubParser.stripHtml(targetHtml);
    final start = anchorTarget?.offset.clamp(0, readableText.length).toInt();
    final end = start == null
        ? null
        : (start + anchorTarget!.text.length)
            .clamp(start, readableText.length)
            .toInt();
    final anchorJson = start == null || end == null
        ? const <String, dynamic>{}
        : ReaderLocator.textAnchorJson(readableText, start, end);

    await _applyLocator(
      ReaderLocator(
        bookId: widget.bookId,
        chapterId: _chapters[target.chapterIndex].id,
        format: 'epub',
        textOffsetStart: start,
        textOffsetEnd: end,
        chapterPosition: start == null ? 0 : null,
        query: anchorTarget?.text,
        selectedText: anchorJson['selectedText'] as String?,
        contextBefore: anchorJson['contextBefore'] as String?,
        contextAfter: anchorJson['contextAfter'] as String?,
        contextHash: anchorJson['contextHash'] as String?,
      ),
      recordHistory: true,
    );
  }

  Future<String> _loadChapterContentForLink(int chapterIndex) async {
    var content = _chapterContents[chapterIndex];
    if (content.isNotEmpty) return content;
    content = await ref
            .read(bookDaoProvider)
            .getChapterContent(_chapters[chapterIndex].id) ??
        '';
    if (mounted && content.isNotEmpty) {
      _chapterContents[chapterIndex] = content;
    }
    return content;
  }

  void _showReaderMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _clearLocatorHighlight() {
    _locatorHighlightTimer?.cancel();
    _locatorHighlightTimer = null;
    if (_locatorHighlightStart == null && _locatorHighlightEnd == null) return;
    if (mounted) {
      setState(() {
        _locatorHighlightStart = null;
        _locatorHighlightEnd = null;
      });
    } else {
      _locatorHighlightStart = null;
      _locatorHighlightEnd = null;
    }
  }

  ReaderLocator _currentNavigationLocation() {
    final chapterIndex =
        _controller.currentChapterIndex.clamp(0, _chapters.length - 1);
    return ReaderLocator(
      bookId: widget.bookId,
      chapterId: _chapters[chapterIndex].id,
      format: _book?.format,
      pageNumber: _book?.format == 'pdf' ? chapterIndex : null,
      chapterPosition: _controller.scrollPosition,
    );
  }

  void _recordNavigationJump(ReaderLocator target) {
    final changed = _navigationHistory.recordJump(
      current: _currentNavigationLocation(),
      target: target,
    );
    if (changed && mounted) setState(() {});
  }

  void _goBackInHistory() {
    final target = _navigationHistory.goBack(_currentNavigationLocation());
    if (target == null) return;
    setState(() {});
    unawaited(_applyLocator(target));
  }

  void _goForwardInHistory() {
    final target = _navigationHistory.goForward(_currentNavigationLocation());
    if (target == null) return;
    setState(() {});
    unawaited(_applyLocator(target));
  }

  Future<void> _exitReader() async {
    if (_exitInProgress) return;
    _exitInProgress = true;
    _scrollDebounce?.cancel();
    try {
      await _saveProgress();
      await _ttsCheckpointStore.clearForBook(widget.bookId);
    } catch (error, stackTrace) {
      developer.log(
        'Failed to save reading progress before exit',
        name: 'reader.progress',
        error: error,
        stackTrace: stackTrace,
      );
    }
    if (!mounted) return;
    setState(() => _allowPop = true);
    await WidgetsBinding.instance.endOfFrame;
    if (mounted) {
      Navigator.of(context, rootNavigator: true).pop();
    }
  }

  void _showTtsPanel(String content) {
    ReaderOverlays.showTtsPanel(
      context,
      content,
      chapterListenable: _controller,
      currentChapterIndex: () => _controller.currentChapterIndex,
      chapterCount: _chapters.length,
      onPreviousChapter: _playPreviousTtsChapter,
      onNextChapter: _playNextTtsChapter,
      onBeforePlay: _prepareTtsForPlayback,
      onSpeechRateChanged: _updateBookTtsSpeechRate,
      onLanguageChanged: _updateBookTtsLanguage,
      onVoiceChanged: _updateBookTtsVoice,
      onSleepTimerChanged: _updateBookTtsSleepTimer,
      onResetBookSettings: _resetBookTtsSettings,
    );
  }

  void _handleTtsCheckpointStateChanged() {
    if (_ttsService.currentText.isEmpty || _chapters.isEmpty) return;
    if (_ttsService.isPlaying) {
      _ttsCheckpointTimer ??= Timer(const Duration(seconds: 5), () {
        _ttsCheckpointTimer = null;
        unawaited(_saveTtsPlaybackCheckpoint());
      });
      return;
    }

    _ttsCheckpointTimer?.cancel();
    _ttsCheckpointTimer = null;
    if (_ttsService.isPaused || _ttsService.status == TTSStatus.error) {
      unawaited(_saveTtsPlaybackCheckpoint());
      return;
    }
    if (_ttsService.status == TTSStatus.ready &&
        (_ttsService.progress <= 0 || _ttsService.progress >= 1)) {
      unawaited(_ttsCheckpointStore.clearForBook(widget.bookId));
    }
  }

  Future<void> _saveTtsPlaybackCheckpoint() async {
    final chapterIndex = _controller.currentChapterIndex;
    final text = _ttsService.currentText;
    if (chapterIndex < 0 ||
        chapterIndex >= _chapters.length ||
        text.isEmpty ||
        _ttsService.progress >= 1) {
      return;
    }
    await _ttsCheckpointStore.save(
      TtsPlaybackCheckpoint(
        bookId: widget.bookId,
        chapterId: _chapters[chapterIndex].id,
        characterOffset: _ttsService.currentOffset,
        updatedAt: DateTime.now().toUtc(),
      ),
    );
  }

  Future<void> _offerTtsResumeCheckpoint() async {
    if (_ttsCheckpointPromptShown ||
        _ttsService.isPlaying ||
        _ttsService.isPaused) {
      return;
    }
    final checkpoint = await _ttsCheckpointStore.load();
    if (!mounted ||
        checkpoint == null ||
        checkpoint.bookId != widget.bookId ||
        _ttsService.isPlaying ||
        _ttsService.isPaused) {
      return;
    }
    _ttsCheckpointPromptShown = true;

    final chapterIndex = _chapters.indexWhere(
      (chapter) => chapter.id == checkpoint.chapterId,
    );
    if (chapterIndex < 0) {
      await _ttsCheckpointStore.clear();
      return;
    }

    var content = _chapterContents[chapterIndex];
    if (content.isEmpty && _book?.format == 'pdf') {
      await _loadPdfPageContent(chapterIndex);
      if (!mounted) return;
      content = _chapterContents[chapterIndex];
    } else if (content.isEmpty) {
      content = await ref
              .read(bookDaoProvider)
              .getChapterContent(checkpoint.chapterId) ??
          '';
      if (!mounted) return;
      if (content.isNotEmpty) {
        _chapterContents[chapterIndex] = content;
      }
    }
    final readableContent = _readableText(content);
    if (readableContent.isEmpty ||
        checkpoint.characterOffset >= readableContent.length) {
      await _ttsCheckpointStore.clear();
      return;
    }
    if (_ttsService.isPlaying || _ttsService.isPaused) return;

    final percent =
        ((checkpoint.characterOffset / readableContent.length) * 100)
            .round()
            .clamp(0, 99);
    final shouldResume = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('继续上次朗读？'),
        content: Text(
          '上次朗读停在「${_chapters[chapterIndex].title}」约 $percent% 处。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('不继续'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            icon: const Icon(Icons.play_arrow_rounded),
            label: const Text('继续朗读'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    if (shouldResume != true) {
      await _ttsCheckpointStore.clear();
      return;
    }
    await _playTtsChapter(
      chapterIndex,
      startOffset: checkpoint.characterOffset,
    );
  }

  Future<void> _loadBookTtsSettings() async {
    try {
      final settings =
          await ref.read(bookTtsSettingsDaoProvider).getForBook(widget.bookId);
      if (!mounted) return;
      if (settings == null) {
        final globalRate = ref
            .read(sharedPreferencesProvider)
            .getDouble(TTSService.speechRateStorageKey);
        _bookSleepTimerOption = TTSSleepTimerOption.off;
        await _ttsService.resetBookOverrides(globalSpeechRate: globalRate);
        return;
      }

      await _ttsService.setSpeechRate(settings.speechRate, persist: false);
      final language = settings.language;
      if (language != null && language.isNotEmpty) {
        await _ttsService.setLanguage(language);
      }
      final voiceName = settings.voiceName;
      final voiceLocale = settings.voiceLocale;
      if (voiceName != null && voiceLocale != null) {
        await _ttsService.setVoice(
          TTSVoice(name: voiceName, locale: voiceLocale),
        );
      }
      _bookSleepTimerOption =
          ttsSleepTimerOptionFromStorage(settings.sleepTimerOption);
      _ttsService.restoreSleepTimerPreference(_bookSleepTimerOption);
    } catch (error, stackTrace) {
      developer.log(
        'Failed to load per-book TTS settings',
        name: 'reader.tts',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  Future<void> _prepareTtsForPlayback() async {
    final loading = _bookTtsSettingsLoad;
    if (loading != null) await loading;
    if (_ttsService.sleepTimerOption == TTSSleepTimerOption.off &&
        _ttsService.preferredSleepTimerOption != TTSSleepTimerOption.off) {
      _ttsService.activatePreferredSleepTimer();
    }
  }

  Future<void> _persistBookTtsSettings() async {
    final voice = _ttsService.voice;
    await ref.read(bookTtsSettingsDaoProvider).save(
          bookId: widget.bookId,
          language: _ttsService.language,
          voiceName: voice?.name,
          voiceLocale: voice?.locale,
          speechRate: _ttsService.speechRate,
          sleepTimerOption: _bookSleepTimerOption.name,
        );
  }

  Future<void> _updateBookTtsSpeechRate(double rate) async {
    await _ttsService.setSpeechRate(rate, persist: false);
    await _saveBookTtsSettingsWithFeedback();
  }

  Future<void> _updateBookTtsLanguage(String language) async {
    final changed = await _ttsService.setLanguage(language);
    if (!changed) {
      _showTtsMessage('系统语音引擎不支持该语言。');
      return;
    }
    await _saveBookTtsSettingsWithFeedback();
    await _ttsService.applyPlaybackSettings();
  }

  Future<void> _updateBookTtsVoice(TTSVoice? voice) async {
    final changed = await _ttsService.setVoice(voice);
    if (!changed) {
      _showTtsMessage(_ttsService.lastError ?? '系统语音引擎无法切换到该声音。');
      return;
    }
    await _saveBookTtsSettingsWithFeedback();
    await _ttsService.applyPlaybackSettings();
  }

  Future<void> _updateBookTtsSleepTimer(
    TTSSleepTimerOption option,
  ) async {
    _bookSleepTimerOption = option;
    _ttsService.setSleepTimer(option);
    await _saveBookTtsSettingsWithFeedback();
  }

  Future<void> _resetBookTtsSettings() async {
    try {
      await ref.read(bookTtsSettingsDaoProvider).reset(widget.bookId);
      final globalRate = ref
          .read(sharedPreferencesProvider)
          .getDouble(TTSService.speechRateStorageKey);
      _bookSleepTimerOption = TTSSleepTimerOption.off;
      await _ttsService.resetBookOverrides(globalSpeechRate: globalRate);
      await _ttsService.applyPlaybackSettings();
      _showTtsMessage('已恢复全局 TTS 设置。');
    } catch (error) {
      _showTtsMessage('恢复全局 TTS 设置失败：$error');
    }
  }

  Future<void> _saveBookTtsSettingsWithFeedback() async {
    try {
      await _persistBookTtsSettings();
    } catch (error) {
      _showTtsMessage('保存本书 TTS 设置失败：$error');
    }
  }

  void _showTtsMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _startTtsFromSelection(
    String selectedText,
    int startOffset,
    int endOffset,
  ) async {
    final chapterIndex = _controller.currentChapterIndex;
    if (chapterIndex < 0 || chapterIndex >= _chapterContents.length) return;
    final content = _readableText(_chapterContents[chapterIndex]);
    if (content.trim().isEmpty) return;

    final resolvedOffset = _resolveSelectionOffset(
      content,
      selectedText,
      startOffset,
    );
    _lastTrackedChapterIndex = chapterIndex;
    _setupTtsSentenceTracking(content);
    final tts = ref.read(ttsServiceProvider);
    await _prepareTtsForPlayback();
    if (!mounted) return;
    final started = await tts.playFromOffset(content, resolvedOffset);
    if (!mounted) return;
    if (!started) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(tts.lastError ?? '无法从所选文本开始朗读。'),
          duration: const Duration(seconds: 5),
        ),
      );
      return;
    }
    _showTtsPanel(content);
  }

  int _resolveSelectionOffset(
    String content,
    String selectedText,
    int requestedOffset,
  ) {
    final offset = requestedOffset.clamp(0, content.length);
    if (selectedText.isEmpty) return offset;
    final end = offset + selectedText.length;
    if (end <= content.length &&
        content.substring(offset, end) == selectedText) {
      return offset;
    }

    var bestMatch = -1;
    var searchFrom = 0;
    while (searchFrom < content.length) {
      final match = content.indexOf(selectedText, searchFrom);
      if (match < 0) break;
      if (bestMatch < 0 ||
          (match - offset).abs() < (bestMatch - offset).abs()) {
        bestMatch = match;
      }
      searchFrom = match + selectedText.length;
    }
    return bestMatch >= 0 ? bestMatch : offset;
  }

  /// Set up sentence tracking between TTS service and reader controller.
  /// Call this whenever the current chapter content changes.
  void _setupTtsSentenceTracking(String content) {
    final sentences = SentenceSplitter.split(content);
    final ctrl = ref.read(readerControllerProvider(widget.bookId));
    ctrl.setCurrentSentences(sentences);
    _syncTtsMediaSessionChapter();
    final tts = ref.read(ttsServiceProvider);
    tts.setCurrentContent(sentences);
    tts.onSentenceChanged = (idx) {
      ctrl.setActiveSentenceIndex(idx);
      if (idx != null) _scrollToSentence(idx);
    };
    tts.onContentCompleted = _handleTtsChapterCompleted;
  }

  void _syncTtsMediaSessionChapter() {
    final book = _book;
    final chapterIndex = _controller.currentChapterIndex;
    if (book == null || chapterIndex < 0 || chapterIndex >= _chapters.length) {
      return;
    }
    final chapter = _chapters[chapterIndex];
    _ttsMediaSession?.updateChapter(
      bookId: book.id,
      chapterId: chapter.id,
      bookTitle: book.title,
      chapterTitle: chapter.title,
      author: book.author,
      hasPreviousChapter: chapterIndex > 0,
      hasNextChapter: chapterIndex < _chapters.length - 1,
    );
  }

  Future<void> _handleTtsChapterCompleted() async {
    if (!mounted || _ttsChapterTransitionInProgress || _chapters.isEmpty) {
      return;
    }
    final completedIndex = _controller.currentChapterIndex;
    final tts = ref.read(ttsServiceProvider);
    if (completedIndex >= _chapters.length - 1) {
      tts.cancelSleepTimer();
      _controller.setActiveSentenceIndex(null);
      return;
    }

    await _playTtsChapter(
      completedIndex + 1,
      expectedCurrentIndex: completedIndex,
    );
  }

  Future<void> _playPreviousTtsChapter() {
    return _playTtsChapter(_controller.currentChapterIndex - 1);
  }

  Future<void> _playNextTtsChapter() {
    return _playTtsChapter(_controller.currentChapterIndex + 1);
  }

  Future<void> _playTtsChapter(
    int targetIndex, {
    int? expectedCurrentIndex,
    int? startOffset,
  }) async {
    if (!mounted ||
        targetIndex < 0 ||
        targetIndex >= _chapters.length ||
        (expectedCurrentIndex != null &&
            _controller.currentChapterIndex != expectedCurrentIndex)) {
      return;
    }
    final transitionRevision = ++_ttsChapterTransitionRevision;
    _ttsChapterTransitionInProgress = true;
    try {
      final tts = ref.read(ttsServiceProvider);
      if (expectedCurrentIndex == null && (tts.isPlaying || tts.isPaused)) {
        await tts.stop(cancelSleepTimer: false);
      }
      await _saveProgress();
      if (!mounted ||
          transitionRevision != _ttsChapterTransitionRevision ||
          (expectedCurrentIndex != null &&
              expectedCurrentIndex != _controller.currentChapterIndex)) {
        return;
      }

      _cancelPositionRestore();
      _chapterTransitionDirection =
          targetIndex >= _controller.currentChapterIndex ? 1 : -1;
      _controller.setCurrentChapterIndex(targetIndex);
      _controller.setCurrentChapterId(_chapters[targetIndex].id);
      _trimChapterMemory(targetIndex);
      unawaited(_preloadAdjacentChapters(targetIndex));
      unawaited(_refreshBookmarkState());

      if (_book?.format == 'pdf') {
        await _loadPdfPageContent(targetIndex);
        _pdfReaderKey.currentState?.goToPage(targetIndex);
      } else if (_chapterContents[targetIndex].isEmpty) {
        final loaded = await ref
            .read(bookDaoProvider)
            .getChapterContent(_chapters[targetIndex].id);
        if (!mounted || transitionRevision != _ttsChapterTransitionRevision) {
          return;
        }
        if (loaded != null && loaded.isNotEmpty) {
          setState(() => _chapterContents[targetIndex] = loaded);
        }
      }

      final content = _readableText(_chapterContents[targetIndex]);
      if (content.trim().isEmpty) {
        ref.read(ttsServiceProvider).cancelSleepTimer();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('目标章节没有可朗读的文字，连续朗读已停止。')),
          );
        }
        return;
      }

      _lastTrackedChapterIndex = targetIndex;
      _setupTtsSentenceTracking(content);
      final normalizedStartOffset =
          startOffset?.clamp(0, content.length).toInt();
      if (normalizedStartOffset != null) {
        final targetPosition =
            content.isEmpty ? 0.0 : normalizedStartOffset / content.length;
        _controller.setScrollPosition(targetPosition);
        if (_controller.readingMode == ReadingMode.scroll) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            unawaited(_restoreChapterPosition(targetIndex, targetPosition));
          });
        }
      }
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted ||
          transitionRevision != _ttsChapterTransitionRevision ||
          targetIndex != _controller.currentChapterIndex) {
        return;
      }
      await _prepareTtsForPlayback();
      if (!mounted || transitionRevision != _ttsChapterTransitionRevision) {
        return;
      }
      final started = normalizedStartOffset == null
          ? await tts.play(content)
          : await tts.playFromOffset(content, normalizedStartOffset);
      if (!started && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(tts.lastError ?? '无法继续朗读目标章节。'),
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } finally {
      if (transitionRevision == _ttsChapterTransitionRevision) {
        _ttsChapterTransitionInProgress = false;
      }
    }
  }

  void _stopTtsForManualChapterNavigation() {
    _ttsChapterTransitionRevision++;
    final tts = ref.read(ttsServiceProvider);
    if (tts.isPlaying || tts.isPaused || _ttsChapterTransitionInProgress) {
      unawaited(tts.stop());
    }
    _ttsChapterTransitionInProgress = false;
    _controller.setActiveSentenceIndex(null);
    _lastTrackedChapterIndex = -1;
  }

  String _readableText(String content) {
    if (_book?.format == 'epub') {
      return EpubParser.stripHtml(content);
    }
    return content;
  }

  /// Auto-scroll to keep the highlighted sentence visible.
  void _scrollToSentence(int sentenceIndex) {
    final ctrl = ref.read(readerControllerProvider(widget.bookId));
    final total = ctrl.totalSentences;
    if (total == 0) return;
    final pos = sentenceIndex / total;
    final sc = _getScrollController(ctrl.currentChapterIndex);
    if (!sc.hasClients) return;
    final maxExtent = sc.position.maxScrollExtent;
    if (maxExtent <= 0) return;
    sc.animateTo(
      maxExtent * pos,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  String? _currentSurroundingText() {
    if (_chapters.isEmpty) return null;
    final idx = _controller.currentChapterIndex;
    if (idx < 0 || idx >= _chapterContents.length) return null;
    return ReaderOverlays.surroundingTextAtPosition(
      _readableText(_chapterContents[idx]),
      _controller.scrollPosition,
    );
  }

  Future<void> _openAiSourceReference(AiSourceReference reference) async {
    if (reference.bookId != null && reference.bookId != widget.bookId) return;
    final locator = reference.locator ??
        ReaderLocator(
          bookId: reference.bookId ?? widget.bookId,
          chapterId: reference.chapterId,
          chapterPosition: reference.chapterPosition,
          query: reference.query,
        );
    await _applyLocator(locator, recordHistory: true);
  }

  void _showAiPanel(
    String? initialPrompt, [
    String? selectedText,
  ]) {
    final content = _controller.currentChapterIndex < _chapterContents.length
        ? _readableText(_chapterContents[_controller.currentChapterIndex])
        : null;
    final chapter = _chapters.isNotEmpty
        ? _chapters[_controller.currentChapterIndex]
        : null;

    ReaderOverlays.showAiPanel(
      context,
      bookId: widget.bookId,
      book: _book,
      chapter: chapter,
      controller: _controller,
      chapterContent: content,
      initialPrompt: initialPrompt,
      selectedText: selectedText,
      surroundingText: _currentSurroundingText(),
      spoilerProtectionLevel:
          ref.read(spoilerProtectionProvider).levelFor(widget.bookId),
      onOpenReference: _openAiSourceReference,
    );
  }

  Future<void> _refreshBookmarkState() async {
    if (_chapters.isEmpty) return;
    final chapterId = _chapters[_controller.currentChapterIndex].id;
    final bm = await ref.read(noteDaoProvider).bookmarkFor(
          widget.bookId,
          chapterId,
        );
    if (mounted) setState(() => _isBookmarked = bm != null);
  }

  Future<void> _toggleBookmark() async {
    final chapterId = _chapters[_controller.currentChapterIndex].id;
    final dao = ref.read(noteDaoProvider);
    final existing = await dao.bookmarkFor(widget.bookId, chapterId);
    if (existing != null) {
      await dao.deleteNote(existing.id);
      if (mounted) setState(() => _isBookmarked = false);
    } else {
      await dao.addBookmark(
        bookId: widget.bookId,
        chapterId: chapterId,
        position: _controller.scrollPosition,
      );
      if (mounted) setState(() => _isBookmarked = true);
    }
  }

  void _goToChapter(int index, {double? position}) {
    if (index < 0 || index >= _chapters.length) return;
    _stopTtsForManualChapterNavigation();
    final targetPosition = position?.clamp(0.0, 1.0).toDouble();
    _cancelPositionRestore();
    unawaited(_saveProgress());
    final changedChapter = index != _controller.currentChapterIndex;
    if (changedChapter) {
      _chapterTransitionDirection =
          index > _controller.currentChapterIndex ? 1 : -1;
      _controller.setCurrentChapterIndex(index);
    }
    _trimChapterMemory(index);
    unawaited(_preloadAdjacentChapters(index));
    _controller.setCurrentChapterId(_chapters[index].id);
    if (targetPosition != null) {
      _controller.setScrollPosition(targetPosition);
    }
    unawaited(_refreshBookmarkState());
    if (_book?.format == 'pdf') {
      unawaited(_loadPdfPageContent(index));
      _pdfReaderKey.currentState?.goToPage(_controller.currentChapterIndex);
    } else if (targetPosition != null) {
      if (_controller.readingMode == ReadingMode.scroll) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          unawaited(_restoreChapterPosition(index, targetPosition));
        });
      } else {
        _scheduleProgressSave(const Duration(milliseconds: 200));
      }
    } else if (changedChapter &&
        _controller.readingMode == ReadingMode.scroll) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        unawaited(_restoreChapterPosition(index, 0));
      });
    }
  }

  void _goToChapterFromNavigation(int index, {double? position}) {
    if (index < 0 || index >= _chapters.length) return;
    final targetPosition = position?.clamp(0.0, 1.0).toDouble() ?? 0.0;
    _recordNavigationJump(
      ReaderLocator(
        bookId: widget.bookId,
        chapterId: _chapters[index].id,
        format: _book?.format,
        pageNumber: _book?.format == 'pdf' ? index : null,
        chapterPosition: targetPosition,
      ),
    );
    _goToChapter(index, position: targetPosition);
  }

  void _showToc() {
    ReaderTocSheet.show(
      context,
      chapters: _chapters,
      controller: _controller,
      noteDao: ref.read(noteDaoProvider),
      onChapterSelected: _goToChapterFromNavigation,
      onBookmarkSelected: (idx, pos) =>
          _goToChapterFromNavigation(idx, position: pos),
    );
  }

  // ignore: unused_element
  void _handleHighlight(String text, int start, int end) async {
    if (_chapters.isEmpty) return;
    ReaderOverlays.handleHighlight(
      context,
      bookId: widget.bookId,
      chapter: _chapters[_controller.currentChapterIndex],
      text: text,
      start: start,
      end: end,
      noteService: ref.read(noteServiceProvider),
    );
  }

  void _handleNote(String text, int start, int end) async {
    if (!mounted || _chapters.isEmpty) return;
    ReaderOverlays.handleNote(
      context,
      bookId: widget.bookId,
      chapter: _chapters[_controller.currentChapterIndex],
      text: text,
      start: start,
      end: end,
      noteService: ref.read(noteServiceProvider),
    );
  }

  Future<void> _handleVocabulary(
    String selectedText,
    int startOffset,
    int _,
  ) async {
    await _openVocabulary(
      selectedText,
      startOffset,
      _controller.currentChapterIndex,
    );
  }

  Future<void> _handlePdfVocabulary(
    String selectedText,
    int pageIndex,
  ) async {
    if (pageIndex < 0 || pageIndex >= _chapters.length) return;
    await _loadPdfPageContent(pageIndex);
    if (!mounted) return;
    await _openVocabulary(selectedText, 0, pageIndex);
  }

  Future<void> _openVocabulary(
    String selectedText,
    int startOffset,
    int chapterIndex,
  ) async {
    final leadingWhitespace =
        selectedText.length - selectedText.trimLeft().length;
    final term = selectedText.trim();
    if (term.isEmpty || _chapters.isEmpty) return;
    if (term.length > VocabularyService.maxTermLength) {
      _showReaderMessage('选中文本过长，请选择不超过 200 个字符的词语或短语。');
      return;
    }

    if (chapterIndex < 0 || chapterIndex >= _chapterContents.length) return;
    final content = _readableText(_chapterContents[chapterIndex]);
    final resolvedStart = _resolveSelectionOffset(
      content,
      term,
      startOffset + leadingWhitespace,
    );
    final resolvedEnd =
        (resolvedStart + term.length).clamp(0, content.length).toInt();
    final sentences = SentenceSplitter.split(content);
    final sentenceIndex =
        SentenceSplitter.findSentenceIndex(sentences, resolvedStart);
    final contextText =
        sentenceIndex < 0 ? null : sentences[sentenceIndex].text.trim();

    final saved = await VocabularyLookupSheet.show(
      context,
      service: ref.read(vocabularyServiceProvider),
      dictionaryService: ref.read(dictionaryServiceProvider),
      bookId: widget.bookId,
      chapterId: _chapters[chapterIndex].id,
      term: term,
      contextText: contextText,
      positionStart: resolvedStart,
      positionEnd: resolvedEnd,
      onOccurrenceTap: (locator) {
        unawaited(_applyLocator(locator, recordHistory: true));
      },
    );
    if (saved == true && mounted) {
      _showReaderMessage('已加入生词本。');
    }
  }

  void _handleTranslation(String selectedText) {
    final text = selectedText.trim();
    if (text.isEmpty) return;
    if (text.length > TranslationService.maxTextLength) {
      _showReaderMessage('选中文本过长，请选择不超过 5000 个字符的内容。');
      return;
    }
    final settings = ref.read(translationSettingsProvider);
    if (!settings.enabled) {
      _showReaderMessage('请先在设置中启用在线翻译。');
      return;
    }
    unawaited(
      TranslationSheet.show(
        context,
        service: ref.read(translationServiceProvider),
        text: text,
        targetLanguage: settings.targetLanguage,
      ),
    );
  }

  Future<void> _handleTranslationToolTap() async {
    final settings = ref.read(translationSettingsProvider);
    if (settings.enabled) {
      _controller.setToolbarVisible(false);
      _showReaderMessage('长按选择正文，然后点击“翻译”。');
      return;
    }

    final openSettings = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('启用在线翻译'),
        content: const Text(
          '翻译只会在你选中文字并点击“翻译”后触发。选中的正文将发送给在线翻译服务，可能产生流量或供应商费用。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            key: const Key('open-translation-settings'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('前往设置'),
          ),
        ],
      ),
    );
    if (openSettings != true || !mounted) return;

    await Navigator.of(context).push(
      GlassPageRoute<void>(
        builder: (_) => const TranslationSettingsPage(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('阅读')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: GlassContainer.stable(
              padding: const EdgeInsets.all(24),
              child: EmptyState(
                icon: Icons.error_outline,
                title: '加载失败',
                subtitle: _error!,
                // 打开书失败最常见的原因是文件被外部挪走或占用，都是重试
                // 一次就可能好的。没有这个按钮就只能退出去重新点一次书。
                action: FilledButton.icon(
                  onPressed: () {
                    setState(() {
                      _error = null;
                      _loading = true;
                    });
                    unawaited(_loadData());
                  },
                  icon: const Icon(Icons.refresh),
                  label: const Text('重试'),
                ),
              ),
            ),
          ),
        ),
      );
    }

    if (_chapters.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('阅读')),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(32.0),
            child: GlassContainer.stable(
              padding: EdgeInsets.all(24),
              child: EmptyState(
                icon: Icons.menu_book_outlined,
                title: '没有章节内容',
                subtitle: '该书籍可能格式不支持或文件已损坏',
              ),
            ),
          ),
        ),
      );
    }

    final readerState = ref.watch(
      readerControllerProvider(widget.bookId).select(
        (controller) => (
          chapterIndex: controller.currentChapterIndex,
          readingMode: controller.readingMode,
          activeSentenceIndex: controller.activeSentenceIndex,
        ),
      ),
    );
    final chapter = _chapters[readerState.chapterIndex];
    final content = readerState.chapterIndex < _chapterContents.length
        ? _chapterContents[readerState.chapterIndex]
        : '';

    final ttsPlaybackState = ref.watch(
      ttsServiceProvider.select(
        (tts) => (isPlaying: tts.isPlaying, isPaused: tts.isPaused),
      ),
    );
    final overlayPreferences = ref.watch(
      effectiveBookReadingPreferencesProvider(widget.bookId).select(
        (preferences) => (
          brightness: preferences.readingBrightness,
          gestureEnabled: preferences.brightnessGestureEnabled,
          lineFocusEnabled: preferences.lineFocusEnabled,
          lineFocusLineCount: preferences.lineFocusLineCount,
          lineFocusLineHeight: preferences.fontSize * preferences.lineHeight,
          lineFocusDimAmount: preferences.lineFocusDimAmount,
        ),
      ),
    );
    final translationEnabled = ref.watch(
      translationSettingsProvider.select((settings) => settings.enabled),
    );

    // 正文纸张独立于全局主题：想黑底白字读书，不必把书架和设置页一起变暗。
    // 覆盖整棵子树而不是只染正文——工具栏、目录面板、快捷设置都从
    // colorScheme 取色，一起换才不会出现「黑底正文弹出白色目录」。
    final paperTheme = readerThemeFor(
      Theme.of(context),
      ref.watch(preferencesProvider.select((p) => p.readerPaper)),
    );

    return Theme(
      data: paperTheme,
      child: PopScope<void>(
        canPop: _allowPop,
        onPopInvokedWithResult: (didPop, result) {
          if (!didPop) {
            unawaited(_exitReader());
          }
        },
        child: Scaffold(
          backgroundColor: paperTheme.colorScheme.surface,
        body: ImmersiveReaderShell(
          controller: _controller,
          readerTapExclusionKeys: [_nextChapterButtonKey],
          readingBrightness: overlayPreferences.brightness,
          brightnessGestureEnabled: overlayPreferences.gestureEnabled,
          lineFocusEnabled: overlayPreferences.lineFocusEnabled,
          lineFocusLineCount: overlayPreferences.lineFocusLineCount,
          lineFocusLineHeight: overlayPreferences.lineFocusLineHeight,
          lineFocusDimAmount: overlayPreferences.lineFocusDimAmount,
          onBrightnessChanged: (value) {
            ref
                .read(preferencesProvider.notifier)
                .updateReadingBrightness(value);
          },
          toolbarBuilder: () => ReaderToolbar(
            onBack: _exitReader,
            chapterTitle: chapter.title,
            currentChapter: readerState.chapterIndex,
            totalChapters: _chapters.length,
            scrollPosition: _controller.scrollPosition,
            scrollPositionListenable: _controller.scrollPositionListenable,
            isExpanded: _controller.toolbarExpanded,
            onToggleExpanded: _controller.toggleToolbarExpanded,
            onHide: () => _controller.setToolbarVisible(false),
            onToc: _showToc,
            isBookmarked: _isBookmarked,
            onBookmark: _toggleBookmark,
            onAi: () => _showAiPanel(null),
            translationEnabled: translationEnabled,
            onTranslation: () => unawaited(_handleTranslationToolTap()),
            onSettings: () => _showQuickSettings(),
            onPrevious: _goToPrevious,
            onNext: _goToNext,
            onHistoryBack:
                _navigationHistory.canGoBack ? _goBackInHistory : null,
            onHistoryForward:
                _navigationHistory.canGoForward ? _goForwardInHistory : null,
            onTts: () async {
              final tts = ref.read(ttsServiceProvider);
              final readableContent = _readableText(content);
              await _prepareTtsForPlayback();
              if (!context.mounted) return;
              if (_lastTrackedChapterIndex != readerState.chapterIndex) {
                _lastTrackedChapterIndex = readerState.chapterIndex;
                _setupTtsSentenceTracking(readableContent);
              }
              if (!tts.isPlaying && !tts.isPaused) {
                final started = await tts.play(
                  readableContent,
                  _controller.scrollPosition,
                );
                if (!context.mounted) return;
                if (!started) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(tts.lastError ?? '无法启动系统语音朗读。'),
                      duration: const Duration(seconds: 5),
                    ),
                  );
                }
              }
              if (context.mounted) {
                _showTtsPanel(readableContent);
              }
            },
          ),
          readerBody: Stack(
            children: [
              Positioned.fill(
                child: _buildReaderWithChapterTransition(
                  content,
                  chapter,
                  readingMode: readerState.readingMode,
                  activeSentenceIndex: readerState.activeSentenceIndex,
                ),
              ),
              _buildNextChapterButton(readerState.chapterIndex),
            ],
          ),
          ttsMiniPlayer:
              (ttsPlaybackState.isPlaying || ttsPlaybackState.isPaused)
                  ? TtsMiniPlayer(
                      content: _readableText(content),
                      onTap: () => _showTtsPanel(_readableText(content)),
                    )
                  : null,
          ),
        ),
      ),
    );
  }

  Widget _buildReaderWithChapterTransition(
    String content,
    Chapter chapter, {
    required ReadingMode readingMode,
    required int? activeSentenceIndex,
  }) {
    final reader = _buildReaderWidget(
      content,
      chapter,
      readingMode: readingMode,
      activeSentenceIndex: activeSentenceIndex,
    );

    if (readingMode != ReadingMode.page || _book?.format == 'pdf') {
      return reader;
    }

    final readerKey = ValueKey<String>('page-reader-${chapter.id}');
    final direction = _chapterTransitionDirection >= 0 ? 1.0 : -1.0;

    return ClipRect(
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 420),
        reverseDuration: const Duration(milliseconds: 360),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInOutCubic,
        layoutBuilder: (currentChild, previousChildren) {
          return Stack(
            fit: StackFit.expand,
            children: [
              ...previousChildren,
              if (currentChild != null) currentChild,
            ],
          );
        },
        transitionBuilder: (child, animation) {
          final incoming = child.key == readerKey;
          final slide = Tween<Offset>(
            begin: incoming
                ? Offset(direction * 0.16, 0)
                : Offset(-direction * 0.08, 0),
            end: Offset.zero,
          ).animate(animation);
          final opacity = Tween<double>(
            begin: incoming ? 0.96 : 0.90,
            end: 1,
          ).animate(animation);

          return FadeTransition(
            opacity: opacity,
            child: SlideTransition(
              position: slide,
              child: child,
            ),
          );
        },
        child: KeyedSubtree(
          key: readerKey,
          child: reader,
        ),
      ),
    );
  }

  ScrollController _getScrollController(int chapterIndex) {
    if (!_scrollControllers.containsKey(chapterIndex)) {
      final sc = ScrollController();
      sc.addListener(() {
        if (sc.hasClients) {
          final maxScroll = sc.position.maxScrollExtent;
          final currentScroll = sc.position.pixels;
          final position = maxScroll > 0 ? currentScroll / maxScroll : 0.0;
          _onScrollUpdate(position);
        }
      });
      _scrollControllers[chapterIndex] = sc;
    }
    return _scrollControllers[chapterIndex]!;
  }

  Widget _buildReaderWidget(
    String content,
    Chapter chapter, {
    required ReadingMode readingMode,
    required int? activeSentenceIndex,
  }) {
    final chapterIndex = _controller.currentChapterIndex;
    final readingPreferences =
        ref.watch(effectiveBookReadingPreferencesProvider(widget.bookId));
    final translationEnabled =
        ref.watch(translationSettingsProvider.select((value) => value.enabled));

    if (_book!.format == 'pdf') {
      return PdfReader(
        key: _pdfReaderKey,
        filePath: _book!.filePath,
        initialPage: _controller.currentChapterIndex,
        cropAmount: readingPreferences.pdfCropAmount,
        contrast: readingPreferences.pdfContrast,
        enableDoublePage: readingPreferences.pdfPageLayout == 'double',
        onVocabularyAction: (text, pageIndex) =>
            unawaited(_handlePdfVocabulary(text, pageIndex)),
        onTranslateAction:
            translationEnabled ? (text, _) => _handleTranslation(text) : null,
        onPageChanged: (pageIndex) {
          if (mounted && pageIndex != _controller.currentChapterIndex) {
            _stopTtsForManualChapterNavigation();
            unawaited(_saveProgress());
            _controller.setCurrentChapterIndex(pageIndex);
            _controller.setCurrentChapterId(_chapters[pageIndex].id);
            unawaited(_loadPdfPageContent(pageIndex));
          }
        },
      );
    }

    if (content.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (readingMode == ReadingMode.page) {
      final pageContent = _readableText(content);
      return PagedReader(
        key: ValueKey('${chapter.id}_$readingMode'),
        content: pageContent,
        chapterTitle: chapter.title,
        fontSize: readingPreferences.fontSize,
        lineHeight: readingPreferences.lineHeight,
        margin: readingPreferences.margin,
        fontFamily: readingPreferences.fontFamily,
        paragraphSpacing: readingPreferences.paragraphSpacing,
        letterSpacing: readingPreferences.letterSpacing,
        wordSpacing: readingPreferences.wordSpacing,
        boldText: readingPreferences.boldText,
        textAlign: readingPreferences.textAlignment == 'justify'
            ? TextAlign.justify
            : TextAlign.start,
        paragraphIndent: readingPreferences.paragraphIndent,
        topContentPadding: readingPreferences.topContentPadding,
        pageTurnEffect: readingPreferences.pageTurnEffect,
        initialPosition: _controller.scrollPosition,
        onPositionChanged: _onPagePositionChanged,
        onAdvanceBeyondLast:
            chapterIndex < _chapters.length - 1 ? _goToNext : null,
        onRetreatBeforeFirst: chapterIndex > 0 ? _goToPreviousAtEnd : null,
        onAiAction: (text) => _showAiPanel(null, text),
        onTranslateAction: translationEnabled ? _handleTranslation : null,
        onTtsAction: _startTtsFromSelection,
        onVocabularyAction: _handleVocabulary,
        onNoteAction: _handleNote,
        locatorHighlightStart: _locatorHighlightStart,
        locatorHighlightEnd: _locatorHighlightEnd,
        activeSentenceIndex: activeSentenceIndex,
      );
    }

    if (_book!.format == 'epub') {
      return EpubReader(
        key: ValueKey(chapter.id),
        content: content,
        chapterTitle: chapter.title,
        fontSize: readingPreferences.fontSize,
        lineHeight: readingPreferences.lineHeight,
        margin: readingPreferences.margin,
        fontFamily: readingPreferences.fontFamily,
        paragraphSpacing: readingPreferences.paragraphSpacing,
        letterSpacing: readingPreferences.letterSpacing,
        wordSpacing: readingPreferences.wordSpacing,
        boldText: readingPreferences.boldText,
        textAlign: readingPreferences.textAlignment == 'justify'
            ? TextAlign.justify
            : TextAlign.start,
        paragraphIndent: readingPreferences.paragraphIndent,
        topContentPadding: readingPreferences.topContentPadding,
        scrollController: _getScrollController(chapterIndex),
        activeSentenceIndex: activeSentenceIndex,
        onAiAction: (text) => _showAiPanel(null, text),
        onTranslateAction: translationEnabled ? _handleTranslation : null,
        onTtsAction: _startTtsFromSelection,
        onVocabularyAction: _handleVocabulary,
        onNoteAction: _handleNote,
        locatorHighlightStart: _locatorHighlightStart,
        locatorHighlightEnd: _locatorHighlightEnd,
        onLinkTap: (link) => unawaited(_handleEpubLink(link)),
      );
    } else {
      return TxtReader(
        key: ValueKey(chapter.id),
        content: content,
        chapterTitle: chapter.title,
        fontSize: readingPreferences.fontSize,
        lineHeight: readingPreferences.lineHeight,
        margin: readingPreferences.margin,
        fontFamily: readingPreferences.fontFamily,
        paragraphSpacing: readingPreferences.paragraphSpacing,
        letterSpacing: readingPreferences.letterSpacing,
        wordSpacing: readingPreferences.wordSpacing,
        boldText: readingPreferences.boldText,
        textAlign: readingPreferences.textAlignment == 'justify'
            ? TextAlign.justify
            : TextAlign.start,
        paragraphIndent: readingPreferences.paragraphIndent,
        topContentPadding: readingPreferences.topContentPadding,
        scrollController: _getScrollController(chapterIndex),
        activeSentenceIndex: activeSentenceIndex,
        onAiAction: (text) => _showAiPanel(null, text),
        onTranslateAction: translationEnabled ? _handleTranslation : null,
        onTtsAction: _startTtsFromSelection,
        onVocabularyAction: _handleVocabulary,
        onNoteAction: _handleNote,
        locatorHighlightStart: _locatorHighlightStart,
        locatorHighlightEnd: _locatorHighlightEnd,
      );
    }
  }

  Widget _buildNextChapterButton(int chapterIndex) {
    if ((_book?.format ?? '') == 'pdf' ||
        _controller.readingMode == ReadingMode.page ||
        chapterIndex >= _chapters.length - 1) {
      return const SizedBox.shrink();
    }

    final nextChapter = _chapters[chapterIndex + 1];
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return ValueListenableBuilder<double>(
          valueListenable: _controller.scrollPositionListenable,
          builder: (context, position, _) {
            final visible = position >= 0.98 && !_controller.toolbarVisible;
            final theme = Theme.of(context);
            return IgnorePointer(
              ignoring: !visible,
              child: SafeArea(
                minimum: const EdgeInsets.fromLTRB(20, 20, 20, 18),
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: AnimatedSlide(
                    offset: visible ? Offset.zero : const Offset(0, 0.2),
                    duration: const Duration(milliseconds: 180),
                    child: AnimatedOpacity(
                      opacity: visible ? 1 : 0,
                      duration: const Duration(milliseconds: 180),
                      child: Material(
                        key: visible ? _nextChapterButtonKey : null,
                        color: theme.colorScheme.surfaceContainerHigh,
                        borderRadius: BorderRadius.circular(20),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(20),
                          onTap: _goToNext,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.arrow_forward_rounded,
                                  size: 18,
                                  color: theme.colorScheme.primary,
                                ),
                                const SizedBox(width: 10),
                                ConstrainedBox(
                                  constraints:
                                      const BoxConstraints(maxWidth: 260),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '继续阅读下一章',
                                        style: theme.textTheme.labelMedium
                                            ?.copyWith(
                                          color: theme
                                              .colorScheme.onSurfaceVariant,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        nextChapter.title,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: theme.textTheme.titleSmall
                                            ?.copyWith(
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showQuickSettings() {
    unawaited(
      showQuickSettingsPanel(
        context,
        ref,
        bookId: widget.bookId,
        isPdf: _book?.format == 'pdf',
        currentMode: _controller.readingMode,
        onModeChanged: _changeReadingMode,
      ),
    );
  }

  void _changeReadingMode(ReadingMode mode) {
    if (mode == _controller.readingMode) return;

    final chapterIndex = _controller.currentChapterIndex;
    final anchor = _controller.scrollPosition;
    _scrollDebounce?.cancel();
    _cancelPositionRestore();
    _controller.setScrollPosition(anchor);

    if (mode == ReadingMode.scroll) {
      // Suppress the retained ScrollController's old offset until the saved
      // text anchor has been applied to the newly mounted scroll reader.
      _restoringScrollPosition = true;
    }

    unawaited(_saveProgress());
    _controller.setReadingMode(mode);

    if (mode == ReadingMode.scroll) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _controller.setScrollPosition(anchor);
        unawaited(_restoreChapterPosition(chapterIndex, anchor));
      });
    } else {
      _scheduleProgressSave(const Duration(milliseconds: 200));
    }
  }
}
