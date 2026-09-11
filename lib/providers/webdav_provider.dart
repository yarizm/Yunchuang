import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/auto_backup_service.dart';
import '../services/backup_service.dart';
import '../services/webdav_service.dart';
import 'database_provider.dart';
import 'preferences_provider.dart';

class WebDavNotifier extends Notifier<WebDavConfig> {
  static const _kBaseUrl = 'webdavBaseUrl';
  static const _kUsername = 'webdavUsername';
  static const _kPassword = 'webdavPassword';
  static const _kRemoteDir = 'webdavRemoteDir';

  @override
  WebDavConfig build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    return WebDavConfig(
      baseUrl: prefs.getString(_kBaseUrl) ?? '',
      username: prefs.getString(_kUsername) ?? '',
      password: prefs.getString(_kPassword) ?? '',
      remoteDir: prefs.getString(_kRemoteDir) ?? 'yunchuang',
    );
  }

  Future<void> save(WebDavConfig config) async {
    final prefs = ref.read(sharedPreferencesProvider);
    await Future.wait([
      prefs.setString(_kBaseUrl, config.baseUrl.trim()),
      prefs.setString(_kUsername, config.username.trim()),
      prefs.setString(_kPassword, config.password),
      prefs.setString(_kRemoteDir, config.remoteDir.trim()),
    ]);
    state = config;
  }

  /// 清空配置，包括密码。
  Future<void> clear() async {
    final prefs = ref.read(sharedPreferencesProvider);
    await Future.wait([
      prefs.remove(_kBaseUrl),
      prefs.remove(_kUsername),
      prefs.remove(_kPassword),
      prefs.remove(_kRemoteDir),
    ]);
    state = const WebDavConfig(baseUrl: '', username: '', password: '');
  }
}

final webDavConfigProvider =
    NotifierProvider<WebDavNotifier, WebDavConfig>(WebDavNotifier.new);

/// 备份包可能上百 MB，超时给得比普通接口宽。
final webDavDioProvider = Provider<Dio>((ref) {
  final dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 20),
    sendTimeout: const Duration(minutes: 10),
    receiveTimeout: const Duration(minutes: 10),
  ));
  ref.onDispose(dio.close);
  return dio;
});

final webDavServiceProvider = Provider<WebDavService>((ref) {
  return WebDavService(ref.watch(webDavDioProvider));
});

final autoBackupServiceProvider = Provider<AutoBackupService>((ref) {
  return AutoBackupService(
    preferences: ref.watch(sharedPreferencesProvider),
    webDav: ref.watch(webDavServiceProvider),
    // 工厂而不是实例：BackupService 每次导出都会打开一个数据库快照，
    // 常驻一个没有意义。
    backupServiceFactory: () => BackupService(
      database: ref.read(databaseProvider),
    ),
  );
});
