import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yunchuang/services/shared_import_service.dart';
import 'package:yunchuang/widgets/shared_import_watcher.dart';

/// 用真实的 MethodChannel + mock handler，连同 Dart 侧的解码路径一起测，
/// 而不是替换掉 SharedImportService。
class _FakeNative {
  final List<List<String>> responses;
  int calls = 0;

  _FakeNative(this.responses);

  void install(WidgetTester tester) {
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SharedImportService.channel,
      (call) async {
        if (call.method != 'consumePending') return null;
        final index = calls++;
        return index < responses.length ? responses[index] : <String>[];
      },
    );
    addTearDown(() {
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SharedImportService.channel,
        null,
      );
    });
  }
}

void main() {
  late Directory temp;

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('shared_import');
  });

  tearDown(() {
    if (temp.existsSync()) temp.deleteSync(recursive: true);
  });

  String makeFile(String name) {
    final file = File('${temp.path}/$name')..writeAsStringSync('x');
    return file.path;
  }

  Future<List<List<String>>> pumpWatcher(
    WidgetTester tester,
    _FakeNative native,
  ) async {
    final received = <List<String>>[];
    native.install(tester);

    await tester.pumpWidget(
      MaterialApp(
        home: SharedImportWatcher(
          // 开发机是 Windows，不打开这个开关的话服务会直接短路返回空。
          service: SharedImportService(supportedOverride: true),
          onFiles: (paths) async => received.add(paths),
          child: const Text('书架'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return received;
  }

  testWidgets('启动后取走待导入文件并交给回调', (tester) async {
    final path = makeFile('a.epub');
    final received = await pumpWatcher(
        tester,
        _FakeNative([
          [path],
        ]));

    expect(received, [
      [path],
    ]);
  });

  testWidgets('没有待导入文件时不触发回调', (tester) async {
    final received = await pumpWatcher(tester, _FakeNative([[]]));

    expect(received, isEmpty);
  });

  // 原生侧记的是路径，文件可能在这之间被清理掉（缓存清理、用户手动删）。
  testWidgets('路径已不存在的条目被过滤掉', (tester) async {
    final alive = makeFile('alive.epub');
    final received = await pumpWatcher(
        tester,
        _FakeNative([
          [alive, '${temp.path}/gone.epub'],
        ]));

    expect(received, [
      [alive],
    ]);
  });

  testWidgets('回到前台时再取一次', (tester) async {
    final first = makeFile('first.epub');
    final second = makeFile('second.epub');
    final native = _FakeNative([
      [first],
      [second],
    ]);
    final received = await pumpWatcher(tester, native);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();

    expect(received, [
      [first],
      [second],
    ]);
  });

  testWidgets('child 原样渲染，不插入额外的可见层', (tester) async {
    await pumpWatcher(tester, _FakeNative([[]]));

    expect(find.text('书架'), findsOneWidget);
  });

  // 没有原生实现的平台（Windows）不该崩，也不该报错。
  testWidgets('channel 未实现时静默返回，不抛异常', (tester) async {
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SharedImportService.channel,
      (call) async => throw MissingPluginException(),
    );
    addTearDown(() {
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SharedImportService.channel,
        null,
      );
    });

    await tester.pumpWidget(
      MaterialApp(
        home: SharedImportWatcher(
          service: SharedImportService(supportedOverride: true),
          onFiles: (_) async {},
          child: const Text('书架'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('书架'), findsOneWidget);
  });

  // 缓存副本在导入后必须清掉：书已经拷进应用存储，留着只是白占体积，
  // 而缓存目录没人会主动清。
  testWidgets('导入结束后删掉缓存副本连同槽位目录', (tester) async {
    final slotDir = Directory('${temp.path}/shared_imports/1700000000_1')
      ..createSync(recursive: true);
    final shared = File('${slotDir.path}/book.epub')..writeAsStringSync('x');
    _FakeNative([
      [shared.path],
    ]).install(tester);

    await tester.pumpWidget(
      MaterialApp(
        home: SharedImportWatcher(
          service: SharedImportService(supportedOverride: true),
          onFiles: (_) async {},
          child: const SizedBox(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(shared.existsSync(), isFalse);
    expect(slotDir.existsSync(), isFalse);
  });
}
