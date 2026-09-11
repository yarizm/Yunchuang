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

String paragraphIndentPrefix({
  required int indentCount,
  required bool startsParagraph,
}) {
  if (!startsParagraph || indentCount <= 0) return '';
  return List.filled(indentCount, '\u3000').join();
}

bool _isIgnorableParagraphLeadingCodeUnit(int codeUnit) {
  return codeUnit == 0x0009 ||
      codeUnit == 0x0020 ||
      codeUnit == 0x00A0 ||
      codeUnit == 0x3000 ||
      codeUnit == 0xFEFF;
}
