import 'package:drift/drift.dart' show OrderingTerm;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:mocktail/mocktail.dart';
import 'package:yunchuang/database/app_database.dart';
import 'package:yunchuang/pages/reader/reader_controller.dart';
import 'package:yunchuang/pages/reader/reader_data_loader.dart';
import 'package:yunchuang/pages/reader/reader_page.dart';
import 'package:yunchuang/providers/database_provider.dart';
import 'package:yunchuang/providers/preferences_provider.dart';
import 'package:yunchuang/services/tts_playback_checkpoint_store.dart';
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

  testWidgets('offers and resumes an interrupted TTS session at exact offset',
      (tester) async {
    tester.view.physicalSize = const Size(800, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    SharedPreferences.setMockInitialValues({'keepScreenOn': false});
    final preferences = await SharedPreferences.getInstance();
    final database = AppDatabase.connect(NativeDatabase.memory());
    final bookId = await database.into(database.books).insert(
          BooksCompanion.insert(
            title: '恢复朗读测试',
            filePath: 'memory://resume.txt',
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
    final book = await (database.select(database.books)
          ..where((row) => row.id.equals(bookId)))
        .getSingle();
    final chapters = await (database.select(database.chapters)
          ..where((row) => row.bookId.equals(bookId))
          ..orderBy([(row) => OrderingTerm.asc(row.sortOrder)]))
        .get();
    const secondChapter = '前置内容。恢复位置后的正文。';
    final resumeOffset = secondChapter.indexOf('恢复');
    final checkpointStore = TtsPlaybackCheckpointStore(preferences);
    final originalCheckpointTime =
        DateTime.now().toUtc().subtract(const Duration(hours: 1));
    await checkpointStore.save(
      TtsPlaybackCheckpoint(
        bookId: bookId,
        chapterId: chapters[1].id,
        characterOffset: resumeOffset,
        updatedAt: originalCheckpointTime,
      ),
    );

    final flutterTts = _MockFlutterTts();
    final spokenTexts = <String>[];
    when(() => flutterTts.getLanguages).thenAnswer((_) async => ['zh-CN']);
    when(() => flutterTts.getVoices).thenAnswer((_) async => const []);
    when(() => flutterTts.setLanguage(any())).thenAnswer((_) async => 1);
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
    final readerData = ReaderData(
      book: book,
      chapters: chapters,
      chapterContents: const ['第一章正文。', secondChapter],
      initialChapterIndex: 0,
    );
    final container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(database),
        sharedPreferencesProvider.overrideWithValue(preferences),
        readerDataLoaderProvider.overrideWithValue(
          _MemoryReaderDataSource(readerData),
        ),
        ttsServiceProvider.overrideWith((ref) => ttsService),
      ],
    );
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
    await _pumpUntil(
      tester,
      () => find.text('继续上次朗读？').evaluate().isNotEmpty,
      reason: 'the TTS resume prompt',
    );

    expect(find.text('上次朗读停在「第二章」约 36% 处。'), findsOneWidget);
    await tester.tap(find.text('继续朗读'));
    await _pumpUntil(
      tester,
      () => spokenTexts.isNotEmpty,
      reason: 'resumed TTS playback',
    );

    final readerController = container.read(readerControllerProvider(bookId));
    expect(readerController.currentChapterIndex, 1);
    expect(spokenTexts, ['恢复位置后的正文。']);
    expect(ttsService.currentOffset, resumeOffset);

    await tester.pump(const Duration(milliseconds: 5100));
    final refreshedCheckpoint = await tester.runAsync(checkpointStore.load);
    expect(
      refreshedCheckpoint?.updatedAt.isAfter(originalCheckpointTime),
      isTrue,
    );
  });
}

Future<void> _pumpUntil(
  WidgetTester tester,
  bool Function() condition, {
  required String reason,
}) async {
  for (var attempt = 0; attempt < 100; attempt++) {
    await tester.pump(const Duration(milliseconds: 50));
    if (condition()) return;
  }
  fail('Timed out waiting for $reason.');
}
