import 'dart:async';
import 'dart:io';

import 'package:audio_session/audio_session.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tts/flutter_tts.dart';

import '../providers/preferences_provider.dart';
import '../utils/sentence_splitter.dart';

final ttsServiceProvider = ChangeNotifierProvider<TTSService>((ref) {
  final preferences = ref.watch(sharedPreferencesProvider);
  final service = TTSService(
    initialSpeechRate: preferences.getDouble(TTSService.speechRateStorageKey),
    persistSpeechRate: (rate) async {
      await preferences.setDouble(TTSService.speechRateStorageKey, rate);
    },
  );
  unawaited(_attachAudioDisconnectListener(service));
  return service;
});

Future<void> _attachAudioDisconnectListener(TTSService service) async {
  try {
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.speech());
    service.attachBecomingNoisyEvents(session.becomingNoisyEventStream);
  } catch (_) {
    // TTS remains usable when audio session events are unavailable.
  }
}

enum TTSEngine { system, ai }

enum TTSStatus { initializing, ready, playing, paused, error }

enum TTSSleepTimerOption {
  off,
  minutes15,
  minutes30,
  minutes60,
  endOfChapter,
}

TTSSleepTimerOption ttsSleepTimerOptionFromStorage(String? value) {
  return TTSSleepTimerOption.values.firstWhere(
    (option) => option.name == value,
    orElse: () => TTSSleepTimerOption.off,
  );
}

@immutable
class TTSVoice {
  final String name;
  final String locale;

  const TTSVoice({required this.name, required this.locale});

  static List<TTSVoice> parseList(dynamic values) {
    if (values is! Iterable) return const [];
    final voices = <TTSVoice>[];
    final seen = <String>{};
    for (final value in values) {
      if (value is! Map) continue;
      final name = value['name']?.toString().trim() ?? '';
      final locale = value['locale']?.toString().trim() ?? '';
      if (name.isEmpty || locale.isEmpty) continue;
      final key = '$name\u0000${locale.toLowerCase()}';
      if (seen.add(key)) {
        voices.add(TTSVoice(name: name, locale: locale));
      }
    }
    voices.sort((left, right) {
      final localeOrder =
          left.locale.toLowerCase().compareTo(right.locale.toLowerCase());
      return localeOrder != 0
          ? localeOrder
          : left.name.toLowerCase().compareTo(right.name.toLowerCase());
    });
    return List.unmodifiable(voices);
  }

  bool supportsLanguage(String language) =>
      _normalizeLocale(locale) == _normalizeLocale(language);

  Map<String, String> toPlatformMap() => {'name': name, 'locale': locale};

  @override
  bool operator ==(Object other) =>
      other is TTSVoice && other.name == name && other.locale == locale;

  @override
  int get hashCode => Object.hash(name, locale);
}

String _normalizeLocale(String value) =>
    value.trim().toLowerCase().replaceAll('_', '-');

class TTSService extends ChangeNotifier {
  static const speechRateStorageKey = 'ttsSpeechRate';
  static const defaultSpeechRate = 0.5;
  static const minSpeechRate = 0.1;
  static const maxSpeechRate = 1.0;
  static const _maxChunkLength = 3000;

  final FlutterTts _tts;
  final FutureOr<void> Function(double rate)? _persistSpeechRate;
  Future<void>? _initialization;
  TTSEngine _engine = TTSEngine.system;
  TTSStatus _status = TTSStatus.initializing;
  double _speechRate;
  String _language = 'zh-CN';
  String _defaultLanguage = 'zh-CN';
  List<String> _availableLanguages = const [];
  List<TTSVoice> _availableVoices = const [];
  TTSVoice? _voice;
  String? _lastError;
  bool _disposed = false;
  bool _ignoreCancel = false;

  double _progress = 0;
  String _currentText = '';
  int _currentBaseOffset = 0;
  List<_SpeechChunk> _speechChunks = const [];
  int _currentChunkIndex = 0;

  List<SentenceSpan> _currentSentences = [];
  int? _lastHighlightedSentence;
  void Function(int? sentenceIndex)? onSentenceChanged;
  FutureOr<void> Function()? onContentCompleted;

  Timer? _sleepTimer;
  StreamSubscription<void>? _becomingNoisySubscription;
  TTSSleepTimerOption _sleepTimerOption = TTSSleepTimerOption.off;
  TTSSleepTimerOption _preferredSleepTimerOption = TTSSleepTimerOption.off;
  DateTime? _sleepTimerDeadline;

  TTSEngine get engine => _engine;
  TTSStatus get status => _status;
  bool get isPlaying => _status == TTSStatus.playing;
  bool get isPaused => _status == TTSStatus.paused;
  bool get isReady =>
      _status == TTSStatus.ready ||
      _status == TTSStatus.playing ||
      _status == TTSStatus.paused;
  double get progress => _progress;
  double get speechRate => _speechRate;
  String get language => _language;
  String get defaultLanguage => _defaultLanguage;
  List<String> get availableLanguages => _availableLanguages;
  List<TTSVoice> get availableVoices => _availableVoices;
  TTSVoice? get voice => _voice;
  String? get lastError => _lastError;
  String get currentText => _currentText;
  int get currentOffset => (_currentText.length * _progress)
      .round()
      .clamp(0, _currentText.length)
      .toInt();
  TTSSleepTimerOption get sleepTimerOption => _sleepTimerOption;
  TTSSleepTimerOption get preferredSleepTimerOption =>
      _preferredSleepTimerOption;
  DateTime? get sleepTimerDeadline => _sleepTimerDeadline;

  TTSService({
    FlutterTts? flutterTts,
    double? initialSpeechRate,
    FutureOr<void> Function(double rate)? persistSpeechRate,
  })  : _tts = flutterTts ?? FlutterTts(),
        _speechRate = normalizeSpeechRate(initialSpeechRate),
        _persistSpeechRate = persistSpeechRate {
    _installHandlers();
    _initialization = _initialize();
  }

  static double normalizeSpeechRate(double? rate) {
    final value = rate ?? defaultSpeechRate;
    if (value.isNaN) return defaultSpeechRate;
    return value.clamp(minSpeechRate, maxSpeechRate).toDouble();
  }

  void _installHandlers() {
    _tts.setStartHandler(() {
      _status = TTSStatus.playing;
      _notify();
    });
    _tts.setCompletionHandler(() {
      unawaited(_handleChunkCompleted());
    });
    _tts.setCancelHandler(() {
      if (_ignoreCancel) return;
      _status = TTSStatus.ready;
      _notify();
    });
    _tts.setPauseHandler(() {
      _status = TTSStatus.paused;
      _notify();
    });
    _tts.setContinueHandler(() {
      _status = TTSStatus.playing;
      _notify();
    });
    _tts.setErrorHandler((message) {
      _setError('系统语音引擎错误：$message');
    });
    _tts.setProgressHandler((text, startOffset, endOffset, word) {
      if (_currentText.isEmpty) return;
      final globalOffset =
          (_currentBaseOffset + ((startOffset + endOffset) ~/ 2))
              .clamp(0, _currentText.length);
      _progress = globalOffset / _currentText.length;

      if (_currentSentences.isNotEmpty) {
        final index = SentenceSplitter.findSentenceIndex(
          _currentSentences,
          globalOffset,
        );
        if (index != -1 && index != _lastHighlightedSentence) {
          _lastHighlightedSentence = index;
          onSentenceChanged?.call(index);
        }
      }
      _notify();
    });
  }

  Future<void> _initialize() async {
    _status = TTSStatus.initializing;
    _lastError = null;
    _notify();
    try {
      final languages = await _tts.getLanguages;
      _availableLanguages = _parseLanguages(languages);
      final initialLanguage = _selectChineseLanguage(languages) ??
          (_availableLanguages.isEmpty ? null : _availableLanguages.first);
      if (initialLanguage == null) {
        _setError('系统语音引擎没有返回可用语言，请先安装系统 TTS 语音。');
        return;
      }
      _language = initialLanguage;
      _defaultLanguage = initialLanguage;
      _voice = null;

      if (Platform.isAndroid) {
        final available = await _tts.isLanguageAvailable(_language);
        if (available != true && available != 1) {
          _setError('系统 TTS 引擎不支持语音：$_language');
          return;
        }
      }

      await _tts.setLanguage(_language);
      await _tts.setSpeechRate(_speechRate);
      await _tts.setVolume(1);
      await _tts.setPitch(1);
      await _loadVoices();
      _status = TTSStatus.ready;
      _notify();
    } catch (error) {
      _setError('TTS 初始化失败：$error');
    }
  }

  String? _selectChineseLanguage(dynamic languages) {
    if (languages is! Iterable) return null;
    final values = languages.map((value) => value.toString()).toList();
    for (final preferred in ['zh-CN', 'zh_CN', 'cmn-CN', 'cmn_CN']) {
      final match = values.where(
        (value) => value.toLowerCase() == preferred.toLowerCase(),
      );
      if (match.isNotEmpty) return match.first;
    }
    for (final value in values) {
      final normalized = value.toLowerCase().replaceAll('_', '-');
      if (normalized.startsWith('zh') || normalized.startsWith('cmn')) {
        return value;
      }
    }
    return null;
  }

  List<String> _parseLanguages(dynamic languages) {
    if (languages is! Iterable) return const [];
    final values = <String>[];
    final seen = <String>{};
    for (final value in languages) {
      final language = value.toString().trim();
      if (language.isEmpty) continue;
      if (seen.add(_normalizeLocale(language))) values.add(language);
    }
    values.sort((left, right) =>
        _normalizeLocale(left).compareTo(_normalizeLocale(right)));
    return List.unmodifiable(values);
  }

  Future<void> _loadVoices() async {
    try {
      _availableVoices = TTSVoice.parseList(await _tts.getVoices);
    } catch (_) {
      _availableVoices = const [];
    }
  }

  Future<void> refreshCapabilities() async {
    if (!await ensureInitialized(retry: _status == TTSStatus.error)) return;
    try {
      _availableLanguages = _parseLanguages(await _tts.getLanguages);
    } catch (_) {
      // Keep the last successfully loaded language list.
    }
    await _loadVoices();
    _notify();
  }

  Future<bool> ensureInitialized({bool retry = false}) async {
    if (isReady) return true;
    if (retry || _initialization == null) {
      _initialization = _initialize();
    }
    await _initialization;
    return isReady;
  }

  void setCurrentContent(List<SentenceSpan> sentences) {
    _currentSentences = sentences;
    _lastHighlightedSentence = null;
  }

  void attachBecomingNoisyEvents(Stream<void> events) {
    if (_disposed) return;
    unawaited(_becomingNoisySubscription?.cancel());
    _becomingNoisySubscription = events.listen((_) {
      if (isPlaying) {
        unawaited(pause());
      }
    });
  }

  void setEngine(TTSEngine engine) {
    _engine = engine;
    notifyListeners();
  }

  Future<bool> play(String text, [double startProgress = 0]) async {
    final progress = startProgress.clamp(0, 1);
    return _playFromOffset(text, (text.length * progress).floor());
  }

  Future<bool> playFromOffset(String text, int startOffset) {
    return _playFromOffset(text, startOffset);
  }

  Future<bool> _playFromOffset(String text, int startOffset) async {
    if (text.trim().isEmpty) {
      _setError('当前章节没有可朗读的文字。');
      return false;
    }
    if (!await ensureInitialized(retry: _status == TTSStatus.error)) {
      return false;
    }

    try {
      _ignoreCancel = true;
      await _tts.stop();

      _currentText = text;
      final normalizedOffset = startOffset.clamp(0, text.length);
      _progress =
          text.isEmpty ? 0 : (normalizedOffset / text.length).clamp(0, 1);
      _speechChunks = _splitSpeech(text, normalizedOffset);
      _currentChunkIndex = 0;
      _lastError = null;
      if (_speechChunks.isEmpty) {
        _ignoreCancel = false;
        _setError('当前位置之后没有可朗读的文字。');
        return false;
      }
      _status = TTSStatus.playing;
      _notify();
      final started = await _speakCurrentChunk();
      // Reset only after speak() is issued, so a late cancel event from the
      // stop() above is ignored across the whole stop→speak window.
      _ignoreCancel = false;
      return started;
    } catch (error) {
      _ignoreCancel = false;
      _setError('无法开始朗读：$error');
      return false;
    }
  }

  List<_SpeechChunk> _splitSpeech(String text, int startOffset) {
    final chunks = <_SpeechChunk>[];
    var start = startOffset.clamp(0, text.length);
    while (start < text.length) {
      var end = start + _maxChunkLength;
      if (end > text.length) end = text.length;
      if (end < text.length) {
        final minimum = start + (_maxChunkLength * 0.6).floor();
        for (var index = end; index >= minimum; index--) {
          final char = text.codeUnitAt(index - 1);
          if (_isSpeechBoundary(char)) {
            end = index;
            break;
          }
        }
      }
      chunks.add(_SpeechChunk(start, text.substring(start, end)));
      start = end;
    }
    return chunks;
  }

  bool _isSpeechBoundary(int char) {
    return char == 0x0A ||
        char == 0x3002 ||
        char == 0xFF01 ||
        char == 0xFF1F ||
        char == 0x002E ||
        char == 0x0021 ||
        char == 0x003F;
  }

  Future<bool> _speakCurrentChunk() async {
    final chunk = _speechChunks[_currentChunkIndex];
    _currentBaseOffset = chunk.startOffset;
    final result = Platform.isAndroid
        ? await _tts.speak(chunk.text, focus: true)
        : await _tts.speak(chunk.text);
    if (result != 1) {
      _setError('系统 TTS 引擎拒绝了朗读请求，请检查系统语音引擎设置。');
      return false;
    }
    return true;
  }

  Future<void> _handleChunkCompleted() async {
    if (_status != TTSStatus.playing) return;
    if (_currentChunkIndex + 1 < _speechChunks.length) {
      _currentChunkIndex++;
      await _speakCurrentChunk();
      return;
    }
    _progress = 1;
    _status = TTSStatus.ready;
    _lastHighlightedSentence = null;
    onSentenceChanged?.call(null);
    final stopAtChapterEnd =
        _sleepTimerOption == TTSSleepTimerOption.endOfChapter;
    if (stopAtChapterEnd) {
      _clearSleepTimerState();
    }
    _notify();
    if (!stopAtChapterEnd) {
      await Future<void>.sync(() => onContentCompleted?.call());
    }
  }

  Future<void> stop({bool cancelSleepTimer = true}) async {
    _ignoreCancel = true;
    await _tts.stop();
    _ignoreCancel = false;
    _status = isReady ? TTSStatus.ready : _status;
    _progress = 0;
    _lastHighlightedSentence = null;
    onSentenceChanged?.call(null);
    if (cancelSleepTimer) {
      _clearSleepTimerState();
    }
    _notify();
  }

  Future<void> pause() async {
    final result = await _tts.pause();
    if (result == 1) {
      _status = TTSStatus.paused;
      _notify();
    } else {
      _setError('当前系统 TTS 引擎不支持暂停。');
    }
  }

  Future<bool> resume() async {
    if (!isPaused || _currentText.isEmpty) return false;
    return play(_currentText, _progress);
  }

  Future<void> setSpeechRate(double rate, {bool persist = true}) async {
    final normalizedRate = normalizeSpeechRate(rate);
    _speechRate = normalizedRate;
    if (persist) {
      unawaited(Future<void>.sync(() {
        return _persistSpeechRate?.call(normalizedRate);
      }));
    }
    if (await ensureInitialized()) {
      await _tts.setSpeechRate(normalizedRate);
    }
    _notify();
  }

  Future<void> applySpeechRate() async {
    await applyPlaybackSettings();
  }

  Future<void> applyPlaybackSettings() async {
    if (isPlaying && _currentText.isNotEmpty) {
      await play(_currentText, _progress);
    }
  }

  void updateProgressUI(double newProgress) {
    _progress = newProgress.clamp(0, 1);
    _notify();
  }

  Future<bool> setLanguage(String language) async {
    try {
      final previousStatus = _status;
      final result = await _tts.setLanguage(language);
      if (!_platformCallSucceeded(result)) return false;
      _language = language;
      if (_voice != null && !_voice!.supportsLanguage(language)) {
        _voice = null;
      }
      _status = previousStatus == TTSStatus.initializing ||
              previousStatus == TTSStatus.error
          ? TTSStatus.ready
          : previousStatus;
      _lastError = null;
      _notify();
      return true;
    } catch (error) {
      _setError('无法切换 TTS 语言：$error');
      return false;
    }
  }

  Future<dynamic> getLanguages() => _tts.getLanguages;

  Future<bool> setVoice(TTSVoice? voice) async {
    if (!await ensureInitialized(retry: _status == TTSStatus.error)) {
      return false;
    }
    try {
      if (voice == null) {
        final result = await _tts.setLanguage(_language);
        if (!_platformCallSucceeded(result)) return false;
        _voice = null;
      } else {
        final languageSet = await setLanguage(voice.locale);
        if (!languageSet) return false;
        final result = await _tts.setVoice(voice.toPlatformMap());
        if (!_platformCallSucceeded(result)) return false;
        _voice = voice;
      }
      _lastError = null;
      _notify();
      return true;
    } catch (error) {
      _setError('无法切换 TTS 声音：$error');
      return false;
    }
  }

  Future<void> resetBookOverrides({double? globalSpeechRate}) async {
    await setSpeechRate(globalSpeechRate ?? defaultSpeechRate, persist: false);
    if (await ensureInitialized(retry: _status == TTSStatus.error)) {
      await setLanguage(_defaultLanguage);
      _voice = null;
    }
    restoreSleepTimerPreference(TTSSleepTimerOption.off);
  }

  void restoreSleepTimerPreference(TTSSleepTimerOption option) {
    _clearSleepTimerState();
    _preferredSleepTimerOption = option;
    _notify();
  }

  void activatePreferredSleepTimer() {
    setSleepTimer(_preferredSleepTimerOption, updatePreference: false);
  }

  void setSleepTimer(
    TTSSleepTimerOption option, {
    bool updatePreference = true,
  }) {
    _sleepTimer?.cancel();
    _sleepTimer = null;
    _sleepTimerDeadline = null;
    _sleepTimerOption = option;
    if (updatePreference) {
      _preferredSleepTimerOption = option;
    }

    final duration = switch (option) {
      TTSSleepTimerOption.minutes15 => const Duration(minutes: 15),
      TTSSleepTimerOption.minutes30 => const Duration(minutes: 30),
      TTSSleepTimerOption.minutes60 => const Duration(minutes: 60),
      TTSSleepTimerOption.off || TTSSleepTimerOption.endOfChapter => null,
    };
    if (duration != null) {
      _sleepTimerDeadline = DateTime.now().add(duration);
      _sleepTimer = Timer(duration, () {
        _clearSleepTimerState();
        unawaited(stop(cancelSleepTimer: false));
      });
    }
    _notify();
  }

  void cancelSleepTimer() {
    if (_sleepTimerOption == TTSSleepTimerOption.off) return;
    _clearSleepTimerState();
    _notify();
  }

  void _clearSleepTimerState() {
    _sleepTimer?.cancel();
    _sleepTimer = null;
    _sleepTimerDeadline = null;
    _sleepTimerOption = TTSSleepTimerOption.off;
  }

  void _setError(String message) {
    _lastError = message;
    _status = TTSStatus.error;
    _lastHighlightedSentence = null;
    onSentenceChanged?.call(null);
    _notify();
  }

  bool _platformCallSucceeded(dynamic result) => result == 1 || result == true;

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _sleepTimer?.cancel();
    unawaited(_becomingNoisySubscription?.cancel());
    onSentenceChanged = null;
    onContentCompleted = null;
    unawaited(_tts.stop());
    super.dispose();
  }
}

class _SpeechChunk {
  final int startOffset;
  final String text;

  const _SpeechChunk(this.startOffset, this.text);
}
