import 'package:flutter_test/flutter_test.dart';
import 'package:yunchuang/typography/line_box.dart';
import 'package:yunchuang/typography/paginator.dart';

/// 这些测试刻意使用 `test()` 而非 `testWidgets()`：分页逻辑不依赖
/// Flutter binding，能这样跑通本身就是依赖切分正确的证明。
void main() {
  // 生成 count 行连续行盒，每行 length 个字符、height 高。
  List<LineBox> makeLines(
    int count, {
    double height = 10,
    int length = 10,
    Set<int> hardBreaksAt = const {},
  }) {
    return List.generate(count, (i) {
      return LineBox(
        start: i * length,
        end: (i + 1) * length,
        height: height,
        hardBreak: hardBreaksAt.contains(i),
      );
    });
  }

  group('paginate', () {
    test('空行盒序列产出空页', () {
      expect(paginate(lines: const [], firstPageHeight: 100, pageHeight: 100),
          isEmpty);
    });

    test('装得下时全部落在一页', () {
      final pages = paginate(
        lines: makeLines(5),
        firstPageHeight: 100,
        pageHeight: 100,
      );

      expect(pages, hasLength(1));
      expect(pages.single.lineCount, 5);
      expect(pages.single.startOffset, 0);
      expect(pages.single.endOffset, 50);
      expect(pages.single.height, 50);
    });

    test('正好填满不会溢出到下一页', () {
      final pages = paginate(
        lines: makeLines(10),
        firstPageHeight: 100,
        pageHeight: 100,
      );

      expect(pages, hasLength(1));
      expect(pages.single.lineCount, 10);
    });

    test('多出一行时开新页', () {
      final pages = paginate(
        lines: makeLines(11),
        firstPageHeight: 100,
        pageHeight: 100,
      );

      expect(pages, hasLength(2));
      expect(pages[0].lineCount, 10);
      expect(pages[1].lineCount, 1);
      expect(pages[1].startOffset, 100);
    });

    test('首页容量更小时只影响首页', () {
      final pages = paginate(
        lines: makeLines(10),
        firstPageHeight: 50,
        pageHeight: 100,
      );

      expect(pages, hasLength(2));
      expect(pages[0].lineCount, 5, reason: '首页让出标题块后只剩 5 行');
      expect(pages[1].lineCount, 5);
    });

    test('段间距会占用容量并可能提前换页', () {
      // 10 行正好填满 100；第 5 行后是段落边界，20 的段间距挤掉两行。
      final pages = paginate(
        lines: makeLines(10, hardBreaksAt: {4}),
        firstPageHeight: 100,
        pageHeight: 100,
        paragraphSpacing: 20,
      );

      expect(pages, hasLength(2));
      expect(pages[0].lineCount, 8, reason: '5 行 + 20 段间距 + 3 行 = 100');
      expect(pages[1].lineCount, 2);
    });

    test('换页后页首不补段间距', () {
      // 第 9 行（末行）是段末，换页后第 10 行不应再被段间距推挤。
      final pages = paginate(
        lines: makeLines(11, hardBreaksAt: {9}),
        firstPageHeight: 100,
        pageHeight: 100,
        paragraphSpacing: 50,
      );

      expect(pages, hasLength(2));
      expect(pages[1].lineCount, 1);
      expect(pages[1].height, 10, reason: '页首行高不含段间距');
    });

    test('单行高于页容量时独占一页而不被丢弃', () {
      final lines = [
        const LineBox(start: 0, end: 10, height: 250),
        const LineBox(start: 10, end: 20, height: 10),
      ];
      final pages = paginate(
        lines: lines,
        firstPageHeight: 100,
        pageHeight: 100,
      );

      expect(pages, hasLength(2));
      expect(pages[0].lineCount, 1);
      expect(pages[0].height, 250);
      expect(pages[1].lineCount, 1);
    });

    test('所有行都被保留且顺序不变', () {
      final lines = makeLines(37, height: 7);
      final pages = paginate(
        lines: lines,
        firstPageHeight: 40,
        pageHeight: 33,
      );

      final flattened = pages.expand((p) => p.lines).toList();
      expect(flattened, lines, reason: '分页不得丢行、改序或改内容');
    });
  });

  group('pageIndexForOffset', () {
    final pages = paginate(
      lines: makeLines(25),
      firstPageHeight: 100,
      pageHeight: 100,
    );

    test('定位到偏移所在的页', () {
      expect(pages, hasLength(3));
      expect(pageIndexForOffset(pages, 0), 0);
      expect(pageIndexForOffset(pages, 99), 0);
      expect(pageIndexForOffset(pages, 100), 1);
      expect(pageIndexForOffset(pages, 200), 2);
    });

    test('超出末页时收敛到末页', () {
      expect(pageIndexForOffset(pages, 999999), 2);
    });

    test('空页序列返回 0', () {
      expect(pageIndexForOffset(const [], 42), 0);
    });
  });
}
