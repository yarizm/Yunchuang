import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../../providers/database_provider.dart';
import '../../services/auto_backup_service.dart';
import '../../providers/webdav_provider.dart';
import '../../services/backup_service.dart';
import '../../services/webdav_service.dart';
import '../../widgets/glass_container.dart';
import 'restore_staged_dialog.dart';

String _formatSize(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  return '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB';
}

String _two(int n) => n.toString().padLeft(2, '0');

String _formatTime(DateTime? at) {
  if (at == null) return '时间未知';
  final local = at.toLocal();
  return '${local.year}-${_two(local.month)}-${_two(local.day)} '
      '${_two(local.hour)}:${_two(local.minute)}';
}

/// WebDAV 备份同步。
///
/// 做的是「备份包上传 / 下载」，不是增量同步：没有冲突解决，也不合并两端
/// 的改动。覆盖的是「换设备」这个主要场景，复用已有的 [BackupService]，
/// 比自建同步协议少一个数量级的复杂度和出错面。
class WebDavPage extends ConsumerStatefulWidget {
  const WebDavPage({super.key});

  @override
  ConsumerState<WebDavPage> createState() => _WebDavPageState();
}

class _WebDavPageState extends ConsumerState<WebDavPage> {
  late final TextEditingController _urlController;
  late final TextEditingController _userController;
  late final TextEditingController _passwordController;
  late final TextEditingController _dirController;

  bool _busy = false;
  bool _obscurePassword = true;
  String? _status;
  List<WebDavEntry>? _entries;

  @override
  void initState() {
    super.initState();
    final config = ref.read(webDavConfigProvider);
    _urlController = TextEditingController(text: config.baseUrl);
    _userController = TextEditingController(text: config.username);
    _passwordController = TextEditingController(text: config.password);
    _dirController = TextEditingController(text: config.remoteDir);
  }

  @override
  void dispose() {
    _urlController.dispose();
    _userController.dispose();
    _passwordController.dispose();
    _dirController.dispose();
    super.dispose();
  }

  WebDavConfig get _formConfig => WebDavConfig(
        baseUrl: _urlController.text,
        username: _userController.text,
        password: _passwordController.text,
        remoteDir: _dirController.text,
      );

  Widget _buildAutoBackupTile() {
    final service = ref.watch(autoBackupServiceProvider);
    final interval = service.interval;
    final lastRun = service.lastRunAt;

    return ListTile(
      key: const Key('webdav-auto-backup'),
      leading: const Icon(Icons.schedule_outlined),
      title: const Text('自动备份'),
      subtitle: Text(
        interval == AutoBackupInterval.off
            ? '关闭。开启后会在启动时检查，到期就自动导出并上传'
            : '${interval.label}；'
                '${lastRun == null ? '尚未运行过' : '上次 ${_formatTime(lastRun)}'}',
      ),
      trailing: DropdownButton<AutoBackupInterval>(
        key: const Key('webdav-auto-backup-interval'),
        value: interval,
        underline: const SizedBox.shrink(),
        onChanged: _busy
            ? null
            : (value) async {
                if (value == null) return;
                await service.setInterval(value);
                if (!mounted) return;
                setState(() {});
              },
        items: [
          for (final item in AutoBackupInterval.values)
            DropdownMenuItem(value: item, child: Text(item.label)),
        ],
      ),
    );
  }

  void _report(String message) {
    if (!mounted) return;
    setState(() => _status = message);
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  /// 每个动作都先存配置：用户改完输入框直接点「上传」时，用的是眼前这份配置，
  /// 而不是上次保存的那份。
  Future<WebDavConfig> _persistForm() async {
    final config = _formConfig;
    await ref.read(webDavConfigProvider.notifier).save(config);
    return config;
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _status = null;
    });
    try {
      await action();
    } on WebDavException catch (error) {
      _report(error.message);
    } catch (error) {
      _report('操作失败：$error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _testConnection() => _run(() async {
        final config = await _persistForm();
        await ref.read(webDavServiceProvider).testConnection(config);
        _report('连接成功');
      });

  Future<void> _upload() => _run(() async {
        final config = await _persistForm();
        final service = ref.read(webDavServiceProvider);
        final backup = BackupService(database: ref.read(databaseProvider));
        // exportBackup 已经清掉了 AI 密钥——上传到网盘和分享出去是同一类出口。
        final zipPath = await backup.exportBackup();
        final entry = await service.uploadBackup(config, zipPath);
        _report('已上传 ${entry.name}（${_formatSize(entry.size)}）');
        await _loadEntries(config);
      });

  Future<void> _refresh() => _run(() async {
        final config = await _persistForm();
        await _loadEntries(config);
        final count = _entries?.length ?? 0;
        _report(count == 0 ? '远端还没有备份' : '找到 $count 个备份');
      });

  Future<void> _loadEntries(WebDavConfig config) async {
    final entries = await ref.read(webDavServiceProvider).listBackups(config);
    if (mounted) setState(() => _entries = entries);
  }

  Future<void> _restore(WebDavEntry entry) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('从远端恢复'),
        content: Text(
          '将下载 ${entry.name} 并覆盖本机的书籍、笔记与阅读数据。\n'
          '恢复在下次启动应用时生效，当前数据会被替换。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(
              '恢复',
              style: TextStyle(
                color: Theme.of(dialogContext).colorScheme.error,
              ),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    await _run(() async {
      final config = _formConfig;
      final temp = await getTemporaryDirectory();
      final localPath = '${temp.path}/${entry.name}';
      await ref
          .read(webDavServiceProvider)
          .downloadBackup(config, entry.name, localPath);
      final backup = BackupService(database: ref.read(databaseProvider));
      final result = await backup.importBackup(localPath);
      if (result.status == RestoreStatus.staged) {
        if (!mounted) return;
        setState(() => _status = result.message);
        await showRestoreStagedDialog(context);
      } else {
        _report(result.message);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final entries = _entries;

    return Scaffold(
      backgroundColor: stableSurfaceColor(context),
      appBar: AppBar(
        title: const Text('WebDAV 同步'),
        leading: Padding(
          padding: const EdgeInsets.all(8.0),
          child: IconButton.filled(
            icon: const Icon(Icons.arrow_back, size: 20),
            onPressed: () => Navigator.pop(context),
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          GlassContainer.stable(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('服务器', style: theme.textTheme.titleSmall),
                const SizedBox(height: 12),
                TextField(
                  key: const Key('webdav-url'),
                  controller: _urlController,
                  enabled: !_busy,
                  keyboardType: TextInputType.url,
                  decoration: const InputDecoration(
                    labelText: '地址',
                    hintText: 'https://dav.example.com/dav',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  key: const Key('webdav-username'),
                  controller: _userController,
                  enabled: !_busy,
                  decoration: const InputDecoration(labelText: '用户名'),
                ),
                const SizedBox(height: 12),
                TextField(
                  key: const Key('webdav-password'),
                  controller: _passwordController,
                  enabled: !_busy,
                  obscureText: _obscurePassword,
                  decoration: InputDecoration(
                    labelText: '密码',
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_off
                            : Icons.visibility,
                      ),
                      onPressed: () => setState(
                        () => _obscurePassword = !_obscurePassword,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  key: const Key('webdav-dir'),
                  controller: _dirController,
                  enabled: !_busy,
                  decoration: const InputDecoration(
                    labelText: '备份目录',
                    helperText: '相对服务器地址，不存在会自动创建',
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    FilledButton.tonal(
                      key: const Key('webdav-test'),
                      onPressed: _busy ? null : _testConnection,
                      child: const Text('测试连接'),
                    ),
                    const SizedBox(width: 12),
                    if (_busy)
                      const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                  ],
                ),
                if (_status != null) ...[
                  const SizedBox(height: 12),
                  Text(_status!, style: theme.textTheme.bodySmall),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          GlassContainer.stable(
            padding: EdgeInsets.zero,
            child: Material(
              type: MaterialType.transparency,
              child: Column(
                children: [
                  ListTile(
                    key: const Key('webdav-upload'),
                    leading: const Icon(Icons.cloud_upload_outlined),
                    title: const Text('上传备份'),
                    subtitle: const Text('导出当前数据并上传；不含 AI 密钥'),
                    enabled: !_busy,
                    onTap: _busy ? null : _upload,
                  ),
                  ListTile(
                    key: const Key('webdav-refresh'),
                    leading: const Icon(Icons.refresh),
                    title: const Text('查看远端备份'),
                    enabled: !_busy,
                    onTap: _busy ? null : _refresh,
                  ),
                  const Divider(height: 1),
                  _buildAutoBackupTile(),
                ],
              ),
            ),
          ),
          if (entries != null) ...[
            const SizedBox(height: 16),
            GlassContainer.stable(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('远端备份', style: theme.textTheme.titleSmall),
                  const SizedBox(height: 8),
                  if (entries.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Text('还没有上传过备份'),
                    )
                  else
                    // ListTile 的水波纹画在最近的 Material 上，
                    // GlassContainer 的背景会把它盖掉——必须自带一层。
                    Material(
                      type: MaterialType.transparency,
                      child: Column(
                        children: [
                          for (final entry in entries)
                            ListTile(
                              key: Key('webdav-entry-${entry.name}'),
                              contentPadding: EdgeInsets.zero,
                              title: Text(
                                entry.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              subtitle: Text(
                                '${_formatTime(entry.modifiedAt)} · '
                                '${_formatSize(entry.size)}',
                              ),
                              trailing:
                                  const Icon(Icons.cloud_download_outlined),
                              enabled: !_busy,
                              onTap: _busy ? null : () => _restore(entry),
                            ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              '这里做的是备份包上传与下载，不是双向同步：不会合并两端的改动，'
              '恢复会整体覆盖本机数据。密码保存在本机，不会写进备份包。',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
