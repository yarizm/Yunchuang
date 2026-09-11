import 'dart:io';

import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/material.dart';

/// 桌面端把书拖进书架。
///
/// 移动端没有这个交互（系统层面就没有拖放到应用的概念），所以非桌面平台
/// 直接返回 [child]，不引入任何额外的 widget 层。
class BookDropTarget extends StatefulWidget {
  final Widget child;

  /// 收到拖放，参数是原始路径，可能包含文件夹与不支持的格式，
  /// 由调用方交给 `BookService.resolveDroppedPaths` 解析。
  final Future<void> Function(List<String> paths) onDrop;

  /// 覆盖平台判断，仅供测试使用。
  final bool? enabledOverride;

  const BookDropTarget({
    super.key,
    required this.child,
    required this.onDrop,
    this.enabledOverride,
  });

  static bool get _isDesktop =>
      Platform.isWindows || Platform.isMacOS || Platform.isLinux;

  @override
  State<BookDropTarget> createState() => _BookDropTargetState();
}

class _BookDropTargetState extends State<BookDropTarget> {
  bool _dragging = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.enabledOverride ?? BookDropTarget._isDesktop;
    if (!enabled) return widget.child;

    final theme = Theme.of(context);

    return DropTarget(
      onDragEntered: (_) => setState(() => _dragging = true),
      onDragExited: (_) => setState(() => _dragging = false),
      onDragDone: (detail) async {
        setState(() => _dragging = false);
        final paths = detail.files.map((f) => f.path).toList();
        if (paths.isEmpty) return;
        await widget.onDrop(paths);
      },
      child: Stack(
        children: [
          widget.child,
          if (_dragging)
            Positioned.fill(
              child: IgnorePointer(
                child: Container(
                  color: theme.colorScheme.primary.withValues(alpha: 0.12),
                  alignment: Alignment.center,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 28,
                      vertical: 20,
                    ),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: theme.colorScheme.primary,
                        width: 2,
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.file_download_outlined,
                          color: theme.colorScheme.primary,
                          size: 32,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '松开以导入',
                          style: theme.textTheme.titleMedium,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'EPUB / PDF / TXT，文件夹会递归查找',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
