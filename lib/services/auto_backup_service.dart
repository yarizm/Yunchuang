import 'package:shared_preferences/shared_preferences.dart';

import 'backup_service.dart';
import 'webdav_service.dart';

/// 自动备份的间隔。
///
/// 没有「每次启动」这一档：导出要 VACUUM 整个数据库再拷贝全部书籍，
/// 每次开应用都跑一遍既慢又费流量。
enum AutoBackupInterval {
  off('off', '关闭', null),
  daily('daily', '每天', Duration(days: 1)),
  weekly('weekly', '每周', Duration(days: 7));

  final String storageValue;
  final String label;
  final Duration? period;

  const AutoBackupInterval(this.storageValue, this.label, this.period);

  static AutoBackupInterval fromStorage(String? value) {
    for (final item in values) {
      if (item.storageValue == value) return item;
    }
    return AutoBackupInterval.off;
  }
}

/// 是否该跑一次自动备份。
///
/// [lastRunAt] 为空表示从没跑过——开启后第一次启动就备份一次，否则用户
/// 打开开关后要等满一个周期才看到第一份，会以为没生效。
///
/// [lastRunAt] 落在未来时也视为到期：设备时间被改过（或跨时区回拨）不该
/// 让自动备份从此再也不触发。
bool isAutoBackupDue({
  required AutoBackupInterval interval,
  required DateTime? lastRunAt,
  required DateTime now,
}) {
  final period = interval.period;
  if (period == null) return false;
  if (lastRunAt == null) return true;
  if (lastRunAt.isAfter(now)) return true;
  return now.difference(lastRunAt) >= period;
}

/// 自动备份的结果，供设置页显示上次状态。
enum AutoBackupOutcome {
  /// 没开、没到期，或 WebDAV 没配完整。
  skipped,
  uploaded,
  failed,
}

class AutoBackupResult {
  final AutoBackupOutcome outcome;
  final String message;

  const AutoBackupResult(this.outcome, this.message);
}

/// 到期时导出一份备份并传到 WebDAV。
///
/// 触发点在应用启动而不是退到后台：后台进程随时可能被系统回收，导出跑到
/// 一半被杀既留下垃圾文件也不会有备份；启动时进程活着，用户也在场。
class AutoBackupService {
  /// 间隔与上次运行时间都不带 `webdav` 前缀——那个前缀是备份导出时的凭据
  /// 黑名单（见 `BackupService`），而这两项是普通偏好，应该跟着备份走。
  static const intervalKey = 'autoBackupInterval';
  static const lastRunKey = 'autoBackupLastRunAt';

  final SharedPreferences _preferences;
  final WebDavService _webDav;
  final BackupService Function() _backupServiceFactory;
  final DateTime Function() _now;

  AutoBackupService({
    required SharedPreferences preferences,
    required WebDavService webDav,
    required BackupService Function() backupServiceFactory,
    DateTime Function()? now,
  })  : _preferences = preferences,
        _webDav = webDav,
        _backupServiceFactory = backupServiceFactory,
        _now = now ?? DateTime.now;

  AutoBackupInterval get interval =>
      AutoBackupInterval.fromStorage(_preferences.getString(intervalKey));

  DateTime? get lastRunAt {
    final raw = _preferences.getString(lastRunKey);
    if (raw == null) return null;
    return DateTime.tryParse(raw)?.toLocal();
  }

  Future<void> setInterval(AutoBackupInterval value) =>
      _preferences.setString(intervalKey, value.storageValue);

  /// 到期就备份并上传，否则原样返回。
  ///
  /// 任何失败都只返回 [AutoBackupOutcome.failed]，不抛出——这是启动路径上
  /// 的后台动作，网盘连不上不该影响用户读书。
  ///
  /// 只有上传成功才记时间戳：失败后下次启动会再试，而不是等满一个周期。
  Future<AutoBackupResult> runIfDue(WebDavConfig config) async {
    if (!isAutoBackupDue(
      interval: interval,
      lastRunAt: lastRunAt,
      now: _now(),
    )) {
      return const AutoBackupResult(AutoBackupOutcome.skipped, '未到期');
    }
    if (!config.isComplete) {
      return const AutoBackupResult(
        AutoBackupOutcome.skipped,
        'WebDAV 未配置完整',
      );
    }
    try {
      // exportBackup 已经清掉 AI 密钥与 WebDAV 凭据——传上网盘和分享出去
      // 是同一类出口。
      final zipPath = await _backupServiceFactory().exportBackup();
      final entry = await _webDav.uploadBackup(config, zipPath);
      await _preferences.setString(
        lastRunKey,
        _now().toUtc().toIso8601String(),
      );
      return AutoBackupResult(
        AutoBackupOutcome.uploaded,
        '已自动备份 ${entry.name}',
      );
    } catch (error) {
      return AutoBackupResult(AutoBackupOutcome.failed, '自动备份失败：$error');
    }
  }
}
