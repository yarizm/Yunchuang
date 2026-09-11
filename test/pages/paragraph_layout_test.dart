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
      paragraphIndentPrefix(indentCount: 2, startsParagraph: true),
      '\u3000\u3000',
    );
    expect(
      paragraphIndentPrefix(indentCount: 2, startsParagraph: false),
      isEmpty,
    );
  });
}
