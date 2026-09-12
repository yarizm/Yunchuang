import 'package:flutter/material.dart';

import '../widgets/app_background.dart';

/// 淡入淡出的整页路由，页面下面铺着用户选的全局背景。
///
/// 每个页面自己画一层 [PreferredAppBackground]，所以路由是 opaque 的：动画
/// 结束后下面那页不再参与绘制，它上面的动画（书架的流动渐变）也跟着停
/// （Overlay 会给遮住的页面关掉 TickerMode）。以前这里铺的是一层 96% 不透明的
/// surface、路由不 opaque——既盖掉了全局背景（「背景只有书架有」），又让
/// 下面那页一直在画。
class GlassPageRoute<T> extends PageRoute<T> {
  final WidgetBuilder builder;
  final Duration fadeDuration;

  /// 页面自己画背景时传 true，路由就不再铺一层。阅读器用：它的背景要画在
  /// 纸张主题里，底色才是纸张色而不是全局主题的 surface。
  final bool paintsOwnBackground;

  GlassPageRoute({
    required this.builder,
    super.settings,
    this.fadeDuration = const Duration(milliseconds: 300),
    this.paintsOwnBackground = false,
  });

  @override
  bool get opaque => true;

  @override
  bool get maintainState => true;

  @override
  Color? get barrierColor => null;

  @override
  String? get barrierLabel => null;

  @override
  Duration get transitionDuration => fadeDuration;

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
    return FadeTransition(
      opacity: animation,
      child: child,
    );
  }
}
