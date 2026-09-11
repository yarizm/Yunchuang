import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../services/screen_brightness_service.dart';
import 'reader_controller.dart';

class ImmersiveReaderShell extends StatefulWidget {
  final ReaderController controller;
  final Widget Function() toolbarBuilder;
  final Widget readerBody;
  final Widget? ttsMiniPlayer;
  final List<GlobalKey> readerTapExclusionKeys;
  final double readingBrightness;
  final bool brightnessGestureEnabled;
  final ValueChanged<double>? onBrightnessChanged;
  final ReaderBrightnessController brightnessController;
  final bool lineFocusEnabled;
  final int lineFocusLineCount;
  final double lineFocusLineHeight;
  final double lineFocusDimAmount;

  const ImmersiveReaderShell({
    super.key,
    required this.controller,
    required this.toolbarBuilder,
    required this.readerBody,
    this.ttsMiniPlayer,
    this.readerTapExclusionKeys = const [],
    this.readingBrightness = -1,
    this.brightnessGestureEnabled = false,
    this.onBrightnessChanged,
    this.brightnessController = const ScreenBrightnessService(),
    this.lineFocusEnabled = false,
    this.lineFocusLineCount = 3,
    this.lineFocusLineHeight = 32,
    this.lineFocusDimAmount = 0.35,
  });

  @override
  State<ImmersiveReaderShell> createState() => _ImmersiveReaderShellState();
}

class _ImmersiveReaderShellState extends State<ImmersiveReaderShell> {
  /// 顶部工具栏浮层覆盖正文的高度（不含系统状态栏）。
  /// 展开态最高：8 + max(44, 两行标题 58.4) + 14 ≈ 80，取 84 留余量。
  static const _topChromeHeight = 84.0;

  /// 点击判定在工具栏下方额外放宽的距离，避免贴边点击被当成正文点击。
  static const _topChromeTapSlop = 28.0;

  Offset? _shortTapStartLocal;
  Timer? _shortTapTimer;
  bool _shortTapEligible = false;
  bool _shortTapSuppressed = false;
  double _currentBrightness = 0.5;
  double? _pendingBrightness;
  bool _brightnessWriteInFlight = false;
  bool _resetBrightnessAfterWrite = false;
  bool _showBrightnessHud = false;
  Timer? _brightnessHudTimer;
  int _brightnessSyncRevision = 0;

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_syncBrightnessPreference());
    });
  }

  @override
  void didUpdateWidget(ImmersiveReaderShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.brightnessController != widget.brightnessController) {
      unawaited(oldWidget.brightnessController.resetBrightness());
    }
    if (oldWidget.readingBrightness != widget.readingBrightness ||
        oldWidget.brightnessController != widget.brightnessController) {
      unawaited(_syncBrightnessPreference());
    }
  }

  void _hideToolbar() {
    widget.controller.setToolbarVisible(false);
  }

  void _showToolbar() {
    widget.controller.setToolbarVisible(true);
  }

  Offset? _globalToLocal(Offset globalPosition) {
    final renderObject = context.findRenderObject();
    if (renderObject is! RenderBox || !renderObject.hasSize) {
      return null;
    }
    return renderObject.globalToLocal(globalPosition);
  }

  void _handleReaderPointerDown(PointerDownEvent event) {
    if (_isExcludedReaderTap(event.position)) {
      _shortTapTimer?.cancel();
      _shortTapTimer = null;
      _shortTapStartLocal = null;
      _shortTapEligible = false;
      _shortTapSuppressed = true;
      return;
    }
    _shortTapStartLocal = _globalToLocal(event.position);
    _shortTapEligible = true;
    _shortTapSuppressed = false;
    _shortTapTimer?.cancel();
    _shortTapTimer = Timer(kLongPressTimeout, () {
      _shortTapEligible = false;
    });
  }

  void _handleReaderPointerCancel(PointerCancelEvent event) {
    _shortTapTimer?.cancel();
    _shortTapTimer = null;
    _shortTapStartLocal = null;
    _shortTapEligible = false;
    _shortTapSuppressed = false;
  }

  void _handleReaderPointerUp(PointerUpEvent event) {
    final start = _shortTapStartLocal;
    final eligible = _shortTapEligible;
    final suppressed =
        _shortTapSuppressed || _isExcludedReaderTap(event.position);
    _shortTapTimer?.cancel();
    _shortTapTimer = null;
    _shortTapStartLocal = null;
    _shortTapEligible = false;
    _shortTapSuppressed = false;
    final end = _globalToLocal(event.position);
    if (suppressed) return;
    if (!eligible || start == null || end == null) return;
    if ((end - start).distance > kTouchSlop) return;
    if (_isReaderBodyPosition(end)) {
      if (widget.controller.toolbarVisible) {
        _hideToolbar();
      } else {
        _showToolbar();
      }
    }
  }

  bool _isExcludedReaderTap(Offset globalPosition) {
    for (final key in widget.readerTapExclusionKeys) {
      final context = key.currentContext;
      final renderObject = context?.findRenderObject();
      if (renderObject is! RenderBox || !renderObject.hasSize) {
        continue;
      }
      final topLeft = renderObject.localToGlobal(Offset.zero);
      final rect = topLeft & renderObject.size;
      if (rect.contains(globalPosition)) {
        return true;
      }
    }
    return false;
  }

  bool _isReaderBodyPosition(Offset localPosition) {
    final renderObject = context.findRenderObject();
    if (renderObject is! RenderBox || !renderObject.hasSize) {
      return false;
    }

    final size = renderObject.size;
    final mediaPadding = MediaQuery.paddingOf(context);
    final toolbarVisible = widget.controller.toolbarVisible;
    const sideNavWidth = 52.0;
    const topChromeHeight = _topChromeHeight + _topChromeTapSlop;
    final bottomChromeHeight = mediaPadding.bottom +
        (widget.controller.toolbarExpanded ? 156.0 : 116.0);
    final topBoundary =
        toolbarVisible ? mediaPadding.top + topChromeHeight : mediaPadding.top;
    final bottomBoundary = size.height -
        (toolbarVisible ? bottomChromeHeight : mediaPadding.bottom + 32.0);
    final inTopChrome = localPosition.dy <= topBoundary;
    final inBottomChrome = localPosition.dy >= bottomBoundary;
    final inLeftNav = toolbarVisible &&
        widget.controller.currentChapterIndex > 0 &&
        localPosition.dx <= sideNavWidth &&
        localPosition.dy > topBoundary &&
        localPosition.dy < bottomBoundary;
    final inRightNav = toolbarVisible &&
        widget.controller.currentChapterIndex <
            widget.controller.chapterCount - 1 &&
        localPosition.dx >= size.width - sideNavWidth &&
        localPosition.dy > topBoundary &&
        localPosition.dy < bottomBoundary;

    return !inTopChrome && !inBottomChrome && !inLeftNav && !inRightNav;
  }

  Future<void> _syncBrightnessPreference() async {
    final revision = ++_brightnessSyncRevision;
    final configured = widget.readingBrightness;
    if (configured >= 0) {
      _currentBrightness = configured.clamp(0.05, 1.0);
      _queueBrightnessWrite(_currentBrightness);
      return;
    }

    await widget.brightnessController.resetBrightness();
    final current = await widget.brightnessController.getCurrentBrightness();
    if (!mounted || revision != _brightnessSyncRevision) return;
    _currentBrightness = current.clamp(0.05, 1.0);
  }

  void _queueBrightnessWrite(double value) {
    _pendingBrightness = value.clamp(0.05, 1.0);
    if (!_brightnessWriteInFlight) {
      unawaited(_drainBrightnessWrites());
    }
  }

  Future<void> _drainBrightnessWrites() async {
    _brightnessWriteInFlight = true;
    final controller = widget.brightnessController;
    while (_pendingBrightness != null) {
      final value = _pendingBrightness!;
      _pendingBrightness = null;
      await controller.setBrightness(value);
    }
    _brightnessWriteInFlight = false;
    if (_resetBrightnessAfterWrite) {
      _resetBrightnessAfterWrite = false;
      await controller.resetBrightness();
    }
  }

  void _handleBrightnessDragStart(DragStartDetails details) {
    _brightnessHudTimer?.cancel();
    setState(() => _showBrightnessHud = true);
  }

  void _handleBrightnessDragUpdate(DragUpdateDetails details) {
    final height = context.size?.height ?? 1;
    final delta = -(details.primaryDelta ?? 0) / height;
    final next = (_currentBrightness + delta).clamp(0.05, 1.0);
    if (next == _currentBrightness) return;
    setState(() {
      _currentBrightness = next;
      _showBrightnessHud = true;
    });
    _queueBrightnessWrite(next);
  }

  void _handleBrightnessDragEnd(DragEndDetails details) {
    widget.onBrightnessChanged?.call(_currentBrightness);
    _scheduleBrightnessHudHide();
  }

  void _handleBrightnessDragCancel() {
    widget.onBrightnessChanged?.call(_currentBrightness);
    _scheduleBrightnessHudHide();
  }

  void _scheduleBrightnessHudHide() {
    _brightnessHudTimer?.cancel();
    _brightnessHudTimer = Timer(const Duration(milliseconds: 500), () {
      if (mounted) setState(() => _showBrightnessHud = false);
    });
  }

  Widget _buildLineFocusOverlay(BuildContext context) {
    final theme = Theme.of(context);
    final dimColor = theme.colorScheme.surface.withValues(
      alpha: widget.lineFocusDimAmount.clamp(0.1, 0.65),
    );
    final boundaryColor = theme.colorScheme.onSurface.withValues(alpha: 0.08);

    return Positioned.fill(
      key: const Key('line-focus-overlay'),
      child: IgnorePointer(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final lineCount =
                const {1, 3, 5}.contains(widget.lineFocusLineCount)
                    ? widget.lineFocusLineCount
                    : 3;
            final lineHeight = widget.lineFocusLineHeight.clamp(16.0, 96.0);
            final focusHeight = (lineHeight * lineCount + 12)
                .clamp(32.0, constraints.maxHeight * 0.8);
            final dimHeight = (constraints.maxHeight - focusHeight) / 2;

            return Stack(
              children: [
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  height: dimHeight,
                  child: ColoredBox(
                    key: const Key('line-focus-top-dim'),
                    color: dimColor,
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  height: dimHeight,
                  child: ColoredBox(
                    key: const Key('line-focus-bottom-dim'),
                    color: dimColor,
                  ),
                ),
                Positioned(
                  top: dimHeight,
                  left: 0,
                  right: 0,
                  height: focusHeight,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      border: Border.symmetric(
                        horizontal: BorderSide(color: boundaryColor),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  @override
  void dispose() {
    _shortTapTimer?.cancel();
    _brightnessHudTimer?.cancel();
    _brightnessSyncRevision++;
    _pendingBrightness = null;
    if (_brightnessWriteInFlight) {
      _resetBrightnessAfterWrite = true;
    } else {
      unawaited(widget.brightnessController.resetBrightness());
    }
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      child: widget.readerBody,
      builder: (context, readerBody) {
        final mediaPadding = MediaQuery.paddingOf(context);
        final toolbarVisible = widget.controller.toolbarVisible;
        final toolbarExpanded = widget.controller.toolbarExpanded;
        final ttsBottomOffset =
            toolbarVisible ? (toolbarExpanded ? 152.0 : 108.0) : 44.0;

        return Stack(
          children: [
            Positioned.fill(
              child: Listener(
                behavior: HitTestBehavior.translucent,
                onPointerDown: _handleReaderPointerDown,
                onPointerCancel: _handleReaderPointerCancel,
                onPointerUp: _handleReaderPointerUp,
                child: _ReaderContentInset(
                  key: const Key('reader-body-media-query'),
                  topInset: _topChromeHeight,
                  child: readerBody!,
                ),
              ),
            ),
            if (widget.lineFocusEnabled) _buildLineFocusOverlay(context),
            Positioned.fill(
              child: AnimatedSlide(
                offset: toolbarVisible ? Offset.zero : const Offset(0, -0.06),
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                child: AnimatedOpacity(
                  opacity: toolbarVisible ? 1 : 0,
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOutCubic,
                  child: IgnorePointer(
                    ignoring: !toolbarVisible,
                    child: Listener(
                      behavior: HitTestBehavior.translucent,
                      onPointerDown: _handleReaderPointerDown,
                      onPointerCancel: _handleReaderPointerCancel,
                      onPointerUp: _handleReaderPointerUp,
                      child: widget.toolbarBuilder(),
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: IgnorePointer(
                child: ValueListenableBuilder<double>(
                  valueListenable: widget.controller.scrollPositionListenable,
                  builder: (context, _, __) {
                    final theme = Theme.of(context);
                    final progress = widget.controller.bookProgress;
                    final chapterCount = widget.controller.chapterCount;
                    final currentChapter = chapterCount > 0
                        ? widget.controller.currentChapterIndex + 1
                        : 0;

                    // 滚动模式下正文会一直滚到屏幕底边，这行字没有底色就会
                    // 压在最后一行正文上，两边都读不了。用一段渐变把它托
                    // 住：上沿透明，下沿接近纸色，正文在它下面淡出。
                    final surface = theme.colorScheme.surface;
                    return DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            surface.withValues(alpha: 0),
                            surface.withValues(alpha: 0.94),
                          ],
                          stops: const [0, 0.55],
                        ),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SafeArea(
                            top: false,
                            bottom: false,
                            minimum: const EdgeInsets.symmetric(horizontal: 24),
                            child: Padding(
                              padding:
                                  const EdgeInsets.only(top: 18, bottom: 6),
                              child: Row(
                                children: [
                                  Text(
                                    '第 $currentChapter / $chapterCount 章',
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                  const Spacer(),
                                  Text(
                                    '${(progress * 100).round()}%',
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      color: theme.colorScheme.onSurfaceVariant,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          Padding(
                            padding:
                                EdgeInsets.only(bottom: mediaPadding.bottom),
                            child: LinearProgressIndicator(
                              value: progress,
                              minHeight: 2,
                              backgroundColor: theme.colorScheme.onSurface
                                  .withValues(alpha: 0.08),
                              valueColor: AlwaysStoppedAnimation(
                                theme.colorScheme.primary
                                    .withValues(alpha: 0.7),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
            if (widget.ttsMiniPlayer != null)
              Positioned(
                bottom: mediaPadding.bottom + ttsBottomOffset,
                left: 24,
                right: 24,
                child: AnimatedOpacity(
                  opacity: toolbarVisible ? 1 : 0,
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOutCubic,
                  child: IgnorePointer(
                    ignoring: !toolbarVisible,
                    child: widget.ttsMiniPlayer!,
                  ),
                ),
              ),
            if (widget.brightnessGestureEnabled && !toolbarVisible)
              Positioned(
                key: const Key('brightness-gesture-zone'),
                left: 0,
                top: mediaPadding.top,
                bottom: mediaPadding.bottom,
                width: 32,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onVerticalDragStart: _handleBrightnessDragStart,
                  onVerticalDragUpdate: _handleBrightnessDragUpdate,
                  onVerticalDragEnd: _handleBrightnessDragEnd,
                  onVerticalDragCancel: _handleBrightnessDragCancel,
                ),
              ),
            Positioned.fill(
              child: IgnorePointer(
                child: AnimatedOpacity(
                  opacity: _showBrightnessHud ? 1 : 0,
                  duration: const Duration(milliseconds: 120),
                  child: Center(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: Theme.of(context)
                            .colorScheme
                            .inverseSurface
                            .withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.brightness_6,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onInverseSurface,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '${(_currentBrightness * 100).round()}%',
                              style: TextStyle(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onInverseSurface,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// 给正文预留顶部工具栏覆盖的高度。
///
/// 预留量是恒定的，不跟随 `toolbarVisible`：正文的顶部 padding 一旦随工具栏
/// 显隐抖动，滚动模式会瞬间跳位（`txt_reader` / `epub_reader` 直接把它当作
/// ListView 的 padding.top），分页模式则会在每次点击时触发
/// `PagedReader.didChangeDependencies` 清空段落高度缓存并重排整章。
///
/// 单独抽成一个 widget，是为了把 `MediaQuery.of` 的依赖限制在这里——放在
/// 外层 `AnimatedBuilder` 里会让整个阅读器 Stack 订阅 viewInsets、textScaler
/// 等所有字段，键盘弹出或字号变化都会重建工具栏与浮层。
class _ReaderContentInset extends StatelessWidget {
  const _ReaderContentInset({
    super.key,
    required this.topInset,
    required this.child,
  });

  final double topInset;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final data = MediaQuery.of(context);
    return MediaQuery(
      data: data.copyWith(
        padding: data.padding.copyWith(top: data.padding.top + topInset),
      ),
      child: child,
    );
  }
}
