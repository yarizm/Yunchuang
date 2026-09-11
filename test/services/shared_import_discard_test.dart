import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:yunchuang/services/shared_import_service.dart';

void main() {
  late Directory temp;
  late Directory cacheRoot;
  late SharedImportService service;

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('shared_discard');
    cacheRoot = Directory(p.join(temp.path, 'shared_imports'))
      ..createSync(recursive: true);
    service = SharedImportService(supportedOverride: true);
  });

  tearDown(() {
    if (temp.existsSync()) temp.deleteSync(recursive: true);
  });

  /// 造一份原生侧那样的布局：shared_imports/<槽位>/<显示名>
  File slot(String slotName, String fileName) {
    final dir = Directory(p.join(cacheRoot.path, slotName))
      ..createSync(recursive: true);
    return File(p.join(dir.path, fileName))..writeAsStringSync('book');
  }

  test('删掉文件连同它的槽位目录', () async {
    final file = slot('1700000000_1', 'a.epub');

    await service.discard([file.path]);

    expect(file.existsSync(), isFalse);
    expect(Directory(p.dirname(file.path)).existsSync(), isFalse);
  });

  test('不删 shared_imports 本身', () async {
    final file = slot('1700000000_1', 'a.epub');

    await service.discard([file.path]);

    expect(cacheRoot.existsSync(), isTrue);
  });

  test('槽位里还有别的文件时保留目录', () async {
    final first = slot('1700000000_1', 'a.epub');
    final second = File(p.join(p.dirname(first.path), 'b.epub'))
      ..writeAsStringSync('other');

    await service.discard([first.path]);

    expect(first.existsSync(), isFalse);
    expect(second.existsSync(), isTrue);
    expect(Directory(p.dirname(first.path)).existsSync(), isTrue);
  });

  test('多份一起删', () async {
    final a = slot('1700000000_1', 'a.epub');
    final b = slot('1700000000_2', 'b.epub');

    await service.discard([a.path, b.path]);

    expect(a.existsSync(), isFalse);
    expect(b.existsSync(), isFalse);
    expect(cacheRoot.listSync(), isEmpty);
  });

  // 用户可能在导入前后自己清了缓存，或系统回收了它。
  test('文件已经不在也不抛异常', () async {
    await service.discard([p.join(cacheRoot.path, 'gone', 'x.epub')]);
  });

  // discard 拿到的路径理论上都来自 consumePending，但删除是不可逆操作，
  // 目录名不对就不动——避免任何路径拼错时误删用户文件。
  test('不在 shared_imports 下的路径只删文件，不碰目录', () async {
    final otherDir = Directory(p.join(temp.path, 'documents'))
      ..createSync(recursive: true);
    final file = File(p.join(otherDir.path, 'user.epub'))
      ..writeAsStringSync('x');

    await service.discard([file.path]);

    expect(file.existsSync(), isFalse);
    expect(otherDir.existsSync(), isTrue);
  });

  test('非 Android 平台什么都不做', () async {
    final file = slot('1700000000_1', 'a.epub');
    final disabled = SharedImportService(supportedOverride: false);

    await disabled.discard([file.path]);

    expect(file.existsSync(), isTrue);
  });
}
