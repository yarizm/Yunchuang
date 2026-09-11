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
    if (sentences.isEmpty) return -1;
    for (final s in sentences) {
      if (charOffset >= s.startOffset && charOffset < s.endOffset) {
        return s.index;
      }
    }
    return -1;
  }
}
