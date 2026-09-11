import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yunchuang/typography/typesetter.dart';

/// 完全确定的度量替身：每行固定字符数与行高，不依赖任何字体或引擎。
///
/// 它的存在本身就是验收标准之一——如果内核真的只依赖 [TextMeasurer]
/// 抽象，那么换成这个实现后分页行为应当照常工作。
class FakeTextMeasurer implements TextMeasurer {
  final int charsPerLine;
  final double lineHeight;

  const FakeTextMeasurer({this.charsPerLine = 10, this.lineHeight = 10});

  @override
  List<LineBox> layout({
    required String text,
    required TextStyle style,
    required double maxWidth,
    required TextDirection direction,
    StrutStyle? strutStyle,
  }) {
    if (text.isEmpty) return const [];

    final boxes = <LineBox>[];
    var cursor = 0;

    for (final segment in text.split('\n')) {
      if (segment.isEmpty) {
        boxes.add(LineBox(
          start: cursor,
          end: cursor,
          height: lineHeight,
          hardBreak: true,
        ));
        cursor += 1; // 跳过换行符
        continue;
      }

      for (var i = 0; i < segment.length; i += charsPerLine) {
        final end = (i + charsPerLine).clamp(0, segment.length);
        final isLastOfSegment = end == segment.length;
        boxes.add(LineBox(
          start: cursor + i,
          end: cursor + end,
          height: lineHeight,
          hardBreak: isLastOfSegment,
        ));
      }
      cursor += segment.length + 1; // 段落长度 + 换行符
    }

    return boxes;
  }
}

void main() {
  const style = TextStyle(fontSize: 16);
  const fake = FakeTextMeasurer();

  List<PageBox> run(
    String text, {
    double pageHeight = 50,
    double? firstPageHeight,
    double paragraphSpacing = 0,
  }) {
    return const Typesetter(measurer: fake).typeset(
      text: text,
      style: style,
      maxWidth: 100,
      pageHeight: pageHeight,
      firstPageHeight: firstPageHeight,
      paragraphSpacing: paragraphSpacing,
      direction: TextDirection.ltr,
    );
  }

  test('空文本产出空页序列', () {
    expect(run(''), isEmpty);
  });

  test('假度量器下的分页与真实度量器走同一条分页路径', () {
    // 30 个字符 → 3 行 → 每页 5 行容量下只需一页
    final pages = run('a' * 30);

    expect(pages, hasLength(1));
    expect(pages.single.lineCount, 3);
    expect(pages.single.startOffset, 0);
    expect(pages.single.endOffset, 30);
  });

  test('超出页容量时按行盒切页', () {
    // 80 字符 → 8 行；每页 5 行 → 2 页
    final pages = run('a' * 80);

    expect(pages, hasLength(2));
    expect(pages[0].lineCount, 5);
    expect(pages[1].lineCount, 3);
    expect(pages[1].startOffset, 50);
  });

  test('首页让出标题块后容量变小', () {
    final pages = run('a' * 80, firstPageHeight: 20);

    expect(pages[0].lineCount, 2, reason: '首页只剩 2 行');
    expect(pages[1].lineCount, 5);
  });

  test('跨段落时计入段间距，超出容量才换页', () {
    // 两段各 10 字符 → 各 1 行（行高 10）；容量 50。
    // 10 + 35 + 10 = 55 > 50，第二段被挤到下一页。
    final pages = run("${'a' * 10}\n${'b' * 10}", paragraphSpacing: 35);

    expect(pages, hasLength(2));
    expect(pages[0].lineCount, 1);
    expect(pages[1].lineCount, 1);
  });

  test('段间距使内容正好填满时不换页', () {
    // 10 + 30 + 10 = 50，与容量相等，不应溢出
    final pages = run("${'a' * 10}\n${'b' * 10}", paragraphSpacing: 30);

    expect(pages, hasLength(1));
    expect(pages.single.lineCount, 2);
  });

  test('换行符不落入任何页的字符范围', () {
    const text = 'aaaa\nbbbb';
    final pages = run(text);

    expect(pages, hasLength(1));
    final lines = pages.single.lines;
    expect(text.substring(lines[0].start, lines[0].end), 'aaaa');
    expect(text.substring(lines[1].start, lines[1].end), 'bbbb');
  });

  test('所有页的行拼接后覆盖全部行盒，不丢不重', () {
    final text = List.generate(6, (i) => '$i' * 25).join('\n');
    final expected = fake.layout(
      text: text,
      style: style,
      maxWidth: 100,
      direction: TextDirection.ltr,
    );
    final actual = run(text, pageHeight: 40).expand((p) => p.lines).toList();

    expect(actual, expected);
  });
}
