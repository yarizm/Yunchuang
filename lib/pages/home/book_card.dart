import 'dart:io';

import 'package:flutter/material.dart';

import '../../database/app_database.dart';
import '../../models/book_reading_status.dart';

class BookCard extends StatelessWidget {
  final Book book;
  final ReadingProgressData? progress;
  final BookReadingStatus? status;
  final bool selected;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onMore;

  const BookCard({
    super.key,
    required this.book,
    this.progress,
    this.status,
    this.selected = false,
    this.onTap,
    this.onLongPress,
    this.onMore,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final progressValue = progress?.percentage.clamp(0.0, 1.0);
    final subtitle = [
      if (book.author.isNotEmpty) book.author,
      if (book.seriesName != null && book.seriesName!.isNotEmpty)
        _seriesLabel(book),
    ].join(' · ');

    return RepaintBoundary(
      child: Material(
        color: theme.colorScheme.surface,
        shadowColor: Colors.black.withValues(alpha: 0.08),
        elevation: 1,
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    BookCover(book: book),
                    if (status != null)
                      Positioned(
                        top: 8,
                        right: 8,
                        child: _buildStatusBadge(context, status!),
                      ),
                    Positioned(
                      top: 4,
                      left: 4,
                      child: selected
                          ? _SelectionMark(color: theme.colorScheme.primary)
                          : IconButton.filledTonal(
                              tooltip: '书籍选项',
                              visualDensity: VisualDensity.compact,
                              constraints: const BoxConstraints.tightFor(
                                width: 34,
                                height: 34,
                              ),
                              icon: const Icon(Icons.more_vert, size: 19),
                              onPressed: onMore,
                            ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      book.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        height: 1.3,
                      ),
                    ),
                    if (subtitle.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (progressValue != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
                  child: Row(
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(2),
                          child: LinearProgressIndicator(
                            value: progressValue,
                            backgroundColor: theme.colorScheme.primary
                                .withValues(alpha: 0.12),
                            minHeight: 4,
                            valueColor: AlwaysStoppedAnimation(
                              theme.colorScheme.primary.withValues(alpha: 0.75),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 34,
                        child: Text(
                          '${(progressValue * 100).round()}%',
                          textAlign: TextAlign.end,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              else
                const SizedBox(height: 3),
            ],
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

  Widget _buildStatusBadge(
    BuildContext context,
    BookReadingStatus status,
  ) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _statusIcon(status),
              size: 12,
              color: theme.colorScheme.onSurface,
            ),
            const SizedBox(width: 3),
            Text(
              status.label,
              style: theme.textTheme.labelSmall?.copyWith(
                fontSize: 10,
                color: theme.colorScheme.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
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

class _SelectionMark extends StatelessWidget {
  final Color color;

  const _SelectionMark({required this.color});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      child: const SizedBox.square(
        dimension: 30,
        child: Icon(Icons.check, size: 19, color: Colors.white),
      ),
    );
  }
}

class BookCover extends StatelessWidget {
  final Book book;

  const BookCover({
    super.key,
    required this.book,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (book.coverPath != null && book.coverPath!.isNotEmpty) {
      return LayoutBuilder(
        builder: (context, constraints) {
          final devicePixelRatio = MediaQuery.devicePixelRatioOf(context);
          final cacheWidth = constraints.maxWidth.isFinite
              ? (constraints.maxWidth * devicePixelRatio).round()
              : null;
          final cacheHeight = constraints.maxHeight.isFinite
              ? (constraints.maxHeight * devicePixelRatio).round()
              : null;

          return Stack(
            fit: StackFit.expand,
            children: [
              Image.file(
                File(book.coverPath!),
                fit: BoxFit.cover,
                filterQuality: FilterQuality.medium,
                cacheWidth:
                    cacheWidth != null && cacheWidth > 0 ? cacheWidth : null,
                cacheHeight:
                    cacheHeight != null && cacheHeight > 0 ? cacheHeight : null,
                errorBuilder: (_, __, ___) => _buildFallbackCover(theme),
              ),
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                height: 40,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.3),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      );
    }

    return _buildFallbackCover(theme);
  }

  Widget _buildFallbackCover(ThemeData theme) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            theme.colorScheme.primary,
            theme.colorScheme.secondary,
          ],
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _formatIcon,
              size: 42,
              color: theme.colorScheme.onPrimary,
            ),
            const SizedBox(height: 8),
            Text(
              book.format.toUpperCase(),
              style: TextStyle(
                color: theme.colorScheme.onPrimary,
                fontSize: 11,
                fontWeight: FontWeight.w500,
                letterSpacing: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData get _formatIcon {
    switch (book.format) {
      case 'epub':
        return Icons.menu_book;
      case 'pdf':
        return Icons.picture_as_pdf;
      case 'txt':
        return Icons.description;
      default:
        return Icons.book;
    }
  }
}
