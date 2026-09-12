import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../database/app_database.dart';
import '../../providers/database_provider.dart';
import '../../services/dictionary_service.dart';
import '../../services/stardict_parser.dart';
import '../../widgets/empty_state.dart';

class DictionaryPage extends ConsumerStatefulWidget {
  const DictionaryPage({super.key});

  @override
  ConsumerState<DictionaryPage> createState() => _DictionaryPageState();
}

class _DictionaryPageState extends ConsumerState<DictionaryPage> {
  bool _importing = false;
  String? _importStatus;
  StarDictImportCancellation? _cancellation;

  @override
  Widget build(BuildContext context) {
    final sourcesAsync = ref.watch(dictionarySourcesProvider);
    return PopScope(
      canPop: !_importing,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('离线词典'),
          actions: [
            IconButton(
              tooltip: '导入说明',
              onPressed: _showImportHelp,
              icon: const Icon(Icons.help_outline),
            ),
            IconButton(
              key: const Key('import-stardict-button'),
              tooltip: '导入 StarDict',
              onPressed: _importing ? null : _pickAndImport,
              icon: const Icon(Icons.add),
            ),
          ],
        ),
        body: Column(
          children: [
            if (_importing) _buildImportProgress(),
            Expanded(
              child: sourcesAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, _) => Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: EmptyState(
                      icon: Icons.error_outline,
                      title: '加载失败',
                      subtitle: '$error',
                      action: FilledButton.icon(
                        onPressed: () =>
                            ref.invalidate(dictionarySourcesProvider),
                        icon: const Icon(Icons.refresh),
                        label: const Text('重试'),
                      ),
                    ),
                  ),
                ),
                data: (sources) => sources.isEmpty
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.all(32),
                          child: EmptyState(
                            icon: Icons.language_outlined,
                            title: '还没有离线词典',
                            subtitle: '导入 StarDict 文件后，查词时会优先显示本地释义',
                          ),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.only(bottom: 24),
                        itemCount: sources.length,
                        separatorBuilder: (_, __) =>
                            const Divider(height: 1, indent: 16),
                        itemBuilder: (context, index) =>
                            _buildSourceTile(sources[index]),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImportProgress() {
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text(_importStatus ?? '正在准备词典…')),
                TextButton(
                  onPressed: _cancellation?.isCancelled == true
                      ? null
                      : () {
                          _cancellation?.cancel();
                          setState(() => _importStatus = '正在取消…');
                        },
                  child: const Text('取消'),
                ),
              ],
            ),
            const LinearProgressIndicator(),
          ],
        ),
      ),
    );
  }

  Widget _buildSourceTile(DictionarySource source) {
    return ListTile(
      key: ValueKey('dictionary-source-${source.id}'),
      contentPadding: const EdgeInsets.fromLTRB(20, 8, 8, 8),
      leading: Icon(
        source.enabled ? Icons.menu_book : Icons.menu_book_outlined,
      ),
      title: Text(
        source.name,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        '${source.entryCount} 个词条 · StarDict ${source.formatVersion}'
        '${source.description?.trim().isNotEmpty == true ? '\n${source.description!.trim()}' : ''}',
        maxLines: 3,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: SizedBox(
        width: 112,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Switch(
              value: source.enabled,
              onChanged:
                  _importing ? null : (enabled) => _setEnabled(source, enabled),
            ),
            PopupMenuButton<_DictionaryAction>(
              tooltip: '更多操作',
              onSelected: (action) {
                if (action == _DictionaryAction.delete) {
                  _deleteSource(source);
                }
              },
              itemBuilder: (context) => const [
                PopupMenuItem(
                  value: _DictionaryAction.delete,
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.delete_outline),
                    title: Text('删除词典'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickAndImport() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: const ['ifo', 'idx', 'gz', 'dict', 'dz', 'syn'],
    );
    if (result == null || !mounted) return;
    if (result.files.any((file) => file.path == null)) {
      _showMessage('无法读取所选文件，请改用本地文件管理器重新选择。');
      return;
    }
    final files = [
      for (final file in result.files)
        StarDictSelectedFile(name: file.name, path: file.path!),
    ];
    final cancellation = StarDictImportCancellation();
    setState(() {
      _importing = true;
      _importStatus = '正在检查 StarDict 文件…';
      _cancellation = cancellation;
    });
    try {
      final source = await ref.read(dictionaryServiceProvider).importStarDict(
        files,
        cancellation: cancellation,
        onProgress: (status) {
          if (mounted) setState(() => _importStatus = status);
        },
      );
      if (!mounted) return;
      _showMessage('已导入“${source.name}”。');
    } on StarDictImportCancelled {
      if (mounted) _showMessage('已取消词典导入。');
    } catch (error) {
      if (mounted) _showMessage('导入失败：$error');
    } finally {
      if (mounted) {
        setState(() {
          _importing = false;
          _importStatus = null;
          _cancellation = null;
        });
      }
    }
  }

  Future<void> _setEnabled(DictionarySource source, bool enabled) async {
    try {
      await ref.read(dictionaryServiceProvider).setEnabled(source.id, enabled);
    } catch (error) {
      if (mounted) _showMessage('更新失败：$error');
    }
  }

  Future<void> _deleteSource(DictionarySource source) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('删除离线词典'),
        content: Text('确定删除“${source.name}”及其本地数据吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(
              '删除',
              style: TextStyle(
                color: Theme.of(dialogContext).colorScheme.error,
              ),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await ref.read(dictionaryServiceProvider).deleteSource(source.id);
      if (mounted) _showMessage('词典已删除。');
    } catch (error) {
      if (mounted) _showMessage('删除失败：$error');
    }
  }

  Future<void> _showImportHelp() {
    return showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('导入 StarDict'),
        content: const SingleChildScrollView(
          child: Text(
            '请一次选中同一套词典的全部文件：\n\n'
            '• 必需：同名的 .ifo、.idx 或 .idx.gz、.dict 或 .dict.dz\n'
            '• 可选：同名的 .syn\n\n'
            '支持 StarDict 2.4.2 和 3.0.0。导入过程完全在本地进行，'
            '压缩正文会解压到应用目录，因此需要预留足够存储空间。'
            '请确认词典来源和授权允许个人使用。',
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('知道了'),
          ),
        ],
      ),
    );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}

enum _DictionaryAction { delete }
