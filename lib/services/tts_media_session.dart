import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'tts_service.dart';

final ttsMediaSessionProvider = Provider<TtsMediaSession?>((ref) => null);

class TtsMediaSession extends BaseAudioHandler {
  TTSService? _tts;
  AsyncCallback? _onPreviousChapter;
  AsyncCallback? _onNextChapter;
  bool _hasPreviousChapter = false;
  bool _hasNextChapter = false;
  Timer? _completionTimer;

  void attach({
    required TTSService tts,
    AsyncCallback? onPreviousChapter,
    AsyncCallback? onNextChapter,
  }) {
    if (!identical(_tts, tts)) {
      _tts?.removeListener(_syncPlaybackState);
      _tts = tts;
      tts.addListener(_syncPlaybackState);
    }
    _onPreviousChapter = onPreviousChapter;
    _onNextChapter = onNextChapter;
    _syncPlaybackState();
  }

  void detach(TTSService tts) {
    if (!identical(_tts, tts)) return;
    tts.removeListener(_syncPlaybackState);
    _tts = null;
    _onPreviousChapter = null;
    _onNextChapter = null;
    _hasPreviousChapter = false;
    _hasNextChapter = false;
    _completionTimer?.cancel();
    _completionTimer = null;
    mediaItem.add(null);
    _publishIdle();
  }

  void updateChapter({
    required int bookId,
    required int chapterId,
    required String bookTitle,
    required String chapterTitle,
    String? author,
    required bool hasPreviousChapter,
    required bool hasNextChapter,
  }) {
    _hasPreviousChapter = hasPreviousChapter;
    _hasNextChapter = hasNextChapter;
    final normalizedBookTitle = bookTitle.trim();
    final normalizedChapterTitle = chapterTitle.trim();
    final normalizedAuthor = author?.trim();
    mediaItem.add(
      MediaItem(
        id: '$bookId:$chapterId',
        title: normalizedChapterTitle.isEmpty ? '当前章节' : normalizedChapterTitle,
        album: normalizedBookTitle.isEmpty ? '芸窗' : normalizedBookTitle,
        artist: normalizedAuthor == null || normalizedAuthor.isEmpty
            ? null
            : normalizedAuthor,
        genre: '有声阅读',
      ),
    );
    _syncPlaybackState();
  }

  @override
  Future<void> play() async {
    final tts = _tts;
    if (tts == null) return;
    _completionTimer?.cancel();
    if (tts.isPaused) {
      await tts.resume();
    } else if (tts.currentText.isNotEmpty && tts.progress < 1) {
      await tts.play(tts.currentText, tts.progress);
    }
  }

  @override
  Future<void> pause() async {
    final tts = _tts;
    if (tts?.isPlaying == true) {
      await tts!.pause();
    }
  }

  @override
  Future<void> stop() async {
    _completionTimer?.cancel();
    _completionTimer = null;
    final tts = _tts;
    if (tts != null) {
      await tts.stop();
    }
    _publishIdle();
  }

  @override
  Future<void> skipToPrevious() async {
    if (!_hasPreviousChapter) return;
    await _onPreviousChapter?.call();
  }

  @override
  Future<void> skipToNext() async {
    if (!_hasNextChapter) return;
    await _onNextChapter?.call();
  }

  @override
  Future<void> onNotificationDeleted() => stop();

  void _syncPlaybackState() {
    final tts = _tts;
    if (tts == null || tts.currentText.isEmpty) {
      _publishIdle();
      return;
    }

    _completionTimer?.cancel();
    _completionTimer = null;

    switch (tts.status) {
      case TTSStatus.initializing:
        _publishState(
          processingState: AudioProcessingState.loading,
          playing: false,
        );
        return;
      case TTSStatus.playing:
        _publishState(
          processingState: AudioProcessingState.ready,
          playing: true,
        );
        return;
      case TTSStatus.paused:
        _publishState(
          processingState: AudioProcessingState.ready,
          playing: false,
        );
        return;
      case TTSStatus.error:
        _publishState(
          processingState: AudioProcessingState.error,
          playing: false,
          errorMessage: tts.lastError,
        );
        return;
      case TTSStatus.ready:
        if (tts.progress <= 0) {
          _publishIdle();
          return;
        }
        _publishState(
          processingState: AudioProcessingState.ready,
          playing: false,
        );
        if (tts.progress >= 1) {
          _completionTimer = Timer(
            const Duration(milliseconds: 750),
            _publishIdle,
          );
        }
    }
  }

  void _publishState({
    required AudioProcessingState processingState,
    required bool playing,
    String? errorMessage,
  }) {
    final controls = <MediaControl>[];
    if (_hasPreviousChapter) {
      controls.add(MediaControl.skipToPrevious);
    }
    controls.add(playing ? MediaControl.pause : MediaControl.play);
    if (_hasNextChapter) {
      controls.add(MediaControl.skipToNext);
    }
    controls.add(MediaControl.stop);

    final compactIndices = <int>[
      for (var index = 0; index < controls.length; index++)
        if (controls[index].action != MediaAction.stop) index,
    ].take(3).toList(growable: false);

    playbackState.add(
      PlaybackState(
        controls: controls,
        androidCompactActionIndices: compactIndices,
        processingState: processingState,
        playing: playing,
        errorMessage: errorMessage,
      ),
    );
  }

  void _publishIdle() {
    playbackState.add(
      PlaybackState(
        processingState: AudioProcessingState.idle,
        playing: false,
      ),
    );
  }
}
