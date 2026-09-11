import 'package:drift/drift.dart';
import 'books.dart';

/// 按天记录阅读时长。
///
/// [ReadingProgress] 只有 `totalReadingSeconds`（每本书的累计值），
/// "今日时长"此前存在 SharedPreferences 且跨天清零——昨天读了多久
/// 无法回溯，也永远补不回来。这张表按 (书, 本地自然日) 累加，是
/// 日/周/月统计与热力图唯一的数据来源。
///
/// [bookId] 可空、删书时置空而非级联删除：删掉一本读完的书不应该
/// 把那几天的阅读记录一起抹掉。代价是失去归属信息，按日期汇总不受影响。
/// 因此这张表没有 (bookId, date) 唯一约束——置空后同一天可能出现
/// 多行 bookId 为 null 的记录，累加写入只针对 bookId 非空的行。
class ReadingSessions extends Table {
  IntColumn get id => integer().autoIncrement()();

  IntColumn get bookId => integer()
      .nullable()
      .references(Books, #id, onDelete: KeyAction.setNull)();

  /// 本地自然日，格式 yyyy-MM-dd，由 `localDateString()` 生成。
  TextColumn get date => text().withLength(min: 10, max: 10)();

  IntColumn get seconds => integer().withDefault(const Constant(0))();
}
