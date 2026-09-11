/// A parsed chapter extracted from a text file.
class ParsedChapter {
  final String title;
  final String content;
  final int sortOrder;

  ParsedChapter({
    required this.title,
    required this.content,
    required this.sortOrder,
  });
}

/// Metadata extracted from a text file (title, author, etc.).
class ParsedMetadata {
  final String title;
  final String author;
  final String? description;
  final String? coverPath;

  ParsedMetadata({
    required this.title,
    this.author = '',
    this.description,
    this.coverPath,
  });
}

/// Parses plain-text (.txt) files into chapters and metadata.
class TxtParser {
  static final RegExp _linePattern = RegExp(r'^.*$', multiLine: true);
  static const String _chineseNumber = '0-9０-９零〇一二两三四五六七八九十百千万亿甲乙丙丁';

  static final RegExp _explicitHeadingPattern = RegExp(
    '^(?:第\\s*)?([$_chineseNumber]+)\\s*(章|话|回|篇|节|卷|部|集|册)'
    r'(?:[\s\u3000:：,，\-_.．、]*)(.{0,60})$',
    caseSensitive: false,
  );
  static final RegExp _strongExplicitHeadingPattern = RegExp(
    '^第\\s*[$_chineseNumber]+\\s*(?:章|话|回|篇|节|卷|部|集|册)'
    r'(?:$|[\s\u3000:：,，\-_.．、])',
    caseSensitive: false,
  );
  static final RegExp _embeddedExplicitHeadingPattern = RegExp(
    '第\\s*([$_chineseNumber]+)\\s*(章|话|回|篇|节)'
    r'(?:[\s\u3000:：,，\-_.．、]*)(.{0,60})$',
    caseSensitive: false,
  );
  static final RegExp _englishHeadingPattern = RegExp(
    r'^chapter\s+(\d+|[ivxlcdm]+)\b(?:[\s:：\-_.]+.{0,60})?$',
    caseSensitive: false,
  );
  static final RegExp _arabicNumberHeadingPattern = RegExp(
    r'^([0-9０-９]{1,5}(?:\.[0-9０-９]{1,2})?)'
    r'(?:\s*$|(?:[.．、:：]\s*|\s+)?(\S.{0,49})?)$',
  );
  static final RegExp _chineseNumberHeadingPattern = RegExp(
    r'^([零〇一二两三四五六七八九十百千万]{1,12})'
    r'(?:\s*$|(?:[.．、:：]\s*|\s+)(\S.{0,49})?)$',
  );
  static final RegExp _specialHeadingPattern = RegExp(
    r'^(序章|序言|前言|楔子|引子|终章|尾声|后记|番外(?:篇)?|附录)$',
  );

  /// Parse text into chapters by detecting chapter heading patterns.
  static List<ParsedChapter> parseChapters(String text) {
    final normalized = _normalize(text);
    final candidates = _findCandidates(normalized);
    final selected = _selectHeadings(candidates);

    if (selected.isEmpty) {
      return [_fallbackChapter(normalized)];
    }

    final chapters = <ParsedChapter>[];
    for (var index = 0; index < selected.length; index++) {
      final start = selected[index].start;
      final end = index + 1 < selected.length
          ? selected[index + 1].start
          : normalized.length;
      final block = normalized.substring(start, end).trim();
      if (block.isEmpty) {
        continue;
      }

      final firstNewline = block.indexOf('\n');
      final title =
          (firstNewline > 0 ? block.substring(0, firstNewline) : block).trim();
      final content =
          firstNewline > 0 ? block.substring(firstNewline).trim() : '';
      chapters.add(
        ParsedChapter(
          title: title.isEmpty ? '第${chapters.length + 1}章' : title,
          content: content,
          sortOrder: chapters.length,
        ),
      );
    }

    return chapters.isEmpty ? [_fallbackChapter(normalized)] : chapters;
  }

  /// Extract metadata (title, author) from text.
  static ParsedMetadata parseMetadata(String text) {
    final lines = _normalize(text)
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();
    final title = lines.isNotEmpty ? lines[0] : '未知书名';
    final author = lines.length > 1 ? lines[1] : '';
    return ParsedMetadata(title: title, author: author);
  }

  static String _normalize(String text) {
    return text
        .replaceFirst('\uFEFF', '')
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n');
  }

  static List<_HeadingCandidate> _findCandidates(String text) {
    final candidates = <_HeadingCandidate>[];
    for (final match in _linePattern.allMatches(text)) {
      final line = match.group(0)?.trim() ?? '';
      if (line.isEmpty) {
        continue;
      }

      final explicit =
          line.length <= 80 ? _explicitHeadingPattern.firstMatch(line) : null;
      if (explicit != null) {
        if (!_looksLikeEndMarker(explicit.group(3))) {
          candidates.add(
            _HeadingCandidate(
              start: match.start + _leadingWhitespaceLength(match.group(0)!),
              kind: _kindForMarker(explicit.group(2)!),
              strong: _strongExplicitHeadingPattern.hasMatch(line),
            ),
          );
        }
        final suffix = explicit.group(3) ?? '';
        final embedded =
            _findEmbeddedHeading(line, explicit.end - suffix.length);
        if (embedded != null) {
          candidates.add(
            _HeadingCandidate(
              start: match.start +
                  _leadingWhitespaceLength(match.group(0)!) +
                  embedded.start,
              kind: _kindForMarker(embedded.group(2)!),
              strong: _strongExplicitHeadingPattern.hasMatch(
                line.substring(embedded.start),
              ),
            ),
          );
        }
        continue;
      }

      if (line.length <= 80 && _englishHeadingPattern.hasMatch(line)) {
        candidates.add(
          _HeadingCandidate(
            start: match.start + _leadingWhitespaceLength(match.group(0)!),
            kind: _HeadingKind.chapter,
            strong: true,
          ),
        );
        continue;
      }

      if (line.length <= 80 && _specialHeadingPattern.hasMatch(line)) {
        candidates.add(
          _HeadingCandidate(
            start: match.start + _leadingWhitespaceLength(match.group(0)!),
            kind: _HeadingKind.special,
            strong: true,
          ),
        );
        continue;
      }

      final numeric = line.length <= 80
          ? _arabicNumberHeadingPattern.firstMatch(line)
          : null;
      if ((numeric != null && _looksLikeNumericHeading(numeric.group(2))) ||
          (line.length <= 80 && _chineseNumberHeadingPattern.hasMatch(line))) {
        candidates.add(
          _HeadingCandidate(
            start: match.start + _leadingWhitespaceLength(match.group(0)!),
            kind: _HeadingKind.numeric,
          ),
        );
        continue;
      }

      final embedded = line.length <= 200
          ? _embeddedExplicitHeadingPattern.firstMatch(line)
          : null;
      if (embedded != null &&
          embedded.start > 0 &&
          _hasEmbeddedHeadingBoundary(line, embedded.start) &&
          !_looksLikeEndMarker(embedded.group(3))) {
        candidates.add(
          _HeadingCandidate(
            start: match.start +
                _leadingWhitespaceLength(match.group(0)!) +
                embedded.start,
            kind: _kindForMarker(embedded.group(2)!),
            strong: _strongExplicitHeadingPattern.hasMatch(
              line.substring(embedded.start),
            ),
          ),
        );
      }
    }
    return candidates;
  }

  static RegExpMatch? _findEmbeddedHeading(String line, int after) {
    for (final match
        in _embeddedExplicitHeadingPattern.allMatches(line, after)) {
      if (_hasEmbeddedHeadingBoundary(line, match.start) &&
          !_looksLikeEndMarker(match.group(3))) {
        return match;
      }
    }
    return null;
  }

  static bool _hasEmbeddedHeadingBoundary(String line, int start) {
    if (start <= 0) return true;
    final prefix = line.substring(0, start).trimRight();
    return prefix.endsWith('。') ||
        prefix.endsWith('！') ||
        prefix.endsWith('？') ||
        prefix.endsWith('!') ||
        prefix.endsWith('?') ||
        prefix.endsWith('完') ||
        prefix.endsWith('终わり') ||
        prefix.endsWith('終わり');
  }

  static bool _looksLikeEndMarker(String? suffix) {
    final value = suffix?.trim().toLowerCase() ?? '';
    return value == '完' ||
        value == '终わり' ||
        value == '終わり' ||
        value == 'end' ||
        value.startsWith('完第') ||
        value.startsWith('终わり第') ||
        value.startsWith('終わり第');
  }

  static bool _looksLikeNumericHeading(String? suffix) {
    final value = suffix?.trim() ?? '';
    if (_looksLikeEndMarker(value)) return false;
    return !RegExp(r'^(年|月|日|点|时|分|秒|岁|个|人|元|%|％)').hasMatch(value);
  }

  static int _leadingWhitespaceLength(String line) {
    return line.length - line.trimLeft().length;
  }

  static _HeadingKind _kindForMarker(String marker) {
    switch (marker) {
      case '卷':
      case '部':
      case '集':
      case '册':
        return _HeadingKind.volume;
      case '节':
        return _HeadingKind.section;
      default:
        return _HeadingKind.chapter;
    }
  }

  static List<_HeadingCandidate> _selectHeadings(
    List<_HeadingCandidate> candidates,
  ) {
    final chapterCount =
        candidates.where((item) => item.kind == _HeadingKind.chapter).length;
    final sectionCount =
        candidates.where((item) => item.kind == _HeadingKind.section).length;
    final numericCount =
        candidates.where((item) => item.kind == _HeadingKind.numeric).length;
    final strongChapterCount = candidates
        .where(
          (item) => item.kind == _HeadingKind.chapter && item.strong,
        )
        .length;
    final strongSectionCount = candidates
        .where(
          (item) => item.kind == _HeadingKind.section && item.strong,
        )
        .length;

    Set<_HeadingKind> selectedKinds;
    _HeadingKind? strongOnlyKind;
    if (strongChapterCount >= 2) {
      selectedKinds = {
        _HeadingKind.chapter,
        if (_shouldIncludeNumeric(chapterCount, numericCount))
          _HeadingKind.numeric,
      };
    } else if (strongSectionCount >= 2) {
      selectedKinds = {_HeadingKind.section};
      strongOnlyKind = _HeadingKind.section;
    } else if (chapterCount >= 2) {
      selectedKinds = {
        _HeadingKind.chapter,
        if (_shouldIncludeNumeric(chapterCount, numericCount))
          _HeadingKind.numeric,
      };
    } else if (sectionCount >= 2) {
      selectedKinds = {
        _HeadingKind.section,
        if (_shouldIncludeNumeric(sectionCount, numericCount))
          _HeadingKind.numeric,
      };
    } else if (numericCount >= 2) {
      selectedKinds = {
        _HeadingKind.numeric,
        if (chapterCount == 1) _HeadingKind.chapter,
        if (sectionCount == 1) _HeadingKind.section,
      };
    } else if (chapterCount + sectionCount + numericCount >= 2) {
      selectedKinds = {
        _HeadingKind.chapter,
        _HeadingKind.section,
        _HeadingKind.numeric,
      };
    } else {
      return const [];
    }

    return candidates
        .where(
          (candidate) =>
              (selectedKinds.contains(candidate.kind) &&
                  (candidate.kind != strongOnlyKind || candidate.strong)) ||
              candidate.kind == _HeadingKind.special,
        )
        .toList()
      ..sort((a, b) => a.start.compareTo(b.start));
  }

  static bool _shouldIncludeNumeric(int mainCount, int numericCount) {
    if (numericCount == 0) return false;
    return mainCount <= 20 || numericCount * 10 >= mainCount;
  }

  static ParsedChapter _fallbackChapter(String text) {
    final trimmed = text.trim();
    final firstNewline = trimmed.indexOf('\n');
    var title = '全文';
    var content = trimmed;

    if (firstNewline > 0) {
      final firstLine = trimmed.substring(0, firstNewline).trim();
      if (firstLine.isNotEmpty && firstLine.length <= 30) {
        title = firstLine;
        content = trimmed.substring(firstNewline).trim();
      }
    }

    return ParsedChapter(title: title, content: content, sortOrder: 0);
  }
}

enum _HeadingKind {
  chapter,
  section,
  numeric,
  volume,
  special,
}

class _HeadingCandidate {
  final int start;
  final _HeadingKind kind;
  final bool strong;

  const _HeadingCandidate({
    required this.start,
    required this.kind,
    this.strong = false,
  });
}
