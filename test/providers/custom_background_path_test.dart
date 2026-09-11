import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yunchuang/models/reading_background.dart';
import 'package:yunchuang/providers/preferences_provider.dart';
import 'package:yunchuang/providers/ui_provider.dart';
import 'package:yunchuang/services/background_image_service.dart';

void main() {
  late Directory documents;

  setUp(() async {
    documents = await Directory.systemTemp.createTemp('yunchuang_bgprov_');
  });

  tearDown(() async {
    if (await documents.exists()) await documents.delete(recursive: true);
  });

  Future<ProviderContainer> containerWith(
    Map<String, Object> preferences, {
    bool injectDocuments = true,
  }) async {
    SharedPreferences.setMockInitialValues(preferences);
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        if (injectDocuments)
          appDocumentsDirectoryProvider.overrideWithValue(documents),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  Future<File> writeBackground(String name) async {
    final directory =
        Directory(p.join(documents.path, BackgroundImageService.directoryName));
    await directory.create(recursive: true);
    final file = File(p.join(directory.path, name));
    await file.writeAsBytes(const [1, 2, 3]);
    return file;
  }

  test('文件在就给出绝对路径', () async {
    final file = await writeBackground('wall.png');
    final container =
        await containerWith({'customBackgroundPath': 'wall.png'});

    expect(container.read(customBackgroundPathProvider), file.path);
  });

  // 换过设备、恢复了不含背景图的老备份、用户自己在系统里删了文件——偏好
  // 还指着它。这时候要给出 null，让 AppBackground 退回纯色。
  test('偏好指向的文件不在就给出 null', () async {
    final container =
        await containerWith({'customBackgroundPath': 'gone.png'});

    expect(container.read(customBackgroundPathProvider), isNull);
  });

  test('没设过背景图时给出 null', () async {
    final container = await containerWith(const {});

    expect(container.read(customBackgroundPathProvider), isNull);
  });

  // appDocumentsDirectoryProvider 要在 main() 里注入。没用过背景图的人不该
  // 因此被拖下水——所有挂载整个 App 的测试也就不用先准备一个文档目录。
  test('没设过背景图时不去碰未注入的文档目录', () async {
    final container = await containerWith(const {}, injectDocuments: false);

    expect(container.read(customBackgroundPathProvider), isNull);
  });

  group('effectiveBackgroundStyleProvider', () {
    // 恢复一份不含 backgrounds/ 的老备份（v3 及以前），或者用户自己把图删了，
    // 偏好里就会留下「custom + 一个不存在的文件」。渲染层会安静退回纯色，
    // 设置页如果照着存的值画，就会显示「自定义图片」选中却什么都没有，
    // 还多一条对不上任何东西的浓度滑块。
    test('custom 但图片不在时按纯色生效', () async {
      final container = await containerWith({
        'appBackgroundStyle': 'custom',
        'customBackgroundPath': 'gone.png',
      });

      expect(
        container.read(effectiveBackgroundStyleProvider),
        AppBackgroundStyle.solid,
      );
      // 存的值不动：不在 build 里写偏好，用户重新选张图就自然修好了。
      expect(
        container.read(preferencesProvider).backgroundStyle,
        AppBackgroundStyle.custom,
      );
    });

    test('图片在就照常是 custom', () async {
      await writeBackground('wall.png');
      final container = await containerWith({
        'appBackgroundStyle': 'custom',
        'customBackgroundPath': 'wall.png',
      });

      expect(
        container.read(effectiveBackgroundStyleProvider),
        AppBackgroundStyle.custom,
      );
    });

    test('其余样式原样透传，不去碰文档目录', () async {
      for (final style in const ['solid', 'gradient', 'illustration']) {
        final container = await containerWith(
          {'appBackgroundStyle': style},
          injectDocuments: false,
        );
        expect(
          container.read(effectiveBackgroundStyleProvider).storageValue,
          style,
        );
      }
    });
  });

  test('设过背景图但文档目录没注入时如实抛错，而不是静默当成没有', () async {
    final container = await containerWith(
      {'customBackgroundPath': 'wall.png'},
      injectDocuments: false,
    );

    expect(
      () => container.read(customBackgroundPathProvider),
      throwsUnimplementedError,
    );
  });
}
