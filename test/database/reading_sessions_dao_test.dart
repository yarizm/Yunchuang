import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yunchuang/database/app_database.dart';
import 'package:yunchuang/database/daos/progress_dao.dart';

void main() {
  late AppDatabase database;
  late ProgressDao dao;

  setUp(() {
    database = AppDatabase.connect(NativeDatabase.memory());
    dao = ProgressDao(database);
  });

  tearDown(() async {
    await database.close();
  });

  test('同一天重复写入累加到同一行，而不是新增行', () async {
    final bookId = await _insertBook(database, title: 'A');

    await dao.addSessionSeconds(bookId: bookId, date: '2026-09-05', seconds: 60);
    await dao.addSessionSeconds(bookId: bookId, date: '2026-09-05', seconds: 30);

    expect(await dao.secondsOnDate('2026-09-05'), 90);
    final rows = await database.select(database.readingSessions).get();
    expect(rows, hasLength(1));
  });

  test('非正数秒数不写入', () async {
    final bookId = await _insertBook(database, title: 'A');

    await dao.addSessionSeconds(bookId: bookId, date: '2026-09-05', seconds: 0);
    await dao.addSessionSeconds(bookId: bookId, date: '2026-09-05', seconds: -5);

    expect(await database.select(database.readingSessions).get(), isEmpty);
  });

  test('secondsOnDate 跨书汇总，且不串到别的日期', () async {
    final a = await _insertBook(database, title: 'A');
    final b = await _insertBook(database, title: 'B');

    await dao.addSessionSeconds(bookId: a, date: '2026-09-05', seconds: 100);
    await dao.addSessionSeconds(bookId: b, date: '2026-09-05', seconds: 200);
    await dao.addSessionSeconds(bookId: a, date: '2026-09-04', seconds: 999);

    expect(await dao.secondsOnDate('2026-09-05'), 300);
    expect(await dao.secondsOnDate('2026-09-04'), 999);
    expect(await dao.secondsOnDate('2026-09-06'), 0);
  });

  test('dailySeconds 按天分组，闭区间，跳过无记录的日期', () async {
    final bookId = await _insertBook(database, title: 'A');

    await dao.addSessionSeconds(bookId: bookId, date: '2026-09-01', seconds: 10);
    await dao.addSessionSeconds(bookId: bookId, date: '2026-09-03', seconds: 20);
    await dao.addSessionSeconds(bookId: bookId, date: '2026-09-05', seconds: 30);

    final result = await dao.dailySeconds(from: '2026-09-01', to: '2026-09-03');

    expect(result, {'2026-09-01': 10, '2026-09-03': 20});
    expect(result.containsKey('2026-09-02'), isFalse);
    expect(result.containsKey('2026-09-05'), isFalse);
  });

  // 这条是这张表存在的理由：删掉一本读完的书，不该把那几天的阅读历史
  // 一起抹掉。bookId 置空，按日期汇总的数字不变。
  test('删除书籍保留历史时长，只丢归属', () async {
    final bookId = await _insertBook(database, title: 'A');
    await dao.addSessionSeconds(bookId: bookId, date: '2026-09-05', seconds: 120);

    await (database.delete(database.books)
          ..where((b) => b.id.equals(bookId)))
        .go();

    expect(await dao.secondsOnDate('2026-09-05'), 120);
    final row = await database.select(database.readingSessions).getSingle();
    expect(row.bookId, isNull);
  });
}

Future<int> _insertBook(AppDatabase db, {required String title}) {
  return db.into(db.books).insert(
        BooksCompanion.insert(
          title: title,
          filePath: '$title.txt',
          format: 'txt',
          fileSize: 1,
        ),
      );
}
