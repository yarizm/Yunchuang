import 'package:drift/drift.dart' show OrderingTerm, Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yunchuang/database/app_database.dart';
import 'package:yunchuang/pages/reader/reader_controller.dart';
import 'package:yunchuang/pages/reader/reader_data_loader.dart';
import 'package:yunchuang/pages/reader/reader_page.dart';
import 'package:yunchuang/providers/database_provider.dart';
import 'package:yunchuang/providers/preferences_provider.dart';
import 'package:yunchuang/services/tts_service.dart';

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

  testWidgets('打开没有正文的章节时显示说明，而不是一直转圈', (tester) async {
    tester.view.physicalSize = const Size(800, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    SharedPreferences.setMockInitialValues({'keepScreenOn': false});
    final preferences = await SharedPreferences.getInstance();
    final database = AppDatabase.connect(NativeDatabase.memory());
    final bookId = await database.into(database.books).insert(
          BooksCompanion.insert(
            title: '空章测试',
            filePath: 'memory://empty-chapter.txt',
            format: 'txt',
            fileSize: 1,
          ),
        );
    await database.into(database.chapters).insert(
          ChaptersCompanion.insert(
            bookId: bookId,
            title: '第一章 空章',
            content: const Value(''),
            contentIndex: 0,
            sortOrder: 0,
          ),
        );
    await database.into(database.chapters).insert(
          ChaptersCompanion.insert(
            bookId: bookId,
            title: '第二章 正文',
            content: const Value('第二章正文。'),
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

    final flutterTts = _MockFlutterTts();
    when(() => flutterTts.getLanguages).thenAnswer((_) async => ['zh-CN']);
    when(() => flutterTts.getVoices).thenAnswer((_) async => const []);
    when(() => flutterTts.setLanguage(any())).thenAnswer((_) async => 1);
    when(() => flutterTts.setSpeechRate(any())).thenAnswer((_) async => 1);
    when(() => flutterTts.setVolume(any())).thenAnswer((_) async => 1);
    when(() => flutterTts.setPitch(any())).thenAnswer((_) async => 1);
    when(() => flutterTts.stop()).thenAnswer((_) async => 1);
    when(() => flutterTts.pause()).thenAnswer((_) async => 1);

    final container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(database),
        sharedPreferencesProvider.overrideWithValue(preferences),
        readerDataLoaderProvider.overrideWithValue(
          _MemoryReaderDataSource(
            ReaderData(
              book: book,
              chapters: chapters,
              chapterContents: const ['', ''],
              initialChapterIndex: 0,
            ),
          ),
        ),
        ttsServiceProvider.overrideWith(
          (ref) => TTSService(flutterTts: flutterTts),
        ),
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
      () => find.text('本章暂无正文').evaluate().isNotEmpty,
      reason: '空章节说明',
    );

    expect(find.text('本章暂无正文'), findsOneWidget);
    expect(find.text('下一章'), findsOneWidget);

    await tester.tap(find.text('下一章'));
    await tester.pump();

    expect(
      container.read(readerControllerProvider(bookId)).currentChapterIndex,
      1,
    );
    expect(find.text('本章暂无正文'), findsNothing);
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
