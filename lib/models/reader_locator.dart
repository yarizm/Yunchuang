class ReaderLocationResolution {
  final double position;
  final int? textOffsetStart;
  final int? textOffsetEnd;

  const ReaderLocationResolution({
    required this.position,
    this.textOffsetStart,
    this.textOffsetEnd,
  });
}

/// A format-neutral pointer to a readable location.
///
/// Text offsets are preferred when they still match the target content. The
/// text anchor and its surrounding context provide recovery when content has
/// changed, while [chapterPosition] remains compatible with older references.
class ReaderLocator {
  static const int contextWindowChars = 48;

  final int bookId;
  final int? chapterId;
  final String? format;
  final int? textOffsetStart;
  final int? textOffsetEnd;
  final int? pageNumber;
  final double? chapterPosition;
  final String? query;
  final String? selectedText;
  final String? contextBefore;
  final String? contextAfter;
  final String? contextHash;

  const ReaderLocator({
    required this.bookId,
    this.chapterId,
    this.format,
    this.textOffsetStart,
    this.textOffsetEnd,
    this.pageNumber,
    this.chapterPosition,
    this.query,
    this.selectedText,
    this.contextBefore,
    this.contextAfter,
    this.contextHash,
  });

  bool get hasTextAnchor =>
      _nonEmpty(selectedText) != null || _nonEmpty(query) != null;

  Map<String, dynamic> toJson() => {
        'bookId': bookId,
        if (chapterId != null) 'chapterId': chapterId,
        if (_nonEmpty(format) != null) 'format': _nonEmpty(format),
        if (textOffsetStart != null) 'textOffsetStart': textOffsetStart,
        if (textOffsetEnd != null) 'textOffsetEnd': textOffsetEnd,
        if (pageNumber != null) 'pageNumber': pageNumber,
        if (chapterPosition != null && chapterPosition!.isFinite)
          'chapterPosition': chapterPosition,
        if (_nonEmpty(query) != null) 'query': _nonEmpty(query),
        if (_nonEmpty(selectedText) != null)
          'selectedText': _nonEmpty(selectedText),
        if (_nonEmpty(contextBefore) != null)
          'contextBefore': _nonEmpty(contextBefore),
        if (_nonEmpty(contextAfter) != null)
          'contextAfter': _nonEmpty(contextAfter),
        if (_nonEmpty(contextHash) != null)
          'contextHash': _nonEmpty(contextHash),
      };

  factory ReaderLocator.fromJson(Map<String, dynamic> json) {
    final rawPosition = _doubleOrNull(json['chapterPosition']);
    final rawStart = _nonNegativeIntOrNull(json['textOffsetStart']);
    final rawEnd = _nonNegativeIntOrNull(json['textOffsetEnd']);
    return ReaderLocator(
      bookId: _intOrNull(json['bookId']) ?? -1,
      chapterId: _positiveIntOrNull(json['chapterId']),
      format: _nonEmpty(_stringOrNull(json['format'])),
      textOffsetStart: rawStart,
      textOffsetEnd: rawStart != null && rawEnd != null && rawEnd >= rawStart
          ? rawEnd
          : null,
      pageNumber: _nonNegativeIntOrNull(json['pageNumber']),
      chapterPosition: rawPosition?.clamp(0.0, 1.0).toDouble(),
      query: _nonEmpty(_stringOrNull(json['query'])),
      selectedText: _nonEmpty(_stringOrNull(json['selectedText'])),
      contextBefore: _nonEmpty(_stringOrNull(json['contextBefore'])),
      contextAfter: _nonEmpty(_stringOrNull(json['contextAfter'])),
      contextHash: _nonEmpty(_stringOrNull(json['contextHash'])),
    );
  }

  ReaderLocationResolution? resolveIn(String content) {
    if (content.isEmpty) {
      final fallback = _normalizedPosition(chapterPosition);
      return fallback == null
          ? null
          : ReaderLocationResolution(position: fallback);
    }

    final anchor = _nonEmpty(selectedText) ?? _nonEmpty(query);
    final exactOffset = _validExactOffset(content, anchor);
    if (exactOffset != null) {
      return _resolution(content.length, exactOffset.$1, exactOffset.$2);
    }

    final recovered = _recoverTextRange(content, anchor);
    if (recovered != null) {
      return _resolution(content.length, recovered.$1, recovered.$2);
    }

    final fallback = _normalizedPosition(chapterPosition);
    return fallback == null
        ? null
        : ReaderLocationResolution(position: fallback);
  }

  (int, int)? _validExactOffset(String content, String? anchor) {
    final start = textOffsetStart;
    if (start == null || start < 0 || start >= content.length) return null;
    final end = (textOffsetEnd ?? (start + (anchor?.length ?? 0)))
        .clamp(start, content.length)
        .toInt();
    if (end <= start) return null;
    if (anchor == null) return (start, end);
    final candidate = content.substring(start, end);
    if (candidate.toLowerCase() == anchor.toLowerCase()) {
      return (start, end);
    }
    return null;
  }

  (int, int)? _recoverTextRange(String content, String? anchor) {
    if (anchor == null || anchor.isEmpty) return null;
    final lowerContent = content.toLowerCase();
    final lowerAnchor = anchor.toLowerCase();
    final candidates = <int>[];
    var searchFrom = 0;
    while (searchFrom <= lowerContent.length - lowerAnchor.length) {
      final index = lowerContent.indexOf(lowerAnchor, searchFrom);
      if (index < 0) break;
      candidates.add(index);
      searchFrom = index + lowerAnchor.length;
      if (candidates.length >= 128) break;
    }
    if (candidates.isEmpty) {
      final fallbackQuery = _nonEmpty(query);
      if (fallbackQuery != null && fallbackQuery != anchor) {
        return _recoverTextRange(content, fallbackQuery);
      }
      return null;
    }
    if (candidates.length == 1) {
      return (candidates.single, candidates.single + anchor.length);
    }

    var bestIndex = candidates.first;
    var bestScore = -1;
    for (final candidate in candidates) {
      final score = _contextScore(content, candidate, anchor.length);
      if (score > bestScore) {
        bestIndex = candidate;
        bestScore = score;
      }
    }
    return (bestIndex, bestIndex + anchor.length);
  }

  int _contextScore(String content, int start, int length) {
    var score = 0;
    final before = _nonEmpty(contextBefore);
    if (before != null) {
      final available = content.substring(0, start);
      final compareLength = before.length.clamp(0, available.length).toInt();
      if (compareLength > 0 &&
          available.substring(available.length - compareLength).toLowerCase() ==
              before.substring(before.length - compareLength).toLowerCase()) {
        score += compareLength;
      }
    }
    final after = _nonEmpty(contextAfter);
    final end = start + length;
    if (after != null && end <= content.length) {
      final available = content.substring(end);
      final compareLength = after.length.clamp(0, available.length).toInt();
      if (compareLength > 0 &&
          available.substring(0, compareLength).toLowerCase() ==
              after.substring(0, compareLength).toLowerCase()) {
        score += compareLength;
      }
    }
    final expectedHash = _nonEmpty(contextHash);
    if (expectedHash != null &&
        contextHashFor(content, start, end) == expectedHash) {
      score += contextWindowChars * 4;
    }
    return score;
  }

  static Map<String, dynamic> textAnchorJson(
    String content,
    int start,
    int end,
  ) {
    if (content.isEmpty || start < 0 || start >= content.length) {
      return const {};
    }
    final safeEnd = end.clamp(start + 1, content.length).toInt();
    final beforeStart = (start - contextWindowChars).clamp(0, start).toInt();
    final afterEnd =
        (safeEnd + contextWindowChars).clamp(safeEnd, content.length).toInt();
    return {
      'textOffsetStart': start,
      'textOffsetEnd': safeEnd,
      'selectedText': content.substring(start, safeEnd),
      if (beforeStart < start)
        'contextBefore': content.substring(beforeStart, start),
      if (safeEnd < afterEnd)
        'contextAfter': content.substring(safeEnd, afterEnd),
      'contextHash': contextHashFor(content, start, safeEnd),
    };
  }

  static String contextHashFor(String content, int start, int end) {
    if (content.isEmpty) return '';
    final safeStart = start.clamp(0, content.length).toInt();
    final safeEnd = end.clamp(safeStart, content.length).toInt();
    final windowStart =
        (safeStart - contextWindowChars).clamp(0, safeStart).toInt();
    final windowEnd =
        (safeEnd + contextWindowChars).clamp(safeEnd, content.length).toInt();
    var hash = 0x811c9dc5;
    for (final codeUnit
        in content.substring(windowStart, windowEnd).codeUnits) {
      hash ^= codeUnit;
      hash = (hash * 0x01000193) & 0xffffffff;
    }
    return hash.toRadixString(16).padLeft(8, '0');
  }

  static ReaderLocationResolution _resolution(
    int contentLength,
    int start,
    int end,
  ) {
    return ReaderLocationResolution(
      position: contentLength <= 0
          ? 0
          : (start / contentLength).clamp(0.0, 1.0).toDouble(),
      textOffsetStart: start,
      textOffsetEnd: end,
    );
  }

  static int? _intOrNull(Object? value) {
    if (value is int) return value;
    if (value is num && value.isFinite) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  static int? _positiveIntOrNull(Object? value) {
    final parsed = _intOrNull(value);
    return parsed != null && parsed > 0 ? parsed : null;
  }

  static int? _nonNegativeIntOrNull(Object? value) {
    final parsed = _intOrNull(value);
    return parsed != null && parsed >= 0 ? parsed : null;
  }

  static double? _doubleOrNull(Object? value) {
    if (value is num && value.isFinite) return value.toDouble();
    if (value is String) {
      final parsed = double.tryParse(value);
      return parsed != null && parsed.isFinite ? parsed : null;
    }
    return null;
  }

  static double? _normalizedPosition(double? value) {
    if (value == null || !value.isFinite) return null;
    return value.clamp(0.0, 1.0).toDouble();
  }

  static String? _nonEmpty(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }

  static String? _stringOrNull(Object? value) => value is String ? value : null;
}
