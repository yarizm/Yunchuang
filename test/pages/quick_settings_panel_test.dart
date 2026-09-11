import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:yunchuang/database/app_database.dart';
import 'package:yunchuang/database/daos/book_reading_settings_dao.dart';
import 'package:yunchuang/pages/reader/format_reader.dart';
import 'package:yunchuang/pages/reader/quick_settings_panel.dart';
import 'package:yunchuang/providers/database_provider.dart';
import 'package:yunchuang/providers/preferences_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('quick settings panel can scroll to page turn effect controls',
      (tester) async {
    tester.view.physicalSize = const Size(393, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    SharedPreferences.setMockInitialValues({
      'pageTurnEffect': 'curl',
    });
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
        child: const MaterialApp(
          home: _QuickSettingsHost(),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.byType(FractionallySizedBox), findsOneWidget);
    expect(find.byType(ListView), findsWidgets);
    expect(find.text('词间距'), findsOneWidget);
    expect(find.text('正文粗体'), findsOneWidget);
    expect(find.text('正文对齐'), findsOneWidget);
    expect(find.text('段首'), findsOneWidget);
    expect(find.text('阅读亮度（全局）'), findsOneWidget);
    expect(find.text('左边缘调光'), findsOneWidget);
    expect(find.text('行聚焦（全局）'), findsOneWidget);

    final pageTurnControl = find.byWidgetPredicate(
      (widget) =>
          widget is SegmentedButton<String> &&
          widget.segments.any((segment) => segment.value == 'slide'),
    );
    final slideIcon = find.descendant(
      of: pageTurnControl,
      matching: find.byIcon(Icons.swipe),
    );

    await tester.ensureVisible(slideIcon);
    await tester.pumpAndSettle();
    await tester.tap(slideIcon);
    await tester.pumpAndSettle();

    expect(prefs.getString('pageTurnEffect'), 'slide');
  });

  testWidgets('book layout can be isolated and reset to global defaults',
      (tester) async {
    tester.view.physicalSize = const Size(393, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    SharedPreferences.setMockInitialValues({'fontSize': 18.0});
    final prefs = await SharedPreferences.getInstance();
    final database = AppDatabase.connect(NativeDatabase.memory());
    addTearDown(database.close);
    final bookId = await database.into(database.books).insert(
          BooksCompanion.insert(
            title: '独立排版',
            filePath: 'layout.txt',
            format: 'txt',
            fileSize: 1,
          ),
        );
    final dao = BookReadingSettingsDao(database);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          databaseProvider.overrideWithValue(database),
        ],
        child: MaterialApp(
          home: _QuickSettingsHost(bookId: bookId),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('设置范围'), findsOneWidget);
    expect(find.text('跟随全局'), findsOneWidget);
    expect(find.text('本书独立'), findsOneWidget);

    await tester.tap(find.text('本书独立'));
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 30));
    });
    expect((await dao.getForBook(bookId))?.fontSize, 18);

    await tester.drag(find.byType(Slider).first, const Offset(120, 0));
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 30));
    });
    final custom = await dao.getForBook(bookId);
    expect(custom, isNotNull);
    expect(custom!.fontSize, greaterThan(18));
    expect(prefs.getDouble('fontSize'), 18);

    await tester.tap(find.text('跟随全局'));
    await tester.pumpAndSettle();
    expect(find.text('恢复全局排版？'), findsOneWidget);
    await tester.tap(
      find.byKey(const Key('confirm-reset-book-reading-settings')),
    );
    await tester.pumpAndSettle();
    expect(await dao.getForBook(bookId), isNull);
  });

  testWidgets('PDF quick settings expose only relevant page controls',
      (tester) async {
    tester.view.physicalSize = const Size(393, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
        child: const MaterialApp(
          home: _QuickSettingsHost(isPdf: true),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('PDF 页面'), findsOneWidget);
    expect(find.text('裁边'), findsOneWidget);
    expect(find.text('对比度'), findsOneWidget);
    expect(find.text('横屏双页'), findsOneWidget);
    expect(find.text('字号'), findsNothing);
    expect(find.text('阅读模式'), findsNothing);

    await tester.tap(find.text('横屏双页'));
    await tester.pumpAndSettle();
    expect(prefs.getString('pdfPageLayout'), 'double');
  });

  testWidgets('live preview stays pinned while the controls scroll',
      (tester) async {
    tester.view.physicalSize = const Size(393, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
        child: const MaterialApp(home: _QuickSettingsHost()),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    final preview = find.textContaining('预览文字');
    expect(preview, findsOneWidget);
    final before = tester.getTopLeft(preview);

    // 滚到排版组底部：段首和翻页效果都在这一段的末尾。
    final indent = find.text('段首');
    await tester.ensureVisible(indent);
    await tester.pumpAndSettle();

    // 控件滚动了，预览必须还在原位——它在滚动区之外。
    expect(preview, findsOneWidget);
    expect(tester.getTopLeft(preview), before);
    expect(
      tester.getBottomLeft(preview).dy,
      lessThan(tester.getTopLeft(indent).dy),
    );
  });
}

class _QuickSettingsHost extends ConsumerWidget {
  final int? bookId;
  final bool isPdf;

  const _QuickSettingsHost({this.bookId, this.isPdf = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: Center(
        child: TextButton(
          onPressed: () => showQuickSettingsPanel(
            context,
            ref,
            bookId: bookId,
            isPdf: isPdf,
            currentMode: ReadingMode.scroll,
          ),
          child: const Text('open'),
        ),
      ),
    );
  }
}
