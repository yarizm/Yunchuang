import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yunchuang/database/app_database.dart';
import 'package:yunchuang/services/auto_backup_service.dart';
import 'package:yunchuang/services/backup_service.dart';
import 'package:yunchuang/services/webdav_service.dart';

class _MockWebDav extends Mock implements WebDavService {}

class _FakeConfig extends Fake implements WebDavConfig {}

void main() {
  group('isAutoBackupDue', () {
    final now = DateTime(2026, 9, 5, 12);

    bool due(AutoBackupInterval interval, DateTime? lastRun) => isAutoBackupDue(
          interval: interval,
          lastRunAt: lastRun,
          now: now,
        );

    test('关闭时永远不到期', () {
      expect(due(AutoBackupInterval.off, null), isFalse);
      expect(due(AutoBackupInterval.off, DateTime(2020)), isFalse);
    });

    // 打开开关后要等满一个周期才出现第一份备份的话，用户会以为没生效。
    test('从没跑过时立即到期', () {
      expect(due(AutoBackupInterval.daily, null), isTrue);
      expect(due(AutoBackupInterval.weekly, null), isTrue);
    });

    test('每天：满 24 小时才到期', () {
      expect(due(AutoBackupInterval.daily, now.subtract(const Duration(hours: 23))), isFalse);
      expect(due(AutoBackupInterval.daily, now.subtract(const Duration(hours: 24))), isTrue);
      expect(due(AutoBackupInterval.daily, now.subtract(const Duration(days: 3))), isTrue);
    });

    test('每周：满 7 天才到期', () {
      expect(due(AutoBackupInterval.weekly, now.subtract(const Duration(days: 6))), isFalse);
      expect(due(AutoBackupInterval.weekly, now.subtract(const Duration(days: 7))), isTrue);
    });

    // 设备时间被改过或跨时区回拨，不该让自动备份从此再也不触发。
    test('上次运行时间在未来时也视为到期', () {
      expect(
        due(AutoBackupInterval.daily, now.add(const Duration(days: 5))),
        isTrue,
      );
    });
  });

  group('AutoBackupInterval', () {
    test('从存储值还原，无法识别时退回关闭', () {
      expect(AutoBackupInterval.fromStorage('daily'), AutoBackupInterval.daily);
      expect(AutoBackupInterval.fromStorage('weekly'), AutoBackupInterval.weekly);
      expect(AutoBackupInterval.fromStorage(null), AutoBackupInterval.off);
      expect(AutoBackupInterval.fromStorage('每天'), AutoBackupInterval.off);
    });

    // 这两个键不能带 webdav 前缀：那是 BackupService 导出时的凭据黑名单，
    // 带上就会被排除在备份之外，而它们是应该跟着换设备走的普通偏好。
    test('偏好键不落进凭据黑名单前缀', () {
      expect(AutoBackupService.intervalKey.startsWith('webdav'), isFalse);
      expect(AutoBackupService.lastRunKey.startsWith('webdav'), isFalse);
    });
  });

  group('runIfDue', () {
    const config = WebDavConfig(
      baseUrl: 'https://dav.example.com',
      username: 'alice',
      password: 'pw',
    );
    const entry = WebDavEntry(name: 'backup_x.zip', size: 10);

    late _MockWebDav webDav;
    late AppDatabase database;
    late Directory temp;

    setUpAll(() {
      registerFallbackValue(_FakeConfig());
    });

    setUp(() async {
      TestWidgetsFlutterBinding.ensureInitialized();
      webDav = _MockWebDav();
      database = AppDatabase.connect(NativeDatabase.memory());
      temp = await Directory.systemTemp.createTemp('auto_backup');
    });

    tearDown(() async {
      await database.close();
      if (temp.existsSync()) temp.deleteSync(recursive: true);
    });

    Future<AutoBackupService> build({
      required String? interval,
      String? lastRun,
      DateTime? now,
    }) async {
      SharedPreferences.setMockInitialValues({
        if (interval != null) AutoBackupService.intervalKey: interval,
        if (lastRun != null) AutoBackupService.lastRunKey: lastRun,
      });
      final prefs = await SharedPreferences.getInstance();
      return AutoBackupService(
        preferences: prefs,
        webDav: webDav,
        backupServiceFactory: () => BackupService(
          database: database,
          appDirectoryProvider: () async => temp,
          preferencesProvider: () async => prefs,
        ),
        now: () => now ?? DateTime(2026, 9, 5, 12),
      );
    }

    test('关闭时不碰网络', () async {
      final service = await build(interval: 'off');

      final result = await service.runIfDue(config);

      expect(result.outcome, AutoBackupOutcome.skipped);
      verifyNever(() => webDav.uploadBackup(any(), any()));
    });

    test('未到期时不上传', () async {
      final service = await build(
        interval: 'daily',
        lastRun: DateTime(2026, 9, 5, 6).toUtc().toIso8601String(),
      );

      final result = await service.runIfDue(config);

      expect(result.outcome, AutoBackupOutcome.skipped);
      verifyNever(() => webDav.uploadBackup(any(), any()));
    });

    // 配置不完整时不该反复失败刷屏，直接跳过。
    test('WebDAV 没配完整时跳过', () async {
      final service = await build(interval: 'daily');

      final result = await service.runIfDue(
        const WebDavConfig(baseUrl: '', username: '', password: ''),
      );

      expect(result.outcome, AutoBackupOutcome.skipped);
      verifyNever(() => webDav.uploadBackup(any(), any()));
    });

    test('到期时导出并上传，然后记下时间', () async {
      when(() => webDav.uploadBackup(any(), any()))
          .thenAnswer((_) async => entry);
      final service = await build(interval: 'daily');

      final result = await service.runIfDue(config);

      expect(result.outcome, AutoBackupOutcome.uploaded);
      verify(() => webDav.uploadBackup(any(), any())).called(1);
      expect(service.lastRunAt, isNotNull);
    });

    // 失败后下次启动应该再试，而不是等满一个周期——所以不记时间戳。
    test('上传失败不记时间戳，下次启动会重试', () async {
      when(() => webDav.uploadBackup(any(), any()))
          .thenThrow(const WebDavException('网络不通'));
      final service = await build(interval: 'daily');

      final result = await service.runIfDue(config);

      expect(result.outcome, AutoBackupOutcome.failed);
      expect(service.lastRunAt, isNull);
    });

    // 这是启动路径上的后台动作，网盘连不上不该影响用户读书。
    test('失败不向外抛异常', () async {
      when(() => webDav.uploadBackup(any(), any()))
          .thenThrow(StateError('炸了'));
      final service = await build(interval: 'daily');

      await expectLater(service.runIfDue(config), completes);
    });
  });
}
