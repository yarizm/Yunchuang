import 'package:flutter/material.dart';

import '../widgets/app_background.dart';
import 'app_motion.dart';

/// 整页路由，页面下面铺着用户选的全局背景。
///
/// 每个页面自己画一层 [PreferredAppBackground]，所以路由是 opaque 的：动画
/// 结束后下面那页不再参与绘制，它上面的动画（书架的流动渐变）也跟着停
/// （Overlay 会给遮住的页面关掉 TickerMode）。以前这里铺的是一层 96% 不透明的
/// surface、路由不 opaque——既盖掉了全局背景（「背景只有书架有」），又让
/// 下面那页一直在画。
///
/// 转场：界面动画关着时淡入淡出；开着时从下方升上来淡入，退出时沉下去淡出；
/// 传了 [expandFrom] 就从那块区域张开（打开书时从书封张开）。
class GlassPageRoute<T> extends PageRoute<T> {
  final WidgetBuilder builder;
  final Duration fadeDuration;

  /// 页面自己画背景时传 true，路由就不再铺一层。阅读器用：它的背景要画在
  /// 纸张主题里，底色才是纸张色而不是全局主题的 surface。
  final bool paintsOwnBackground;

  /// 从屏幕上这块区域展开（全局坐标，路由要推在根 Navigator 上）。只在界面
  /// 动画开着时生效。
  final Rect? expandFrom;

  /// 展开时先张开的那张底的颜色，应当和页面的底色一致（阅读器传纸张色）。
  /// 不传就用当前主题的 surface。
  final Color? expandColor;

  GlassPageRoute({
    required this.builder,
    super.settings,
    this.fadeDuration = const Duration(milliseconds: 300),
    this.paintsOwnBackground = false,
    this.expandFrom,
    this.expandColor,
  });

  /// 推入时定下来：界面动画开没开。之后用户拨开关，这一页的转场结构也不变，
  /// 页面不会被卸载重建，见 [AppMotion]。
  bool _enhanced = false;

  /// 展开动画播完过。没播完就退出（刚点开就返回）时原路缩回卡片；播完之后
  /// 书架多半已经重排（刚读的书排到前面），卡片早不在原处，改成原地缩小淡出。
  bool _expanded = false;

  @override
  void install() {
    final context = navigator?.context;
    _enhanced = context != null && AppMotion.peek(context);
    super.install();
    // 听 controller 而不是 animation：推入后第一帧 Navigator 会把新页面放在
    // 屏幕外（offstage）给 Hero 量尺寸，这时 animation 代理临时指向一个
    // 「已完成」的动画，会报一次假的 completed。
    controller?.addStatusListener(_trackExpanded);
  }

  void _trackExpanded(AnimationStatus status) {
    if (status == AnimationStatus.completed) _expanded = true;
  }

  @override
  bool get opaque => true;

  @override
  bool get maintainState => true;

  @override
  Color? get barrierColor => null;

  @override
  String? get barrierLabel => null;

  @override
  Duration get transitionDuration {
    if (!_enhanced) return fadeDuration;
    return expandFrom != null ? AppMotion.bookOpen : AppMotion.pageEnter;
  }

  @override
  Duration get reverseTransitionDuration =>
      _enhanced ? AppMotion.pageExit : fadeDuration;

  @override
  Widget buildPage(BuildContext context, Animation<double> animation,
      Animation<double> secondaryAnimation) {
    final page = builder(context);
    if (paintsOwnBackground) return page;
    return PreferredAppBackground(child: page);
  }

  @override
  Widget buildTransitions(BuildContext context, Animation<double> animation,
      Animation<double> secondaryAnimation, Widget child) {
    return AnimatedBuilder(
      animation: animation,
      child: child,
      builder: (context, child) => LayoutBuilder(
        builder: (context, constraints) {
          final frame = _frameAt(animation, constraints.biggest);
          return Stack(
            fit: StackFit.expand,
            children: [
              Opacity(
                opacity: frame.opacity,
                child: ClipRRect(
                  clipper: _FrameClipper(frame.clip),
                  // 硬边裁剪，圆角由上面那张纸画，见 _frameAt。
                  clipBehavior: frame.clip == null ? Clip.none : Clip.hardEdge,
                  child: Transform(transform: frame.transform, child: child),
                ),
              ),
              CustomPaint(
                painter: _SheetPainter(
                  frame.sheet,
                  expandColor ?? Theme.of(context).colorScheme.surface,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  /// 转场某一帧的样子。各种情况都落到同一套部件上（Opacity → ClipRRect →
  /// Transform 包着页面，上面盖一张「纸」），只是参数不同：展开途中退出时
  /// 换算法，结构不变，页面不会被重建。
  ///
  /// 打开书那几帧的取舍都是 profile 版里量出来的：
  /// - **不缩放页面**：缩放时整页的字每帧按新大小重新光栅化，一帧 30～75ms。
  /// - **不给页面做淡入**：页面放进透明度图层就得整页离屏重画，一帧 30～40ms。
  ///   改成页面一直不透明、画在纸的下面，纸张开后自己变透明把正文露出来——纸
  ///   和页面底色相同，看起来就是正文淡入。正文在纸底下早早画过，字形也就
  ///   提前光栅化好了。
  /// - **页面只做硬边裁剪**：抗锯齿的圆角裁剪同样贵，圆角由纸自己画。
  _TransitionFrame _frameAt(Animation<double> animation, Size size) {
    final t = animation.value;
    if (!_enhanced) return _TransitionFrame(opacity: t);
    if (t >= 1) return const _TransitionFrame(opacity: 1);

    final reversing = animation.status == AnimationStatus.reverse;
    final origin = expandFrom;
    if (origin != null && (!reversing || !_expanded)) {
      // 打开书：一张纸从书封的位置张开到全屏，正文随后在纸上淡入。
      final eased = Curves.fastOutSlowIn.transform(t);
      final rect = Rect.lerp(origin, Offset.zero & size, eased)!;
      // 书架卡片是 8 像素圆角。
      final shape = RRect.fromRectAndRadius(
        rect,
        Radius.circular(8 * (1 - eased)),
      );
      // 纸先在卡片上淡出来，盖严之后页面才开始画（不然纸半透明时卡片
      // 位置会透出一块正文）；张开到后半段纸再慢慢变透明，露出正文。
      final sheetIn =
          const Interval(0, _sheetCovers, curve: Curves.easeOut).transform(t);
      final sheetOut =
          const Interval(0.55, 0.95, curve: Curves.easeIn).transform(t);
      return _TransitionFrame(
        opacity: t < _sheetCovers ? 0 : 1,
        clip: RRect.fromRectAndRadius(rect, Radius.zero),
        sheet: (
          shape: shape,
          opacity: sheetIn * (1 - sheetOut),
          elevation: 10 * (1 - eased),
        ),
      );
    }

    // 普通页面：从下方升上来淡入，退出时沉下去淡出。
    final eased = Curves.easeOutCubic.transform(t);
    return _TransitionFrame(
      opacity: reversing
          ? const Interval(0.1, 1, curve: Curves.easeOut).transform(t)
          // 淡入快一点：两页的字叠在一起的时间短，看着利落。
          : const Interval(0, 0.45, curve: Curves.easeOut).transform(t),
      transform: Matrix4.translationValues(0, _riseDistance * (1 - eased), 0),
    );
  }

  /// 普通页面推入时从多低的地方升上来。
  static const _riseDistance = 28.0;

  /// 打开书时纸用多少时间（占整段的比例）淡出来盖严卡片。
  static const _sheetCovers = 0.1;
}

typedef _Sheet = ({RRect shape, double opacity, double elevation});

class _TransitionFrame {
  final double opacity;
  final Matrix4? _transform;

  /// 裁剪区域（页面坐标，硬边）。null 表示不裁。
  final RRect? clip;

  /// 打开书时盖在页面上、从卡片张开的那张纸。null 表示不画。
  final _Sheet? sheet;

  const _TransitionFrame({
    required this.opacity,
    Matrix4? transform,
    this.clip,
    this.sheet,
  }) : _transform = transform;

  Matrix4 get transform => _transform ?? Matrix4.identity();
}

class _FrameClipper extends CustomClipper<RRect> {
  final RRect? clip;

  const _FrameClipper(this.clip);

  @override
  RRect getClip(Size size) =>
      clip ??
      RRect.fromRectAndRadius(
        Offset.zero & size,
        Radius.zero,
      );

  @override
  bool shouldReclip(_FrameClipper oldClipper) => oldClipper.clip != clip;
}

class _SheetPainter extends CustomPainter {
  final _Sheet? sheet;
  final Color color;

  const _SheetPainter(this.sheet, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final sheet = this.sheet;
    if (sheet == null || sheet.opacity <= 0) return;
    final path = Path()..addRRect(sheet.shape);
    // 纸和书架的底色往往很接近，靠一圈阴影看出它在张开。
    if (sheet.elevation > 0.5) {
      canvas.drawShadow(
        path,
        Colors.black.withValues(alpha: 0.5 * sheet.opacity),
        sheet.elevation,
        false,
      );
    }
    canvas.drawPath(
      path,
      Paint()..color = color.withValues(alpha: color.a * sheet.opacity),
    );
  }

  @override
  bool hitTest(Offset position) => false;

  @override
  bool shouldRepaint(_SheetPainter oldDelegate) =>
      oldDelegate.sheet != sheet || oldDelegate.color != color;
}
