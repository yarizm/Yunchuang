import 'package:flutter/material.dart';

import '../theme/app_motion.dart';

/// 底部 Tab 的容器，替换 go_router 默认的 IndexedStack。
///
/// 界面动画开着时切 Tab 走「淡出 → 淡入」（Material 的 fade through）：旧页
/// 在前 35% 的时间里淡出，新页再稍稍升起、淡入。两页之间只隔着 MainShell
/// 那层全局背景，不会闪出别的颜色。关着时和 IndexedStack 一样一下子换过去。
/// 只平移不缩放：缩放会让整页的字每帧重新光栅化，见 GlassPageRoute。
///
/// 和 IndexedStack 一样，每个分支一直挂在树上（状态、滚动位置都留着），
/// 看不见的用 Offstage 不画、TickerMode 停掉动画。开关两边部件结构相同，
/// 见 [AppMotion]。
class AnimatedBranchContainer extends StatefulWidget {
  final int currentIndex;
  final List<Widget> children;

  const AnimatedBranchContainer({
    super.key,
    required this.currentIndex,
    required this.children,
  });

  @override
  State<AnimatedBranchContainer> createState() =>
      _AnimatedBranchContainerState();
}

class _AnimatedBranchContainerState extends State<AnimatedBranchContainer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: AppMotion.tabSwitch,
    value: 1,
  )..addStatusListener(_handleStatus);

  late final Animation<double> _incomingOpacity = _controller.drive(
    CurveTween(curve: const Interval(0.3, 1, curve: Curves.easeOut)),
  );
  late final Animation<Offset> _incomingSlide = _controller.drive(
    Tween<Offset>(begin: const Offset(0, 0.02), end: Offset.zero).chain(
      CurveTween(curve: const Interval(0.3, 1, curve: Curves.easeOutCubic)),
    ),
  );
  late final Animation<double> _outgoingOpacity = _controller.drive(
    Tween<double>(begin: 1, end: 0).chain(
      CurveTween(curve: const Interval(0, 0.35, curve: Curves.easeIn)),
    ),
  );

  static const _still = AlwaysStoppedAnimation<Offset>(Offset.zero);

  /// 正在淡出的那一页，动画结束后清掉。
  int? _previousIndex;
  bool _enhanced = false;

  void _handleStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed && _previousIndex != null) {
      setState(() => _previousIndex = null);
    }
  }

  @override
  void didUpdateWidget(AnimatedBranchContainer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentIndex == widget.currentIndex) return;
    if (_enhanced) {
      _previousIndex = oldWidget.currentIndex;
      _controller.forward(from: 0);
    } else {
      _previousIndex = null;
      _controller.value = 1;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _enhanced = AppMotion.of(context);
    return Stack(
      fit: StackFit.expand,
      children: [
        for (var index = 0; index < widget.children.length; index++)
          _buildBranch(index),
      ],
    );
  }

  Widget _buildBranch(int index) {
    final current = index == widget.currentIndex;
    final previous = index == _previousIndex;
    return Offstage(
      offstage: !current && !previous,
      child: TickerMode(
        enabled: current,
        child: IgnorePointer(
          ignoring: !current,
          child: FadeTransition(
            opacity: current
                ? _incomingOpacity
                : previous
                    ? _outgoingOpacity
                    : kAlwaysCompleteAnimation,
            child: SlideTransition(
              position: current ? _incomingSlide : _still,
              child: widget.children[index],
            ),
          ),
        ),
      ),
    );
  }
}
