import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yunchuang/database/app_database.dart';
import 'package:yunchuang/pages/reader/epub_reader.dart';
import 'package:yunchuang/pages/reader/format_reader.dart';
import 'package:yunchuang/pages/reader/paged_reader.dart';
import 'package:yunchuang/pages/reader/reader_controller.dart';
import 'package:yunchuang/pages/reader/reader_toc_sheet.dart';
import 'package:yunchuang/pages/reader/txt_reader.dart';

class _FakeNoteDao {
  Future<List<dynamic>> bookmarksForBook(int bookId) async => const [];
}

void main() {
  test('scroll progress does not notify the whole reader controller', () {
    final controller = ReaderController(bookId: 1);
    addTearDown(controller.dispose);
    var controllerNotifications = 0;
    var progressNotifications = 0;
    controller.addListener(() => controllerNotifications++);
    controller.scrollPositionListenable.addListener(
      () => progressNotifications++,
    );

    for (var index = 1; index <= 100; index++) {
      controller.setScrollPosition(index / 100);
    }

    expect(controllerNotifications, 0);
    expect(progressNotifications, greaterThan(0));
    expect(controller.scrollPosition, 1);
  });

  testWidgets('large TXT chapters build a virtualized subset', (tester) async {
    final content = List.generate(
      5000,
      (index) => '第$index段：用于验证长文本不会一次创建全部渲染节点。\n',
    ).join();
    final scrollController = ScrollController();
    addTearDown(scrollController.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TxtReader(
            content: content,
            scrollController: scrollController,
          ),
        ),
      ),
    );

    expect(content.length, greaterThan(100000));
    expect(find.byType(SelectableText), findsWidgets);
    expect(find.byType(SelectableText).evaluate().length, lessThan(80));
  });

  testWidgets('long TXT paragraphs are split into bounded render chunks',
      (tester) async {
    final content = List.filled(5000, '长段落内容').join();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TxtReader(content: content, paragraphIndent: 0),
        ),
      ),
    );

    final renderedLengths = tester
        .widgetList<SelectableText>(find.byType(SelectableText))
        .map((text) => text.textSpan?.toPlainText().length ?? 0);
    expect(renderedLengths, isNotEmpty);
    expect(renderedLengths.every((length) => length <= 1200), isTrue);
  });

  testWidgets('TXT scroll reader applies paragraph spacing to layout',
      (tester) async {
    const content = '第一段正文。\n第二段正文。\n第三段正文。';

    Future<double> paragraphGap(double spacing) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TxtReader(
              content: content,
              paragraphSpacing: spacing,
              paragraphIndent: 0,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final first = find.text('第一段正文。');
      final second = find.text('第二段正文。');
      return tester.getTopLeft(second).dy - tester.getBottomLeft(first).dy;
    }

    final compactGap = await paragraphGap(0);
    final spaciousGap = await paragraphGap(28);

    expect(spaciousGap, greaterThan(compactGap + 20));
  });

  testWidgets('TXT scroll reader applies adjustable top content padding',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(
            padding: EdgeInsets.only(top: 24),
          ),
          child: Scaffold(
            body: TxtReader(
              content: 'Top padding should avoid display cutouts.',
              topContentPadding: 32,
            ),
          ),
        ),
      ),
    );

    final listView = tester.widget<ListView>(find.byType(ListView));
    final padding = listView.padding as EdgeInsets;
    expect(padding.top, 56);
  });

  testWidgets('EPUB scroll reader applies paragraph spacing to layout',
      (tester) async {
    const content = '<p>第一段正文。</p><p>第二段正文。</p><p>第三段正文。</p>';

    Future<double> paragraphGap(double spacing) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EpubReader(
              content: content,
              paragraphSpacing: spacing,
              paragraphIndent: 0,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final first = find.text('第一段正文。');
      final second = find.text('第二段正文。');
      return tester.getTopLeft(second).dy - tester.getBottomLeft(first).dy;
    }

    final compactGap = await paragraphGap(0);
    final spaciousGap = await paragraphGap(28);

    expect(spaciousGap, greaterThan(compactGap + 20));
  });

  testWidgets('large EPUB chapters build a virtualized subset', (tester) async {
    final content = List.generate(
      5000,
      (index) => '<p>第$index段：用于验证 EPUB 长章节不会一次创建全部渲染节点。</p>',
    ).join();
    final scrollController = ScrollController();
    addTearDown(scrollController.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: EpubReader(
            content: content,
            scrollController: scrollController,
          ),
        ),
      ),
    );

    expect(content.length, greaterThan(100000));
    expect(find.byType(SelectableText), findsWidgets);
    expect(find.byType(SelectableText).evaluate().length, lessThan(80));
  });

  testWidgets('long EPUB paragraphs are split into bounded render chunks',
      (tester) async {
    final content = '<p>${List.filled(5000, '长段落内容').join()}</p>';

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: EpubReader(content: content, paragraphIndent: 0),
        ),
      ),
    );

    final renderedLengths = tester
        .widgetList<SelectableText>(find.byType(SelectableText))
        .map((text) => text.textSpan?.toPlainText().length ?? 0);
    expect(renderedLengths, isNotEmpty);
    expect(renderedLengths.every((length) => length <= 1200), isTrue);
  });

  testWidgets('large table of contents only builds visible chapter rows',
      (tester) async {
    final chapters = List.generate(
      10000,
      (index) => Chapter(
        id: index + 1,
        bookId: 1,
        title: '第 ${index + 1} 章',
        contentIndex: index,
        sortOrder: index,
      ),
    );
    final controller = ReaderController(bookId: 1)
      ..chapterCount = chapters.length
      ..setCurrentChapterIndex(9000);
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            return Scaffold(
              body: TextButton(
                onPressed: () => ReaderTocSheet.show(
                  context,
                  chapters: chapters,
                  controller: controller,
                  noteDao: _FakeNoteDao(),
                  onChapterSelected: (_) {},
                  onBookmarkSelected: (_, __) {},
                ),
                child: const Text('打开目录'),
              ),
            );
          },
        ),
      ),
    );
    await tester.tap(find.text('打开目录'));
    await tester.pumpAndSettle();

    final builtRows = find
        .byWidgetPredicate(
          (widget) =>
              widget.key is ValueKey<String> &&
              (widget.key! as ValueKey<String>)
                  .value
                  .startsWith('toc-chapter-'),
        )
        .evaluate()
        .length;
    expect(builtRows, lessThan(30));
    expect(
      find.byKey(const ValueKey('toc-chapter-9000')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('toc-global-progress')),
      findsOneWidget,
    );
    expect(find.text('第 9001 / 10000 章'), findsOneWidget);

    final progress = tester.widget<Slider>(
      find.byKey(const ValueKey('toc-global-progress')),
    );
    progress.onChanged!(1234);
    await tester.pump();

    expect(find.text('第 1235 / 10000 章'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('toc-chapter-1234')),
      findsOneWidget,
    );
  });

  testWidgets('paged reader configures horizontal page navigation',
      (tester) async {
    final content = List.filled(1000, '分页模式应当左右翻页，而不是上下滚动。').join();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PagedReader(
            content: content,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final pageView = tester.widget<PageView>(find.byType(PageView));
    expect(pageView.scrollDirection, Axis.horizontal);
    expect(pageView.physics, isA<PageScrollPhysics>());
    for (final text in tester.widgetList<SelectableText>(
      find.byType(SelectableText),
    )) {
      expect(text.scrollPhysics, isA<NeverScrollableScrollPhysics>());
    }
  });

  testWidgets('paged reader applies selected font family to page text',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PagedReader(
            content: 'Font family should reach rendered text.',
            fontFamily: 'monospace',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final text = tester.widget<SelectableText>(find.byType(SelectableText));
    expect(text.style?.fontFamily, 'monospace');
  });

  testWidgets('paged reader first page shows chapter title and body',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PagedReader(
            chapterTitle: 'Chapter Title',
            content: 'First body paragraph.\nSecond body paragraph.',
            paragraphIndent: 0,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Chapter Title'), findsOneWidget);
    expect(find.text('First body paragraph.'), findsOneWidget);
  });

  testWidgets('paged reader highlights a locator text range', (tester) async {
    const content = 'before target after';
    final start = content.indexOf('target');
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PagedReader(
            content: content,
            locatorHighlightStart: start,
            locatorHighlightEnd: start + 'target'.length,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final selectable = tester.widget<SelectableText>(
      find.byType(SelectableText).first,
    );
    final spans = (selectable.textSpan as TextSpan).children!;
    final targetSpan = spans
        .whereType<TextSpan>()
        .singleWhere((span) => span.text == 'target');

    expect(targetSpan.style?.backgroundColor, isNotNull);
  });

  testWidgets('paged reader follows and highlights the active TTS sentence',
      (tester) async {
    final content = List.generate(500, (index) => 'Sentence $index.').join(' ');
    int? activeSentenceIndex;
    late StateSetter rebuild;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              rebuild = setState;
              return PagedReader(
                content: content,
                activeSentenceIndex: activeSentenceIndex,
              );
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    rebuild(() => activeSentenceIndex = 450);
    await tester.pumpAndSettle();

    final pageIndicator = tester
        .widgetList<Text>(find.byType(Text))
        .map((text) => text.data ?? '')
        .firstWhere((text) => RegExp(r'^\d+ / \d+$').hasMatch(text));
    final currentPage = int.parse(pageIndicator.split('/').first.trim());
    final hasHighlight = tester
        .widgetList<SelectableText>(find.byType(SelectableText))
        .map((text) => text.textSpan)
        .whereType<TextSpan>()
        .expand((span) => span.children ?? const <InlineSpan>[])
        .whereType<TextSpan>()
        .any((span) => span.style?.backgroundColor != null);

    expect(currentPage, greaterThan(1));
    expect(hasHighlight, isTrue);
  });

  testWidgets('paged reader curl effect paints a page curl overlay',
      (tester) async {
    final content = List.filled(1200, '仿真翻页效果需要页边阴影和折痕。').join();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PagedReader(
            content: content,
            pageTurnEffect: 'curl',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final pageView = tester.widget<PageView>(find.byType(PageView));
    final controller = pageView.controller!;
    controller.jumpTo(controller.position.viewportDimension * 0.35);
    await tester.pump();

    expect(find.byKey(const ValueKey('page_curl_overlay')), findsWidgets);
    final perspective = tester.widget<Transform>(
      find.byKey(const ValueKey('page_curl_transform-0')),
    );
    // Rotation composes with the configured 0.0018 perspective entry, so the
    // resulting matrix value varies slightly with the drag angle.
    expect(perspective.transform.entry(3, 2), inInclusiveRange(0.001, 0.002));
    expect(perspective.transform.entry(0, 0), lessThan(1));
  });

  testWidgets('paged reader plain effect keeps curl overlay disabled',
      (tester) async {
    final content =
        List.filled(1200, 'Plain page turn should avoid curl overlay.').join();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PagedReader(
            content: content,
            pageTurnEffect: 'plain',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final pageView = tester.widget<PageView>(find.byType(PageView));
    final controller = pageView.controller!;
    controller.jumpTo(controller.position.viewportDimension * 0.35);
    await tester.pump();

    expect(find.byKey(const ValueKey('page_curl_overlay')), findsNothing);
  });

  testWidgets('paged reader updates page number and text anchor on every turn',
      (tester) async {
    final content = List.filled(1000, '翻页后应立即更新页码和阅读锚点。').join();
    final positions = <double>[];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PagedReader(
            content: content,
            onPositionChanged: positions.add,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    String pageIndicator() => tester
        .widgetList<Text>(find.byType(Text))
        .map((text) => text.data ?? '')
        .firstWhere((text) => RegExp(r'^\d+ / \d+$').hasMatch(text));

    expect(pageIndicator(), startsWith('1 / '));
    final pageView = tester.widget<PageView>(find.byType(PageView));
    pageView.controller!.jumpToPage(1);
    await tester.pumpAndSettle();

    expect(pageIndicator(), startsWith('2 / '));
    expect(positions, isNotEmpty);
    expect(positions.last, greaterThan(0));
  });

  testWidgets('paged reader follows an updated external reading position',
      (tester) async {
    final content = List.filled(1200, '引用跳转应定位到包含命中内容的页面。').join();
    var initialPosition = 0.0;
    late StateSetter rebuild;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              rebuild = setState;
              return PagedReader(
                content: content,
                initialPosition: initialPosition,
              );
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    rebuild(() => initialPosition = 0.8);
    await tester.pumpAndSettle();

    final pageIndicator = tester
        .widgetList<Text>(find.byType(Text))
        .map((text) => text.data ?? '')
        .firstWhere((text) => RegExp(r'^\d+ / \d+$').hasMatch(text));
    final currentPage = int.parse(pageIndicator.split('/').first.trim());
    expect(currentPage, greaterThan(1));
  });

  testWidgets('paged reader discards stale pagination after content changes',
      (tester) async {
    final largeContent = List.generate(
      20000,
      (index) =>
          'Old chapter paragraph $index keeps the first pagination busy.',
    ).join('\n');

    Widget reader(String content, String title) {
      return MaterialApp(
        home: Scaffold(
          body: PagedReader(
            content: content,
            chapterTitle: title,
          ),
        ),
      );
    }

    await tester.pumpWidget(reader(largeContent, 'Old chapter'));
    await tester.pumpWidget(
      reader('The replacement chapter is intentionally short.', 'New chapter'),
    );
    await tester.pumpAndSettle();

    expect(find.text('New chapter'), findsOneWidget);
    expect(
      find.textContaining('The replacement chapter is intentionally short.'),
      findsOneWidget,
    );
    final pageView = tester.widget<PageView>(find.byType(PageView));
    expect(pageView.childrenDelegate.estimatedChildCount, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('paged reader can request the next chapter from the last page',
      (tester) async {
    final content = List.filled(1200, '最后一页继续翻动应进入下一章。').join();
    var advanceRequests = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PagedReader(
            content: content,
            onAdvanceBeyondLast: () => advanceRequests++,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final pageIndicator = tester
        .widgetList<Text>(find.byType(Text))
        .map((text) => text.data ?? '')
        .firstWhere((text) => RegExp(r'^\d+ / \d+$').hasMatch(text));
    final pageCount = int.parse(pageIndicator.split('/').last.trim());
    final pageView = tester.widget<PageView>(find.byType(PageView));
    pageView.controller!.jumpToPage(pageCount - 1);
    await tester.pumpAndSettle();

    await tester.drag(find.byType(PageView), const Offset(-500, 0));
    await tester.pump(const Duration(milliseconds: 220));

    expect(advanceRequests, 1);
  });

  testWidgets('paged reader delays chapter changes until the edge drag ends',
      (tester) async {
    final content = List.filled(
      1200,
      'Chapter boundary changes should wait for the page drag to finish.',
    ).join();
    var advanceRequests = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PagedReader(
            content: content,
            onAdvanceBeyondLast: () => advanceRequests++,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final pageIndicator = tester
        .widgetList<Text>(find.byType(Text))
        .map((text) => text.data ?? '')
        .firstWhere((text) => RegExp(r'^\d+ / \d+$').hasMatch(text));
    final pageCount = int.parse(pageIndicator.split('/').last.trim());
    final pageView = tester.widget<PageView>(find.byType(PageView));
    pageView.controller!.jumpToPage(pageCount - 1);
    await tester.pumpAndSettle();

    final center = tester.getCenter(find.byType(PageView));
    final gesture = await tester.startGesture(center);
    await gesture.moveBy(const Offset(-500, 0));
    await tester.pump(const Duration(milliseconds: 100));

    expect(advanceRequests, 0);

    await gesture.up();
    await tester.pump(const Duration(milliseconds: 100));
    expect(advanceRequests, 0);

    await tester.pump(const Duration(milliseconds: 100));
    expect(advanceRequests, 1);
  });

  testWidgets(
      'paged reader can request the previous chapter from the first page',
      (tester) async {
    final content = List.filled(
      1200,
      'Dragging backward on the first page should open the previous chapter.',
    ).join();
    var retreatRequests = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PagedReader(
            content: content,
            onRetreatBeforeFirst: () => retreatRequests++,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.drag(find.byType(PageView), const Offset(500, 0));
    await tester.pump(const Duration(milliseconds: 220));

    expect(retreatRequests, 1);
  });

  test('switching reading modes preserves the canonical position', () {
    final controller = ReaderController(bookId: 2);
    addTearDown(controller.dispose);

    controller.setScrollPosition(0.63);
    controller.setReadingMode(ReadingMode.page);
    controller.setReadingMode(ReadingMode.scroll);

    expect(controller.scrollPosition, 0.63);
  });
}
