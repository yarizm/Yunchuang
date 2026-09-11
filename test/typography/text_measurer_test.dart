import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yunchuang/typography/line_box.dart';
import 'package:yunchuang/typography/text_measurer.dart';

/// 这些测试锁住排版内核对 Flutter 文本栈的全部假设。
/// 若某天 Flutter 改了断行或行度量行为，应当在这里先红。
void main() {
  const measurer = FlutterTextMeasurer();
  const style = TextStyle(fontSize: 16, height: 1.6);

  List<LineBox> layout(String text, {double width = 300}) => measurer.layout(
        text: text,
        style: style,
        maxWidth: width,
        direction: TextDirection.ltr,
      );

  test('空文本产出空行盒序列', () {
    expect(layout(''), isEmpty);
  });

  test('单行文本产出一个行盒，覆盖全文', () {
    const text = '短句';
    final lines = layout(text);

    expect(lines, hasLength(1));
    expect(lines.single.start, 0);
    expect(lines.single.end, text.length);
    expect(lines.single.height, greaterThan(0));
  });

  test('无换行长文本的行范围首尾相接，可无损还原原文', () {
    const text = '这是一段很长的中文段落用来验证断行行为，'
        '它应该会被排成好几行，我们需要知道每一行到底覆盖了原文的哪些字符。';
    final lines = layout(text);

    expect(lines.length, greaterThan(1), reason: '测试前提：该文本必须换行');
    expect(lines.first.start, 0);
    expect(lines.last.end, text.length);

    for (var i = 1; i < lines.length; i++) {
      expect(lines[i].start, lines[i - 1].end,
          reason: '无换行符时行范围必须首尾相接');
    }

    final rebuilt = lines.map((l) => text.substring(l.start, l.end)).join();
    expect(rebuilt, text);
  });

  test('换行符不属于任何行，行范围之间留有间隙', () {
    const text = '第一段\n第二段';
    final lines = layout(text);

    expect(lines, hasLength(2));
    expect(text.substring(lines[0].start, lines[0].end), '第一段');
    expect(text.substring(lines[1].start, lines[1].end), '第二段');
    expect(lines[1].start, lines[0].end + 1,
        reason: '换行符自身不计入任何行，因此存在 1 个字符的间隙');
  });

  test('硬换行结尾的行被标记，软换行不被标记', () {
    const text = '第一段\n这是一段足够长的文字使其必须折行显示以便验证软换行不会被误判为硬换行';
    final lines = layout(text);

    expect(lines.first.hardBreak, isTrue, reason: '首行以 \\n 结束');
    expect(lines.length, greaterThan(2), reason: '测试前提：第二段必须折行');
    expect(lines[1].hardBreak, isFalse, reason: '折行属于软换行');
    expect(lines.last.hardBreak, isTrue, reason: '文本末行视为硬结束');
  });

  test('西文单词不会被拆断', () {
    const text = 'Flutter typesetting kernel validation sentence here';
    final lines = layout(text, width: 200);

    expect(lines.length, greaterThan(1), reason: '测试前提：该文本必须换行');
    for (final line in lines) {
      final slice = text.substring(line.start, line.end).trim();
      if (slice.isEmpty) continue;
      // 每一行的首尾都不应落在单词内部
      if (line.start > 0 && text[line.start - 1] != ' ') {
        fail('行起点 ${line.start} 落在单词内部："$slice"');
      }
    }
  });

  test('行高恒为正，且随字号增大', () {
    const text = '这是一段需要折行的中文文字内容用来比较不同字号下的行高差异';

    final small = measurer.layout(
      text: text,
      style: const TextStyle(fontSize: 12, height: 1.5),
      maxWidth: 300,
      direction: TextDirection.ltr,
    );
    final large = measurer.layout(
      text: text,
      style: const TextStyle(fontSize: 24, height: 1.5),
      maxWidth: 300,
      direction: TextDirection.ltr,
    );

    expect(small.every((l) => l.height > 0), isTrue);
    expect(large.first.height, greaterThan(small.first.height));
    expect(large.length, greaterThan(small.length), reason: '字号越大行数越多');
  });

  test('行盒顺序严格递增，无重叠', () {
    const text = '第一段文字\n第二段是一段更长的文字需要折行显示以便产生多个行盒\n第三段';
    final lines = layout(text);

    for (var i = 1; i < lines.length; i++) {
      expect(lines[i].start, greaterThanOrEqualTo(lines[i - 1].end),
          reason: '行盒不得重叠');
    }
    for (final line in lines) {
      expect(line.start, lessThanOrEqualTo(line.end));
      expect(line.start, greaterThanOrEqualTo(0));
      expect(line.end, lessThanOrEqualTo(text.length));
    }
  });
}
