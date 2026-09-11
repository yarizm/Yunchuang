import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yunchuang/pages/settings/webdav_page.dart';
import 'package:yunchuang/providers/preferences_provider.dart';
import 'package:yunchuang/providers/webdav_provider.dart';
import 'package:yunchuang/services/webdav_service.dart';
import 'package:yunchuang/theme/app_theme.dart';

/// 记录调用并按需抛错的假服务，不碰网络。
class FakeWebDavService implements WebDavService {
  final Object? failWith;
  final List<WebDavEntry> entries;
  WebDavConfig? lastTestedConfig;
  int listCalls = 0;

  FakeWebDavService({this.failWith, this.entries = const []});

  @override
  Future<void> testConnection(WebDavConfig config) async {
    lastTestedConfig = config;
    if (failWith != null) throw failWith!;
  }

  @override
  Future<List<WebDavEntry>> listBackups(WebDavConfig config) async {
    listCalls++;
    if (failWith != null) throw failWith!;
    return entries;
  }

  @override
  Future<void> ensureRemoteDir(WebDavConfig config) async {}

  @override
  Future<WebDavEntry> uploadBackup(
      WebDavConfig config, String localPath) async {
    throw UnimplementedError();
  }

  @override
  Future<String> downloadBackup(
    WebDavConfig config,
    String name,
    String targetPath,
  ) async {
    throw UnimplementedError();
  }
}

Future<void> _pump(
  WidgetTester tester, {
  required FakeWebDavService service,
  Map<String, Object> prefs = const {},
}) async {
  SharedPreferences.setMockInitialValues(prefs);
  final instance = await SharedPreferences.getInstance();

  // 页面是一列表单加两组卡片，默认 800x600 视口放不下，下面的列表项点不到。
  tester.view.physicalSize = const Size(500, 1600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(instance),
        webDavServiceProvider.overrideWithValue(service),
      ],
      child: MaterialApp(
        theme: AppTheme.lightTheme,
        home: const WebDavPage(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('已保存的配置回填到表单', (tester) async {
    await _pump(
      tester,
      service: FakeWebDavService(),
      prefs: const {
        'webdavBaseUrl': 'https://dav.example.com/dav',
        'webdavUsername': 'reader',
        'webdavRemoteDir': 'books',
      },
    );

    expect(
      tester
          .widget<TextField>(find.byKey(const Key('webdav-url')))
          .controller!
          .text,
      'https://dav.example.com/dav',
    );
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('webdav-username')))
          .controller!
          .text,
      'reader',
    );
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('webdav-dir')))
          .controller!
          .text,
      'books',
    );
  });

  testWidgets('密码默认遮蔽', (tester) async {
    await _pump(tester, service: FakeWebDavService());

    final field =
        tester.widget<TextField>(find.byKey(const Key('webdav-password')));
    expect(field.obscureText, isTrue);
  });

  // 用户改完输入框直接点按钮，用的应该是眼前这份配置，而不是上次保存的。
  testWidgets('测试连接用表单里的当前值，并顺带保存', (tester) async {
    final service = FakeWebDavService();
    await _pump(tester, service: service);

    await tester.enterText(
      find.byKey(const Key('webdav-url')),
      'https://new.example.com',
    );
    await tester.enterText(find.byKey(const Key('webdav-username')), 'newuser');
    await tester.tap(find.byKey(const Key('webdav-test')));
    await tester.pumpAndSettle();

    expect(service.lastTestedConfig?.baseUrl, 'https://new.example.com');
    expect(service.lastTestedConfig?.username, 'newuser');
    expect(find.text('连接成功'), findsWidgets);
  });

  testWidgets('连接失败时显示服务端给出的原因', (tester) async {
    await _pump(
      tester,
      service: FakeWebDavService(
        failWith: const WebDavException('认证失败，请检查用户名与密码'),
      ),
    );

    await tester.tap(find.byKey(const Key('webdav-test')));
    await tester.pumpAndSettle();

    expect(find.text('认证失败，请检查用户名与密码'), findsWidgets);
  });

  testWidgets('远端列表展示备份名、大小与时间', (tester) async {
    final service = FakeWebDavService(entries: [
      WebDavEntry(
        name: 'backup_2026-09-04.zip',
        size: 2 * 1024 * 1024,
        modifiedAt: DateTime.utc(2026, 9, 4, 10, 30),
      ),
    ]);
    await _pump(tester, service: service);

    await tester.tap(find.byKey(const Key('webdav-refresh')));
    await tester.pumpAndSettle();

    expect(find.text('backup_2026-09-04.zip'), findsOneWidget);
    expect(find.textContaining('2.0 MB'), findsOneWidget);
  });

  testWidgets('远端为空时说明还没上传过，而不是留白', (tester) async {
    await _pump(tester, service: FakeWebDavService(entries: const []));

    await tester.tap(find.byKey(const Key('webdav-refresh')));
    await tester.pumpAndSettle();

    expect(find.text('还没有上传过备份'), findsOneWidget);
  });

  // 恢复会整体覆盖本机数据，必须先确认。
  testWidgets('点远端备份先弹确认框，取消则不下载', (tester) async {
    final service = FakeWebDavService(entries: [
      const WebDavEntry(name: 'backup.zip', size: 10),
    ]);
    await _pump(tester, service: service);

    await tester.tap(find.byKey(const Key('webdav-refresh')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('webdav-entry-backup.zip')));
    await tester.pumpAndSettle();

    expect(find.text('从远端恢复'), findsOneWidget);
    // 页面底部的说明文字里也有「覆盖本机」，所以限定在弹窗内找。
    expect(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.textContaining('覆盖本机'),
      ),
      findsOneWidget,
    );

    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();

    // downloadBackup 会抛 UnimplementedError，没崩说明确实没被调用。
    expect(tester.takeException(), isNull);
  });
}
