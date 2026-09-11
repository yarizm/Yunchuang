import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yunchuang/database/app_database.dart';
import 'package:yunchuang/models/book_shelf_options.dart';
import 'package:yunchuang/pages/home/book_card.dart';
import 'package:yunchuang/pages/home/book_list_tile.dart';
import 'package:yunchuang/pages/home/home_page.dart';
import 'package:yunchuang/providers/book_import_progress.dart';
import 'package:yunchuang/providers/book_provider.dart';
import 'package:yunchuang/providers/database_provider.dart';
import 'package:yunchuang/providers/preferences_provider.dart';
import 'package:yunchuang/theme/app_theme.dart';
import 'package:yunchuang/widgets/glass_container.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets(
      'shelf chrome and book metadata use stable high-contrast surfaces',
      (tester) async {
    tester.view.physicalSize = const Size(430, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final database = AppDatabase.connect(NativeDatabase.memory());
    addTearDown(database.close);
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    await _insertBook(database, '高对比书籍', author: '作者名称');

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(database),
          sharedPreferencesProvider.overrideWithValue(preferences),
        ],
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: const HomePage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final context = tester.element(find.text('我的书架'));
    final expectedSurface = stableSurfaceColor(context);
    final stableChrome = tester
        .widgetList<ColoredBox>(find.byType(ColoredBox))
        .where((box) => box.color == expectedSurface);
    expect(stableChrome.length, greaterThanOrEqualTo(4));

    final chipTheme = AppTheme.lightTheme.chipTheme;
    expect(
      chipTheme.backgroundColor,
      AppTheme.lightTheme.colorScheme.surfaceContainerHigh,
    );
    expect(
      chipTheme.selectedColor,
      AppTheme.lightTheme.colorScheme.primaryContainer,
    );
    expect(
      chipTheme.labelStyle?.color,
      AppTheme.lightTheme.colorScheme.onSurface,
    );
    expect(
      chipTheme.secondaryLabelStyle?.color,
      AppTheme.lightTheme.colorScheme.onPrimaryContainer,
    );

    final author = tester.widget<Text>(find.text('作者名称'));
    expect(
        author.style?.color, AppTheme.lightTheme.colorScheme.onSurfaceVariant);
    final card = find.ancestor(
      of: find.text('高对比书籍'),
      matching: find.byType(BookCard),
    );
    final surfaces = tester
        .widgetList<Material>(
            find.descendant(of: card, matching: find.byType(Material)))
        .where((material) =>
            material.color == AppTheme.lightTheme.colorScheme.surface);
    expect(surfaces, isNotEmpty);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });

  testWidgets('offers multi-file and folder import entry points',
      (tester) async {
    tester.view.physicalSize = const Size(430, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final database = AppDatabase.connect(NativeDatabase.memory());
    addTearDown(database.close);
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(database),
          sharedPreferencesProvider.overrideWithValue(preferences),
        ],
        child: const MaterialApp(home: HomePage()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '导入书籍'));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(ListTile, '选择文件'), findsOneWidget);
    expect(find.widgetWithText(ListTile, '选择文件夹'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });

  testWidgets('filters inferred statuses and persists a manual override',
      (tester) async {
    tester.view.physicalSize = const Size(430, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final database = AppDatabase.connect(NativeDatabase.memory());
    addTearDown(database.close);
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final unreadId = await _insertBook(database, '未读书');
    final readingId = await _insertBook(database, '阅读中书');
    await _insertBook(
      database,
      '已读书',
      readingStatus: 'finished',
    );
    await database.into(database.readingProgress).insert(
          ReadingProgressCompanion.insert(
            bookId: Value(readingId),
            percentage: const Value(0.4),
            totalReadingSeconds: const Value(60),
          ),
        );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(database),
          sharedPreferencesProvider.overrideWithValue(preferences),
        ],
        child: const MaterialApp(home: HomePage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('未读书'), findsOneWidget);
    expect(find.text('阅读中书'), findsOneWidget);
    expect(find.text('已读书'), findsOneWidget);

    await tester.tap(find.widgetWithText(ChoiceChip, '阅读中'));
    await tester.pumpAndSettle();

    expect(find.text('阅读中书'), findsOneWidget);
    expect(find.text('未读书'), findsNothing);
    expect(find.text('已读书'), findsNothing);

    await tester.tap(find.widgetWithText(ChoiceChip, '全部'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('未读书'));
    await tester.pumpAndSettle();
    await _openOptionsForBook(tester, '未读书');
    await tester.tap(find.widgetWithText(ListTile, '阅读状态'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ListTile, '暂停'));
    await tester.pumpAndSettle();

    final updated = await (database.select(database.books)
          ..where((book) => book.id.equals(unreadId)))
        .getSingle();
    expect(updated.readingStatus, 'paused');

    final pausedFilter = find.widgetWithText(ChoiceChip, '暂停');
    await tester.ensureVisible(pausedFilter);
    await tester.pumpAndSettle();
    await tester.tap(pausedFilter);
    await tester.pumpAndSettle();
    expect(find.text('未读书'), findsOneWidget);
    expect(find.text('阅读中书'), findsNothing);
    expect(find.text('已读书'), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });

  // 空结果的筛选态必须保留筛选栏。否则筛掉全部书之后页面只剩「还没有书」
  // 的导入引导，选中的状态筛选无处可点，用户被困在空书架里——只有杀进程
  // 重来（筛选存在内存里）才能退出。
  testWidgets('a status filter that matches nothing keeps its escape hatch',
      (tester) async {
    tester.view.physicalSize = const Size(430, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final database = AppDatabase.connect(NativeDatabase.memory());
    addTearDown(database.close);
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    await _insertBook(database, '未读书');

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(database),
          sharedPreferencesProvider.overrideWithValue(preferences),
        ],
        child: const MaterialApp(home: HomePage()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(ChoiceChip, '已读完'));
    await tester.pumpAndSettle();

    expect(find.text('未读书'), findsNothing);
    // 空书架的导入引导只对「一本书都没有」成立，这里书是被筛掉的。
    expect(find.text('还没有书'), findsNothing);
    expect(find.textContaining('没有已读完书籍'), findsOneWidget);

    // 筛选栏还在，且真的能退出去。
    final allChip = find.widgetWithText(ChoiceChip, '全部');
    expect(allChip, findsOneWidget);
    await tester.tap(allChip);
    await tester.pumpAndSettle();
    expect(find.text('未读书'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });

  // 书架是根 Tab，页面本身不会被销毁重建（StatefulShellRoute.indexedStack
  // 保留分支状态）。所以provider 一旦进入 error 态，切走再切回来也还是错误页——
  // 没有重试入口就只能杀进程。这和「筛选把自己困住」是同一类问题。
  testWidgets('shelf load failure offers a retry', (tester) async {
    tester.view.physicalSize = const Size(430, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final database = AppDatabase.connect(NativeDatabase.memory());
    addTearDown(database.close);
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    await _insertBook(database, '正常的书');

    var shouldFail = true;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(database),
          sharedPreferencesProvider.overrideWithValue(preferences),
          shelfBooksProvider.overrideWith((ref) {
            if (shouldFail) return Stream<List<Book>>.error('磁盘读不出来');
            return ref.watch(bookDaoProvider).watchShelfBooks();
          }),
        ],
        child: const MaterialApp(home: HomePage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('加载失败'), findsOneWidget);

    // 出错了要能自己救回来。
    shouldFail = false;
    await tester.tap(find.widgetWithText(FilledButton, '重试'));
    await tester.pumpAndSettle();

    expect(find.text('加载失败'), findsNothing);
    expect(find.text('正常的书'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });

  // 导入一本书要算整个文件的哈希、拷贝、分章、写库，几十兆的 PDF 或者一
  // 整个文件夹要跑好几秒。在这之前界面完全没反应，用户看不出发生了什么。
  testWidgets('import shows progress and blocks a second run', (tester) async {
    tester.view.physicalSize = const Size(430, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final database = AppDatabase.connect(NativeDatabase.memory());
    addTearDown(database.close);
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    await _insertBook(database, '已有的书');

    final container = ProviderContainer(overrides: [
      databaseProvider.overrideWithValue(database),
      sharedPreferencesProvider.overrideWithValue(preferences),
    ]);
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: HomePage()),
      ),
    );
    await tester.pumpAndSettle();

    // 空闲时看不到进度条，FAB 可点。
    expect(find.byType(LinearProgressIndicator), findsNothing);
    expect(
      tester.widget<FloatingActionButton>(find.byType(FloatingActionButton))
          .onPressed,
      isNotNull,
    );

    container.read(bookImportProgressProvider.notifier).state =
        const BookImportProgress(
      completed: 1,
      total: 3,
      currentName: '深入理解计算机系统.epub',
    );
    await tester.pump();

    expect(find.text('正在导入 2/3'), findsOneWidget);
    expect(find.text('深入理解计算机系统.epub'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    // 导入期间 FAB 禁用：并发导入会让重复检测看不见对方刚写进去的书。
    expect(
      tester.widget<FloatingActionButton>(find.byType(FloatingActionButton))
          .onPressed,
      isNull,
    );

    container.read(bookImportProgressProvider.notifier).state = null;
    await tester.pumpAndSettle();

    expect(find.byType(LinearProgressIndicator), findsNothing);
    expect(
      tester.widget<FloatingActionButton>(find.byType(FloatingActionButton))
          .onPressed,
      isNotNull,
    );

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });

  testWidgets('creates, assigns, and filters custom book collections',
      (tester) async {
    tester.view.physicalSize = const Size(430, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final database = AppDatabase.connect(NativeDatabase.memory());
    addTearDown(database.close);
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final keptId = await _insertBook(database, '已归类');
    await _insertBook(database, '待归类');
    final collectionId = await database.into(database.bookCollections).insert(
          BookCollectionsCompanion.insert(name: '收藏'),
        );
    await database.into(database.bookCollectionItems).insert(
          BookCollectionItemsCompanion.insert(
            collectionId: collectionId,
            bookId: keptId,
          ),
        );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(database),
          sharedPreferencesProvider.overrideWithValue(preferences),
        ],
        child: const MaterialApp(home: HomePage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('已归类'), findsOneWidget);
    expect(find.text('待归类'), findsOneWidget);
    await tester.tap(find.widgetWithText(ChoiceChip, '收藏'));
    await tester.pumpAndSettle();

    expect(find.text('已归类'), findsOneWidget);
    expect(find.text('待归类'), findsNothing);

    await tester.tap(find.widgetWithText(ChoiceChip, '全部书架'));
    await tester.pumpAndSettle();
    await _openOptionsForBook(tester, '待归类');
    await tester.tap(find.widgetWithText(ListTile, '加入书架'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(CheckboxListTile, '收藏'));
    await tester.tap(find.widgetWithText(FilledButton, '保存'));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(ChoiceChip, '收藏'));
    await tester.pumpAndSettle();
    expect(find.text('已归类'), findsOneWidget);
    expect(find.text('待归类'), findsOneWidget);

    await tester.tap(find.byTooltip('管理书架'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '新建书架'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '稍后阅读');
    await tester.tap(find.widgetWithText(FilledButton, '保存'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(ListTile, '稍后阅读'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });

  testWidgets('switches shelf views and persists sorting preferences',
      (tester) async {
    tester.view.physicalSize = const Size(430, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final database = AppDatabase.connect(NativeDatabase.memory());
    addTearDown(database.close);
    SharedPreferences.setMockInitialValues({
      'bookShelfSortMode': 'title',
      'bookShelfViewMode': 'list',
    });
    final preferences = await SharedPreferences.getInstance();
    await _insertBook(database, 'Beta');
    await _insertBook(database, 'Alpha');

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(database),
          sharedPreferencesProvider.overrideWithValue(preferences),
        ],
        child: const MaterialApp(home: HomePage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(BookListTile), findsNWidgets(2));
    expect(find.byType(BookCard), findsNothing);
    expect(
      tester.getTopLeft(find.text('Alpha')).dy,
      lessThan(tester.getTopLeft(find.text('Beta')).dy),
    );

    await tester.tap(find.byTooltip('网格视图'));
    await tester.pumpAndSettle();
    expect(find.byType(BookCard), findsNWidgets(2));
    expect(preferences.getString('bookShelfViewMode'), 'grid');

    await tester.tap(find.byTooltip('排序方式'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.widgetWithText(PopupMenuItem<BookSortMode>, '最近导入'),
    );
    await tester.pumpAndSettle();
    expect(preferences.getString('bookShelfSortMode'), 'importedNewest');

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });

  testWidgets('filters the shelf by series', (tester) async {
    tester.view.physicalSize = const Size(430, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final database = AppDatabase.connect(NativeDatabase.memory());
    addTearDown(database.close);
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    await _insertBook(
      database,
      '系列书',
      seriesName: '测试系列',
      seriesIndex: 1,
    );
    await _insertBook(database, '独立书');

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(database),
          sharedPreferencesProvider.overrideWithValue(preferences),
        ],
        child: const MaterialApp(home: HomePage()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('筛选系列'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.widgetWithText(CheckedPopupMenuItem<String>, '测试系列'),
    );
    await tester.pumpAndSettle();

    expect(find.text('系列书'), findsOneWidget);
    expect(find.text('独立书'), findsNothing);
    expect(find.byTooltip('系列：测试系列'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });

  testWidgets('batch manages status, collections, and deletion',
      (tester) async {
    tester.view.physicalSize = const Size(430, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final database = AppDatabase.connect(NativeDatabase.memory());
    addTearDown(database.close);
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final firstId = await _insertBook(database, '第一本');
    final secondId = await _insertBook(database, '第二本');
    final collectionId = await database.into(database.bookCollections).insert(
          BookCollectionsCompanion.insert(name: '批量书架'),
        );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(database),
          sharedPreferencesProvider.overrideWithValue(preferences),
        ],
        child: const MaterialApp(home: HomePage()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.longPress(find.text('第一本'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('第二本'));
    await tester.pumpAndSettle();
    expect(find.text('已选 2 本'), findsOneWidget);

    await tester.tap(find.byTooltip('批量修改状态'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ListTile, '暂停'));
    await tester.pumpAndSettle();
    final statusRows = await database.select(database.books).get();
    expect(statusRows.map((book) => book.readingStatus).toSet(), {'paused'});
    expect(find.text('已选 2 本'), findsNothing);

    await tester.longPress(find.text('第一本'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('第二本'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('批量管理书架'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(CheckboxListTile, '批量书架'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '加入所选书架'));
    await tester.pumpAndSettle();

    final memberships =
        await database.select(database.bookCollectionItems).get();
    expect(memberships, hasLength(2));
    expect(memberships.map((item) => item.bookId).toSet(), {firstId, secondId});
    expect(
      memberships.map((item) => item.collectionId).toSet(),
      {collectionId},
    );

    await tester.longPress(find.text('第一本'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('第二本'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('批量删除'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '删除'));
    await tester.pumpAndSettle();

    expect(await database.select(database.books).get(), isEmpty);
    expect(find.text('还没有书'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });
}

Future<int> _insertBook(
  AppDatabase database,
  String title, {
  String? readingStatus,
  String? seriesName,
  double? seriesIndex,
  String? author,
}) {
  return database.into(database.books).insert(
        BooksCompanion.insert(
          title: title,
          author: Value(author ?? ''),
          filePath: '$title.txt',
          format: 'txt',
          fileSize: 1,
          readingStatus: Value(readingStatus),
          seriesName: Value(seriesName),
          seriesIndex: Value(seriesIndex),
        ),
      );
}

Future<void> _openOptionsForBook(
  WidgetTester tester,
  String title,
) async {
  final card = find.ancestor(
    of: find.text(title),
    matching: find.byType(BookCard),
  );
  await tester.ensureVisible(card);
  await tester.pumpAndSettle();
  await tester.tap(
    find.descendant(
      of: card,
      matching: find.byTooltip('书籍选项'),
    ),
  );
  await tester.pumpAndSettle();
}
