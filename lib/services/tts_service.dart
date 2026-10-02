import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:audio_session/audio_session.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tts/flutter_tts.dart';

import '../models/tts_highlight.dart';
import '../providers/preferences_provider.dart';
import '../utils/sentence_splitter.dart';
import 'external_tts.dart';

final ttsServiceProvider = ChangeNotifierProvider<TTSService>((ref) {
  final preferences = ref.watch(sharedPreferencesProvider);
  final service = TTSService(
    initialSpeechRate: preferences.getDouble(TTSService.speechRateStorageKey),
    persistSpeechRate: (rate) async {
      await preferences.setDouble(TTSService.speechRateStorageKey, rate);
    },
    externalSettings: ref.read(externalTtsSettingsProvider),
  );
  // 只 listen 不 watch：改外部语音设置不该把整个朗读服务重建一遍。
  ref.listen<ExternalTtsSettings>(
    externalTtsSettingsProvider,
    (_, settings) => unawaited(service.configureExternal(settings)),
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

/// 系统自带的语音引擎，或用户配置的外部语音服务（[ExternalTtsSettings]）。
enum TTSEngine { system, external }

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

  /// 一次交给引擎的最长字数。按段落读，段落太长再在句末切开。每读完一段
  /// 引擎都会回调，正文高亮、朗读进度、断点续读都靠这个回调——很多系统
  /// 引擎不报逐词进度，只有它是可靠的。段落越短，高亮和进度跟得越紧。
  static const _maxUnitLength = 300;

  /// 长段落切开时，每一截至少这么长，免得切出一串零碎的短句。
  static const _minUnitLength = 120;

  /// 比这短的段落（对话、短句）和后面的短段落并成一个单位，合起来不超过
  /// [_maxGroupLength]。
  static const _shortParagraphLength = 30;
  static const _maxGroupLength = 80;

  final FlutterTts _tts;
  final FutureOr<void> Function(double rate)? _persistSpeechRate;
  Future<void>? _initialization;
  TTSStatus _status = TTSStatus.initializing;

  final SpeechSynthesizer Function(ExternalTtsSettings settings)
      _createSynthesizer;
  final SpeechAudioPlayer Function() _createAudioPlayer;
  ExternalTtsSettings _externalSettings;
  SpeechSynthesizer? _synthesizer;
  SpeechAudioPlayer? _audioPlayer;
  StreamSubscription<void>? _audioCompletion;
  StreamSubscription<void>? _audioInterruption;

  /// 每次停下、换位置都加一。合成请求回来时编号对不上，说明用户已经
  /// 停了或者跳走了，这段音频作废。
  int _externalRequest = 0;

  /// 播放器里有这一段的音频：暂停后接着播就行，不用重新合成。
  bool _externalAudioLoaded = false;

  /// 合成过和正在预取的音频，按（文字，倍速）存。只留最近几段。
  final Map<(String, double), Future<Uint8List>> _audioCache = {};
  double _speechRate;
  String _language = 'zh-CN';
  String _defaultLanguage = 'zh-CN';
  List<String> _availableLanguages = const [];
  List<TTSVoice> _availableVoices = const [];
  TTSVoice? _voice;
  String? _lastError;
  bool _disposed = false;
  bool _ignoreCancel = false;

  /// 进度条显示的比例。拖动进度条时先变它，松手才真正跳过去。
  double _progress = 0;

  /// 读到哪个字了：正在读的那一段的开头，引擎报逐词进度时是正在读的字。
  int _offset = 0;
  String _currentText = '';
  _SpeechUnit? _currentUnit;
  List<SentenceSpan>? _sentences;

  /// 朗读单位要在这些位置之前的句末断开，翻页模式下是各页的开头。
  String _breaksText = '';
  List<int> _breaks = const [];

  TtsHighlight? _highlight;

  /// 正在读的位置变了：换到下一段、引擎报到下一句，或者停下来（null）。
  void Function(TtsHighlight? highlight)? onHighlightChanged;
  FutureOr<void> Function()? onContentCompleted;

  Timer? _sleepTimer;
  StreamSubscription<void>? _becomingNoisySubscription;
  TTSSleepTimerOption _sleepTimerOption = TTSSleepTimerOption.off;
  TTSSleepTimerOption _preferredSleepTimerOption = TTSSleepTimerOption.off;
  DateTime? _sleepTimerDeadline;

  TTSEngine get engine =>
      _externalSettings.isActive ? TTSEngine.external : TTSEngine.system;
  bool get usesExternalEngine => engine == TTSEngine.external;
  ExternalTtsSettings get externalSettings => _externalSettings;
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
  int get currentOffset => _offset;
  TtsHighlight? get highlight => _highlight;
  TTSSleepTimerOption get sleepTimerOption => _sleepTimerOption;
  TTSSleepTimerOption get preferredSleepTimerOption =>
      _preferredSleepTimerOption;
  DateTime? get sleepTimerDeadline => _sleepTimerDeadline;

  TTSService({
    FlutterTts? flutterTts,
    double? initialSpeechRate,
    FutureOr<void> Function(double rate)? persistSpeechRate,
    ExternalTtsSettings externalSettings = const ExternalTtsSettings(),
    SpeechSynthesizer Function(ExternalTtsSettings settings)? createSynthesizer,
    SpeechAudioPlayer Function()? createAudioPlayer,
  })  : _tts = flutterTts ?? FlutterTts(),
        _speechRate = normalizeSpeechRate(initialSpeechRate),
        _persistSpeechRate = persistSpeechRate,
        _externalSettings = externalSettings,
        _createSynthesizer = createSynthesizer ?? OpenAiSpeechSynthesizer.new,
        _createAudioPlayer = createAudioPlayer ?? FileSpeechAudioPlayer.new {
    _installHandlers();
    if (externalSettings.isActive) {
      _synthesizer = _createSynthesizer(externalSettings);
      _status = TTSStatus.ready;
    }
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
      final unit = _currentUnit;
      if (unit == null || _status != TTSStatus.playing) return;
      final offset =
          (unit.start + startOffset).clamp(unit.start, unit.end).toInt();
      _setOffset(offset);
      // 引擎报了读到哪个字，就在段落里再标出正在读的那一句。
      final sentences = _sentences ??= SentenceSplitter.split(_currentText);
      final index = SentenceSplitter.findSentenceIndex(sentences, offset);
      if (index >= 0) {
        final sentence = sentences[index];
        _setHighlight(
          TtsHighlight(
            unit.start,
            unit.end,
            sentenceStart: math.max(sentence.startOffset, unit.start),
            sentenceEnd: math.min(sentence.endOffset, unit.end),
          ),
        );
      }
      _notify();
    });
  }

  /// 初始化系统引擎。外部语音服务在用时照样初始化（换回系统引擎时要用），
  /// 但不动朗读状态——那是外部服务的。
  Future<void> _initialize() async {
    if (!usesExternalEngine) {
      _status = TTSStatus.initializing;
      _lastError = null;
      _notify();
    }
    final error = await _initializeSystemEngine();
    if (usesExternalEngine) return;
    if (error != null) {
      _setError(error);
    } else {
      _status = TTSStatus.ready;
      _notify();
    }
  }

  /// 成功返回 null，失败返回给用户看的原因。
  Future<String?> _initializeSystemEngine() async {
    try {
      final languages = await _tts.getLanguages;
      _availableLanguages = _parseLanguages(languages);
      final initialLanguage = _selectChineseLanguage(languages) ??
          (_availableLanguages.isEmpty ? null : _availableLanguages.first);
      if (initialLanguage == null) {
        return '系统语音引擎没有返回可用语言，请先安装系统 TTS 语音。';
      }
      _language = initialLanguage;
      _defaultLanguage = initialLanguage;
      _voice = null;

      if (Platform.isAndroid) {
        final available = await _tts.isLanguageAvailable(_language);
        if (available != true && available != 1) {
          return '系统 TTS 引擎不支持语音：$_language';
        }
      }

      await _tts.setLanguage(_language);
      await _tts.setSpeechRate(_speechRate);
      await _tts.setVolume(1);
      await _tts.setPitch(1);
      await _loadVoices();
      return null;
    } catch (error) {
      return 'TTS 初始化失败：$error';
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
    if (usesExternalEngine) {
      // 外部服务没有要初始化的东西；上一次请求失败留下的错误状态，重试时清掉。
      if (!isReady) {
        _status = TTSStatus.ready;
        _lastError = null;
        _notify();
      }
      return true;
    }
    if (isReady) return true;
    if (retry || _initialization == null) {
      _initialization = _initialize();
    }
    await _initialization;
    return isReady;
  }

  /// 朗读 [text] 时，跨过 [offsets] 里任一位置的段落在它前面的最后一个句末
  /// 断开。翻页模式传各页的开头：没有逐词进度的引擎读完一段才回调一次，
  /// 一段跨两页的话，读到下一页的内容时高亮和翻页还停在上一页。
  ///
  /// 只对还没开始读的段落生效；[text] 和正在读的文本不同时，留着等它开始读。
  void setSpeechBreaks(String text, List<int> offsets) {
    _breaksText = text;
    _breaks = List.unmodifiable(offsets.toList()..sort());
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

  /// 换外部语音服务的设置。正在读就先停下，下一次朗读按新设置来；关掉或
  /// 没填全就回到系统引擎。
  Future<void> configureExternal(ExternalTtsSettings settings) async {
    if (settings == _externalSettings) return;
    // 先换设置再 await：设置页保存时 provider 的监听和设置页自己都会调到
    // 这里，后到的那次要能看出设置已经换过了。
    final wasExternal = usesExternalEngine;
    final wasSpeaking = isPlaying || isPaused;
    _externalSettings = settings;
    _audioCache.clear();
    _synthesizer = settings.isActive ? _createSynthesizer(settings) : null;
    if (wasSpeaking) await stop();
    if (usesExternalEngine) {
      _status = TTSStatus.ready;
      _lastError = null;
      _notify();
    } else if (wasExternal) {
      // 系统引擎的状态在用外部服务期间没有显示过，重新检测一遍。
      _initialization = _initialize();
      await _initialization;
    }
  }

  /// 从比例 [startProgress] 处开始读。比例换算出的位置多半在句子中间，
  /// 退到那一句的句首。进度条拖动、前进后退用它。
  Future<bool> play(String text, [double startProgress = 0]) async {
    final progress = startProgress.clamp(0.0, 1.0);
    final offset = (text.length * progress).floor();
    return _playFromOffset(
      text,
      offset <= 0 ? 0 : SentenceSplitter.sentenceStartAt(text, offset),
    );
  }

  /// 从字符 [startOffset] 处开始读，不做调整。选中文字朗读、断点续读用它。
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
      await _haltExternalAudio();
      await _tts.stop();

      if (text != _currentText) _sentences = null;
      _currentText = text;
      _lastError = null;
      final normalizedOffset = startOffset.clamp(0, text.length).toInt();
      final unit = _unitFrom(normalizedOffset);
      if (unit == null) {
        _ignoreCancel = false;
        _currentUnit = null;
        _setOffset(normalizedOffset);
        _setError('当前位置之后没有可朗读的文字。');
        return false;
      }
      _status = TTSStatus.playing;
      final started = await _speakUnit(unit);
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

  /// 从 [position] 起的下一个朗读单位：一个段落，太长就在句末切开；对话
  /// 这类很短的段落连着几段并成一个。跳过只有空白或标点的段落——单独交给
  /// 引擎，有的会念出「星号星号」。
  _SpeechUnit? _unitFrom(int position) {
    final text = _currentText;
    var start = position;
    while (start < text.length) {
      var paragraphEnd = text.indexOf('\n', start);
      if (paragraphEnd < 0) paragraphEnd = text.length;
      final end = _unitEnd(text, start, paragraphEnd);
      final range = _trimBlank(text, start, end);
      if (range != null && _hasSpeakableText(text, range.start, range.end)) {
        final unitEnd = end == paragraphEnd
            ? _groupShortParagraphs(text, range.start, range.end)
            : range.end;
        return _SpeechUnit(
          range.start,
          unitEnd,
          text.substring(range.start, unitEnd),
        );
      }
      start = end < paragraphEnd ? end : paragraphEnd + 1;
    }
    return null;
  }

  /// 去掉 [start, end) 两头的空白；全是空白返回 null。
  ({int start, int end})? _trimBlank(String text, int start, int end) {
    var from = start;
    var to = end;
    while (from < to && SentenceSplitter.isBlank(text.codeUnitAt(from))) {
      from++;
    }
    while (to > from && SentenceSplitter.isBlank(text.codeUnitAt(to - 1))) {
      to--;
    }
    return to > from ? (start: from, end: to) : null;
  }

  /// 这一单位读到段尾而且很短时，把后面紧跟着的短段落并进来。对话多的章节
  /// 一行一停，系统引擎每段都有起读的停顿，外部服务每段一个请求，几十行
  /// 对话就是几十个请求。并到总长 [_maxGroupLength] 为止；遇到长段落、
  /// 只有标点的分隔行、下一页的开头都停。
  int _groupShortParagraphs(String text, int unitStart, int unitEnd) {
    if (unitEnd - unitStart >= _shortParagraphLength) return unitEnd;
    final pageBreak = _breaksApply(text) ? _firstBreakAfter(unitStart) : null;
    var end = unitEnd;
    var newline = text.indexOf('\n', unitEnd);
    while (newline >= 0) {
      var nextEnd = text.indexOf('\n', newline + 1);
      if (nextEnd < 0) nextEnd = text.length;
      final next = _trimBlank(text, newline + 1, nextEnd);
      if (next != null) {
        if (next.end - next.start >= _shortParagraphLength ||
            next.end - unitStart > _maxGroupLength ||
            (pageBreak != null && next.end > pageBreak) ||
            !_hasSpeakableText(text, next.start, next.end)) {
          break;
        }
        end = next.end;
      }
      newline = nextEnd < text.length ? nextEnd : -1;
    }
    return end;
  }

  bool _breaksApply(String text) =>
      identical(text, _breaksText) || text == _breaksText;

  /// 从 [start] 开始的这一单位在哪里结束，不超过段尾 [paragraphEnd]。
  int _unitEnd(String text, int start, int paragraphEnd) {
    var limit = paragraphEnd;
    final pageBreak = _breaksApply(text) ? _firstBreakAfter(start) : null;
    if (pageBreak != null && pageBreak < limit) {
      // 段落跨页：在下一页开头之前的最后一个句末断开。开头这句本身就跨页
      // 的话，单独读完这一句就断，下一单位从新的一页开始。
      limit = _lastSentenceCut(text, start + 1, pageBreak, paragraphEnd) ??
          _firstSentenceCut(text, pageBreak, paragraphEnd) ??
          limit;
    }
    if (limit - start <= _maxUnitLength) return limit;

    final hardLimit = start + _maxUnitLength;
    final minimum = start + _minUnitLength;
    final sentenceCut = _lastSentenceCut(text, minimum, hardLimit, limit);
    if (sentenceCut != null) return sentenceCut;
    for (var index = hardLimit; index > minimum; index--) {
      if (_isClauseEnd(text.codeUnitAt(index - 1))) return index;
    }
    // 实在没有标点就硬切，但别把代理对切成两半。
    final last = text.codeUnitAt(hardLimit - 1);
    return last >= 0xD800 && last <= 0xDBFF ? hardLimit - 1 : hardLimit;
  }

  /// (from, to] 里最后一个句末标点之后的位置，连带紧跟的收尾引号括号，
  /// 不超过 [limit]。没有就返回 null。
  int? _lastSentenceCut(String text, int from, int to, int limit) {
    for (var index = to; index > from; index--) {
      if (!SentenceSplitter.isSentenceEnd(text.codeUnitAt(index - 1))) {
        continue;
      }
      var end = index;
      while (end < limit && _isClosingMark(text.codeUnitAt(end))) {
        end++;
      }
      return end;
    }
    return null;
  }

  /// [from] 之后第一个句末标点之后的位置，规则同 [_lastSentenceCut]。
  int? _firstSentenceCut(String text, int from, int limit) {
    for (var index = from; index < limit; index++) {
      if (!SentenceSplitter.isSentenceEnd(text.codeUnitAt(index))) continue;
      var end = index + 1;
      while (end < limit && _isClosingMark(text.codeUnitAt(end))) {
        end++;
      }
      return end;
    }
    return null;
  }

  int? _firstBreakAfter(int position) {
    var low = 0;
    var high = _breaks.length;
    while (low < high) {
      final middle = (low + high) >> 1;
      if (_breaks[middle] <= position) {
        low = middle + 1;
      } else {
        high = middle;
      }
    }
    return low < _breaks.length ? _breaks[low] : null;
  }

  static bool _isClosingMark(int codeUnit) =>
      !SentenceSplitter.isBlank(codeUnit) &&
      SentenceSplitter.isSentenceTrailer(codeUnit);

  static bool _isClauseEnd(int codeUnit) =>
      codeUnit == 0xFF0C || // ，
      codeUnit == 0x3001 || // 、
      codeUnit == 0xFF1B || // ；
      codeUnit == 0xFF1A || // ：
      codeUnit == 0x2C || // ,
      codeUnit == 0x3B || // ;
      codeUnit == 0x3A || // :
      codeUnit == 0x2026 || // …
      codeUnit == 0x20;

  /// 有没有字母、数字或汉字这类念得出来的字符。标点、符号、空白都不算。
  static bool _hasSpeakableText(String text, int start, int end) {
    for (var index = start; index < end; index++) {
      final codeUnit = text.codeUnitAt(index);
      if (codeUnit < 0x80) {
        if ((codeUnit >= 0x30 && codeUnit <= 0x39) ||
            (codeUnit >= 0x41 && codeUnit <= 0x5A) ||
            (codeUnit >= 0x61 && codeUnit <= 0x7A)) {
          return true;
        }
        continue;
      }
      // 标点和分隔用的符号（※ ◆ ★ ── 之类），罗马数字、带圈数字不算。
      final isPunctuation = (codeUnit >= 0x2000 && codeUnit <= 0x206F) ||
          (codeUnit >= 0x2190 && codeUnit <= 0x21FF) ||
          (codeUnit >= 0x2500 && codeUnit <= 0x27BF) ||
          (codeUnit >= 0x2B00 && codeUnit <= 0x2BFF) ||
          (codeUnit >= 0x3000 && codeUnit <= 0x3004) ||
          (codeUnit >= 0x3008 && codeUnit <= 0x303F) ||
          (codeUnit >= 0xFE30 && codeUnit <= 0xFE4F) ||
          (codeUnit >= 0xFF00 && codeUnit <= 0xFF0F) ||
          (codeUnit >= 0xFF1A && codeUnit <= 0xFF20) ||
          (codeUnit >= 0xFF3B && codeUnit <= 0xFF40) ||
          (codeUnit >= 0xFF5B && codeUnit <= 0xFF65) ||
          codeUnit == 0xA0 ||
          codeUnit == 0xFEFF;
      if (!isPunctuation) return true;
    }
    return false;
  }

  Future<bool> _speakUnit(_SpeechUnit unit) async {
    _currentUnit = unit;
    _setOffset(unit.start);
    _setHighlight(TtsHighlight(unit.start, unit.end));
    _notify();
    if (usesExternalEngine) return _speakExternal(unit);
    final result = Platform.isAndroid
        ? await _tts.speak(unit.text, focus: true)
        : await _tts.speak(unit.text);
    if (result != 1) {
      _setError('系统 TTS 引擎拒绝了朗读请求，请检查系统语音引擎设置。');
      return false;
    }
    return true;
  }

  /// 外部语音服务：合成这一段、播放，同时预取下一段，段与段之间不用干等
  /// 网络。播完由播放器的完成事件接到 [_handleChunkCompleted]，和系统
  /// 引擎走同一条路。
  Future<bool> _speakExternal(_SpeechUnit unit) async {
    final request = ++_externalRequest;
    final speed = _externalSpeed;
    try {
      final audio = await _synthesize(unit.text, speed);
      // 等合成的时候用户停了、跳走了，或者暂停了：这段先不播。暂停的话
      // 音频还在缓存里，接着读时直接拿。
      if (request != _externalRequest || _status != TTSStatus.playing) {
        return true;
      }
      final player = _audioPlayer ??= _createAudioPlayer();
      _audioCompletion ??= player.onCompleted.listen((_) {
        // 停止、换位置时 _haltExternalAudio 先清了标记，那时的完成事件不算
        // 读完一段。
        if (!_externalAudioLoaded) return;
        _externalAudioLoaded = false;
        unawaited(_handleChunkCompleted());
      });
      // 播放器自己停下了（Android 上被别的应用抢走音频焦点）：状态跟着改成
      // 暂停，不然界面一直显示在读，其实没声音。音频还在，接着读直接续播。
      _audioInterruption ??= player.onInterrupted.listen((_) {
        if (_status != TTSStatus.playing || !_externalAudioLoaded) return;
        _status = TTSStatus.paused;
        _notify();
      });
      // 标记要在 play() 之前打上：很短的一段可能 play() 还没返回就播完了。
      _externalAudioLoaded = true;
      try {
        await player.play(audio);
      } catch (_) {
        _externalAudioLoaded = false;
        rethrow;
      }
      // play() 期间被停掉或换了新的一段：播放器现在归新的请求管，这里什么
      // 都别动。停掉的那种 audioplayers 自己不会再出声（stop 把 desiredState
      // 改成了 stopped）；这里再 stop 一次反而会把新请求刚开始的播放掐掉。
      if (request != _externalRequest) return true;
      final next = _unitFrom(unit.end);
      if (next != null) unawaited(_synthesize(next.text, speed).then((_) {}));
      return true;
    } catch (error) {
      if (request != _externalRequest) return false;
      _setError(
        error is ExternalTtsException ? error.message : '外部语音服务出错：$error',
      );
      return false;
    }
  }

  /// 外部服务的倍速：应用里 0.5 是正常语速，接口里 1 是正常。OpenAI 接受
  /// 0.25 到 4。
  double get _externalSpeed => (_speechRate * 2).clamp(0.25, 4.0).toDouble();

  Future<Uint8List> _synthesize(String text, double speed) {
    final key = (text, speed);
    final cached = _audioCache[key];
    if (cached != null) return cached;
    final synthesizer = _synthesizer;
    if (synthesizer == null) {
      return Future.error(const ExternalTtsException('外部语音服务没有配置好。'));
    }
    final audio = synthesizer.synthesize(text, speed: speed);
    _audioCache[key] = audio;
    while (_audioCache.length > 4) {
      _audioCache.remove(_audioCache.keys.first);
    }
    // 预取的请求失败了没人等它，挂一个处理，别让它变成未捕获的异常；
    // 失败的也不留在缓存里，下次重新请求。
    unawaited(
      audio.then<void>((_) {}, onError: (Object _) {
        if (identical(_audioCache[key], audio)) _audioCache.remove(key);
      }),
    );
    return audio;
  }

  /// 停掉外部服务正在放的和正在合成的。
  Future<void> _haltExternalAudio() async {
    _externalRequest++;
    _externalAudioLoaded = false;
    await _audioPlayer?.stop();
  }

  Future<void> _handleChunkCompleted() async {
    if (_status != TTSStatus.playing) return;
    final current = _currentUnit;
    final next = current == null ? null : _unitFrom(current.end);
    if (next != null) {
      await _speakUnit(next);
      return;
    }
    _currentUnit = null;
    _setOffset(_currentText.length);
    _status = TTSStatus.ready;
    _setHighlight(null);
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
    await _haltExternalAudio();
    _ignoreCancel = true;
    await _tts.stop();
    _ignoreCancel = false;
    _status = isReady ? TTSStatus.ready : _status;
    _currentUnit = null;
    _setOffset(0);
    _setHighlight(null);
    if (cancelSleepTimer) {
      _clearSleepTimerState();
    }
    _notify();
  }

  /// 暂停后接着读、换了声音语速重读时的起点：正在读的那一句的句首，但不
  /// 早于这一段的开头。没有逐词进度时就是这一段的开头。
  int _restartOffset() {
    final unitStart = _currentUnit?.start ?? _offset;
    final sentenceStart = SentenceSplitter.sentenceStartAt(
      _currentText,
      _offset,
    );
    return math.max(unitStart, sentenceStart);
  }

  void _setOffset(int offset) {
    final length = _currentText.length;
    _offset = offset.clamp(0, length).toInt();
    _progress = length == 0 ? 0 : _offset / length;
  }

  void _setHighlight(TtsHighlight? highlight) {
    if (_highlight == highlight) return;
    _highlight = highlight;
    onHighlightChanged?.call(highlight);
  }

  Future<void> pause() async {
    if (usesExternalEngine) {
      await _audioPlayer?.pause();
      _status = TTSStatus.paused;
      _notify();
      return;
    }
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
    // 外部服务的音频还在播放器里，原地接着放，不用重新合成。
    if (usesExternalEngine && _externalAudioLoaded) {
      _status = TTSStatus.playing;
      _notify();
      await _audioPlayer!.resume();
      return true;
    }
    return _playFromOffset(_currentText, _restartOffset());
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
      await _playFromOffset(_currentText, _restartOffset());
    }
  }

  /// 拖动进度条时只改显示，松手后由调用方从新位置开始读。
  void updateProgressUI(double newProgress) {
    _progress = newProgress.clamp(0.0, 1.0);
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
    _setHighlight(null);
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
    onHighlightChanged = null;
    onContentCompleted = null;
    unawaited(_tts.stop());
    _externalRequest++;
    unawaited(_audioCompletion?.cancel());
    unawaited(_audioInterruption?.cancel());
    unawaited(_audioPlayer?.dispose());
    super.dispose();
  }
}

/// 一次交给引擎朗读的文字，[start]、[end] 是它在整章文本里的位置。
class _SpeechUnit {
  final int start;
  final int end;
  final String text;

  const _SpeechUnit(this.start, this.end, this.text);
}
