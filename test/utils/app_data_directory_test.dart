import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:yunchuang/utils/app_data_directory.dart';

void main() {
  test('YUNCHUANG_DATA_DIR 指向的目录会被使用，不存在则创建', () async {
    final temp = await Directory.systemTemp.createTemp('yunchuang_data_dir');
    addTearDown(() => temp.delete(recursive: true));
    final target = p.join(temp.path, 'nested', 'profile');

    final dir = await appDataDirectory(
      environment: {appDataDirectoryEnv: '  $target  '},
    );

    expect(p.equals(dir.path, target), isTrue, reason: dir.path);
    expect(await dir.exists(), isTrue);
  });

  test('变量为空白时忽略，回落到系统目录', () async {
    // 单元测试里没有 path_provider 插件，回落分支会抛 MissingPluginException；
    // 这里只要确认它没有把空串当成目录去建。
    await expectLater(
      appDataDirectory(environment: {appDataDirectoryEnv: '   '}),
      throwsA(isA<Object>()),
    );
    expect(Directory('   ').existsSync(), isFalse);
  });
}
