import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../theme/app_motion.dart';

/// 按下时轻轻缩小，松手回弹。界面动画关着时不缩。
///
/// 用 Listener 而不是手势识别器：不进手势竞技场，里面的 InkWell、长按多选、
/// 外面的滚动都照常工作。手指移动超过 [kTouchSlop] 就当作在滚动，立刻弹回，
/// 免得划过书架时卡片一路跟着缩。鼠标只认左键。
class PressScale extends StatefulWidget {
  final Widget child;

  /// 按住时的缩放比例。
  final double scale;

  const PressScale({super.key, required this.child, this.scale = 0.96});

  @override
  State<PressScale> createState() => _PressScaleState();
}

class _PressScaleState extends State<PressScale> {
  int? _pointer;
  Offset? _downPosition;

  void _handleDown(PointerDownEvent event) {
    if (_pointer != null) return;
    if (event.kind == PointerDeviceKind.mouse &&
        event.buttons != kPrimaryMouseButton) {
      return;
    }
    setState(() {
      _pointer = event.pointer;
      _downPosition = event.position;
    });
  }

  void _handleMove(PointerMoveEvent event) {
    final origin = _downPosition;
    if (event.pointer != _pointer || origin == null) return;
    if ((event.position - origin).distance > kTouchSlop) _release();
  }

  void _handleEnd(PointerEvent event) {
    if (event.pointer == _pointer) _release();
  }

  void _release() {
    setState(() {
      _pointer = null;
      _downPosition = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final enabled = AppMotion.of(context);
    if (!enabled) {
      // 按住时关了动画，松手事件就收不到了；不清掉的话再打开时一直当作按着。
      _pointer = null;
      _downPosition = null;
    }
    final pressed = enabled && _pointer != null;
    return Listener(
      onPointerDown: enabled ? _handleDown : null,
      onPointerMove: enabled ? _handleMove : null,
      onPointerUp: enabled ? _handleEnd : null,
      onPointerCancel: enabled ? _handleEnd : null,
      child: AnimatedScale(
        scale: pressed ? widget.scale : 1,
        duration: pressed ? AppMotion.press : AppMotion.release,
        curve: pressed ? Curves.easeOut : Curves.easeOutBack,
        child: widget.child,
      ),
    );
  }
}
