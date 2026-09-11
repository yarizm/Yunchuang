import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:mocktail/mocktail.dart';
import 'package:yunchuang/services/tts_service.dart';
import 'package:yunchuang/widgets/tts_control_panel.dart';

class _MockFlutterTts extends Mock implements FlutterTts {}

void main() {
  late _MockFlutterTts flutterTts;
  late TTSService service;

  setUp(() {
    flutterTts = _MockFlutterTts();
    when(() => flutterTts.getLanguages)
        .thenAnswer((_) async => ['zh-CN', 'zh-TW']);
    when(() => flutterTts.getVoices).thenAnswer((_) async => [
          {'name': 'Voice A', 'locale': 'zh-CN'},
          {'name': 'Voice B', 'locale': 'zh-TW'},
        ]);
    when(() => flutterTts.setLanguage(any())).thenAnswer((_) async => 1);
    when(() => flutterTts.setVoice(any())).thenAnswer((_) async => 1);
    when(() => flutterTts.setSpeechRate(any())).thenAnswer((_) async => 1);
    when(() => flutterTts.setVolume(any())).thenAnswer((_) async => 1);
    when(() => flutterTts.setPitch(any())).thenAnswer((_) async => 1);
    when(() => flutterTts.stop()).thenAnswer((_) async => 1);
    service = TTSService(flutterTts: flutterTts);
  });

  testWidgets('sleep timer remains usable on a short screen', (tester) async {
    tester.view.physicalSize = const Size(400, 420);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ttsServiceProvider.overrideWith((ref) => service),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: TtsControlPanel(content: '用于朗读的章节正文。'),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('睡眠定时'), findsOneWidget);
    await tester.ensureVisible(find.text('关闭'));
    await tester.pump();
    await tester.tap(find.text('关闭'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.scrollUntilVisible(
      find.text('本章结束').last,
      120,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(find.text('本章结束').last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(service.sleepTimerOption, TTSSleepTimerOption.endOfChapter);
    expect(tester.takeException(), isNull);
  });

  testWidgets('chapter controls follow the current reader chapter',
      (tester) async {
    final chapterIndex = ValueNotifier<int>(1);
    addTearDown(chapterIndex.dispose);
    var previousCalls = 0;
    var nextCalls = 0;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ttsServiceProvider.overrideWith((ref) => service),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: TtsControlPanel(
              content: '用于朗读的章节正文。',
              chapterListenable: chapterIndex,
              currentChapterIndex: () => chapterIndex.value,
              chapterCount: 3,
              onPreviousChapter: () async {
                previousCalls++;
                chapterIndex.value--;
              },
              onNextChapter: () async {
                nextCalls++;
                chapterIndex.value++;
              },
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('第 2 / 3 章'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.skip_next_rounded));
    await tester.pump();

    expect(nextCalls, 1);
    expect(find.text('第 3 / 3 章'), findsOneWidget);
    final nextButton = tester.widget<IconButton>(
      find.widgetWithIcon(IconButton, Icons.skip_next_rounded),
    );
    expect(nextButton.onPressed, isNull);

    await tester.tap(find.byIcon(Icons.skip_previous_rounded));
    await tester.pump();

    expect(previousCalls, 1);
    expect(find.text('第 2 / 3 章'), findsOneWidget);
  });

  testWidgets('per-book language, voice, sleep, and reset actions are exposed',
      (tester) async {
    tester.view.physicalSize = const Size(800, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    String? savedLanguage;
    TTSVoice? savedVoice;
    TTSSleepTimerOption? savedSleepTimer;
    var resetCalls = 0;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ttsServiceProvider.overrideWith((ref) => service),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: TtsControlPanel(
              content: '用于朗读的章节正文。',
              onLanguageChanged: (language) async {
                savedLanguage = language;
                await service.setLanguage(language);
              },
              onVoiceChanged: (voice) async {
                savedVoice = voice;
                await service.setVoice(voice);
              },
              onSleepTimerChanged: (option) async {
                savedSleepTimer = option;
                service.setSleepTimer(option);
              },
              onResetBookSettings: () async => resetCalls++,
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 200));
    await tester.runAsync(service.refreshCapabilities);
    expect(service.availableLanguages, contains('zh-TW'));

    final languageControl = find.byKey(const Key('tts-language-setting'));
    await tester.ensureVisible(languageControl);
    await tester.pump(const Duration(milliseconds: 300));
    tester.widget<InkWell>(languageControl).onTap!.call();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.scrollUntilVisible(
      find.text('zh-TW').last,
      120,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(find.text('zh-TW').last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(savedLanguage, 'zh-TW');

    final voiceControl = find.byKey(const Key('tts-voice-setting'));
    await tester.ensureVisible(voiceControl);
    await tester.pump(const Duration(milliseconds: 300));
    tester.widget<InkWell>(voiceControl).onTap!.call();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.scrollUntilVisible(
      find.text('Voice B'),
      120,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(find.text('Voice B'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(savedVoice, const TTSVoice(name: 'Voice B', locale: 'zh-TW'));

    final sleepControl = find.byKey(const Key('tts-sleep-timer-setting'));
    await tester.ensureVisible(sleepControl);
    await tester.pump(const Duration(milliseconds: 300));
    tester.widget<InkWell>(sleepControl).onTap!.call();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.scrollUntilVisible(
      find.text('30 分钟').last,
      120,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(find.text('30 分钟').last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(savedSleepTimer, TTSSleepTimerOption.minutes30);

    await tester.ensureVisible(find.text('恢复全局默认'));
    await tester.tap(find.text('恢复全局默认'));
    await tester.pump();
    expect(resetCalls, 1);
  });
}
