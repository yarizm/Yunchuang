import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yunchuang/database/app_database.dart';
import 'package:yunchuang/pages/home/book_card.dart';
import 'package:yunchuang/pages/reader/immersive_reader_shell.dart';
import 'package:yunchuang/pages/reader/reader_controller.dart';
import 'package:yunchuang/pages/reader/reader_toolbar.dart';

void main() {
  testWidgets('book card shows a numeric reading percentage', (tester) async {
    final now = DateTime(2026);
    final book = Book(
      id: 1,
      title: '测试书籍',
      author: '作者',
      filePath: 'book.txt',
      format: 'txt',
      fileSize: 1,
      createdAt: now,
      updatedAt: now,
    );
    final progress = ReadingProgressData(
      bookId: 1,
      chapterId: 1,
      positionInChapter: 0.2,
      percentage: 0.42,
      totalReadingSeconds: 1,
      lastReadAt: now,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 180,
              height: 320,
              child: BookCard(book: book, progress: progress),
            ),
          ),
        ),
      ),
    );

    expect(find.text('42%'), findsOneWidget);
    final indicator = tester
        .widget<LinearProgressIndicator>(find.byType(LinearProgressIndicator));
    expect(indicator.value, 0.42);
  });

  testWidgets('reader footer shows safe chapter and percentage labels',
      (tester) async {
    final controller = ReaderController(bookId: 1)
      ..chapterCount = 10
      ..setCurrentChapterIndex(2)
      ..setScrollPosition(0.5);
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(400, 800),
            padding: EdgeInsets.fromLTRB(12, 24, 16, 20),
          ),
          child: Scaffold(
            body: ImmersiveReaderShell(
              controller: controller,
              toolbarBuilder: SizedBox.shrink,
              readerBody: const SizedBox.expand(),
            ),
          ),
        ),
      ),
    );

    expect(find.text('第 3 / 10 章'), findsOneWidget);
    expect(find.text('25%'), findsOneWidget);

    final safeAreas = tester.widgetList<SafeArea>(find.byType(SafeArea));
    expect(
      safeAreas.any(
        (area) =>
            area.minimum.left >= 24 &&
            area.minimum.right >= 24 &&
            !area.top &&
            !area.bottom,
      ),
      isTrue,
    );
  });

  testWidgets('reader chrome reappears from a short body tap', (tester) async {
    final controller = ReaderController(bookId: 2)
      ..chapterCount = 8
      ..setToolbarVisible(false);
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(400, 800),
            padding: EdgeInsets.fromLTRB(12, 24, 16, 20),
          ),
          child: Scaffold(
            body: ImmersiveReaderShell(
              controller: controller,
              toolbarBuilder: SizedBox.expand,
              readerBody: const SizedBox.expand(),
            ),
          ),
        ),
      ),
    );

    expect(find.byIcon(Icons.keyboard_arrow_down), findsNothing);

    await tester.tapAt(const Offset(200, 400));
    await tester.pumpAndSettle();
    expect(controller.toolbarVisible, isTrue);
    expect(controller.toolbarExpanded, isFalse);
  });

  testWidgets('reader toolbar toggles between compact and expanded action rows',
      (tester) async {
    var expanded = false;

    Future<void> pumpToolbar() async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox.expand(
              child: ReaderToolbar(
                chapterTitle: '第一章 测试标题',
                currentChapter: 0,
                totalChapters: 12,
                isExpanded: expanded,
                onToggleExpanded: () {
                  expanded = !expanded;
                },
                onToc: () {},
                onAi: () {},
                onTts: () {},
                onSettings: () {},
              ),
            ),
          ),
        ),
      );
    }

    await pumpToolbar();
    expect(find.text('更多'), findsOneWidget);
    expect(find.text('收起'), findsNothing);
    expect(find.text('朗读'), findsNothing);

    await tester.tap(find.text('更多'));
    await tester.pump();
    await pumpToolbar();
    await tester.pumpAndSettle();

    expect(find.text('收起'), findsOneWidget);
    expect(find.text('朗读'), findsOneWidget);
    expect(find.text('AI'), findsOneWidget);
  });

  testWidgets('tts mini player offset grows when toolbar expands',
      (tester) async {
    final controller = ReaderController(bookId: 3)
      ..chapterCount = 6
      ..setToolbarVisible(true)
      ..setToolbarExpanded(true);
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(400, 800),
            padding: EdgeInsets.fromLTRB(12, 24, 16, 20),
          ),
          child: Scaffold(
            body: ImmersiveReaderShell(
              controller: controller,
              toolbarBuilder: SizedBox.expand,
              readerBody: const SizedBox.expand(),
              ttsMiniPlayer: const SizedBox(
                key: ValueKey('tts-mini-player'),
                height: 20,
              ),
            ),
          ),
        ),
      ),
    );

    final bottomLeft = tester.getBottomLeft(find.byKey(
      const ValueKey('tts-mini-player'),
    ));
    expect(bottomLeft.dy, lessThan(620));
  });
}
