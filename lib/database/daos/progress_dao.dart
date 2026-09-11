import 'package:drift/drift.dart';
import '../app_database.dart';
import '../tables/reading_progress.dart';
import '../tables/reading_sessions.dart';

part 'progress_dao.g.dart';

class BookSecondsRow {
  final int bookId;
  final String title;
  final String? coverPath;
  final int totalSeconds;
  final double percentage;

  const BookSecondsRow({
    required this.bookId,
    required this.title,
    required this.coverPath,
    required this.totalSeconds,
    required this.percentage,
  });
}

@DriftAccessor(tables: [ReadingProgress, ReadingSessions])
class ProgressDao extends DatabaseAccessor<AppDatabase>
    with _$ProgressDaoMixin {
  ProgressDao(super.db);

  Future<ReadingProgressData?> getProgress(int bookId) =>
      (select(readingProgress)..where((p) => p.bookId.equals(bookId)))
          .getSingleOrNull();

  Stream<Map<int, ReadingProgressData>> watchAllProgress() {
    return select(readingProgress).watch().map(
          (rows) => {
            for (final row in rows) row.bookId: row,
          },
        );
  }

  Future<void> saveProgress({
    required int bookId,
    required int? chapterId,
    double positionInChapter = 0.0,
    double percentage = 0.0,
    int totalReadingSeconds = 0,
  }) async {
    await into(readingProgress).insertOnConflictUpdate(
      ReadingProgressCompanion.insert(
        bookId: Value(bookId),
        chapterId: Value(chapterId),
        positionInChapter: Value(positionInChapter),
        percentage: Value(percentage),
        totalReadingSeconds: Value(totalReadingSeconds),
        lastReadAt: Value(DateTime.now()),
      ),
    );
  }

  Future<void> ensureProgress(int bookId, int? chapterId) async {
    final existing = await getProgress(bookId);
    if (existing == null) {
      await saveProgress(bookId: bookId, chapterId: chapterId);
    }
  }

  Future<void> saveSessionProgress({
    required int bookId,
    required int? chapterId,
    required double positionInChapter,
    required int totalReadingSeconds,
  }) async {
    final existing = await getProgress(bookId);
    if (existing == null) {
      await saveProgress(
        bookId: bookId,
        chapterId: chapterId,
        positionInChapter: positionInChapter,
        totalReadingSeconds: totalReadingSeconds,
      );
      return;
    }
    await (update(readingProgress)
          ..where((progress) => progress.bookId.equals(bookId)))
        .write(ReadingProgressCompanion(
      chapterId: Value(chapterId),
      positionInChapter: Value(positionInChapter),
      totalReadingSeconds: Value(totalReadingSeconds),
      lastReadAt: Value(DateTime.now()),
    ));
  }

  Future<int> sumTotalSeconds() async {
    final query = selectOnly(readingProgress)
      ..addColumns([readingProgress.totalReadingSeconds.sum()]);
    final row = await query.getSingle();
    return row.read(readingProgress.totalReadingSeconds.sum()) ?? 0;
  }

  Future<({int finished, int total})> completionStats() async {
    final all = await select(readingProgress).get();
    final finished = all.where((p) => p.percentage >= 1.0).length;
    return (finished: finished, total: all.length);
  }

  Future<List<BookSecondsRow>> topBooksBySeconds(int limit) async {
    final query = customSelect(
      'SELECT p.book_id AS book_id, b.title AS title, '
      'b.cover_path AS cover_path, p.total_reading_seconds AS secs, '
      'p.percentage AS pct '
      'FROM reading_progress p JOIN books b ON p.book_id = b.id '
      'WHERE p.total_reading_seconds > 0 '
      'ORDER BY secs DESC LIMIT ?',
      variables: [Variable.withInt(limit)],
      readsFrom: {readingProgress, books},
    );
    final rows = await query.get();
    return rows
        .map((r) => BookSecondsRow(
              bookId: r.read<int>('book_id'),
              title: r.read<String>('title'),
              coverPath: r.read<String?>('cover_path'),
              totalSeconds: r.read<int>('secs'),
              percentage: r.read<double>('pct'),
            ))
        .toList();
  }

  /// 把 [seconds] 累加到 ([bookId], [date]) 那一行，没有就新建。
  ///
  /// 调用方按秒缓冲后成批写入（见 `reader_page.dart`），所以这里每次
  /// 读-改-写的开销可以接受；用事务是因为并发的阅读页与 TTS 可能同时落盘。
  Future<void> addSessionSeconds({
    required int bookId,
    required String date,
    required int seconds,
  }) async {
    if (seconds <= 0) return;
    await transaction(() async {
      final existing = await (select(readingSessions)
            ..where((s) => s.bookId.equals(bookId) & s.date.equals(date))
            ..limit(1))
          .getSingleOrNull();
      if (existing == null) {
        await into(readingSessions).insert(
          ReadingSessionsCompanion.insert(
            bookId: Value(bookId),
            date: date,
            seconds: Value(seconds),
          ),
        );
      } else {
        await (update(readingSessions)..where((s) => s.id.equals(existing.id)))
            .write(
          ReadingSessionsCompanion(seconds: Value(existing.seconds + seconds)),
        );
      }
    });
  }

  /// 某个自然日的总时长（跨全部书籍，含已删除书籍留下的记录）。
  Future<int> secondsOnDate(String date) async {
    final total = readingSessions.seconds.sum();
    final query = selectOnly(readingSessions)
      ..addColumns([total])
      ..where(readingSessions.date.equals(date));
    final row = await query.getSingle();
    return row.read(total) ?? 0;
  }

  /// [from]、[to] 闭区间内按天汇总，只返回有记录的日期。
  ///
  /// 没读书的那天不会出现在结果里——热力图需要自己补零，避免这里
  /// 为一整年生成 365 个空条目。
  Future<Map<String, int>> dailySeconds({
    required String from,
    required String to,
  }) async {
    final total = readingSessions.seconds.sum();
    final query = selectOnly(readingSessions)
      ..addColumns([readingSessions.date, total])
      ..where(readingSessions.date.isBetweenValues(from, to))
      ..groupBy([readingSessions.date]);
    final rows = await query.get();
    return {
      for (final row in rows)
        row.read(readingSessions.date)!: row.read(total) ?? 0,
    };
  }
}
