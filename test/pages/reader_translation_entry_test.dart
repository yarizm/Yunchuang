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
import 'package:yunchuang/providers/translation_provider.dart';
import 'package:yunchuang/services/translation_service.dart';
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

  testWidgets(
      'translation tool explains setup and enabled tap never sends text',
      (tester) async {
    tester.view.physicalSize = const Size(393, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    SharedPreferences.setMockInitialValues({'keepScreenOn': false});
    final preferences = await SharedPreferences.getInstance();
    final database = AppDatabase.connect(NativeDatabase.memory());
    final bookId = await database.into(database.books).insert(
          BooksCompanion.insert(
            title: '翻译入口测试',
            filePath: 'memory://translation.txt',
            format: 'txt',
            fileSize: 1,
          ),
        );
    final chapterId = await database.into(database.chapters).insert(
          ChaptersCompanion.insert(
            bookId: bookId,
            title: '第一章',
            contentIndex: 0,
            sortOrder: 0,
          ),
        );
    final book = await (database.select(database.books)
          ..where((row) => row.id.equals(bookId)))
        .getSingle();
    final chapter = await (database.select(database.chapters)
          ..where((row) => row.id.equals(chapterId)))
        .getSingle();

    final flutterTts = _MockFlutterTts();
    when(() => flutterTts.getLanguages).thenAnswer((_) async => ['zh-CN']);
    when(() => flutterTts.getVoices).thenAnswer((_) async => const []);
    when(() => flutterTts.setLanguage(any())).thenAnswer((_) async => 1);
    when(() => flutterTts.setSpeechRate(any())).thenAnswer((_) async => 1);
    when(() => flutterTts.setVolume(any())).thenAnswer((_) async => 1);
    when(() => flutterTts.setPitch(any())).thenAnswer((_) async => 1);
    when(() => flutterTts.stop()).thenAnswer((_) async => 1);
    when(() => flutterTts.pause()).thenAnswer((_) async => 1);
    final ttsService = TTSService(flutterTts: flutterTts);
    var translationRequests = 0;
    final translationService = TranslationService.withProviderLoader(() async {
      translationRequests++;
      return null;
    });
    final readerData = ReaderData(
      book: book,
      chapters: [chapter],
      chapterContents: const ['这是供选择和翻译的正文。'],
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
        translationServiceProvider.overrideWithValue(translationService),
      ],
    );
    final readerController = container.read(readerControllerProvider(bookId))
      ..setToolbarExpanded(true);
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
      () => find.byTooltip('配置在线翻译').evaluate().isNotEmpty,
      reason: 'disabled translation tool',
    );

    await tester.tap(find.byKey(const Key('reader-translation-tool')));
    await tester.pumpAndSettle();
    expect(find.text('启用在线翻译'), findsOneWidget);
    expect(find.textContaining('选中的正文将发送'), findsOneWidget);
    expect(translationRequests, 0);

    await tester.tap(find.byKey(const Key('open-translation-settings')));
    await tester.pumpAndSettle();
    expect(find.text('在线翻译'), findsWidgets);
    expect(find.byKey(const Key('online-translation-switch')), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();
    await container.read(translationSettingsProvider.notifier).setEnabled(true);
    await tester.pump();
    expect(find.byTooltip('翻译（已启用）'), findsOneWidget);

    await tester.tap(find.byKey(const Key('reader-translation-tool')));
    await tester.pump();

    expect(readerController.toolbarVisible, isFalse);
    expect(find.text('长按选择正文，然后点击“翻译”。'), findsOneWidget);
    expect(translationRequests, 0);
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
