import 'package:flutter/material.dart';

import '../../database/app_database.dart';
import '../../models/book_reading_status.dart';
import 'book_card.dart';

class BookListTile extends StatelessWidget {
  final Book book;
  final ReadingProgressData? progress;
  final BookReadingStatus status;
  final bool selected;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onMore;

  const BookListTile({
    super.key,
    required this.book,
    required this.status,
    this.progress,
    this.selected = false,
    this.onTap,
    this.onLongPress,
    this.onMore,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final percentage = progress?.percentage.clamp(0.0, 1.0);
    final subtitle = [
      if (book.author.isNotEmpty) book.author,
      if (book.seriesName != null && book.seriesName!.isNotEmpty)
        _seriesLabel(book),
    ].join(' · ');

    return RepaintBoundary(
      child: Material(
        color: theme.colorScheme.surface,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(
            color: selected
                ? theme.colorScheme.primary
                : theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
            width: selected ? 2 : 1,
          ),
        ),
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Row(
              children: [
                SizedBox(
                  width: 62,
                  height: 88,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: BookCover(book: book),
                      ),
                      if (selected)
                        ColoredBox(
                          color:
                              theme.colorScheme.primary.withValues(alpha: 0.5),
                          child: const Icon(
                            Icons.check_circle,
                            color: Colors.white,
                            size: 30,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: SizedBox(
                    height: 88,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                book.title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  height: 1.25,
                                ),
                              ),
                            ),
                            IconButton(
                              tooltip: '书籍选项',
                              visualDensity: VisualDensity.compact,
                              constraints: const BoxConstraints.tightFor(
                                width: 32,
                                height: 32,
                              ),
                              padding: EdgeInsets.zero,
                              icon: const Icon(Icons.more_vert, size: 20),
                              onPressed: selected ? null : onMore,
                            ),
                          ],
                        ),
                        if (subtitle.isNotEmpty) ...[
                          const SizedBox(height: 3),
                          Text(
                            subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                        const Spacer(),
                        Row(
                          children: [
                            Icon(
                              _statusIcon(status),
                              size: 15,
                              color: theme.colorScheme.primary,
                            ),
                            const SizedBox(width: 5),
                            Text(
                              status.label,
                              style: theme.textTheme.labelMedium,
                            ),
                            const SizedBox(width: 10),
                            Text(
                              book.format.toUpperCase(),
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                            if (percentage != null) ...[
                              const Spacer(),
                              Text(
                                '${(percentage * 100).round()}%',
                                style: theme.textTheme.labelMedium,
                              ),
                            ],
                          ],
                        ),
                        if (percentage != null) ...[
                          const SizedBox(height: 5),
                          LinearProgressIndicator(
                            value: percentage,
                            minHeight: 3,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _seriesLabel(Book book) {
    final index = book.seriesIndex;
    if (index == null) return book.seriesName!;
    final formatted =
        index == index.roundToDouble() ? index.toInt().toString() : '$index';
    return '${book.seriesName} $formatted';
  }

  IconData _statusIcon(BookReadingStatus status) {
    switch (status) {
      case BookReadingStatus.unread:
        return Icons.fiber_new_outlined;
      case BookReadingStatus.reading:
        return Icons.auto_stories_outlined;
      case BookReadingStatus.finished:
        return Icons.check_circle_outline;
      case BookReadingStatus.paused:
        return Icons.pause_circle_outline;
    }
  }
}
