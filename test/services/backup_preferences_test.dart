import 'dart:convert';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yunchuang/database/app_database.dart';
import 'package:yunchuang/services/backup_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory temp;
  late AppDatabase database;

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('backup_prefs');
    database = AppDatabase.connect(NativeDatabase.memory());
  });

  tearDown(() async {
    await database.close();
    if (temp.existsSync()) temp.deleteSync(recursive: true);
  });

  BackupService serviceWith(SharedPreferences prefs) => BackupService(
        database: database,
        appDirectoryProvider: () async => temp,
        preferencesProvider: () async => prefs,
      );

  Future<SharedPreferences> prefsWith(Map<String, Object> values) async {
    SharedPreferences.setMockInitialValues(values);
    return SharedPreferences.getInstance();
  }

  Map<String, dynamic> preferencesInZip(String zipPath) {
    final archive = ZipDecoder().decodeBytes(File(zipPath).readAsBytesSync());
    final entry = archive.files.firstWhere(
      (file) => file.name.endsWith('preferences.json'),
      orElse: () => throw StateError('备份里没有 preferences.json'),
    );
    return jsonDecode(utf8.decode(entry.content as List<int>))
        as Map<String, dynamic>;
  }

  group('导出', () {
    test('全局偏好写进备份', () async {
      final prefs = await prefsWith({
        'fontSize': 18.5,
        'theme': 'sepia',
        'keepScreenOn': true,
        'lineFocusLineCount': 3,
      });

      final zipPath = await serviceWith(prefs).exportBackup();
      final stored = preferencesInZip(zipPath);

      expect(stored['fontSize'], 18.5);
      expect(stored['theme'], 'sepia');
      expect(stored['keepScreenOn'], isTrue);
      expect(stored['lineFocusLineCount'], 3);
    });

    // 与 AI 密钥同一条理由：备份会被分享或传上网盘。
    test('WebDAV 凭据整组不进备份', () async {
      final prefs = await prefsWith({
        'theme': 'dark',
        'webdavBaseUrl': 'https://dav.example.com',
        'webdavUsername': 'alice',
        'webdavPassword': 'hunter2',
        'webdavRemoteDir': 'yunchuang',
      });

      final zipPath = await serviceWith(prefs).exportBackup();
      final stored = preferencesInZip(zipPath);

      expect(stored['theme'], 'dark');
      for (final key in stored.keys) {
        expect(key.startsWith('webdav'), isFalse, reason: '$key 不该进备份');
      }
    });

    // 查整个文件的字节，不只查解析结果——分享出去的是这个 ZIP 本身。
    test('备份文件的字节里找不到 WebDAV 密码', () async {
      const secret = 'sup3rs3cr3t-webdav-pw';
      final prefs = await prefsWith({
        'theme': 'dark',
        'webdavPassword': secret,
      });

      final zipPath = await serviceWith(prefs).exportBackup();
      final bytes = File(zipPath).readAsBytesSync();
      final needle = utf8.encode(secret);

      var found = false;
      for (var i = 0; i + needle.length <= bytes.length; i++) {
        var match = true;
        for (var j = 0; j < needle.length; j++) {
          if (bytes[i + j] != needle[j]) {
            match = false;
            break;
          }
        }
        if (match) {
          found = true;
          break;
        }
      }
      expect(found, isFalse, reason: '备份文件的原始字节里仍能找到 WebDAV 密码');
    });
  });

  group('applyPendingPreferences', () {
    void stage(Map<String, Object> values) {
      File(p.join(temp.path, 'preferences.json'))
          .writeAsStringSync(jsonEncode(values));
    }

    test('写回各种类型并保留原类型', () async {
      stage({
        'fontSize': 21.0,
        'theme': 'dark',
        'keepScreenOn': true,
        'lineFocusLineCount': 5,
      });
      final prefs = await prefsWith({});

      final applied = await BackupService.applyPendingPreferences(
        prefs,
        appDirectoryProvider: () async => temp,
      );

      expect(applied, isTrue);
      expect(prefs.getDouble('fontSize'), 21.0);
      expect(prefs.getString('theme'), 'dark');
      expect(prefs.getBool('keepScreenOn'), isTrue);
      expect(prefs.getInt('lineFocusLineCount'), 5);
    });

    // 关键：不删的话每次启动都重放一遍，把用户后来改的设置反复冲掉。
    test('写回后删掉中间文件', () async {
      stage({'theme': 'dark'});
      final prefs = await prefsWith({});

      await BackupService.applyPendingPreferences(
        prefs,
        appDirectoryProvider: () async => temp,
      );

      expect(File(p.join(temp.path, 'preferences.json')).existsSync(), isFalse);
    });

    test('第二次启动不再改动设置', () async {
      stage({'theme': 'dark'});
      final prefs = await prefsWith({});
      await BackupService.applyPendingPreferences(
        prefs,
        appDirectoryProvider: () async => temp,
      );
      await prefs.setString('theme', 'sepia'); // 用户改回来

      final applied = await BackupService.applyPendingPreferences(
        prefs,
        appDirectoryProvider: () async => temp,
      );

      expect(applied, isFalse);
      expect(prefs.getString('theme'), 'sepia');
    });

    // 备份可能是别处改过的，导出侧挡一次不够。
    test('文件里带凭据也不写回', () async {
      stage({'theme': 'dark', 'webdavPassword': 'leaked'});
      final prefs = await prefsWith({});

      await BackupService.applyPendingPreferences(
        prefs,
        appDirectoryProvider: () async => temp,
      );

      expect(prefs.getString('theme'), 'dark');
      expect(prefs.getString('webdavPassword'), isNull);
    });

    test('没有文件时什么都不做', () async {
      final prefs = await prefsWith({'theme': 'light'});

      final applied = await BackupService.applyPendingPreferences(
        prefs,
        appDirectoryProvider: () async => temp,
      );

      expect(applied, isFalse);
      expect(prefs.getString('theme'), 'light');
    });

    // 设置恢复失败不该拖垮启动，但文件必须删掉，否则每次启动都重试。
    test('内容损坏时不抛异常，且删掉文件', () async {
      File(p.join(temp.path, 'preferences.json')).writeAsStringSync('{ 坏的');
      final prefs = await prefsWith({'theme': 'light'});

      final applied = await BackupService.applyPendingPreferences(
        prefs,
        appDirectoryProvider: () async => temp,
      );

      expect(applied, isFalse);
      expect(prefs.getString('theme'), 'light');
      expect(File(p.join(temp.path, 'preferences.json')).existsSync(), isFalse);
    });
  });

  // 端到端：真正会出错的是恢复链路的接线——preferences.json 要通过
  // _isAllowedEntry 的白名单，还要出现在 applyPendingRestore 的安装列表里。
  // 少任何一环，上面的单元测试都照样绿，而设置还是恢复不了。
  test('导出到恢复的完整往返能带回设置', () async {
    final source = await prefsWith({
      'fontSize': 22.0,
      'theme': 'sepia',
      'webdavPassword': 'hunter2',
    });
    final service = serviceWith(source);

    final archivePath = await service.exportBackup();
    final staged = await service.importBackup(archivePath);
    expect(staged.status, RestoreStatus.staged);

    final applied = await BackupService.applyPendingRestore(
      appDirectoryProvider: () async => temp,
    );
    expect(applied.status, RestoreStatus.applied);

    // 换设备的情形：新机器上偏好是空的。
    final target = await prefsWith({});
    final restored = await BackupService.applyPendingPreferences(
      target,
      appDirectoryProvider: () async => temp,
    );

    expect(restored, isTrue);
    expect(target.getDouble('fontSize'), 22.0);
    expect(target.getString('theme'), 'sepia');
    expect(target.getString('webdavPassword'), isNull);
  });
}
