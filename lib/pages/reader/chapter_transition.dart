import 'package:flutter/material.dart';

import '../../theme/app_motion.dart';

/// 翻页模式换章的过渡：旧章先淡出，新章再顺着翻页方向滑进来、淡入。
///
/// 页面不铺底色（纸张色由阅读器外层画），两章要是同时以较高的不透明度叠着
/// 画，字会糊在一起——之前就是这样：旧章停在 0.9、新章从 0.96 起，换章那
/// 0.4 秒两层字叠在一起。现在旧章在前 40% 的时间里淡出，新章从 35% 才开始
/// 淡入，中间只有很短一段两边都接近透明。新章刚挂上时还在分页、显示的是
/// 加载圈，晚一点淡入，短章节分完页之前就不会露出来。
///
/// 界面动画关着时时长为 0，直接换过去。开关两边部件结构相同，见 [AppMotion]。
class ChapterTransition extends StatelessWidget {
  /// 每章一个 key，key 变了就是换章。
  final Key chapterKey;

  /// 1 表示往后翻（新章从右边进来），-1 往前翻。
  final double direction;

  final Widget child;

  const ChapterTransition({
    super.key,
    required this.chapterKey,
    required this.direction,
    required this.child,
  });

  static const _enter = Interval(0.35, 1, curve: Curves.easeOutCubic);

  /// 旧章的动画是从 1 倒着走到 0，[Interval] 取 0.6～1 就是前 40% 的时间。
  static const _exit = Interval(0.6, 1, curve: Curves.easeIn);

  @override
  Widget build(BuildContext context) {
    final duration =
        AppMotion.of(context) ? AppMotion.chapterSwitch : Duration.zero;
    return ClipRect(
      child: AnimatedSwitcher(
        duration: duration,
        reverseDuration: duration,
        layoutBuilder: (currentChild, previousChildren) {
          return Stack(
            fit: StackFit.expand,
            children: [
              ...previousChildren,
              if (currentChild != null) currentChild,
            ],
          );
        },
        transitionBuilder: (child, animation) {
          final incoming = child.key == chapterKey;
          final curve = CurveTween(curve: incoming ? _enter : _exit);
          final slide = Tween<Offset>(
            begin: incoming
                ? Offset(direction * 0.06, 0)
                : Offset(-direction * 0.04, 0),
            end: Offset.zero,
          ).chain(curve);
          return FadeTransition(
            opacity: animation.drive(curve),
            child: SlideTransition(
              position: animation.drive(slide),
              child: child,
            ),
          );
        },
        child: KeyedSubtree(key: chapterKey, child: child),
      ),
    );
  }
}
