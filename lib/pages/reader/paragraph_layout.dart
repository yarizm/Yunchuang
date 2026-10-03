bool isLogicalParagraphStart(String content, int sourceOffset) {
  if (sourceOffset <= 0) return true;
  if (content.isEmpty || sourceOffset > content.length) return false;

  for (var index = sourceOffset - 1; index >= 0; index--) {
    final codeUnit = content.codeUnitAt(index);
    if (codeUnit == 0x0A || codeUnit == 0x0D) return true;
    if (_isIgnorableParagraphLeadingCodeUnit(codeUnit)) continue;
    return false;
  }
  return true;
}

/// \u6bb5\u9996\u7f29\u8fdb\u7684\u524d\u7f00\uff0c\u53ea\u8865 [paragraphText] \u81ea\u5df1\u7f3a\u7684\u90a3\u90e8\u5206\u3002
///
/// \u4e0d\u5c11\u4e2d\u6587 TXT \u6bcf\u6bb5\u5f00\u5934\u81ea\u5e26\u4e24\u4e2a\u5168\u89d2\u7a7a\u683c\u3002\u4e0d\u770b\u539f\u6587\u7167\u52a0\u7684\u8bdd\uff0c\u4e24\u4efd\u7f29\u8fdb\u53e0\u6210
/// \u56db\u683c\uff1b\u800c\u5206\u7ae0\u65f6\u6574\u7ae0 trim \u6389\u4e86\u7ae0\u9996\u90a3\u6bb5\u7684\u7a7a\u683c\uff0c\u4e8e\u662f\u6bcf\u7ae0\u7b2c\u4e00\u6bb5\u4e24\u683c\u3001\u540e\u9762
/// \u56db\u683c\u3002\u53ea\u8865\u4e0d\u8db3\u7684\u90e8\u5206\uff0c\u539f\u6587\u4e00\u4e2a\u5b57\u4e0d\u52a8\uff0c\u5b57\u7b26\u504f\u79fb\u4e5f\u5c31\u4e0d\u53d7\u5f71\u54cd\u3002\u5ea6\u91cf\u548c
/// \u6e32\u67d3\u90fd\u8981\u7ecf\u8fc7\u8fd9\u91cc\uff0c\u4e24\u8fb9\u7b97\u51fa\u7684\u524d\u7f00\u624d\u4e00\u81f4\u3002
String paragraphIndentPrefix({
  required int indentCount,
  required bool startsParagraph,
  required String paragraphText,
}) {
  if (!startsParagraph || indentCount <= 0) return '';
  final missing = indentCount - _leadingIndentWidth(paragraphText);
  if (missing <= 0) return '';
  return List.filled(missing, '\u3000').join();
}

/// \u6bb5\u9996\u7a7a\u767d\u6298\u7b97\u6210\u51e0\u4e2a\u6c49\u5b57\u5bbd\uff1a\u5168\u89d2\u7a7a\u683c\u7b97\u4e00\u4e2a\uff0c\u534a\u89d2\u7a7a\u683c\u3001\u5236\u8868\u7b26\u4e24\u4e2a\u7b97\u4e00\u4e2a\u3002
int _leadingIndentWidth(String text) {
  var halfWidths = 0;
  for (var index = 0; index < text.length; index++) {
    final codeUnit = text.codeUnitAt(index);
    if (codeUnit == 0x3000) {
      halfWidths += 2;
    } else if (codeUnit == 0x0020 || codeUnit == 0x00A0 || codeUnit == 0x0009) {
      halfWidths += 1;
    } else if (codeUnit != 0xFEFF) {
      break;
    }
  }
  return halfWidths ~/ 2;
}

bool _isIgnorableParagraphLeadingCodeUnit(int codeUnit) {
  return codeUnit == 0x0009 ||
      codeUnit == 0x0020 ||
      codeUnit == 0x00A0 ||
      codeUnit == 0x3000 ||
      codeUnit == 0xFEFF;
}
