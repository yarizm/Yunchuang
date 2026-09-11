import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../database/daos/progress_dao.dart';
import '../utils/local_date.dart';
import 'database_provider.dart';

class ReadingStats {
  final int todaySeconds;
  final int totalSeconds;
  final List<BookSecondsRow> topBooks;

  const ReadingStats({
    required this.todaySeconds,
    required this.totalSeconds,
    required this.topBooks,
  });
}

/// 热力图数据：一整年按天的阅读秒数。
///
/// 网格按周分列，所以起点必须对齐到周一，否则每列会跨两个星期。
class ReadingHeatmap {
  /// 网格左上角那一格的日期，一定是周一。
  final DateTime startDate;

  /// 网格总天数，7 的整数倍。
  final int dayCount;

  /// 只含有记录的日期，没读书的那天不在里面。
  final Map<String, int> secondsByDate;

  /// 区间内单日最长时长，用于计算色阶。没有记录时为 0。
  final int maxSeconds;

  const ReadingHeatmap({
    required this.startDate,
    required this.dayCount,
    required this.secondsByDate,
    required this.maxSeconds,
  });

  DateTime dateAt(int index) => DateTime(
        startDate.year,
        startDate.month,
        startDate.day + index,
      );

  int secondsAt(int index) =>
      secondsByDate[localDateString(dateAt(index))] ?? 0;

  int get weekCount => dayCount ~/ 7;

  bool get isEmpty => secondsByDate.isEmpty;

  /// 本周（周一起算）到今天为止的总时长。
  int secondsThisWeek([DateTime? now]) {
    final today = _startOfDay(now ?? DateTime.now());
    final monday = DateTime(
      today.year,
      today.month,
      today.day - (today.weekday - 1),
    );
    return _sumBetween(monday, today);
  }

  /// 本月 1 号到今天为止的总时长。
  int secondsThisMonth([DateTime? now]) {
    final today = _startOfDay(now ?? DateTime.now());
    return _sumBetween(DateTime(today.year, today.month, 1), today);
  }

  /// 当前连续阅读天数。
  ///
  /// 从今天往回数；今天还没读不算断——很多人晚上才读，白天打开统计页
  /// 看到连胜清零是错的。所以今天为空时从昨天起算。
  int currentStreak([DateTime? now]) {
    final today = _startOfDay(now ?? DateTime.now());
    var cursor = today;
    if ((secondsByDate[localDateString(cursor)] ?? 0) <= 0) {
      cursor = DateTime(cursor.year, cursor.month, cursor.day - 1);
    }
    var streak = 0;
    while ((secondsByDate[localDateString(cursor)] ?? 0) > 0) {
      streak++;
      cursor = DateTime(cursor.year, cursor.month, cursor.day - 1);
    }
    return streak;
  }

  /// 这一年里最长的连续阅读天数。
  int longestStreak() {
    var longest = 0;
    var running = 0;
    for (var i = 0; i < dayCount; i++) {
      if (secondsAt(i) > 0) {
        running++;
        if (running > longest) longest = running;
      } else {
        running = 0;
      }
    }
    return longest;
  }

  int _sumBetween(DateTime from, DateTime to) {
    var total = 0;
    var cursor = from;
    while (!cursor.isAfter(to)) {
      total += secondsByDate[localDateString(cursor)] ?? 0;
      cursor = DateTime(cursor.year, cursor.month, cursor.day + 1);
    }
    return total;
  }

  static DateTime _startOfDay(DateTime at) =>
      DateTime(at.year, at.month, at.day);
}

/// 色阶档位 0-4：0 表示没读，1-4 按占当期最长一天的比例分。
///
/// 用相对值而不是绝对分钟数：每天读十分钟的人和每天读两小时的人，
/// 关心的都是"自己这段时间读得连不连贯"，绝对阈值会让前者整片同色。
/// 具体时长点击格子能看到，不靠颜色传达。
int heatLevel(int seconds, int maxSeconds) {
  if (seconds <= 0) return 0;
  if (maxSeconds <= 0) return 1;
  return (seconds / maxSeconds * 4).ceil().clamp(1, 4);
}

/// 热力图覆盖的周数：52 周加当周，和 GitHub 贡献图一致。
const heatmapWeeks = 53;

final readingHeatmapProvider = FutureProvider<ReadingHeatmap>((ref) async {
  final dao = ref.watch(progressDaoProvider);
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);

  // 末列是本周，起点回退到 52 周前的那个周一。
  // DateTime.weekday 周一为 1，所以减 (weekday - 1) 落到本周一。
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
  const dayCount = heatmapWeeks * 7;
  final end = DateTime(start.year, start.month, start.day + dayCount - 1);

  final byDate = await dao.dailySeconds(
    from: localDateString(start),
    to: localDateString(end),
  );

  return ReadingHeatmap(
    startDate: start,
    dayCount: dayCount,
    secondsByDate: byDate,
    maxSeconds: byDate.values.isEmpty
        ? 0
        : byDate.values.reduce((a, b) => a > b ? a : b),
  );
});

final readingStatsProvider = FutureProvider<ReadingStats>((ref) async {
  final dao = ref.watch(progressDaoProvider);
  // 今日时长与历史都来自 reading_sessions，是这个数字唯一的来源。
  final results = await Future.wait([
    dao.secondsOnDate(localDateString()),
    dao.sumTotalSeconds(),
    dao.topBooksBySeconds(5),
  ]);

  return ReadingStats(
    todaySeconds: results[0] as int,
    totalSeconds: results[1] as int,
    topBooks: results[2] as List<BookSecondsRow>,
  );
});
