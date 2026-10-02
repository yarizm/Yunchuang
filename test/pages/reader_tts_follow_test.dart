import 'dart:async';
import 'dart:typed_data';

import 'package:drift/drift.dart' show OrderingTerm;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yunchuang/database/app_database.dart';
import 'package:yunchuang/pages/reader/format_reader.dart';
import 'package:yunchuang/pages/reader/paged_reader.dart';
import 'package:yunchuang/pages/reader/reader_controller.dart';
import 'package:yunchuang/pages/reader/reader_data_loader.dart';
import 'package:yunchuang/pages/reader/reader_page.dart';
import 'package:yunchuang/pages/reader/reader_scroll_controller.dart';
import 'package:yunchuang/pages/reader/txt_reader.dart';
import 'package:yunchuang/providers/database_provider.dart';
import 'package:yunchuang/providers/preferences_provider.dart';
import 'package:yunchuang/services/external_tts.dart';
import 'package:yunchuang/services/tts_media_session.dart';
import 'package:yunchuang/services/tts_service.dart';
import 'package:yunchuang/utils/sentence_splitter.dart';

class _MockFlutterTts extends Mock implements FlutterTts {}

/// 第一段请求挂着不回，模拟慢的外部语音服务。
class _HeldSynthesizer implements SpeechSynthesizer {
  Completer<Uint8List>? pending;

  @override
  Future<Uint8List> synthesize(String text, {required double speed}) {
    if (pending != null) return Future.value(Uint8List(1));
    return (pending = Completer<Uint8List>()).future;
  }
}

class _SilentPlayer implements SpeechAudioPlayer {
  final played = <Uint8List>[];
  final _events = StreamController<void>.broadcast();

  @override
  Stream<void> get onCompleted => _events.stream;

  @override
  Stream<void> get onInterrupted => _events.stream;

  @override
  Future<void> play(Uint8List audio) async => played.add(audio);

  @override
  Future<void> pause() async {}

  @override
  Future<void> resume() async {}

  @override
  Future<void> stop() async {}

  @override
  Future<void> dispose() => _events.close();
}

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

/// 每段开头都带段号，按开头几个字就能在屏幕上找到它。
final _chapter = [
  for (var i = 0; i < 200; i++) '第$i段开头一句。这一段中间还有一句话，稍微长一些。第$i段最后一句。',
].join('\n');

class _Harness {
  _Harness(this.container, this.tts, this.spoken, this.complete);

  final ProviderContainer container;
  final TTSService tts;
  final List<String> spoken;
  final void Function() complete;
}

Future<_Harness> _openReader(
  WidgetTester tester, {
  required ReadingMode mode,
  TTSService Function(FlutterTts flutterTts)? createTts,
}) async {
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
            title: '跟读测试',
            filePath: 'memory://follow.txt',
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

  final flutterTts = _MockFlutterTts();
  void Function()? completion;
  final spoken = <String>[];
  when(() => flutterTts.setCompletionHandler(any())).thenAnswer((invocation) {
    completion = invocation.positionalArguments.single as void Function();
  });
  when(() => flutterTts.getLanguages).thenAnswer((_) async => ['zh-CN']);
  when(() => flutterTts.getVoices).thenAnswer((_) async => const []);
  when(() => flutterTts.setLanguage(any())).thenAnswer((_) async => 1);
  when(() => flutterTts.setSpeechRate(any())).thenAnswer((_) async => 1);
  when(() => flutterTts.setVolume(any())).thenAnswer((_) async => 1);
  when(() => flutterTts.setPitch(any())).thenAnswer((_) async => 1);
  when(() => flutterTts.stop()).thenAnswer((_) async => 1);
  when(() => flutterTts.pause()).thenAnswer((_) async => 1);
  when(() => flutterTts.speak(any())).thenAnswer((invocation) async {
    spoken.add(invocation.positionalArguments.single as String);
    return 1;
  });
  final tts = createTts?.call(flutterTts) ?? TTSService(flutterTts: flutterTts);

  final container = ProviderContainer(
    overrides: [
      databaseProvider.overrideWithValue(database),
      sharedPreferencesProvider.overrideWithValue(fixture.preferences),
      readerDataLoaderProvider.overrideWithValue(
        _MemoryReaderDataSource(
          ReaderData(
            book: book,
            chapters: fixture.chapters,
            chapterContents: [_chapter],
            initialChapterIndex: 0,
            savedProgress: ReadingProgressData(
              bookId: book.id,
              chapterId: fixture.chapters.first.id,
              positionInChapter: 0.5,
              percentage: 0.5,
              totalReadingSeconds: 0,
              lastReadAt: DateTime(2026),
            ),
          ),
        ),
      ),
      ttsServiceProvider.overrideWith((ref) => tts),
      ttsMediaSessionProvider.overrideWithValue(TtsMediaSession()),
    ],
  );
  container.read(readerControllerProvider(book.id))
    ..setReadingMode(mode)
    ..setToolbarExpanded(true);
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
  await _pumpUntil(
    tester,
    () => find.byTooltip('朗读').evaluate().isNotEmpty,
    reason: 'the reader toolbar',
  );
  await tester.pump(const Duration(milliseconds: 500));
  return _Harness(container, tts, spoken, () => completion!());
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

/// 读完一段：回调引擎的完成事件，再等跟读的滚动或翻页动画走完。动画的
/// 第一帧不计时，只推一帧带时长的 pump 动画还停在起点。
Future<void> _finishUnit(WidgetTester tester, _Harness harness) async {
  harness.complete();
  await tester.pump();
  for (var frame = 0; frame < 6; frame++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

String _plainText(SelectableText widget) =>
    widget.data ?? widget.textSpan?.toPlainText() ?? '';

/// 屏幕上包含 [fragment] 的那块正文。
Finder _textBlock(String fragment) => find.byWidgetPredicate(
      (widget) =>
          widget is SelectableText && _plainText(widget).contains(fragment),
    );

/// [fragment] 所在的正文块里有没有染了底色的字。
bool _isShaded(WidgetTester tester, String fragment) {
  final widget = tester.widget<SelectableText>(_textBlock(fragment).first);
  var shaded = false;
  widget.textSpan?.visitChildren((span) {
    if (span is TextSpan &&
        (span.text ?? '').isNotEmpty &&
        span.style?.backgroundColor != null) {
      shaded = true;
    }
    return true;
  });
  return shaded;
}

void main() {
  testWidgets('scroll mode reads from the screen center and follows along',
      (tester) async {
    final harness = await _openReader(tester, mode: ReadingMode.scroll);
    final controller = tester
        .widget<TxtReader>(find.byType(TxtReader))
        .scrollController! as ReaderScrollController;
    final center = controller.centerCharOffset!;
    final expectedStart = SentenceSplitter.sentenceStartAt(_chapter, center);
    expect(expectedStart, greaterThan(0));

    await tester.tap(find.byTooltip('朗读'));
    await _pumpUntil(
      tester,
      () => harness.spoken.isNotEmpty,
      reason: 'TTS to start',
    );

    expect(harness.tts.currentOffset, expectedStart);
    expect(_chapter.substring(expectedStart), startsWith(harness.spoken.first));
    final firstUnit = harness.spoken.first;
    expect(_isShaded(tester, firstUnit.substring(0, 6)), isTrue);
    // 不是从章首读起。
    expect(_chapter.indexOf(firstUnit), greaterThan(_chapter.length ~/ 3));

    final firstTop = controller.position.pixels;
    final topInset = (tester
            .widget<ListView>(
              find.descendant(
                of: find.byType(TxtReader),
                matching: find.byType(ListView),
              ),
            )
            .padding! as EdgeInsets)
        .top;
    // 跟读只在段落快贴到底边（正文区下 15%）时才滚。
    final followLimit = 800 - (800 - topInset) * 0.15;
    for (var step = 0; step < 15; step++) {
      await _finishUnit(tester, harness);
      final unit = harness.spoken.last;
      final block = _textBlock(unit.substring(0, 5));
      expect(block, findsOneWidget, reason: 'step $step: $unit');
      final rect = tester.getRect(block);
      // 正在读的段落始终整段在屏幕上，而且不贴着底边。
      expect(rect.top, greaterThanOrEqualTo(0), reason: 'step $step');
      expect(rect.bottom, lessThanOrEqualTo(followLimit), reason: 'step $step');
      expect(_isShaded(tester, unit.substring(0, 5)), isTrue);
    }
    expect(harness.spoken, hasLength(16));
    // 十五段大约两屏，跟读确实滚动过。
    expect(controller.position.pixels, greaterThan(firstTop + 400));
  });

  testWidgets('the TTS panel opens before an external service answers',
      (tester) async {
    final synthesizer = _HeldSynthesizer();
    final player = _SilentPlayer();
    final harness = await _openReader(
      tester,
      mode: ReadingMode.scroll,
      createTts: (flutterTts) => TTSService(
        flutterTts: flutterTts,
        externalSettings: const ExternalTtsSettings(
          enabled: true,
          baseUrl: 'http://127.0.0.1:5050/v1',
          model: 'tts-1',
          voice: 'alloy',
        ),
        createSynthesizer: (_) => synthesizer,
        createAudioPlayer: () => player,
      ),
    );

    await tester.tap(find.byTooltip('朗读'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    // 合成还没回来，面板已经弹出来了，正在读的位置也已经标上。
    expect(synthesizer.pending, isNotNull);
    expect(player.played, isEmpty);
    expect(find.text('语音朗读控制'), findsOneWidget);
    expect(harness.tts.isPlaying, isTrue);
    expect(harness.tts.highlight, isNotNull);

    synthesizer.pending!.complete(Uint8List.fromList([1, 2, 3]));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(player.played, hasLength(1));
  });

  testWidgets('paged mode starts mid-page and turns pages with the speech',
      (tester) async {
    final harness = await _openReader(tester, mode: ReadingMode.page);
    await _pumpUntil(
      tester,
      () =>
          find.byType(PagedReader).evaluate().isNotEmpty &&
          find.byType(SelectableText).evaluate().isNotEmpty,
      reason: 'pagination',
    );
    String pageText() => tester
        .widgetList<SelectableText>(find.byType(SelectableText))
        .map(_plainText)
        .join('\n');
    String pageIndicator() => tester
        .widgetList<Text>(find.byType(Text))
        .map((text) => text.data ?? '')
        .firstWhere((text) => RegExp(r'^\d+ / \d+$').hasMatch(text));

    final firstPage = pageText();
    final startIndicator = pageIndicator();

    await tester.tap(find.byTooltip('朗读'));
    await _pumpUntil(
      tester,
      () => harness.spoken.isNotEmpty,
      reason: 'TTS to start',
    );

    final firstUnit = harness.spoken.first;
    final positionOnPage = firstPage.indexOf(firstUnit.substring(0, 6));
    expect(positionOnPage, greaterThan(firstPage.length * 0.25));
    expect(positionOnPage, lessThan(firstPage.length * 0.75));

    var turns = 0;
    var indicator = startIndicator;
    for (var step = 0; step < 30 && turns < 2; step++) {
      await _finishUnit(tester, harness);
      final unit = harness.spoken.last;
      // 每一段都在当前显示的那一页上开始，读到下一页的内容时已经翻过去。
      expect(pageText(), contains(unit.substring(0, 5)), reason: unit);
      if (pageIndicator() != indicator) {
        indicator = pageIndicator();
        turns++;
      }
    }
    expect(turns, 2);
  });
}
