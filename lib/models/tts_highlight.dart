import 'package:flutter/foundation.dart';

/// 听书时正文里要标出来的位置，字符坐标和朗读的那份文本一致。
@immutable
class TtsHighlight {
  const TtsHighlight(
    this.start,
    this.end, {
    this.sentenceStart,
    this.sentenceEnd,
  });

  /// 正在读的这一段：交给引擎的一次朗读，通常是一个段落。
  final int start;
  final int end;

  /// 引擎报了读到哪个字时，段落里正在读的那一句。很多系统引擎不报，就是 null。
  final int? sentenceStart;
  final int? sentenceEnd;

  /// 最该让读者看到的位置：有句子就是句子，否则是整段。
  int get focusStart => sentenceStart ?? start;
  int get focusEnd => sentenceEnd ?? end;

  @override
  bool operator ==(Object other) =>
      other is TtsHighlight &&
      other.start == start &&
      other.end == end &&
      other.sentenceStart == sentenceStart &&
      other.sentenceEnd == sentenceEnd;

  @override
  int get hashCode => Object.hash(start, end, sentenceStart, sentenceEnd);

  @override
  String toString() => 'TtsHighlight($start, $end, '
      'sentence: $sentenceStart-$sentenceEnd)';
}
