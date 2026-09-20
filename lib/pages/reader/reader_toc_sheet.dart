import 'dart:developer' as developer;

import 'package:flutter/material.dart';

import '../../database/app_database.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/glass_container.dart';
import 'reader_controller.dart';

class ReaderTocSheet {
  static void show(
    BuildContext context, {
    required List<Chapter> chapters,
    required ReaderController controller,
    required dynamic noteDao,
    required ValueChanged<int> onChapterSelected,
    required void Function(int chapterIndex, double position)
        onBookmarkSelected,
  }) {
    final openStopwatch = Stopwatch()..start();
    final openTimeline = developer.TimelineTask()
      ..start(
        'reader_toc_open',
        arguments: {
          'book_id': controller.bookId,
          'chapter_count': chapters.length,
        },
      );
    const tocItemExtent = 68.0;
    final screenHeight = MediaQuery.sizeOf(context).height;
    final initialOffset =
        (controller.currentChapterIndex * tocItemExtent - screenHeight * 0.25)
            .clamp(0.0, double.infinity);
    final tocScrollController =
        ScrollController(initialScrollOffset: initialOffset);
    var previewChapterIndex = controller.currentChapterIndex;

    final sheet = showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.16),
      builder: (sheetCtx) {
        return StatefulBuilder(
          builder: (sheetCtx, setSheetState) {
            final theme = Theme.of(sheetCtx);
            return DefaultTabController(
              length: 2,
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 20, 12, 12),
                  child: GlassContainer.stable(
                    borderRadius: 28,
                    color: theme.colorScheme.surface,
                    border: Border.all(
                      color: theme.colorScheme.outlineVariant
                          .withValues(alpha: 0.3),
                    ),
                    child: Material(
                      type: MaterialType.transparency,
                      child: SizedBox(
                        height: screenHeight * 0.74,
                        child: Column(
                          children: [
                            const SizedBox(height: 10),
                            Container(
                              width: 42,
                              height: 4,
                              decoration: BoxDecoration(
                                color: theme.colorScheme.onSurface
                                    .withValues(alpha: 0.18),
                                borderRadius: BorderRadius.circular(99),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.fromLTRB(18, 18, 12, 8),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '目录',
                                          style: theme.textTheme.titleLarge
                                              ?.copyWith(
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          '跳转到你想继续阅读的位置',
                                          style: theme.textTheme.bodySmall
                                              ?.copyWith(
                                            color: theme
                                                .colorScheme.onSurfaceVariant,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 8,
                                    ),
                                    decoration: BoxDecoration(
                                      color: theme.colorScheme.primaryContainer,
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: Text(
                                      '第 ${controller.currentChapterIndex + 1} 章',
                                      style:
                                          theme.textTheme.labelMedium?.copyWith(
                                        fontWeight: FontWeight.w700,
                                        color: theme
                                            .colorScheme.onPrimaryContainer,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  IconButton(
                                    tooltip: '关闭',
                                    onPressed: () => Navigator.pop(sheetCtx),
                                    icon: const Icon(Icons.close_rounded),
                                  ),
                                ],
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  color:
                                      theme.colorScheme.surfaceContainerHighest,
                                  borderRadius: BorderRadius.circular(18),
                                ),
                                child: TabBar(
                                  dividerColor: Colors.transparent,
                                  indicatorSize: TabBarIndicatorSize.tab,
                                  indicator: BoxDecoration(
                                    borderRadius: BorderRadius.circular(14),
                                    color: theme.colorScheme.primary
                                        .withValues(alpha: 0.16),
                                  ),
                                  labelStyle:
                                      theme.textTheme.labelLarge?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                                  unselectedLabelColor:
                                      theme.colorScheme.onSurfaceVariant,
                                  tabs: const [
                                    Tab(text: '目录'),
                                    Tab(text: '书签'),
                                  ],
                                ),
                              ),
                            ),
                            if (chapters.isNotEmpty)
                              Padding(
                                padding:
                                    const EdgeInsets.fromLTRB(18, 0, 18, 12),
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    color:
                                        theme.colorScheme.surfaceContainerHigh,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: theme.colorScheme.outlineVariant
                                          .withValues(alpha: 0.24),
                                    ),
                                  ),
                                  child: Padding(
                                    padding:
                                        const EdgeInsets.fromLTRB(12, 8, 12, 8),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Icon(
                                              Icons.swap_vert_rounded,
                                              size: 18,
                                              color: theme.colorScheme.primary,
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Text(
                                                '全局定位',
                                                style: theme
                                                    .textTheme.labelLarge
                                                    ?.copyWith(
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                            ),
                                            Text(
                                              '第 ${previewChapterIndex + 1} / ${chapters.length} 章',
                                              key: const Key(
                                                'toc-global-progress-label',
                                              ),
                                              style: theme.textTheme.labelMedium
                                                  ?.copyWith(
                                                color: theme.colorScheme
                                                    .onSurfaceVariant,
                                              ),
                                            ),
                                          ],
                                        ),
                                        Slider(
                                          key: const Key('toc-global-progress'),
                                          min: 0,
                                          max: chapters.length > 1
                                              ? (chapters.length - 1).toDouble()
                                              : 1,
                                          value: chapters.length > 1
                                              ? previewChapterIndex.toDouble()
                                              : 0,
                                          onChanged: chapters.length <= 1
                                              ? null
                                              : (value) {
                                                  final index = value
                                                      .round()
                                                      .clamp(
                                                        0,
                                                        chapters.length - 1,
                                                      )
                                                      .toInt();
                                                  if (index !=
                                                      previewChapterIndex) {
                                                    setSheetState(() {
                                                      previewChapterIndex =
                                                          index;
                                                    });
                                                  }
                                                  _scrollToTocChapter(
                                                    tocScrollController,
                                                    index,
                                                    tocItemExtent,
                                                  );
                                                },
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            Expanded(
                              child: TabBarView(
                                children: [
                                  ListView.builder(
                                    controller: tocScrollController,
                                    itemExtent: tocItemExtent,
                                    padding: const EdgeInsets.fromLTRB(
                                        12, 0, 12, 16),
                                    itemCount: chapters.length,
                                    itemBuilder: (ctx, index) {
                                      final chapter = chapters[index];
                                      final isCurrent = index ==
                                          controller.currentChapterIndex;
                                      return _buildTocTile(
                                        theme,
                                        chapter,
                                        index,
                                        isCurrent: isCurrent,
                                        onTap: () {
                                          Navigator.pop(ctx);
                                          onChapterSelected(index);
                                        },
                                      );
                                    },
                                  ),
                                  _buildBookmarksTab(
                                    theme,
                                    bookId: controller.bookId,
                                    chapters: chapters,
                                    noteDao: noteDao,
                                    onBookmarkSelected: (idx, pos) {
                                      Navigator.pop(sheetCtx);
                                      onBookmarkSelected(idx, pos);
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      openTimeline
        ..instant(
          'reader_toc_first_frame',
          arguments: {'elapsed_ms': openStopwatch.elapsedMilliseconds},
        )
        ..finish();
      developer.log(
        'reader_toc_first_frame=${openStopwatch.elapsedMilliseconds}ms '
        'chapters=${chapters.length}',
        name: 'reader.performance',
      );
    });
    sheet.whenComplete(tocScrollController.dispose);
  }

  static void _scrollToTocChapter(
    ScrollController controller,
    int index,
    double itemExtent,
  ) {
    if (!controller.hasClients) return;
    final position = controller.position;
    final target = (index * itemExtent - position.viewportDimension / 2)
        .clamp(0.0, position.maxScrollExtent)
        .toDouble();
    controller.jumpTo(target);
  }

  static Widget _buildTocTile(
    ThemeData theme,
    Chapter chapter,
    int index, {
    required bool isCurrent,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Ink(
            key: ValueKey('toc-chapter-$index'),
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: isCurrent
                  ? theme.colorScheme.primary.withValues(alpha: 0.12)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              border: isCurrent
                  ? Border.all(
                      color: theme.colorScheme.primary.withValues(alpha: 0.22),
                    )
                  : null,
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 34,
                  height: 34,
                  child: Center(
                    child: Text(
                      '${index + 1}',
                      style: theme.textTheme.labelMedium?.copyWith(
                        fontWeight:
                            isCurrent ? FontWeight.w700 : FontWeight.w500,
                        color: isCurrent
                            ? theme.colorScheme.primary
                            : theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    chapter.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w500,
                      color: isCurrent
                          ? theme.colorScheme.primary
                          : theme.colorScheme.onSurface,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Icon(
                  isCurrent
                      ? Icons.play_circle_fill_rounded
                      : Icons.chevron_right_rounded,
                  size: 20,
                  color: isCurrent
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static Widget _buildBookmarksTab(
    ThemeData theme, {
    required int bookId,
    required List<Chapter> chapters,
    required dynamic noteDao,
    required void Function(int chapterIndex, double position)
        onBookmarkSelected,
  }) {
    return FutureBuilder<List<dynamic>>(
      future: noteDao.bookmarksForBook(bookId),
      builder: (ctx, snap) {
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final bookmarks = snap.data!;
        if (bookmarks.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: GlassContainer.stable(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 28,
                ),
                borderRadius: 22,
                color: theme.colorScheme.surfaceContainerHigh,
                child: const EmptyState(
                  icon: Icons.bookmark_add_outlined,
                  title: '还没有书签',
                  subtitle: '点击顶部书签按钮，把当前阅读位置保存下来',
                ),
              ),
            ),
          );
        }
        final chaptersById = <int, Chapter>{
          for (final chapter in chapters) chapter.id: chapter,
        };
        final chapterIndices = <int, int>{
          for (var index = 0; index < chapters.length; index++)
            chapters[index].id: index,
        };
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
          itemCount: bookmarks.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (ctx, index) {
            final bm = bookmarks[index];
            final chapter =
                bm.chapterId == null ? null : chaptersById[bm.chapterId];
            final positionLabel =
                '${((bm.positionStart ?? 0) / 100).toStringAsFixed(0)}%';
            final dateLabel = bm.createdAt.toIso8601String().substring(0, 10);
            return Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(18),
                onTap: () {
                  if (chapter == null) return;
                  final idx = chapterIndices[chapter.id] ?? -1;
                  if (idx >= 0) {
                    final position =
                        ((bm.positionStart ?? 0) / 10000).clamp(0.0, 1.0);
                    onBookmarkSelected(idx, position.toDouble());
                  }
                },
                child: Ink(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: theme.colorScheme.outlineVariant
                          .withValues(alpha: 0.18),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color:
                              theme.colorScheme.primary.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.bookmark_rounded,
                          size: 18,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              chapter?.title ?? '未知章节',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '$positionLabel · $dateLabel',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Icon(
                        Icons.chevron_right_rounded,
                        size: 20,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
