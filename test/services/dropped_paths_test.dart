import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:yunchuang/database/app_database.dart';
import 'package:yunchuang/database/daos/book_dao.dart';
import 'package:yunchuang/services/book_service.dart';

void main() {
  late AppDatabase database;
  late BookService service;
  late Directory temp;

  setUp(() async {
    database = AppDatabase.connect(NativeDatabase.memory());
    temp = await Directory.systemTemp.createTemp('dropped_paths_test');
    service = BookService(
      BookDao(database),
      appDirectoryProvider: () async => temp,
    );
  });

  tearDown(() async {
    await database.close();
    if (temp.existsSync()) temp.deleteSync(recursive: true);
  });

  File touch(String name) {
    final file = File(p.join(temp.path, name))
      ..createSync(recursive: true)
      ..writeAsStringSync('x');
    return file;
  }

  test('保留支持的格式，丢掉其余的', () async {
    final epub = touch('a.epub');
    final pdf = touch('b.pdf');
    final txt = touch('c.txt');
    final mobi = touch('d.mobi');
    final image = touch('e.png');

    final resolved = await service.resolveDroppedPaths([
      epub.path,
      pdf.path,
      txt.path,
      mobi.path,
      image.path,
    ]);

    expect(resolved, containsAll([epub.path, pdf.path, txt.path]));
    expect(resolved, isNot(contains(mobi.path)));
    expect(resolved, isNot(contains(image.path)));
  });

  test('扩展名大小写不敏感', () async {
    final upper = touch('A.EPUB');

    expect(await service.resolveDroppedPaths([upper.path]), [upper.path]);
  });

  test('文件夹递归展开', () async {
    final nested = Directory(p.join(temp.path, 'books', 'sub'))
      ..createSync(recursive: true);
    final inner = File(p.join(nested.path, 'deep.txt'))
      ..writeAsStringSync('x');
    File(p.join(temp.path, 'books', 'note.md')).writeAsStringSync('x');

    final resolved = await service.resolveDroppedPaths(
      [p.join(temp.path, 'books')],
    );

    expect(resolved, [inner.path]);
  });

  // 拖到一半源文件被删、或拖的是快捷方式指向不存在的目标。
  test('不存在的路径被跳过而不是抛异常', () async {
    final real = touch('real.txt');

    final resolved = await service.resolveDroppedPaths([
      p.join(temp.path, 'gone.epub'),
      real.path,
    ]);

    expect(resolved, [real.path]);
  });

  test('重复路径只算一次', () async {
    final file = touch('same.txt');

    final resolved =
        await service.resolveDroppedPaths([file.path, file.path, file.path]);

    expect(resolved, hasLength(1));
  });

  // 文件夹里的书和单独拖进来的同一本书，不应该导入两次。
  test('文件夹与其中的文件同时拖入不会重复', () async {
    final dir = Directory(p.join(temp.path, 'lib'))..createSync();
    final book = File(p.join(dir.path, 'one.epub'))..writeAsStringSync('x');

    final resolved =
        await service.resolveDroppedPaths([dir.path, book.path]);

    expect(resolved, [book.path]);
  });

  test('空输入返回空', () async {
    expect(await service.resolveDroppedPaths(const []), isEmpty);
  });
}
