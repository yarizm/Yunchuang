import 'dart:convert';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:drift/drift.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

import '../database/app_database.dart';
import '../utils/app_data_directory.dart';

typedef AppDirectoryProvider = Future<Directory> Function();

enum RestoreStatus { none, staged, applied, failed }

class RestoreResult {
  final RestoreStatus status;
  final String message;

  const RestoreResult(this.status, this.message);
}

class BackupException implements Exception {
  final String message;
  final Object? cause;

  const BackupException(this.message, [this.cause]);

  @override
  String toString() => cause == null ? message : '$message: $cause';
}

/// Creates portable backups and stages validated restores.
class BackupService {
  /// v4 起多了 `backgrounds/`（用户自选的背景图）。
  ///
  /// 光加目录本来不必动版本号，但导入时遇到不认识的条目是**硬失败**（见
  /// [_isAllowedEntry] 的调用处）。老版本装上新备份，与其报「备份包含不
  /// 允许的文件: backgrounds/xxx.png」，不如让它在版本校验那一步就说清楚
  /// 是格式太新。
  static const backupFormatVersion = 4;
  static const _pendingDirectoryName = 'restore_pending';

  /// 沿用旧名，不随项目更名为 yunchuang。
  ///
  /// manifest 里没有记录数据库文件名，导入时是拿这个常量去比对压缩包条目的
  /// （见 [_isKnownRootEntry]）。改了它，用户手上**已经导出的备份 ZIP 会全部
  /// 失效**；同理 [_openConnection] 里的库文件名也不能改，否则旧安装升级后
  /// 找不到自己的数据。文件格式标识符与项目名是两回事。
  static const _databaseName = 'reading_offline.db';
  static const _manifestName = 'manifest.json';

  /// 全局阅读偏好（字号、行高、主题、剧透档位等）存在 SharedPreferences，
  /// 不在数据库里，所以要单独打一份进备份——否则换设备恢复后设置全丢。
  /// 按书覆盖的设置在 book_reading_settings 表里，随数据库走，不受影响。
  static const _preferencesName = 'preferences.json';

  /// 自定义背景图目录，与 `BackgroundImageService.directoryName` 一致。
  ///
  /// 偏好里存的是文件名，目录和 preferences.json 一起进备份，换设备恢复后
  /// 两边还能对上——这正是当初不存绝对路径的原因。
  static const _backgroundsName = 'backgrounds';

  /// 前缀命中就不进备份。
  ///
  /// 与 AI 密钥同一条理由（见 [_redactCredentials]）：备份的出口是系统分享
  /// 或 WebDAV 网盘，凭据跟着 ZIP 走出去就是泄露。整组排除而不是只去掉密码，
  /// 是为了不留「填了地址和用户名、密码却是空的」这种半配置状态。
  /// 还原后重新填一次即可。
  ///
  /// 新增存放凭据的偏好键时必须让它落进这里的前缀。
  static const _credentialKeyPrefixes = ['webdav'];

  static bool _isCredentialKey(String key) =>
      _credentialKeyPrefixes.any(key.startsWith);
  static const _maxExpandedBytes = 4 * 1024 * 1024 * 1024;

  final AppDatabase _database;
  final AppDirectoryProvider _appDirectoryProvider;

  BackupService({
    required AppDatabase database,
    AppDirectoryProvider? appDirectoryProvider,
    Future<SharedPreferences> Function()? preferencesProvider,
  })  : _database = database,
        _appDirectoryProvider =
            appDirectoryProvider ?? appDataDirectory,
        _preferencesProvider =
            preferencesProvider ?? SharedPreferences.getInstance;

  final Future<SharedPreferences> Function() _preferencesProvider;

  Future<String> exportBackup() async {
    final appDir = await _appDirectoryProvider();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final workDir = Directory(p.join(appDir.path, '.backup_$timestamp'));
    final payloadDir = Directory(p.join(workDir.path, 'payload'));
    final snapshot = File(p.join(payloadDir.path, _databaseName));

    await payloadDir.create(recursive: true);
    try {
      final escapedPath = snapshot.path.replaceAll("'", "''");
      await _database.customStatement("VACUUM INTO '$escapedPath'");

      final snapshotDb = AppDatabase.forFile(snapshot);
      try {
        final books = await snapshotDb.select(snapshotDb.books).get();
        for (final book in books) {
          final bookPath = await _copyReferencedFile(
            payloadDir,
            book.filePath,
            'books',
            book.id,
          );
          final coverPath = await _copyReferencedFile(
            payloadDir,
            book.coverPath,
            'covers',
            book.id,
          );
          await (snapshotDb.update(snapshotDb.books)
                ..where((row) => row.id.equals(book.id)))
              .write(BooksCompanion(
            filePath: Value(bookPath ?? ''),
            coverPath: Value(coverPath),
          ));
        }
        final dictionaries =
            await snapshotDb.select(snapshotDb.dictionarySources).get();
        for (final dictionary in dictionaries) {
          final dataPath = await _copyReferencedFile(
            payloadDir,
            dictionary.dataFilePath,
            'dictionaries',
            dictionary.id,
          );
          await (snapshotDb.update(snapshotDb.dictionarySources)
                ..where((row) => row.id.equals(dictionary.id)))
              .write(
            DictionarySourcesCompanion(
              dataFilePath: Value(dataPath ?? ''),
            ),
          );
        }
        await _redactCredentials(snapshotDb);
        await snapshotDb.customStatement('PRAGMA wal_checkpoint(TRUNCATE)');
      } finally {
        await snapshotDb.close();
      }

      final manifestBytes = utf8.encode(jsonEncode({
        'formatVersion': backupFormatVersion,
        'schemaVersion': _database.schemaVersion,
        'createdAt': DateTime.now().toUtc().toIso8601String(),
      }));
      await File(p.join(payloadDir.path, _manifestName))
          .writeAsBytes(manifestBytes, flush: true);
      await _writePreferences(payloadDir);
      await _copyDirectory(
        Directory(p.join(appDir.path, _backgroundsName)),
        Directory(p.join(payloadDir.path, _backgroundsName)),
      );

      final zipPath = p.join(appDir.path, 'backup_$timestamp.zip');
      await ZipFileEncoder().zipDirectoryAsync(
        payloadDir,
        filename: zipPath,
      );
      if (!await File(zipPath).exists()) {
        throw const BackupException('无法编码备份文件');
      }
      return zipPath;
    } catch (error) {
      if (error is BackupException) rethrow;
      throw BackupException('导出备份失败', error);
    } finally {
      if (await workDir.exists()) {
        await workDir.delete(recursive: true);
      }
    }
  }

  /// 把全局偏好写进 payload，凭据除外（见 [_credentialKeyPrefixes]）。
  ///
  /// 偏好读不出来不该让整个备份失败——书和笔记才是主体，设置丢了重新调
  /// 就行，所以这里吞掉异常只跳过这一步。
  Future<void> _writePreferences(Directory payloadDir) async {
    try {
      final prefs = await _preferencesProvider();
      final data = <String, Object>{};
      for (final key in prefs.getKeys()) {
        if (_isCredentialKey(key)) continue;
        final value = prefs.get(key);
        if (value != null) data[key] = value;
      }
      await File(p.join(payloadDir.path, _preferencesName))
          .writeAsString(jsonEncode(data), flush: true);
    } catch (_) {
      // 没有偏好文件的备份仍然可以正常恢复，见 applyPendingPreferences。
    }
  }

  /// 把恢复出来的偏好写回 SharedPreferences，然后删掉中间文件。
  ///
  /// 单独一步、不并进 [applyPendingRestore]：那一步跑在
  /// `SharedPreferences.getInstance()` 之前（数据库必须先就位），拿不到
  /// prefs 实例。所以恢复时只把 preferences.json 放到应用目录，等 main()
  /// 拿到 prefs 之后再调这里。
  ///
  /// 返回是否真的写入过。任何一步失败都只是设置没恢复，不该影响启动，
  /// 所以异常一律吞掉——但中间文件必须删，否则每次启动都会重放一遍，
  /// 把用户后来改的设置反复冲掉。
  static Future<bool> applyPendingPreferences(
    SharedPreferences prefs, {
    AppDirectoryProvider? appDirectoryProvider,
  }) async {
    final directoryProvider =
        appDirectoryProvider ?? appDataDirectory;
    final File file;
    try {
      final appDir = await directoryProvider();
      file = File(p.join(appDir.path, _preferencesName));
      if (!await file.exists()) return false;
    } catch (_) {
      return false;
    }
    try {
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! Map) return false;
      for (final entry in decoded.entries) {
        final key = entry.key.toString();
        // 导出时已经排除过，这里再挡一次：备份文件可能是别处改过的。
        if (_isCredentialKey(key)) continue;
        final value = entry.value;
        if (value is bool) {
          await prefs.setBool(key, value);
        } else if (value is int) {
          await prefs.setInt(key, value);
        } else if (value is double) {
          await prefs.setDouble(key, value);
        } else if (value is String) {
          await prefs.setString(key, value);
        } else if (value is List) {
          await prefs.setStringList(
            key,
            value.map((item) => item.toString()).toList(),
          );
        }
      }
      return true;
    } catch (_) {
      return false;
    } finally {
      try {
        await file.delete();
      } catch (_) {
        // 删不掉最多下次启动再放一次，不影响本次。
      }
    }
  }

  /// 清除快照中的凭据，导出的备份不含 AI 密钥。
  ///
  /// 导出的唯一出口是系统分享（见 `pages/settings/data_management.dart`）：
  /// 备份 ZIP 会被发进网盘、聊天窗口或邮箱，明文密钥跟着走出去就是泄露。
  /// 还原后重新填一次密钥是几十秒的事，泄露一次却要付账单——因此无条件清除，
  /// 不提供"包含密钥"开关。
  ///
  /// 新增存放密钥或令牌的列时必须同步加到这里。`aiProviders.extraConfig` 是
  /// 自由格式 JSON，目前只写入 null；若将来往里塞凭据，也要在此清除。
  static Future<void> _redactCredentials(AppDatabase snapshot) async {
    // SQLite 默认不擦除被释放的内容，行内改写后旧密钥可能留在页的空闲区里。
    // 分享出去的是文件本身，光让 SELECT 查不到不算清除。
    await snapshot.customStatement('PRAGMA secure_delete=ON');
    await snapshot.update(snapshot.aiProviders).write(
          const AiProvidersCompanion(apiKey: Value<String?>(null)),
        );
  }

  Future<String?> _copyReferencedFile(
    Directory payloadDir,
    String? sourcePath,
    String directory,
    int entityId,
  ) async {
    if (sourcePath == null || sourcePath.isEmpty) return null;
    final source = File(sourcePath);
    if (!await source.exists()) return null;

    final safeName = p
        .basename(source.path)
        .replaceAll(RegExp(r'[^A-Za-z0-9._\-\u4e00-\u9fff]'), '_');
    final archivePath = '$directory/${entityId}_$safeName';
    final target =
        File(p.joinAll([payloadDir.path, ...archivePath.split('/')]));
    await target.parent.create(recursive: true);
    await source.copy(target.path);
    return archivePath;
  }

  Future<RestoreResult> importBackup(String zipPath) async {
    final appDir = await _appDirectoryProvider();
    final pendingDir = Directory(p.join(appDir.path, _pendingDirectoryName));
    final stagingDir = Directory(
      p.join(
        appDir.path,
        '.restore_${DateTime.now().millisecondsSinceEpoch}',
      ),
    );

    try {
      await stagingDir.create(recursive: true);
      final input = InputFileStream(zipPath);
      final archive = ZipDecoder().decodeBuffer(input);
      var expandedBytes = 0;
      var hasDatabase = false;

      try {
        for (final entry in archive) {
          if (!entry.isFile) continue;
          final safePath = _validateEntryPath(entry.name);
          if (!_isAllowedEntry(safePath)) {
            throw BackupException('备份包含不允许的文件: ${entry.name}');
          }
          expandedBytes += entry.size;
          if (expandedBytes > _maxExpandedBytes) {
            throw const BackupException('备份解压后超过 4GB 限制');
          }

          final output = File(
            p.joinAll([stagingDir.path, ...safePath.split('/')]),
          );
          await _writeArchiveEntry(entry, output);
          hasDatabase = hasDatabase || safePath == _databaseName;
        }
      } finally {
        await input.close();
      }

      if (!hasDatabase) {
        throw const BackupException('备份中缺少数据库文件');
      }
      await _validateManifest(stagingDir);
      await _validateAndPrepareDatabase(stagingDir, appDir);

      if (await pendingDir.exists()) {
        await pendingDir.delete(recursive: true);
      }
      await stagingDir.rename(pendingDir.path);
      return const RestoreResult(
        RestoreStatus.staged,
        '备份已验证，请重启应用完成恢复',
      );
    } catch (error) {
      if (error is BackupException) rethrow;
      throw BackupException('导入备份失败', error);
    } finally {
      if (await stagingDir.exists()) {
        await stagingDir.delete(recursive: true);
      }
    }
  }

  Future<void> _writeArchiveEntry(ArchiveFile entry, File output) async {
    await output.parent.create(recursive: true);
    final stream = OutputFileStream(output.path);
    try {
      if (entry.rawContent != null &&
          (entry.compressionType == ArchiveFile.STORE ||
              entry.compressionType == ArchiveFile.DEFLATE)) {
        entry.clear();
        entry.decompress(stream);
      } else {
        entry.writeContent(stream);
      }
    } finally {
      await stream.close();
      entry.clear();
    }
  }

  String _validateEntryPath(String rawName) {
    final portable = rawName.replaceAll('\\', '/');
    final normalized = p.posix.normalize(portable);
    if (portable.startsWith('/') ||
        RegExp(r'^[A-Za-z]:').hasMatch(portable) ||
        normalized == '..' ||
        normalized.startsWith('../') ||
        normalized.contains('/../')) {
      throw BackupException('备份包含不安全路径: $rawName');
    }
    return normalized;
  }

  bool _isAllowedEntry(String name) {
    return name == _databaseName ||
        name == _manifestName ||
        name == _preferencesName ||
        name.startsWith('books/') ||
        name.startsWith('covers/') ||
        name.startsWith('dictionaries/') ||
        name.startsWith('$_backgroundsName/');
  }

  /// 整目录拷进 payload。目录不存在就跳过——没设过自定义背景是常态。
  ///
  /// 背景图不像书籍和词典那样由数据库行引用，没有 id 可以拿来命名，所以
  /// 不能复用 [_copyReferencedFile]。
  static Future<void> _copyDirectory(Directory source, Directory target) async {
    if (!await source.exists()) return;
    await target.create(recursive: true);
    await for (final entity in source.list()) {
      if (entity is! File) continue;
      await entity.copy(p.join(target.path, p.basename(entity.path)));
    }
  }

  Future<void> _validateManifest(Directory stagingDir) async {
    final manifest = File(p.join(stagingDir.path, _manifestName));
    if (!await manifest.exists()) return; // Version 1 backups had no manifest.

    final data =
        jsonDecode(await manifest.readAsString()) as Map<String, dynamic>;
    final version = data['formatVersion'];
    if (version is! int || version < 1 || version > backupFormatVersion) {
      throw BackupException('不支持的备份格式版本: $version');
    }
  }

  Future<void> _validateAndPrepareDatabase(
    Directory stagingDir,
    Directory appDir,
  ) async {
    final databaseFile = File(p.join(stagingDir.path, _databaseName));
    final db = AppDatabase.forFile(databaseFile);
    try {
      final integrity = await db
          .customSelect('PRAGMA integrity_check')
          .map((row) => row.read<String>('integrity_check'))
          .getSingle();
      if (integrity.toLowerCase() != 'ok') {
        throw BackupException('数据库完整性检查失败: $integrity');
      }

      final books = await db.select(db.books).get();
      for (final book in books) {
        final filePath = _resolveRestoredPath(
          stagingDir,
          appDir,
          book.filePath,
          'books',
        );
        final coverPath = _resolveRestoredPath(
          stagingDir,
          appDir,
          book.coverPath,
          'covers',
        );
        await (db.update(db.books)..where((row) => row.id.equals(book.id)))
            .write(BooksCompanion(
          filePath: Value(filePath ?? ''),
          coverPath: Value(coverPath),
        ));
      }
      final dictionaries = await db.select(db.dictionarySources).get();
      for (final dictionary in dictionaries) {
        final dataPath = _resolveRestoredPath(
          stagingDir,
          appDir,
          dictionary.dataFilePath,
          'dictionaries',
        );
        await (db.update(db.dictionarySources)
              ..where((row) => row.id.equals(dictionary.id)))
            .write(
          DictionarySourcesCompanion(
            dataFilePath: Value(dataPath ?? ''),
          ),
        );
      }
      await db.customStatement('PRAGMA wal_checkpoint(TRUNCATE)');
    } finally {
      await db.close();
    }
  }

  String? _resolveRestoredPath(
    Directory stagingDir,
    Directory appDir,
    String? storedPath,
    String directory,
  ) {
    if (storedPath == null || storedPath.isEmpty) return null;
    final portable = storedPath.replaceAll('\\', '/');

    String relative;
    if (portable.startsWith('$directory/')) {
      relative = portable;
    } else {
      // Legacy backups stored absolute database paths and archived basenames.
      relative = '$directory/${p.basename(storedPath)}';
    }
    final stagedFile =
        File(p.joinAll([stagingDir.path, ...relative.split('/')]));
    if (!stagedFile.existsSync()) return null;
    return p.joinAll([appDir.path, ...relative.split('/')]);
  }

  /// Applies a previously validated restore before the live database opens.
  static Future<RestoreResult> applyPendingRestore({
    AppDirectoryProvider? appDirectoryProvider,
  }) async {
    final directoryProvider =
        appDirectoryProvider ?? appDataDirectory;
    final appDir = await directoryProvider();
    final pendingDir = Directory(p.join(appDir.path, _pendingDirectoryName));
    final legacyPending =
        File(p.join(appDir.path, 'reading_offline_pending.db'));
    if (!await pendingDir.exists() && await legacyPending.exists()) {
      await pendingDir.create(recursive: true);
      await legacyPending.rename(p.join(pendingDir.path, _databaseName));
    }
    if (!await pendingDir.exists()) {
      return const RestoreResult(RestoreStatus.none, '');
    }

    final pendingDatabase = File(p.join(pendingDir.path, _databaseName));
    if (!await pendingDatabase.exists()) {
      return _quarantinePending(appDir, pendingDir, '待恢复目录中缺少数据库');
    }
    try {
      final validationDatabase = AppDatabase.forFile(pendingDatabase);
      try {
        final integrity = await validationDatabase
            .customSelect('PRAGMA integrity_check')
            .map((row) => row.read<String>('integrity_check'))
            .getSingle();
        if (integrity.toLowerCase() != 'ok') {
          throw BackupException('待恢复数据库完整性检查失败: $integrity');
        }
      } finally {
        await validationDatabase.close();
      }
    } catch (error) {
      // Validation failed (corrupt db, schema newer than this app, etc.).
      // Quarantine the pending restore so the app still starts with existing
      // data instead of failing on every launch.
      return _quarantinePending(
        appDir,
        pendingDir,
        '待恢复备份校验失败，已隔离: $error',
      );
    }

    final rollbackDir = Directory(p.join(
      appDir.path,
      '.restore_rollback_${DateTime.now().millisecondsSinceEpoch}',
    ));
    await rollbackDir.create(recursive: true);
    final movedCurrent = <String>[];
    final installed = <String>[];
    var rollbackSafe = false;

    try {
      final replacementNames = <String>[
        _databaseName,
        '$_databaseName-wal',
        '$_databaseName-shm',
        _preferencesName,
        if (await Directory(p.join(pendingDir.path, 'books')).exists()) 'books',
        if (await Directory(p.join(pendingDir.path, 'covers')).exists())
          'covers',
        if (await Directory(p.join(pendingDir.path, 'dictionaries')).exists())
          'dictionaries',
        if (await Directory(p.join(pendingDir.path, _backgroundsName)).exists())
          _backgroundsName,
      ];
      for (final name in replacementNames) {
        final sourcePath = p.join(appDir.path, name);
        if (FileSystemEntity.typeSync(sourcePath) !=
            FileSystemEntityType.notFound) {
          await _renameEntity(sourcePath, p.join(rollbackDir.path, name));
          movedCurrent.add(name);
        }
      }

      for (final name in [
        _databaseName,
        // 只是放到应用目录，真正写回 SharedPreferences 在
        // applyPendingPreferences，由 main() 在拿到 prefs 之后调用。
        _preferencesName,
        'books',
        'covers',
        'dictionaries',
        _backgroundsName,
      ]) {
        final sourcePath = p.join(pendingDir.path, name);
        if (FileSystemEntity.typeSync(sourcePath) !=
            FileSystemEntityType.notFound) {
          await _renameEntity(sourcePath, p.join(appDir.path, name));
          installed.add(name);
        }
      }

      if (!installed.contains(_databaseName)) {
        throw const BackupException('待恢复目录中缺少数据库');
      }
      await pendingDir.delete(recursive: true);
      // Restore succeeded: the rollback copy is now disposable.
      rollbackSafe = true;
      return const RestoreResult(
        RestoreStatus.applied,
        '备份恢复已完成',
      );
    } catch (error) {
      // Best-effort rollback: try every entry even if one fails, and only
      // treat the rollback copy as disposable when every original was restored.
      var rollbackComplete = true;
      for (final name in installed.reversed) {
        final installedPath = p.join(appDir.path, name);
        try {
          if (FileSystemEntity.typeSync(installedPath) !=
              FileSystemEntityType.notFound) {
            await _deleteEntity(installedPath);
          }
        } catch (_) {
          rollbackComplete = false;
        }
      }
      for (final name in movedCurrent.reversed) {
        final rollbackPath = p.join(rollbackDir.path, name);
        try {
          if (FileSystemEntity.typeSync(rollbackPath) !=
              FileSystemEntityType.notFound) {
            await _renameEntity(rollbackPath, p.join(appDir.path, name));
          }
        } catch (_) {
          rollbackComplete = false;
        }
      }
      rollbackSafe = rollbackComplete;
      if (!rollbackComplete) {
        throw BackupException(
          '恢复失败且自动回滚不完整，原数据保留在 ${rollbackDir.path}，请手动恢复',
          error,
        );
      }
      // Rollback succeeded — original data is intact, let the app start.
      return RestoreResult(RestoreStatus.failed, '恢复失败，已回滚到原数据: $error');
    } finally {
      // Only delete the rollback copy when it is safe; otherwise it holds the
      // only copy of the user's original data.
      if (rollbackSafe && await rollbackDir.exists()) {
        await rollbackDir.delete(recursive: true);
      }
    }
  }

  static Future<RestoreResult> _quarantinePending(
    Directory appDir,
    Directory pendingDir,
    String message,
  ) async {
    final quarantine = Directory(p.join(
      appDir.path,
      'restore_failed_${DateTime.now().millisecondsSinceEpoch}',
    ));
    try {
      if (await pendingDir.exists()) {
        await pendingDir.rename(quarantine.path);
      }
    } catch (_) {
      // If it cannot be moved aside, delete it so the app does not loop on
      // every launch trying to apply a broken restore.
      if (await pendingDir.exists()) {
        await pendingDir.delete(recursive: true);
      }
    }
    return RestoreResult(RestoreStatus.failed, message);
  }

  static Future<void> _renameEntity(String source, String destination) async {
    final type = FileSystemEntity.typeSync(source);
    if (type == FileSystemEntityType.directory) {
      await Directory(source).rename(destination);
    } else {
      await File(source).rename(destination);
    }
  }

  static Future<void> _deleteEntity(String path) async {
    final type = FileSystemEntity.typeSync(path);
    if (type == FileSystemEntityType.directory) {
      await Directory(path).delete(recursive: true);
    } else if (type != FileSystemEntityType.notFound) {
      await File(path).delete();
    }
  }
}
