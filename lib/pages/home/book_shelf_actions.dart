import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../database/app_database.dart';
import '../../models/book_reading_status.dart';
import '../../providers/book_provider.dart';
import '../../widgets/glass_container.dart';
import 'book_collection_sheets.dart';

/// 书架上「对书做事」的那一组：多选批量操作，以及单本的阅读状态切换。
///
/// 从 `home_page.dart` 拆出来。这两组本可以再分，但它们共用
/// [shelfStatusIcon]，且批量改状态与单本改状态走的是同一套语义，分开会
/// 让这个共享关系变成跨文件的隐式依赖。
///
/// 全部是顶层函数而不是类：原本就是 ConsumerWidget 上的方法，只吃
/// (context, ref) 加参数，没有自己的状态。

Widget buildBatchActionBar(
  BuildContext context,
  WidgetRef ref,
  Set<int> selectedIds,
  Set<int> visibleIds,
) {
  final allVisibleSelected =
      visibleIds.isNotEmpty && selectedIds.containsAll(visibleIds);
  return Material(
    elevation: 8,
    color: Theme.of(context).colorScheme.surface,
    child: SafeArea(
      top: false,
      child: SizedBox(
        height: 64,
        child: Row(
          children: [
            IconButton(
              tooltip: '退出批量管理',
              icon: const Icon(Icons.close),
              onPressed: () => clearBookSelection(ref),
            ),
            Text(
              '已选 ${selectedIds.length} 本',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const Spacer(),
            IconButton(
              tooltip: allVisibleSelected ? '取消全选' : '全选当前结果',
              icon: Icon(
                allVisibleSelected ? Icons.deselect : Icons.select_all_outlined,
              ),
              onPressed: () {
                final next = {...selectedIds};
                if (allVisibleSelected) {
                  next.removeAll(visibleIds);
                } else {
                  next.addAll(visibleIds);
                }
                ref.read(selectedShelfBookIdsProvider.notifier).state = next;
              },
            ),
            IconButton(
              tooltip: '批量管理书架',
              icon: const Icon(Icons.drive_file_move_outline),
              onPressed: () =>
                  showBatchCollectionSheet(context, ref, selectedIds),
            ),
            IconButton(
              tooltip: '批量修改状态',
              icon: const Icon(Icons.fact_check_outlined),
              onPressed: () => showBatchStatusSheet(context, ref, selectedIds),
            ),
            IconButton(
              tooltip: '批量删除',
              color: Theme.of(context).colorScheme.error,
              icon: const Icon(Icons.delete_outline),
              onPressed: () => confirmBatchDelete(context, ref, selectedIds),
            ),
            const SizedBox(width: 4),
          ],
        ),
      ),
    ),
  );
}

void toggleBookSelection(WidgetRef ref, int bookId) {
  final next = {...ref.read(selectedShelfBookIdsProvider)};
  if (!next.add(bookId)) next.remove(bookId);
  ref.read(selectedShelfBookIdsProvider.notifier).state = next;
}

void clearBookSelection(WidgetRef ref) {
  ref.read(selectedShelfBookIdsProvider.notifier).state = const {};
}

Future<void> showBatchCollectionSheet(
  BuildContext context,
  WidgetRef ref,
  Set<int> selectedIds,
) async {
  final updated = await showBatchBookCollectionAction(
    context,
    selectedIds,
  );
  if (updated == true) clearBookSelection(ref);
}

void showBatchStatusSheet(
  BuildContext context,
  WidgetRef ref,
  Set<int> selectedIds,
) {
  showModalBottomSheet<void>(
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
                  '批量修改阅读状态',
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
          leading: const Icon(Icons.auto_awesome),
          title: const Text('自动判断'),
          onTap: () => updateBatchReadingStatus(
            context,
            sheetContext,
            ref,
            selectedIds,
            null,
          ),
        ),
        for (final status in BookReadingStatus.values)
          ListTile(
            leading: Icon(shelfStatusIcon(status)),
            title: Text(status.label),
            onTap: () => updateBatchReadingStatus(
              context,
              sheetContext,
              ref,
              selectedIds,
              status,
            ),
          ),
        const SizedBox(height: 12),
      ],
    ),
  );
}

Future<void> updateBatchReadingStatus(
  BuildContext context,
  BuildContext sheetContext,
  WidgetRef ref,
  Set<int> selectedIds,
  BookReadingStatus? status,
) async {
  Navigator.pop(sheetContext);
  try {
    await ref
        .read(booksProvider.notifier)
        .updateReadingStatuses({...selectedIds}, status);
    clearBookSelection(ref);
  } catch (error) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('批量更新状态失败：$error')),
    );
  }
}

Future<void> confirmBatchDelete(
  BuildContext context,
  WidgetRef ref,
  Set<int> selectedIds,
) async {
  final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('批量删除书籍'),
          content: Text(
            '确定删除所选 ${selectedIds.length} 本书及其笔记吗？此操作无法撤销。',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('删除'),
            ),
          ],
        ),
      ) ??
      false;
  if (!confirmed || !context.mounted) return;
  try {
    await ref.read(booksProvider.notifier).deleteBooks({...selectedIds});
    clearBookSelection(ref);
  } catch (error) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('批量删除失败：$error')),
    );
  }
}

void showBookStatusSheet(
  BuildContext context,
  WidgetRef ref,
  Book book,
  BookReadingStatus effectiveStatus,
) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) => SafeArea(
      top: false,
      child: GlassContainer.stable(
        borderRadius: 24,
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
        child: Material(
          type: MaterialType.transparency,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '阅读状态',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              buildStatusOption(
                context,
                icon: Icons.auto_awesome,
                label: '自动判断',
                subtitle: '根据阅读进度判断，当前${effectiveStatus.label}',
                selected: book.readingStatus == null,
                onTap: () => updateBookReadingStatus(
                  context,
                  sheetContext,
                  ref,
                  book.id,
                  null,
                ),
              ),
              for (final status in BookReadingStatus.values)
                buildStatusOption(
                  context,
                  icon: shelfStatusIcon(status),
                  label: status.label,
                  selected: book.readingStatus == status.storageValue,
                  onTap: () => updateBookReadingStatus(
                    context,
                    sheetContext,
                    ref,
                    book.id,
                    status,
                  ),
                ),
            ],
          ),
        ),
      ),
    ),
  );
}

Widget buildStatusOption(
  BuildContext context, {
  required IconData icon,
  required String label,
  String? subtitle,
  required bool selected,
  required VoidCallback onTap,
}) {
  return ListTile(
    leading: Icon(icon),
    title: Text(label),
    subtitle: subtitle == null ? null : Text(subtitle),
    trailing: selected
        ? Icon(Icons.check, color: Theme.of(context).colorScheme.primary)
        : null,
    onTap: onTap,
  );
}

Future<void> updateBookReadingStatus(
  BuildContext context,
  BuildContext sheetContext,
  WidgetRef ref,
  int bookId,
  BookReadingStatus? status,
) async {
  Navigator.pop(sheetContext);
  try {
    await ref.read(booksProvider.notifier).updateReadingStatus(bookId, status);
  } catch (error) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('更新阅读状态失败：$error')),
    );
  }
}

BookReadingStatus shelfStatusFor(
  Book book,
  ReadingProgressData? progress,
) {
  return resolveBookReadingStatus(
    overrideValue: book.readingStatus,
    percentage: progress?.percentage,
    totalReadingSeconds: progress?.totalReadingSeconds,
  );
}

IconData shelfStatusIcon(BookReadingStatus? status) {
  switch (status) {
    case BookReadingStatus.unread:
      return Icons.fiber_new_outlined;
    case BookReadingStatus.reading:
      return Icons.auto_stories_outlined;
    case BookReadingStatus.finished:
      return Icons.check_circle_outline;
    case BookReadingStatus.paused:
      return Icons.pause_circle_outline;
    case null:
      return Icons.library_books_outlined;
  }
}
