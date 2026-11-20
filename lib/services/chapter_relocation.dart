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

  ChapterPosition moved(int index, int start) {
    final contentLength = newChapters[index].content.length;
    final clamped = start.clamp(0, contentLength);
    final end = position.end;
    return ChapterPosition(
      chapterIndex: index,
      start: clamped,
      end: end == null
          ? null
          : (clamped + end - position.start).clamp(clamped, contentLength),
      text: position.text,
      approximate: position.approximate,
    );
  }

  // 先整章找。旧规则多切出来的章节，正文原封不动地并进了新的某一章，
  // 找到整段就知道它从哪儿开始，偏移直接加上去。只拿位置附近一小段原文
  // 去找会认错：「叮！系统提示……」这种句子一章里出现好几次，假章节并回去
  // 以后，前面往往还有一模一样的一段。
  final start = position.start;
  if (old.content.trim().length >= _minAnchorLength &&
      start >= 0 &&
      start <= old.content.length) {
    final hit = joined.find(
      old.content,
      preferTitle: old.title,
      expectedIndex: expected,
      expectedOffset: 0,
    );
    if (hit != null) return moved(hit.index, hit.offset + start);
  }

  // 整段找不到，是新规则把这一章切开了（或者正文变了）。改用位置附近的
  // 一小段原文找：旧位置附近可能正好夹着一个新的章节标题，跨过它的那段
  // 在哪一章里都没有，所以前后都取、只取后面、只取前面轮着试。
  for (final anchor in _anchorsFor(position, old.content)) {
    final hit = joined.find(
      anchor.text,
      preferTitle: old.title,
      expectedIndex: expected,
      expectedOffset: anchor.start,
    );
    if (hit != null) return moved(hit.index, hit.offset + anchor.delta);
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

/// 拿来搜的几段原文，按先后试：旧位置前后各取 32 个字、只取后面 32 个、
/// 只取前面 32 个，再换 12 个字各来一遍（到了章首章尾就少取）。[delta]
/// 是旧位置在这段文字里的偏移。旧正文缺了，或者和笔记记下的原文对不上，
/// 就只用笔记的原文本身。
Iterable<({String text, int start, int delta})> _anchorsFor(
  ChapterPosition position,
  String content,
) sync* {
  final start = position.start;
  final text = position.text;
  final inContent = start >= 0 && start <= content.length;
  final textMatches = text == null ||
      text.isEmpty ||
      (inContent &&
          start + text.length <= content.length &&
          content.startsWith(text, start));
  if (content.isNotEmpty && inContent && textMatches) {
    final seen = <String>{};
    for (final radius in const [32, 12]) {
      for (final (before, after) in [
        (radius, radius),
        (0, radius),
        (radius, 0),
      ]) {
        final from = math.max(0, start - before);
        final to = math.min(content.length, start + after);
        final anchor = content.substring(from, to);
        if (anchor.trim().length >= _minAnchorLength && seen.add(anchor)) {
          yield (text: anchor, start: from, delta: start - from);
        }
      }
    }
    return;
  }
  if (text != null && text.trim().length >= _minAnchorLength) {
    yield (text: text, start: start, delta: 0);
  }
}

/// 太短的原文到处都是，搜到了也说明不了什么。
const _minAnchorLength = 4;

/// 新章节的正文首尾相接成一个字符串，一次搜遍全书。章与章之间夹一个
/// 正文里不会有的字符，搜的原文不会跨章。
class _JoinedChapters {
  _JoinedChapters(this._chapters) {
    final buffer = StringBuffer();
    for (var index = 0; index < _chapters.length; index++) {
      final chapter = _chapters[index];
      _starts.add(buffer.length);
      buffer
        ..write(chapter.content)
        ..write('\u0000');
      (_byTitle[chapter.title] ??= []).add(index);
    }
    _text = buffer.toString();
  }

  final List<RelocatableChapter> _chapters;
  final List<int> _starts = [];
  final Map<String, List<int>> _byTitle = {};
  late final String _text;

  /// 同一段原文最多看这么多处：一行「……」这种到处都有的原文不值得
  /// 全部比一遍。
  static const _maxHits = 200;

  /// 先在估计序号前后这么多章里找，找不到再扫全书。
  static const _window = 60;

  /// 找 [anchor]：同名的章优先，其次离 [expectedIndex] 近的章，同一章里
  /// 取离 [expectedOffset] 近的那处。
  ///
  /// 先在附近逐章找：同名的那几章、估计序号前后 [_window] 章。这样挑出来的
  /// 和扫全书一样（全书的优先级也是先同名、再看离得多远），只是绝大多数
  /// 位置不用扫全书——几百万字的书扫一遍要几十毫秒，一本书挂着几百条笔记
  /// 时，之前光找位置就要十几秒。
  ({int index, int offset})? find(
    String anchor, {
    required String preferTitle,
    required int expectedIndex,
    required int expectedOffset,
  }) {
    final sameTitle = [...?_byTitle[preferTitle]]..sort(
        (a, b) => (a - expectedIndex).abs() - (b - expectedIndex).abs(),
      );
    for (final index in sameTitle) {
      final offset = _nearestIn(index, anchor, expectedOffset);
      if (offset != null) return (index: index, offset: offset);
    }
    for (var distance = 0; distance <= _window; distance++) {
      for (final index in {expectedIndex - distance, expectedIndex + distance}) {
        if (index < 0 || index >= _chapters.length) continue;
        final offset = _nearestIn(index, anchor, expectedOffset);
        if (offset != null) return (index: index, offset: offset);
      }
    }
    return _scanAll(
      anchor,
      preferTitle: preferTitle,
      expectedIndex: expectedIndex,
      expectedOffset: expectedOffset,
    );
  }

  /// 第 [index] 章里离 [expectedOffset] 最近的那处 [anchor]。
  int? _nearestIn(int index, String anchor, int expectedOffset) {
    final content = _chapters[index].content;
    int? best;
    var hits = 0;
    for (var at = content.indexOf(anchor);
        at >= 0 && hits < _maxHits;
        at = content.indexOf(anchor, at + 1), hits++) {
      if (best == null ||
          (at - expectedOffset).abs() < (best - expectedOffset).abs()) {
        best = at;
      }
    }
    return best;
  }

  ({int index, int offset})? _scanAll(
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
