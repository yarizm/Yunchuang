import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../providers/preferences_provider.dart';

/// 外部语音服务的设置，走 OpenAI 兼容的 `POST {baseUrl}/audio/speech`。
///
/// OpenAI、硅基流动这类云服务，openai-edge-tts、Kokoro-FastAPI 这类自己
/// 搭的服务，用的都是这个接口：传文字、模型、声音，回一段音频。
@immutable
class ExternalTtsSettings {
  const ExternalTtsSettings({
    this.enabled = false,
    this.baseUrl = '',
    this.apiKey = '',
    this.model = '',
    this.voice = '',
  });

  /// 偏好键都以 `externalTts` 开头：里面有 API Key，备份时整组排除（见
  /// BackupService 的 `_credentialKeyPrefixes`）。开关也放在这组里，免得
  /// 恢复出「开着外部朗读、地址却是空的」的半配置状态。
  static const keyPrefix = 'externalTts';
  static const enabledKey = '${keyPrefix}Enabled';
  static const baseUrlKey = '${keyPrefix}BaseUrl';
  static const apiKeyKey = '${keyPrefix}ApiKey';
  static const modelKey = '${keyPrefix}Model';
  static const voiceKey = '${keyPrefix}Voice';

  final bool enabled;
  final String baseUrl;
  final String apiKey;
  final String model;
  final String voice;

  factory ExternalTtsSettings.fromPreferences(SharedPreferences preferences) {
    return ExternalTtsSettings(
      enabled: preferences.getBool(enabledKey) ?? false,
      baseUrl: preferences.getString(baseUrlKey) ?? '',
      apiKey: preferences.getString(apiKeyKey) ?? '',
      model: preferences.getString(modelKey) ?? '',
      voice: preferences.getString(voiceKey) ?? '',
    );
  }

  /// 地址、模型、声音都填了才能用。API Key 可以空，自建服务通常不要。
  bool get isComplete =>
      _parsedBaseUrl != null &&
      model.trim().isNotEmpty &&
      voice.trim().isNotEmpty;

  /// 开着而且填全了：朗读改走外部服务。
  bool get isActive => enabled && isComplete;

  Uri? get _parsedBaseUrl {
    final uri = Uri.tryParse(baseUrl.trim());
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) return null;
    if (uri.scheme != 'http' && uri.scheme != 'https') return null;
    return uri;
  }

  /// 填的是服务的根地址（如 `https://api.openai.com/v1`），接口路径在后面拼。
  Uri get speechUri {
    final base = _parsedBaseUrl!;
    final path = base.path.endsWith('/')
        ? base.path.substring(0, base.path.length - 1)
        : base.path;
    return base.replace(path: '$path/audio/speech');
  }

  ExternalTtsSettings copyWith({
    bool? enabled,
    String? baseUrl,
    String? apiKey,
    String? model,
    String? voice,
  }) {
    return ExternalTtsSettings(
      enabled: enabled ?? this.enabled,
      baseUrl: baseUrl ?? this.baseUrl,
      apiKey: apiKey ?? this.apiKey,
      model: model ?? this.model,
      voice: voice ?? this.voice,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is ExternalTtsSettings &&
      other.enabled == enabled &&
      other.baseUrl == baseUrl &&
      other.apiKey == apiKey &&
      other.model == model &&
      other.voice == voice;

  @override
  int get hashCode => Object.hash(enabled, baseUrl, apiKey, model, voice);
}

class ExternalTtsSettingsNotifier extends Notifier<ExternalTtsSettings> {
  SharedPreferences get _preferences => ref.read(sharedPreferencesProvider);

  @override
  ExternalTtsSettings build() {
    return ExternalTtsSettings.fromPreferences(
      ref.watch(sharedPreferencesProvider),
    );
  }

  /// 存下来，返回实际存的那份（去掉了首尾空白）。
  Future<ExternalTtsSettings> save(ExternalTtsSettings settings) async {
    final trimmed = settings.copyWith(
      baseUrl: settings.baseUrl.trim(),
      apiKey: settings.apiKey.trim(),
      model: settings.model.trim(),
      voice: settings.voice.trim(),
    );
    await _preferences.setBool(ExternalTtsSettings.enabledKey, trimmed.enabled);
    await _preferences.setString(
      ExternalTtsSettings.baseUrlKey,
      trimmed.baseUrl,
    );
    await _preferences.setString(ExternalTtsSettings.apiKeyKey, trimmed.apiKey);
    await _preferences.setString(ExternalTtsSettings.modelKey, trimmed.model);
    await _preferences.setString(ExternalTtsSettings.voiceKey, trimmed.voice);
    state = trimmed;
    return trimmed;
  }
}

final externalTtsSettingsProvider =
    NotifierProvider<ExternalTtsSettingsNotifier, ExternalTtsSettings>(
  ExternalTtsSettingsNotifier.new,
);

/// 外部语音服务出错，[message] 直接给用户看。
class ExternalTtsException implements Exception {
  const ExternalTtsException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// 把一段文字合成成音频。
abstract class SpeechSynthesizer {
  /// [speed] 是播放倍速，1 为正常。
  Future<Uint8List> synthesize(String text, {required double speed});
}

/// 外部语音服务请求的超时。连接超时必须设：Dio 默认不设，地址填错、局域网
/// 那台机器没开时要等系统的 TCP 超时（Windows 约 21 秒，Android 可到两分钟），
/// 这期间朗读显示在读、却没有声音也没有报错。
BaseOptions externalTtsBaseOptions() => BaseOptions(
      connectTimeout: const Duration(seconds: 10),
      sendTimeout: const Duration(seconds: 20),
      receiveTimeout: const Duration(seconds: 60),
    );

/// OpenAI 兼容的 `/audio/speech`，要 mp3：Android 和 Windows 都能直接播。
class OpenAiSpeechSynthesizer implements SpeechSynthesizer {
  OpenAiSpeechSynthesizer(this.settings, {Dio? dio})
      : _dio = dio ?? Dio(externalTtsBaseOptions());

  final ExternalTtsSettings settings;
  final Dio _dio;

  @override
  Future<Uint8List> synthesize(String text, {required double speed}) async {
    final Response<List<int>> response;
    try {
      response = await _dio.postUri<List<int>>(
        settings.speechUri,
        data: {
          'model': settings.model.trim(),
          'input': text,
          'voice': settings.voice.trim(),
          'response_format': 'mp3',
          'speed': speed,
        },
        options: Options(
          responseType: ResponseType.bytes,
          contentType: Headers.jsonContentType,
          headers: {
            if (settings.apiKey.trim().isNotEmpty)
              'Authorization': 'Bearer ${settings.apiKey.trim()}',
          },
        ),
      );
    } on DioException catch (error) {
      throw ExternalTtsException(_describe(error));
    }

    final bytes = response.data;
    final contentType = response.headers.value(Headers.contentTypeHeader);
    // 有的兼容服务出错也回 200，正文是一段 JSON。
    if (contentType != null && contentType.contains('json')) {
      throw ExternalTtsException(
        '语音服务没有返回音频：${_serverMessage(bytes) ?? '未知错误'}',
      );
    }
    if (bytes == null || bytes.isEmpty) {
      throw const ExternalTtsException('语音服务返回了空的音频。');
    }
    return Uint8List.fromList(bytes);
  }

  static String _describe(DioException error) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
        return '连不上语音服务（连接超时），请检查地址和网络。';
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.transformTimeout:
        return '语音服务响应超时。';
      case DioExceptionType.badResponse:
        final status = error.response?.statusCode;
        final message = _serverMessage(error.response?.data);
        final hint = switch (status) {
          401 || 403 => 'API Key 无效或没有权限',
          404 => '地址或模型不对',
          429 => '请求太频繁或额度用完了',
          final code? when code >= 500 => '服务暂时异常，请稍后重试',
          _ => null,
        };
        return [
          '语音服务返回错误 $status',
          if (hint != null) hint,
          if (message != null) message,
        ].join('：');
      case DioExceptionType.connectionError:
        return '连不上语音服务，请检查地址和网络。';
      case DioExceptionType.badCertificate:
        return '语音服务的 HTTPS 证书无效。';
      case DioExceptionType.cancel:
        return '语音请求已取消。';
      case DioExceptionType.unknown:
        return '请求语音服务失败：${error.message ?? error.error}';
    }
  }

  /// 从错误响应里取出服务端给的说明：OpenAI 是 `{"error": {"message"}}`，
  /// 也有直接 `{"message"}` 或纯文本的。
  static String? _serverMessage(Object? data) {
    String? text;
    if (data is List<int>) {
      text = utf8.decode(data, allowMalformed: true);
    } else if (data is String) {
      text = data;
    }
    if (text == null || text.trim().isEmpty) return null;
    try {
      final decoded = jsonDecode(text);
      if (decoded is Map) {
        final error = decoded['error'];
        final message = error is Map ? error['message'] : decoded['message'];
        if (message != null) text = message.toString();
        if (error is String) text = error;
      }
    } on FormatException {
      // 不是 JSON，就用原文。
    }
    final trimmed = text!.trim();
    return trimmed.length > 200 ? '${trimmed.substring(0, 200)}…' : trimmed;
  }
}

/// 播放合成好的一段音频，播完从 [onCompleted] 通知。
abstract class SpeechAudioPlayer {
  Stream<void> get onCompleted;

  /// 播放器自己停下了，不是调用方叫停的（Android 上被别的应用抢走音频焦点）。
  Stream<void> get onInterrupted;
  Future<void> play(Uint8List audio);
  Future<void> pause();
  Future<void> resume();
  Future<void> stop();
  Future<void> dispose();
}

/// 用 audioplayers 播放。音频先写进临时文件再播：从内存直接播在 Windows 上
/// 不一定支持，文件哪个平台都行。
class FileSpeechAudioPlayer implements SpeechAudioPlayer {
  FileSpeechAudioPlayer() {
    _completion = _player.onPlayerComplete.listen((_) => _unwatch());
    if (Platform.isAndroid) {
      // 熄屏也要接着读：播放时保持 CPU 唤醒，合成下一段的请求才不会停住。
      // 设置失败只是少了这层保障，照样能播，记一笔日志。
      unawaited(
        _player
            .setAudioContext(
          AudioContext(
            android: const AudioContextAndroid(
              stayAwake: true,
              contentType: AndroidContentType.speech,
              usageType: AndroidUsageType.media,
              audioFocus: AndroidAudioFocus.gain,
            ),
          ),
        )
            .catchError((Object error, StackTrace stackTrace) {
          developer.log(
            'Failed to configure the external TTS audio context',
            name: 'tts.external',
            error: error,
            stackTrace: stackTrace,
          );
        }),
      );
    }
  }

  /// 轮流写这几个文件：正在播的那个不会被下一段覆盖。
  static const _fileCount = 3;

  final AudioPlayer _player = AudioPlayer();
  final _interrupted = StreamController<void>.broadcast();
  late final StreamSubscription<void> _completion;
  late final _watchdog = PlaybackStallWatchdog(
    readPosition: _player.getCurrentPosition,
    onStall: () {
      if (!_interrupted.isClosed) _interrupted.add(null);
    },
  );
  Directory? _directory;
  var _nextFile = 0;

  @override
  Stream<void> get onCompleted => _player.onPlayerComplete;

  @override
  Stream<void> get onInterrupted => _interrupted.stream;

  @override
  Future<void> play(Uint8List audio) async {
    final directory = _directory ??= await Directory(
      p.join((await getTemporaryDirectory()).path, 'tts_audio'),
    ).create(recursive: true);
    final file = File(p.join(directory.path, 'speech_$_nextFile.mp3'));
    _nextFile = (_nextFile + 1) % _fileCount;
    await file.writeAsBytes(audio, flush: true);
    await _player.play(DeviceFileSource(file.path, mimeType: 'audio/mpeg'));
    _watch();
  }

  @override
  Future<void> pause() {
    _unwatch();
    return _player.pause();
  }

  @override
  Future<void> resume() async {
    await _player.resume();
    _watch();
  }

  @override
  Future<void> stop() {
    _unwatch();
    return _player.stop();
  }

  @override
  Future<void> dispose() async {
    _unwatch();
    await _completion.cancel();
    await _interrupted.close();
    await _player.dispose();
  }

  /// audioplayers 在 Android 上丢了音频焦点会自己暂停，却不发任何事件，只能
  /// 看播放位置停没停。其他平台没有音频焦点这回事，不用看。
  void _watch() {
    if (Platform.isAndroid) _watchdog.start();
  }

  void _unwatch() => _watchdog.stop();
}

/// 播放期间定时看播放位置，连续 [stallTicks] 次没动就调一次 [onStall]，
/// 然后停止观察，等下次 [start]。
class PlaybackStallWatchdog {
  PlaybackStallWatchdog({
    required this.readPosition,
    required this.onStall,
    this.interval = const Duration(seconds: 1),
    this.stallTicks = 2,
  });

  final Future<Duration?> Function() readPosition;
  final VoidCallback onStall;
  final Duration interval;
  final int stallTicks;

  Timer? _timer;

  void start() {
    stop();
    Duration? last;
    var stalled = 0;
    var checking = false;
    late final Timer timer;
    timer = Timer.periodic(interval, (_) async {
      if (checking) return;
      checking = true;
      try {
        final position = await readPosition();
        // 已经停止观察，或者还在准备、位置还没开始走：不算停。
        if (!identical(_timer, timer)) return;
        if (position == null || position == Duration.zero) return;
        if (position == last) {
          stalled++;
          if (stalled >= stallTicks) {
            stop();
            onStall();
          }
        } else {
          stalled = 0;
          last = position;
        }
      } on Exception catch (error) {
        // 读不到位置（正在切换音源之类）：这一轮不判断，下一轮再看。
        developer.log(
          'Failed to read the external TTS playback position',
          name: 'tts.external',
          error: error,
        );
      } finally {
        checking = false;
      }
    });
    _timer = timer;
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }
}
