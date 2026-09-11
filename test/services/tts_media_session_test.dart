import 'package:audio_service/audio_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:mocktail/mocktail.dart';
import 'package:yunchuang/services/tts_media_session.dart';
import 'package:yunchuang/services/tts_service.dart';

class _MockFlutterTts extends Mock implements FlutterTts {}

void main() {
  late _MockFlutterTts flutterTts;
  late TTSService tts;
  late TtsMediaSession session;

  setUp(() async {
    flutterTts = _MockFlutterTts();
    when(() => flutterTts.getLanguages).thenAnswer((_) async => ['zh-CN']);
    when(() => flutterTts.getVoices).thenAnswer((_) async => const []);
    when(() => flutterTts.setLanguage(any())).thenAnswer((_) async => 1);
    when(() => flutterTts.setSpeechRate(any())).thenAnswer((_) async => 1);
    when(() => flutterTts.setVolume(any())).thenAnswer((_) async => 1);
    when(() => flutterTts.setPitch(any())).thenAnswer((_) async => 1);
    when(() => flutterTts.stop()).thenAnswer((_) async => 1);
    when(() => flutterTts.pause()).thenAnswer((_) async => 1);
    when(() => flutterTts.speak(any())).thenAnswer((_) async => 1);

    tts = TTSService(flutterTts: flutterTts);
    session = TtsMediaSession();
    await tts.ensureInitialized();
  });

  tearDown(() {
    session.detach(tts);
    tts.dispose();
  });

  test('publishes chapter metadata and boundary-aware notification controls',
      () async {
    var previousCalls = 0;
    var nextCalls = 0;
    session.attach(
      tts: tts,
      onPreviousChapter: () async => previousCalls++,
      onNextChapter: () async => nextCalls++,
    );
    session.updateChapter(
      bookId: 7,
      chapterId: 11,
      bookTitle: '蛊真人',
      chapterTitle: '第一章',
      author: '作者',
      hasPreviousChapter: true,
      hasNextChapter: true,
    );

    expect(session.mediaItem.value?.id, '7:11');
    expect(session.mediaItem.value?.title, '第一章');
    expect(session.mediaItem.value?.album, '蛊真人');
    expect(session.mediaItem.value?.artist, '作者');

    await tts.play('章节正文');

    expect(session.playbackState.value.playing, isTrue);
    expect(
      session.playbackState.value.controls.map((control) => control.action),
      [
        MediaAction.skipToPrevious,
        MediaAction.pause,
        MediaAction.skipToNext,
        MediaAction.stop,
      ],
    );
    expect(
      session.playbackState.value.androidCompactActionIndices,
      [0, 1, 2],
    );

    await session.skipToPrevious();
    await session.skipToNext();

    expect(previousCalls, 1);
    expect(nextCalls, 1);
  });

  test('routes media play, pause, and stop actions to TTS', () async {
    session.attach(tts: tts);
    session.updateChapter(
      bookId: 7,
      chapterId: 11,
      bookTitle: '测试书',
      chapterTitle: '第一章',
      hasPreviousChapter: false,
      hasNextChapter: false,
    );
    await tts.play('chapter text');

    await session.pause();

    expect(tts.isPaused, isTrue);
    expect(session.playbackState.value.playing, isFalse);
    expect(
      session.playbackState.value.controls.map((control) => control.action),
      [MediaAction.play, MediaAction.stop],
    );

    await session.play();

    expect(tts.isPlaying, isTrue);
    verify(() => flutterTts.speak('chapter text')).called(2);

    await session.stop();

    expect(tts.progress, 0);
    expect(
      session.playbackState.value.processingState,
      AudioProcessingState.idle,
    );
    expect(session.playbackState.value.controls, isEmpty);
  });

  test('ignores unavailable chapter actions', () async {
    var previousCalls = 0;
    var nextCalls = 0;
    session.attach(
      tts: tts,
      onPreviousChapter: () async => previousCalls++,
      onNextChapter: () async => nextCalls++,
    );
    session.updateChapter(
      bookId: 7,
      chapterId: 11,
      bookTitle: '测试书',
      chapterTitle: '唯一章节',
      hasPreviousChapter: false,
      hasNextChapter: false,
    );

    await session.skipToPrevious();
    await session.skipToNext();

    expect(previousCalls, 0);
    expect(nextCalls, 0);
  });

  test('retries a failed TTS request from the retained offset', () async {
    var failSpeak = true;
    when(() => flutterTts.speak(any())).thenAnswer((_) async {
      if (failSpeak) throw StateError('engine unavailable');
      return 1;
    });
    session.attach(tts: tts);
    session.updateChapter(
      bookId: 7,
      chapterId: 11,
      bookTitle: '测试书',
      chapterTitle: '第一章',
      hasPreviousChapter: false,
      hasNextChapter: false,
    );

    final started = await tts.playFromOffset('abcdef', 3);

    expect(started, isFalse);
    expect(tts.status, TTSStatus.error);
    expect(tts.currentOffset, 3);

    failSpeak = false;
    await session.play();

    expect(tts.isPlaying, isTrue);
    expect(tts.currentOffset, 3);
    verify(() => flutterTts.speak('def')).called(2);
  });
}
