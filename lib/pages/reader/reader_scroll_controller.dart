import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

/// 一个列表项覆盖的正文字符区间，`end` 不含。标题这类不含正文的项是空区间。
typedef ReaderTextRange = ({int start, int end});

/// 滚动模式按「正文字符」定位的 [ScrollController]。
///
/// `ListView.builder` 是懒布局，`maxScrollExtent` 只是拿已布局子项的平均高度
/// 外推出来的估计值，布局越往后推它越会变。旧实现按 `pixels / maxScrollExtent`
/// 记进度、恢复时跳到「比例 × maxScrollExtent」，估计值一变就落到别处，于是一帧
/// 帧按新的估计值重跳——打开书时正文上下抽动，最后停的段落也不对。
///
/// 某个滚动偏移处是哪段正文倒是准的：往后跳时 sliver 会把途经的子项逐个布局，
/// 不准的只有总高度。所以这里的位置一律是字符坐标：阅读位置是视口顶部那一行的
/// 字符，恢复就是先让目标字符所在的子项被布局出来，再按它的真实偏移跳过去。
/// 子项内部按字数线性插值，记进度和恢复走同一套换算，来回不会漂。
class ReaderScrollController extends ScrollController {
  ReaderScrollController({this.onReadingPositionChanged}) {
    addListener(_handleScroll);
  }

  /// 阅读位置变化，单位是字符比例 0~1，滚到底记 1。
  ///
  /// 等布局完成才算，每帧最多回报一次；定位期间不回报，定位结束补报一次。
  final ValueChanged<double>? onReadingPositionChanged;

  /// 估算落点要几帧才能收敛，正常两三帧。超过这个数就停在当前位置。
  static const _maxRestoreFrames = 24;

  final ValueNotifier<bool> _restoring = ValueNotifier(false);
  int _textLength = 0;
  int _leadingItemCount = 0;
  List<ReaderTextRange> _ranges = const [];
  double _topInset = 0;

  int _request = 0;
  int? _runningRequest;
  double? _pendingFraction;
  bool _reportScheduled = false;
  bool _disposed = false;
  ScrollPosition? _sliverOwner;
  RenderSliverMultiBoxAdaptor? _sliver;

  /// 正在把正文挪到目标位置。阅读器在这期间藏起正文，免得露出估算中的中间帧。
  ValueListenable<bool> get restoring => _restoring;

  /// 阅读器每次 build 时告诉控制器列表项和字符的对应关系。
  ///
  /// [leadingItemCount] 是正文前不含正文的项（章节标题），[ranges] 依次是之后
  /// 每一项的字符区间。[topInset] 是列表顶部留白（安全区 + 正文顶部留白），
  /// 阅读位置取的是留白下面那一行。
  void updateLayout({
    required int textLength,
    required List<ReaderTextRange> ranges,
    required int leadingItemCount,
    required double topInset,
  }) {
    _textLength = textLength;
    _ranges = ranges;
    _leadingItemCount = leadingItemCount;
    _topInset = topInset;
  }

  /// 视口顶部那一行的字符比例；滚到底算 1。布局还没好时返回 null。
  double? get readingFraction {
    final position = _laidOutPosition;
    if (position == null) return null;
    if (position.maxScrollExtent > 0 &&
        position.pixels >= position.maxScrollExtent - 0.5) {
      return 1.0;
    }
    if (_textLength <= 0) return 0.0;
    final char = _charAt(position.pixels + _topInset);
    if (char == null) return null;
    return (char / _textLength).clamp(0.0, 1.0).toDouble();
  }

  /// 视口里正文区域正中那一行的字符偏移。
  int? get centerCharOffset {
    final position = _laidOutPosition;
    if (position == null) return null;
    final top = position.pixels + _topInset;
    final bottom = position.pixels + position.viewportDimension;
    return _charAt((top + bottom) / 2);
  }

  /// 停在章首：列表在最顶上，而且没有待完成的定位。
  bool get isAtTop {
    if (_pendingFraction != null) return false;
    final position = _laidOutPosition;
    return position != null && position.pixels <= position.minScrollExtent + 1;
  }

  /// 让 [start, end) 这段正文出现在屏幕上，听书跟读用。
  ///
  /// 已经在正文区域里、离底边还有一段距离就不动；否则把它的开头滚到正文
  /// 区域上部，下面留出接着要读的内容，不用每读一段就滚一次。用户正在
  /// 拖动或者惯性滚动时不抢；自己的跟读动画还没停时，新的位置排在后面，
  /// 动画停了再处理。
  void reveal(int start, int end) => _reveal(start, end, allowEstimate: true);

  void _reveal(int start, int end, {required bool allowEstimate}) {
    if (_restoring.value) return;
    if (_revealAnimating) {
      _queuedReveal = (start: start, end: end);
      return;
    }
    final position = _laidOutPosition;
    if (position == null || position.isScrollingNotifier.value) return;
    final viewTop = position.pixels + _topInset;
    final viewBottom = position.pixels + position.viewportDimension;
    final contentHeight = viewBottom - viewTop;
    final top = _offsetOfChar(start);
    if (top == null) {
      // 目标还没布局。离得不远（刚读到缓存区外的下一段）就按估算平滑滚
      // 过去，到了再按真实位置校正一次；离得远（被拖到很远的地方）才按
      // 定位的办法藏起正文跳过去。
      final estimate = _estimateOffsetOfChar(start);
      if (allowEstimate &&
          estimate != null &&
          (estimate - viewTop).abs() <= position.viewportDimension * 2) {
        _queuedReveal ??= (start: start, end: end);
        _animateReveal(position, estimate - _topInset - contentHeight * 0.2);
      } else if (_textLength > 0) {
        jumpToFraction(start / _textLength);
      }
      return;
    }
    final bottom = _offsetOfChar(end) ?? top;
    if (top >= viewTop && bottom <= viewBottom - contentHeight * 0.15) return;
    _animateReveal(position, top - _topInset - contentHeight * 0.2);
  }

  bool _revealAnimating = false;
  ReaderTextRange? _queuedReveal;

  void _animateReveal(ScrollPosition position, double offset) {
    final target = offset
        .clamp(position.minScrollExtent, position.maxScrollExtent)
        .toDouble();
    if ((target - position.pixels).abs() < 1) {
      _queuedReveal = null;
      return;
    }
    _revealAnimating = true;
    animateTo(
      target,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
    ).whenComplete(() {
      _revealAnimating = false;
      final queued = _queuedReveal;
      _queuedReveal = null;
      if (queued != null && !_disposed) {
        _reveal(queued.start, queued.end, allowEstimate: false);
      }
    });
  }

  /// 让字符比例 [fraction] 处那一行停在视口顶部（留白下面）。
  ///
  /// 阅读器还没挂上时也可以调，挂上之后再跳。目标子项已经布局时直接跳；
  /// 否则先按已布局部分估算，逐帧收敛，期间 [restoring] 为 true。
  void jumpToFraction(double fraction) {
    final target = fraction.clamp(0.0, 1.0).toDouble();
    _request++;
    _pendingFraction = null;
    // 跳转打断了跟读动画，排着的跟读位置作废，别等动画收尾时又滚回去。
    _queuedReveal = null;
    if (target <= 0) {
      // 新挂上的列表本来就在开头，用不着估算。
      _setRestoring(false);
      final position = _laidOutPosition;
      if (position != null) jumpTo(position.minScrollExtent);
      return;
    }
    final landing = _landingFor(target);
    if (landing != null && landing.exact) {
      _setRestoring(false);
      _jumpWithinBounds(landing.offset);
      return;
    }
    _pendingFraction = target;
    _setRestoring(true);
    if (hasClients) unawaited(_run(_request));
  }

  /// 放弃还没完成的定位，正文照常显示。
  void cancelRestore() {
    _request++;
    _pendingFraction = null;
    _queuedReveal = null;
    _setRestoring(false);
  }

  @override
  void attach(ScrollPosition position) {
    super.attach(position);
    if (_pendingFraction != null) unawaited(_run(_request));
  }

  @override
  void dispose() {
    _disposed = true;
    _request++;
    removeListener(_handleScroll);
    _restoring.dispose();
    super.dispose();
  }

  Future<void> _run(int request) async {
    if (_runningRequest == request) return;
    _runningRequest = request;
    var settled = false;
    try {
      for (var frame = 0; frame < _maxRestoreFrames; frame++) {
        await SchedulerBinding.instance.endOfFrame;
        if (_disposed || request != _request) return;
        // 阅读器被卸下（切到翻页模式、换章）就不再跟，等下次请求。
        if (!hasClients) break;
        final fraction = _pendingFraction;
        if (fraction == null) break;
        final position = _laidOutPosition;
        if (position == null) continue;
        final landing = _landingFor(fraction);
        if (landing == null) continue;
        final offset = landing.offset
            .clamp(position.minScrollExtent, position.maxScrollExtent)
            .toDouble();
        if (landing.exact && (position.pixels - offset).abs() < 0.5) {
          settled = true;
          break;
        }
        jumpTo(offset);
      }
    } finally {
      if (_runningRequest == request) _runningRequest = null;
      if (!_disposed && request == _request) {
        _pendingFraction = null;
        _setRestoring(false);
        if (settled) {
          _report();
        } else {
          _scheduleReport();
        }
      }
    }
  }

  void _jumpWithinBounds(double offset) {
    final position = this.position;
    jumpTo(
      offset
          .clamp(position.minScrollExtent, position.maxScrollExtent)
          .toDouble(),
    );
  }

  /// 目标滚动偏移，以及它是不是按已布局子项算出来的准确值。
  ({double offset, bool exact})? _landingFor(double fraction) {
    final position = _laidOutPosition;
    if (position == null) return null;
    if (fraction >= 1) {
      // 读到章末就停在最底。最后一项布局出来之前 maxScrollExtent 是估计值。
      final sliver = _findSliver();
      final last = sliver?.lastChild;
      final exact = last != null && sliver!.indexOf(last) == _itemCount - 1;
      return (offset: position.maxScrollExtent, exact: exact);
    }
    final char = (fraction * _textLength).round();
    final exact = _offsetOfChar(char);
    if (exact != null) return (offset: exact - _topInset, exact: true);
    final estimate = _estimateOffsetOfChar(char);
    if (estimate == null) return null;
    return (offset: estimate - _topInset, exact: false);
  }

  ScrollPosition? get _laidOutPosition {
    if (!hasClients) return null;
    final position = this.position;
    if (!position.hasContentDimensions || !position.hasPixels) return null;
    return position;
  }

  int get _itemCount => _leadingItemCount + _ranges.length;

  ReaderTextRange _rangeOfItem(int index) {
    final chunkIndex = index - _leadingItemCount;
    if (chunkIndex < 0) return (start: 0, end: 0);
    if (chunkIndex >= _ranges.length) {
      return (start: _textLength, end: _textLength);
    }
    return _ranges[chunkIndex];
  }

  RenderSliverMultiBoxAdaptor? _findSliver() {
    if (!hasClients) return null;
    final position = this.position;
    final cached = _sliver;
    if (identical(_sliverOwner, position) &&
        cached != null &&
        cached.attached) {
      return cached.geometry == null ? null : cached;
    }
    RenderSliverMultiBoxAdaptor? found;
    void visit(RenderObject node) {
      if (found != null) return;
      if (node is RenderSliverMultiBoxAdaptor) {
        found = node;
        return;
      }
      node.visitChildren(visit);
    }

    final root = position.context.storageContext.findRenderObject();
    if (root != null) visit(root);
    _sliverOwner = position;
    _sliver = found;
    return found?.geometry == null ? null : found;
  }

  /// 已布局子项在滚动坐标里的上下沿。
  Iterable<({RenderBox child, int index, double top, double bottom})>
      _laidOutChildren(RenderSliverMultiBoxAdaptor sliver) sync* {
    final base = sliver.constraints.precedingScrollExtent;
    for (var child = sliver.firstChild;
        child != null;
        child = sliver.childAfter(child)) {
      final offset = sliver.childScrollOffset(child);
      if (offset == null || !child.hasSize) continue;
      final top = base + offset;
      yield (
        child: child,
        index: sliver.indexOf(child),
        top: top,
        bottom: top + child.size.height,
      );
    }
  }

  /// 滚动坐标 [y] 处的字符。只看已布局的子项，[y] 落在它们之外时取最近的边界。
  int? _charAt(double y) {
    final sliver = _findSliver();
    if (sliver == null) return null;
    final lastChild = sliver.lastChild;
    for (final item in _laidOutChildren(sliver)) {
      if (y >= item.bottom && item.child != lastChild) continue;
      final range = _rangeOfItem(item.index);
      if (y <= item.top || range.end <= range.start) return range.start;
      final t = ((y - item.top) / (item.bottom - item.top)).clamp(0.0, 1.0);
      // 加一点余量再取整：定位时按字算出偏移跳过去，读回来时浮点误差可能
      // 差一丁点，直接 floor 会变成前一个字，每开一次书往回漂一个字。
      return (range.start + t * (range.end - range.start) + 1e-6)
          .floor()
          .clamp(range.start, range.end)
          .toInt();
    }
    return null;
  }

  /// 字符 [char] 那一行的滚动坐标。它所在的子项还没布局时返回 null。
  double? _offsetOfChar(int char) {
    final sliver = _findSliver();
    if (sliver == null) return null;
    final firstChild = sliver.firstChild;
    // 字符正好落在某一项的末尾（段尾）：下一项布局了就是它的顶边，在下面
    // 的循环里给出；下一项还在缓存区外，那就是这一项的底边。
    double? endOfLastItem;
    for (final item in _laidOutChildren(sliver)) {
      // 章首连标题一起露出来。
      if (char <= 0 && item.index == 0) return item.top;
      final range = _rangeOfItem(item.index);
      if (range.end <= range.start) continue;
      if (char < range.start) {
        // 字符在这项前面：要么是段落之间的换行，要么前面还有没布局的项。
        final unknownBefore =
            item.child == firstChild && item.index > _leadingItemCount;
        return unknownBefore ? null : item.top;
      }
      final isLastItem = item.index == _itemCount - 1;
      if (char < range.end || (isLastItem && char == range.end)) {
        final t = (char - range.start) / (range.end - range.start);
        return item.top + t * (item.bottom - item.top);
      }
      endOfLastItem = char == range.end ? item.bottom : null;
    }
    return endOfLastItem;
  }

  /// 目标子项没布局时，按已布局部分的「每字高度」往前或往后外推。
  double? _estimateOffsetOfChar(int char) {
    final sliver = _findSliver();
    if (sliver == null) return null;
    final children = _laidOutChildren(sliver).toList(growable: false);
    if (children.isEmpty) return null;
    final first = children.first;
    final last = children.last;
    final firstChar = _rangeOfItem(first.index).start;
    final lastChar = _rangeOfItem(last.index).end;
    final chars = lastChar - firstChar;
    if (chars <= 0) return char < firstChar ? first.top : last.bottom;
    final pixelsPerChar = (last.bottom - first.top) / chars;
    if (char >= lastChar) {
      return last.bottom + (char - lastChar) * pixelsPerChar;
    }
    return first.top - (firstChar - char) * pixelsPerChar;
  }

  void _handleScroll() {
    if (_restoring.value) return;
    _scheduleReport();
  }

  void _scheduleReport() {
    if (_reportScheduled || onReadingPositionChanged == null) return;
    _reportScheduled = true;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _reportScheduled = false;
      _report();
    });
  }

  void _report() {
    if (_disposed || _restoring.value) return;
    final fraction = readingFraction;
    if (fraction != null) onReadingPositionChanged?.call(fraction);
  }

  void _setRestoring(bool value) {
    if (_disposed || _restoring.value == value) return;
    _restoring.value = value;
  }
}

/// [controller] 定位期间把正文藏起来、也不接手势，定位完再一次性露出来。
/// 只重建这一层，列表本身不跟着重建。
class HiddenWhileRestoring extends StatelessWidget {
  const HiddenWhileRestoring({
    super.key,
    required this.controller,
    required this.child,
  });

  final ReaderScrollController controller;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: controller.restoring,
      builder: (context, restoring, child) => IgnorePointer(
        ignoring: restoring,
        child: Opacity(opacity: restoring ? 0 : 1, child: child),
      ),
      child: child,
    );
  }
}
