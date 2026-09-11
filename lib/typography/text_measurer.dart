import 'package:flutter/painting.dart';

import 'line_box.dart';

/// 向排版内核提供「给定文本与样式在给定宽度下排成哪些行」的能力。
///
/// 内核只依赖这个抽象，不关心背后是引擎测量还是字体表解析。将来若要
/// 把排版搬进后台 isolate，只需换掉实现，`paginator.dart` 一行都不用动。
abstract class TextMeasurer {
  List<LineBox> layout({
    required String text,
    required TextStyle style,
    required double maxWidth,
    required TextDirection direction,
    StrutStyle? strutStyle,
  });
}

/// 基于 `TextPainter` 的度量实现，复用 Flutter 自带的 ICU 断行。
///
/// 行字符范围的取法已实测验证：按累计高度取每行竖直中点，
/// `getPositionForOffset` 定位后再用 `getLineBoundary` 取该行边界。
/// 行高之和与 `TextPainter.height` 精确相等。
class FlutterTextMeasurer implements TextMeasurer {
  const FlutterTextMeasurer();

  @override
  List<LineBox> layout({
    required String text,
    required TextStyle style,
    required double maxWidth,
    required TextDirection direction,
    StrutStyle? strutStyle,
  }) {
    if (text.isEmpty) return const [];

    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: direction,
      strutStyle: strutStyle,
    )..layout(maxWidth: maxWidth);

    try {
      final metrics = painter.computeLineMetrics();
      final boxes = <LineBox>[];
      var top = 0.0;

      for (final metric in metrics) {
        final position =
            painter.getPositionForOffset(Offset(0, top + metric.height / 2));
        final range = painter.getLineBoundary(position);
        top += metric.height;

        // 极端窄宽度下 getLineBoundary 可能返回空范围，跳过以免产生
        // 零长度行盒污染分页。
        if (range.start < 0 || range.end < range.start) continue;

        boxes.add(LineBox(
          start: range.start,
          end: range.end,
          height: metric.height,
          hardBreak: metric.hardBreak,
        ));
      }

      return boxes;
    } finally {
      painter.dispose();
    }
  }
}
