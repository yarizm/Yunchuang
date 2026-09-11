import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yunchuang/pages/reader/immersive_reader_shell.dart';
import 'package:yunchuang/pages/reader/reader_controller.dart';
import 'package:yunchuang/pages/reader/reader_toolbar.dart';
import 'package:yunchuang/services/screen_brightness_service.dart';

void main() {
  testWidgets('reader toolbar hide button hides navigation chrome',
      (tester) async {
    final controller = ReaderController(bookId: 42)
      ..chapterCount = 3
      ..setCurrentChapterIndex(1);
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
              toolbarBuilder: () => ReaderToolbar(
                chapterTitle: 'Chapter 2',
                currentChapter: 1,
                totalChapters: 3,
                onHide: () => controller.setToolbarVisible(false),
              ),
              readerBody: const SizedBox.expand(),
            ),
          ),
        ),
      ),
    );

    expect(controller.toolbarVisible, isTrue);
    expect(find.byTooltip('收起导航栏'), findsOneWidget);

    await tester.tap(find.byTooltip('收起导航栏'));
    await tester.pumpAndSettle();

    expect(controller.toolbarVisible, isFalse);
  });

  testWidgets('reader content inset stays stable across toolbar toggles',
      (tester) async {
    final controller = ReaderController(bookId: 48)..chapterCount = 1;
    addTearDown(controller.dispose);
    var observedTopPadding = -1.0;
    var readerBodyBuilds = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(400, 800),
            padding: EdgeInsets.only(top: 24),
          ),
          child: Scaffold(
            body: ImmersiveReaderShell(
              controller: controller,
              toolbarBuilder: () => const ReaderToolbar(
                chapterTitle: 'Chapter 1',
                currentChapter: 0,
                totalChapters: 1,
              ),
              readerBody: Builder(
                builder: (context) {
                  readerBodyBuilds++;
                  observedTopPadding = MediaQuery.paddingOf(context).top;
                  return const SizedBox.expand();
                },
              ),
            ),
          ),
        ),
      ),
    );

    // 系统状态栏 24 + 顶部工具栏 84。
    expect(observedTopPadding, 108);
    final buildsAfterFirstFrame = readerBodyBuilds;

    // 隐藏工具栏不得改变正文的顶部预留：padding 抖动会让滚动模式瞬间跳位，
    // 并触发分页模式重排整章。
    controller.setToolbarVisible(false);
    await tester.pump();

    expect(observedTopPadding, 108);
    expect(readerBodyBuilds, buildsAfterFirstFrame);

    controller.setToolbarVisible(true);
    await tester.pump();

    expect(observedTopPadding, 108);
    expect(readerBodyBuilds, buildsAfterFirstFrame);
  });

  testWidgets('tapping reader body outside chrome hides navigation chrome',
      (tester) async {
    final controller = ReaderController(bookId: 43)
      ..chapterCount = 3
      ..setCurrentChapterIndex(1);
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
              toolbarBuilder: () => ReaderToolbar(
                chapterTitle: 'Chapter 2',
                currentChapter: 1,
                totalChapters: 3,
                onHide: () => controller.setToolbarVisible(false),
              ),
              readerBody: const SizedBox.expand(),
            ),
          ),
        ),
      ),
    );

    expect(controller.toolbarVisible, isTrue);

    await tester.tapAt(const Offset(200, 400));
    await tester.pumpAndSettle();

    expect(controller.toolbarVisible, isFalse);
  });

  testWidgets('short tapping reader body restores hidden navigation chrome',
      (tester) async {
    final controller = ReaderController(bookId: 44)
      ..chapterCount = 3
      ..setCurrentChapterIndex(1)
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
              toolbarBuilder: () => const ReaderToolbar(
                chapterTitle: 'Chapter 2',
                currentChapter: 1,
                totalChapters: 3,
              ),
              readerBody: const SizedBox.expand(),
            ),
          ),
        ),
      ),
    );

    expect(controller.toolbarVisible, isFalse);

    final longPress = await tester.startGesture(const Offset(200, 400));
    await tester.pump(const Duration(milliseconds: 600));
    await longPress.up();
    await tester.pumpAndSettle();

    expect(controller.toolbarVisible, isFalse);

    await tester.tapAt(const Offset(200, 400));
    await tester.pumpAndSettle();

    expect(controller.toolbarVisible, isTrue);
  });

  testWidgets('reader tap exclusion does not restore hidden navigation chrome',
      (tester) async {
    final controller = ReaderController(bookId: 45)
      ..chapterCount = 3
      ..setCurrentChapterIndex(1)
      ..setToolbarVisible(false);
    final excludedKey = GlobalKey();
    var buttonTaps = 0;
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
              readerTapExclusionKeys: [excludedKey],
              toolbarBuilder: () => const ReaderToolbar(
                chapterTitle: 'Chapter 2',
                currentChapter: 1,
                totalChapters: 3,
              ),
              readerBody: Stack(
                children: [
                  const SizedBox.expand(),
                  Center(
                    child: ElevatedButton(
                      key: excludedKey,
                      onPressed: () => buttonTaps++,
                      child: const Text('excluded'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    expect(controller.toolbarVisible, isFalse);

    await tester.tap(find.text('excluded'));
    await tester.pumpAndSettle();

    expect(buttonTaps, 1);
    expect(controller.toolbarVisible, isFalse);

    await tester.tapAt(const Offset(200, 320));
    await tester.pumpAndSettle();

    expect(controller.toolbarVisible, isTrue);
  });

  testWidgets('left edge gesture adjusts and restores reading brightness',
      (tester) async {
    final controller = ReaderController(bookId: 46)
      ..chapterCount = 3
      ..setCurrentChapterIndex(1)
      ..setToolbarVisible(false);
    final brightness = _FakeBrightnessController(current: 0.4);
    double? savedBrightness;
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(size: Size(400, 800)),
          child: Scaffold(
            body: ImmersiveReaderShell(
              controller: controller,
              readingBrightness: 0.4,
              brightnessGestureEnabled: true,
              brightnessController: brightness,
              onBrightnessChanged: (value) => savedBrightness = value,
              toolbarBuilder: () => const ReaderToolbar(
                chapterTitle: 'Chapter 2',
                currentChapter: 1,
                totalChapters: 3,
              ),
              readerBody: const SizedBox.expand(),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byKey(const Key('brightness-gesture-zone')), findsOneWidget);
    expect(brightness.values, contains(0.4));

    await tester.drag(
      find.byKey(const Key('brightness-gesture-zone')),
      const Offset(0, -240),
    );
    await tester.pump();

    expect(savedBrightness, isNotNull);
    expect(savedBrightness!, greaterThan(0.4));
    expect(brightness.values.last, closeTo(savedBrightness!, 0.001));
    expect(controller.toolbarVisible, isFalse);

    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    await tester.pump();
    expect(brightness.resetCount, greaterThan(0));
  });

  testWidgets('line focus dims surrounding text without blocking reader taps',
      (tester) async {
    final controller = ReaderController(bookId: 47)
      ..chapterCount = 3
      ..setCurrentChapterIndex(1)
      ..setToolbarVisible(false);
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(size: Size(400, 800)),
          child: Scaffold(
            body: ImmersiveReaderShell(
              controller: controller,
              lineFocusEnabled: true,
              lineFocusLineCount: 3,
              lineFocusLineHeight: 30,
              lineFocusDimAmount: 0.4,
              toolbarBuilder: () => const ReaderToolbar(
                chapterTitle: 'Chapter 2',
                currentChapter: 1,
                totalChapters: 3,
              ),
              readerBody: const SizedBox.expand(),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byKey(const Key('line-focus-overlay')), findsOneWidget);
    expect(find.byKey(const Key('line-focus-top-dim')), findsOneWidget);
    expect(find.byKey(const Key('line-focus-bottom-dim')), findsOneWidget);

    await tester.tapAt(const Offset(200, 400));
    await tester.pumpAndSettle();
    expect(controller.toolbarVisible, isTrue);
  });

  testWidgets('expanded reader toolbar exposes location history actions',
      (tester) async {
    var backCount = 0;
    var forwardCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(size: Size(400, 800)),
          child: Scaffold(
            body: ReaderToolbar(
              chapterTitle: 'Chapter 2',
              currentChapter: 1,
              totalChapters: 3,
              isExpanded: true,
              onHistoryBack: () => backCount++,
              onHistoryForward: () => forwardCount++,
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byTooltip('返回上一位置'));
    await tester.tap(find.byTooltip('前进到下一位置'));
    await tester.pump();

    expect(backCount, 1);
    expect(forwardCount, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('expanded toolbar shows enabled translation in a 2 by 4 layout',
      (tester) async {
    tester.view.physicalSize = const Size(393, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var translationTaps = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ReaderToolbar(
            chapterTitle: '章节标题',
            currentChapter: 0,
            totalChapters: 2,
            isExpanded: true,
            translationEnabled: true,
            onTranslation: () => translationTaps++,
          ),
        ),
      ),
    );

    expect(find.byKey(const Key('reader-translation-tool')), findsOneWidget);
    expect(find.byTooltip('翻译（已启用）'), findsOneWidget);
    expect(find.text('后退'), findsOneWidget);
    expect(find.text('前进'), findsOneWidget);
    expect(find.text('目录'), findsOneWidget);
    expect(find.text('AI'), findsOneWidget);
    expect(find.text('翻译'), findsOneWidget);
    expect(find.text('朗读'), findsOneWidget);
    expect(find.text('设置'), findsOneWidget);
    expect(find.text('收起'), findsOneWidget);

    await tester.tap(find.byKey(const Key('reader-translation-tool')));
    await tester.pump();

    expect(translationTaps, 1);
    expect(tester.takeException(), isNull);
  });
}

class _FakeBrightnessController implements ReaderBrightnessController {
  double current;
  int resetCount = 0;
  final List<double> values = [];

  _FakeBrightnessController({required this.current});

  @override
  Future<double> getCurrentBrightness() async => current;

  @override
  Future<void> resetBrightness() async {
    resetCount++;
  }

  @override
  Future<void> setBrightness(double value) async {
    current = value;
    values.add(value);
  }
}
