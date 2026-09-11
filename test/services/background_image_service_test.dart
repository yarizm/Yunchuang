import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:yunchuang/services/background_image_service.dart';

void main() {
  // ui.ImageDescriptor / toByteData 都要求 binding 起来。
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory documents;
  late BackgroundImageService service;

  setUp(() async {
    documents = await Directory.systemTemp.createTemp('yunchuang_bg_');
    service = BackgroundImageService(documents);
  });

  tearDown(() async {
    if (await documents.exists()) await documents.delete(recursive: true);
  });

  Future<File> writePng(String name, int width, int height) async {
    final recorder = ui.PictureRecorder();
    Canvas(recorder).drawRect(
      Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
      Paint()..color = const Color(0xFF3366AA),
    );
    final image =
        await recorder.endRecording().toImage(width, height);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    final file = File(p.join(documents.path, name));
    await file.writeAsBytes(data!.buffer.asUint8List(), flush: true);
    return file;
  }

  Future<ui.Size> sizeOf(String path) async {
    final buffer =
        await ui.ImmutableBuffer.fromUint8List(await File(path).readAsBytes());
    final descriptor = await ui.ImageDescriptor.encoded(buffer);
    final size = ui.Size(
      descriptor.width.toDouble(),
      descriptor.height.toDouble(),
    );
    descriptor.dispose();
    return size;
  }

  group('resolvePath', () {
    test('文件名为空或文件不在都返回 null', () {
      expect(service.resolvePath(null), isNull);
      expect(service.resolvePath(''), isNull);
      expect(service.resolvePath('nothing-here.png'), isNull);
    });

    // 存进偏好的应该只是文件名。真混进了路径分隔符（改坏的 prefs、别处来的
    // 备份），拼接之后 remove() 会跑到应用目录外面删东西。
    test('带路径的值一律当成无效，不去拼接', () {
      for (final hostile in const [
        '../../secret.png',
        'subdir/image.png',
        r'..\..\secret.png',
      ]) {
        expect(service.resolvePath(hostile), isNull, reason: hostile);
      }
    });

    test('文件真的存在时给出绝对路径', () async {
      await service.directory.create(recursive: true);
      final file = File(p.join(service.directory.path, 'bg.png'));
      await file.writeAsBytes(const [1, 2, 3]);

      expect(service.resolvePath('bg.png'), file.path);
    });
  });

  group('import', () {
    test('小图原样收进来，不重新编码', () async {
      final source = await writePng('small.png', 400, 300);
      final original = await source.readAsBytes();

      final name = await service.import(source);
      final stored = File(service.resolvePath(name)!);

      expect(p.extension(name), '.png');
      expect(await stored.readAsBytes(), original);
    });

    // 4000px 的原图当背景毫无意义，只会让每次备份都胖几 MB。
    test('长边超过上限的图缩到上限', () async {
      final source = await writePng('huge.png', 4000, 2000);

      final name = await service.import(source);
      final size = await sizeOf(service.resolvePath(name)!);

      expect(size.width, BackgroundImageService.maxEdge.toDouble());
      expect(size.height, BackgroundImageService.maxEdge / 2);
    });

    // FileImage 是按路径缓存的。沿用同一个文件名，换过的背景在下次重启前
    // 会一直显示旧图。
    test('每次导入都换一个新文件名', () async {
      final first = await service.import(await writePng('a.png', 100, 100));
      final second = await service.import(await writePng('b.png', 100, 100));

      expect(first, isNot(second));
    });

    test('不支持的扩展名直接拒绝', () async {
      final file = File(p.join(documents.path, 'note.txt'));
      await file.writeAsString('not an image');

      expect(
        () => service.import(file),
        throwsA(isA<BackgroundImageException>()),
      );
    });

    test('扩展名对但内容不是图片时报错，而不是存下一个坏文件', () async {
      final file = File(p.join(documents.path, 'fake.png'));
      await file.writeAsBytes(Uint8List.fromList(List.filled(64, 7)));

      expect(
        () => service.import(file),
        throwsA(isA<BackgroundImageException>()),
      );
    });

    test('超过体积上限的图被拦下', () async {
      final file = File(p.join(documents.path, 'big.png'));
      await file.writeAsBytes(
        Uint8List(BackgroundImageService.maxSourceBytes + 1),
      );

      expect(
        () => service.import(file),
        throwsA(isA<BackgroundImageException>()),
      );
    });
  });

  group('清理', () {
    test('remove 删掉指定的图，文件已经不在也不报错', () async {
      final name = await service.import(await writePng('x.png', 80, 80));
      expect(service.resolvePath(name), isNotNull);

      await service.remove(name);
      expect(service.resolvePath(name), isNull);
      await service.remove(name); // 再删一次
    });

    // 换背景是「先写新图、再改偏好」，中间崩了就留下没人引用的孤儿文件。
    test('pruneExcept 只留下还在用的那一张', () async {
      final orphanA = await service.import(await writePng('1.png', 60, 60));
      final orphanB = await service.import(await writePng('2.png', 60, 60));
      final keep = await service.import(await writePng('3.png', 60, 60));

      await service.pruneExcept(keep);

      expect(service.resolvePath(keep), isNotNull);
      expect(service.resolvePath(orphanA), isNull);
      expect(service.resolvePath(orphanB), isNull);
    });

    test('目录还不存在时 pruneExcept 什么都不做', () async {
      await service.pruneExcept(null);
    });
  });
}
