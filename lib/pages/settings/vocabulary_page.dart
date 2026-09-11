import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../database/daos/vocabulary_dao.dart';
import '../../models/reader_locator.dart';
import '../../services/vocabulary_service.dart';
import '../../theme/glass_page_route.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/glass_container.dart';
import '../reader/reader_page.dart';

class VocabularyPage extends ConsumerStatefulWidget {
  const VocabularyPage({super.key});

  @override
  ConsumerState<VocabularyPage> createState() => _VocabularyPageState();
}

class _VocabularyPageState extends ConsumerState<VocabularyPage> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final entriesAsync = ref.watch(allVocabularyEntriesProvider);
    final allEntries =
        entriesAsync.asData?.value ?? const <VocabularyEntryDetails>[];
    final entries = allEntries.where(_matchesQuery).toList(growable: false);

    return Scaffold(
      backgroundColor: stableSurfaceColor(context),
      appBar: AppBar(
        title: const Text('生词本'),
        actions: [
          PopupMenuButton<_VocabularyExportFormat>(
            key: const Key('vocabulary-export-menu'),
            tooltip: '导出生词本',
            enabled: allEntries.isNotEmpty,
            icon: const Icon(Icons.ios_share_outlined),
            onSelected: (format) => _export(allEntries, format),
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: _VocabularyExportFormat.markdown,
                child: Text('导出 Markdown'),
              ),
              PopupMenuItem(
                value: _VocabularyExportFormat.csv,
                child: Text('导出 CSV'),
              ),
            ],
          ),
        ],
      ),
      body: entriesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: EmptyState(
              icon: Icons.error_outline,
              title: '加载失败',
              subtitle: '$error',
              action: FilledButton.icon(
                onPressed: () => ref.invalidate(allVocabularyEntriesProvider),
                icon: const Icon(Icons.refresh),
                label: const Text('重试'),
              ),
            ),
          ),
        ),
        data: (_) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: TextField(
                key: const Key('vocabulary-search-field'),
                controller: _searchController,
                onChanged: (value) => setState(() => _query = value.trim()),
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: '搜索词条、释义、书籍或原句',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _query.isEmpty
                      ? null
                      : IconButton(
                          tooltip: '清除',
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _query = '');
                          },
                          icon: const Icon(Icons.close),
                        ),
                ),
              ),
            ),
            Expanded(
              child: allEntries.isEmpty
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(32),
                        child: EmptyState(
                          icon: Icons.menu_book_outlined,
                          title: '还没有生词',
                          subtitle: '阅读时选中文本并点击“查词”即可加入',
                        ),
                      ),
                    )
                  : entries.isEmpty
                      ? const Center(
                          child: Padding(
                            padding: EdgeInsets.all(32),
                            child: EmptyState(
                              icon: Icons.search_off,
                              title: '没有匹配结果',
                              subtitle: '换一个关键词再试',
                            ),
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.only(bottom: 24),
                          itemCount: entries.length,
                          separatorBuilder: (_, __) =>
                              const Divider(height: 1, indent: 16),
                          itemBuilder: (context, index) =>
                              _buildEntryTile(entries[index]),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  bool _matchesQuery(VocabularyEntryDetails details) {
    if (_query.isEmpty) return true;
    final query = _query.toLowerCase();
    final entry = details.entry;
    return entry.term.toLowerCase().contains(query) ||
        (entry.definition?.toLowerCase().contains(query) ?? false) ||
        details.bookTitle.toLowerCase().contains(query) ||
        (details.chapterTitle?.toLowerCase().contains(query) ?? false) ||
        (entry.contextText?.toLowerCase().contains(query) ?? false);
  }

  Widget _buildEntryTile(VocabularyEntryDetails details) {
    final theme = Theme.of(context);
    final entry = details.entry;
    final definition = entry.definition?.trim();
    final source = details.chapterTitle == null
        ? details.bookTitle
        : '${details.bookTitle} · ${details.chapterTitle}';

    return ListTile(
      key: ValueKey('vocabulary-entry-${entry.id}'),
      contentPadding: const EdgeInsets.fromLTRB(20, 8, 8, 8),
      onTap: entry.chapterId == null
          ? null
          : () => Navigator.of(context).push(
                GlassPageRoute(
                  builder: (_) => ReaderPage(
                    bookId: entry.bookId,
                    initialLocator: ReaderLocator(
                      bookId: entry.bookId,
                      chapterId: entry.chapterId,
                      textOffsetStart: entry.positionStart,
                      textOffsetEnd: entry.positionEnd,
                      query: entry.term,
                      selectedText: entry.term,
                    ),
                  ),
                ),
              ),
      title: Text(
        entry.term,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 4),
          Text(
            definition?.isNotEmpty == true ? definition! : '暂无释义',
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: definition?.isNotEmpty == true
                ? null
                : TextStyle(color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 4),
          Text(
            source,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.primary,
            ),
          ),
          if (entry.contextText?.trim().isNotEmpty == true) ...[
            const SizedBox(height: 4),
            Text(
              entry.contextText!.trim(),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
      trailing: PopupMenuButton<_VocabularyEntryAction>(
        tooltip: '更多操作',
        onSelected: (action) {
          switch (action) {
            case _VocabularyEntryAction.edit:
              _editDefinition(details);
            case _VocabularyEntryAction.delete:
              _delete(details);
          }
        },
        itemBuilder: (context) => const [
          PopupMenuItem(
            value: _VocabularyEntryAction.edit,
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.edit_outlined),
              title: Text('编辑释义'),
            ),
          ),
          PopupMenuItem(
            value: _VocabularyEntryAction.delete,
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.delete_outline),
              title: Text('删除'),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _editDefinition(VocabularyEntryDetails details) async {
    var definition = details.entry.definition ?? '';
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('编辑“${details.entry.term}”'),
        content: TextFormField(
          key: const Key('edit-vocabulary-definition'),
          initialValue: definition,
          onChanged: (value) => definition = value,
          autofocus: true,
          minLines: 3,
          maxLines: 8,
          decoration: const InputDecoration(
            labelText: '释义',
            alignLabelWithHint: true,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(definition),
            child: const Text('保存'),
          ),
        ],
      ),
    );
    if (result == null || !mounted) return;
    try {
      await ref
          .read(vocabularyServiceProvider)
          .updateDefinition(details.entry.id, result);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('释义已更新')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('更新失败：$error')),
      );
    }
  }

  Future<void> _delete(VocabularyEntryDetails details) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('删除生词'),
        content: Text('确定删除“${details.entry.term}”吗？'),
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
      await ref.read(vocabularyServiceProvider).deleteEntry(details.entry.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('生词已删除')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('删除失败：$error')),
      );
    }
  }

  Future<void> _export(
    List<VocabularyEntryDetails> entries,
    _VocabularyExportFormat format,
  ) async {
    try {
      final service = ref.read(vocabularyServiceProvider);
      final content = switch (format) {
        _VocabularyExportFormat.markdown => service.exportMarkdown(entries),
        _VocabularyExportFormat.csv => service.exportCsv(entries),
      };
      final extension =
          format == _VocabularyExportFormat.markdown ? 'md' : 'csv';
      final directory = await getTemporaryDirectory();
      final timestamp = DateTime.now()
          .toUtc()
          .toIso8601String()
          .replaceAll(RegExp(r'[:.]'), '-');
      final file = File('${directory.path}/生词本_$timestamp.$extension');
      await file.writeAsString(
        format == _VocabularyExportFormat.csv ? '\ufeff$content' : content,
      );
      await Share.shareXFiles(
        [XFile(file.path)],
        text: '阅读器生词本',
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('导出失败：$error')),
      );
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}

enum _VocabularyEntryAction { edit, delete }

enum _VocabularyExportFormat { markdown, csv }
