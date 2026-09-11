import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yunchuang/providers/reading_stats_provider.dart';
import 'package:yunchuang/utils/local_date.dart';
import 'package:yunchuang/widgets/reading_heatmap_grid.dart';

/// 造一个和 provider 同样对齐方式的网格：末列是本周，起点是 52 周前的周一。
ReadingHeatmap _buildHeatmap(Map<String, int> secondsByDate) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final thisMonday = DateTime(
    today.year,
    today.month,
    today.day - (today.weekday - 1),
  );
  final start = DateTime(
    thisMonday.year,
    thisMonday.month,
    thisMonday.day - (heatmapWeeks - 1) * 7,
  );
  return ReadingHeatmap(
    startDate: start,
    dayCount: heatmapWeeks * 7,
    secondsByDate: secondsByDate,
    maxSeconds: secondsByDate.values.isEmpty
        ? 0
        : secondsByDate.values.reduce((a, b) => a > b ? a : b),
  );
}

Future<void> _pump(WidgetTester tester, ReadingHeatmap heatmap) async {
  // 53 列约 848px，给足宽度让所有格子都在视口内，否则点不中。
  tester.view.physicalSize = const Size(1600, 800);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(body: ReadingHeatmapGrid(heatmap: heatmap)),
    ),
  );
  await tester.pumpAndSettle();
}

Finder _cell(DateTime date) =>
    find.byKey(ValueKey('heatmap-cell-${localDateString(date)}'));

void main() {
  testWidgets('画出 53 周 × 7 天的格子', (tester) async {
    await _pump(tester, _buildHeatmap(const {}));

    // 图例也用同样的方块，所以按 key 过滤只数网格里的。
    final cells = find.byWidgetPredicate(
      (w) => w is Container && w.key is ValueKey<String>,
    );
    expect(tester.widgetList(cells), hasLength(heatmapWeeks * 7));
  });

  testWidgets('默认显示图例，没有选中日期', (tester) async {
    await _pump(tester, _buildHeatmap(const {}));

    expect(find.text('还没有阅读记录'), findsOneWidget);
    expect(find.text('少'), findsOneWidget);
    expect(find.text('多'), findsOneWidget);
  });

  testWidgets('点格子显示当天日期与时长', (tester) async {
    final today = DateTime.now();
    final target = DateTime(today.year, today.month, today.day - 3);
    final key = localDateString(target);

    await _pump(tester, _buildHeatmap({key: 3660}));

    await tester.tap(_cell(target));
    await tester.pump();

    expect(find.textContaining(key), findsOneWidget);
    expect(find.textContaining('1h 1m'), findsOneWidget);
  });

  testWidgets('点没有记录的那天说明白是没读，不是没数据', (tester) async {
    final today = DateTime.now();
    final target = DateTime(today.year, today.month, today.day - 5);

    await _pump(tester, _buildHeatmap(const {}));

    await tester.tap(_cell(target));
    await tester.pump();

    expect(find.textContaining('没有阅读记录'), findsOneWidget);
  });

  testWidgets('再点一次取消选中，回到图例', (tester) async {
    final today = DateTime.now();
    final target = DateTime(today.year, today.month, today.day - 2);

    await _pump(tester, _buildHeatmap(const {}));

    await tester.tap(_cell(target));
    await tester.pump();
    expect(find.text('少'), findsNothing);

    await tester.tap(_cell(target));
    await tester.pump();
    expect(find.text('少'), findsOneWidget);
  });

  // 本周还没到的日子留空且点不动——否则会显示成"那天没读书"，
  // 而事实是那天还没来。
  testWidgets('未来的格子点不动', (tester) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    if (today.weekday == DateTime.sunday) {
      return; // 周日当周没有未来格子，跳过
    }
    final tomorrow = DateTime(today.year, today.month, today.day + 1);

    await _pump(tester, _buildHeatmap(const {}));

    await tester.tap(_cell(tomorrow));
    await tester.pump();

    // 仍然是图例，没有切到日期详情。
    expect(find.text('少'), findsOneWidget);
    expect(find.textContaining(localDateString(tomorrow)), findsNothing);
  });

  // 网格 53 列约 848px，手机宽度放不下，靠横向滚动容纳。
  // 这条盯的是它不会把整页撑破（RenderFlex overflow）。
  testWidgets('手机宽度下不溢出', (tester) async {
    tester.view.physicalSize = const Size(375, 812);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [ReadingHeatmapGrid(heatmap: _buildHeatmap(const {}))],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });

  testWidgets('初始滚到最右边，看到的是最近的日期', (tester) async {
    tester.view.physicalSize = const Size(375, 812);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
            body: ReadingHeatmapGrid(heatmap: _buildHeatmap(const {}))),
      ),
    );
    await tester.pumpAndSettle();

    final scrollable = tester.widget<Scrollable>(
      find.byType(Scrollable).first,
    );
    final position = scrollable.controller!.position;
    expect(position.pixels, position.maxScrollExtent);
    expect(position.maxScrollExtent, greaterThan(0));
  });
}
