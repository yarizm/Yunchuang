import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';

import '../../services/backup_service.dart';
import '../../providers/database_provider.dart';
import '../../theme/glass_page_route.dart';
import '../../widgets/glass_container.dart';
import 'webdav_page.dart';
import 'restore_staged_dialog.dart';

/// Page for backup export and import.
class DataManagementPage extends ConsumerStatefulWidget {
  const DataManagementPage({super.key});

  @override
  ConsumerState<DataManagementPage> createState() => _DataManagementPageState();
}

class _DataManagementPageState extends ConsumerState<DataManagementPage> {
  BackupService get _backupService =>
      BackupService(database: ref.read(databaseProvider));
  bool _loading = false;

  /// 手动压缩。
  ///
  /// 删书时够大就会自动跑一遍（见 `BookService._compactIfWorthIt`），这里是
  /// 给两种情况兜底：删了一堆小书攒起来的体积，以及这个功能上线之前就已经
  /// 删掉的书——那些空间不会自己回来。
  Future<void> _compact() async {
    setState(() => _loading = true);
    try {
      await ref.read(databaseProvider).compact();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('已回收空间')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('压缩失败：$error')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _export() async {
    setState(() => _loading = true);
    try {
      final zipPath = await _backupService.exportBackup();
      await Share.shareXFiles([XFile(zipPath)], text: '阅读器备份');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('备份已导出（不含 AI 密钥，还原后需重新填写）'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('导出失败: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _import() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['zip'],
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    if (!mounted) return;

    // 导入是整库覆盖，不是合并。选错文件的代价是丢掉本机全部数据，得先问。
    // WebDAV 那边的恢复一直有这一步，本地导入之前漏了。
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('导入备份'),
        content: Text(
          '将用 ${file.name} 覆盖本机的书籍、笔记与阅读数据。\n'
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
              '导入',
              style: TextStyle(
                color: Theme.of(dialogContext).colorScheme.error,
              ),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _loading = true);
    try {
      final restore = await _backupService.importBackup(file.path!);
      if (!mounted) return;
      if (restore.status == RestoreStatus.staged) {
        await showRestoreStagedDialog(context);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(restore.message)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('导入失败: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('数据管理'),
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
            padding: EdgeInsets.zero,
            child: Material(
              type: MaterialType.transparency,
              child: ListTile(
                leading: const Icon(Icons.upload),
                title: const Text('导出备份'),
                subtitle: const Text('打包书籍、笔记与阅读数据；不含 AI 密钥'),
                trailing: _loading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.chevron_right),
                onTap: _loading ? null : _export,
              ),
            ),
          ),
          const SizedBox(height: 16),
          GlassContainer.stable(
            padding: EdgeInsets.zero,
            child: Material(
              type: MaterialType.transparency,
              child: ListTile(
                leading: const Icon(Icons.download),
                title: const Text('导入备份'),
                subtitle: const Text('从 zip 文件恢复书籍和笔记'),
                trailing: _loading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.chevron_right),
                onTap: _loading ? null : _import,
              ),
            ),
          ),
          const SizedBox(height: 16),
          GlassContainer.stable(
            padding: EdgeInsets.zero,
            child: Material(
              type: MaterialType.transparency,
              child: ListTile(
                key: const Key('compact-database'),
                leading: const Icon(Icons.cleaning_services_outlined),
                title: const Text('压缩数据库'),
                subtitle: const Text('回收删书之后留下的空间'),
                trailing: _loading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.chevron_right),
                onTap: _loading ? null : _compact,
              ),
            ),
          ),
          const SizedBox(height: 16),
          GlassContainer.stable(
            padding: EdgeInsets.zero,
            child: Material(
              type: MaterialType.transparency,
              child: ListTile(
                key: const Key('open-webdav'),
                leading: const Icon(Icons.cloud_outlined),
                title: const Text('WebDAV 同步'),
                subtitle: const Text('把备份传到自己的网盘，换设备时取回'),
                trailing: const Icon(Icons.chevron_right),
                onTap: _loading
                    ? null
                    : () => Navigator.of(context).push(
                          GlassPageRoute(builder: (_) => const WebDavPage()),
                        ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
