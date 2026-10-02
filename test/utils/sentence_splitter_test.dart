import 'package:flutter_test/flutter_test.dart';
import 'package:yunchuang/utils/sentence_splitter.dart';

void main() {
  group('sentenceStartAt', () {
    const text = '第一句。“第二句。”他说。\n　　第二段。';

    test('returns the start of the sentence containing the offset', () {
      expect(SentenceSplitter.sentenceStartAt(text, 1), 0);
      // 句末标点属于它前面那一句。
      expect(SentenceSplitter.sentenceStartAt(text, 3), 0);
      expect(SentenceSplitter.sentenceStartAt(text, 6), 4);
    });

    test('closing quotes and blanks after a sentence end are skipped', () {
      final said = text.indexOf('他');
      expect(SentenceSplitter.sentenceStartAt(text, said + 1), said);
      final secondParagraph = text.indexOf('第二段');
      expect(
        SentenceSplitter.sentenceStartAt(text, secondParagraph + 2),
        secondParagraph,
      );
    });

    test('clamps offsets outside the text', () {
      expect(SentenceSplitter.sentenceStartAt(text, -5), 0);
      expect(SentenceSplitter.sentenceStartAt('', 3), 0);
    });
  });

  test('findSentenceIndex locates sentences by binary search', () {
    final sentences = SentenceSplitter.split('甲。乙乙。丙丙丙。');

    expect(SentenceSplitter.findSentenceIndex(sentences, 0), 0);
    expect(SentenceSplitter.findSentenceIndex(sentences, 1), 0);
    expect(SentenceSplitter.findSentenceIndex(sentences, 2), 1);
    expect(SentenceSplitter.findSentenceIndex(sentences, 8), 2);
    expect(SentenceSplitter.findSentenceIndex(sentences, 9), -1);
    expect(SentenceSplitter.findSentenceIndex(const [], 0), -1);
  });
}
