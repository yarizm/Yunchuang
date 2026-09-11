import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yunchuang/database/app_database.dart';
import 'package:yunchuang/models/reading_background.dart';
import 'package:yunchuang/pages/reader/reader_data_loader.dart';
import 'package:yunchuang/pages/reader/reader_page.dart';
import 'package:yunchuang/providers/database_provider.dart';
import 'package:yunchuang/providers/preferences_provider.dart';
import 'package:yunchuang/services/tts_service.dart';
import 'package:yunchuang/theme/app_theme.dart';

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

  /// 挂起阅读器，返回它的 Scaffold 底色与正文取到的主题。
  Future<(Color background, ThemeData theme)> pumpReader(
    WidgetTester tester, {
    required Map<String, Object> initialPreferences,
  }) async {
    tester.view.physicalSize = const Size(393, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    SharedPreferences.setMockInitialValues({
      'keepScreenOn': false,
      ...initialPreferences,
    });
    final preferences = await SharedPreferences.getInstance();
    final database = AppDatabase.connect(NativeDatabase.memory());
    final bookId = await database.into(database.books).insert(
          BooksCompanion.insert(
            title: '纸张测试',
            filePath: 'memory://paper.txt',
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

    final container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(database),
        sharedPreferencesProvider.overrideWithValue(preferences),
        readerDataLoaderProvider.overrideWithValue(
          _MemoryReaderDataSource(
            ReaderData(
              book: book,
              chapters: [chapter],
              chapterContents: const ['芸香草能防蠹，古人拿它护书。'],
              initialChapterIndex: 0,
            ),
          ),
        ),
        ttsServiceProvider.overrideWith((ref) => TTSService(
              flutterTts: flutterTts,
            )),
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
        // 全局主题固定为日间，好和纸张的效果区分开。
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: ReaderPage(bookId: bookId),
        ),
      ),
    );
    // 加载中的那一屏也是个 Scaffold，但没设 backgroundColor。等到设了色的
    // 那个出现，就说明正文已经就位。
    final readerScaffold = find
        .descendant(
          of: find.byType(ReaderPage),
          matching: find.byType(Scaffold),
        )
        .first;
    Color? background;
    for (var attempt = 0; attempt < 100; attempt++) {
      await tester.pump(const Duration(milliseconds: 50));
      if (readerScaffold.evaluate().isEmpty) continue;
      background = tester.widget<Scaffold>(readerScaffold).backgroundColor;
      if (background != null) break;
    }
    if (background == null) fail('阅读器没有加载出正文');

    return (background, Theme.of(tester.element(readerScaffold)));
  }

  testWidgets('默认跟随主题时正文底色仍是主题的 surface', (tester) async {
    final (background, theme) =
        await pumpReader(tester, initialPreferences: const {});

    expect(background, AppTheme.lightTheme.colorScheme.surface);
    expect(theme.brightness, Brightness.light);
  });

  // 这一条是整个功能的意义所在：全局还是日间主题，正文已经是黑底。
  testWidgets('选了纯黑纸时正文变黑底，全局主题不受影响', (tester) async {
    final ink = ReaderPaper.presetById('ink')!;
    final (background, theme) = await pumpReader(
      tester,
      initialPreferences: const {'readerPaperId': 'ink'},
    );

    expect(background, ink.background);
    expect(theme.colorScheme.surface, ink.background);
    expect(theme.colorScheme.onSurface, ink.foreground);
    // 正文亮度翻成暗色，工具栏和目录面板才会跟着一起变。
    expect(theme.brightness, Brightness.dark);
  });

  testWidgets('自定义底色按存下来的色值生效', (tester) async {
    const picked = Color(0xFF3A5F4B);
    final (background, theme) = await pumpReader(
      tester,
      initialPreferences: {
        'readerPaperId': ReaderPaper.customId,
        'readerPaperColor': picked.toARGB32(),
      },
    );

    expect(background, picked);
    expect(
      ReaderPaper.contrastRatio(
        theme.colorScheme.onSurface,
        theme.colorScheme.surface,
      ),
      greaterThanOrEqualTo(4.5),
    );
  });

  // 存了 custom 却没有色值（备份只恢复了一半、prefs 被改坏），不该黑屏。
  testWidgets('自定义纸缺少色值时退回跟随主题', (tester) async {
    final (background, _) = await pumpReader(
      tester,
      initialPreferences: {'readerPaperId': ReaderPaper.customId},
    );

    expect(background, AppTheme.lightTheme.colorScheme.surface);
  });
}
