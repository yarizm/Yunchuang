/// 排版内核的基本单位。
///
/// 本文件刻意不依赖 Flutter：`paginator.dart` 只依赖这里，因此分页逻辑
/// 可以在没有 Flutter binding 的普通 `test()` 中运行。
library;

/// 正文经排版后的一行，承载该行覆盖的原文字符范围与占用高度。
class LineBox {
  /// 原文字符起始偏移，含。
  final int start;

  /// 原文字符结束偏移，不含。
  final int end;

  /// 该行占用的高度。
  final double height;

  /// 该行是否以硬换行（原文中的 `\n`）结束。
  ///
  /// 换行符本身不属于任何行，因此相邻行盒的 [end] 与 [start] 之间
  /// 可能存在间隙，不能假定连续。
  final bool hardBreak;

  const LineBox({
    required this.start,
    required this.end,
    required this.height,
    this.hardBreak = false,
  });

  int get length => end - start;

  @override
  bool operator ==(Object other) =>
      other is LineBox &&
      other.start == start &&
      other.end == end &&
      other.height == height &&
      other.hardBreak == hardBreak;

  @override
  int get hashCode => Object.hash(start, end, height, hardBreak);

  @override
  String toString() =>
      'LineBox($start,$end h=$height${hardBreak ? ' hard' : ''})';
}

/// 一页所容纳的连续行盒集合。
///
/// 由行盒聚合而成，不独立参与排版计算。
class PageBox {
  final List<LineBox> lines;

  PageBox(List<LineBox> lines)
      : assert(lines.isNotEmpty, '页盒不能为空'),
        lines = List.unmodifiable(lines);

  /// 本页起始的原文偏移，等价于旧实现中的「分页切分点」。
  int get startOffset => lines.first.start;

  /// 本页结束的原文偏移，不含。
  int get endOffset => lines.last.end;

  /// 本页所有行的高度之和，不含段间距。
  double get height => lines.fold(0.0, (sum, line) => sum + line.height);

  int get lineCount => lines.length;

  @override
  String toString() =>
      'PageBox(${lines.length} lines, [$startOffset,$endOffset))';
}
