import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../providers/ai/ai_usage.dart';

enum TokenChartStyle { line, bar }

/// 最近若干天的 token 用量：折线（每天总量）或柱状（输入 / 输出堆叠）。
///
/// 自己用 CustomPainter 画，不引图表库：就两种图、一组数据，库的体积和
/// API 都用不上。
class TokenUsageChart extends StatelessWidget {
  final List<AiUsageDay> days;
  final TokenChartStyle style;

  const TokenUsageChart({
    super.key,
    required this.days,
    required this.style,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return CustomPaint(
      painter: _TokenUsagePainter(
        days: days,
        style: style,
        promptColor: scheme.primary,
        // 主题的强调色都是木色系，secondary / tertiary 和 primary 挨在一起
        // 分不开，输出用淡一档的同色。
        completionColor: scheme.primary.withValues(alpha: 0.4),
        gridColor: scheme.outlineVariant.withValues(alpha: 0.6),
        labelStyle: theme.textTheme.labelSmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ) ??
            TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
        textDirection: Directionality.of(context),
      ),
      child: const SizedBox(width: double.infinity, height: 180),
    );
  }
}

class _TokenUsagePainter extends CustomPainter {
  final List<AiUsageDay> days;
  final TokenChartStyle style;
  final Color promptColor;
  final Color completionColor;
  final Color gridColor;
  final TextStyle labelStyle;
  final TextDirection textDirection;

  static const _leftInset = 44.0;
  static const _bottomInset = 22.0;
  static const _topInset = 8.0;

  const _TokenUsagePainter({
    required this.days,
    required this.style,
    required this.promptColor,
    required this.completionColor,
    required this.gridColor,
    required this.labelStyle,
    required this.textDirection,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (days.isEmpty) return;
    final plot = Rect.fromLTRB(
      _leftInset,
      _topInset,
      size.width,
      size.height - _bottomInset,
    );
    final maxValue = days.fold(0, (m, d) => math.max(m, d.usage.totalTokens));
    final ceiling = _niceCeiling(maxValue);

    _paintGrid(canvas, plot, ceiling);
    if (style == TokenChartStyle.bar) {
      _paintBars(canvas, plot, ceiling);
    } else {
      _paintLine(canvas, plot, ceiling);
    }
    _paintDateLabels(canvas, plot);
  }

  /// 取一个「好看」的上限：1 / 1.2 / 1.5 / 2 / 2.5 / 3 / 4 / 5 / 6 / 8 × 10^n，
  /// 至少 100。步子细一点，最高的柱子才不会只到图的一半。
  static int _niceCeiling(int maxValue) {
    if (maxValue <= 100) return 100;
    final magnitude = math.pow(10, (math.log(maxValue) / math.ln10).floor());
    for (final step in const [1, 1.2, 1.5, 2, 2.5, 3, 4, 5, 6, 8, 10]) {
      final candidate = (step * magnitude).round();
      if (candidate >= maxValue) return candidate;
    }
    return maxValue;
  }

  void _paintGrid(Canvas canvas, Rect plot, int ceiling) {
    final paint = Paint()
      ..color = gridColor
      ..strokeWidth = 1;
    for (var i = 0; i <= 2; i++) {
      final value = ceiling * i ~/ 2;
      final y = plot.bottom - plot.height * i / 2;
      canvas.drawLine(Offset(plot.left, y), Offset(plot.right, y), paint);
      _label(
        canvas,
        formatTokenCount(value),
        Offset(plot.left - 6, y),
        alignRight: true,
      );
    }
  }

  void _paintBars(Canvas canvas, Rect plot, int ceiling) {
    final slot = plot.width / days.length;
    final barWidth = math.max(2.0, math.min(slot * 0.6, 22.0));
    final promptPaint = Paint()..color = promptColor;
    final completionPaint = Paint()..color = completionColor;
    for (var i = 0; i < days.length; i++) {
      final usage = days[i].usage;
      if (usage.totalTokens == 0) continue;
      final x = plot.left + slot * (i + 0.5) - barWidth / 2;
      final promptHeight = plot.height * usage.promptTokens / ceiling;
      final completionHeight = plot.height * usage.completionTokens / ceiling;
      final promptTop = plot.bottom - promptHeight;
      canvas.drawRect(
        Rect.fromLTWH(x, promptTop, barWidth, promptHeight),
        promptPaint,
      );
      canvas.drawRRect(
        RRect.fromRectAndCorners(
          Rect.fromLTWH(
            x,
            promptTop - completionHeight,
            barWidth,
            completionHeight,
          ),
          topLeft: const Radius.circular(3),
          topRight: const Radius.circular(3),
        ),
        completionPaint,
      );
    }
  }

  void _paintLine(Canvas canvas, Rect plot, int ceiling) {
    final slot = plot.width / days.length;
    final points = <Offset>[
      for (var i = 0; i < days.length; i++)
        Offset(
          plot.left + slot * (i + 0.5),
          plot.bottom - plot.height * days[i].usage.totalTokens / ceiling,
        ),
    ];
    final line = Path()..moveTo(points.first.dx, points.first.dy);
    for (final point in points.skip(1)) {
      line.lineTo(point.dx, point.dy);
    }
    final area = Path.from(line)
      ..lineTo(points.last.dx, plot.bottom)
      ..lineTo(points.first.dx, plot.bottom)
      ..close();
    canvas.drawPath(area, Paint()..color = promptColor.withValues(alpha: 0.12));
    canvas.drawPath(
      line,
      Paint()
        ..color = promptColor
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke
        ..strokeJoin = StrokeJoin.round,
    );
    final dot = Paint()..color = promptColor;
    for (var i = 0; i < points.length; i++) {
      if (days[i].usage.totalTokens == 0 && days.length > 7) continue;
      canvas.drawCircle(points[i], 3, dot);
    }
  }

  void _paintDateLabels(Canvas canvas, Rect plot) {
    final slot = plot.width / days.length;
    // 首、中、末三个日期，多了挤成一团。
    final indexes = days.length <= 7
        ? List.generate(days.length, (i) => i)
        : [0, days.length ~/ 2, days.length - 1];
    for (final i in indexes) {
      final date = days[i].date;
      _label(
        canvas,
        '${date.month}/${date.day}',
        Offset(plot.left + slot * (i + 0.5), plot.bottom + 4),
        centered: true,
        below: true,
      );
    }
  }

  void _label(
    Canvas canvas,
    String text,
    Offset anchor, {
    bool alignRight = false,
    bool centered = false,
    bool below = false,
  }) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: labelStyle),
      textDirection: textDirection,
    )..layout();
    final dx = alignRight
        ? anchor.dx - painter.width
        : centered
            ? anchor.dx - painter.width / 2
            : anchor.dx;
    final dy = below ? anchor.dy : anchor.dy - painter.height / 2;
    painter.paint(canvas, Offset(dx, dy));
  }

  @override
  bool shouldRepaint(_TokenUsagePainter old) =>
      old.days != days ||
      old.style != style ||
      old.promptColor != promptColor ||
      old.completionColor != completionColor ||
      old.gridColor != gridColor ||
      old.labelStyle != labelStyle;
}
