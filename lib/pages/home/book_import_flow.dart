import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../database/app_database.dart';
import '../../providers/book_import_progress.dart';
import '../../providers/book_provider.dart';
import '../../providers/database_provider.dart';
import '../../services/book_service.dart';

enum BookImportSource { files, folder }

/// 把书弄进书架的三条路径：文件选择器、桌面拖拽、Android 分享。
///
/// 从 `home_page.dart` 拆出来——书架页已经超过合理体积，而这一组逻辑与
/// 书架的筛选、排序、批量选择完全无关，只跟「拿到一批路径，逐个导入」
/// 有关。三条路径共用同一套重复检测与导入后处理，是拆到一起的理由。
class BookImportFlow {
  /// 单本导入成功后弹元数据编辑框。回调而不是直接调用：那个对话框归书架页
  /// 管，它同时被长按菜单用到，不该跟着搬过来。
  final void Function(BuildContext context, WidgetRef ref, Book book)
      onSingleImported;

  const BookImportFlow({required this.onSingleImported});

  Future<void> showOptions(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final source = await showModalBottomSheet<BookImportSource>(
      context: context,
      useSafeArea: true,
      builder: (sheetContext) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 8, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '导入书籍',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                IconButton(
                  tooltip: '关闭',
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(sheetContext),
                ),
              ],
            ),
          ),
          ListTile(
            leading: const Icon(Icons.file_open_outlined),
            title: const Text('选择文件'),
            subtitle: const Text('可一次选择多本 EPUB、PDF 或 TXT'),
            onTap: () => Navigator.pop(sheetContext, BookImportSource.files),
          ),
          ListTile(
            leading: const Icon(Icons.folder_open_outlined),
            title: const Text('选择文件夹'),
            subtitle: const Text('递归查找文件夹中的支持格式书籍'),
            onTap: () => Navigator.pop(sheetContext, BookImportSource.folder),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
    if (source != null && context.mounted) {
      await _pickAndImport(context, ref, source);
    }
  }

  Future<void> _pickAndImport(
    BuildContext context,
    WidgetRef ref,
    BookImportSource source,
  ) async {
    final notifier = ref.read(booksProvider.notifier);
    late final List<String> paths;
    try {
      paths = source == BookImportSource.folder
          ? await notifier.pickBookDirectory()
          : await notifier.pickBookFiles();
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('读取导入内容失败：$error')),
      );
      return;
    }
    if (paths.isEmpty || !context.mounted) {
      if (context.mounted && source == BookImportSource.folder) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('所选文件夹中没有 EPUB、PDF 或 TXT 书籍')),
        );
      }
      return;
    }
    await importPaths(context, ref, paths);
  }

  /// 桌面拖放进来的路径：先解析掉文件夹与不支持的格式，再走与文件选择器
  /// 完全相同的导入流程（重复检测、替换/跳过、导入后编辑元数据）。
  Future<void> importDropped(
    BuildContext context,
    WidgetRef ref,
    List<String> rawPaths,
  ) async {
    final List<String> paths;
    try {
      paths = await ref.read(bookServiceProvider).resolveDroppedPaths(rawPaths);
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('读取拖入内容失败：$error')),
      );
      return;
    }
    if (!context.mounted) return;
    if (paths.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('拖入的内容里没有 EPUB、PDF 或 TXT 书籍')),
      );
      return;
    }
    await importPaths(context, ref, paths);
  }

  Future<void> importPaths(
    BuildContext context,
    WidgetRef ref,
    List<String> paths,
  ) async {
    // 已经在导了就不再开一轮：导入没有进度反馈的时候用户很容易连点两下，
    // 两轮并发跑同一批文件，重复检测互相看不见对方刚写进去的那本。
    final progress = ref.read(bookImportProgressProvider.notifier);
    if (progress.state != null) return;

    final notifier = ref.read(booksProvider.notifier);
    final imported = <Book>[];
    var skippedCount = 0;
    var replacedCount = 0;
    try {
    for (final (index, path) in paths.indexed) {
      progress.state = BookImportProgress(
        completed: index,
        total: paths.length,
        currentName: p.basename(path),
      );
      try {
        final analysis = await notifier.analyzeBookImport(path);
        if (!context.mounted) return;
        var action = DuplicateBookAction.keepCopy;
        if (analysis.isDuplicate) {
          action = await _showDuplicateImportDialog(context, analysis) ??
              DuplicateBookAction.skip;
        }
        if (action == DuplicateBookAction.skip) {
          skippedCount++;
          continue;
        }
        final book = await notifier.importBookFile(
          path,
          analysis: analysis,
          duplicateAction: action,
        );
        imported.add(book);
        if (action == DuplicateBookAction.replace) replacedCount++;
      } catch (error) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('导入失败：$error')),
        );
      }
    }
    } finally {
      // 中途 return（context 没了）也要清掉，否则进度条一直挂着、
      // 而且再也导不进第二本。
      progress.state = null;
    }
    if (!context.mounted) return;
    if (paths.length == 1 && imported.length == 1 && replacedCount == 0) {
      onSingleImported(context, ref, imported.single);
    } else if (imported.isNotEmpty || skippedCount > 0) {
      final addedCount = imported.length - replacedCount;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '导入完成：新增 $addedCount 本，替换 $replacedCount 本，'
            '跳过 $skippedCount 本',
          ),
        ),
      );
    }
  }

  Future<DuplicateBookAction?> _showDuplicateImportDialog(
    BuildContext context,
    BookImportAnalysis analysis,
  ) {
    final existing = analysis.existingBook!;
    return showDialog<DuplicateBookAction>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        title: const Text('发现重复书籍'),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
            child: Text('所选文件与《${existing.title}》内容相同。'),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(
              dialogContext,
              DuplicateBookAction.skip,
            ),
            child: const ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.skip_next_outlined),
              title: Text('跳过'),
              subtitle: Text('保留当前书籍，不再导入'),
            ),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(
              dialogContext,
              DuplicateBookAction.keepCopy,
            ),
            child: const ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.copy_outlined),
              title: Text('保留副本'),
              subtitle: Text('作为另一本书导入'),
            ),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(
              dialogContext,
              DuplicateBookAction.replace,
            ),
            child: const ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.find_replace_outlined),
              title: Text('替换文件'),
              subtitle: Text('保留进度、笔记、书架和书籍信息'),
            ),
          ),
        ],
      ),
    );
  }
}
