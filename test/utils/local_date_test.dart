import 'package:flutter_test/flutter_test.dart';
import 'package:yunchuang/utils/local_date.dart';

void main() {
  test('formats as yyyy-MM-dd with zero padding', () {
    expect(localDateString(DateTime(2026, 9, 5)), '2026-09-05');
    expect(localDateString(DateTime(2026, 12, 31)), '2026-12-31');
  });

  // 用本地时间字段而不是 UTC：深夜阅读必须算进当天，不能因为
  // 时区偏移被推到第二天（或退回前一天）。
  test('uses local calendar day, not UTC', () {
    final lateNight = DateTime(2026, 9, 5, 23, 30);
    expect(localDateString(lateNight), '2026-09-05');

    final earlyMorning = DateTime(2026, 9, 5, 0, 30);
    expect(localDateString(earlyMorning), '2026-09-05');
  });

  test('sorts lexicographically in chronological order', () {
    final dates = [
      localDateString(DateTime(2026, 10, 1)),
      localDateString(DateTime(2026, 9, 30)),
      localDateString(DateTime(2025, 12, 1)),
    ]..sort();

    expect(dates, ['2025-12-01', '2026-09-30', '2026-10-01']);
  });
}
