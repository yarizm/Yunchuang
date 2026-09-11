import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../database/daos/progress_dao.dart';
import '../../utils/sentence_splitter.dart';
import 'format_reader.dart';

class ReaderController extends ChangeNotifier {
  final int bookId;

  ReaderController({required this.bookId});

  int _currentChapterIndex = 0;
  double _scrollPosition = 0.0;
  final ValueNotifier<double> scrollPositionListenable =
      ValueNotifier<double>(0.0);
  ReadingMode _readingMode = ReadingMode.scroll;
  bool _toolbarVisible = true;
  bool _toolbarExpanded = false;
  int _totalReadingSeconds = 0;
  int? _activeSentenceIndex;
  List<SentenceSpan>? _currentSentences;
  Timer? _readingTimer;
  DateTime? _lastTickTime;
  int? _currentChapterId;
  int chapterCount = 0;

  /// 每秒计时回调，传入当前累计的 [totalReadingSeconds]。
  /// 由外部（reader_page）订阅以同步 todaySeconds。
  void Function(int totalSeconds)? onTick;

  int get currentChapterIndex => _currentChapterIndex;
  double get scrollPosition => _scrollPosition;
  ReadingMode get readingMode => _readingMode;
  bool get toolbarVisible => _toolbarVisible;
  bool get toolbarExpanded => _toolbarExpanded;
  int get totalReadingSeconds => _totalReadingSeconds;
  int? get activeSentenceIndex => _activeSentenceIndex;
  int? get currentChapterId => _currentChapterId;

  /// Overall reading progress across the whole book in [0, 1], combining the
  /// current chapter index with the in-chapter scroll fraction. Backs both the
  /// persisted percentage (shelf progress) and the always-visible progress bar.
  double get bookProgress {
    if (chapterCount <= 0) return 0;
    return ((_currentChapterIndex + _scrollPosition) / chapterCount)
        .clamp(0.0, 1.0);
  }

  void setCurrentChapterIndex(int index) {
    if (index == _currentChapterIndex) return;
    _currentChapterIndex = index;
    _scrollPosition = 0.0;
    scrollPositionListenable.value = 0.0;
    notifyListeners();
  }

  void setCurrentChapterIndexAtEnd(int index) {
    if (index == _currentChapterIndex) return;
    _currentChapterIndex = index;
    _scrollPosition = 1.0;
    scrollPositionListenable.value = 1.0;
    notifyListeners();
  }

  void setScrollPosition(double pos) {
    final next = pos.clamp(0.0, 1.0);
    _scrollPosition = next;
    if ((scrollPositionListenable.value - next).abs() >= 0.001) {
      scrollPositionListenable.value = next;
    }
  }

  void setReadingMode(ReadingMode mode) {
    _readingMode = mode;
    notifyListeners();
  }

  void toggleToolbar() {
    _toolbarVisible = !_toolbarVisible;
    if (_toolbarVisible) {
      _toolbarExpanded = false;
    }
    notifyListeners();
  }

  void setToolbarVisible(bool visible) {
    if (_toolbarVisible == visible) return;
    _toolbarVisible = visible;
    if (visible) {
      _toolbarExpanded = false;
    }
    notifyListeners();
  }

  void setToolbarExpanded(bool expanded) {
    if (_toolbarExpanded == expanded) return;
    _toolbarExpanded = expanded;
    notifyListeners();
  }

  void toggleToolbarExpanded() {
    _toolbarExpanded = !_toolbarExpanded;
    notifyListeners();
  }

  void addReadingSeconds(int seconds) {
    _totalReadingSeconds += seconds;
    notifyListeners();
  }

  void setActiveSentenceIndex(int? index) {
    if (_activeSentenceIndex == index) return;
    _activeSentenceIndex = index;
    notifyListeners();
  }

  void setCurrentSentences(List<SentenceSpan> sentences) {
    _currentSentences = sentences;
  }

  /// Return the sentence span at [index], or null if not available.
  SentenceSpan? getSentenceSpan(int index) {
    if (_currentSentences == null) return null;
    if (index < 0 || index >= _currentSentences!.length) return null;
    return _currentSentences![index];
  }

  int get totalSentences => _currentSentences?.length ?? 0;

  void startReadingTimer() {
    _readingTimer?.cancel();
    _lastTickTime = DateTime.now();
    _readingTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      final now = DateTime.now();
      final elapsed = now.difference(_lastTickTime!).inSeconds;
      if (elapsed > 0) {
        _totalReadingSeconds += elapsed;
        _lastTickTime = now;
        onTick?.call(_totalReadingSeconds);
      }
    });
  }

  void pauseReadingTimer() {
    _readingTimer?.cancel();
    _readingTimer = null;
    _lastTickTime = null;
  }

  void setCurrentChapterId(int id) {
    _currentChapterId = id;
  }

  /// Restore total reading seconds from DB (does not trigger rebuild).
  void setTotalReadingSeconds(int s) {
    _totalReadingSeconds = s;
  }

  /// Persist current scroll position, chapter id, and reading duration.
  /// Uses a targeted update to avoid overwriting percentage and other fields
  /// that this controller does not manage.
  Future<void> flushProgress(ProgressDao dao) async {
    await dao.saveSessionProgress(
      bookId: bookId,
      chapterId: _currentChapterId,
      positionInChapter: _scrollPosition,
      totalReadingSeconds: _totalReadingSeconds,
    );
  }

  @override
  void dispose() {
    _readingTimer?.cancel();
    scrollPositionListenable.dispose();
    super.dispose();
  }
}

final readerControllerProvider =
    ChangeNotifierProvider.family<ReaderController, int>(
  (ref, bookId) => ReaderController(bookId: bookId),
);
