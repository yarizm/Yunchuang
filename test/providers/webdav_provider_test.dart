import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yunchuang/providers/preferences_provider.dart';
import 'package:yunchuang/providers/webdav_provider.dart';
import 'package:yunchuang/services/webdav_service.dart';

/// 每个用例一份干净的存储。`setMockInitialValues` 会清空整个 store，
/// 所以只能在 setUp 里调一次——用它模拟「重开应用」会把刚存的东西抹掉。
late SharedPreferences prefs;

ProviderContainer _newContainer() {
  return ProviderContainer(
    overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
  );
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  test('没有存过配置时是空的，默认目录为 yunchuang', () {
    final container = _newContainer();
    addTearDown(container.dispose);

    final config = container.read(webDavConfigProvider);

    expect(config.baseUrl, '');
    expect(config.remoteDir, 'yunchuang');
    expect(config.isComplete, isFalse);
  });

  test('保存后能读回来，地址与用户名去掉首尾空格', () async {
    final container = _newContainer();
    addTearDown(container.dispose);

    await container.read(webDavConfigProvider.notifier).save(
          const WebDavConfig(
            baseUrl: '  https://dav.example.com/dav  ',
            username: ' reader ',
            password: 'secret',
            remoteDir: ' books ',
          ),
        );

    // 换一个 container 读，等价于重开应用后从磁盘加载。
    final saved = _newContainer();
    addTearDown(saved.dispose);
    final config = saved.read(webDavConfigProvider);

    expect(config.baseUrl, 'https://dav.example.com/dav');
    expect(config.username, 'reader');
    expect(config.remoteDir, 'books');
  });

  // 密码原样保存：前后空格可能是密码的一部分，不能 trim。
  test('密码不做 trim', () async {
    final container = _newContainer();
    addTearDown(container.dispose);

    await container.read(webDavConfigProvider.notifier).save(
          const WebDavConfig(
            baseUrl: 'https://x',
            username: 'u',
            password: '  pw  ',
          ),
        );

    final saved = _newContainer();
    addTearDown(saved.dispose);

    expect(saved.read(webDavConfigProvider).password, '  pw  ');
  });

  test('清空配置连密码一起删掉', () async {
    final container = _newContainer();
    addTearDown(container.dispose);
    final notifier = container.read(webDavConfigProvider.notifier);

    await notifier.save(
      const WebDavConfig(
        baseUrl: 'https://x',
        username: 'u',
        password: 'p',
      ),
    );
    await notifier.clear();

    expect(container.read(webDavConfigProvider).baseUrl, '');
    expect(container.read(webDavConfigProvider).password, '');

    final reopened = _newContainer();
    addTearDown(reopened.dispose);
    expect(reopened.read(webDavConfigProvider).baseUrl, '');
  });
}
