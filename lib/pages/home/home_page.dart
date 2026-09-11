import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../database/app_database.dart';
import '../../models/book_reading_status.dart';
import '../../models/book_shelf_options.dart';
import '../../providers/book_import_progress.dart';
import '../../providers/book_provider.dart';
import '../../providers/database_provider.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/book_drop_target.dart';
import '../../widgets/shared_import_watcher.dart';
import '../../widgets/glass_container.dart';
import '../../theme/glass_page_route.dart';
import '../reader/reader_page.dart';
import 'book_card.dart';
import 'book_collection_sheets.dart';
import 'book_import_flow.dart';
import 'book_shelf_actions.dart';
import 'book_list_tile.dart';
import 'edit_book_dialog.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final importFlow = BookImportFlow(onSingleImported: _showEditBookDialog);
    final booksAsync = ref.watch(shelfBooksProvider);
    final progressMap = ref.watch(allReadingProgressProvider).maybeWhen(
          data: (value) => value,
          orElse: () => const <int, ReadingProgressData>{},
        );
    final statusFilter = ref.watch(shelfStatusFilterProvider);
    final selectedCollectionId = ref.watch(selectedBookCollectionProvider);
    final selectedSeries = ref.watch(selectedBookSeriesProvider);
    final collectionsAsync = ref.watch(bookCollectionsProvider);
    final seriesAsync = ref.watch(bookSeriesProvider);
    final shelfPreferences = ref.watch(bookShelfPreferencesProvider);
    final selectedBookIds = ref.watch(selectedShelfBookIdsProvider);
    final importProgress = ref.watch(bookImportProgressProvider);
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SharedImportWatcher(
        // 从别的应用分享 / 用「打开方式」打开进来的书，与拖拽走同一条导入
        // 流程；原生侧已经落盘并按扩展名筛过，这里不必再解析路径。
        onFiles: (paths) => importFlow.importPaths(context, ref, paths),
        child: BookDropTarget(
          onDrop: (paths) => importFlow.importDropped(context, ref, paths),
          child: booksAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            // 书架是根 Tab，页面不会被销毁重建（StatefulShellRoute 保留分支
            // 状态），provider 进了 error 态切走再切回来还是这一屏。没有重试
            // 入口就只能杀进程。
            error: (e, _) => Center(
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: GlassContainer.stable(
                  padding: const EdgeInsets.all(24),
                  child: EmptyState(
                    icon: Icons.error_outline,
                    title: '加载失败',
                    subtitle: '$e',
                    action: FilledButton.icon(
                      onPressed: () => ref.invalidate(shelfBooksProvider),
                      icon: const Icon(Icons.refresh),
                      label: const Text('重试'),
                    ),
                  ),
                ),
              ),
            ),
            data: (books) {
              // 「还没有书」是导入引导，只对真正一本书都没有的库成立。任何
              // 筛选条件生效时都不能走这一支：那时它会顶掉整条筛选栏，用户
              // 没有任何控件可以取消筛选，等于被困在空书架里。
              if (books.isEmpty &&
                  statusFilter == null &&
                  selectedCollectionId == null &&
                  selectedSeries == null) {
                return CustomScrollView(
                  slivers: [
                    _buildHeader(context, theme),
                    _buildImportProgress(importProgress),
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32.0),
                          child: GlassContainer.stable(
                            padding: const EdgeInsets.symmetric(
                                vertical: 40, horizontal: 20),
                            child: EmptyState(
                              icon: Icons.menu_book,
                              title: '还没有书',
                              subtitle: '点击右下角 + 导入你的第一本书',
                              action: FilledButton.icon(
                                onPressed: () =>
                                    importFlow.showOptions(context, ref),
                                icon: const Icon(Icons.add),
                                label: const Text('导入书籍'),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              }
              final visibleBooks = books;
              return CustomScrollView(
                slivers: [
                  _buildHeader(context, theme),
                  _buildImportProgress(importProgress),
                  _buildCollectionFilters(
                    ref,
                    collectionsAsync,
                    selectedCollectionId,
                  ),
                  _buildStatusFilters(ref, statusFilter),
                  _buildShelfToolbar(
                    ref,
                    shelfPreferences,
                    seriesAsync,
                    selectedSeries,
                  ),
                  if (visibleBooks.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: EmptyState(
                        icon: selectedCollectionId == null &&
                                selectedSeries == null
                            ? shelfStatusIcon(statusFilter)
                            : Icons.filter_alt_outlined,
                        title: selectedCollectionId == null &&
                                selectedSeries == null
                            ? '没有${statusFilter?.label ?? ''}书籍'
                            : '当前筛选中没有${statusFilter?.label ?? ''}书籍',
                        subtitle: '可以切换筛选条件，或长按书籍修改书架和阅读状态',
                      ),
                    )
                  else if (shelfPreferences.viewMode == BookShelfViewMode.grid)
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
                      sliver: SliverGrid(
                        gridDelegate:
                            const SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 180,
                          childAspectRatio: 0.62,
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 20,
                        ),
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final book = visibleBooks[index];
                            final progress = progressMap[book.id];
                            return BookCard(
                              book: book,
                              progress: progress,
                              status: shelfStatusFor(book, progress),
                              selected: selectedBookIds.contains(book.id),
                              onTap: selectedBookIds.isEmpty
                                  ? () => _openBook(context, book)
                                  : () => toggleBookSelection(ref, book.id),
                              onLongPress: () =>
                                  toggleBookSelection(ref, book.id),
                              onMore: selectedBookIds.isEmpty
                                  ? () => _showBookOptions(
                                        context,
                                        ref,
                                        book,
                                        progress,
                                      )
                                  : null,
                            );
                          },
                          addAutomaticKeepAlives: false,
                          addRepaintBoundaries: true,
                          childCount: visibleBooks.length,
                        ),
                      ),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final book = visibleBooks[index];
                            final progress = progressMap[book.id];
                            return Padding(
                              padding: EdgeInsets.only(
                                bottom:
                                    index == visibleBooks.length - 1 ? 0 : 12,
                              ),
                              child: BookListTile(
                                book: book,
                                progress: progress,
                                status: shelfStatusFor(book, progress),
                                selected: selectedBookIds.contains(book.id),
                                onTap: selectedBookIds.isEmpty
                                    ? () => _openBook(context, book)
                                    : () => toggleBookSelection(ref, book.id),
                                onLongPress: () =>
                                    toggleBookSelection(ref, book.id),
                                onMore: selectedBookIds.isEmpty
                                    ? () => _showBookOptions(
                                          context,
                                          ref,
                                          book,
                                          progress,
                                        )
                                    : null,
                              ),
                            );
                          },
                          addAutomaticKeepAlives: false,
                          addRepaintBoundaries: true,
                          childCount: visibleBooks.length,
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ),
      floatingActionButton: selectedBookIds.isEmpty
          ? FloatingActionButton(
              // 导入期间禁掉：并发导入会让重复检测看不见对方刚写进去的书。
              onPressed: importProgress != null
                  ? null
                  : () => importFlow.showOptions(context, ref),
              backgroundColor: importProgress != null
                  ? theme.colorScheme.surfaceContainerHighest
                  : null,
              tooltip: importProgress == null ? '导入书籍' : '正在导入…',
              child: importProgress != null
                  ? const SizedBox.square(
                      dimension: 22,
                      child: CircularProgressIndicator(strokeWidth: 2.5),
                    )
                  : const Icon(Icons.add),
            )
          : null,
      bottomSheet: selectedBookIds.isEmpty
          ? null
          : booksAsync.maybeWhen(
              data: (books) => buildBatchActionBar(
                context,
                ref,
                selectedBookIds,
                books.map((book) => book.id).toSet(),
              ),
              orElse: () => null,
            ),
    );
  }

  Widget _buildShelfToolbar(
    WidgetRef ref,
    BookShelfPreferences preferences,
    AsyncValue<List<String>> series,
    String? selectedSeries,
  ) {
    return SliverToBoxAdapter(
      child: Builder(
        builder: (context) => ColoredBox(
          color: stableSurfaceColor(context),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
            child: Row(
              children: [
                PopupMenuButton<BookSortMode>(
                  tooltip: '排序方式',
                  initialValue: preferences.sortMode,
                  onSelected: ref
                      .read(bookShelfPreferencesProvider.notifier)
                      .updateSortMode,
                  itemBuilder: (context) => [
                    for (final mode in BookSortMode.values)
                      PopupMenuItem(
                        value: mode,
                        child: Row(
                          children: [
                            Icon(_sortIcon(mode), size: 19),
                            const SizedBox(width: 10),
                            Text(mode.label),
                            if (mode == preferences.sortMode) ...[
                              const Spacer(),
                              Icon(
                                Icons.check,
                                size: 18,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ],
                          ],
                        ),
                      ),
                  ],
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.sort, size: 20),
                        const SizedBox(width: 7),
                        Text(preferences.sortMode.label),
                        const SizedBox(width: 3),
                        const Icon(Icons.arrow_drop_down, size: 20),
                      ],
                    ),
                  ),
                ),
                const Spacer(),
                series.when(
                  loading: () => const SizedBox.square(
                    dimension: 40,
                    child: Padding(
                      padding: EdgeInsets.all(11),
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                  error: (_, __) => IconButton(
                    tooltip: '重新加载系列',
                    icon: const Icon(Icons.refresh),
                    onPressed: () => ref.invalidate(bookSeriesProvider),
                  ),
                  data: (items) => PopupMenuButton<String>(
                    tooltip:
                        selectedSeries == null ? '筛选系列' : '系列：$selectedSeries',
                    icon: Icon(
                      selectedSeries == null
                          ? Icons.filter_alt_outlined
                          : Icons.filter_alt,
                    ),
                    onSelected: (value) => ref
                        .read(selectedBookSeriesProvider.notifier)
                        .state = value.isEmpty ? null : value,
                    itemBuilder: (context) => [
                      CheckedPopupMenuItem(
                        value: '',
                        checked: selectedSeries == null,
                        child: const Text('全部系列'),
                      ),
                      for (final name in items)
                        CheckedPopupMenuItem(
                          value: name,
                          checked: selectedSeries == name,
                          child: Text(
                            name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                  ),
                ),
                SegmentedButton<BookShelfViewMode>(
                  segments: const [
                    ButtonSegment(
                      value: BookShelfViewMode.grid,
                      icon: Icon(Icons.grid_view_outlined, size: 19),
                      tooltip: '网格视图',
                    ),
                    ButtonSegment(
                      value: BookShelfViewMode.list,
                      icon: Icon(Icons.view_list_outlined, size: 20),
                      tooltip: '列表视图',
                    ),
                  ],
                  selected: {preferences.viewMode},
                  showSelectedIcon: false,
                  onSelectionChanged: (selection) => ref
                      .read(bookShelfPreferencesProvider.notifier)
                      .updateViewMode(selection.single),
                  style: const ButtonStyle(
                    visualDensity: VisualDensity.compact,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCollectionFilters(
    WidgetRef ref,
    AsyncValue<List<BookCollection>> collections,
    int? selectedId,
  ) {
    return SliverToBoxAdapter(
      child: Builder(
        builder: (context) => ColoredBox(
          color: stableSurfaceColor(context),
          child: collections.when(
            loading: () => const SizedBox(
              height: 48,
              child: Center(
                child: SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
            error: (_, __) => Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => ref.invalidate(bookCollectionsProvider),
                  icon: const Icon(Icons.refresh),
                  label: const Text('重新加载书架'),
                ),
              ),
            ),
            data: (items) => SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Row(
                children: [
                  ChoiceChip(
                    avatar: const Icon(Icons.all_inbox_outlined, size: 18),
                    label: const Text('全部书架'),
                    selected: selectedId == null,
                    onSelected: (_) => ref
                        .read(selectedBookCollectionProvider.notifier)
                        .state = null,
                  ),
                  for (final collection in items) ...[
                    const SizedBox(width: 8),
                    ChoiceChip(
                      avatar: const Icon(Icons.shelves, size: 18),
                      label: Text(collection.name),
                      selected: selectedId == collection.id,
                      onSelected: (_) => ref
                          .read(selectedBookCollectionProvider.notifier)
                          .state = collection.id,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// 导入进度条。没有导入在跑时不占位。
  ///
  /// 用常驻的条而不是模态弹层：导入过程中还会弹「这本书已经有了」的重复
  /// 确认框，模态进度框会跟它打架。
  Widget _buildImportProgress(BookImportProgress? progress) {
    if (progress == null) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }
    return SliverToBoxAdapter(
      child: Builder(
        builder: (context) {
          final theme = Theme.of(context);
          return ColoredBox(
            color: stableSurfaceColor(context),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        progress.label,
                        style: theme.textTheme.labelMedium,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          progress.currentName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    // 单个文件时给不出有意义的比例，退回不确定进度。
                    child: LinearProgressIndicator(
                      value: progress.total > 1 ? progress.fraction : null,
                      minHeight: 4,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatusFilters(
    WidgetRef ref,
    BookReadingStatus? selected,
  ) {
    return SliverToBoxAdapter(
      child: Builder(
        builder: (context) => ColoredBox(
          color: stableSurfaceColor(context),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                ChoiceChip(
                  avatar: const Icon(Icons.library_books_outlined, size: 18),
                  label: const Text('全部'),
                  selected: selected == null,
                  onSelected: (_) =>
                      ref.read(shelfStatusFilterProvider.notifier).state = null,
                ),
                for (final status in BookReadingStatus.values) ...[
                  const SizedBox(width: 8),
                  ChoiceChip(
                    avatar: Icon(shelfStatusIcon(status), size: 18),
                    label: Text(status.label),
                    selected: selected == status,
                    onSelected: (_) => ref
                        .read(shelfStatusFilterProvider.notifier)
                        .state = status,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, ThemeData theme) {
    return SliverToBoxAdapter(
      child: ColoredBox(
        color: stableSurfaceColor(context),
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 32, 20, 16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.library_books_rounded,
                    color: theme.colorScheme.onPrimaryContainer,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '我的书架',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '记录你的阅读足迹',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: '管理书架',
                  icon: const Icon(Icons.shelves),
                  onPressed: () => showBookCollectionManager(context),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _openBook(BuildContext context, Book book) {
    Navigator.of(context, rootNavigator: true).push(
      GlassPageRoute(
        isOpaque: true,
        builder: (_) => ReaderPage(bookId: book.id),
      ),
    );
  }

  void _showEditBookDialog(BuildContext context, WidgetRef ref, Book book) {
    showDialog(
      context: context,
      builder: (ctx) => EditBookDialog(book: book),
    );
  }

  void _showBookOptions(
    BuildContext context,
    WidgetRef ref,
    Book book,
    ReadingProgressData? progress,
  ) {
    final status = shelfStatusFor(book, progress);
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => GlassContainer.stable(
        borderRadius: 24,
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
        child: Material(
          type: MaterialType.transparency,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('书籍选项', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.drive_file_move_outline),
                title: const Text('加入书架'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.pop(ctx);
                  showBookCollectionAssignment(context, book);
                },
              ),
              ListTile(
                leading: Icon(shelfStatusIcon(status)),
                title: const Text('阅读状态'),
                subtitle: Text(
                  book.readingStatus == null
                      ? '自动判断 · 当前${status.label}'
                      : status.label,
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.pop(ctx);
                  showBookStatusSheet(context, ref, book, status);
                },
              ),
              ListTile(
                leading: const Icon(Icons.edit),
                title: const Text('编辑书籍信息'),
                onTap: () {
                  Navigator.pop(ctx);
                  _showEditBookDialog(context, ref, book);
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text('删除书籍', style: TextStyle(color: Colors.red)),
                onTap: () {
                  Navigator.pop(ctx);
                  showDialog(
                    context: context,
                    builder: (innerCtx) => AlertDialog(
                      title: const Text('确认删除'),
                      content: Text('确定要删除《${book.title}》及其所有笔记吗？'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(innerCtx),
                          child: const Text('取消'),
                        ),
                        TextButton(
                          onPressed: () {
                            Navigator.pop(innerCtx);
                            unawaited(_deleteBook(context, ref, book));
                          },
                          child: const Text('删除',
                              style: TextStyle(color: Colors.red)),
                        ),
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  /// 删书失败得让人知道。`booksProvider` 自己会进 error 态，但书架看的是
  /// `shelfBooksProvider` 那条流，没人盯着它——不在这里报，用户看到的就是
  /// 点了「删除」书还在，什么提示都没有。
  Future<void> _deleteBook(
    BuildContext context,
    WidgetRef ref,
    Book book,
  ) async {
    try {
      await ref.read(booksProvider.notifier).deleteBook(book.id);
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('删除失败：$error')),
      );
    }
  }

  IconData _sortIcon(BookSortMode mode) {
    switch (mode) {
      case BookSortMode.recentlyRead:
        return Icons.history;
      case BookSortMode.importedNewest:
        return Icons.file_download_outlined;
      case BookSortMode.title:
        return Icons.sort_by_alpha;
      case BookSortMode.author:
        return Icons.person_outline;
      case BookSortMode.series:
        return Icons.collections_bookmark_outlined;
      case BookSortMode.readingTime:
        return Icons.schedule_outlined;
    }
  }
}
