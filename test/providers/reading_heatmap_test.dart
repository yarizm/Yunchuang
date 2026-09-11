import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yunchuang/database/app_database.dart';
import 'package:yunchuang/database/daos/progress_dao.dart';
import 'package:yunchuang/providers/database_provider.dart';
import 'package:yunchuang/providers/reading_stats_provider.dart';
import 'package:yunchuang/utils/local_date.dart';

void main() {
  group('heatLevel', () {
    test('没读书是 0 档，读了就至少 1 档', () {
      expect(heatLevel(0, 3600), 0);
      expect(heatLevel(1, 3600), 1);
    });

    test('按占最长一天的比例分 4 档，最长的那天是满档', () {
      expect(heatLevel(3600, 3600), 4);
      expect(heatLevel(2700, 3600), 3);
      expect(heatLevel(1800, 3600), 2);
      expect(heatLevel(900, 3600), 1);
    });

    // 只有一天有记录时 max 等于它自己，不能除出 0 或越界。
    test('极端比例不会越出 1-4', () {
      expect(heatLevel(1, 100000), 1);
      expect(heatLevel(5, 0), 1);
      expect(heatLevel(100, 10), 4);
    });
  });

  group('汇总数字', () {
    // 这些方法只看 secondsByDate，不依赖 startDate，所以传入固定的 now
    // 就完全确定。2026-09-05 是周六。
    ReadingHeatmap build(Map<String, int> data) => ReadingHeatmap(
          startDate: DateTime(2026, 9, 1),
          dayCount: 7,
          secondsByDate: data,
          maxSeconds: data.values.isEmpty
              ? 0
              : data.values.reduce((a, b) => a > b ? a : b),
        );

    final saturday = DateTime(2026, 9, 5);

    test('本周从周一算到今天，不含往后的日子', () {
      final heatmap = build({
        '2026-08-30': 600, // 上周日，不算
        '2026-08-31': 100, // 本周一
        '2026-09-05': 200, // 今天（周六）
        '2026-09-06': 900, // 周日，还没到
      });

      expect(heatmap.secondsThisWeek(saturday), 300);
    });

    test('本月从 1 号算到今天', () {
      final heatmap = build({
        '2026-08-31': 999, // 上月
        '2026-09-01': 100,
        '2026-09-05': 200,
        '2026-09-30': 900, // 还没到
      });

      expect(heatmap.secondsThisMonth(saturday), 300);
    });

    test('连续天数从今天往回数', () {
      final heatmap = build({
        '2026-09-03': 100,
        '2026-09-04': 100,
        '2026-09-05': 100,
      });

      expect(heatmap.currentStreak(saturday), 3);
    });

    // 关键取舍：很多人晚上才读，白天打开统计页不该看到连胜清零。
    test('今天还没读不算断，从昨天起算', () {
      final heatmap = build({
        '2026-09-03': 100,
        '2026-09-04': 100,
      });

      expect(heatmap.currentStreak(saturday), 2);
    });

    test('今天和昨天都没读才算断', () {
      final heatmap = build({
        '2026-09-01': 100,
        '2026-09-02': 100,
      });

      expect(heatmap.currentStreak(saturday), 0);
    });

    test('中间断过的不连起来算', () {
      final heatmap = build({
        '2026-09-01': 100,
        // 09-02 断
        '2026-09-03': 100,
        '2026-09-04': 100,
        '2026-09-05': 100,
      });

      expect(heatmap.currentStreak(saturday), 3);
    });

    test('最长连续扫整个网格', () {
      final heatmap = ReadingHeatmap(
        startDate: DateTime(2026, 8, 31), // 周一
        dayCount: 7,
        secondsByDate: const {
          '2026-08-31': 100,
          '2026-09-01': 100,
          '2026-09-02': 100,
          '2026-09-03': 100,
          // 09-04 断
          '2026-09-05': 100,
          '2026-09-06': 100,
        },
        maxSeconds: 100,
      );

      expect(heatmap.longestStreak(), 4);
    });

    test('全空时汇总都是 0', () {
      final heatmap = build(const {});

      expect(heatmap.secondsThisWeek(saturday), 0);
      expect(heatmap.secondsThisMonth(saturday), 0);
      expect(heatmap.currentStreak(saturday), 0);
      expect(heatmap.longestStreak(), 0);
    });
  });

  group('readingHeatmapProvider', () {
    late AppDatabase database;
    late ProviderContainer container;

    setUp(() {
      database = AppDatabase.connect(NativeDatabase.memory());
      container = ProviderContainer(
        overrides: [databaseProvider.overrideWithValue(database)],
      );
    });

    tearDown(() async {
      container.dispose();
      await database.close();
    });

    test('网格从周一起算，覆盖 53 周', () async {
      final heatmap = await container.read(readingHeatmapProvider.future);

      expect(heatmap.startDate.weekday, DateTime.monday);
      expect(heatmap.weekCount, heatmapWeeks);
      expect(heatmap.dayCount, heatmapWeeks * 7);
    });

    test('末列包含今天', () async {
      final heatmap = await container.read(readingHeatmapProvider.future);

      final todayKey = localDateString();
      final lastWeekKeys = [
        for (var i = 0; i < 7; i++)
          localDateString(heatmap.dateAt(heatmap.dayCount - 7 + i)),
      ];

      expect(lastWeekKeys, contains(todayKey));
    });

    test('读出当天时长并算出最大值', () async {
      final bookId = await database.into(database.books).insert(
            BooksCompanion.insert(
              title: 'A',
              filePath: 'a.txt',
              format: 'txt',
              fileSize: 1,
            ),
          );
      final dao = ProgressDao(database);
      final today = DateTime.now();
      final yesterday =
          DateTime(today.year, today.month, today.day - 1);

      await dao.addSessionSeconds(
        bookId: bookId,
        date: localDateString(today),
        seconds: 600,
      );
      await dao.addSessionSeconds(
        bookId: bookId,
        date: localDateString(yesterday),
        seconds: 1800,
      );

      final heatmap = await container.read(readingHeatmapProvider.future);

      expect(heatmap.maxSeconds, 1800);
      expect(heatmap.isEmpty, isFalse);

      final todayIndex = heatmap.dayCount -
          7 +
          (today.weekday - 1); // 末列里今天的行号
      expect(heatmap.secondsAt(todayIndex), 600);
    });

    test('没有记录时是空的，最大值为 0', () async {
      final heatmap = await container.read(readingHeatmapProvider.future);

      expect(heatmap.isEmpty, isTrue);
      expect(heatmap.maxSeconds, 0);
      expect(heatmap.secondsAt(0), 0);
    });

    // 一年前的记录落在窗口外，不能被算进来影响色阶。
    test('窗口外的记录不参与统计', () async {
      final bookId = await database.into(database.books).insert(
            BooksCompanion.insert(
              title: 'A',
              filePath: 'a.txt',
              format: 'txt',
              fileSize: 1,
            ),
          );
      final dao = ProgressDao(database);
      final longAgo = DateTime.now().subtract(const Duration(days: 400));

      await dao.addSessionSeconds(
        bookId: bookId,
        date: localDateString(longAgo),
        seconds: 99999,
      );

      final heatmap = await container.read(readingHeatmapProvider.future);

      expect(heatmap.isEmpty, isTrue);
      expect(heatmap.maxSeconds, 0);
    });
  });
}
