import 'package:flutter_test/flutter_test.dart';
import 'package:yunchuang/pages/reader/paragraph_layout.dart';

void main() {
  group('isLogicalParagraphStart', () {
    test('recognizes chapter start, BOM, leading spaces, LF, and CRLF', () {
      expect(isLogicalParagraphStart('第一段', 0), isTrue);

      const bomText = '\uFEFF  第一段';
      expect(isLogicalParagraphStart(bomText, bomText.indexOf('第')), isTrue);

      const lfText = '第一段\n  第二段';
      expect(isLogicalParagraphStart(lfText, lfText.indexOf('第', 1)), isTrue);

      const crlfText = '第一段\r\n第二段';
      expect(
        isLogicalParagraphStart(crlfText, crlfText.lastIndexOf('第')),
        isTrue,
      );
    });

    test('does not treat a split inside a long paragraph as a new paragraph',
        () {
      const text = '这是一个不会在中途重复缩进的长段落';
      expect(isLogicalParagraphStart(text, 8), isFalse);
    });
  });

  test('paragraph indent is a render-only ideographic-space prefix', () {
    expect(
      paragraphIndentPrefix(
        indentCount: 2,
        startsParagraph: true,
        paragraphText: '\u6b63\u6587',
      ),
      '\u3000\u3000',
    );
    expect(
      paragraphIndentPrefix(
        indentCount: 2,
        startsParagraph: false,
        paragraphText: '\u6b63\u6587',
      ),
      isEmpty,
    );
    expect(
      paragraphIndentPrefix(
        indentCount: 0,
        startsParagraph: true,
        paragraphText: '\u6b63\u6587',
      ),
      isEmpty,
    );
  });

  test('paragraph indent only tops up what the text already has', () {
    String prefix(String text, {int indent = 2}) => paragraphIndentPrefix(
          indentCount: indent,
          startsParagraph: true,
          paragraphText: text,
        );

    // \u4e2d\u6587 TXT \u5e38\u89c1\u7684\u4e24\u4e2a\u5168\u89d2\u7a7a\u683c\uff1a\u5df2\u7ecf\u591f\u4e86\uff0c\u4e0d\u518d\u53e0\u52a0\u3002
    expect(prefix('\u3000\u3000\u6b63\u6587'), isEmpty);
    expect(prefix('\u3000\u6b63\u6587'), '\u3000');
    expect(prefix('\u3000\u3000\u6b63\u6587', indent: 4), '\u3000\u3000');
    // \u534a\u89d2\u7a7a\u683c\u4e24\u4e2a\u6298\u4e00\u4e2a\u6c49\u5b57\u5bbd\u3002
    expect(prefix('    \u6b63\u6587'), isEmpty);
    expect(prefix('  \u6b63\u6587'), '\u3000');
    expect(prefix(' \u6b63\u6587'), '\u3000\u3000');
    // BOM \u4e0d\u5360\u5bbd\u5ea6\uff0c\u4e0d\u80fd\u5f53\u6210\u7f29\u8fdb\u3002
    expect(prefix('\ufeff\u6b63\u6587'), '\u3000\u3000');
    expect(prefix(''), '\u3000\u3000');
  });
}
