/// 本地自然日的字符串表示（yyyy-MM-dd）。
///
/// 阅读时长按"用户所在时区的自然日"归集，不是 UTC 日。跨天清零、
/// 按天统计、热力图三处必须用同一个定义，否则会出现某一天的时长
/// 被算进相邻日期的偏差，因此收敛到这一个函数。
String localDateString([DateTime? at]) {
  final d = at ?? DateTime.now();
  final month = d.month.toString().padLeft(2, '0');
  final day = d.day.toString().padLeft(2, '0');
  return '${d.year.toString().padLeft(4, '0')}-$month-$day';
}
