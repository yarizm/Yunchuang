import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:mocktail/mocktail.dart';
import 'package:yunchuang/services/tts_service.dart';

class _MockFlutterTts extends Mock implements FlutterTts {}

void main() {
  late _MockFlutterTts flutterTts;

  setUp(() {
    flutterTts = _MockFlutterTts();
    when(() => flutterTts.getLanguages).thenAnswer((_) async => ['zh-CN']);
    when(() => flutterTts.getVoices).thenAnswer((_) async => [
          {'name': 'Voice B', 'locale': 'zh-TW'},
          {'name': 'Voice A', 'locale': 'zh-CN'},
          {'name': 'Voice A', 'locale': 'zh-CN'},
        ]);
    when(() => flutterTts.setLanguage(any())).thenAnswer((_) async => 1);
    when(() => flutterTts.setVoice(any())).thenAnswer((_) async => 1);
    when(() => flutterTts.setSpeechRate(any())).thenAnswer((_) async => 1);
    when(() => flutterTts.setVolume(any())).thenAnswer((_) async => 1);
    when(() => flutterTts.setPitch(any())).thenAnswer((_) async => 1);
    when(() => flutterTts.stop()).thenAnswer((_) async => 1);
    when(() => flutterTts.pause()).thenAnswer((_) async => 1);
    when(() => flutterTts.speak(any())).thenAnswer((_) async => 1);
  });

  test('uses persisted speech rate during initialization', () async {
    final service = TTSService(
      flutterTts: flutterTts,
      initialSpeechRate: 0.8,
    );
    addTearDown(service.dispose);

    expect(service.speechRate, 0.8);
    await service.ensureInitialized();

    verify(() => flutterTts.setSpeechRate(0.8)).called(1);
  });

  test('clamps and persists speech rate updates', () async {
    final persistedRates = <double>[];
    final service = TTSService(
      flutterTts: flutterTts,
      persistSpeechRate: persistedRates.add,
    );
    addTearDown(service.dispose);

    await service.ensureInitialized();
    await service.setSpeechRate(1.5);

    expect(service.speechRate, 1.0);
    expect(persistedRates, [1.0]);
    verify(() => flutterTts.setSpeechRate(1.0)).called(1);
  });

  test('starts speaking from an exact character offset', () async {
    final service = TTSService(flutterTts: flutterTts);
    addTearDown(service.dispose);
    const content = '开头内容。方源从这里开始朗读。';
    final startOffset = content.indexOf('方源');

    final started = await service.playFromOffset(content, startOffset);

    expect(started, isTrue);
    expect(service.progress, closeTo(startOffset / content.length, 0.0001));
    verify(() => flutterTts.speak('方源从这里开始朗读。')).called(1);
  });

  test('falls back to the default rate for invalid stored values', () {
    expect(TTSService.normalizeSpeechRate(double.nan), 0.5);
    expect(TTSService.normalizeSpeechRate(null), 0.5);
  });

  test('loads, deduplicates, and applies platform voices', () async {
    final service = TTSService(flutterTts: flutterTts);
    addTearDown(service.dispose);

    await service.ensureInitialized();

    expect(
      service.availableVoices,
      const [
        TTSVoice(name: 'Voice A', locale: 'zh-CN'),
        TTSVoice(name: 'Voice B', locale: 'zh-TW'),
      ],
    );
    final changed = await service.setVoice(
      const TTSVoice(name: 'Voice B', locale: 'zh-TW'),
    );

    expect(changed, isTrue);
    expect(service.language, 'zh-TW');
    expect(service.voice?.name, 'Voice B');
    verify(() => flutterTts.setVoice({
          'name': 'Voice B',
          'locale': 'zh-TW',
        })).called(1);
  });

  test('falls back to the first available language when Chinese is absent',
      () async {
    when(() => flutterTts.getLanguages).thenAnswer((_) async => ['en-US']);
    when(() => flutterTts.getVoices).thenAnswer((_) async => [
          {'name': 'English Voice', 'locale': 'en-US'},
        ]);
    final service = TTSService(flutterTts: flutterTts);
    addTearDown(service.dispose);

    final initialized = await service.ensureInitialized();

    expect(initialized, isTrue);
    expect(service.defaultLanguage, 'en-US');
    expect(service.language, 'en-US');
    verify(() => flutterTts.setLanguage('en-US')).called(1);
  });

  test('keeps playback active while applying a different voice', () async {
    final service = TTSService(flutterTts: flutterTts);
    addTearDown(service.dispose);
    await service.ensureInitialized();
    await service.play('chapter text');

    final changed = await service.setVoice(
      const TTSVoice(name: 'Voice B', locale: 'zh-TW'),
    );

    expect(changed, isTrue);
    expect(service.isPlaying, isTrue);

    await service.applyPlaybackSettings();

    expect(service.isPlaying, isTrue);
    verify(() => flutterTts.speak('chapter text')).called(2);
  });

  test('book overrides do not replace the global speech rate', () async {
    final persistedRates = <double>[];
    final service = TTSService(
      flutterTts: flutterTts,
      initialSpeechRate: 0.6,
      persistSpeechRate: persistedRates.add,
    );
    addTearDown(service.dispose);
    await service.ensureInitialized();

    await service.setSpeechRate(0.9, persist: false);
    service.restoreSleepTimerPreference(TTSSleepTimerOption.minutes30);

    expect(persistedRates, isEmpty);
    expect(service.preferredSleepTimerOption, TTSSleepTimerOption.minutes30);
    expect(service.sleepTimerOption, TTSSleepTimerOption.off);

    service.activatePreferredSleepTimer();
    expect(service.sleepTimerOption, TTSSleepTimerOption.minutes30);
    expect(service.sleepTimerDeadline, isNotNull);

    await service.resetBookOverrides(globalSpeechRate: 0.6);
    expect(service.speechRate, 0.6);
    expect(service.voice, isNull);
    expect(service.preferredSleepTimerOption, TTSSleepTimerOption.off);
    expect(service.sleepTimerOption, TTSSleepTimerOption.off);
    expect(persistedRates, isEmpty);
  });

  test('notifies the reader when the current content completes', () async {
    final service = TTSService(flutterTts: flutterTts);
    addTearDown(service.dispose);
    await service.ensureInitialized();
    var completed = 0;
    service.onContentCompleted = () => completed++;
    await service.play('第一句。');
    final completionHandler = verify(
      () => flutterTts.setCompletionHandler(captureAny()),
    ).captured.single as void Function();

    completionHandler();
    await Future<void>.delayed(Duration.zero);

    expect(completed, 1);
    expect(service.status, TTSStatus.ready);
    expect(service.progress, 1);
  });

  test('end-of-chapter sleep timer stops before continuation', () async {
    final service = TTSService(flutterTts: flutterTts);
    addTearDown(service.dispose);
    await service.ensureInitialized();
    var completed = 0;
    service.onContentCompleted = () => completed++;
    service.setSleepTimer(TTSSleepTimerOption.endOfChapter);
    await service.play('第一句。');
    final completionHandler = verify(
      () => flutterTts.setCompletionHandler(captureAny()),
    ).captured.single as void Function();

    completionHandler();
    await Future<void>.delayed(Duration.zero);

    expect(completed, 0);
    expect(service.status, TTSStatus.ready);
    expect(service.sleepTimerOption, TTSSleepTimerOption.off);
  });

  test('minute sleep timer can be configured and cancelled', () {
    final service = TTSService(flutterTts: flutterTts);
    addTearDown(service.dispose);

    service.setSleepTimer(TTSSleepTimerOption.minutes30);

    expect(service.sleepTimerOption, TTSSleepTimerOption.minutes30);
    expect(service.sleepTimerDeadline, isNotNull);
    expect(
      service.sleepTimerDeadline!.difference(DateTime.now()).inMinutes,
      inInclusiveRange(29, 30),
    );

    service.cancelSleepTimer();

    expect(service.sleepTimerOption, TTSSleepTimerOption.off);
    expect(service.sleepTimerDeadline, isNull);
  });

  test('pauses when headphones or Bluetooth audio disconnects', () async {
    final noisyEvents = StreamController<void>();
    addTearDown(noisyEvents.close);
    final service = TTSService(flutterTts: flutterTts);
    addTearDown(service.dispose);
    service.attachBecomingNoisyEvents(noisyEvents.stream);
    await service.ensureInitialized();
    await service.play('第一句。');

    noisyEvents.add(null);
    await Future<void>.delayed(Duration.zero);

    verify(() => flutterTts.pause()).called(1);
    expect(service.status, TTSStatus.paused);
  });
}
