class SentenceSpan {
  final int index;
  final int startOffset;
  final int endOffset;
  final String text;

  const SentenceSpan({
    required this.index,
    required this.startOffset,
    required this.endOffset,
    required this.text,
  });
}

class SentenceSplitter {
  /// Split [text] into sentences using Chinese/English punctuation:
  /// 。！？! ? . \n
  static List<SentenceSpan> split(String text) {
    final sentences = <SentenceSpan>[];
    if (text.isEmpty) return sentences;

    final pattern = RegExp(r'[^。！？!?\n.]+[。！？!?\n.]?');
    final matches = pattern.allMatches(text);

    for (final match in matches) {
      final s = match.group(0)!.trim();
      if (s.isEmpty) continue;
      sentences.add(SentenceSpan(
        index: sentences.length,
        startOffset: match.start,
        endOffset: match.end,
        text: s,
      ));
    }

    return sentences;
  }

  /// Find which sentence contains [charOffset].
  /// Returns -1 if not found.
  static int findSentenceIndex(List<SentenceSpan> sentences, int charOffset) {
    // 句子按位置排好、互不重叠，二分找最后一个起点不超过 charOffset 的。
    var low = 0;
    var high = sentences.length - 1;
    while (low <= high) {
      final middle = (low + high) >> 1;
      if (sentences[middle].startOffset <= charOffset) {
        low = middle + 1;
      } else {
        high = middle - 1;
      }
    }
    if (high < 0) return -1;
    final sentence = sentences[high];
    return charOffset < sentence.endOffset ? sentence.index : -1;
  }

  /// [offset] 所在那一句的句首：往回找到上一个句末标点，再跳过紧跟在它
  /// 后面的空白和收尾的引号、括号——这些算上一句的。
  ///
  /// 句末标点和 [split] 用的同一组，两边对句子的划分一致。
  static int sentenceStartAt(String text, int offset) {
    var index = offset.clamp(0, text.length).toInt();
    while (index > 0 && !isSentenceEnd(text.codeUnitAt(index - 1))) {
      index--;
    }
    while (index < text.length && isSentenceTrailer(text.codeUnitAt(index))) {
      index++;
    }
    return index;
  }

  static bool isSentenceEnd(int codeUnit) =>
      codeUnit == 0x3002 || // 。
      codeUnit == 0xFF01 || // ！
      codeUnit == 0xFF1F || // ？
      codeUnit == 0x21 || // !
      codeUnit == 0x3F || // ?
      codeUnit == 0x2E || // .
      codeUnit == 0x0A;

  /// 句末标点后面还属于这一句的字符：空白，以及收尾的引号和括号。
  static bool isSentenceTrailer(int codeUnit) =>
      isBlank(codeUnit) ||
      codeUnit == 0x201D || // ”
      codeUnit == 0x2019 || // ’
      codeUnit == 0x300D || // 」
      codeUnit == 0x300F || // 』
      codeUnit == 0xFF09 || // ）
      codeUnit == 0x29 || // )
      codeUnit == 0x5D || // ]
      codeUnit == 0x3011 || // 】
      codeUnit == 0x300B; // 》

  static bool isBlank(int codeUnit) =>
      codeUnit == 0x20 ||
      codeUnit == 0x09 ||
      codeUnit == 0x0A ||
      codeUnit == 0x0D ||
      codeUnit == 0x3000 ||
      codeUnit == 0xA0 ||
      codeUnit == 0xFEFF;
}
