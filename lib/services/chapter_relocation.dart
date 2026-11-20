import 'dart:math' as math;

/// 一章的标题和正文。重新分章前后都用它描述。
typedef RelocatableChapter = ({String title, String content});

/// 挂在某一章某个地方的东西：阅读进度、书签、笔记、生词。
class ChapterPosition {
  const ChapterPosition({
    required this.chapterIndex,
    required this.start,
    this.end,
    this.text,
    this.approximate = false,
  });

  /// 第几章，从 0 数。
  final int chapterIndex;

  /// 章内字符偏移。[end] 不含；阅读进度、书签只有一个点，[end] 为 null。
  final int start;
  final int? end;

  /// 那里原本的文字（笔记选中的原文、生词）。旧正文对不上时拿它来找。
  final String? text;

  /// 原文找不到时，可以退到估出来的那一章开头。阅读进度、书签这样就够了；
  /// 笔记、高亮挂错地方比没有位置更糟，不退。
  final bool approximate;
}

/// 重新分章以后，把旧章节上的位置搬到新章节上。结果和 [positions] 一一
/// 对应，找不到的是 null。
///
/// 新旧章节是从同一份正文切出来的，只是切口不同，所以按原文找：取旧位置
/// 往后的一小段文字，到新章节里搜。搜到多处时，先取标题相同的那章——没被
/// 切错的章节，标题和开头都不变——再取离按比例估出来的序号最近的。
List<ChapterPosition?> relocateChapterPositions({
  required List<RelocatableChapter> oldChapters,
  required List<RelocatableChapter> newChapters,
  required List<ChapterPosition> positions,
}) {
  if (newChapters.isEmpty) return List.filled(positions.length, null);
  // 章节划分没变：同一个文件按同样的规则切，或者 PDF 的页。原样对上，
  // 正文没缓存（PDF）也不用找。
  if (_sameTitles(oldChapters, newChapters)) {
    return [
      for (final position in positions)
        position.chapterIndex < newChapters.length ? position : null,
    ];
  }
  final joined = _JoinedChapters(newChapters);
  return [
    for (final position in positions)
      _relocate(position, oldChapters, newChapters, joined),
  ];
}

bool _sameTitles(
  List<RelocatableChapter> oldChapters,
  List<RelocatableChapter> newChapters,
) {
  if (oldChapters.length != newChapters.length) return false;
  for (var index = 0; index < oldChapters.length; index++) {
    if (oldChapters[index].title != newChapters[index].title) return false;
  }
  return true;
}

ChapterPosition? _relocate(
  ChapterPosition position,
  List<RelocatableChapter> oldChapters,
  List<RelocatableChapter> newChapters,
  _JoinedChapters joined,
) {
  final oldIndex = position.chapterIndex;
  if (oldIndex < 0 || oldIndex >= oldChapters.length) return null;
  final old = oldChapters[oldIndex];
  final expected = oldChapters.length <= 1
      ? 0
      : (oldIndex * (newChapters.length - 1) / (oldChapters.length - 1))
          .round()
          .clamp(0, newChapters.length - 1);

  // 先用长一点的原文找；旧位置附近正好跨过一个新的章节标题时，长的那段
  // 在哪一章里都找不到，再用短的试一次。
  for (final length in const [32, 12]) {
    final anchor = _anchorFor(position, old.content, length);
    if (anchor == null) continue;
    final hit = joined.find(
      anchor.text,
      preferTitle: old.title,
      expectedIndex: expected,
      expectedOffset: anchor.start,
    );
    if (hit == null) continue;
    final contentLength = newChapters[hit.index].content.length;
    final start = (hit.offset + anchor.delta).clamp(0, contentLength);
    final end = position.end;
    return ChapterPosition(
      chapterIndex: hit.index,
      start: start,
      end: end == null
          ? null
          : (start + end - position.start).clamp(start, contentLength),
      text: position.text,
      approximate: position.approximate,
    );
  }

  if (!position.approximate) return null;
  // 退到同名的那章（有几章同名取离估计序号最近的），没有同名的就用估计的
  // 序号，都从章首开始。
  var fallback = -1;
  for (var index = 0; index < newChapters.length; index++) {
    if (newChapters[index].title != old.title) continue;
    if (fallback < 0 ||
        (index - expected).abs() < (fallback - expected).abs()) {
      fallback = index;
    }
  }
  return ChapterPosition(
    chapterIndex: fallback < 0 ? expected : fallback,
    start: 0,
    text: position.text,
    approximate: true,
  );
}

/// 拿来搜的那段原文：从旧位置往后取 [length] 个字，快到章末时往前补够。
/// [delta] 是旧位置在这段文字里的偏移。旧正文缺了，或者和笔记记下的原文
/// 对不上，就用笔记的原文本身。
({String text, int start, int delta})? _anchorFor(
  ChapterPosition position,
  String content,
  int length,
) {
  final start = position.start;
  final text = position.text;
  final inContent = start >= 0 && start <= content.length;
  final textMatches = text == null ||
      text.isEmpty ||
      (inContent &&
          start + text.length <= content.length &&
          content.startsWith(text, start));
  if (content.isNotEmpty && inContent && textMatches) {
    final to = math.min(content.length, start + length);
    final from = math.max(0, to - length);
    final anchor = content.substring(from, to);
    if (anchor.trim().length >= _minAnchorLength) {
      return (text: anchor, start: from, delta: start - from);
    }
  }
  if (text != null && text.trim().length >= _minAnchorLength) {
    return (text: text, start: start, delta: 0);
  }
  return null;
}

/// 太短的原文到处都是，搜到了也说明不了什么。
const _minAnchorLength = 4;

/// 新章节的正文首尾相接成一个字符串，一次搜遍全书。章与章之间夹一个
/// 正文里不会有的字符，搜的原文不会跨章。
class _JoinedChapters {
  _JoinedChapters(this._chapters) {
    final buffer = StringBuffer();
    for (final chapter in _chapters) {
      _starts.add(buffer.length);
      buffer
        ..write(chapter.content)
        ..write('\u0000');
    }
    _text = buffer.toString();
  }

  final List<RelocatableChapter> _chapters;
  final List<int> _starts = [];
  late final String _text;

  /// 同一段原文最多看这么多处：一行「……」这种到处都有的原文不值得
  /// 全部比一遍。
  static const _maxHits = 200;

  ({int index, int offset})? find(
    String anchor, {
    required String preferTitle,
    required int expectedIndex,
    required int expectedOffset,
  }) {
    ({int index, int offset})? best;
    (int, int, int)? bestKey;
    var hits = 0;
    for (var at = _text.indexOf(anchor);
        at >= 0 && hits < _maxHits;
        at = _text.indexOf(anchor, at + 1), hits++) {
      final index = _chapterAt(at);
      final offset = at - _starts[index];
      final key = (
        _chapters[index].title == preferTitle ? 0 : 1,
        (index - expectedIndex).abs(),
        (offset - expectedOffset).abs(),
      );
      if (bestKey == null || _compare(key, bestKey) < 0) {
        best = (index: index, offset: offset);
        bestKey = key;
      }
    }
    return best;
  }

  static int _compare((int, int, int) a, (int, int, int) b) {
    if (a.$1 != b.$1) return a.$1 - b.$1;
    if (a.$2 != b.$2) return a.$2 - b.$2;
    return a.$3 - b.$3;
  }

  int _chapterAt(int offset) {
    var low = 0;
    var high = _starts.length - 1;
    while (low < high) {
      final middle = (low + high + 1) >> 1;
      if (_starts[middle] <= offset) {
        low = middle;
      } else {
        high = middle - 1;
      }
    }
    return low;
  }
}
