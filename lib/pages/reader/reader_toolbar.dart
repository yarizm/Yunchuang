import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class ReaderToolbar extends StatelessWidget {
  final String chapterTitle;
  final int currentChapter;
  final int totalChapters;
  final VoidCallback? onBack;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;
  final VoidCallback? onTts;
  final VoidCallback? onToc;
  final VoidCallback? onAi;
  final VoidCallback? onTranslation;
  final VoidCallback? onSettings;
  final bool translationEnabled;
  final double scrollPosition;
  final ValueListenable<double>? scrollPositionListenable;
  final bool isBookmarked;
  final VoidCallback? onBookmark;
  final bool isExpanded;
  final VoidCallback? onToggleExpanded;
  final VoidCallback? onHide;
  final VoidCallback? onHistoryBack;
  final VoidCallback? onHistoryForward;

  const ReaderToolbar({
    super.key,
    required this.chapterTitle,
    required this.currentChapter,
    required this.totalChapters,
    this.onBack,
    this.onPrevious,
    this.onNext,
    this.onTts,
    this.onToc,
    this.onAi,
    this.onTranslation,
    this.onSettings,
    this.translationEnabled = false,
    this.scrollPosition = 0.0,
    this.scrollPositionListenable,
    this.isBookmarked = false,
    this.onBookmark,
    this.isExpanded = false,
    this.onToggleExpanded,
    this.onHide,
    this.onHistoryBack,
    this.onHistoryForward,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final chapterNumber = currentChapter + 1;

    return Column(
      children: [
        _TopChrome(
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: EdgeInsets.fromLTRB(10, 8, 10, isExpanded ? 14 : 10),
              child: Row(
                children: [
                  _IconSurface(
                    tooltip: '返回书架',
                    icon: Icons.arrow_back,
                    onPressed: onBack ??
                        () => Navigator.of(context, rootNavigator: true).pop(),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          chapterTitle,
                          textAlign: TextAlign.center,
                          maxLines: isExpanded ? 2 : 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            height: 1.2,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '第 $chapterNumber 章 / 共 $totalChapters 章',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  _IconSurface(
                    tooltip: isBookmarked ? '移除书签' : '添加书签',
                    icon: isBookmarked ? Icons.bookmark : Icons.bookmark_border,
                    onPressed: onBookmark,
                  ),
                  if (onHide != null) ...[
                    const SizedBox(width: 8),
                    _IconSurface(
                      tooltip: '收起导航栏',
                      icon: Icons.keyboard_arrow_up_rounded,
                      onPressed: onHide,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
        Expanded(
          child: Stack(
            children: [
              Positioned.fill(
                child: SafeArea(
                  minimum:
                      const EdgeInsets.symmetric(horizontal: 0, vertical: 112),
                  child: Row(
                    children: [
                      if (currentChapter > 0)
                        _EdgeNavButton(
                          tooltip: '上一章',
                          icon: Icons.chevron_left_rounded,
                          side: _NavSide.left,
                          onPressed: onPrevious,
                        )
                      else
                        const SizedBox(width: 34),
                      const Spacer(),
                      if (currentChapter < totalChapters - 1)
                        _EdgeNavButton(
                          tooltip: '下一章',
                          icon: Icons.chevron_right_rounded,
                          side: _NavSide.right,
                          onPressed: onNext,
                        )
                      else
                        const SizedBox(width: 34),
                    ],
                  ),
                ),
              ),
              Align(
                alignment: Alignment.bottomCenter,
                child: _BottomChrome(
                  child: SafeArea(
                    top: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 10, 16, 26),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (scrollPositionListenable != null)
                            ValueListenableBuilder<double>(
                              valueListenable: scrollPositionListenable!,
                              builder: (context, progress, _) =>
                                  _buildProgressIndicator(theme, progress),
                            )
                          else
                            _buildProgressIndicator(theme, scrollPosition),
                          const SizedBox(height: 10),
                          Material(
                            color: theme.colorScheme.surfaceContainerHigh,
                            borderRadius: BorderRadius.circular(24),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 6,
                              ),
                              child: AnimatedSwitcher(
                                duration: const Duration(milliseconds: 180),
                                switchInCurve: Curves.easeOutCubic,
                                switchOutCurve: Curves.easeInCubic,
                                child: isExpanded
                                    ? _ExpandedActionRow(
                                        key: const ValueKey('expanded_actions'),
                                        onToc: onToc,
                                        onAi: onAi,
                                        onTranslation: onTranslation,
                                        translationEnabled: translationEnabled,
                                        onTts: onTts,
                                        onSettings: onSettings,
                                        onToggleExpanded: onToggleExpanded,
                                        onHistoryBack: onHistoryBack,
                                        onHistoryForward: onHistoryForward,
                                      )
                                    : _CompactActionRow(
                                        key: const ValueKey('compact_actions'),
                                        onToc: onToc,
                                        onSettings: onSettings,
                                        onToggleExpanded: onToggleExpanded,
                                      ),
                              ),
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
        ),
      ],
    );
  }

  Widget _buildProgressIndicator(ThemeData theme, double progress) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(99),
      child: LinearProgressIndicator(
        value: progress,
        minHeight: 2.5,
        backgroundColor: theme.dividerColor.withValues(alpha: 0.2),
        valueColor: AlwaysStoppedAnimation(
          theme.colorScheme.primary.withValues(alpha: 0.7),
        ),
      ),
    );
  }
}

class _TopChrome extends StatelessWidget {
  final Widget child;

  const _TopChrome({required this.child});

  @override
  Widget build(BuildContext context) {
    final surface = Theme.of(context).colorScheme.surface;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            surface.withValues(alpha: 0.98),
            surface.withValues(alpha: 0.9),
            surface.withValues(alpha: 0),
          ],
        ),
      ),
      child: child,
    );
  }
}

class _BottomChrome extends StatelessWidget {
  final Widget child;

  const _BottomChrome({required this.child});

  @override
  Widget build(BuildContext context) {
    final surface = Theme.of(context).colorScheme.surface;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [
            surface.withValues(alpha: 0.98),
            surface.withValues(alpha: 0.9),
            surface.withValues(alpha: 0),
          ],
        ),
      ),
      child: child,
    );
  }
}

class _IconSurface extends StatelessWidget {
  final String tooltip;
  final IconData icon;
  final VoidCallback? onPressed;

  const _IconSurface({
    required this.tooltip,
    required this.icon,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Tooltip(
      message: tooltip,
      child: Material(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onPressed,
          child: SizedBox(
            width: 44,
            height: 44,
            child: Icon(
              icon,
              size: 20,
              color: onPressed == null
                  ? theme.disabledColor
                  : theme.colorScheme.onSurface,
            ),
          ),
        ),
      ),
    );
  }
}

enum _NavSide { left, right }

class _EdgeNavButton extends StatefulWidget {
  final String tooltip;
  final IconData icon;
  final _NavSide side;
  final VoidCallback? onPressed;

  const _EdgeNavButton({
    required this.tooltip,
    required this.icon,
    required this.side,
    this.onPressed,
  });

  @override
  State<_EdgeNavButton> createState() => _EdgeNavButtonState();
}

class _EdgeNavButtonState extends State<_EdgeNavButton> {
  bool _isHovered = false;
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final surface = theme.colorScheme.surface;
    final borderRadius = BorderRadius.horizontal(
      left: widget.side == _NavSide.right
          ? const Radius.circular(18)
          : Radius.zero,
      right: widget.side == _NavSide.left
          ? const Radius.circular(18)
          : Radius.zero,
    );
    final begin = widget.side == _NavSide.left
        ? Alignment.centerLeft
        : Alignment.centerRight;
    final end = widget.side == _NavSide.left
        ? Alignment.centerRight
        : Alignment.centerLeft;
    final isInteractive = widget.onPressed != null;
    final primaryAlpha = _isPressed
        ? 0.82
        : _isHovered
            ? 0.72
            : 0.6;
    final secondaryAlpha = _isPressed
        ? 0.36
        : _isHovered
            ? 0.28
            : 0.22;
    final iconColor = isInteractive
        ? theme.colorScheme.onSurface.withValues(
            alpha: _isPressed
                ? 0.98
                : _isHovered
                    ? 0.94
                    : 0.9,
          )
        : theme.disabledColor;

    return Tooltip(
      message: widget.tooltip,
      child: SizedBox(
        width: 34,
        child: MouseRegion(
          cursor: isInteractive ? SystemMouseCursors.click : MouseCursor.defer,
          child: AnimatedScale(
            scale: _isPressed
                ? 0.96
                : _isHovered
                    ? 1.04
                    : 1,
            duration: const Duration(milliseconds: 120),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: borderRadius,
                onTap: widget.onPressed,
                onHover: (value) => setState(() => _isHovered = value),
                onHighlightChanged: (value) =>
                    setState(() => _isPressed = value),
                child: Ink(
                  decoration: BoxDecoration(
                    borderRadius: borderRadius,
                    gradient: LinearGradient(
                      begin: begin,
                      end: end,
                      colors: [
                        surface.withValues(alpha: primaryAlpha),
                        surface.withValues(alpha: secondaryAlpha),
                        surface.withValues(alpha: 0),
                      ],
                    ),
                    boxShadow: _isHovered
                        ? [
                            BoxShadow(
                              color: theme.colorScheme.shadow
                                  .withValues(alpha: 0.08),
                              blurRadius: 16,
                              offset: const Offset(0, 6),
                            ),
                          ]
                        : null,
                  ),
                  child: Align(
                    alignment: widget.side == _NavSide.left
                        ? Alignment.centerLeft
                        : Alignment.centerRight,
                    child: AnimatedPadding(
                      duration: const Duration(milliseconds: 140),
                      curve: Curves.easeOutCubic,
                      padding: EdgeInsets.only(
                        left: widget.side == _NavSide.left
                            ? (_isHovered ? 6 : 3)
                            : 0,
                        right: widget.side == _NavSide.right
                            ? (_isHovered ? 6 : 3)
                            : 0,
                      ),
                      child: Icon(
                        widget.icon,
                        size: 24,
                        color: iconColor,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CompactActionRow extends StatelessWidget {
  final VoidCallback? onToc;
  final VoidCallback? onSettings;
  final VoidCallback? onToggleExpanded;

  const _CompactActionRow({
    super.key,
    required this.onToc,
    required this.onSettings,
    required this.onToggleExpanded,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _BottomActionButton(
            tooltip: '目录',
            icon: Icons.format_list_bulleted,
            label: '目录',
            onPressed: onToc,
          ),
        ),
        Expanded(
          child: _BottomActionButton(
            tooltip: '更多工具',
            icon: Icons.expand_less_rounded,
            label: '更多',
            onPressed: onToggleExpanded,
          ),
        ),
        Expanded(
          child: _BottomActionButton(
            tooltip: '阅读设置',
            icon: Icons.settings,
            label: '设置',
            onPressed: onSettings,
          ),
        ),
      ],
    );
  }
}

class _ExpandedActionRow extends StatelessWidget {
  final VoidCallback? onToc;
  final VoidCallback? onAi;
  final VoidCallback? onTranslation;
  final VoidCallback? onTts;
  final VoidCallback? onSettings;
  final VoidCallback? onToggleExpanded;
  final VoidCallback? onHistoryBack;
  final VoidCallback? onHistoryForward;
  final bool translationEnabled;

  const _ExpandedActionRow({
    super.key,
    required this.onToc,
    required this.onAi,
    required this.onTranslation,
    required this.translationEnabled,
    required this.onTts,
    required this.onSettings,
    required this.onToggleExpanded,
    required this.onHistoryBack,
    required this.onHistoryForward,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Expanded(
              child: _BottomActionButton(
                tooltip: '返回上一位置',
                icon: Icons.undo_rounded,
                label: '后退',
                onPressed: onHistoryBack,
              ),
            ),
            Expanded(
              child: _BottomActionButton(
                tooltip: '前进到下一位置',
                icon: Icons.redo_rounded,
                label: '前进',
                onPressed: onHistoryForward,
              ),
            ),
            Expanded(
              child: _BottomActionButton(
                tooltip: '目录',
                icon: Icons.format_list_bulleted,
                label: '目录',
                onPressed: onToc,
              ),
            ),
            Expanded(
              child: _BottomActionButton(
                tooltip: 'AI 助手',
                icon: Icons.auto_awesome,
                label: 'AI',
                onPressed: onAi,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Row(
          children: [
            Expanded(
              child: _BottomActionButton(
                key: const Key('reader-translation-tool'),
                tooltip: translationEnabled ? '翻译（已启用）' : '配置在线翻译',
                icon: Icons.translate,
                label: '翻译',
                active: translationEnabled,
                onPressed: onTranslation,
              ),
            ),
            Expanded(
              child: _BottomActionButton(
                tooltip: '朗读',
                icon: Icons.record_voice_over,
                label: '朗读',
                onPressed: onTts,
              ),
            ),
            Expanded(
              child: _BottomActionButton(
                tooltip: '阅读设置',
                icon: Icons.settings,
                label: '设置',
                onPressed: onSettings,
              ),
            ),
            Expanded(
              child: _BottomActionButton(
                tooltip: '收起工具栏',
                icon: Icons.expand_more_rounded,
                label: '收起',
                onPressed: onToggleExpanded,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _BottomActionButton extends StatelessWidget {
  final String tooltip;
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final bool active;

  const _BottomActionButton({
    super.key,
    required this.tooltip,
    required this.icon,
    required this.label,
    this.onPressed,
    this.active = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final enabledColor =
        active ? theme.colorScheme.primary : theme.colorScheme.onSurface;
    return Tooltip(
      message: tooltip,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onPressed,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: 20,
                  color: onPressed == null ? theme.disabledColor : enabledColor,
                ),
                const SizedBox(height: 3),
                Text(
                  label,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color:
                        onPressed == null ? theme.disabledColor : enabledColor,
                    fontWeight: active ? FontWeight.w700 : null,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
