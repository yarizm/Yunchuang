import 'package:audio_service/audio_service.dart';
import 'package:drift/drift.dart' show OrderingTerm;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:mocktail/mocktail.dart';
import 'package:yunchuang/database/app_database.dart';
import 'package:yunchuang/database/daos/book_tts_settings_dao.dart';
import 'package:yunchuang/pages/reader/reader_controller.dart';
import 'package:yunchuang/pages/reader/reader_data_loader.dart';
import 'package:yunchuang/pages/reader/reader_page.dart';
import 'package:yunchuang/providers/database_provider.dart';
import 'package:yunchuang/providers/preferences_provider.dart';
import 'package:yunchuang/services/tts_media_session.dart';
import 'package:yunchuang/services/tts_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockFlutterTts extends Mock implements FlutterTts {}

class _MemoryReaderDataSource implements ReaderDataSource {
  final ReaderData data;

  const _MemoryReaderDataSource(this.data);

  @override
  Future<ReaderData?> loadBook(int bookId, {int? targetChapterId}) async =>
      data;

  @override
  Future<Map<int, String>> loadPdfPageTexts(
    Book book,
    List<Chapter> chapters,
    Iterable<int> chapterIndexes, {
    Set<int>? ignoreIndexes,
  }) async =>
      const {};
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> pumpUntil(
    WidgetTester tester,
    bool Function() condition, {
    String reason = 'condition',
  }) async {
    for (var attempt = 0; attempt < 100; attempt++) {
      await tester.pump(const Duration(milliseconds: 50));
      if (condition()) return;
    }
    fail('Timed out waiting for $reason.');
  }

  testWidgets(
      'reader TTS supports chapter controls, continuation, and final stop',
      (tester) async {
    tester.view.physicalSize = const Size(800, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final database = AppDatabase.connect(NativeDatabase.memory());
    final fixture = await tester.runAsync(() async {
      SharedPreferences.setMockInitialValues({'keepScreenOn': false});
      final preferences = await SharedPreferences.getInstance();
      final bookId = await database.into(database.books).insert(
            BooksCompanion.insert(
              title: '连续朗读测试',
              filePath: 'memory://book.txt',
              format: 'txt',
              fileSize: 1,
            ),
          );
      await database.into(database.chapters).insert(
            ChaptersCompanion.insert(
              bookId: bookId,
              title: '第一章',
              contentIndex: 0,
              sortOrder: 0,
            ),
          );
      await database.into(database.chapters).insert(
            ChaptersCompanion.insert(
              bookId: bookId,
              title: '第二章',
              contentIndex: 1,
              sortOrder: 1,
            ),
          );
      await BookTtsSettingsDao(database).save(
        bookId: bookId,
        language: 'zh-TW',
        voiceName: 'Voice B',
        voiceLocale: 'zh-TW',
        speechRate: 0.8,
        sleepTimerOption: 'off',
      );
      return (
        preferences: preferences,
        book: await (database.select(database.books)
              ..where((book) => book.id.equals(bookId)))
            .getSingle(),
        chapters: await (database.select(database.chapters)
              ..where((chapter) => chapter.bookId.equals(bookId))
              ..orderBy([(chapter) => OrderingTerm.asc(chapter.sortOrder)]))
            .get(),
      );
    });
    final book = fixture!.book;
    final chapters = fixture.chapters;
    final bookId = book.id;
    final readerData = ReaderData(
      book: book,
      chapters: chapters,
      chapterContents: const ['第一章内容。', '第二章内容。'],
      initialChapterIndex: 0,
    );

    final flutterTts = _MockFlutterTts();
    void Function()? completionHandler;
    final spokenTexts = <String>[];
    when(() => flutterTts.setCompletionHandler(any())).thenAnswer((invocation) {
      completionHandler =
          invocation.positionalArguments.single as void Function();
    });
    when(() => flutterTts.getLanguages)
        .thenAnswer((_) async => ['zh-CN', 'zh-TW']);
    when(() => flutterTts.getVoices).thenAnswer((_) async => [
          {'name': 'Voice B', 'locale': 'zh-TW'},
        ]);
    when(() => flutterTts.setLanguage(any())).thenAnswer((_) async => 1);
    when(() => flutterTts.setVoice(any())).thenAnswer((_) async => 1);
    when(() => flutterTts.setSpeechRate(any())).thenAnswer((_) async => 1);
    when(() => flutterTts.setVolume(any())).thenAnswer((_) async => 1);
    when(() => flutterTts.setPitch(any())).thenAnswer((_) async => 1);
    when(() => flutterTts.stop()).thenAnswer((_) async => 1);
    when(() => flutterTts.pause()).thenAnswer((_) async => 1);
    when(() => flutterTts.speak(any())).thenAnswer((invocation) async {
      spokenTexts.add(invocation.positionalArguments.single as String);
      return 1;
    });
    final ttsService = TTSService(flutterTts: flutterTts);
    final mediaSession = TtsMediaSession();

    final container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(database),
        sharedPreferencesProvider.overrideWithValue(fixture.preferences),
        readerDataLoaderProvider.overrideWithValue(
          _MemoryReaderDataSource(readerData),
        ),
        ttsServiceProvider.overrideWith((ref) => ttsService),
        ttsMediaSessionProvider.overrideWithValue(mediaSession),
      ],
    );
    final readerController = container.read(readerControllerProvider(bookId));
    readerController.setToolbarExpanded(true);

    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      container.dispose();
      await database.close();
    });

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(home: ReaderPage(bookId: bookId)),
      ),
    );
    await pumpUntil(
      tester,
      () => find.byTooltip('朗读').evaluate().isNotEmpty,
      reason: 'the reader toolbar',
    );

    expect(readerController.currentChapterIndex, 0);
    await tester.tap(find.byTooltip('朗读'));
    await pumpUntil(
      tester,
      () => spokenTexts.length == 1,
      reason: 'the first chapter to start speaking',
    );
    expect(completionHandler, isNotNull);
    expect(spokenTexts, ['第一章内容。']);
    expect(ttsService.speechRate, 0.8);
    expect(ttsService.language, 'zh-TW');
    expect(ttsService.voice?.name, 'Voice B');
    expect(mediaSession.mediaItem.value?.id, '$bookId:${chapters.first.id}');
    expect(mediaSession.mediaItem.value?.title, '第一章');
    expect(mediaSession.mediaItem.value?.album, '连续朗读测试');
    expect(mediaSession.playbackState.value.playing, isTrue);

    await tester.pump(const Duration(milliseconds: 500));
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
    final savedSettings = await tester.runAsync(
      () => BookTtsSettingsDao(database).getForBook(bookId),
    );
    expect(savedSettings?.sleepTimerOption, 'minutes30');

    await tester.ensureVisible(find.byIcon(Icons.skip_next_rounded));
    await tester.pump();
    await tester.tap(find.byIcon(Icons.skip_next_rounded));
    await pumpUntil(
      tester,
      () =>
          readerController.currentChapterIndex == 1 && spokenTexts.length == 2,
      reason: 'the next chapter control to start chapter two',
    );
    expect(spokenTexts, ['第一章内容。', '第二章内容。']);

    await tester.ensureVisible(find.byIcon(Icons.skip_previous_rounded));
    await tester.pump();
    await tester.tap(find.byIcon(Icons.skip_previous_rounded));
    await pumpUntil(
      tester,
      () =>
          readerController.currentChapterIndex == 0 && spokenTexts.length == 3,
      reason: 'the previous chapter control to restart chapter one',
    );
    expect(spokenTexts, ['第一章内容。', '第二章内容。', '第一章内容。']);

    completionHandler!();
    await pumpUntil(
      tester,
      () =>
          readerController.currentChapterIndex == 1 && spokenTexts.length == 4,
      reason: 'TTS to continue into the second chapter',
    );

    expect(readerController.currentChapterIndex, 1);
    expect(
      spokenTexts,
      ['第一章内容。', '第二章内容。', '第一章内容。', '第二章内容。'],
    );

    completionHandler!();
    await tester.pump(const Duration(milliseconds: 800));

    expect(readerController.currentChapterIndex, 1);
    expect(spokenTexts, hasLength(4));
    expect(
      mediaSession.playbackState.value.processingState,
      AudioProcessingState.idle,
    );
  });
}
