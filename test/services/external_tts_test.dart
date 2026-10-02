import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:mocktail/mocktail.dart';
import 'package:yunchuang/models/tts_highlight.dart';
import 'package:yunchuang/services/external_tts.dart';
import 'package:yunchuang/services/tts_media_session.dart';
import 'package:yunchuang/services/tts_service.dart';

class _MockFlutterTts extends Mock implements FlutterTts {}

class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this.respond);

  final ResponseBody Function(RequestOptions options) respond;
  RequestOptions? lastRequest;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    lastRequest = options;
    return respond(options);
  }

  @override
  void close({bool force = false}) {}
}

class _FakeSynthesizer implements SpeechSynthesizer {
  final requests = <(String, double)>[];
  final pending = <String, Completer<Uint8List>>{};
  bool holdRequests = false;
  Object? failWith;

  @override
  Future<Uint8List> synthesize(String text, {required double speed}) {
    requests.add((text, speed));
    if (failWith != null) return Future.error(failWith!);
    if (holdRequests) {
      return (pending[text] = Completer<Uint8List>()).future;
    }
    return Future.value(Uint8List.fromList(utf8.encode(text)));
  }
}

class _FakePlayer implements SpeechAudioPlayer {
  final _completed = StreamController<void>.broadcast();
  final _interrupted = StreamController<void>.broadcast();
  final played = <String>[];
  final calls = <String>[];

  /// 不为空时 play() 卡在这里，模拟 audioplayers 准备音源的那段时间。
  Completer<void>? playGate;

  void finish() => _completed.add(null);

  void interrupt() => _interrupted.add(null);

  @override
  Stream<void> get onCompleted => _completed.stream;

  @override
  Stream<void> get onInterrupted => _interrupted.stream;

  @override
  Future<void> play(Uint8List audio) async {
    calls.add('play');
    await playGate?.future;
    played.add(utf8.decode(audio));
  }

  @override
  Future<void> pause() async => calls.add('pause');

  @override
  Future<void> resume() async => calls.add('resume');

  @override
  Future<void> stop() async => calls.add('stop');

  @override
  Future<void> dispose() async {
    await _completed.close();
    await _interrupted.close();
  }
}

/// 够长（三十字以上）、不会和前后的段落并成一组的段落。
String _paragraph(String label) => '$label：他沿着河岸慢慢走着，看见远处的灯火一点点亮起来，风从山口吹过来。';

const _settings = ExternalTtsSettings(
  enabled: true,
  baseUrl: 'https://tts.example.com/v1/',
  apiKey: 'sk-test',
  model: 'tts-1',
  voice: 'alloy',
);

void main() {
  group('ExternalTtsSettings', () {
    test('builds the speech endpoint from the base url', () {
      expect(
        _settings.speechUri.toString(),
        'https://tts.example.com/v1/audio/speech',
      );
      expect(
        _settings.copyWith(baseUrl: 'http://192.168.1.5:5050').speechUri,
        Uri.parse('http://192.168.1.5:5050/audio/speech'),
      );
    });

    test('needs an http(s) address, a model and a voice', () {
      expect(_settings.isActive, isTrue);
      expect(_settings.copyWith(apiKey: '').isComplete, isTrue);
      expect(
          _settings.copyWith(baseUrl: 'tts.example.com').isComplete, isFalse);
      expect(_settings.copyWith(baseUrl: 'ftp://x.com').isComplete, isFalse);
      expect(_settings.copyWith(model: ' ').isComplete, isFalse);
      expect(_settings.copyWith(voice: '').isComplete, isFalse);
      expect(_settings.copyWith(enabled: false).isActive, isFalse);
    });
  });

  group('OpenAiSpeechSynthesizer', () {
    test('posts the OpenAI speech request and returns the audio', () async {
      final adapter = _FakeAdapter(
        (_) => ResponseBody.fromBytes(
          [1, 2, 3],
          200,
          headers: {
            Headers.contentTypeHeader: ['audio/mpeg'],
          },
        ),
      );
      final dio = Dio()..httpClientAdapter = adapter;

      final audio = await OpenAiSpeechSynthesizer(_settings, dio: dio)
          .synthesize('你好。', speed: 1.2);

      expect(audio, [1, 2, 3]);
      final request = adapter.lastRequest!;
      expect(request.uri.toString(), 'https://tts.example.com/v1/audio/speech');
      expect(request.headers['Authorization'], 'Bearer sk-test');
      expect(request.data, {
        'model': 'tts-1',
        'input': '你好。',
        'voice': 'alloy',
        'response_format': 'mp3',
        'speed': 1.2,
      });
    });

    test('explains HTTP errors with the server message', () async {
      final dio = Dio()
        ..httpClientAdapter = _FakeAdapter(
          (_) => ResponseBody.fromString(
            jsonEncode({
              'error': {'message': 'Incorrect API key provided'},
            }),
            401,
            headers: {
              Headers.contentTypeHeader: ['application/json'],
            },
          ),
        );

      await expectLater(
        OpenAiSpeechSynthesizer(_settings, dio: dio)
            .synthesize('你好。', speed: 1),
        throwsA(
          isA<ExternalTtsException>().having(
            (error) => error.message,
            'message',
            allOf(contains('401'), contains('Incorrect API key provided')),
          ),
        ),
      );
    });

    test('requests give up connecting after a timeout', () {
      // Dio 默认不设连接超时，地址填错时要等系统 TCP 超时。
      expect(externalTtsBaseOptions().connectTimeout, isNotNull);
    });

    test('explains server-side failures and bad certificates', () async {
      Future<String> messageFor(ResponseBody Function(RequestOptions) respond) {
        final dio = Dio()..httpClientAdapter = _FakeAdapter(respond);
        return OpenAiSpeechSynthesizer(_settings, dio: dio)
            .synthesize('你好。', speed: 1)
            .then<String>((_) => 'no error', onError: (Object error) {
          return (error as ExternalTtsException).message;
        });
      }

      expect(
        await messageFor((_) => ResponseBody.fromString('bad gateway', 502)),
        allOf(contains('502'), contains('服务暂时异常')),
      );
      expect(
        await messageFor(
          (options) => throw DioException.badCertificate(
            requestOptions: options,
          ),
        ),
        contains('证书'),
      );
    });

    test('a JSON body with status 200 is an error, not audio', () async {
      final dio = Dio()
        ..httpClientAdapter = _FakeAdapter(
          (_) => ResponseBody.fromString(
            jsonEncode({'message': 'voice not found'}),
            200,
            headers: {
              Headers.contentTypeHeader: ['application/json'],
            },
          ),
        );

      await expectLater(
        OpenAiSpeechSynthesizer(_settings, dio: dio)
            .synthesize('你好。', speed: 1),
        throwsA(
          isA<ExternalTtsException>().having(
            (error) => error.message,
            'message',
            contains('voice not found'),
          ),
        ),
      );
    });
  });

  group('PlaybackStallWatchdog', () {
    testWidgets('reports once when the position stops moving', (tester) async {
      final positions = <Duration?>[
        Duration.zero, // 还在准备
        const Duration(milliseconds: 900),
        const Duration(milliseconds: 1900),
        const Duration(milliseconds: 1900),
        const Duration(milliseconds: 1900),
        const Duration(milliseconds: 1900),
      ];
      var stalls = 0;
      final watchdog = PlaybackStallWatchdog(
        readPosition: () async =>
            positions.isEmpty ? null : positions.removeAt(0),
        onStall: () => stalls++,
      );

      watchdog.start();
      for (var second = 0; second < 6; second++) {
        await tester.pump(const Duration(seconds: 1));
      }

      // 1.9 秒处连着两次没动才算停，之后不再重复报。
      expect(stalls, 1);
      watchdog.stop();
    });

    testWidgets('stays quiet while playing or after stop', (tester) async {
      var position = Duration.zero;
      var stalls = 0;
      final watchdog = PlaybackStallWatchdog(
        readPosition: () async {
          position += const Duration(milliseconds: 1000);
          return position;
        },
        onStall: () => stalls++,
      );

      watchdog.start();
      for (var second = 0; second < 5; second++) {
        await tester.pump(const Duration(seconds: 1));
      }
      watchdog.stop();
      position = const Duration(seconds: 1);
      for (var second = 0; second < 3; second++) {
        await tester.pump(const Duration(seconds: 1));
      }

      expect(stalls, 0);
    });
  });

  group('TTSService with an external engine', () {
    late _MockFlutterTts flutterTts;
    late _FakeSynthesizer synthesizer;
    late _FakePlayer player;
    late TTSService service;

    setUp(() async {
      flutterTts = _MockFlutterTts();
      when(() => flutterTts.getLanguages).thenAnswer((_) async => ['zh-CN']);
      when(() => flutterTts.getVoices).thenAnswer((_) async => const []);
      when(() => flutterTts.setLanguage(any())).thenAnswer((_) async => 1);
      when(() => flutterTts.setSpeechRate(any())).thenAnswer((_) async => 1);
      when(() => flutterTts.setVolume(any())).thenAnswer((_) async => 1);
      when(() => flutterTts.setPitch(any())).thenAnswer((_) async => 1);
      when(() => flutterTts.stop()).thenAnswer((_) async => 1);
      when(() => flutterTts.speak(any())).thenAnswer((_) async => 1);
      synthesizer = _FakeSynthesizer();
      player = _FakePlayer();
      service = TTSService(
        flutterTts: flutterTts,
        initialSpeechRate: 0.6,
        externalSettings: _settings,
        createSynthesizer: (_) => synthesizer,
        createAudioPlayer: () => player,
      );
      await service.ensureInitialized();
    });

    tearDown(() => service.dispose());

    Future<void> finishUnit() async {
      player.finish();
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
    }

    test('speaks paragraphs through the service and prefetches the next',
        () async {
      final first = _paragraph('第一段');
      final second = _paragraph('第二段');
      final third = _paragraph('第三段');
      final content = [first, second, third].join('\n');
      final highlights = <TtsHighlight?>[];
      service.onHighlightChanged = highlights.add;

      expect(service.engine, TTSEngine.external);
      await service.play(content);

      expect(player.played, [first]);
      // 应用语速 0.6 对应接口的 1.2 倍；下一段在这一段播的时候就去合成了。
      expect(synthesizer.requests, [(first, 1.2), (second, 1.2)]);
      expect(highlights.last, TtsHighlight(0, first.length));
      verifyNever(() => flutterTts.speak(any()));

      await finishUnit();

      expect(player.played, [first, second]);
      expect(service.currentOffset, first.length + 1);
      // 第二段用的是预取好的音频，没有再请求一次。
      expect(
        synthesizer.requests.where((request) => request.$1 == second),
        hasLength(1),
      );

      await finishUnit();
      await finishUnit();

      expect(player.played, [first, second, third]);
      expect(service.status, TTSStatus.ready);
      expect(service.progress, 1);
      expect(highlights.last, isNull);
    });

    test('short dialogue lines share one request', () async {
      final lines = [
        for (var i = 0; i < 9; i++) '对话$i：“嗯，我知道了。”',
      ];
      final content = [...lines, _paragraph('叙述')].join('\n');

      await service.play(content);
      for (var i = 0; i < 4; i++) {
        await finishUnit();
      }

      // 十五字左右的对话五行一组（不超过八十字），长段落单独一个。
      expect(player.played, [
        lines.sublist(0, 5).join('\n'),
        lines.sublist(5).join('\n'),
        _paragraph('叙述'),
      ]);
    });

    test('pause and resume keep the loaded audio', () async {
      final first = _paragraph('第一段');
      await service.play([first, _paragraph('第二段')].join('\n'));

      await service.pause();
      expect(service.isPaused, isTrue);
      final requestsBeforeResume = synthesizer.requests.length;

      expect(await service.resume(), isTrue);

      expect(service.isPlaying, isTrue);
      expect(player.calls, containsAllInOrder(['play', 'pause', 'resume']));
      expect(synthesizer.requests, hasLength(requestsBeforeResume));
      expect(player.played, [first]);
    });

    test('a player interrupted by the system shows as paused', () async {
      final first = _paragraph('第一段');
      await service.play([first, _paragraph('第二段')].join('\n'));

      player.interrupt();
      await Future<void>.delayed(Duration.zero);

      expect(service.isPaused, isTrue);
      expect(await service.resume(), isTrue);
      // 音频还在播放器里，原地续播，不重新合成。
      expect(player.calls.last, 'resume');
      expect(player.played, [first]);
    });

    test('an older play() finishing late does not stop the newer one',
        () async {
      final first = _paragraph('第一段');
      final second = _paragraph('第二段');
      final content = [first, second].join('\n');
      player.playGate = Completer<void>();

      final starting = service.play(content);
      await Future<void>.delayed(Duration.zero);
      // 第一段还在 play() 里准备音源，用户就跳到了第二段。
      final jumping = service.playFromOffset(content, first.length + 1);
      await Future<void>.delayed(Duration.zero);
      player.playGate!.complete();
      await starting;
      await jumping;

      expect(player.calls.last, 'play');
      expect(service.isPlaying, isTrue);
      expect(
        service.highlight,
        TtsHighlight(first.length + 1, content.length),
      );
    });

    test('stopping while the audio is being synthesized drops it', () async {
      synthesizer.holdRequests = true;
      final playing = service.play('第一段。');
      await Future<void>.delayed(Duration.zero);

      await service.stop();
      synthesizer.pending['第一段。']!.complete(Uint8List.fromList([1]));
      await playing;

      expect(player.played, isEmpty);
      expect(service.status, TTSStatus.ready);
    });

    test('a failed request reports the error and can be retried', () async {
      final session = TtsMediaSession()..attach(tts: service);
      addTearDown(() => session.detach(service));
      synthesizer.failWith = const ExternalTtsException('语音服务返回错误 401');

      final started = await service.playFromOffset('甲段。\n乙段。', 4);

      expect(started, isFalse);
      expect(service.status, TTSStatus.error);
      expect(service.lastError, '语音服务返回错误 401');
      expect(service.currentOffset, 4);

      synthesizer.failWith = null;
      await session.play();

      expect(service.isPlaying, isTrue);
      expect(player.played, ['乙段。']);
    });

    test('turning the external engine off goes back to system speech',
        () async {
      await service.configureExternal(_settings.copyWith(enabled: false));

      expect(service.engine, TTSEngine.system);
      await service.play('系统朗读。');

      verify(() => flutterTts.speak('系统朗读。')).called(1);
      expect(player.played, isEmpty);
    });
  });
}
