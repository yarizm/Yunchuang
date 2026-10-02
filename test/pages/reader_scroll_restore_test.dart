import 'package:drift/drift.dart' show OrderingTerm;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yunchuang/database/app_database.dart';
import 'package:yunchuang/pages/reader/epub_reader.dart';
import 'package:yunchuang/parsers/epub_parser.dart';
import 'package:yunchuang/pages/reader/reader_controller.dart';
import 'package:yunchuang/pages/reader/reader_data_loader.dart';
import 'package:yunchuang/pages/reader/reader_page.dart';
import 'package:yunchuang/pages/reader/reader_scroll_controller.dart';
import 'package:yunchuang/pages/reader/txt_reader.dart';
import 'package:yunchuang/providers/database_provider.dart';
import 'package:yunchuang/providers/preferences_provider.dart';
import 'package:yunchuang/services/tts_media_session.dart';
import 'package:yunchuang/services/tts_service.dart';

class _MockFlutterTts extends Mock implements FlutterTts {}

class _MemoryReaderDataSource implements ReaderDataSource {
  const _MemoryReaderDataSource(this.data);

  final ReaderData data;

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

/// 段落高度差得很远：开头一串短段、中间长段、结尾一串对话。懒布局按开头
/// 那几段估出来的总高度和真实值差好几倍，旧的按比例恢复就是在这种章节上抽动。
String _unevenChapter() {
  return [
    for (var i = 0; i < 60; i++) '短$i。',
    for (var i = 0; i < 120; i++)
      '长段$i${List.filled(90, '这是很长的一段叙述文字。').join()}',
    for (var i = 0; i < 200; i++) '对话$i：“嗯。”',
  ].join('\n');
}

/// 视口顶部留白下面那一行所在的正文块，去掉段首缩进。
String _textAtReadingLine(WidgetTester tester, Finder reader) {
  final listFinder =
      find.descendant(of: reader, matching: find.byType(ListView));
  final list = tester.widget<ListView>(listFinder);
  final line =
      tester.getTopLeft(listFinder).dy + (list.padding! as EdgeInsets).top;
  String? text;
  var bestTop = double.negativeInfinity;
  for (final element in find
      .descendant(of: reader, matching: find.byType(SelectableText))
      .evaluate()) {
    final box = element.renderObject! as RenderBox;
    final top = box.localToGlobal(Offset.zero).dy;
    if (top <= line + 0.5 && top > bestTop) {
      bestTop = top;
      final widget = element.widget as SelectableText;
      text = widget.data ?? widget.textSpan!.toPlainText();
    }
  }
  return text!.replaceFirst(RegExp('^　+'), '');
}

/// 阅读线到它所在正文块顶部的距离，用来比较两次落点是否同一行。
double _readingLineInset(WidgetTester tester, Finder reader) {
  final listFinder =
      find.descendant(of: reader, matching: find.byType(ListView));
  final list = tester.widget<ListView>(listFinder);
  final line =
      tester.getTopLeft(listFinder).dy + (list.padding! as EdgeInsets).top;
  var bestTop = double.negativeInfinity;
  for (final element in find
      .descendant(of: reader, matching: find.byType(SelectableText))
      .evaluate()) {
    final top =
        (element.renderObject! as RenderBox).localToGlobal(Offset.zero).dy;
    if (top <= line + 0.5 && top > bestTop) bestTop = top;
  }
  return line - bestTop;
}

void main() {
  testWidgets('opening a book lands on the saved paragraph without jitter',
      (tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final database = AppDatabase.connect(NativeDatabase.memory());
    final fixture = await tester.runAsync(() async {
      SharedPreferences.setMockInitialValues({'keepScreenOn': false});
      final preferences = await SharedPreferences.getInstance();
      final bookId = await database.into(database.books).insert(
            BooksCompanion.insert(
              title: '抽动测试',
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
    final text = _unevenChapter();
    const saved = 0.6;
    final readerData = ReaderData(
      book: book,
      chapters: fixture.chapters,
      chapterContents: [text],
      initialChapterIndex: 0,
      savedProgress: ReadingProgressData(
        bookId: book.id,
        chapterId: fixture.chapters.first.id,
        positionInChapter: saved,
        percentage: saved,
        totalReadingSeconds: 0,
        lastReadAt: DateTime(2026),
      ),
    );

    final flutterTts = _MockFlutterTts();
    when(() => flutterTts.getLanguages).thenAnswer((_) async => ['zh-CN']);
    when(() => flutterTts.getVoices).thenAnswer((_) async => []);
    when(() => flutterTts.setLanguage(any())).thenAnswer((_) async => 1);
    when(() => flutterTts.setSpeechRate(any())).thenAnswer((_) async => 1);
    when(() => flutterTts.setVolume(any())).thenAnswer((_) async => 1);
    when(() => flutterTts.setPitch(any())).thenAnswer((_) async => 1);
    when(() => flutterTts.stop()).thenAnswer((_) async => 1);

    final container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(database),
        sharedPreferencesProvider.overrideWithValue(fixture.preferences),
        readerDataLoaderProvider.overrideWithValue(
          _MemoryReaderDataSource(readerData),
        ),
        ttsServiceProvider
            .overrideWith((ref) => TTSService(flutterTts: flutterTts)),
        ttsMediaSessionProvider.overrideWithValue(TtsMediaSession()),
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
        child: MaterialApp(home: ReaderPage(bookId: book.id)),
      ),
    );

    final reader = find.byType(TxtReader);
    final offsetsWhileVisible = <double>[];
    var hiddenFrames = 0;
    for (var frame = 0; frame < 40; frame++) {
      await tester.pump(const Duration(milliseconds: 16));
      if (reader.evaluate().isEmpty) continue;
      final opacity = tester.widget<Opacity>(
        find.descendant(
          of: find.byType(HiddenWhileRestoring),
          matching: find.byType(Opacity),
        ),
      );
      if (opacity.opacity == 0) {
        // 一旦露出来就不能再藏回去重新定位。
        expect(offsetsWhileVisible, isEmpty);
        hiddenFrames++;
        continue;
      }
      offsetsWhileVisible.add(
        tester
            .state<ScrollableState>(
              // 每个 SelectableText 里还有一个横向 Scrollable，列表自己的在最前。
              find
                  .descendant(of: reader, matching: find.byType(Scrollable))
                  .first,
            )
            .position
            .pixels,
      );
    }

    // 估算两三帧就该收敛，藏太久就成了打开书时的一段空白。
    expect(hiddenFrames, inInclusiveRange(1, 6));
    expect(offsetsWhileVisible, isNotEmpty);
    expect(offsetsWhileVisible.first, greaterThan(0));
    expect(offsetsWhileVisible.toSet(), hasLength(1));

    final targetChar = (text.length * saved).round();
    final visible = _textAtReadingLine(tester, reader);
    final start = text.indexOf(visible);
    expect(start, isNonNegative);
    expect(targetChar, inInclusiveRange(start, start + visible.length));
    expect(
      container.read(readerControllerProvider(book.id)).scrollPosition,
      closeTo(saved, 0.002),
    );
  });

  testWidgets('TXT scroll position round-trips through character fraction',
      (tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final text = _unevenChapter();

    double? reported;
    final first = ReaderScrollController(
      onReadingPositionChanged: (position) => reported = position,
    );
    addTearDown(first.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TxtReader(
            key: const ValueKey('first'),
            content: text,
            chapterTitle: '第一章',
            scrollController: first,
          ),
        ),
      ),
    );
    // 一路往下拖，让中间段落都按真实高度布局一遍。
    for (var i = 0; i < 12; i++) {
      await tester.drag(find.byType(ListView), const Offset(0, -2500));
      await tester.pumpAndSettle();
    }
    final reader = find.byType(TxtReader);
    final savedText = _textAtReadingLine(tester, reader);
    final savedInset = _readingLineInset(tester, reader);
    expect(reported, isNotNull);
    expect(reported, inExclusiveRange(0, 1));

    final second = ReaderScrollController();
    addTearDown(second.dispose);
    second.jumpToFraction(reported!);
    expect(second.restoring.value, isTrue);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TxtReader(
            key: const ValueKey('second'),
            content: text,
            chapterTitle: '第一章',
            scrollController: second,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(second.restoring.value, isFalse);
    expect(_textAtReadingLine(tester, reader), savedText);
    expect(_readingLineInset(tester, reader), closeTo(savedInset, 3));
    expect(second.readingFraction, closeTo(reported!, 0.0005));

    // 章末记 1，恢复 1 就停在最底。
    second.jumpToFraction(1);
    await tester.pumpAndSettle();
    final position = second.position;
    expect(position.pixels, position.maxScrollExtent);
    expect(second.readingFraction, 1);

    // 章首连标题一起露出来。
    second.jumpToFraction(0);
    await tester.pumpAndSettle();
    expect(second.position.pixels, 0);
    expect(find.text('第一章'), findsOneWidget);
  });

  testWidgets('a restored position reads back as the same character',
      (tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final text = _unevenChapter();
    final paragraph = text.indexOf('长段70');

    // 读回少一个字的话，存下来的进度每开一次书就往回漂一个字。浮点误差
    // 只在部分位置出现，多试几个字。
    for (var step = 0; step < 16; step++) {
      final target = paragraph + 11 + step * 23;
      final controller = ReaderScrollController();
      addTearDown(controller.dispose);
      controller.jumpToFraction(target / text.length);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TxtReader(
              key: ValueKey(step),
              content: text,
              scrollController: controller,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        (controller.readingFraction! * text.length).round(),
        target,
        reason: 'char $target',
      );
    }
  });

  testWidgets('following a long unit scrolls its end into view',
      (tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    // 每段六百字，一段就是一个列表项，比一屏还高。
    final paragraphs = [
      for (var i = 0; i < 12; i++)
        '段$i${List.filled(25, '他沿着河岸慢慢走着，看见远处的灯火一点点亮起来。').join()}'
            .substring(0, 600),
    ];
    final text = paragraphs.join('\n');
    int startOf(int index) => index * 601;
    final controller = ReaderScrollController();
    addTearDown(controller.dispose);
    var hiddenFrames = 0;
    controller.restoring.addListener(() {
      if (controller.restoring.value) hiddenFrames++;
    });

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TxtReader(
            content: text,
            paragraphIndent: 0,
            scrollController: controller,
          ),
        ),
      ),
    );
    // 第三段后半截（最后一个朗读单位）的开头放在屏幕下部。
    final unitStart = startOf(3) + 300;
    final unitEnd = startOf(3) + 600;
    controller.jumpToFraction(unitStart / text.length);
    await tester.pumpAndSettle();
    controller.jumpTo(controller.position.pixels - 620);
    await tester.pumpAndSettle();
    hiddenFrames = 0;
    // 下一段还在缓存区外，没建出来。
    expect(find.textContaining('段4'), findsNothing);

    controller.reveal(unitStart, unitEnd);
    await tester.pumpAndSettle();

    final current = tester.getRect(find.textContaining('段3').first);
    expect(current.bottom, lessThanOrEqualTo(800 - (800 - 16) * 0.15 + 1));

    // 接着读下一段：平滑滚过去，不藏起正文。
    controller.reveal(startOf(4), startOf(4) + 300);
    await tester.pumpAndSettle();

    expect(hiddenFrames, 0);
    final next = tester.getRect(find.textContaining('段4').first);
    expect(next.top, greaterThanOrEqualTo(0));
    expect(next.top, lessThan(800 * 0.5));
  });

  testWidgets('following a unit just past the laid-out region animates there',
      (tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final paragraphs = [
      for (var i = 0; i < 12; i++)
        '段$i${List.filled(25, '他沿着河岸慢慢走着，看见远处的灯火一点点亮起来。').join()}'
            .substring(0, 600),
    ];
    final text = paragraphs.join('\n');
    final controller = ReaderScrollController();
    addTearDown(controller.dispose);
    var hiddenFrames = 0;
    controller.restoring.addListener(() {
      if (controller.restoring.value) hiddenFrames++;
    });
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TxtReader(
            content: text,
            paragraphIndent: 0,
            scrollController: controller,
          ),
        ),
      ),
    );
    controller.jumpToFraction((3 * 601 + 300) / text.length);
    await tester.pumpAndSettle();
    controller.jumpTo(controller.position.pixels - 620);
    await tester.pumpAndSettle();
    hiddenFrames = 0;
    expect(find.textContaining('段4'), findsNothing);

    // 直接跳到下一段（比如引擎没报完成就换段），它还没布局。
    controller.reveal(4 * 601, 4 * 601 + 300);
    await tester.pumpAndSettle();

    expect(hiddenFrames, 0);
    final next = tester.getRect(find.textContaining('段4').first);
    expect(next.top, greaterThanOrEqualTo(0));
    expect(next.top, lessThan(800 * 0.5));
  });

  testWidgets('EPUB scroll reader restores the same paragraph', (tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final html = [
      for (var i = 0; i < 40; i++) '<p>短$i。</p>',
      for (var i = 0; i < 80; i++)
        '<p>长段$i${List.filled(60, '这是很长的一段叙述文字。').join()}</p>',
      for (var i = 0; i < 120; i++) '<p>对话$i：“嗯。”</p>',
    ].join();

    final controller = ReaderScrollController();
    addTearDown(controller.dispose);
    controller.jumpToFraction(0.5);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: EpubReader(content: html, scrollController: controller),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // EPUB 正文的字符坐标就是去掉标签后的纯文本，和定位、朗读用的是同一份。
    final plainText = EpubParser.stripHtml(html);
    final targetChar = (plainText.length * 0.5).round();
    final visible = _textAtReadingLine(tester, find.byType(EpubReader));
    final start = plainText.indexOf(visible);
    expect(start, isNonNegative);
    expect(targetChar, inInclusiveRange(start, start + visible.length));
    expect(controller.readingFraction, closeTo(0.5, 0.002));
  });
}
